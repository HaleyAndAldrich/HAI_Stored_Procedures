use equis
go

set nocount on
go

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*Associates location parameters with samples; [HAI].[sp_Get_EQuIS_Results_w_ALs xxx appends parameters to results set  xxx*/

alter procedure hai.sp_HAI_location_parameters2 (
		 @facility_id int  =1686992 
		,@location_groups varchar (2000)
		,@locations varchar (2000)
		,@sample_type varchar(200) 
		,@task_codes varchar (1000)
		,@start_date datetime  = '1/1/1900'  
		,@end_date datetime ='1/1/2050'  
		,@matrix_codes varchar (500) 
		,@loc_param_codes varchar (4000)  )

	as
	begin

	if object_id('tempdb...##location_parameters') is not null drop table ##location_parameters

	exec [hai].[sp_HAI_Get_Locs] @facility_id,@location_groups, @locations  --creates ##locs


	select distinct 
		  s.facility_id
		, sf.subfacility_name
		, coalesce(sample_name,sys_sample_code) as sys_sample_code
		, s.sample_name
		, s.sample_type_code
		, s.sys_loc_code
		, s.task_code
		, s.sample_source
		, s.sample_date as sample_datetime
		, cast(convert(varchar,s.sample_date,101) as datetime) as sample_date
		,'12/31/2015 - 12/31/2015' as sample_date_range
		, cast([rpt].[fn_HAI_sample_end_date] (coalesce(duration,'0'),coalesce(duration_unit,'hrs'),sample_date) as datetime) as sample_end_datetime
		, coalesce(rlpt.param_desc, lp.param_code) as chemical_name
		, lp.param_value as result_qualifier
		, lp.param_value	as report_result	
		, lp.param_unit as result_unit
		, isnull(measurement_method, 'Location Parameter') as analytic_method
		, 'Location Parameters' as compound_group
		, 'Location Parameters' as param_group_name
		, left(lp.param_code,15) as cas_rn
		, case when param_value = 'NM' or param_value = '--' then 'N' else 'Y' end as detect_flag 
		, case when param_value = 'NM' or param_value = '--' then '<' else null end as nd_flag 
		,'99' as mag_report_order
		,'99' as param_group_order

		from dt_sample s 
			inner join ##locs l on s.facility_id = l.facility_id and s.sys_loc_code = l.sys_loc_code
			inner join dt_location_parameter lp 
						on s.facility_id = lp.facility_id 
		                and s.sys_loc_code = lp.sys_loc_code
			inner join rt_location_param_type rlpt on lp.param_code = rlpt.param_code
			left join dt_subfacility sf on l.subfacility_code = sf.subfacility_code

		where s.facility_id =@facility_id  
			and s.matrix_code in (select matrix_code from rpt.fn_hai_get_matrix(@facility_id, @matrix_codes))
			and coalesce(s.task_code, 'none') in (select task_code from rpt.fn_hai_get_taskcode(@facility_id, @task_codes))
			and (cast(s.sample_date as datetime)>= @start_date and cast(s.sample_date as datetime) <= @end_date + 1)
			and lp.param_code in (select cast(value as varchar (100)) from dbo.fn_split(@loc_param_codes))	
			and cast(convert(varchar,s.sample_date,101) as datetime) = cast(convert(varchar,coalesce(lp.measurement_date,s.sample_date),101) as datetime)

	end