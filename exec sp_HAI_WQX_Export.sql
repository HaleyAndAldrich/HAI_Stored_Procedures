use equis
go

declare @fac int = (select facility_id from dt_facility where facility_name like '%yakima%')
exec [rpt].[sp_HAI_WQX_Export]
	 @fac,
	  null, --@location_groups varchar (2000),
	  null, --@locations varchar (2000),
	  'n', --@sample_type varchar (20),
	  '2014 fall', --'Fall 2014', --@task_codes varchar (1000),
	 '1/1/2010', --@start_date datetime,
	 '1/1/2017', --@end_date datetime,
	  null, --@mth_grp varchar(2000),
	  null, --@param varchar (2000),
	  null, --@fraction varchar(10) = null,
	  'so', --@matrix_codes varchar (500),
	  null, --@target_unit varchar(100),
	  null, --@limit_type varchar (10) = 'RL',
	  null, --@user_qual_def varchar (10) = '# Q',
	  'n', --@show_val_yn varchar (10) = 'N',
	 'Location', --@rpt_flag varchar (20),    -- Determine if exporting WQX_Location, WQX_Result or WQX_Weather
	  null --@coord_type 

