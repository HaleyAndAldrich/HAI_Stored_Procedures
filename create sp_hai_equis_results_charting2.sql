USE [equis]
GO
/****** Object:  StoredProcedure [HAI].[sp_HAI_EQUIS_Results_Charting2]    Script Date: 1/6/2017 3:00:17 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO




ALTER procedure [HAI].[sp_HAI_EQUIS_Results_Charting2](
	 @facility_id int
	,@start_date datetime
	,@end_date datetime
	,@sample_type varchar (100)
	,@matrix_codes varchar (100)
	,@task_codes varchar (1000)
	,@location_groups varchar (1000)
	,@locations varchar (1000)
	,@analyte_groups varchar (2000)
	,@cas_rns varchar(2000)
	,@target_unit varchar(15)
	,@limit_type varchar (10)
	,@user_qual_def varchar (10)
	,@coord_type varchar(20)
	)

as 
begin

	
	declare @start_time datetime = getdate()
	declare @elapsed_time datetime
	declare @time_msg varchar (100)

	declare @params varchar(1000)
	SELECT @params =  ISNULL(@params,'') + chemical_name + '|' 
	from (
	select chemical_name from rt_analyte where cas_rn in (select cast(value as varchar) from fn_split(@cas_rns)))z

	set @params = left(@params,len(@params) -1)
	

	exec [hai].[sp_HAI_Get_Locs] @facility_id,@location_groups, @locations  --creates ##locs

	exec [hai].[sp_HAI_GetParams] @facility_id,@analyte_groups, @params --creates ##mthgrps


	set @elapsed_time = getdate() -@start_time
	set @start_Time = getdate()
	set  @time_msg = 'locs '  + convert(varchar,(@elapsed_Time) ,114)
	raiserror (@time_msg,0,1) with nowait	

	exec [hai].[sp_HAI_Get_Samples] @facility_id, @start_date, @end_date, @task_codes,@sample_type,@matrix_codes  --creates ##samples

	set @elapsed_time = getdate() -@start_time
	set @start_Time = getdate()
	set  @time_msg = 'samples '  + convert(varchar,(@elapsed_Time) ,114)
	raiserror (@time_msg,0,1) with nowait


	IF OBJECT_ID('tempdb..##results')IS NOT NULL DROP TABLE ##results

	

	Select
		s.facility_id,
		s.sample_id,
		t.test_id,
		s.sys_sample_code,
		s.sample_name,
		t.lab_sample_id,
		coalesce(s.sys_loc_code,'none') as sys_loc_code,
		coalesce(l.loc_name,'none') as loc_name,
		l.loc_type,
		coalesce(l.loc_report_order,'99') as loc_report_order,
		l.loc_group,
		s.sample_date  as sample_date_time,
		convert(varchar,s.sample_date,101)  as simple_date,
		s.duration,
		s.duration_unit,
		s.matrix_code,
		s.sample_type_code,
		s.sample_source,
		coalesce(s.task_code,'none') as task_code,
		s.start_depth,
		s.end_depth,
		s.depth_unit,
		t.analytic_method,
		t.leachate_method,
		t.dilution_factor,
		t.fraction ,
		t.test_type,
		coalesce(t.lab_sdg,'No_SDG')as lab_sdg,
		t.lab_name_code,
		t.analysis_date,
		ra.chemical_name,
		r.cas_rn,
		r.result_text,
		r.result_numeric,
		r.reporting_detection_limit,
		r.method_detection_limit,
		r.result_error_delta,
		case when r.detect_flag = 'N' then r.reporting_detection_limit else r.result_text end as lab_reported_result,
		r.result_unit as lab_reported_result_unit,
		r.detect_flag,
		r.reportable_result,
		r.result_type_code,
		r.lab_qualifiers,
		r.validator_qualifiers,
		r.interpreted_qualifiers,
		r.validated_yn,
		approval_code,
		approval_a,
		case 
			when r.interpreted_qualifiers is not null then r.interpreted_qualifiers
			when charindex('j',r.lab_qualifiers)> 0 and r.interpreted_qualifiers is null then 'J'
			when charindex('j',r.lab_qualifiers)= 0 and r.interpreted_qualifiers is null and r.detect_flag = 'N' then 'U' 
		end as qualifier,


		case 
			when r.detect_flag = 'N' and coalesce(@limit_type,'RL') = 'RL' then  --default to RL
			equis.significant_figures(equis.unit_conversion_result(reporting_detection_limit, r.result_unit,coalesce(@target_unit, r.result_unit),default,null, null,  null,  r.cas_rn,null),equis.significant_figures_get(reporting_detection_limit ),default)
			when r.detect_flag = 'N' and @limit_type = 'MDL' then 
			equis.significant_figures(equis.unit_conversion_result(method_detection_limit, r.result_unit,coalesce(@target_unit, r.result_unit),default,null, null,  null,  r.cas_rn,null),equis.significant_figures_get(method_Detection_limit ),default)
			when r.detect_flag = 'N' and @limit_type = 'PQL' then 
			equis.significant_figures(equis.unit_conversion_result(quantitation_limit, r.result_unit,coalesce(@target_unit, r.result_unit),default,null, null,  null,  r.cas_rn,null),equis.significant_figures_get(quantitation_limit ),default)
			when r.detect_flag = 'Y' then
			equis.significant_figures(equis.unit_conversion_result(r.result_numeric,r.result_unit,coalesce(@target_unit,r.result_unit), default,null, null,  null,  r.cas_rn,null),equis.significant_figures_get(coalesce(r.result_text,rpt.trim_zeros(cast(r.result_numeric as varchar)))),default) 
			end 
			as  result_value, 
				
			rpt.fn_HAI_result_qualifier (
				hai.fn_thousands_separator(
						equis.significant_figures(cast(
						
			--result value			
			case 
				when r.detect_flag = 'N' and coalesce(@limit_type,'RL') = 'RL' then  --default to RL
				equis.significant_figures(equis.unit_conversion_result(reporting_detection_limit, r.result_unit,coalesce(@target_unit, r.result_unit),default,null, null,  null,  r.cas_rn,null),equis.significant_figures_get(reporting_detection_limit ),default)
				when r.detect_flag = 'N' and @limit_type = 'MDL' then 
				equis.significant_figures(equis.unit_conversion_result(method_detection_limit, r.result_unit,coalesce(@target_unit, r.result_unit),default,null, null,  null,  r.cas_rn,null),equis.significant_figures_get(method_Detection_limit ),default)
				when r.detect_flag = 'N' and @limit_type = 'PQL' then 
				equis.significant_figures(equis.unit_conversion_result(quantitation_limit, r.result_unit,coalesce(@target_unit, r.result_unit),default,null, null,  null,  r.cas_rn,null),equis.significant_figures_get(quantitation_limit ),default)
				when r.detect_flag = 'Y' then
				equis.significant_figures(equis.unit_conversion_result(r.result_numeric,r.result_unit,coalesce(@target_unit,r.result_unit), default,null, null,  null,  r.cas_rn,null),equis.significant_figures_get(coalesce(r.result_text,rpt.trim_zeros(cast(r.result_numeric as varchar)))),default) 
			end 	
			
			as varchar), equis.significant_figures_get(coalesce(result_text, reporting_detection_limit)),default)),
			
			--nd flag
				case 
					when detect_flag = 'N' then '<' 
					when detect_flag = 'Y' and charindex(validator_qualifiers, 'U') >0 then '<'
					when detect_flag = 'Y' and charindex(interpreted_qualifiers, 'U') >0 then '<'
					else null 
				end,  
			
			--reporting qualifier	
			coalesce(case when r.interpreted_qualifiers is not null and charindex(',',r.interpreted_qualifiers) >0 then  left(r.interpreted_qualifiers, charindex(',',r.interpreted_qualifiers)-1)
				when r.interpreted_qualifiers is not null then r.interpreted_qualifiers
				when r.validator_qualifiers is not null then r.validator_qualifiers
				when detect_flag = 'N' and interpreted_qualifiers is null then 'U' 
				when validated_yn = 'N' and charindex('J',lab_qualifiers) >0 then 'J'
				else ''
				end, ''),  
				interpreted_qualifiers,
				@user_qual_def)  --how the user wants the result to look
			as Result_Qualifier,

	  
			coalesce(case when r.interpreted_qualifiers is not null and charindex(',',r.interpreted_qualifiers) >0 then  left(r.interpreted_qualifiers, charindex(',',r.interpreted_qualifiers)-1)
			when r.interpreted_qualifiers is not null then r.interpreted_qualifiers
			when r.validator_qualifiers is not null then r.validator_qualifiers
			when detect_flag = 'N' and interpreted_qualifiers is null then 'U' 
			when validated_yn = 'N' and charindex('J',lab_qualifiers) >0 then 'J'
			else ''
		end, '') as reporting_qualifier,

		coalesce(@target_unit, result_unit) as result_value_unit,
		case 
			when @limit_type  = 'rl' and reporting_detection_limit is not null then 'RL'
			when @limit_type = 'rl' and reporting_detection_limit is null and method_detection_limit is not null then '(MDL)'
			when @limit_type = 'mdl' and method_detection_limit is not null then 'MDL'
			when @limit_type = 'mdl' and method_detection_limit is null and reporting_detection_limit is not null then '(RL)'
		end as detection_limit_type,
		coord_type_code,
		x_coord,
		y_coord


	--into ##results 
	From dbo.dt_sample s
		inner join dt_test t on s.facility_id = t.facility_id and  s.sample_id = t.sample_id
		inner join dt_result r on t.facility_id = r.facility_id and t.test_id = r.test_id
		inner join rt_analyte ra on r.cas_rn = ra.cas_rn
		--inner join dt_location l on s.facility_id = l.facility_id and s.sys_loc_code = l.sys_loc_code

	inner join ##samples ss on s.facility_id = s.facility_id and s.sample_id = ss.sample_id
	inner join ##locs l on s.facility_id = l.facility_id and s.sys_loc_code = l.sys_loc_code
	inner join ##mthgrps mg on 
			t.facility_id = mg.facility_id 
			and t.analytic_method = mg.analytic_method 
			and r.cas_Rn = mg.cas_rn 
			and case when t.fraction = 'D' then 'D' else 'T' end =  mg.fraction 


		
	left join (select facility_id, sys_loc_code, coord_type_code,x_coord, y_coord 
				from dt_coordinate 
				where facility_id in (select facility_id from equis.facility_group_members(@facility_id)) and coord_type_code = @coord_type)c 
			on s.facility_id = c.facility_id and s.sys_loc_code = c.sys_loc_code


	Where
	(r.result_type_code = 'trg' or r.result_Type_code = 'fld')
	and (r.reportable_result like 'Y%')-- or r.reportable_result = 'y')
	
	and 
	(case  --filter out non-numeric values
		when result_text is not null then isnumeric(result_text) 
		when reporting_detection_limit is not null then isnumeric(reporting_detection_limit)
		else -1
		 end) <> 0

	--update result_qualifier
	--update ##results
	--set result_qualifier =
			--rpt.fn_HAI_result_qualifier (
			--hai.fn_thousands_separator(
			--		equis.significant_figures(cast(result_value as varchar), equis.significant_figures_get(coalesce(result_text, reporting_detection_limit)),default)),
					
			--case 
			--	when detect_flag = 'N' then '<' 
			--	when detect_flag = 'Y' and charindex(validator_qualifiers, 'U') >0 then '<'
			--	when detect_flag = 'Y' and charindex(interpreted_qualifiers, 'U') >0 then '<'
			--	else null 
			--end,  --nd flag
			--reporting_qualifier,  --qualifiers
			--interpreted_qualifiers,
			--@user_qual_def) --how the user wants the result to look


	set @elapsed_time = getdate() -@start_time
	set @start_Time = getdate()
	set  @time_msg = 'results '  + convert(varchar,(@elapsed_Time) ,114)
	raiserror (@time_msg,0,1) with nowait

	--ALTER TABLE ##results   
	--ADD CONSTRAINT PK_results PRIMARY KEY CLUSTERED (facility_Id, sample_id, test_id, cas_rn);  
	
	raiserror ('End make ##results',0,1) with nowait
		
    --select * from ##results

	set @elapsed_time = getdate() - @start_time
	set @start_Time = getdate()
	set @time_msg = 'results '  + convert(varchar,(@elapsed_Time) ,114)
	raiserror (@time_msg,0,1) with nowait

end

