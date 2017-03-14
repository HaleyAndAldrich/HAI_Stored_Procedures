USE [EQuIS]
GO
/****** Object:  StoredProcedure [HAI].[sp_HAI_Get_SDGs]    Script Date: 3/14/2017 8:10:54 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER procedure [HAI].[sp_HAI_Get_SDGs] (
	@facility_id int, 
	@SDGs varchar(1000))

 as
  begin
	IF OBJECT_ID('tempdb..##sdgs')IS NOT NULL DROP TABLE ##sdgs

	create table ##sdgs
	(facility_id int
	,test_id int
	,lab_sdg varchar (200)
	,PRIMARY KEY CLUSTERED (facility_id, test_id)
	)


  if (select count(@SDGs)) >0
	begin
		insert into ##sdgs
		select t.facility_id, t.test_id ,t.lab_sdg
		from dbo.dt_test t
		inner join ##samples s on t.facility_id = s.facility_id and t.sample_id = s.sample_id
		where lab_sdg in (select cast(value as varchar(200))from equis.split(@SDGs))
	end

	if (select count(*) from ##sdgs) = 0
	begin
		insert into ##sdgs
		select distinct
			t.facility_Id, t.test_id, coalesce(t.lab_sdg, 'No_SDG')
			from dt_test t
		inner join ##samples s on t.facility_id = s.facility_id and t.sample_id = s.sample_id
	end
return
end