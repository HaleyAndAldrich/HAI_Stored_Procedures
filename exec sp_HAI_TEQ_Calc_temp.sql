use equis
go

exec 
[rpt].[sp_HAI_TEQ_Calc_temp]
		47 -- @facility_id int
		,'0' --@ND_mult float 
		,'wg' --@matrix varchar (20)
		,'row_well_feasibility_gw'
		,'PGE-GW-Alk-PAHs-051517'    --@analyte_groups
		,null --@SDG varchar ( 2000)
		,'pah_16_sum' --@TEF varchar (200)
		,'ug/l'  --@unit varchar (20)
		,'RL'  --@DL_type varchar (20)
		,'GW TPAH' --@new_chem_name varchar (255)
	
