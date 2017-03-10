
use equis
go

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
set nocount on
go
set ansi_warnings off
go

alter procedure hai.sp_hai_locs_wNo_coords(
	@facility_id int
	,@subfacility_codes varchar (1000)
	) as 
	begin
		declare @subfacility_table table(facility_id int, subfacility_code varchar (20))
		insert into @subfacility_table
		select
		facility_id
		,subfacility_code
		from dt_subfacility
		where subfacility_code in(select cast(value as varchar (20)) as subfacility_code from fn_split(@subfacility_codes))

		if (select count(*) from @subfacility_table) = 0
		begin
			insert into @subfacility_table
			select facility_id, subfacility_code from dt_subfacility where facility_id = @facility_id
		end

		select
		l.subfacility_code
		,l.sys_loc_code
		,l.loc_name
		,case when c.sys_loc_code is null then 'Missing Coord' else 'Has Coord' end as Coord_Status
		into #coord_status
		from dt_location l
		inner join @subfacility_table sb
		on l.facility_id = sb.facility_id and l.subfacility_code = sb.subfacility_code
		left join dt_coordinate c on l.facility_id = c.facility_id and l.sys_loc_code = c.sys_loc_code
		where l.facility_id = @facility_id
		order by subfacility_code, l.sys_loc_code

		select * from #coord_status
	end
	--select 
	--subfacility_code
	--,count(case when coord_status = 'Missing coord' then 1 end) as coord_missing_count
	--,count(case when coord_status = 'has coord' then 1 end) as has_coord_count
	--from #coord_status
	--group by subfacility_code




