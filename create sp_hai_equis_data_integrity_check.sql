use equis
go

set nocount on
go

alter procedure hai.sp_hai_equis_data_integrity_check (
	@facility_id int
	)
	as 
	begin

/*Check that all samples have task codes*/
		select 
		'1' as [Check ID]
		,'Sample has task code.' as [Check Name]
		,l.subfacility_code as Subfacility
		,'sys_sample_code' as [Value Type]
		,sys_sample_code as [Value Name]
		,case when task_code is null then 'task code missing' end as 'Error Msg'
		from dt_sample s
		inner join dt_location l
		on s.facility_id = l.facility_id and s.sys_loc_code = l.sys_loc_code
		where s.facility_id = @facility_id
		and sample_source = 'field'
		and task_code is null

		union 

/*Check task codes have a permission code*/
		select distinct
		'2' as [Check ID]
		,'Task code has permission code.' as [Check Name]
		 ,l.subfacility_code as Subfacility
		 ,'task_code' as [Value Type]
		,s.task_code  as [Value Name]
		,case when permission_type_code is null then 'permission code missing' end as 'Error Msg'

		from dt_sample s
		inner join dt_location l
		on s.facility_id = l.facility_id and s.sys_loc_code = l.sys_loc_code
		left join dt_hai_task_permissions tp on s.facility_id = tp.facility_id and s.task_code = tp.task_code

		where s.facility_id = @facility_id
		and sample_source = 'field'
		and permission_Type_code is null
		and s.task_code is not null
		union

/*Check permission codes have a review comment*/
		select distinct
		'3' as [Check ID]
		,'Task Code has review comment.' as [Check Name]
		,l.subfacility_code as Subfacility
		 ,'task_code' as [Value Type]
		,tp.task_code  as [Value Name]
		,case when tp.review_comment is null then 'review comment missing' end as 'Error Msg'
		from dt_sample s
		inner join dt_location l
		on s.facility_id = l.facility_id and s.sys_loc_code = l.sys_loc_code
		inner join dt_hai_task_permissions tp on s.facility_id = tp.facility_id and s.task_code = tp.task_code
		where s.facility_id = @facility_id
		and sample_source = 'field'
		and review_comment is null

		union

/*Check sample source = 'Field' for field samples*/
		select distinct
		'4' as [Check ID]
		,'Field sample source = ''field'' for field samples.' as [Check Name]
		,l.subfacility_code as Subfacility
		,'sys_sample_code' as [Value Type]
		,sys_sample_code as [Value Name]
		,case when sample_source is null then 'sample source missing' end as 'Error Msg'

		from dt_sample s
		inner join dt_location l
		on s.facility_id = l.facility_id and s.sys_loc_code = l.sys_loc_code
		where s.facility_id = @facility_id
		and s.sample_type_code in ('n','fd','tb','eb','fb')
		and (s.sample_source is null or s.sample_source not like 'field')

		order by [check id]

	end