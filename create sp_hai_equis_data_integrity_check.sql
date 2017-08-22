use equis
go

set nocount on
go

alter procedure hai.sp_hai_equis_data_integrity_check (
	@facility_id int
	)
	as 
	begin

	declare @t table
	([Check ID]  varchar(10)
	,[Check Name]  varchar (200)
	,Subfacility  varchar (50)
	,[Value Type]  varchar (100)
	,[Value Name]  varchar(50)
	,[Error Msg]  varchar (255)
	)

	insert into @t

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

		union
/*Samples with no sys_loc_codes*/
		select distinct
		'5' as [Check ID]
		,'Samples with no sys_loc_code' as [Check Name]
		,'NA' as Subfacility
		,'sys_sample_code' as [Value Type]
		,sys_sample_code as [Value Name]
		,case when s.sys_loc_code is null then 'sys_loc_code Missing' end as 'Error Msg'
		from dt_sample s

		where s.facility_id = @facility_id
		and s.sample_type_code in ('n','fd','tb','eb','fb')
		and s.sys_loc_code is null
		
		union

/*Sample / test_id with no lab_name_code*/
		select distinct
		'6' as [Check ID]
		,'test_id with no lab_name_code' as [Check Name]
		,l.subfacility_code as Subfacility
		,'sys_sample_code [test_id]' as [Value Type]
		,cast(s.sys_sample_code as varchar (20)) + ' [' + cast(test_id as varchar (20)) + ']' as [Value Name]
		,case when t.lab_name_code is null then 'lab_name_code missing' end as 'Error Msg'
		from dt_sample s
		inner join dt_test t on s.facility_id = t.facility_id and s.sample_id = t.sample_id
		inner join dt_location l on s.facility_id =l.facility_id and s.sys_loc_code = l.sys_loc_code
		where s.facility_id = @facility_id
		and s.sample_type_code in ('n','fd','tb','eb','fb')
		and t.lab_name_code is null

		union

/*Locations without Coords*/
		select
		'7' as [Check ID]
		,'Location with no coordinates'
		,l.subfacility_code
		,'sys_loc_code' as [Value Type]
		,l.sys_loc_code as [Value Name]
		,case when c.sys_loc_code is null then 'Missing Coord' else 'Has Coord' end as 'Error Msg'
		from dt_location l
		left join dt_coordinate c on l.facility_id = c.facility_id and l.sys_loc_code = c.sys_loc_code
		where l.facility_id = @facility_id
		and l.loc_type not like '%IDW%' and l.loc_type not like '%waste%' and l.loc_type not like '%QC%'
		and l.subfacility_code in ('pge-nb','pge-ff','pge-bs','pge-ehu','pge-ehs','pge-p39','pge-p39-eb','pge-p39-wb','PGE-POTRERO','PGE-FRE1','PGE-FRE2')
		and c.sys_loc_code is null
		


/*Need to add Records for Tests that passed*/
		declare @t2 table
		([Check ID]  varchar(10)
		,[Check Name]  varchar (200)
		,Subfacility  varchar (50)
		,[Value Type]  varchar (100)
		,[Value Name]  varchar(50)
		,[Error Msg]  varchar (255))

		insert into @t2
		select
		'1'
		,'All Samples Have task_codes', '--', '--', '--', 'ok'
		union
		select
		'2'
		,'All task_codes Have permission_type_codes', '--', '--', '--', 'ok'
		union
		select
		'3'
		,'All task_permission_type_codes have review comments', '--', '--', '--', 'ok'
		union
		select
		'4'
		,'All field samples flagged as sample_source = ''field''', '--', '--', '--', 'ok'
		union
		select
		'5'
		,'All field samples Have sys_loc_codes', '--', '--', '--', 'ok'
		union
		select
		'6'
		,'All test_ids have lab_name_code', '--', '--', '--', 'ok'
		union
		select
		'7'
		,'All locations have coordinates', '--', '--', '--', 'ok'
		

		insert into @t
		select t2.*
		from @t2 t2
		left join @t t1
		on t2.[check id] = t1.[check id]
		where  t1.[check id] is null
		
		select * from @t
		order by [check id]

	end