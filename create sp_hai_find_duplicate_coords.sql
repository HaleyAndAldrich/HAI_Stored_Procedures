
use equis
go

set nocount on
go

	Alter procedure hai.sp_hai_find_duplicate_coords(
	@facility_id int
	)

	as 
	begin

	declare @t table (sys_loc_code varchar (20), coord_type_code varchar (20), identifier varchar (30), x_coord varchar (20), y_coord varchar (20))

	/*insert coords where the is a decimal, trim to two decimal places*/
	insert into @t
		select distinct
		 c.sys_loc_code
		,coord_Type_code
		,identifier
		,left(x_coord, charindex('.', x_coord)+2) x_coord
		,left(y_coord, charindex('.', y_coord)+2) y_coord
		from dt_coordinate c
		inner join dt_sample s on c.facility_id = s.facility_id and c.sys_loc_code = s.sys_loc_code
		where 

		c.facility_id = @facility_id
		--and left(c.sys_loc_code, 2) not like 'BS'
		and charindex('.',x_coord) > 0
		and identifier = 'secondary'
		and coord_type_code not like '%lat%'

	/*insert coords where these is no decimal place*/
	insert into @t
		select distinct
		 c.sys_loc_code
		,coord_Type_code
		,identifier
		,x_coord
		,y_coord
		from dt_coordinate c
		inner join dt_sample s on c.facility_id = s.facility_id and c.sys_loc_code = s.sys_loc_code
		where 

		c.facility_id = @facility_id
		--and left(c.sys_loc_code, 2) not like 'BS'
		and charindex('.',x_coord) = 0
		and identifier = 'secondary'
		and coord_type_code not like '%lat%'

		

		--and c.sys_loc_Code not like 'p39%'
		--and c.sys_loc_code not like '%idw%'
		--and c.sys_loc_code not like '%cmt%'

		declare @d table (x_coord varchar(20))
		insert into @d
		select x_coord
		from (select x_coord,
		 count(x_coord) as x_cnt
		 ,count(y_coord) as y_cnt
		from @t
		group by x_coord
		having count(x_coord) >1 and count(y_coord) > 1)z

		select sys_loc_code
		,x_coord
		,y_coord
		,dense_rank() over (order by x_coord) as dup_ID
		from @t
		where x_coord in (
			select x_coord from @d)

		order by x_coord, sys_loc_code
		
	end