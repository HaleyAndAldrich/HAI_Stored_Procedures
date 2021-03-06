USE [equis]
GO
/****** Object:  StoredProcedure [rpt].[sp_HAI_PGE_TCLP]    Script Date: 1/6/2017 3:10:34 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

	create procedure [hai].[sp_HAI_PGE_TCLP]
	(
		  @facility_id int
		 ,@task_codes varchar(500)
		 ,@mth_grp varchar (500) 
		 ,@param varchar (1000)
		 ,@location_groups varchar (1000)
		 ,@locations varchar (500)
		 ,@sample_type varchar(20)
		 ,@matrix_codes varchar(100)	 
	)

	as
	begin
	declare @starttime datetime
	set @starttime = cast(getdate()  as datetime)

	
	----Need @facs to cross-query facilities
	--	declare @facs table (facility_id int, facility_code varchar(20))
	--	insert into @facs	select f.facility_id, f.facility_code
	--						from dt_facility f
	--						where facility_id in (select cast(value as int) from fn_split(@facility_id) )

	--creates ##mthgrps
	exec [hai].[sp_HAI_GetParams] @facility_id,@mth_grp, null 
	print 'Get Params done'
	print cast(getdate()  - @starttime as varchar)

begin try
	exec [hai].[sp_HAI_Get_Locs] @facility_id,@location_groups, @locations  --creates ##locs
	print 'Get Locs done'
end try
begin catch
	print 'Get Locs failed'
end catch
	print cast(getdate()   - @starttime as varchar)

	

	declare @leach_method table( analytic_method varchar (200),leachate_method varchar (200))

							
	--/*Get a list of samples and methods with Leachate*/
	declare @samps table (
	 facility_id int
	, sample_id int
	, test_id int
	, sample_name varchar (100)
	, analytic_method varchar (100)
	, leachate_method varchar (100)
	, cas_Rn varchar (30)
	)
	insert into @samps

	select 
	   s.facility_id
	 ,  s.sample_id
	 ,  t.test_id
	 , s.sample_name
	 ,  t.analytic_method
	 ,  t.leachate_method
	 , r.cas_Rn
	
	from dt_sample s 
	 inner join dt_test t on s.facility_id = t.facility_id and s.sample_id = t.sample_id
	 inner join dt_result r on t.facility_Id = r.facility_id and t.test_id = r.test_id
	where s.facility_id = @facility_id
	 and sample_source = 'field'
	 and matrix_code in (select matrix_code from rpt.fn_hai_get_matrix(@facility_id, @matrix_codes))
	 and leachate_method is not null
	 and (sys_sample_code like '%IDW%' or sys_loc_code like '%idw%')
	 and cas_Rn not like '57-12-5%'  --eleminate cyanide
	 and sample_name = '0463A008-IDW-021412'

	-- select * from @samps

	--/*Pulls all regular results for list above*/
	 insert into @samps
	 select distinct 
	  s.facility_id
	 , s.sample_id
	 , t.test_id
	 , s.sample_name
	 , t.analytic_method
	 , t.leachate_method
	 , r.cas_rn
	 from dt_sample s 
	 inner join dt_test t on s.facility_id = t.facility_id and s.sample_id = t.sample_id
	 inner join dt_result r on t.facility_Id = r.facility_id and t.test_id = r.test_id
	 inner join @samps sps on s.facility_id = sps.facility_id and s.sample_name = sps.sample_name
		and r.cas_rn = sps.cas_rn
	where s.facility_id  in (@facility_id) 
	 and sample_source = 'field'
	 and matrix_code in (select matrix_code from rpt.fn_hai_get_matrix(@facility_id, @matrix_codes))
	 and (s.sys_sample_code like '%IDW%' or sys_loc_code like '%idw%')
	 and s.sample_id not in (select distinct sample_id from @samps)
	 

	 select * from @samps

	print 'Samps Done'
	print cast(getdate()   - @starttime as varchar)
		
		--General Results Table
		declare @r table (
			facility_name varchar (100),
			sys_sample_code varchar (200),
			sample_name varchar(200),
			sample_depth varchar(20),
			sample_date datetime, 
			sys_loc_code varchar (200), 
			matrix_code varchar (20),
			chemical_name varchar (200), 
			cas_rn varchar (100),
			analytic_method varchar(200), 
			leachate_method varchar(200),
			detect_flag varchar (20),
			interpreted_qualifiers varchar(20),
			report_result varchar (200), 
			report_result_unit varchar(200),
			default_units varchar (20)
			)

		insert into @r
		select distinct
			case when r.facility_id = 47 then 'North Beach'
				when r.facility_id = 48 then 'Fillmore'
				else 'Unknown' end,
			r.sys_sample_code,
			r.sample_name,
			case 
				when start_depth is not null and end_depth is null then cast(start_depth as varchar)
				when start_depth is  null and end_depth is not null then cast(end_depth as varchar)
				when start_depth is not null and end_depth is not null then cast(start_depth as varchar)+ '-' + cast(end_depth as varchar)
			end as depth,
			sample_date,
			r.sys_loc_code,
			r.matrix_code,
			m.parameter,
			r.cas_rn,
			r.analytic_method,
			r.leachate_method,
			detect_flag,
			interpreted_qualifiers,
			converted_result,
			converted_Result_unit,
			coalesce(m.default_units, converted_result_unit) as default_units

		from rpt.fn_HAI_EQuIS_Results (@facility_id,null, null, null) r
			inner join ##locs l on r.facility_id = l.facility_id and r.sys_loc_code = l.sys_loc_code
			inner join ##mthgrps m 
				on r.facility_id  = m.facility_id 
					and r.cas_rn = m.cas_rn 
					and r.analytic_method = m.analytic_method 
					and r.fraction = m.fraction
					and right(r.converted_result_unit,1) =  right(coalesce(m.default_units,r.converted_result_unit),1)
			inner join @samps sps on r.facility_Id = sps.facility_id and r.sample_id = sps.sample_id  and r.cas_rn = sps.cas_rn

		where r.sample_source = 'field'
			and r.sample_type_code in (select sample_type_code from rpt.fn_hai_get_sampletype(@facility_id, @sample_type))
			and coalesce(r.task_code, 'none') in (select task_code from rpt.fn_hai_get_taskCode(@facility_id, @task_codes))
			--and (r.sys_sample_code like '%IDW%' or r.sys_loc_code like '%idw%')

		--select *  from @r
			
		update @r
		set report_Result = equis.significant_figures(
			equis.unit_conversion(report_result, report_result_unit,
			 case when right(report_result_unit,1) = 'l' then 'mg/l'
			 when right(report_result_unit,1) = 'g' then 'mg/kg'
			 end, default),
		equis.significant_figures_get(report_result), default)
		update @r
		set report_result =  case when detect_flag = 'N' then '<'+cast(report_result as varchar) else cast(report_result as varchar) end

		----select * from @r
		
		--ditch the word (free) from cyanide so it will pivot with the parent samples in the xtab below.
		update @r
		set chemical_name = 'Cyanide' ,cas_rn = '57-12-5'
		where chemical_name = 'Cyanide (free)'
		
		
		select
		r.facility_name,
		r.sample_name as [Sample ID],
		r.sys_loc_code as [Loc ID],
		convert(varchar,r.sample_date,101) as  [Date],
		coalesce(sample_depth,'--') as [Depth(feet)],
		r.chemical_name as Parameter,
		min(case when r.leachate_method is null then  coalesce(r.report_result,'') end) 
		+    coalesce(max(case  when c.res_count > 1 and r.leachate_method is null then '/'+coalesce(r.report_result,'')  else '' end ),'')  as 'Result (mg/Kg)',

		  coalesce(min(case when r.leachate_method ='SW1311' then coalesce(r.report_result,'') end )  
		+    coalesce(max(case  when l_mth.res_count > 2 and r.leachate_method ='SW1311' then '/'+coalesce(r.report_result,'')  else '' end ),''),'NA')  as 'TCLP (mg/L)',
 
		  coalesce(min(case when r.leachate_method ='CAWET' or leachate_method = 'method' then coalesce(r.report_result,'') end )  
		+    coalesce(max(case  when l_mth.res_count > 2 and (r.leachate_method ='CAWET' or leachate_method = 'method') then '/'+coalesce(r.report_result,'')  else '' end ),''),'NA')  as 'STLC (mg/L)',
 
		/*cyanide*/
		 -- coalesce(min(case when r.leachate_method ='SW9013' or leachate_method = 'tclp' then coalesce(r.report_result,'') end )  
		--+    coalesce(max(case  when l_mth.res_count > 2 and (r.leachate_method ='SW9013' or leachate_method = 'tclp') then '/'+coalesce(r.report_result,'')  else '' end ),''),'NA')  as 'SW9013 (mg/kg)'
  

		 --,c.res_count
		 --,l_mth.res_count
		 null as Exceed_Check
		from @r r
		left join 
				(select
				facility_name,
				sample_name,
				chemical_name,
				cas_rn,
				count(report_result) as res_count,
				matrix_code
				from @r
				where leachate_method is null
				group by facility_name,sample_name, chemical_name, cas_rn,matrix_code) c
		on r.sample_name = c.sample_name and r.cas_rn = c.cas_rn and r.matrix_code = c.matrix_code
		left join 
				(select
				facility_name,
				sample_name,
				chemical_name,
				cas_rn,
				count(report_result) as res_count,
				matrix_code
				from @r
				where leachate_method is not null
				group by facility_name,sample_name, chemical_name, cas_rn,matrix_code) l_mth
		on r.sample_name = l_mth.sample_name and r.cas_rn = l_mth.cas_rn and r.matrix_code = l_mth.matrix_code

		group by  r.facility_name,r.sample_name, r.sys_loc_code,r.sample_depth,r.sample_date,r.chemical_name,c.res_count,l_mth.res_count

		order by r.facility_name,r.sample_name, r.chemical_name, sample_depth

		

end