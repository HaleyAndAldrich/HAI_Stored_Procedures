
use equis
go

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

/*Summarizes field samples received by sample date , matrix,and lab SDG*/

	Alter procedure hai.sp_hai_sdg_summary 
	(
	 @facility_id int 
	 ,@task_codes varchar (2000)
	 )

	 as begin
		
		/*Optional filter by task code */
		declare @tasks_table table (task_code varchar (30))

		if (select count(@task_codes)) = 0
		begin 
			insert into @tasks_table
			select distinct task_code from dt_sample where facility_id = @facility_id and sample_source = 'field'
		end
		if (select count(@task_codes)) > 0
		begin
			insert into @tasks_table
			select cast(value as varchar (30)) from fn_split(@task_codes)
		end


		select 
		 convert(varchar, min(sample_date), 101) as sample_date
		 ,coalesce(convert(varchar,eb.edd_date, 101), '--')  as edd_load_date
		,coalesce(t.lab_sdg, 'no data') as lab_sdg
		,count(s.sample_id) as sample_count
		,matrix_desc as matrix

		from dt_sample s
		left join (select distinct facility_id, sample_id, lab_sdg from dt_test where facility_id = @facility_id)t
		 on s.facility_id = t.facility_id and s.sample_id = t.sample_id
		left join st_edd_batch eb on s.ebatch = eb.ebatch
		inner join rt_matrix rm on s.matrix_code = rm.matrix_code
		inner join  @tasks_table tt on coalesce(s.task_code,'none') = coalesce(tt.task_code,'none')
		where s.facility_id = @facility_id
		and s.sample_source = 'field'
		group by convert(varchar,eb.edd_date, 101), lab_sdg,matrix_desc

	end

	