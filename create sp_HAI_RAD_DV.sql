
  use equis
  go 

  set nocount on
  go

 alter procedure HAI.sp_HAI_RAD_DV (
  
   @facility_id int = 153
  ,@locations varchar (1000)
  ,@analyte_groups varchar (2000) --= 'SSFL RAD'
  ,@cas_rns varchar (1000) 
  ,@limit_type varchar (20) = 'rl'
  ,@target_unit varchar (20)
  )
  as
  begin
		if object_id('temp_db..##mthgrps') is not null drop table ##mthgrps
		exec [hai].[sp_HAI_GetParams] @facility_id,@analyte_groups, @cas_rns --creates ##mthgrps
  
		select * from ##mthgrps

		  select
		  sample_id
		  ,sample_date
		  ,chemical_name
		  ,[Primary Result]
		  ,[Primary Qual]
		  ,case when [primary TPU]  is not null then '+/-' + [primary TPU] else null end as [primary TPU]
		  ,case when [lab dup TPU] is not null then '+/-' + [lab dup TPU] else null end as [lab dup TPU]
		  ,square(cast([Primary TPU] as float)) + square(cast([lab dup TPU] as float)) as [LD Sum of SQs]
		  ,cast(sqrt(square(cast([Primary TPU] as float)) + square(cast([lab dup TPU] as float))) as decimal(10,2)) as [LD SQRT of Sum]
		  ,cast([Primary Result]/sqrt(square(cast([Primary TPU] as float)) + square(cast([lab dup TPU] as float))) as decimal (10,2)) as  [LD Stat_Error]
		  ,case when abs([Primary Result]/sqrt(square(cast([Primary TPU] as float)) + square(cast([lab dup TPU] as float)))) > 1.96 then 'J' else '--' end as [LD Qual]


		  from (
		  select
		   sample_id
		  ,sample_date
		  ,chemical_name
		  ,Max(case when sample_type_code = 'n' then converted_result  end) as 'Primary Result'
		  ,Max(case when sample_type_code = 'n' then reporting_qualifier  end) as 'Primary Qual'
		  ,Max(case when sample_type_code = 'n' then result_error_delta  end) as 'Primary TPU'
		  ,Max(case when sample_type_code = 'lr' then result_error_delta  end) as 'lab dup TPU'

		  from (
				  select 
				  coalesce(parent_sample_code, sys_sample_code) as sample_id
				  ,sample_date
				  ,chemical_name
				  ,sample_type_code
				  ,lab_sdg
				  ,result_error_delta
					,case 
						when r.detect_flag = 'N' and coalesce(@limit_type,'RL') = 'RL' then  --default to RL
							equis.significant_figures(equis.unit_conversion_result(coalesce(reporting_detection_limit,result_text), r.result_unit,coalesce(@target_unit, r.result_unit),default,null, null,  null,  r.cas_rn,null),equis.significant_figures_get(coalesce(reporting_detection_limit,result_text) ),default)
						when r.detect_flag = 'N' and @limit_type = 'MDL' then 
							equis.significant_figures(equis.unit_conversion_result(coalesce(method_detection_limit,result_text), r.result_unit,coalesce(@target_unit, r.result_unit),default,null, null,  null,  r.cas_rn,null),equis.significant_figures_get(coalesce(method_Detection_limit,result_text) ),default)
						when r.detect_flag = 'N' and @limit_type = 'PQL' then 
							equis.significant_figures(equis.unit_conversion_result(quantitation_limit, r.result_unit,coalesce(@target_unit, r.result_unit),default,null, null,  null,  r.cas_rn,null),equis.significant_figures_get(quantitation_limit ),default)
						when r.detect_flag = 'Y' then
							equis.significant_figures(equis.unit_conversion_result(r.result_numeric,r.result_unit,coalesce(@target_unit,r.result_unit), default,null, null,  null,  r.cas_rn,null),equis.significant_figures_get(coalesce(r.result_text,rpt.trim_zeros(cast(r.result_numeric as varchar)))),default) 
						end 
						as converted_result
	  
						,coalesce(case when r.interpreted_qualifiers is not null and charindex(',',r.interpreted_qualifiers) >0 then  left(r.interpreted_qualifiers, charindex(',',r.interpreted_qualifiers)-1)
						when r.interpreted_qualifiers is not null then r.interpreted_qualifiers
						when r.validator_qualifiers is not null then r.validator_qualifiers
						when detect_flag = 'N' and interpreted_qualifiers is null then 'U' 
						when validated_yn = 'N' and charindex('J',lab_qualifiers) >0 then 'J'
						else ''
					end, '') as reporting_qualifier
				  ,tba.test_batch_id
				  from dt_sample s 
				  inner join dt_test t on s.facility_id = t.facility_id and t.sample_id = s.sample_id
				  inner join dt_result r on t.facility_id = r.facility_id and t.test_id = r.test_id
				  inner join rt_analyte ra on r.cas_rn = ra.cas_rn
				  inner join (select rec_id, analytic_method, fraction, cas_rn ,parameter,grp_name, param_report_order, mag_report_order, default_units  from ##mthgrps) mg 
					on t.analytic_method = mg.analytic_method 
					and (case when t.fraction = 'D' then 'D' else 'T'end) = mg.fraction
					and mg.cas_rn = r.cas_Rn

				  inner join at_test_batch_assign tba
				   on t.facility_id = tba.facility_id and t.test_id = tba.test_id

				  where s.facility_id = @facility_id
				  and sample_type_code in ('n','fd','lcs','lcsd','ms','sd','lr','bs','bd','lb')
				  and tba.test_batch_type = 'analysis'
				  and year(sample_date) = 2017
				  )z
	
			group by   
			sample_id
		  ,sample_date
		  ,chemical_name
		  ) y
		  where [lab dup TPU] is not null
end