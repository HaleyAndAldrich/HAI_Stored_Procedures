


exec [rpt].[sp_HAI_ProUCL] 
	 47 --@facility_id int
	,null --@subfacility_codes varchar (200)
	,null --@analyte_groups varchar (2000)
	,'naphthalene' --@params varchar (1000)
	,null --@fraction varchar(20)
	,null --@locations varchar (2000)
	,'pge row monitoring wells' --@location_groups varchar (200)
	,null --@min_depth float 
	,null  --@max_depth float 
	,'ug/l' -- @target_unit varchar(20)
	,'n '  --@samp_type varchar(20)
	,'wg' --@matrix_codes varchar(200)
	,'01/01/1966' --@min_date datetime
	,'rl'  --@limit_type varchar (20)