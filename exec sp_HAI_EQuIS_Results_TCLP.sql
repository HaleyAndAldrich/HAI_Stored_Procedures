

exec [HAI].[sp_HAI_EQuIS_Results_TCLP]
	 
	47 -- @facility_id int  = 47
	,'1/1/2000' --@start_date datetime =  '1/1/2000'
	,'6/1/2070' --@end_date datetime  = '6/1/2070'
	, 'n' --@sample_type varchar (100) = 'n'
	,null --@matrix_codes varchar (100)
	,'potrero-so'  --@task_codes varchar (1000) = 'potrero-so'
	,null --@location_groups varchar (1000)
	,null --@locations varchar (1000)
	,null --@sdg varchar (1000)
	,'PGE-Potrero-Cyanide|PGE-Potrero_Inorganic|pge-potrero_metals|pge-potrero_svocs|pge-potrero_vocs|pge-qtrly-svocs'  --@analyte_groups varchar(2000)= 'PGE-Potrero-DispSO-Standard'
	,null --@cas_rns varchar (2000)
	,null --@target_unit varchar(15)
	,'RL' --@limit_type varchar (10)
	,'PGE-SL-POTRERO-10xSTLC|PGE-SL-POTRERO-20xTCLP|PGE-SL-POTRERO-STLC|PGE-SL-POTRERO-TCLP|PGE-SL-POTRERO-TTLC' --@action_level_codes varchar (500)
	,'< # Q' --@user_qual_def varchar (10)
	,'N' --@show_val_yn varchar (10) 
	,null --@coord_type varchar(20)