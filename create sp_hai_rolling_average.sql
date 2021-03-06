USE [equis]
GO
/****** Object:  StoredProcedure [HAI].[sp_hai_rolling_average]    Script Date: 1/6/2017 3:18:02 PM ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER ON
GO

	ALTER procedure [HAI].[sp_hai_rolling_average](

		 @facility_id int = 1830934
		,@chemical_name varchar(2000) --= 'arsenic|cadmium'
		,@location_groups varchar (2000) --= '14AAP-PM10TF|16AAP-PM10TF|18AAP-PM10TF|23AAP-PM10TF|26AAP-PM10TF'
		,@locations varchar (2000)
		,@sample_type_codes varchar (200)
		,@matrix_codes varchar (200)
		,@start_date datetime --= '6/30/2015'
		,@analytic_methods varchar (2000)
		,@limit_type	varchar (20)
		,@date_interval int
		,@sample_interval int)

	as
	Begin


			exec hai.sp_hai_get_locs @facility_id, @location_groups, @locations


			if (select count(@analytic_methods)) = 0
			begin
				set @analytic_methods = 'none_selected' 
			end

		IF OBJECT_ID('tempdb..#r')IS NOT NULL DROP TABLE #r
		create table #r
			(
			sys_sample_code varchar (50)
			,sys_loc_code varchar (40)
			,matrix_code varchar (10)
			,sample_type_code varchar (10)
			,sample_date datetime
			,chemical_name varchar (100)
			,cas_rn varchar (30)
			,analytic_method varchar (50)
			,limit_type varchar (10)
			,reporting_detection_limit varchar (20)
			,method_detection_limit varchar (20)
			,converted_result_05ND float
			,converted_result float
			,converted_result_unit varchar (10)
			,detect_flag varchar (10)
			,PRIMARY KEY CLUSTERED ( sys_sample_code, cas_Rn,analytic_method)
			)
			
		insert into #r
			select 
				 r.sys_sample_code
				,r.sys_loc_code
				,r.matrix_code
				,r.sample_type_code
				,sample_date
				,r.chemical_name
				,r.cas_Rn
				,r.analytic_method
				,@limit_type limit_type
				,reporting_detection_limit
				,method_detection_limit
				--1/2 detection limit if result is ND
				,case when detect_flag = 'N' then  cast(0.5 as float) * converted_result else converted_result end as converted_result_05ND
				,dbo.fn_significant_figures(converted_result,dbo.fn_significant_figures_get(converted_result), default) as converted_result					
				,converted_Result_unit
				,detect_flag
				from rpt.fn_hai_equis_results (1830934, null,@limit_type, null) r
				inner join ##locs l on r.facility_id = l.facility_id and r.sys_loc_code = l.sys_loc_code
				inner join rpt.fn_hai_get_matrix (@facility_id, @matrix_codes) m on r.facility_id = m.facility_id and r.matrix_code = m.matrix_code
				inner join rpt.fn_hai_get_sampletype (@facility_id, @sample_type_codes) st on r.facility_id = st.facility_id and r.sample_type_code = st.sample_type_code
				where r.sys_loc_code in (select sys_loc_code from ##locs)
				and chemical_name in (select cast(value as varchar (100)) from dbo.fn_split (@chemical_name))
				and reportable_result like 'y%'
				and result_type_code = 'trg'
				and case when @analytic_methods not like 'none_selected' then analytic_method else 'none_selected' end in (select cast(value as varchar (100)) from dbo.fn_split(@analytic_methods))

		insert into #r
		Select 
			 sys_sample_code_fd
			,sys_loc_code
			,matrix_code
			,'N' as sys_sample_code		
			,sample_date
			,chemical_name
			,cas_rn
			,analytic_method	
			,limit_type	
			,reporting_detection_limit
			,method_detection_limit		
			,Collocated as converted_result_05ND
			,converted_result
			,converted_Result_unit
			,detect_flag
		
		from (
			select
			 'FD_replace_Null-N_' + sys_loc_code as sys_sample_code_fd
			 ,sys_loc_code
			 ,matrix_code
			 --,sample_type_code
			--,max(case when sample_type_code = 'N' then sys_sample_code end ) as sys_sample_code_N
			,cast(convert(varchar,sample_date,101)  as datetime) as sample_date
			,chemical_name
			,cas_rn
			,analytic_method		
			,@limit_type as limit_type	
			,null as reporting_detection_limit
			,null as method_detection_limit
			,max(case when sample_type_code = 'N' then converted_result_05ND  end) as 'null_check'
			,max(case when sample_type_code = 'N' then converted_result_05ND  end) as 'Primary'
			,max(case when sample_type_code = 'FD' then converted_result_05ND end) as 'Collocated'
			,null as converted_result
			,converted_Result_unit
			,detect_flag
			from #R
			where sys_loc_code like '%26%'
			group by sys_loc_code, chemical_name,cas_rn,analytic_method,cast(convert(varchar,sample_date,101) as datetime)
				,matrix_code,converted_result_unit, detect_flag
			)z
			where null_check is null
			
			--select * from #r


		if (select count(*) from #r) >0
		begin try

		--Make date buckets for rolling average
			declare @date_hash table (id int identity(1,1), start_date datetime, end_date datetime)


			while @start_date + @sample_interval < getdate() or (select count(*) from @date_hash) >1000
				begin
					insert into @date_hash
					select @start_date, @start_date + @date_interval 
					--print @start_date

					set @start_date = @start_date + @sample_interval 

				end

			select
				sys_loc_code
				,sample_type_code
				,chemical_name
				,analytic_method
				,matrix_code
				,start_date
				,end_date
				,cast(round(avg(cast(converted_result_05ND as float)),5) as decimal(10,5)) as [avg_05ND]
				,cast(round(avg(cast(converted_result_05ND as float)),5) as decimal(10,5)) as [avg]
				,count(converted_result_05ND ) as record_count

				from (

					select 
					 r.sys_loc_code
					,r.matrix_code
					,r.sample_type_code
					,dh.id
					,sample_date
					,dh.Start_Date
					,dh.End_Date
					,r.chemical_name
					,r.analytic_method
					,@limit_type limit_type
					,reporting_detection_limit
					,method_detection_limit
					,converted_result_05ND
					,dbo.fn_significant_figures(converted_result,dbo.fn_significant_figures_get(converted_result), default) as converted_result	
					,converted_Result_unit
					from #r r
					inner join @date_hash dh on r.sample_date >= start_date and r.sample_date <= end_date +1
					
				)z
				group by sys_loc_code,chemical_name,analytic_method,matrix_code,sample_type_code
				, start_date, end_date

	end try
	begin catch
		Select 'No Results Found'
	end catch
	
	End

