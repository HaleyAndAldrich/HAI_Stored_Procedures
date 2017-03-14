USE [EQuIS]
GO
/****** Object:  StoredProcedure [HAI].[sp_HAI_Get_Samples]    Script Date: 3/14/2017 8:10:26 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER procedure [HAI].[sp_HAI_Get_Samples]
(
 @facility_Id int,
 @start_date datetime ,
 @end_date datetime  ,
 @task_codes varchar (1000),
 @sample_type varchar (1000),
 @matrix_codes varchar (500)
)

as

IF OBJECT_ID('tempdb..##samples')IS NOT NULL DROP TABLE ##samples
create table ##samples
(
 facility_id int
,sample_id int
,PRIMARY KEY CLUSTERED (facility_id, sample_id)
)

begin
	
    insert into ##samples 
		select s.facility_id, sample_id 
		from equis.dbo.dt_sample s
		
		where s.facility_id = @facility_id
			and s.sample_type_code in (select sample_type_code from rpt.fn_hai_get_sampletype(@facility_id, @sample_type))
			and coalesce(s.task_code,'none') in (select task_code from rpt.fn_hai_get_taskCode(@facility_id, @task_codes))
			and s.matrix_code in (select matrix_code from rpt.fn_hai_get_matrix(@facility_id, @matrix_codes))
			and (cast(s.sample_date as datetime)>= @start_date and cast(s.sample_date as datetime) <= @end_date + 1)

end		