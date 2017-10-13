use equis
go

set nocount on
go


alter procedure hai.sp_hai_validation_sample_method_summary(
		 @facility_id int = 47
		,@task_codes varchar (1000)
		,@SDGs varchar (1000) 
		,@sample_type varchar(100)
		,@limit_type varchar(10)
		,@compound_groups varchar (2000)
		,@validation_report_type varchar (20) --'Qualifiers'  'Methods' 
		)

	as 
	begin
	declare 
	 @list varchar (max)
	,@SQL varchar(max)

	if @validation_report_type = 'Methods'
		begin 
			select distinct
			sys_sample_code as [Sample ID]
			,sample_type_code [Sample Type]
			,lab_sample_ID as [Lab Sample ID]
			,convert(varchar,sample_date,101) as [Sample Collection Date]
			,matrix_desc as Matrix
			,rpt.fn_list(@facility_id, sys_sample_code) as [Methods]
			from dt_sample s
			inner join dt_test t on s.facility_id = t.facility_id and s.sample_id = t.sample_id
			inner join rt_matrix rm on s.matrix_code = rm.matrix_code

			where s.facility_id = @facility_id
			and s.task_code in (select task_code from rpt.fn_hai_get_taskcode(@facility_id, @task_codes))
			and t.lab_sdg in (select SDG from rpt.fn_hai_get_sdgs(@facility_id, @SDGs) )
			and s.sample_type_code in (select sample_type_code from rpt.fn_hai_get_sampletype(@facility_id, @sample_type))

		end
	if @validation_report_type = 'Qualifiers'
		begin 
			select 
			sys_sample_code as [Sample ID]
			,lab_sample_ID as [Lab Sample ID]
			,convert(varchar,sample_date,101) as [Sample Collection Date]
			,matrix_desc as Matrix
			,compound_group
			,t.analytic_method
			,t.fraction
			,chemical_name
			,case 
			  when detect_flag = 'N' then hai.fn_thousands_separator(
				case when @limit_type = 'RL' then r.reporting_detection_limit
					when @limit_type = 'MDL' then r.method_detection_limit end)
			  when detect_flag = 'Y' then hai.fn_thousands_separator(coalesce(r.result_text, 
				case when @limit_type = 'RL' then r.reporting_detection_limit
					when @limit_type = 'MDL' then r.method_detection_limit end))
			 end  + ' ' 
			 +  coalesce(case 
				when charindex('J',lab_qualifiers) > 0 then 'J'
				when detect_flag = 'N' then 'U' end,'')  
			 as lab_result

			,case 
			  when detect_flag = 'N' then hai.fn_thousands_separator(
				case when @limit_type = 'RL' then r.reporting_detection_limit
					when @limit_type = 'MDL' then r.method_detection_limit end)

			  when detect_flag = 'Y' then hai.fn_thousands_separator(coalesce(r.result_text,
			  		case when @limit_type = 'RL' then r.reporting_detection_limit
					when @limit_type = 'MDL' then r.method_detection_limit end))
			 end  + ' ' +  coalesce(interpreted_qualifiers,'')  + 
			 case when validated_yn = 'n' then coalesce ('[nv]','') else '' end 
			 as validated_result
			 ,approval_a
			,result_unit
			from dt_sample s
			inner join dt_test t on s.facility_id = t.facility_id and s.sample_id = t.sample_id
			inner join dt_result r on t.facility_id = r.facility_id and t.test_id = r.test_id
			inner join rt_analyte ra on r.cas_rn = ra.cas_rn
			inner join rt_matrix rm on s.matrix_code = rm.matrix_code

			inner join (select facility_id, compound_group, analytic_method from  [rpt].[fn_HAI_Get_CompoundGroups] (@facility_id, @compound_groups))gc
			on t.facility_id = gc.facility_id and t.analytic_method = gc.analytic_method
			

			where s.facility_id = @facility_id
			and s.task_code in (select task_code from rpt.fn_hai_get_taskcode(@facility_id, @task_codes))
			and t.lab_sdg in (select SDG from rpt.fn_hai_get_sdgs(@facility_id, @SDGs) )
			and s.sample_type_code in (select sample_type_code from rpt.fn_hai_get_sampletype(@facility_id, @sample_type))
			and result_type_code = 'trg'



		end
	end