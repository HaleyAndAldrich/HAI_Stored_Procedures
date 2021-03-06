USE [equis]
GO
/****** Object:  StoredProcedure [rpt].[sp_HAI_CooperDrum_Air_ppbv_ugM3]    Script Date: 1/6/2017 2:54:53 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER procedure [rpt].[sp_HAI_CooperDrum_Air_ppbv_ugM3] 
	(
	 @facility_id int
	,@start_date datetime
	,@end_date datetime
	,@location_groups varchar (1000)
	,@locations varchar (1000)
	,@mth_grp varchar (1000) 
	,@param varchar (1000)
	,@matrix_code varchar (20) 
	,@target_unit1 varchar (20)
	,@target_unit2 varchar (20) 
	)

	as begin
		declare @user_qual_def varchar (100) = '< # Q'

		exec [hai].[sp_HAI_GetParams] @facility_id,@mth_grp, @param --creates ##mthgrps
		
		exec [hai].[sp_HAI_Get_Locs] @facility_id,@location_groups, @locations  --creates ##locs


	select 
		r.sys_sample_code,
		r.sample_id,
		r.test_id,
		r.reportable_result,
		r.sys_loc_code,
		l.loc_report_order,
		r.sample_date,
		case 
			when r.start_depth is not null and r.end_depth is not null then cast(r.start_depth as varchar) + '-' + cast(r.end_depth as varchar)
		else cast(coalesce( r.start_Depth, r.end_depth) as varchar)
		end as Depth, 

		case when r.sample_type_code = 'N' then 'Primary'
			when r.sample_type_code = 'FD' then 'Duplicate'
			else r.sample_type_code 
		end as sample_type_code,
		r.matrix_code,
		r.chemical_name,
		mg.parameter,
		mg.mag_report_order,
		mg.param_report_order,
		detect_flag,

		case when detect_flag = 'Y' then result_text else reporting_detection_limit end as [Lab_Reported_Result],
		r.reported_result_unit  as [Lab Reported Unit],

		rpt.fn_hai_result_qualifier(cast(equis.unit_conversion(r.converted_result,r.converted_result_unit,coalesce(mg.default_units,@target_unit1,converted_result_unit),default) as varchar),(case when detect_flag = 'N' then '<' else null end), r.reporting_qualifier,interpreted_qualifiers,@user_qual_def)  as [Result_target_unit1],
		coalesce(mg.default_units,@target_unit1,converted_result_unit) as  Result_unit_target_unit1,

		cast(equis.significant_figures(
			equis.unit_conversion_result(
				converted_result,converted_result_unit,coalesce(MG.DEFAULT_UNITS,@target_unit2,@target_unit1,converted_Result_unit), default,r.facility_id,r.sample_id,r.test_id,r.cas_rn,null),
				equis.significant_figures_get(converted_result),default) as varchar) as Result_Number ,

		rpt.fn_hai_result_qualifier(
			cast(equis.significant_figures(
				equis.unit_conversion_result(converted_result,converted_result_unit,
				coalesce((case when converted_result_unit = '%v/v' then '%v/v' else @target_unit2 end),MG.DEFAULT_UNITS,@target_unit1,converted_Result_unit), 
				default,r.facility_id,r.sample_id,r.test_id,r.cas_rn,null),
				equis.significant_figures_get(converted_result),default) as varchar) 
				,(case when detect_flag = 'N' then '<' else null end), r.reporting_qualifier,interpreted_qualifiers,@user_qual_def) as [Result_target_unit2],
		
		coalesce((case when converted_result_unit = '%v/v' then '%v/v' else @target_unit2 end),MG.DEFAULT_UNITS,@target_unit1,converted_Result_unit) as Result_unit_target_unit2

	from rpt.fn_hai_equis_results(@facility_Id,null,null,null) r
	inner join ##mthgrps mg on r.cas_rn = mg.cas_Rn and r.analytic_method = mg.analytic_method and (case when r.fraction = 'N' then 'T' else r.fraction end) = mg.fraction
	inner join ##locs l on r.facility_id = l.facility_id and r.sys_loc_code = l.sys_loc_code
	inner join (select matrix_code from rpt.fn_hai_get_matrix(@facility_Id,@matrix_code))m on r.matrix_code = m.matrix_code
	where 
		 (cast (sample_Date as datetime) >= @start_date and cast(sample_date as datetime ) <= @end_date)
		and reportable_result = 'Yes'
	IF OBJECT_ID('tempdb..##mthgrps') IS NOT NULL drop table ##mthgrps
	IF OBJECT_ID('tempdb..##locs') IS NOT NULL drop table ##locs

end
	 

	
