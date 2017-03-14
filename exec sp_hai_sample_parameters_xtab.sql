	use equis
	go
			
			declare @facility_id int = (select facility_id from dt_facility where facility_name like 'M&M%')


		exec hai.sp_hai_get_locs @facility_id, null, null


		if OBJECT_ID('tempdb..##sample_params_xtab') IS not NULL drop table ##sample_params_xtab

		exec [HAI].[sp_HAI_sample_parameters_xtab] 
			 @facility_id 
			,'N' --@sample_type 
			,'PGE-P39-EB' --@task_codes 
			,'1/1/2010' --@start_date 
			,'1/1/2050' --@end_date 
			,'se' --@matrix_codes 
			,'Elevation Range|Mudline Elevation' --'excavated_yn' --@sample_param_codes 

			select * from ##sample_params_xtab

			--where sp_sys_sample_code like '%TS01_BS01%'