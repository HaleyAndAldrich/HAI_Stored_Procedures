USE [EQuIS]
GO
/****** Object:  StoredProcedure [HAI].[sp_HAI_EQuIS_Results_TCLP]    Script Date: 6/2/2017 12:12:56 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER procedure [HAI].[sp_HAI_EQuIS_Results_TCLP](
	 
	 @facility_id int  = 47
	,@start_date datetime =  '1/1/2000'
	,@end_date datetime  = '6/1/2070'
	,@sample_type varchar (100) = 'n'
	,@matrix_codes varchar (100)
	,@task_codes varchar (1000) = 'potrero-so'
	,@location_groups varchar (1000)
	,@locations varchar (1000)
	,@sdg varchar (1000)
	,@analyte_groups varchar(2000)= 'PGE-Potrero-DispSO-Standard'
	,@cas_rns varchar (2000)
	,@target_unit varchar(15)
	,@limit_type varchar (10)
	,@action_level_codes varchar (500)
	,@user_qual_def varchar (10)
	,@show_val_yn varchar (10) 
	,@coord_type varchar(20)
	)

as 
begin

	

	exec [hai].[sp_HAI_Get_Locs] @facility_id,@location_groups, @locations  --creates ##locs
	--raiserror ('locs',0,1) with nowait	

	exec [hai].[sp_HAI_Get_Samples] @facility_id, @start_date, @end_date, @task_codes,@sample_type,@matrix_codes  --creates ##samples
	--raiserror ('samples',0,1) with nowait	

	exec [hai].[sp_HAI_GetParams] @facility_id,@analyte_groups, @cas_rns --creates ##mthgrps

	exec [hai].[sp_HAI_Get_Tests] @facility_id, @sdg  --creates ##tests  --depends on sp_hai_get_samples and sp_hai_getparams



	
/********Get Action Levels*******************************************************/
	if object_id('tempdb..#ActionLevel_table') is not null Drop table #ActionLevel_table
	if object_id('tempdb..#al_params') is not null Drop table #al_params

	--declare @action_level_codes varchar (500)
	--=  'PGE-SL-POTRERO-10xSTLC|PGE-SL-POTRERO-20xTCLP|PGE-SL-POTRERO-STLC|PGE-SL-POTRERO-TCLP|PGE-SL-POTRERO-TTLC'

	create table #al_params (chemical_name varchar (40), cas_rn varchar(20), al_unit varchar (10), al_method varchar (30))
	insert into #al_params
	select distinct chemical_name, param_code,unit , analytic_method
	from dt_action_level_parameter alp
	inner join rt_analyte ra on alp.param_code = ra.cas_rn
	where action_level_code in (select cast(value as varchar(30)) from fn_split(@action_level_codes))

	

	create table #ActionLevel_table (action_level_code varchar (30))
	insert into #ActionLevel_table
	select cast(value as varchar(30)) from fn_split(@action_level_codes)

	declare @SQL1 varchar (max)
	declare @AL varchar (30)

	set @SQL1 = 'Select  ap.cas_rn as al_cas_rn, al_unit, al_method, ' + char(10) 
	while (select Count(*) from #ActionLevel_table) > 0
	begin
		select @AL = (select top 1 action_level_code from #ActionLevel_table)
	
		Set @SQL1 = @SQL1 +
		--'max(case when action_level_code = ' + '''' +  @AL + '''' + ' then action_level_code end) as [' +  @AL + '_AL], '+ char(10) +
		--'max(case when action_level_code = ' + '''' + @AL + '''' + ' then param_code end) as [' +  @AL + '_cas],' + char(10) +
		--'max(case when action_level_code = ' + '''' + @AL + '''' + ' then  remark end) as [' +  @AL + '_param],' + char(10) +
		'max(case when action_level_code = ' + '''' + @AL + '''' + ' then  action_level end) as [' +  @AL + '_al_value],' + char(10) 
		--'max(case when action_level_code = ' + '''' + @AL + '''' + ' then unit end) as [' +  @AL + '_al_unit],' + char(10) 

		delete #ActionLevel_table where action_level_code = @AL
	end
	
	Set @SQL1 = rtrim(ltrim(@SQL1))
	Set @SQL1 = left(@SQL1,len(@SQL1) -2)
	Set @SQL1 = @SQL1 +
	char(10) + 'into ##AL_TCLP from #al_params ap left join dt_action_level_parameter alp on ap.cas_rn = alp.param_code and alp.unit = ap.al_unit  and alp.analytic_method = ap.al_method' + char(10) +
	'where action_level_code in  ' + char(10) +
	'(select * From #actionlevel_table)' + char(10) + 
	'group by chemical_name, cas_rn, al_unit, al_method'

	insert into #ActionLevel_table
	select cast(value as varchar(30)) from fn_split(@action_level_codes)
	exec( @SQl1)

	
/******************End Get Action Levels************************************************************/


	IF OBJECT_ID('tempdb..##results')IS NOT NULL DROP TABLE ##results
	--raiserror ('drop ##results',0,1) with nowait

	Select
		s.facility_id,
		s.sample_id,
		t.test_id,
		s.sys_sample_code,
		s.sample_name,
		t.lab_sample_id,
		fs.field_sdg,
		l.subfacility_code,
		sf.subfacility_name,
		coalesce(s.sys_loc_code,'none') as sys_loc_code,
		coalesce(l.loc_name,'none') as loc_name,
		l.loc_type,
		coalesce(locs.loc_report_order,'99') as loc_report_order,
		locs.loc_group,
		s.sample_date,
		s.duration,
		s.duration_unit,
		s.matrix_code,
		s.sample_type_code,
		s.sample_source,
		coalesce(s.task_code,'none') as task_code,
		s.start_depth,
		s.end_depth,
		s.depth_unit,
		g.compound_group,
		magm.grp_name as parameter_group_name,
		magm.parameter as mth_grp_parameter,
		magm.param_report_order,
		magm.mag_report_order,
		magm.default_units,
		t.analytic_method,
		case 
			when t.leachate_method = 'SW1311' then 'TCLP'
			when t.leachate_method = 'CAWET' then 'STLC'
			else 'NA'
		end as leachate_method
		,
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
		case when r.detect_flag = 'N' then r.reporting_detection_limit else r.result_text end as result,
		r.result_unit as reported_result_unit,
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
				equis.significant_figures(equis.unit_conversion_result(coalesce(reporting_detection_limit,result_text), r.result_unit,coalesce(magm.default_units, r.result_unit),default,null, null,  null,  r.cas_rn,null),equis.significant_figures_get(coalesce(reporting_detection_limit,result_text) ),default)
			when r.detect_flag = 'N' and @limit_type = 'MDL' then 
				equis.significant_figures(equis.unit_conversion_result(coalesce(method_detection_limit,result_text), r.result_unit,coalesce(magm.default_units, r.result_unit),default,null, null,  null,  r.cas_rn,null),equis.significant_figures_get(coalesce(method_Detection_limit,result_text) ),default)
			when r.detect_flag = 'N' and @limit_type = 'PQL' then 
				equis.significant_figures(equis.unit_conversion_result(quantitation_limit, r.result_unit,coalesce(magm.default_units, r.result_unit),default,null, null,  null,  r.cas_rn,null),equis.significant_figures_get(quantitation_limit ),default)
			when r.detect_flag = 'Y' then
				equis.significant_figures(equis.unit_conversion_result(r.result_numeric,r.result_unit,coalesce(magm.default_units,r.result_unit), default,null, null,  null,  r.cas_rn,null),equis.significant_figures_get(coalesce(r.result_text,rpt.trim_zeros(cast(r.result_numeric as varchar)))),default) 
			end 
			as report_result_numeric, 

			'--------------' as report_result,
	  
			coalesce(case when r.interpreted_qualifiers is not null and charindex(',',r.interpreted_qualifiers) >0 then  left(r.interpreted_qualifiers, charindex(',',r.interpreted_qualifiers)-1)
			when r.interpreted_qualifiers is not null then r.interpreted_qualifiers
			when r.validator_qualifiers is not null then r.validator_qualifiers
			when detect_flag = 'N' and interpreted_qualifiers is null then 'U' 
			when validated_yn = 'N' and charindex('J',lab_qualifiers) >0 then 'J'
			else ''
		end, '') as reporting_qualifier,
		alt.*,

		coalesce(magm.default_units, result_unit) as report_result_unit,
		@limit_type as detection_limit_type,
		coord_type_code,
		x_coord,
		y_coord,
		eb.edd_date, 
		eb.edd_user,
		eb.edd_file 

	into ##results
	From dbo.dt_sample s
		inner join dt_test t on s.facility_id = t.facility_id and  s.sample_id = t.sample_id
		inner join dt_result r on t.facility_id = r.facility_id and t.test_id = r.test_id
		inner join rt_analyte ra on r.cas_rn = ra.cas_rn
		inner join dt_location l on s.facility_id = l.facility_id and s.sys_loc_code = l.sys_loc_code

		--inner join ##samples ss on s.facility_id = s.facility_id and s.sample_id = ss.sample_id
		--inner join ##tests ts on t.facility_id = ts.facility_id and ts.sample_id = t.sample_id and t.test_id = ts.test_id and r.cas_rn = ts.cas_rn
		inner join ##locs locs on s.facility_id = locs.facility_id and s.sys_loc_code = locs.sys_loc_code
		inner join ##mthgrps magm on magm.analytic_method = t.analytic_method and magm.cas_rn = r.cas_rn and magm.fraction = (case when t.fraction = 'N' then 'T' else t.fraction end) and right(magm.default_units, 1) = right(r.result_unit, 1) 
		
		left join ##AL_TCLP ALT on r.cas_rn = ALT.al_cas_rn and t.analytic_method = alt.al_method and right(r.result_unit,1) = right(alt.al_unit,1)
		left join dt_subfacility sf on l.facility_Id = sf.facility_id and l.subfacility_code = sf.subfacility_code
		left join dt_field_sample fs on s.facility_id = fs.facility_id and s.sample_id = fs.sample_id
		left join st_edd_batch eb on r.ebatch = eb.ebatch
		left join (select facility_id, sys_loc_code, coord_type_code,x_coord, y_coord 
					from dt_coordinate 
					where facility_id in (select facility_id from equis.facility_group_members(@facility_id)) and coord_type_code = @coord_type)c 
				on s.facility_id = c.facility_id and s.sys_loc_code = c.sys_loc_code


		left join (select member_code ,rgm.group_code as compound_group from rt_group_member rgm
				inner join rt_group rg on rgm.group_code = rg.group_code
				 where rg.group_type = 'compound_group')g
		on t.analytic_method = g.member_code

	Where
	(r.result_type_code = 'trg' or r.result_Type_code = 'fld')
	and (r.reportable_result ='yes' or r.reportable_result = 'y')
	and s.sample_source ='field'
	and s.task_code in (select cast(value as varchar (20)) from fn_split( @task_codes))
	and 
	(case  --filter out non-numeric values
		when result_text is not null then isnumeric(result_text) 
		when reporting_detection_limit is not null then isnumeric(reporting_detection_limit)
		else -1
		 end) <> 0

	update ##results
	set report_result = 
	 coalesce(cast(rpt.fn_HAI_result_qualifier ( 
		report_result_numeric, 
			case 
				when detect_flag = 'N' then '<' 
				when detect_flag = 'Y' and charindex(validator_qualifiers, 'U') >0 then '<'
				when detect_flag = 'Y' and charindex(interpreted_qualifiers, 'U') >0 then '<'
				else null 
			end,  --nd flag
			reporting_qualifier,  --qualifiers
			interpreted_qualifiers,
			@user_qual_def) --how the user wants the result to look
			+ case when @show_val_yn = 'Y'  and (validated_yn = 'N' or validated_yn is null) then '[nv]' else '' end  as varchar), null)
			

	raiserror ('End make ##results',0,1) with nowait

	select * from  ##results
	order by chemical_name

	if object_id('tempdb..#ActionLevel_table') is not null Drop table #ActionLevel_table
	if object_id('tempdb..#al_params') is not null Drop table #al_params
	if object_id('tempdb..##AL_TCLP') is not null Drop table  ##AL_TCLP
end
