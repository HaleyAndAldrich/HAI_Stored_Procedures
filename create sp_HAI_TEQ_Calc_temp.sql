USE [EQuIS]
GO
/****** Object:  StoredProcedure [rpt].[sp_HAI_TEQ_Calc]    Script Date: 12/5/2017 5:11:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


alter PROCEDURE [rpt].[sp_HAI_TEQ_Calc_temp]
	(
		 @facility_id int
		,@ND_mult float 
		,@matrix varchar (20)
		,@locations varchar (2000)
		,@location_groups  varchar(2000)
		,@task_codes varchar (2000) 
		,@SDG varchar ( 2000)
		,@TEF varchar (200)
		,@analyte_groups varchar(2000)  
		,@unit varchar (20)
		,@DL_type varchar (20)
		,@new_chem_name varchar (255)
	)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	--set @DL_type =   --add the crazy [dot] present in the cas number for BAP when the RL is used for ND
	--(select case when @DL_type = 'RL' then '.RL' else @DL_type end)

	Declare @Task_T table (facility_id int, task_code varchar (200))
		Insert into @Task_T
		Select facility_id, coalesce(task_code,'None') from rpt.fn_HAI_Get_TaskCode (@facility_id, @task_codes)

	Declare @SDG_T table (facility_id int, sample_delivery_group varchar(200))
		insert into @SDG_T
		Select facility_id, SDG from rpt.fn_HAI_Get_SDGs (@facility_id, @SDG)

	Declare @locations_T table (facility_id int, sys_loc_code varchar(20))
		insert into @locations_T
		select facility_id, sys_loc_code
		from dt_location l
		where l.facility_id = @facility_id
		and l.sys_loc_code in (select cast(value as varchar (20)) from fn_split(@locations))

		insert into @locations_T
		select gm.facility_id, member_code
		from rt_group_member gm
		inner join (select @facility_id as facility_id, cast(value as varchar (40)) as group_code from fn_split(@location_groups))g
		on gm.facility_id = g.facility_id and gm.group_code = g.group_code
		where gm.member_code not in (select sys_loc_code from @locations_T)

		if (select count(*) from @locations_T) = 0
		begin
			insert into @locations_T
			select distinct s.facility_id, s.sys_loc_code
			from dt_sample s
			inner join dt_test t on s.facility_id =t.facility_id and s.sample_id = t.sample_id
			inner join @Task_T tsk on coalesce(s.task_code,'None') = tsk.task_code 
			inner join @SDG_T sdg_t on coalesce(t.lab_sdg, 'No_SDG') =  sdg_t.sample_delivery_group
			order by s.sys_loc_code
		end
	
	Select * from @locations_T order by sys_loc_code

	Declare @MthGrps table  (
	 facility_id int
	,Grp_Name varchar(100)
	,parameter varchar(4000)
	,cas_rn varchar (30)
	,analytic_method varchar (30)
	,fraction varchar (10)
	,param_report_order varchar(10)
	,mag_report_order varchar(10)
	,default_units varchar (10)
	)

	insert into @MthGrps
	select  
	 facility_id
	,method_analyte_group_code
	,chemical_name
	,cas_rn
	,analytic_method
	,total_or_dissolved 
	,min(report_order) 
	,mag_report_order
	,default_units
	from (
	select  @facility_id as facility_Id,magm.method_analyte_group_code, chemical_name,magm.cas_rn
	, analytic_method, case when total_or_dissolved = 'D' then 'D' else 'T'end as total_or_dissolved , report_order ,mag_report_order, default_units
		from equis.dbo.rt_mth_anl_group_member magm
		inner join equis.dbo.rt_mth_anl_group mag on magm.method_analyte_group_code = mag.method_analyte_group_code 
		where magm.method_analyte_group_code in (select cast(value as varchar(2000)) from fn_split(@analyte_groups)) )z
		group by facility_id, method_analyte_group_code, chemical_name, cas_rn, analytic_method,  mag_report_order, default_units, total_or_dissolved

	if (select count(*) from @mthgrps) = 0
	begin
		insert into @mthgrps(parameter, cas_rn, analytic_method, fraction)
		select distinct
			tf.chemical_name
			,r.cas_Rn
			,t.analytic_method
			,t.fraction
		from equis.dbo.dt_sample s
			inner join equis.dbo.dt_test t on  s.facility_id = t.facility_id and s.sample_id = t.sample_id
			inner join equis.dbo.dt_result r on  t.facility_id = r.facility_id and t.test_id = r.test_id
			inner join equis.dbo.rt_hai_TEF TF on r.cas_rn = TF.cas_rn   --Links to the TEF lookup table
			inner join @Task_T tsk on coalesce(s.task_code,'None') = tsk.task_code 
			inner join @SDG_T sdg_t on coalesce(t.lab_sdg, 'No_SDG') =  sdg_t.sample_delivery_group
		where
		r.reportable_result in ('Y','Yes')
		and s.sample_source = 'field'
		and s.facility_id = @facility_id
		and s.matrix_code = @matrix 

	end
	
	--Create this table variable (array) so we can manipulate the data set in several steps

	Declare @Result table (
	al_code varchar (200)
	,loc varchar(200)
	,s_date varchar (200)
	,sampID varchar (200)
	,test_ID int 
	,facility_id int
	,samptype varchar (20)
	,matrix varchar (20)
	,unit varchar (20)
	, reportable varchar(20)
	,TEQ varchar(200)
	,test varchar (100)
	,fraction varchar(10)
	,cas varchar (100)
	,chem varchar (100)
	,cnt varchar (2000)
	--, Y_noU_cnt varchar (20)
	--,Y_U_cnt varchar (20)
	--,ND_cnt varchar (20)
	,SDG varchar (200)
	, detect_flag varchar (20))

begin try
	INSERT into @result
	SELECT  
		 TF.TEF_CODE  
		,s.sys_loc_code
		,s.sample_date
		,sys_sample_code
		,min(t.test_id)  --grab the min test_id for each group of contributing compounds to use as the test_id for this result set
		,s.facility_id
		, s.sample_type_code
		,s.matrix_code
		, @unit
		, r.reportable_result
		/*MAKING THE TEQ....
		 if detect_flag = 'Y then convert the result to the specific output units and multiply it by the TEF for that compound
		 if detect_flag = 'N' then multipy the reporting_detection_limit by the user-selected ND multiplier  then multiply this by the TEF
		 then sum them all up!!*/
		,sum (case 
					/*if detect is Y and not U-qualified */
					--when r.detect_flag = 'Y' and charindex(coalesce(r.validator_qualifiers,r.interpreted_qualifiers),'U') = 0 then  equis.unit_conversion(result_numeric ,result_unit,@unit, null)  * cast(TF.TEF  as float) 
					
					/*if detect is Y and result is effectively ND due to applied qualifiers (eg method blank detection) then treat like ND and multiply by ND_mult*/
					--when detect_flag = 'Y'and charindex('U',coalesce(r.validator_qualifiers,r.interpreted_qualifiers)) > 0 and @DL_type = 'RL' then (cast (@ND_mult as float) * equis.unit_conversion( cast(coalesce(r.reporting_detection_limit,result_numeric) as float),result_unit,@unit, null)) * cast(TF.TEF as float) 
					--when detect_flag = 'Y'and charindex('U',coalesce(r.validator_qualifiers,r.interpreted_qualifiers)) > 0 and @DL_type = 'MDL' then (cast (@ND_mult as float) * equis.unit_conversion( cast(coalesce(r.method_detection_limit,result_numeric) as float),result_unit,@unit, null)) * cast(TF.TEF as float) 
					
					when r.detect_flag = 'Y'  then  equis.unit_conversion(result_numeric ,result_unit,@unit, null)  * cast(TF.TEF  as float) 
					when detect_flag = 'N' and @DL_type = 'RL' then (cast (@ND_mult as float) * equis.unit_conversion( cast(coalesce(r.reporting_detection_limit,result_numeric) as float),result_unit,@unit, null)) * cast(TF.TEF as float) 
					when detect_flag = 'N' and @DL_type = 'MDL' then (cast (@ND_mult as float) * equis.unit_conversion( cast(coalesce(r.method_detection_limit,result_numeric) as float),result_unit,@unit, null)) * cast(TF.TEF as float) 
					end) as 'TEQ'
		,max(cast (@ND_mult as float) * equis.unit_conversion( cast(coalesce(r.reporting_detection_limit,result_numeric) as float),result_unit,@unit, null) * cast(TF.TEF as float) )
		,t.fraction
		,null--cas  leave blank for later
		,@new_chem_name --max(tf.chemical_name)  -- chem  leave blank for later
		,COUNT(r.cas_rn) as 'Conjourner Count'  --Give a count of how many individual chemicals were used to create the TEQ
		--,count(case when detect_flag = 'y' and charindex('U',validator_qualifiers) = 0 then 1 end)  as Y_noU_cnt
		--,count(case when detect_flag = 'y' and charindex('U',validator_qualifiers) > 0 then 1 end) as Y_U_cnt
		--,count(case when detect_flag = 'n' then 1 end) as ND_cnt
		,t.lab_sdg

		/* line below modified so CA BaP calcs are all detect flag = 'Y'; 
		may have to expand source table to include hint on how
		to handle NDs for various reg situations*/
		,max(case when @TEF  = 'cpah_human health' then 'Y' else case when detect_flag = 'Y'then 'Y' else 'N'end end)  --If at least one contributing chemical is detected then the TEQ will be flagged as detect
		
	FROM equis.dbo.dt_sample s
		inner join equis.dbo.dt_test t on  s.facility_id = t.facility_id and s.sample_id = t.sample_id
		inner join equis.dbo.dt_result r on  t.facility_id = r.facility_id and t.test_id = r.test_id
		inner join equis.dbo.rt_hai_TEF TF on r.cas_rn = TF.cas_rn   --Links to the TEF lookup table
		inner join @Task_T tsk on coalesce(s.task_code,'None') = tsk.task_code 
	    inner join @SDG_T sdg_t on coalesce(t.lab_sdg, 'No_SDG') =  sdg_t.sample_delivery_group
		inner join @MthGrps mg on t.analytic_method = mg.analytic_method and t.fraction = mg.fraction and r.cas_rn = mg.cas_rn
		inner join @locations_T l on s.facility_id = l.facility_id and s.sys_loc_code = l.sys_loc_code
	WHERE
		TF.TEF_CODE = @TEF   --pulls only the TEFs the user selects
	    and 
		r.reportable_result in ('Y','Yes')
		and s.sample_source = 'field'
		and s.facility_id = @facility_id
		and s.matrix_code = @matrix 
		--and r.result_unit not like '%OC'  --We don't want any TOC normalized data
		and t.analytic_method not like '%calc%'  -- we don't want any other calculated results
		and right(result_unit,1) = right(@unit,1)  --make sure we get only the sample matrix; keeps out Leachate Test results
		--and s.sys_sample_code = 'FF-ROW-CMT01A-GW-091217'
	GROUP BY 
	TF.TEF_CODE 
	,s.sys_loc_code
	,s.sample_date
	,s.sys_sample_code
	,s.facility_id
	,s.sample_type_code
	,s.matrix_code
	,r.result_unit 
	,t.lab_sdg
	,reportable_result 
	,t.fraction

	ORDER by sys_sample_code,fraction
end try
begin catch
	print 'No Luck Calculating TEFs: ' +  error_message() 
end catch	

	--/*Making Cas Numbers for various cases*/
	update @Result
	set cas = 
	(select cas_rn from rt_analyte where chemical_name = @new_chem_name)

	--create ESBASIC EDD
select 
	 r.sampid as 'sys_sample_code'
	,s.sample_type_code
	,s.matrix_code
	,convert(varchar,s.sample_date,101) as 'sample_date'
	,convert(varchar,s.sample_date,108) as 'sample_time'
	,s.sys_loc_code
	,t.lab_name_code
	,'CALC' as 'lab_anl_method_name'  --Set the new TEQ method as calculated
	,convert(varchar,GETDATE(),1) as analysis_date   --assign the analysis date as NOW
	,'00:00' as	'analysis_time'
	,t.test_type
	,'001' as 'test_batch_id'   --make up a bogus test_batch_id
	,t.lab_sample_id   --reuses the lab_sample_id for each group of chemicals
	,lab_sdg
	,t.basis
	,null as 'lab_prep_method_name'
	,null as 'prep_date'
	,null as 'prep_time'
	,cas as 'cas_rn'
	,r.chem 
	,r.TEQ as 'result_value'
	,r.unit as 'result_unit'
	,r.detect_flag as 'detect_flag'
	,case when r.detect_flag = 'N' then r.TEQ else Null end as 'detection_limit_used'
	,null as 'lab_qualifiers'
	,'Param Cnt = '+ r.[cnt] +'; TEQ Calc on ' + cast(cast(getdate() as date) as varchar) +' by ' + right(system_user,len(system_user)-charindex('\',system_user)) as 'comment'  --Give a summary of contribution chemicals for auditing purposes
	,s.parent_sample_code as 'parent_sample_code'
	,'T' as 'fraction'
	,s.sample_source as 'sample_source'

from @result r
	inner join equis.dbo.dt_sample s on r.sampid = s.sys_sample_code and r.facility_id = s.facility_id
	inner join equis.dbo.dt_test t on s.facility_id = t.facility_id and s.sample_id = t.sample_id and r.test_id = t.test_id
	left join equis.dbo.rt_analyte ra on r.cas = ra.cas_rn 

END
