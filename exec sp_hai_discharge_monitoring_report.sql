use equis

go

exec [HAI].[sp_hai_discharge_monitoring_report]

      153 --@facility_id int 
	 ,'2017'  --@event_year varchar (4000)
	 ,'1st quarter'  --@event_quarter varchar(4000)
	 ,'1/01/2017'  --@start_date datetime
	 ,'4/01/2017'  --@end_date datetime
	 ,'outfall 009'  --@locations varchar (2000)
	 ,null  --@location_groups varchar (2000)
	 ,'n'  --@sample_type_code varchar (100)
	 ,'mdl'  --@limit_type varchar (10)