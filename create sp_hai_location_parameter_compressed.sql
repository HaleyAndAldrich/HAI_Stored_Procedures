USE [equis]
GO
/****** Object:  StoredProcedure [HAI].[sp_HAI_location_parameter_compressed]    Script Date: 1/6/2017 3:08:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*Created Sept 2016 by Dan Higgins*/
/*procedure specifically developed to suppport Enterprise flow and precip data charting*/
/* Note that non-zero data is filtered out*/
/*non-numeric values are filtered out*/

ALTER procedure [HAI].[sp_HAI_location_parameter_compressed]
	( 
	 @facility_id int 
	,@location_groups varchar(2000)
	,@locations varchar(2000)
	,@task_codes varchar (2000)
	,@param_codes varchar (2000)

	)
 as
 begin

 exec [hai].[sp_HAI_Get_Locs] @facility_id, @location_groups, @locations

 declare  @tasks table (task_code varchar (50))
	insert into @tasks
	select cast(value as varchar) from fn_split(@task_codes)
	if (select count(*) from @tasks) = 0

		insert into @tasks
		select distinct coalesce(task_code , 'none')
		from dt_location_parameter lp
		where lp.facility_id = @facility_id
		and param_code in (select cast(value as varchar) from fn_split(@param_codes))


	select
	 lp.sys_loc_code
	,measurement_date
	,coalesce(task_code, 'none') as task_code
	,param_code
	,param_value
	,param_unit
	

	from dt_location_parameter lp
	inner join ##locs l on lp.facility_id = l.facility_id and lp.sys_loc_code = l.sys_loc_code
	where lp.facility_id = @facility_id
	and param_code in (select cast(value as varchar) from fn_split(@param_codes))
	and param_value not like '0'  --prevents non-zero data from overloading the system
	and isnumeric(param_value) = 1
	and coalesce(lp.task_code, 'none') in (select task_code from @tasks)
union
	select
	 lp.sys_loc_code
	,min(measurement_date) as measurement_date
	,coalesce(task_code, 'none') as task_code
	,param_code
	,param_value
	,param_unit
	

	from dt_location_parameter lp
	inner join ##locs l on lp.facility_id = l.facility_id and lp.sys_loc_code = l.sys_loc_code
	where lp.facility_id = @facility_id
	and param_code in (select cast(value as varchar) from fn_split(@param_codes))
	and coalesce(lp.task_code, 'none') in (select task_code from @tasks)
	group by
	 lp.sys_loc_code
	,coalesce(task_code, 'none')
	,param_code
	,param_value
	,param_unit
	
union
	select
	 lp.sys_loc_code
	,max(measurement_date) as measurement_date
	,coalesce(task_code, 'none') as task_code
	,param_code
	,param_value
	,param_unit
	

	from dt_location_parameter lp
	inner join ##locs l on lp.facility_id = l.facility_id and lp.sys_loc_code = l.sys_loc_code
	where lp.facility_id = @facility_id
	and param_code in (select cast(value as varchar) from fn_split(@param_codes))
	and coalesce(lp.task_code, 'none') in (select task_code from @tasks)
	group by
	 lp.sys_loc_code
	,coalesce(task_code, 'none') 
	,param_code
	,param_value
	,param_unit
	
end


--exec hai.sp_HAI_location_parameter_compressed 118, null, null ,null, 'flow_rate'