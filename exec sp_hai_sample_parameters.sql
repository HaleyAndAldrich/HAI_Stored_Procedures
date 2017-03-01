

use equis
go


exec hai.sp_hai_get_locs 47,null, null

--drop table ##sample_params_xtab

exec [HAI].[sp_HAI_sample_parameters_xtab] 



	    47 -- @facility_id int 
		,'n' --@sample_type varchar(200)
		,'EH_SE_2016Oct' --@task_codes varchar (1000)
		,'1/1/2010'  --@start_date datetime --= 'jan 01 1900 12:00 AM',
		,'1/1/2050' -- @end_date datetime -- ='dec 31 2050 11:59 PM',
		,null -- @matrix_codes varchar (500)
		,'Elevation Range|Mudline Elevation' --,@sample_param_codes varchar (4000)

		select * from ##sample_params_xtab




