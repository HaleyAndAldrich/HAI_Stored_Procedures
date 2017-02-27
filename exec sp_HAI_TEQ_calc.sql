BEGIN TRAN


exec
[rpt].[sp_HAI_TEQ_Calc]
	
		 153 --@facility_id int
		,0 --@ND_mult float 
		,'wm' --@matrix varchar (20)
		,null --@task_codes varchar (2000) 
		,'4401742371|4401741101|4401727601' --@SDG varchar ( 2000)
		,'ssfl_tcdd' --@TEF varchar (200)
		,'ng/l' --@unit varchar (20)
		,'mdl' --DL_type varchar (20)
		,'2,3,7,8-TCDD TEQ_NoDNQ'--@new_chem_name varchar (255)
	



ROLLBACK

