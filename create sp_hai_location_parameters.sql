USE [equis]
GO
/****** Object:  StoredProcedure [HAI].[sp_HAI_location_parameters]    Script Date: 9/12/2017 10:54:03 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER procedure [HAI].[sp_HAI_location_parameters]

	(	 @facility_id int =47
		,@location_groups varchar (2000)
		,@locations varchar (2000)
		,@sample_type varchar(200)
		,@task_codes varchar (1000)
		,@start_date datetime --= 'jan 01 1900 12:00 AM',
		,@end_date datetime -- ='dec 31 2050 11:59 PM',
		,@matrix_codes varchar (500)
		,@loc_param_codes varchar (4000)
	)

as
begin
	set nocount on

	if object_id('tempdb...##location_parameters') is not null drop table ##location_parameters

	exec [hai].[sp_HAI_Get_Locs] @facility_id,@location_groups, @locations  --creates ##locs

	select 
		 s.facility_id
		,s.subfacility_name
		,coalesce(s.sample_name,s.sys_sample_code) as sys_sample_code  --uses sample_name so PGE duplicate samples (TO15 TO13) will resolve in crosstab
		,s.sample_name
		,s.sample_type_code
		,s.sys_loc_code
		,s.task_code
		,s.sample_source
		,sample_date as sample_datetime
		,convert(varchar,sample_date,101) as sample_date
		,'12/31/2015 - 12/31/2015' as sample_date_range
		,cast([rpt].[fn_HAI_sample_end_date] (duration,duration_unit,sample_date) as datetime) as sample_end_datetime
		,rlpt.param_desc as  chemical_name
		,param_value as result_qualifier
		,param_value as report_result
		,param_unit as report_unit
		,measurement_method as analytic_method
		,measurement_method as parameter_group_name
		,left(lp.param_code,15) as cas_rn
		,case when param_value = 'NM' or param_value = '--' then 'N' else 'Y' end as detect_flag 
		,case when param_value = 'NM' or param_value = '--' then '<' else null end as nd_flag 
		,'99' as mag_report_order
		,'99' as param_group_order
		

	from (
	select distinct 
		s.facility_id
		, coalesce(sample_name,sys_sample_code) as sys_sample_code
		, s.sample_name
		, cast(convert(varchar,s.sample_date,101) as datetime) as sample_date
		, s.sys_loc_code
		, s.task_code 
		, s.matrix_code
		, s.sample_type_code
		, s.sample_source
		, null as duration
		, s.duration_unit
		,sf.subfacility_name
		from dt_sample s 
			inner join dt_location loc on s.facility_id = loc.facility_id and s.sys_loc_code = loc.sys_loc_code
			inner join ##locs l on s.facility_id = l.facility_id and s.sys_loc_code = l.sys_loc_code
			inner join dt_subfacility sf on loc.subfacility_code = sf.subfacility_code

		where s.facility_id =@facility_id  
			and s.matrix_code in (select matrix_code from rpt.fn_hai_get_matrix(@facility_id, @matrix_codes))
			and coalesce(s.task_code, 'none') in (select task_code from rpt.fn_hai_get_taskcode(@facility_id, @task_codes))
			and (cast(s.sample_date as datetime)>= @start_date and cast(s.sample_date as datetime) <= @end_date + 1)
		)s

		inner join dt_location_parameter lp 
		on s.facility_id = lp.facility_id 
			and s.sys_loc_code = lp.sys_loc_code
			and cast(convert(varchar,s.sample_date,101) as datetime) = cast(convert(varchar,lp.measurement_date,101) as datetime)
		inner join rt_location_param_type rlpt on lp.param_code = rlpt.param_code
		where	
		lp.param_code in (select cast(value as varchar (100)) from dbo.fn_split(@loc_param_codes))	



end