USE [EQuIS]
GO
/****** Object:  StoredProcedure [HAI].[sp_hai_discharge_monitoring_report]    Script Date: 3/23/2017 2:11:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


	ALTER procedure [HAI].[sp_hai_discharge_monitoring_report]
	(
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

	/*Get Rain Events*/
	declare @rain_events table (facility_id int, sys_sample_code varchar (40), param_value varchar (100), event_year varchar (40), event_quarter varchar (40), rain_event varchar (100))
		insert into @rain_events
			select 
				sp.facility_Id
				, sp.sys_sample_code
				, param_value
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
						when charindex('11thrainevent',replace(param_value, ' ', '')) > 0 then '11th Rain Event'
						when charindex('12thrainevent',replace(param_value, ' ', '')) > 0 then '12th Rain Event'
						when charindex('13thrainevent',replace(param_value, ' ', '')) > 0 then '13th Rain Event'
						when charindex('14thrainevent',replace(param_value, ' ', '')) > 0 then '14th Rain Event'
						when charindex('15thrainevent',replace(param_value, ' ', '')) > 0 then '15th Rain Event'
						when charindex('16thrainevent',replace(param_value, ' ', '')) > 0 then '16th Rain Event'
						else 'not identified'
					end as rain_event
				from dt_sample_parameter sp
				where facility_id = @facility_id
				and param_code = 'event' 
				and param_value like '%'+ @event_year+ '%' and param_value like '%'+ @event_quarter +'%'


	exec hai.sp_HAI_Get_Locs @facility_id, @location_groups, @locations

			declare @sample_plan table (
			facility_id int
		    ,method_analyte_group_code varchar (50)
			,cas_rn varchar (20)
			,chemical_name varchar (50)
			,planned_sample_date varchar(30)
			,sample_type varchar (20)
			,report_order varchar(10)
			,fraction  varchar (10)
			,dmr_Sample_Freq varchar(40)
			,sys_loc_code varchar (30)
			,limit varchar(20)
			,limit_unit varchar (10)
			)

		insert into @sample_plan
			select 
				facility_id
				 ,method_analyte_group_code
				,cas_rn
				,chemical_name
				,null
				,sample_type
				,case when len (report_order) = 1 then '0'+ isnull(report_order,'') else report_order end as report_order
				,case when sp.fraction = 'N' then 'T' else sp.fraction end
				,dmr_Sample_Freq
				,sp.sys_loc_code
				,limit
				,limit_unit
			from 
			dt_hai_stormwater_sample_plan sp
			where 
			 sys_loc_code in (select cast(value as varchar (20)) from fn_split(@locations))
			 --and (chemical_name = '1,2-Dichlorobenzene')
			 
		declare @results table(
				 sys_sample_code varchar (50)
				,sys_loc_code varchar (50)
				,sample_datetime datetime
				,sample_date_range varchar (100)
				,event_year varchar (400)
				,event_quarter varchar (100)
				,rain_event varchar (200)
				,sample_type_code varchar (10)
				,sample_type varchar (20)
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
			insert into @results
				select 
					r.sys_sample_code
					,r.sys_loc_code
					,sample_date 
					,null
					,e.event_year
					,e.event_quarter
					,e.rain_event
					,r.sample_type_code
					,case				
						when charindex('grab_extra',r.sys_sample_code) > 0 then 'Grab'
						when charindex('grab',r.sys_sample_code) > 0 then 'Grab'
						when charindex('comp_f',r.sys_Sample_code) >  0 then 'Comp'
						when charindex('comp',r.sys_Sample_code) >  0 then 'Comp'
						else 'Unknown'
						end as Sample_Type
					,r.analytic_method
					,case when r.fraction = 'N' then 'T' else r.fraction end
					,r.chemical_name
					,r.cas_rn
					,detect_flag
					,validator_qualifiers
					,interpreted_qualifiers
					,reporting_qualifier
					,approval_a
					,converted_result
					,converted_result_unit
				from rpt.fn_hai_equis_results(@facility_Id, null, @limit_type, null)r
				
				left join @rain_events e
				on r.facility_id =e.facility_id and r.sys_sample_code = e.sys_sample_code
					
				inner join (select sample_type_code from rpt.fn_HAI_Get_SampleType (@facility_id, @sample_type_code)) st on r.sample_type_code = st.sample_type_code
				inner join ##locs l on r.facility_id = l.facility_id and r.sys_loc_code = l.sys_loc_code

			where sample_source = 'field'
					and (result_type_code = 'trg' or result_type_code = 'fld')
					and reportable_result like 'y%'
					and (cast(r.sample_date as datetime)>= @start_date and cast(r.sample_date as datetime) <= @end_date + 1)
					--and (r.chemical_name like '%human%')

			update @results
			set converted_result = equis.unit_conversion(converted_result,converted_result_unit, samplan.limit_unit,9999999)
			from @results r
				left join @sample_plan samplan on 
				    r.sys_loc_code = samplan.sys_loc_code 
					and r.cas_rn = samplan.cas_rn 
					and r.fraction = samplan.fraction
					and r.sample_type = samplan.sample_type

	/*Add Human Bacteria- not included in initial result set because rpt.fn_hai_equis_results excludes non numeric results for unit conversion calcs*/
		insert into @results
			select
				 s.sys_sample_code
				,s.sys_loc_code
				,s.sample_date
				,null
				,e.event_year
				,e.event_quarter
				,e.rain_event
				,s.sample_type_code
				,case				
					when charindex('grab_extra',s.sys_sample_code) > 0 then 'Grab'
					when charindex('grab',s.sys_sample_code) > 0 then 'Grab'
					when charindex('comp_f',s.sys_Sample_code) >  0 then 'Comp'
					when charindex('comp',s.sys_Sample_code) >  0 then 'Comp'
					else 'Unknown'
					end as Sample_Type
				,t.analytic_method
				,case when t.fraction = 'N' then 'T' else t.fraction end
				,ra.chemical_name
				,r.cas_rn
				,r.detect_flag
				,r.validator_qualifiers
				,r.interpreted_qualifiers
				,coalesce(case when r.interpreted_qualifiers is not null and charindex(',',r.interpreted_qualifiers) >0 then  left(r.interpreted_qualifiers, charindex(',',r.interpreted_qualifiers)-1)
						when r.interpreted_qualifiers is not null then r.interpreted_qualifiers
						when r.validator_qualifiers is not null then r.validator_qualifiers
						when detect_flag = 'N' and interpreted_qualifiers is null then 'U' 
						when validated_yn = 'N' and charindex('J',lab_qualifiers) >0 then 'J'
						else ''
					end, '') as reporting_qualifier
				,r.approval_a
				,case when detect_flag = 'Y' then 'Present' else 'Absent' end as result_text
				,r.result_unit

			from dt_result r
			inner join dt_test t on r.facility_id = t.facility_id and r.test_id = t.test_id
			inner join dt_sample s on t.facility_id = s.facility_id and t.sample_id = s.sample_id
			inner join rt_analyte ra on r.cas_rn = ra.cas_rn

			inner join (select sample_type_code from rpt.fn_HAI_Get_SampleType (@facility_id, @sample_type_code)) st on s.sample_type_code = st.sample_type_code
			inner join ##locs l on s.facility_id = l.facility_id and s.sys_loc_code = l.sys_loc_code
			left join @rain_events e
				on s.facility_id =e.facility_id and s.sys_sample_code = e.sys_sample_code
			where sample_source = 'field'
				and (result_type_code = 'trg' or result_type_code = 'fld')
				and reportable_result like 'y%'
				and (cast(s.sample_date as datetime)>= @start_date and cast(s.sample_date as datetime) <= @end_date + 1)

				and r.cas_rn like 'human%'
				print 'bact added'



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
	
	
	
	select 
		method_analyte_group_code
		,sp.sys_loc_code sp_sys_loc_code
		,sp.chemical_name as sp_chemical_name
		,report_order
		,sys_sample_code
		,sp.sample_type
		,r.sample_type
		,r.sys_loc_code as result_sys_loc_code
		,case when r.fraction = 'D' then 'Dissolved' 
			when r.fraction = 'T' then 'Total' 
			when r.fraction = 'N' then 'Total'
			end as Total_or_Dissolved
		,r.chemical_name as result_chemical_name
		,sample_datetime
		,sample_date_range
		,event_year
		,event_quarter
		,rain_event
		,limit
		,case 
			when converted_result is not null and converted_result not like 'absent' and converted_result not like 'present' then
				case 
					when detect_flag = 'n' then 'ND ' else '' end + rpt.fn_hai_result_qualifier(converted_result, case when detect_flag = 'N' then '<' end,reporting_qualifier, interpreted_qualifiers, '< # Q') 
					when detect_flag = 'N' and converted_result is null then 'ND'
			else converted_result
		end as Report_Result
		,converted_result_unit as report_result_unit
		,dmr_Sample_Freq
		, case 
			when reporting_qualifier is not null and approval_a is not null and approval_a <> '--' then reporting_qualifier + ' ('+approval_a+ ')' 
			when  approval_a = '--' then '--' 
			when reporting_qualifier is not null and approval_a is  null then reporting_qualifier
			when sys_sample_code is not null and reporting_qualifier is null then null
		 end as report_result_qualifier 
		,approval_a as validation_approval_code 

	from @sample_plan sp 

		left join @results r
			on sp.cas_rn = r.cas_rn and sp.fraction =  r.fraction  and sp.sys_loc_code = r.sys_loc_code and sp.sample_type = r.sample_type and r.sample_type = sp.sample_type
	where r.sys_loc_code is not null
	
	order by sp.method_analyte_group_code, sp.sys_loc_code,  report_order, sp.fraction desc

end