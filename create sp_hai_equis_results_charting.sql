USE [EQuIS]
GO
/****** Object:  StoredProcedure [HAI].[sp_HAI_EQUIS_Results_Charting]    Script Date: 6/22/2017 11:17:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*EQuIS Reporting crosstab used for Excel charting macro fails if there are duplicates.
Therefore, this query returns the max detect if there are any detects in the set of duplicates. 
If there are no detects but multiple non-detects then the query returns the lowest reporting limit*/

alter procedure [HAI].[sp_HAI_EQUIS_Results_Charting](
	 @facility_id int,
	 @subfacility_codes varchar (2000),
	 @location_groups varchar (2000),
	 @locations varchar (2000),
	 @sample_type varchar (20),
	 @task_codes varchar (1000),
	 @start_date datetime, --= 'jan 01 1900 12:00 AM',
	 @end_date datetime,  -- ='dec 31 2050 11:59 PM',
	 @analyte_groups varchar(2000),
	 @cas_rns varchar (2000),
	 @fraction varchar(20),
	 @matrix_codes varchar (500),
	 @target_unit varchar(100),
	 @limit_type varchar (10) = 'RL',
	 @user_qual_def varchar (10) = '# Q',
	 @show_val_yn varchar (10) = 'N',
	 @detected_chem_only varchar (10) = 'N',
	 @action_level_code varchar (300)
	 )


as 
begin
	
	if object_id('tempdb..#al') is not null drop table #al
	select
	action_level_code as al_code
	,param_code as al_param_code
	,equis.unit_conversion(action_level,unit,coalesce(@target_unit,unit), default) as al_value
	,coalesce(@target_unit,unit) as al_unit
	into #AL
	from equis.dbo.dt_action_level_parameter al
	where action_level_code = @action_level_code


	exec [hai].[sp_HAI_GetParams] @facility_id,@analyte_groups, @cas_rns --creates ##mthgrps

	exec [hai].[sp_HAI_Get_Locs] @facility_id,@location_groups, @locations  --creates ##locs

	if (select count(@subfacility_codes)) > 0
	begin
		delete ##locs
		from ##locs locs
		left join (select sys_loc_code from dt_location where facility_id = @facility_id and subfacility_code in (select cast(value as varchar (20)) from fn_split(@subfacility_codes)))l
		on locs.sys_loc_code = l.sys_loc_code
		where l.sys_loc_code is null
	end

	select
	r.facility_id
	,r.sys_sample_code
	,r.sample_name
	,r.lab_sample_id
	,r.sys_loc_code
	,l.loc_report_order
	,m.param_report_order
	,r.start_depth
	,r.end_depth
	,r.depth_unit
	,case 
		when r.start_depth is not null and r.end_depth is null then
			cast(r.start_depth as varchar) + ' (' + depth_unit + ')'
		when r.start_depth is not null and r.end_depth is not null then + '-' + coalesce(cast(end_depth as varchar),'') + ' (' + depth_unit + ')'
		end as sample_depth
	,r.sample_source
	,r.sample_date
	,cast(convert(varchar,r.sample_date,101) as datetime) as simple_date
	,case 
		when r.duration_unit = 'hours' then dateadd(hour,cast(r.duration as real),sample_date)
		when r.duration_unit = 'hour' then dateadd(hour,cast(r.duration as real),sample_date)
		when r.duration_unit = 'days' then dateadd(day,cast(r.duration as real),sample_date)
		when r.duration_unit = 'day' then dateadd(day,cast(r.duration as real),sample_date)
		else coalesce(sample_date,'') end as sample_end_date
	,r.task_code
	,r.matrix_code
	,r.sample_type_code
	--,params.grp_name as Parameter_Group_Name
	--,params.param_report_order
	,r.analytic_method
	,r.fraction
	,r.analysis_location
	,r.cas_rn
	,coalesce(m.parameter, r.chemical_name) as chemical_name
	,case   /*If duplicate results and one or more are detected then report 'Y' */
		when count(case when r.detect_flag = 'y' then r.detect_Flag end) > 0 then max(case when r.detect_flag = 'y' then cast(r.detect_flag as varchar) end )
		when count(case when r.detect_flag = 'n' then r.detect_flag end) >0  then  max(case when r.detect_flag = 'n' then cast(r.detect_flag as varchar) end )
	 end as detect_flag
	,r.result_text
	,r.result_numeric
	,r.reporting_detection_limit
	,r.method_detection_limit
	,r.reported_result_unit
	,case   /*If duplicate results and one or more are detected then report the max detect*/
		when count(case when r.detect_flag = 'y' then r.detect_Flag end) > 0 then max(case when r.detect_flag = 'y' then equis.unit_conversion(r.converted_result,r.converted_result_unit,coalesce(@target_unit,m.default_units, r.converted_result_unit),default)  end)
		/*if duplicate results and there are no detects then report the minimum detection limit*/
		 when count(case when r.detect_flag = 'n' then r.detect_flag end) > 0 then min(case when r.detect_flag = 'n' then equis.unit_conversion(r.converted_result,r.converted_result_unit,coalesce(@target_unit,m.default_units, r.converted_result_unit),default) end)
	 end as Report_Result

	,case 
		when count(case when r.detect_flag = 'y' then r.detect_Flag end) > 0 then max(case when r.detect_flag = 'y' then cast(equis.unit_conversion(r.converted_result,r.converted_result_unit,coalesce(@target_unit,m.default_units, r.converted_result_unit),default) as float)  end)
		 when count(case when r.detect_flag = 'n' then r.detect_flag end) > 0 then max(case when r.detect_flag = 'n' then cast(equis.unit_conversion(r.converted_result,r.converted_result_unit,coalesce(@target_unit,m.default_units, r.converted_result_unit),default) as float) end)
	 end as Result_All
	,case when count(case when r.detect_flag = 'y' then r.detect_Flag end) > 0 then max(case when r.detect_flag = 'y' then cast(equis.unit_conversion(r.converted_result,r.converted_result_unit,coalesce(@target_unit,m.default_units, r.converted_result_unit),default) as float)  end) end as Result_detected
	,case when count(case when r.detect_flag = 'n' then r.detect_flag end) > 0 then min(case when r.detect_flag = 'n' then cast(equis.unit_conversion(r.converted_result,r.converted_result_unit,coalesce(@target_unit,m.default_units, r.converted_result_unit),default) as float) end) end as Result_non_detected
	,coalesce(@target_unit,m.default_units, r.converted_result_unit) as Report_Unit
	,r.reporting_qualifier
	,r.detection_limit_type
	,r.interpreted_qualifiers
	,r.validator_qualifiers
	,validated_yn
	,case 
		when count(case when r.detect_flag = 'n' then r.detect_flag end) >0  then  max(case when r.detect_flag = 'n' then cast('<' as varchar) end )
	 end as ND_flag
	,approval_a
	,cast(x_coord as real) as x_coord
	,cast(y_coord as real) as y_coord
	,al.al_code
	,al.al_value
	,al.al_unit

	into #R

	from [rpt].[fn_HAI_EQuIS_Results](@facility_id, @target_unit, @limit_type, null) r


	inner join ##locs l on r.facility_id = l.facility_id and r.sys_loc_code = l.sys_loc_code

	inner join (select  facility_id, grp_name, parameter,cas_rn
		, analytic_method,  fraction, param_report_order
		,mag_report_order, default_units from ##mthgrps
		  ) m 
		on r.facility_id  = m.facility_id and r.cas_rn = m.cas_rn and r.analytic_method = m.analytic_method 
		and case when r.fraction = 'D' then 'D' else 'T' end =  m.fraction
		
	left join #al al on r.cas_rn = al.al_param_code 
	
	where r.sample_type_code in (select sample_type_code from rpt.fn_hai_get_sampletype(@facility_id, @sample_type))
		and coalesce(r.task_code, 'none') in (select task_code from rpt.fn_hai_get_taskCode(@facility_id, @task_codes))
		and r.matrix_code in (select matrix_code from rpt.fn_hai_get_matrix(@facility_id, @matrix_codes))
		and r.fraction in (select fraction from rpt.fn_hai_get_fraction (@facility_id, @fraction))

	
		and (cast(r.sample_date as datetime)>= @start_date and cast(r.sample_date as datetime) <= @end_date + 1)

		and result_type_code in ('trg', 'FLD') 
		and coalesce(analysis_location,'LB') = 'lb'
		and reportable_result like 'y%'

	group by

	r.facility_id
	,r.sys_sample_code
	,r.sample_name
	,r.lab_sample_id
	,r.sys_loc_code
	,l.loc_report_order
	,m.param_report_order
	,r.start_depth
	,r.end_depth
	,r.depth_unit
	,r.sample_source
	,r.sample_date
	,r.duration
	,r.duration_unit
	,r.task_code
	,r.matrix_code
	,r.sample_type_code
	,r.analytic_method
	,r.fraction
	,r.analysis_location
	,r.cas_rn
	,r.chemical_name
	,m.parameter
	,r.result_text
	,r.result_numeric
	,r.reporting_detection_limit
	,r.method_detection_limit
	,r.reported_result_unit
	,r.converted_result_unit 
	,m.default_units
	,r.reporting_qualifier
	,r.approval_a
	,r.detection_limit_type
	,r.interpreted_qualifiers
	,r.validator_qualifiers
	,validated_yn
	,x_coord
	,y_coord
	,al.al_code
	,al.al_value
	,al.al_unit
	--Remove chemicals not detected in any location
	declare @detected_chem table (cas_rn varchar(30), param_name varchar (100),detect_flag varchar (10))
	if @detected_chem_only = 'Y'
		begin		
		insert into @detected_chem
			select distinct
			cas_rn
			,chemical_name
			,detect_flag
			from #R
			where detect_Flag = 'Y'

			delete #R where cas_rn not in (select cas_rn from @detected_chem)
		end

	--Format report result
	update #R

		set report_result =
		rpt.fn_HAI_result_qualifier 
		(report_result, --orginal result
		case when detect_flag = 'N' then '<' else null end,  --nd flag
		validator_qualifiers,  --qualifiers
		interpreted_qualifiers,
		@user_qual_def) --how the user wants the result to look
		+ case when @show_val_yn = 'Y'  and validated_yn = 'N' then '[nv]' else '' end 


		select * from #R wh

		if object_id('tempdb..#al') is not null drop table #al
end

