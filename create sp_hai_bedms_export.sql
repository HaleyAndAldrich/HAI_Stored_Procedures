USE [equis]
GO
/****** Object:  StoredProcedure [rpt].[sp_HAI_BEDMS_Export]    Script Date: 1/6/2017 2:51:49 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*updated from sp_hai_bedms_test on 6/15/2016*/
ALTER procedure [rpt].[sp_HAI_BEDMS_Export](
	 @facility_id int  
	,@rpt_type varchar(40)  
	,@location_groups varchar (2000)
	,@locations varchar (2000) 
	,@start_date datetime 
	,@end_date datetime 
	,@sample_type varchar (20)
	,@task_codes varchar (1000)
	,@matrix_codes varchar (500)
	,@mth_grp varchar(2000)
	,@param varchar (2000)
	,@target_unit varchar(100)
)
as 
begin

	declare @limit_type varchar (20) = 'RL'

	IF OBJECT_ID('tempdb..##sample')IS NOT NULL DROP TABLE ##sample
	create table ##sample 
	(
		facility_id int,
		sample_id int,
		test_id int,
		[Site] varchar (30),
		[Object Name] varchar (30),
		[Sample Name] varchar(30),

		[Parent Sample Name] varchar (30),
		
		[Sample Type] varchar (50),
		[Matrix Type] varchar (50),
		[Collection DateTime] datetime,
		[Sampling Event] varchar (100),
		[Top Depth] decimal(5,2),
		[Base Depth] decimal(5,2),
		[Depth Unit] varchar (50),
		ConsultantName varchar (50),

		Collector varchar (30),
		[Sampling Device] varchar (50),
		[COC Ref No] varchar (20),	
		[Lab Name] varchar (400),

		
		[Analysis Method] varchar (400),
		Filtered varchar(20),

		[Turnaround] int,
		Resuls_Due_DateTime datetime,
		Results_Received_DateTime datetime

		primary key clustered (facility_id, sample_id, test_id)

		)
	if @start_date is null
	Begin
		set @start_date = (select min(sample_date) 
		from equis.dbo.dt_sample 
		where sample_source = 'field' and facility_id = @facility_id)
	end

	if @end_Date is null
	Begin
		set @end_date = (select max(sample_date) from equis.dbo.dt_sample 
		where sample_source = 'field' and facility_id = @facility_id)
	end

	set @start_date = cast(CONVERT(varchar,@start_date,101)as DATE)
	set @end_date = CAST(convert(varchar, @end_date, 101) as date)



	exec [hai].[sp_HAI_GetParams] @facility_id, @mth_grp, @param --creates ##mthgrps

	exec [hai].[sp_HAI_Get_Locs] @facility_id,@location_groups, @locations  --creates ##locs
	
	Insert into ##sample

	Select distinct
		s.facility_id,
		s.sample_id,
		t.test_id,
		'SSFL', --as [Site],
		l.sys_loc_code, --as [Object Name],
		left(sys_sample_code,30), --as [Sample Name],
		parent_sample_code, --as [Parent Sample Name],
		bedms_samp_type.BEDMS_sample_type, --as [Sample Type],
		bedms_matrix.[matrix type], --as [Matrix Type],
		sample_date, --as [Collection DateTime],
		task_code, --as [Sampling Event],
		cast(s.start_depth as decimal (5,2)), --as [Top Depth],
		cast(s.end_depth as decimal (5,2)), --as [Base Depth,
		s.depth_unit, --as [Depth Unit],
		'Haley & Aldrich', --as ConsultantName,
		coalesce(fs.sampler,'--missing--'), --as Collector,
		coalesce(fs.equipment_desc,'--missing--'), --as [Sampling Device],
		coalesce(fs.chain_of_custody,fs.field_sdg,'--missing--'),
		coalesce(rc.company_name, '--Check--[' + coalesce(t.lab_name_code,'missing') + ']'), --as [Lab Name],
		coalesce(BEDMS_analysis_method.bedms_method, '--Check--[' + t.analytic_method + ']'), --as [Analysis Method],
		case when t.fraction = 'D' then 'Yes' else 'No' end, --as Filtered,
		t.turnaround_days, --'14', --as [Turnaround] 
		t.lab_report_due_date,
		t.lab_report_receipt_date

	From dt_sample s
			INNER JOIN dbo.dt_test t on s.facility_id = t.facility_id and s.sample_id = t.sample_Id
			inner join dbo.dt_result r on t.facility_id = r.facility_id and t.test_id = r.test_id

			left join ##locs l
					on s.facility_Id = l.facility_Id and s.sys_loc_code = l.sys_loc_code
			left join ##mthgrps m
					on s.facility_Id = m.facility_Id 
					and t.analytic_method = m.analytic_method 
					and r.cas_rn = m.cas_rn 
					and  (case when t.fraction = 'N' then 'T' else t.fraction end) = m.fraction


			left JOIN (Select fs.facility_id, fs.sample_id,fs.sampler, fs.sample_receipt_date, fs.chain_of_custody,fs.equipment_code,
						 e.equipment_desc, fs.field_sdg from dbo.dt_field_sample fs 
					left join dbo.dt_equipment e on fs.equipment_code = e.equipment_code) fs
					on s.facility_id = fs.facility_id and s.sample_id = fs.sample_id
					

			LEFT JOIN (select external_value BEDMS_sample_type, internal_value as sample_type_code
				from rt_remap_detail where remap_code = 'BEDMS' and external_field = 'BEDMS_samp_type') bedms_samp_type
					on s.sample_type_code = BEDMS_samp_type.sample_type_code

			LEFT JOIN (select external_value [Matrix Type], internal_value as matrix_code
				from rt_remap_detail where remap_code = 'BEDMS' and external_field = 'BEDMS_matrix')  bedms_matrix
					on s.matrix_code = bedms_matrix.matrix_code

			LEFT JOIN (select company_code, company_name 
				from dbo.rt_company where company_type = 'lab')rc 
					on t.lab_name_code = rc.company_code

			LEFT JOIN (select external_value BEDMS_method, internal_value as analytic_method 
				from rt_remap_detail where remap_code = 'BEDMS' and external_field = 'BEDMS_anl_mth') bedms_analysis_method
					on t.analytic_method = BEDMS_analysis_method.analytic_method
				
	WHERE 
	s.facility_id = @facility_id
	and (cast(s.sample_date as datetime) > = @start_date and cast(s.sample_date as datetime) <= @end_date +1)
	and s.matrix_code in (select matrix_code from rpt.fn_hai_get_matrix(@facility_id,@matrix_codes) )
	and coalesce(s.task_code,'none') in (select task_code from rpt.fn_hai_get_TaskCode(@facility_Id, @task_codes))
	
	
	if @rpt_type = '1 Sample Log' 
		begin
			begin try
				select distinct
				'SSFL' as [Site],
				[Object Name],
				[Sample Name],
				[Parent Sample Name],
				[Sample Type],
				[Matrix Type],
				[Collection DateTime],
				[Sampling Event],
				[Top Depth],
				[Depth Unit],
				ConsultantName,
				Collector,
				[Sampling Device],
				[COC Ref No],
				[Lab Name],
				[Analysis Method],
				Filtered,
				Turnaround				
				
				 from ##sample
				print 'Sample Log Exported' 
			end try
			begin catch
				select 'Sample Log Export Failed: ' + error_message()
			end catch
		end

	if @rpt_type = '3 Analytical Result EDD'
		begin 
			Begin try

			/*this procedure gets a list of lab_qualifier descriptions*/
			exec rpt.sp_HAI_BEDMS_lab_desc @facility_id, @start_date

				SELECT 
	
		
					'SSFL' as project_id,
					coalesce(rc.company_name, '--Check--') as [Lab Name],
					'Haley & Aldrich' as Consultant_id,
					s.sys_sample_code as [Sample Name],	
					s.sample_date as [Sample Date],
					coalesce(bedms_matrix.[Matrix Type], '--Check--') as [Matrix Type],
					cast(t.lab_sample_id as varchar) as [Lab Sample Name],
					coalesce(bedms_sample_type.lst, '--Check--') as [Lab Sample Type],
					coalesce(bedms_result_type.rst, '--Check--') as [Result Type],
					coalesce(cast(t.lab_report_receipt_date as varchar),'--missing--') as [Received DateTime],
					coalesce(lab_sdg, '--missing--') as [SDG Number],
					coalesce(fs.chain_of_custody,fs.field_sdg,'--missing--') as [COC Ref No] ,
					case when t.fraction = 'D' then 'Yes' else 'No' end as Filtered,
					coalesce(t.prep_date, t.analysis_date) as'Extraction Date',
					coalesce(t.prep_method,'none') as [Extraction Method],
					t.analysis_date as [Analysis DateTime],
					coalesce(bedms_compound_group.anl_grp, '--Check--') as [Analysis Group],

					coalesce(BEDMS_analysis_method.bedms_method, '--Check--(' + t.analytic_method + ')') as [Analysis Method],
					coalesce(bedms_parameter.parameter, '--Check--)' ) as Analyte,
					coalesce(bedms_parameter.bedms_cas,'--Check--(' + r.cas_rn + ')') as [Cas No],
					case 
						when r.detect_flag = 'N' and coalesce(@limit_type,'RL') = 'RL' then  --default to RL
						equis.significant_figures(equis.unit_conversion_result(r.reporting_detection_limit, r.result_unit,coalesce(@target_unit, r.result_unit),default,null, null,  null,  r.cas_rn),equis.significant_figures_get(r.reporting_detection_limit ),default)
						when r.detect_flag = 'N' and @limit_type = 'MDL' then 
						equis.significant_figures(equis.unit_conversion_result(r.method_detection_limit, r.result_unit,coalesce(@target_unit, r.result_unit),default,null, null,  null,  r.cas_rn),equis.significant_figures_get(r.method_Detection_limit ),default)
						when r.detect_flag = 'N' and @limit_type = 'PQL' then 
						equis.significant_figures(equis.unit_conversion_result(r.quantitation_limit, r.result_unit,coalesce(@target_unit, r.result_unit),default,null, null,  null,  r.cas_rn),equis.significant_figures_get(r.quantitation_limit ),default)
						when r.detect_flag = 'Y' then
						equis.significant_figures(equis.unit_conversion_result(r.result_numeric,r.result_unit,coalesce(@target_unit,r.result_unit), default,null, null,  null,  r.cas_rn),equis.significant_figures_get(coalesce(r.result_text,rpt.trim_zeros(cast(r.result_numeric as varchar)))),default) 
					end as [Result Value],
					coalesce(@target_unit, result_unit) as [Result Value Units],
					--r.detect_flag,
					--r.interpreted_qualifiers,
					case 
						when rq.qc_spike_status = '*' then 'QC'	
						when charindex('UJ',r.interpreted_qualifiers) >0 then 'UJ'
						when charindex('U',r.interpreted_qualifiers)>0  then 'U'
						when charindex('J',r.interpreted_qualifiers)> 0 then 'J'
						when r.interpreted_qualifiers = 'R' then 'R'
						when r.interpreted_qualifiers = 'B' then 'J'
						when r.result_type_code = 'TIC' then 'TIC'
						when r.interpreted_qualifiers is null and r.detect_flag = 'N' then 'U'
						else '(' +r.interpreted_qualifiers + ')'
					end as [Project Qualifier Code],
					r.lab_qualifiers as [Lab Qualifier Code],
					##t.qual_desc as [Lab Qualifier Description],  --grabs a list of lab_qualifier descriptions
					case when charindex('Q',s.sample_type_code) = 0  and cast(r.reporting_detection_limit as varchar) is not null  then 'RDL' end  as [DL Type 1],
					case when charindex('Q',s.sample_type_code) = 0 then cast(r.reporting_detection_limit as varchar) end as [DL Value 1],
					case when charindex('Q',s.sample_type_code) = 0 and r.reporting_detection_limit is not null then cast(r.detection_limit_unit as varchar) end as [DL Units 1],
					case when charindex('Q',s.sample_type_code) = 0 and r.result_error_delta is not null then 'Counting Error +/-' end as [DL Type 2],
					case when charindex('Q',s.sample_type_code) = 0 and r.result_error_delta is not null  then cast(r.result_error_delta as varchar) end as [DL Value 2],
					case when charindex('Q',s.sample_type_code) = 0 and r.result_error_delta is not null then cast(r.detection_limit_unit as varchar) end as [DL Units 2],
					case when charindex('Q',s.sample_type_code) = 0 and r.method_detection_limit is not null then 'MDL - Method Detection Limit' end as [DL Type 3],
					cast(r.method_detection_limit as varchar) as [DL Value 3],
					case when r.method_detection_limit is not null then r.detection_limit_unit end as [DL Units 3],
					cast(rq.qc_spike_ucl as varchar) [Upper Limit],
					cast(rq.qc_spike_lcl as varchar) [Lower Limit],
					t.lab_report_receipt_date [Report Date],
					coalesce(cast(t.lab_sdg as varchar),'--missing--') as [Lab Batch No],
					cast(t.dilution_factor as varchar) as [Dilution Factor],
					cast(r.remark as varchar) as [comment],
					cast(case when (s.matrix_code = 'SE' or s.matrix_code = 'SO') and t.percent_moisture <> 'NA' and t.percent_moisture is not null then 100 - t.percent_moisture end as varchar) as [Percent Solids],				
					cast(case when charindex('Val_Level:',r.remark) > 0 then 'Level ' + substring(r.remark,charindex('Val_Level:',r.remark)+10 ,3) end as varchar) as [QC Level],
					s.parent_sample_code as [Parent Sample Name]--,

				FROM  dbo.dt_sample s
					
				INNER JOIN dbo.dt_field_sample fs
					on s.facility_id = fs.facility_id and s.sample_id = fs.sample_id

				INNER JOIN dbo.dt_test t 
					on s.facility_id = t.facility_id and
					s.sample_id = t.sample_id 
					
				INNER JOIN dt_result r
					on t.facility_id = r.facility_id and
					 t.test_id = r.test_id 

				inner join ##locs l
						on s.facility_Id = l.facility_Id and s.sys_loc_code = l.sys_loc_code

				inner join ##mthgrps m
						on s.facility_Id = m.facility_Id 
						and t.analytic_method = m.analytic_method 
						and r.cas_rn = m.cas_rn 
						and  (case when t.fraction = 'N' then 'T' else t.fraction end) = m.fraction
					 
				left join dt_result_qc rq
					on r.facility_id = rq.facility_id and r.test_id = rq.test_id and r.cas_rn = rq.cas_rn

				INNER Join rt_sample_type rst
					on s.sample_type_code = rst.sample_type_code
				
				left join ##t on r.lab_qualifiers =  ##t.lab_qualifiers


					LEFT JOIN (select external_value [Matrix Type], internal_value as matrix_code
						from rt_remap_detail where remap_code = 'BEDMS' and external_field = 'BEDMS_matrix')  bedms_matrix
							on s.matrix_code = bedms_matrix.matrix_code
					LEFT JOIN (select company_code, company_name 
						from dbo.rt_company where company_type = 'lab')rc 
							on t.lab_name_code = rc.company_code
					LEFT JOIN (select external_value LST, internal_value as sample_source 
						from rt_remap_detail where remap_code = 'BEDMS' and external_field = 'BEDMS_sample_type') bedms_sample_type
							on s.sample_source = bedms_sample_type.sample_source
					LEFT JOIN (select external_value RST, internal_value as sample_source 
						from rt_remap_detail where remap_code = 'BEDMS' and external_field = 'BEDMS_test_type') bedms_result_type
							on t.test_type = bedms_result_type.sample_source
					LEFT JOIN (select external_value anl_grp, internal_value as analytic_method 
						from rt_remap_detail where remap_code = 'BEDMS' and external_field = 'BEDMS_Compound_Group') bedms_compound_group
							on t.analytic_method = bedms_compound_group.analytic_method
					LEFT JOIN (select external_value BEDMS_method, internal_value as analytic_method 
						from rt_remap_detail where remap_code = 'BEDMS' and external_field = 'BEDMS_anl_mth') bedms_analysis_method
							on t.analytic_method = BEDMS_analysis_method.analytic_method
					LEFT JOIN (select external_value BEDMS_cas, internal_value as cas_rn, remark as parameter 
						from rt_remap_detail where remap_code = 'BEDMS' and external_field = 'BEDMS_cas_rn') bedms_parameter
							on r.cas_rn = BEDMS_parameter.cas_rn
					LEFT JOIN (select external_value BEDMS_sample_type, internal_value as sample_type_code, remark as parameter 
						from rt_remap_detail where remap_code = 'BEDMS' and external_field = 'BEDMS_samp_type') bedms_samp_type
							on s.sample_type_code = BEDMS_samp_type.sample_type_code
					LEFT JOIN (select external_value BEDMS_lab_qualifier_desc, internal_value as lab_qualifiers
						from rt_remap_detail where remap_code = 'BEDMS' and external_field = 'BEDMS_Lab_Qual_desc') bedms_qual_desc
							on r.lab_qualifiers = bedms_qual_desc.lab_qualifiers
							
				WHERE s.facility_id = @facility_id 
				and (cast(s.sample_date as datetime) > = @start_date and cast(s.sample_date as varchar ) <= @end_date -1)


				print 'BEDMS Analytical EDD Exported.'
			end try
			begin catch
				Select 'BEDMS Analytical EDD Export Failed: ' + error_message()
			end catch
		end

		if @rpt_type = '2 Field Monitoring EDD'
		begin

			begin try
				select
				
				'SSFL' as [Site],
				fr.sys_loc_code as [Object Name],
				fr.sample_date as [Monitoring Date Time],
				fr.task_code as [Monitoring Event],
				fr.chemical_name as [Monitoring Parameter],
				fr.converted_result as [Parameter Value],
				fr.converted_result_unit as [Parameter Unit],
				fr.interpreted_qualifiers as [Monitoring Qualifier],
				--eqr.remark as [Remark],
				samp.[Collector] as [Recorded By]


				FROM rpt.fn_hai_equis_results 
				 (@facility_id ,@target_unit, null, null)fr

				INNER JOIN ##sample samp on fr.facility_Id = samp.facility_id
					and fr.sample_id = samp.sample_id
					and fr.test_id = samp.test_id

				inner join ##locs l
					on fr.facility_Id = l.facility_Id and fr.sys_loc_code = l.sys_loc_code

				where 
				--(cast(sample_date as datetime) > = @start_date and cast(sample_date as varchar ) <= @end_date -1)
                (chemical_name like '%field%' or chemical_name like '%flow%')

				print 'Field Monitoring BEDMS EDD Exported.'
			end try
			begin catch
				Select 'Field Monitoring BEDMS EDD Failed: ' + error_message()
			end catch

		end


IF OBJECT_ID('tempdb..##sample')IS NOT NULL DROP TABLE ##sample
IF OBJECT_ID('tempdb..##locations')IS NOT NULL DROP TABLE ##locations
IF OBJECT_ID('tempdb..##mthgrps')IS NOT NULL DROP TABLE ##mthgrps
END