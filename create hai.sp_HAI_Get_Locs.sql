USE [EQuIS]
GO
/****** Object:  StoredProcedure [HAI].[sp_HAI_Get_Locs]    Script Date: 6/23/2017 8:16:55 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER procedure [HAI].[sp_HAI_Get_Locs]
(
 @facility_Id int,
 @location_groups varchar (2000),
 @locations varchar (1000)

)

as

IF OBJECT_ID('tempdb..##locs')IS NOT NULL DROP TABLE ##locs
create table ##locs
(
 facility_id int
,sys_loc_code varchar (200)
,loc_name varchar (200)
,Loc_Group varchar (200)
,Loc_Report_order varchar(10)
,loc_type varchar(20)
,PRIMARY KEY CLUSTERED (facility_id, sys_loc_code)
)

begin
	
    insert into ##locs 
		select l.facility_id
		,member_code
		,coalesce(l.loc_name, sys_loc_code)
		,group_code 
		,case when len(report_order) = 1 then '0' + cast(report_order as varchar(10)) else cast(report_order as varchar(10)) end
		,l.loc_type 
	from equis.dbo.rt_group_member gm
	inner join equis.dbo.dt_location l on gm.member_code = l.sys_loc_code
		where group_code in (select cast(l.value as varchar(200)) from fn_split(@location_groups)l)
		 and member_type = 'sys_loc_code' 
		 and l.facility_id in (select facility_id from equis.facility_group_members(@facility_id)) 
		 and l.status_flag = 'A'
		order by display_order

   insert into ##locs
		Select 
		facility_id
		,sys_loc_code
		,coalesce(l.loc_name, sys_loc_code)
		,'none selected' 
		,row_number() over (partition by facility_id order by sys_loc_code)
		,loc_type 
		from dt_location l
		where l.facility_id  in (select facility_id from equis.facility_group_members(@facility_id)) 
		and sys_loc_code in (select cast(l.value as varchar(200)) from fn_split(@locations)l)
		and sys_loc_code not in (select sys_loc_code from ##locs)
	
	/*if no locations or groups were selected*/	
	if (select count(*) from ##locs) = 0  and (select count(@location_groups)) = 0 and (select count(@locations)) = 0
	insert into ##locs (l.facility_ID, sys_loc_code, loc_name,loc_Group,loc_report_order, loc_type ) 
			select 
			l.facility_ID
			,coalesce(sys_loc_code,'none')
			,coalesce(l.loc_name, sys_loc_code,'none')
			,coalesce(loc_type, 'none selected')
			,'99' 
			,loc_type 
			from equis.dbo.dt_location l 
			where l.facility_id  in (select facility_id from equis.facility_group_members(@facility_id))  

	/*if no locations exist in the facility....*/
	if (select count(*) from ##locs) = 0 and ( (select count(@location_groups)) = 0 or (select count(@locations)) = 0)
	insert into ##locs (facility_ID, sys_loc_code,loc_name, loc_Group,loc_report_order, loc_type ) 
	select 
	@facility_id
	,'none'
	,null
	,'none selected'
	,null
	,null

	/*if loc order is single digit then add leading zeros*/
	update ##locs
	set loc_report_order = case when len(loc_report_order) = 1 then '0' + loc_report_order else loc_report_order end
return
end			