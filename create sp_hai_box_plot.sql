USE [equis]
GO
/****** Object:  StoredProcedure [rpt].[sp_HAI_BoxPlot]    Script Date: 1/6/2017 2:52:58 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [rpt].[sp_HAI_BoxPlot]

  @facility_id int,
  @location_groups varchar(2000),
  @locations varchar(2000), 
  @sample_type VARCHAR(20), 
  @task_codes varchar (1000),
  @start_date datetime,
  @end_date datetime,
  @mth_grp varchar(2000),
  @param varchar(2000), 
  @fraction varchar(10),
  @matrix_codes varchar(500),
  @target_unit varchar(100)

AS
BEGIN
/*round down start date and round up end date so selection is inclusive*/

if @start_date is null
Begin
	set @start_date = (select min(sample_date) 
	from equis.dbo.dt_sample 
	where sample_source = 'field' and facility_id = @facility_id)
end

if @end_Date is null
Begin
	set @end_date = (select max(sample_date) from equis.dbo.dt_sample 
	where sample_source = 'field' and facility_id = @facility_id)
end

set @start_date = cast(CONVERT(varchar,@start_date,101)as DATE)
set @end_date = CAST(convert(varchar, @end_date, 101) as date)


exec [hai].[sp_HAI_GetParams] @facility_id,@mth_grp, @param --creates ##mth_grps

exec [hai].[sp_HAI_Get_Locs] @facility_id,location_groups, @locations  --creates ##locs

--***************************************************************************	

--Here's where we get the result set we'll use for statitics

IF OBJECT_ID('tempdb..#result') IS NOT NULL DROP TABLE #result
Create table #result  (loc_report_order int,Loc_ID varchar(2000), matrix varchar (200)
,param varchar (2000), fraction varchar (10), detect varchar (20),result float, unit varchar(200))



Insert into #result 

SELECT loc_report_order,r.sys_loc_code, r.matrix_code,  r.chemical_name, r.fraction, r.detect_flag
,converted_result
, converted_result_unit

FROM rpt.fn_hai_equis_results(@facility_id,@target_unit,null, null)r 
inner join ##locs l on r.facility_id = l.facility_id and r.sys_loc_code =  l.sys_loc_code
inner join ##mthgrps mg on r.facility_id = mg.facility_id and r.cas_rn = mg.cas_rn and r.analytic_method = mg.analytic_method and r.fraction = mg.fraction

where 
	r.matrix_code in  (select  matrix_code from rpt.fn_HAI_Get_Matrix (@facility_id,@matrix_codes))
	 and coalesce(r.task_code, 'none') in  (select  task_code from rpt.fn_HAI_Get_TaskCode (@facility_id, @task_codes))
	and  r.sample_type_code in(select  sample_type_Code from rpt.fn_HAI_Get_SampleType (@facility_id, @sample_type) ) 
	and r.fraction in (select fraction from [rpt].[fn_HAI_Get_Fraction] (@facility_id, @fraction))


--***********************************************************************************************

--Builds a table to collect stats as we go along. This is the table returned to the user in EQuIS
IF OBJECT_ID('tempdb..#stats') IS NOT NULL DROP TABLE #stats


create Table #stats ( 
	loc_id varchar (200)
	,Param varchar(200)
	,fraction varchar (10)
	,matrix varchar (20)
	,StatType varchar (20)
	,Val float
	,Unit varchar (10))

--Gets the simple stats created using built-in functions out of the way first
	 insert into #stats
		select distinct loc_id, param,fraction, matrix,'Count',COUNT(result), unit from #result group by loc_id , param, unit, matrix,fraction
	 insert into #stats
		select distinct loc_id, param,fraction,matrix,'DetectCnt',count(case when detect = 'Y' then detect  end)  , unit  from #result group by loc_id , param, unit, matrix,fraction--#Detects
	 insert into #stats
		select distinct loc_id, param,fraction,matrix,'IRQ',null , unit  from #result group by loc_id , param, unit,matrix,fraction--#IQR
	 insert into #stats
		select distinct loc_id, param,fraction,matrix,'Max',Max(result), unit from #result group by loc_id , param, unit, matrix,fraction
	 insert into #stats
		select distinct loc_id,param,fraction,matrix,'Mean',avg(result) , unit from #result group by loc_id , param, unit, matrix,fraction
	 insert into #stats
		select distinct loc_id, param,fraction, matrix,'Median',PERCENTILE_cont(0.5) within group(order by result) over(partition by loc_id, param, matrix,fraction) , unit   from #result --Pcnt Detect
	 insert into #stats
		select distinct loc_id,  param,fraction, matrix, 'Min',MIN(result), unit from #result group by loc_id , param, unit, matrix,fraction

	 insert into #stats
		select distinct loc_id, param,fraction,matrix,'Pct Detects',round(count(case when upper(detect) = 'Y' then detect end)/cast(COUNT(detect) as float),2)  , unit  from #result group by loc_id, param, unit, matrix,fraction--Pcnt Detect

/*use the percentile function*/
	 insert into #stats
		select distinct loc_id, param,fraction, matrix,'1Q',PERCENTILE_cont(0.25) within group(order by result) over(partition by loc_id, param, matrix,fraction) , unit   from #result --Pcnt Detect
	 insert into #stats
		select distinct loc_id, param,fraction, matrix,'3Q_label',PERCENTILE_cont(0.75) within group(order by result) over(partition by loc_id, param, matrix,fraction) , unit   from #result --Pcnt Detect
	 insert into #stats
		select distinct loc_id, param,fraction, matrix,'95th',PERCENTILE_cont(0.95) within group(order by result) over(partition by loc_id, param, matrix,fraction) , unit   from #result --Pcnt Detect
	
	 insert into #stats
		select distinct [3Q].loc_id, [3Q].param,[3Q].fraction, [3Q].matrix, '3Q', cast([3q].val as float) - cast([1Q].val as float) ,[3Q].unit
		from
		(select distinct loc_id, param,fraction, matrix,val , unit   from #Stats where StatType = '3Q_label') [3Q]
		inner join
		(select distinct loc_id, param,fraction, matrix, val , unit from #stats where stattype = '1Q')[1Q]
		on [3Q].loc_id = [1Q].loc_id and [3Q].param = [1Q].param and [3Q].fraction = [1Q].fraction and [3Q].matrix = [1Q].matrix

IF OBJECT_ID('tempdb..#outliers') IS NOT NULL DROP TABLE #outliers
	create table #outliers 	
		(loc_id varchar (200)
		,Param varchar(200)
		,fraction varchar(10)
		,matrix varchar (20)
		,StatType varchar (200)
		,Val real
		,Unit varchar (10))

	insert into #outliers 
		select distinct 
			 s.loc_id
			,s.param
			,s.fraction
			, o.matrix
			,'zOutlier'+cast(o.row_num as varchar)
			, o.result 
			, o.unit
		from #stats s 
			inner join 
			(select  r.loc_id, r.matrix, r.fraction,r.result,  r.param, ROW_NUMBER() over ( partition by loc_id,param, fraction order by r.result desc) as Row_Num, r.unit
			from (select distinct loc_id, matrix,param, fraction, result,unit  from #result )r) o 
			on s.loc_id = o.loc_id and s.param =o.param and s.fraction = o.fraction

			inner join
			(select loc_id, param, fraction, stattype, val as [95th_val] from #stats where stattype = '95th') outlier
			on s.loc_id = outlier.loc_id and s.param = outlier.param and s.fraction = outlier.fraction

					 
		 where o.result > outlier.[95th_val] 


--********************************************************

/*Crosstab Outliers so they can be joined to the #stats table*/
IF OBJECT_ID('tempdb..##outlier_test') IS NOT NULL DROP TABLE ##outlier_test

if (select count(*) from #outliers) > 0
begin
		declare @outid varchar (20)
		declare @sql varchar (max)
		declare @cnt int =1
		declare @rowcnt int = (select max(replace(stattype,'zOutlier','')) from #outliers)
		--print 'row count = ' + cast(@rowcnt as varchar)

		set @sql = 'select loc_id, param, matrix, fraction '

		while @cnt < @rowcnt + 1
		begin
			set @outid = 'zOutlier' + cast(@cnt as varchar)
			set @sql = @sql + char(13) +
			',max(case when stattype =' + '''' +  @outid + '''' + ' then val end ) as ' + @outid 

			print @cnt
			set @cnt = @cnt + 1
		end

		set @sql = @sql + char(13) +
		'into ##outlier_test ' + char(13) +  ' From #outliers ' + char(13) + 
		'Group by loc_id, param, fraction, matrix, unit '

		exec( @sql)
end
if (select count(*) from #outliers) = 0
begin
	create table ##outlier_test (loc_id varchar (200), param varchar (200), matrix varchar (20), fraction varchar(10))
end		

		IF OBJECT_ID('tempdb..#stats') IS NOT NULL 
		begin
			IF OBJECT_ID('tempdb..##stat_final') IS NOT NULL 
			begin
				DROP TABLE ##stat_final
			end

			select 
			s.loc_id + ' [' + s.param +
			case when s.fraction = 't' then + ' (Total)'
				when s.fraction = 'd' then ' (Dissolved)'
				else '' end + 
			  + ']' as loc_param,
			s.loc_id,
			s.param,
			s.fraction,
			s.matrix,
			s.unit,
			max(case when stattype = 'count' then val end) as 'Count',
			max(case when stattype = 'detectcnt' then val end) as [Detect Count],
			null as [IQR],
			max(case when stattype = 'max' then val end) as 'Max',
			max(case when stattype = 'mean' then val end) as 'Mean',			
			max(case when stattype = 'median' then val end) as 'Median',
			max(case when stattype = 'min' then val end) as 'Min',						
			max(case when stattype = '1Q' then val end) as [First Quartile],
			max(case when stattype = '3Q' then val end) as [Third Quartile],
			max(case when stattype = '3Q_label' then val end ) as [Third Q Label],
			null as [Pct Detects]
			into ##stat_final
			from #stats s
			group by s.loc_id, s.param, s.fraction,s.matrix, s.unit

			select
			sf.loc_param,
			sf.loc_id,
			sf.param,
			sf.fraction,
			sf.matrix,
			sf.unit,
			sf.[Min],
			sf.[Max],
			sf.[Mean],
			sf.[Median],
			sf.[Count],
			sf.[Detect Count],
			sf.[First Quartile],
			sf.[Third Quartile],
			sf.[Third Q Label],
			ot.*
			from ##stat_final sf
			left join ##outlier_test ot on sf.loc_id = ot.loc_id and sf.param  = ot.param and sf.fraction = ot.fraction and sf.matrix = ot.matrix
		order by sf.param, sf.fraction, sf.loc_id
		end


IF OBJECT_ID('tempdb..#stats') IS NOT NULL DROP TABLE #stats
IF OBJECT_ID('tempdb..#result') IS NOT NULL DROP TABLE #result
IF OBJECT_ID('tempdb..##outlier_test') IS NOT NULL DROP TABLE ##outlier_test
IF OBJECT_ID('tempdb..##stat_final') IS NOT NULL DROP TABLE ##stat_final

END
