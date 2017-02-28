USE [equis]
GO
/****** Object:  StoredProcedure [rpt].[sp_HAI_sample_parameters_xtab]    Script Date: 2/28/2017 3:50:41 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--Creates a crosstab of action levels to append to an EQuIS Results set
--created by Dan Higgins  8/20/2015

ALTER procedure  [rpt].[sp_HAI_sample_parameters_xtab] 
(
 @facility_id int ,
 @task_codes varchar (2000),
 @include_sample_params varchar (10) 
)
as
begin
if (select @include_sample_params) = 'Y'
	begin
		IF OBJECT_ID('tempdb..##sample_params') IS NOT NULL drop table ##sample_params
		declare @sample_params_list table(sample_params_name varchar(100) primary key)
		
		insert into @sample_params_list
		select distinct param_code  from dbo.dt_sample_parameter sp
		inner join dt_sample s on sp.facility_id = s.facility_id and sp.sys_sample_code =  s.sys_sample_code
		inner join rpt.fn_hai_get_taskcode (@facility_Id, @task_codes) t
			on s.facility_id = t.facility_id and s.task_code = t.task_code
		where param_code is not null
		
		declare @param_name varchar (100)
		declare @SQL_sp varchar (max) ='create table ##sample_params (facility_id1 int, sys_sample_code1 varchar(50),' + char(13)

		
		while (select count(*) from @sample_params_list) >0
		begin
			set @param_name = (select top 1 sample_params_name from @sample_params_list)
	
			set @SQL_sp = @SQL_sp +'[' + @param_name + '] varchar(100),' + char(13)

			
			delete @sample_params_list where sample_params_name = @param_name
		end

		
		set @SQL_sp = left(@SQL_sp,len(@SQL_sp) -2) + ')'
		exec (@SQL_sp)



		insert into ##sample_params
		exec [dbo].[sample_parameters_crosstab_HAI] @facility_id,null

		delete ##sample_params
		from ##sample_params sp
		left join (select s.facility_id, sys_sample_code, s.task_code  from dt_sample s
					inner join rpt.fn_hai_get_taskcode(@facility_id, @task_codes)t
					on s.facility_id = t.facility_id and s.task_code = t.task_code) s 
		on sp.facility_id1 = s.facility_id and sp.sys_sample_code1 =  s.sys_sample_code
		where s.sys_sample_code is  null

	end

end