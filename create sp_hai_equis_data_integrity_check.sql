use equis
go

set nocount on
go

/*Checks to add*/
--SOIL SAMPLES ALL FRACTION = 'N'
--Soil and Sediment with liquid units  (TCLP)
--detect_flag = "Y" but qualifier = U or UJ or U* '%U%'
--U's
--validated_yn is populated
--check if result_text and result_numeric are populated if detect_flag = 'Y'
--check if < or > in result_text
-- check for "E"
--check for text in result_text

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
		'01' as [Check ID]
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



/*Check sample source = 'Field' for field samples*/
		select distinct
		'02' as [Check ID]
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
		'03' as [Check ID]
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
		'04' as [Check ID]
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
		'05' as [Check ID]
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
		
		union
/*Monitoring Well with no Screen Interval*/
		select
		'06' as [Check ID]
		,'Monitoring Well with no screen interval'
		,l.subfacility_code
		,'sys_loc_code' as [Value Type]
		,l.sys_loc_code as [Value Name]
		,case when ws.sys_loc_code is null then 'Missing ''Screen Inteval'' in dt_well_segment' else 'Has Screen Interval' end as 'Error Msg'
		from dt_location l
		left join (select facility_id, sys_loc_code from dt_well_segment ws  where ws.segment_type = 'screened interval') ws
			on l.facility_id = ws.facility_id and l.sys_loc_code = ws.sys_loc_code
		where l.facility_id = @facility_id
		and l.loc_type not like '%IDW%' and l.loc_type not like '%waste%' and l.loc_type not like '%QC%'
		and l.subfacility_code in ('pge-nb','pge-ff','pge-bs','pge-ehu','pge-ehs','pge-p39','pge-p39-eb','pge-p39-wb','PGE-POTRERO','PGE-FRE1','PGE-FRE2')
		and l.loc_type = 'Monitoring Well'
		and ws.sys_loc_code is null

		union
/*Monitoring Well with TOC*/
		select
		'07' as [Check ID]
		,'Monitoring Well with no TOC'
		,l.subfacility_code
		,'sys_loc_code' as [Value Type]
		,l.sys_loc_code as [Value Name]
		,case when ve.sys_loc_code is null then 'Missing TOC in dt_vertical_elevation' else 'Has TOC' end as 'Error Msg'
		from dt_location l
		left join (select facility_id, sys_loc_code from dt_hai_vertical_elevation ve  where ve.elev_reference_type_code = 'TOC') ve
			on l.facility_id = ve.facility_id and l.sys_loc_code = ve.sys_loc_code
		where l.facility_id = @facility_id
		and l.loc_type not like '%IDW%' and l.loc_type not like '%waste%' and l.loc_type not like '%QC%'
		and l.subfacility_code in ('pge-nb','pge-ff','pge-bs','pge-ehu','pge-ehs','pge-p39','pge-p39-eb','pge-p39-wb','PGE-POTRERO','PGE-FRE1','PGE-FRE2')
		and l.loc_type = 'Monitoring Well'
		and ve.sys_loc_code is null

		union
/*Soil or Sed samples with missing depth(s)*/
		select
		'08'
		,'Soil or Sed with missing sample depth'
		,l.subfacility_code
		,'sys_sample_code' as [Value type]
		,sys_sample_code as [Value name]
		,case 
			when s.start_depth is null and s.end_depth is null then 'missing start and end depth'
			when s.start_depth is null and s.end_depth is not null then 'missing start depth'
			when s.start_depth is not null and s.end_depth is null then 'missing end depth'
		end as  'Err Msg'

		from dt_sample s
		inner join dt_location l on s.facility_id = l.facility_id and s.sys_loc_code = l.sys_loc_code
		where s.facility_id = @facility_id
		and s.matrix_code in ('se','so')
		and (s.start_depth is null or s.end_depth is null)
		and l.loc_type not like '%idw%' and l.loc_type not like '%qc%' 

		union
/*Validator Qualifer not like Interpreted Qualifer*/
		select distinct
		'09'
		,'Interpreted Qual <> Validator Qual'
		,'NA'
		,'Val Qual / Interp Qual (Count)' as [Value Type]
 
		,validator_qualifiers + ' / ' + interpreted_qualifiers + ' (' + cast(count(*) as varchar (10)) + ')' as [Value Name]
		,'Interpreted Qual <> Validator Qual' as 'Err Msg'
		from dt_result r
		where r.facility_id = @facility_id
		and validator_qualifiers is not null
		and validator_qualifiers not like interpreted_qualifiers

		group by 
		 lab_qualifiers
		,validator_qualifiers
		,interpreted_qualifiers

	
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
		'01'
		,'All Samples Have task_codes', '--', '--', '--', 'ok'
		union
		select
		'02'
		,'All field samples flagged as sample_source = ''field''', '--', '--', '--', 'ok'
		union
		select
		'03'
		,'All field samples Have sys_loc_codes', '--', '--', '--', 'ok'
		union
		select
		'04'
		,'All test_ids have lab_name_code', '--', '--', '--', 'ok'
		union
		select
		'05'
		,'All locations have coordinates', '--', '--', '--', 'ok'
		union
		select
		'06'
		,'All Monitoring Wells have Screen Intervals', '--', '--', '--', 'ok'		
		union
		select
		'07'
		,'All Monitoring Wells have TOC', '--', '--', '--', 'ok'	
		union
		select
		'08'
		,'All Soil and Sed Samples have depths', '--', '--', '--', 'ok'	
		union
		select
		'09'
		,'All Val Quals = Interp Quals', '--', '--', '--', 'ok'	

		insert into @t
		select t2.*
		from @t2 t2
		left join @t t1
		on t2.[check id] = t1.[check id]
		where  t1.[check id] is null
		
		select * from @t
		order by [check id]

	end