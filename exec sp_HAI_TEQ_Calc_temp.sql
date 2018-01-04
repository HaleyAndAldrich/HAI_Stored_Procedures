use equis
go

exec 
[rpt].[sp_HAI_TEQ_Calc_temp]
		47 -- @facility_id int
		,'0' --@ND_mult float 
		,'se' --@matrix varchar (20)
		,'EH_SE_2015Jan|eh-sedchar|EH_SE_2015dec|EH_SE_2016mar|EH_SE_2016oct|EH_sea_se_pore_2015'
		,null --@SDG varchar ( 2000)
		,'pah_25_sum' --@TEF varchar (200)
		,'ug/kg'  --@unit varchar (20)
		,'RL'  --@DL_type varchar (20)
		,'GW TPAH' --@new_chem_name varchar (255)
	
