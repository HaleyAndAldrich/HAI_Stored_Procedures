USE [EQuIS]
GO
/****** Object:  StoredProcedure [HAI].[sp_hai_discharge_monitoring_report]    Script Date: 3/7/2017 5:47:47 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


	ALTER procedure [HAI].[sp_hai_discharge_monitoring_report](
	  @facility_id int 
	 ,@event_year varchar (4000)
	 ,@event_quarter varchar(4000)
	 ,@start_date datetime
	 ,@end_date datetime
	 ,@locations varchar (2000)
	 ,@location_groups varchar (2000)
	 ,@sample_type_code varchar (100)
	 ,@limit_type varchar (10)
	 
	)
	as
	begin

	declare @min_date as datetime
	declare @max_date as datetime
	declare @loc as varchar (50)

	exec hai.sp_HAI_Get_Locs @facility_id, @location_groups, @locations

			declare @sample_plan table (
		     method_analyte_group_code varchar (50)
			, cas_rn varchar (20)
			, chemical_name varchar (50)
			, planned_sample_date varchar(30)
			, report_order varchar(10)
			, fraction  varchar (10)
			,dmr_Sample_Freq varchar(40)
			,sys_loc_code varchar (30)
			)

		insert into @sample_plan
		select 
			 method_analyte_group_code
			, cas_rn
			, chemical_name
			, null
			, report_order
			, fraction 
			,dmr_Sample_Freq
			,sp.sys_loc_code
			from 
			hai.dt_stormwater_sample_plan sp
			where 
			 sys_loc_code in (select cast(value as varchar (20)) from fn_split(@locations))
			 --and (chemical_name = 'mercury' or chemical_name = 'aluminum')

		declare @results table(
				 sys_sample_code varchar (50)
				,sys_loc_code varchar (50)
				,sample_datetime datetime
				,sample_date_range varchar (100)
				,event_year varchar (400)
				,event_quarter varchar (100)
				,rain_event varchar (200)
				,sample_type_code varchar (10)
				,analytic_method varchar (40)
				,fraction varchar (10)
				,chemical_name varchar (50)
				,cas_rn varchar (30)
				,detect_flag varchar (10)
				,validator_qualifiers varchar(10)
				,interpreted_qualifiers varchar(10)
				,reporting_qualifier varchar(10)
				,approval_a varchar(10)
				,converted_result varchar(40)
				,converted_result_unit varchar(10)
					)
			--insert into @results
				select 
					r.sys_sample_code
					,r.sys_loc_code
					,sample_date 
					,null
					,e.event_year
					,e.event_quarter
					,e.rain_event
					,r.sample_type_code
					,r.analytic_method
					,case when r.fraction = 'N' then 'T' else r.fraction end
					,chemical_name
					,r.cas_rn
					,detect_flag
					,validator_qualifiers
					,interpreted_qualifiers
					,reporting_qualifier
					,approval_a
					,converted_result
					,converted_result_unit
				from rpt.fn_hai_equis_results(@facility_Id, null,@limit_type, null)r
				
				inner join (select facility_Id, sys_sample_code, param_value
					,case when charindex(@event_year,param_value) > 0 then @event_year end as event_year
					,case when charindex(@event_quarter,param_value) > 0 then @event_quarter end as event_quarter
					,case 
						when charindex('1strainevent',replace(param_value, ' ', '')) > 0 then '1st Rain Event'
						when charindex('2ndrainevent',replace(param_value, ' ', '')) > 0 then '2nd Rain Event'
						when charindex('3rdrainevent',replace(param_value, ' ', '')) > 0 then '3rd Rain Event'
						when charindex('4thrainevent',replace(param_value, ' ', '')) > 0 then '4th Rain Event'
						when charindex('5thrainevent',replace(param_value, ' ', '')) > 0 then '5th Rain Event'
						when charindex('6thrainevent',replace(param_value, ' ', '')) > 0 then '6th Rain Event'
						when charindex('7thrainevent',replace(param_value, ' ', '')) > 0 then '7th Rain Event'
						when charindex('8thrainevent',replace(param_value, ' ', '')) > 0 then '8th Rain Event'
						when charindex('9thrainevent',replace(param_value, ' ', '')) > 0 then '9th Rain Event'
						when charindex('10thrainevent',replace(param_value, ' ', '')) > 0 then '10th Rain Event'
						else 'not identified'
					end as rain_event
					from dt_sample_parameter
					where param_value like '%'+ @event_year+ '%' and param_value like '%'+ @event_quarter +'%')e
				on r.facility_id =e.facility_id and r.sys_sample_code = e.sys_sample_code
					
				inner join (select sample_type_code from rpt.fn_HAI_Get_SampleType (@facility_id, @sample_type_code)) st on r.sample_type_code = st.sample_type_code
				inner join ##locs l on r.facility_id = l.facility_id and r.sys_loc_code = l.sys_loc_code
			where sample_source = 'field'
					and result_type_code = 'trg'
					and reportable_result like 'y%'
					and (cast(r.sample_date as datetime)>= @start_date and cast(r.sample_date as datetime) <= @end_date + 1)
					--and (chemical_name = 'mercury' or chemical_name = 'aluminum')

			
			set @min_date = (select min(sample_datetime )   from @results)
			set @max_date = (select max(sample_datetime )   from @results)
			update @results
			set sample_date_range =  
			--select 
			date_range
			--, ev.sys_loc_code, ev.rain_event
			from 
			(select
			sys_loc_code,rain_event
			,convert(varchar,min(sample_datetime ),101) + ' - ' + convert(varchar,max(sample_datetime),101) as date_range
			from @results
			group by rain_event, sys_loc_code)ev
			inner join @results r
			on ev.rain_event = r.rain_event and ev.sys_loc_code = r.sys_loc_code

	declare @rain_event table (rain_event varchar (100), sample_date_range varchar (100))
	insert into @rain_event
	select distinct rain_event, sample_date_range from @results


	insert into @results(sys_loc_code, sample_date_range, chemical_name, cas_rn, fraction,rain_event, converted_result_unit)
	select  distinct z.sys_loc_code, z.sample_date_range, z.chemical_name, z.cas_rn, z.fraction, z.rain_event, z.converted_result_unit
	from(
	select  distinct sp.sys_loc_code, rv.sample_date_range, sp.chemical_name, sp.cas_rn, sp.fraction, rv.rain_event, r.converted_result_unit
	from @sample_plan sp 
	cross apply @rain_event rv
	left join (select distinct cas_Rn, converted_result_unit from @results)r
	on sp.cas_rn = r.cas_rn
	)z
	left join @results r
		on z.sys_loc_code = r.sys_loc_code and z.cas_rn = r.cas_rn and z.fraction = r.fraction and z.rain_event = r.rain_event
	where r.chemical_name is null

	update @sample_plan
	set report_order =  case when len(report_order) = 1 then '0' + report_order else report_order end
	

	--select * from @results where sys_sample_code is null
	
	select 
		method_analyte_group_code
		,sp.sys_loc_code sp_sys_loc_code
		,sp.chemical_name as sp_chemical_name
		,report_order
		,sys_sample_code
		,r.sys_loc_code as result_sys_loc_code
		,case when r.fraction = 'D' then 'Dissolved' 
			when r.fraction = 'T' then 'Total' 
			when r.fraction = 'N' then 'Total'
			--else 'check'
			end as Total_or_Dissolved
		,r.chemical_name as result_chemical_name
		,sample_datetime
		,sample_date_range
		, event_year
		,event_quarter
		,rain_event
		,case 
			when charindex('grab',sys_sample_code) > 0 then 'Grab'
			when charindex('comp',sys_Sample_code) >  0 then 'Composite'
			when sys_sample_code is null then 'ANR'
			else 'Unknown'
			end as Sample_Type

		,converted_Result
		,case 
			when converted_result is null then 'ANR'
			when converted_result is not null then
				case when detect_flag = 'n' then 'ND ' else '' end + rpt.fn_hai_result_qualifier(converted_result, case when detect_flag = 'N' then '<' end,reporting_qualifier, interpreted_qualifiers, '< # Q') 
				end as Report_Result
		,converted_result_unit as report_result_unit
		,dmr_Sample_Freq
		, case 
			when reporting_qualifier is not null and approval_a is not null and approval_a <> '--' then reporting_qualifier + ' ('+approval_a+ ')' 
			when  approval_a = '--' then '--' 
			when reporting_qualifier is not null and approval_a is  null then reporting_qualifier
			when sys_sample_code is not null and reporting_qualifier is null then null
			when sys_sample_code is null then 'ANR'
		 end as report_result_qualifier 
		,approval_a as validation_approval_code 

	from @sample_plan sp 

		left join @results r
			on sp.cas_rn = r.cas_rn and sp.fraction =  r.fraction  and sp.sys_loc_code = r.sys_loc_code 
			order by sp.method_analyte_group_code, sp.sys_loc_code,  report_order, sp.fraction desc
end