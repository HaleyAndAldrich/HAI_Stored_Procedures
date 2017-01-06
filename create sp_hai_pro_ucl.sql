USE [equis]
GO
/****** Object:  StoredProcedure [rpt].[sp_HAI_ProUCL]    Script Date: 1/6/2017 3:14:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



create procedure [hai].[sp_HAI_ProUCL] (
	 @facility_id int
	,@subfacility_codes varchar (200)
	,@analyte_groups varchar (2000)
	,@params varchar (1000)
	,@fraction varchar(20)
	,@locations varchar (2000)
	,@location_groups varchar (200)
	,@min_depth float 
	,@max_depth float 
	,@Unit varchar(20)
	,@samp_type varchar(20)
	,@matrix_codes varchar(200)
	,@min_date datetime
	,@limit_type varchar (20)
	)

as
Begin
	/*Organize Grps and such...*/
	
 -- facilities
 
	  declare @facs table (facility_id int )
	  insert into @facs 
	  select facility_id 
	  from equis.dbo.fn_facility_group_members(@facility_id)

	  declare @subfacs table(facility_id int, subfacility_code varchar (20), subfacility_name varchar(60))
	  insert into @subfacs 
	  select f.facility_id, sf.subfacility_code, sf.subfacility_name 
	  from dt_subfacility sf
	  inner join @facs f on sf.facility_id = f.facility_id
	  where sf.subfacility_code in (select cast(value as varchar (20)) from dbo.fn_split(@subfacility_codes))

	  if len(@subfacility_codes) = 0
	  begin
		insert into @subfacs
		select sf.facility_id, sf.subfacility_code, sf.subfacility_name 
		from dt_subfacility sf
		inner join @facs f on sf.facility_id = f.facility_id
		where subfacility_code is not null
	  end

	  if (select count(*) from @subfacs) = 0
	  begin
		insert into @subfacs
		select f.facility_id, coalesce(sf.subfacility_code,'none'),coalesce(sf.subfacility_name,'none')
		from @facs f 
		inner join dt_subfacility sf on f.facility_id = sf.facility_id
		union
		select @facility_id, 'none', 'none'
	  end

	  
  exec [rpt].[sp_HAI_GetParams] @facility_id,@analyte_groups, @params --creates ##mthgrps
  exec [rpt].[sp_HAI_Get_Locs] @facility_id,@location_groups, @locations  --creates ##locs	

  --manage start and end depth

  if (select len(@min_depth)) is null 
  begin
	set @min_depth = cast(-999998 as float)
  end

  if (select len(@max_depth)) is null 
  begin
	set @max_depth = cast(999998 as float)
  end

--********************************************************************************************************************			
		
/*Ok- lets do the main work*/

		IF OBJECT_ID('tempdb..#R') IS NOT NULL DROP TABLE #R

		  create table #R (
			 sys_loc_code varchar (100)
			,subfacility_code varchar (20)
			,start_depth varchar (20)
			,end_depth varchar (20)
			,matrix varchar (20)
			,sample_date varchar(30)
			,param varchar(100)
			,analytic_method varchar (30)
			,result float
			,detect_Flag varchar(10)
			,unit varchar(10))
			
		 insert into #R

			select
				 r.sys_loc_code
				,sf.subfacility_code
				,r.start_depth
				,r.end_depth 
				,r.matrix_code 
				,convert(varchar,sample_date,101)
				,chemical_name 
				,r.analytic_method
				,r.converted_result
				,detect_flag
				,r.converted_result_unit

		from rpt.fn_HAI_EQuIS_Results(@facility_id,@unit,@limit_type, null) r

		inner join ##locs l on r.facility_id = l.facility_id and r.sys_loc_code = l.sys_loc_code

		inner join @subfacs sf
		on sf.facility_id = r.facility_id and sf.subfacility_code = coalesce(r.subfacility_code, 'none')

		inner join (select  facility_id, grp_name, parameter,cas_rn
		, analytic_method,  fraction, param_report_order
		,mag_report_order, default_units from ##mthgrps
		  ) m 
		on r.facility_id  = m.facility_id and r.cas_rn = m.cas_rn and r.analytic_method = m.analytic_method 
		and case when r.fraction = 'D' then 'D' else 'T' end =  m.fraction 

		inner join (select sample_type_code from rpt.fn_HAI_Get_SampleType(@facility_id, @samp_type))st 
		 on r.sample_type_code = st.sample_type_code 

		 inner join (select matrix_code from rpt.fn_hai_get_matrix(@facility_id, @matrix_codes)) mx
		 on r.matrix_code = mx.matrix_code
		
		where sample_date >= @min_date 
		and reportable_result in ('yes','y')
		and result_type_code = 'trg'
		and (coalesce(r.start_depth,-99998)>=  @min_depth and coalesce(r.end_depth,98888) <= @max_depth)


if (select COUNT(*) from #r) >0
	begin try

		declare @t table (param varchar(100))
		insert into @t select distinct 
		param from #r


		declare @param varchar(100)
		declare @SQL1 varchar(max)
		declare @SQL2 varchar(max) = ''
		declare @sql3 varchar(max)

		set @SQL1 = 

		'select
		 subfacility_code
		,sys_loc_code
		,start_depth
		,end_depth
		,matrix
		,unit
		,sample_date' + CHAR(13)
				
				
		while (select COUNT(param) from @t ) > 0  --for each column header listed in the table variable @column
			begin
			 set @param =  ( select top 1 * from @t)  --pull the first column header from the list
			 set @sql2 = @sql2 + ',max(case when param = ' + ''''+ @param + ''''+ ' then result end ) as ' + '''' + @param + '''' +  char(13)  --add each column to the SQL string
			 +  ',max(case when param = ' + ''''+ @param + ''''+ ' and detect_flag =' + '''' + 'Y' +'''' + ' then 1 ' +char(13) 
				+ 'When param = ' + ''''+ @param + ''''+ ' and detect_flag =' + '''' + 'N' +'''' + ' then 0  end) as ' +'''' + 'd_' + @param + '''' +  char(13)
			 
			 delete @t where param = @param  --delete the last used column heading from the list
			 
			end	


		set @sql3 = 
				'From #r
				group by sys_loc_code , subfacility_code, sample_date,start_Depth, end_depth, matrix,unit
				order by subfacility_code, sys_loc_code, cast(sample_date as smalldatetime)'
		end try
		begin catch
			select ERROR_MESSAGE()
		end catch		
		
		if (select COUNT(*) from #r) =0
		begin
			select 'Check Query Parameters: no data returned'
		end
		
		begin try
				exec( @sql1 + @sql2  + @sql3)
		end try
		begin catch
			select ERROR_MESSAGE ()
			select 'Query String = ' + (@sql1 + @sql2  + @sql3)
		end catch
end
