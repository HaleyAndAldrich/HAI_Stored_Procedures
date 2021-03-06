USE [EQuIS]
GO
/****** Object:  StoredProcedure [rpt].[sp_HAI_WQX_Export]    Script Date: 2/22/2017 3:47:24 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [rpt].[sp_HAI_WQX_Export]
	(@facility_id int,
	 @location_groups varchar (2000),
	 @locations varchar (2000),
	 @sample_type varchar (20),
	 @task_codes varchar (1000),
	 @start_date datetime,
	 @end_date datetime,
	 @mthgrps varchar(2000),
	 @params varchar (2000),
	 @fraction varchar(10) = null,
	 @matrix_codes varchar (500),
	 @target_unit varchar(100),
	 @limit_type varchar (10) = 'RL',
	 @user_qual_def varchar (10) = '# Q',
	 @show_val_yn varchar (10) = 'N',
	 @rpt_flag varchar (20),    -- Determine if exporting WQX_Location, WQX_Result or WQX_Weather
	 @coord_type varchar(20) = null  	
	)
AS

--Check @rpt_flag

if	(Select LEN(@rpt_flag)) is null
	begin
		Select 'Pick a Report type' as 'Error'
	end

----pick samples/locs to report
	declare @samp_select table( 
	 facility_id int
	,sample_id int 
	,sys_sample_code varchar (200)
	,task_code varchar (100)
	,sys_loc_code varchar (50)
	,org_code varchar (100)
	,matrix varchar (20)
	,WQX_Exported varchar (20)
	 unique(sample_id, sys_loc_code))
	
	
begin try
	insert into @samp_select

	select distinct 
	 s.facility_id
	,s.sample_id 
	,s.sys_sample_code
	,s.task_code
	,s.sys_loc_code 
	,f.program_code 
	,s.matrix_code 
	,coalesce(lp.param_value ,'No')
	from equis.dbo.dt_sample s 
		inner join equis.dbo.dt_location l on s.facility_id = l.facility_id and s.sys_loc_code = l.sys_loc_code 
		inner join equis.dbo.dt_facility f on l.facility_id = f.facility_id
		left join (select facility_id, sys_loc_code, param_value from  
				equis.dbo.dt_location_parameter where param_code = 'WQX_exported')lp on l.facility_id = lp.facility_id and l.sys_loc_code = lp.sys_loc_code 
		inner join (select facility_id, sys_loc_code from rpt.fn_HAI_Get_Locs (@facility_id, @location_groups, @locations))locs on s.facility_id = locs.facility_id and s.sys_loc_code = locs.sys_loc_code
		inner join (select facility_id, task_code from rpt.fn_HAI_Get_TaskCode (@facility_id, @task_codes)) tasks on s.facility_id = tasks.facility_id and s.task_code = tasks.task_code
	where 	
		s.facility_id = @facility_id 
		and s.sample_date>= @start_date
		and s.sample_date <= @end_date
		and (sample_source is null or sample_source = 'field')
		and sample_type_code = 'N'  --MAA 11/24/2015 Does not include Field Dups
		--and matrix_code in (select cast(value as varchar (10)) from fn_split(@matrix_codes))
		and l.status_flag = 'A'
end try

begin catch
	select 'Error in SampSelect' as Err_Loc,ERROR_MESSAGE () as error_desc,ERROR_LINE() as error_line
end catch

raiserror('samples done' ,0,1) with nowait

--create list of Location IDs
	declare @loc_ids table (
		 WQX_loc_id varchar (15)
		,loc_name varchar (255)
		,Org_code varchar (100)
		,facility_id varchar (100)
		,sys_loc_code varchar (50)
		,WQX_exported varchar (40)
	)
	
begin try	
	insert into @loc_ids
	select distinct
	  left(ss.sys_loc_code,15) --case when len(wqxl.WQX_loc_id  ) >15 then 'Loc ID too long' else coalesce(wqxl.WQX_loc_id,'missing') end
	 ,l.loc_name
	 ,ss.org_code
	 ,ss.facility_id
	 ,ss.sys_loc_code
	 ,ss.WQX_Exported

	from  @samp_select ss
	left join (select facility_id, sys_loc_code,loc_name from equis.dbo.dt_location where facility_id = @facility_id )l
	on ss.facility_id = l.facility_id and ss.sys_loc_code = l.sys_loc_code
	--print 'Loc IDs Done'
end try
begin catch
	select 'Error in insert to LocIds' as Err_Loc,ERROR_MESSAGE () as error_desc,ERROR_LINE() as error_line
end catch

raiserror('distinct locations done' ,0,1) with nowait

declare @WQX_locs table
	(
	--used just for cross checking and lookups in EQuIS
	 facility_id int
	,sys_loc_code varchar (50)

	--beginning of WQX Location EDD fields
	,MonitoringLocationIdentifier varchar (35)  --WQX location ID --R
	,MonitoringLocationName varchar (255)      --R
	,MonitorinLocationType varchar (45)      --R

	,MonitoringLocationLatitude varchar (200)      --R
	,MontitoringLocationLongitude varchar (200)      --R

    ,HorizontalCoordinateSystemDatumName Varchar (6)  --'WGS84'       --R
    ,HorizontalCollectionMethodName varchar (150)  --from remap_detail      --R
    
	)

	raiserror('created WQX table' ,0,1) with nowait

begin try --Get Location information. Used later in getting results

	insert into @WQX_Locs
	select distinct
     l.facility_id
    ,l.sys_loc_code
    
    ,li.WQX_loc_id  --Location ID
    ,li.loc_name   --location name
    ,lt.Wqx_loc_Type --WQX location_type ;lookup from rt_remap_detail
  
    ,coalesce(c.y_coord ,'--check dt_coordinate.y_coord--')    -- Latitude_Decimal_Degrees 
    ,coalesce(c.x_coord ,'-check dt_coordinate.x_coord---')    -- Longitude_Decimal_Degrees 

    ,case when c.y_coord is not null then coalesce(c.horz_datum, '{Unknown}') else null end  -- Horizontal_Coordinates_Ref --Added c.horz_datum_code, Changed from WGS84 to UNKWN MAA 11/23/2015--
    ,case when c.y_coord is not null then coalesce(c.Horz_Method,'{Unknown}')  else null end  -- Horizontal_Coordinate_Collection_Method int --Changed from GPS-Unknown to Unknown MAA 11/23/2015--
    
	from equis.dbo.dt_location l
		inner join equis.dbo.dt_sample s on l.facility_id = s.facility_id and l.sys_loc_code = s.sys_loc_code
		
		inner join equis.dbo.dt_facility f on s.facility_id = f.facility_id
		
		inner join @samp_select ss on ss.sample_id = s.sample_id and ss.facility_id = s.facility_id
		
		inner join @loc_ids li on li.sys_loc_code = l.sys_loc_code and li.facility_id = l.facility_id
		
		left join  (select facility_id , sys_loc_code, coord_Type_code, x_coord, y_coord,horz_accuracy_value,hm.external_value as Horz_Method,hd.external_value as Horz_Datum
			from equis.dbo.dt_coordinate c 
		
			left join  (select external_value, internal_value from equis.dbo.rt_remap_detail rd where rd.remap_code = 'EPA_WQX' and external_field = 'WQX_Horz_mth') hm
				on c.horz_collect_method_code = hm.internal_value 				
			left join (select external_value, internal_value from equis.dbo.rt_remap_detail rd where rd.remap_code = 'EPA_WQX' and external_field = 'WQX_Horz_datum') hd				on c.horz_datum_code = hd.internal_value 
				where c.coord_type_code = 'LATLONG')c on l.facility_id = c.facility_id and l.sys_loc_code = c.sys_loc_code
			
		left join (select internal_value as EQ_loc_Type, external_value as 'WQX_loc_Type' from equis.dbo.rt_remap_detail rd  --Loc Type
		where rd.external_field = 'WQX_loc_Type')lt on l.loc_type = lt.EQ_loc_Type 

		raiserror('Location output table done' ,0,1) with nowait
end try

begin catch
	select 'Error in Location Output' as Err_Loc,ERROR_MESSAGE () as error_desc,ERROR_LINE() as error_line
end catch


----Begin Location Export
if @rpt_flag = 'Location' 
	begin
	
	 Select 
	 MonitoringLocationIdentifier 
	,MonitoringLocationName 
	,MonitorinLocationType 
	,MonitoringLocationLatitude 
	,MontitoringLocationLongitude 
    ,HorizontalCoordinateSystemDatumName 
    ,HorizontalCollectionMethodName
	from @wqx_locs
	end
	
	raiserror('Done Exporting Locations' ,0,1) with nowait
----*********************************************************************************************
----Begin Results Export
If @rpt_flag = 'Result'
begin
	Begin try
		declare @WQX_Result table  (
		 facility_id int
		,EQ_sample_ID varchar(200)   --R
		,ProjectIdentifier varchar(35)   --Rmaa  ProjectIdentifier
		,MonitoringLocationIdentifier varchar (35)   --R   MonitoringLocationIdentifier
		,ActivityIdentifier varchar (35)	   --Rmaa   --ActivityIdentifier  (task code)
		,ActivityTypeCode varchar(70)   --Rmaa   --ActivityTypeCode
		,ActivityMediaName varchar(200)   --Rmaa    ActivityMediaName (matrix)
		,ActivityStartDate varchar(10)   --Rmaa    --ActivityStartDate
		,CharacteristicName varchar(120)  --R
		,ResultDetectionConditionText varchar(100) --R
		,ResultMeasureValue varchar(100)  --Cmaa
		,ResultMeasureUnitCode varchar(120)  --Cmaa
		,ResultMeasureQualifierCode varchar(50)  --O MAA Need to investigate
		,ResultSampleFractionText   varchar(250)  --C
		,ResultValueTypeName  varchar(120)  --R  (Actual, Estimated, Calculated, etc)  default is actual
		,ResultStatusIdentifier varchar(120)  --R  'Final' for Superfund results eg qualified - MAA Need to investigate
		,SampleCollectionMethodIdentifier  varchar(200)  --C, MAA Required if Activity Type contains the term 'Sample'
		,SampleCollectionEquipmentName varchar(450)  --R, MAA Required when SampleCollectionMethod is present. 
		,ResultAnalyticalMethodIdentifier  varchar(200)   --R
		,ResultAnalyticalMethodIdentifierContext  varchar(120)  --R
		,DetectionQuantitationLimitMeasureValue  varchar (200)  --Cmaa
		,DetectionQuantitationLimitMeasureUnitCode  varchar(120)  --Cmaa
		,DetectionQuantitationLimitTypeName  varchar(350)  --Cmaa
		,ResultComment varchar(4000) --R   include refernce to data validation label. For Palermo it's 'S2BVM'
		--		--Provided to allow for the entry of comments about result.  
		--		--Required - lf a data validation label was generated for a result it must be included in this comment 
		--		--field prefixed by "AnalyticalDataPackageValidationStage="AnalyticalDataPackageValidationStag=S2BVM    
		--		--this represents  a STAGE_2B_Validation_Manual) . 
)

	--Create unique nonclustered index IX_EIMRESULT on @WQX_Result (facility_id
	--, EQ_sample_id,CharacteristicName,ActivityTopDepthHeightMeasureMeasureValue,MethodSpeciationName)--ResultSampleFractionText)
	raiserror('@WQX_Result created' ,0,1) with nowait
	------------------------------------


	set @params = left(@params,len(@params) -1)
	exec [rpt].[sp_HAI_GetParams] @facility_id,@mthgrps, @params --creates ##mthgrps

	 insert into @wqx_result
	 select 	 
		 s.facility_id
		,s.sample_id	
		,wpi.wqx_project_identifier --coalesce(s.task_code, '--check dt_sample.task_code--') --'???????????????????'  --f.program_code  -- projectidentifier maa need to find a place for this
		,wxl.monitoringlocationidentifier -- monitoringlocationidentifier
		,s.sys_sample_code + '_'+ t.lab_name_code    --activityidentifier
		,case 
			when r.result_type_code = 'fld' then 'field msr/obs' 
			when s.sample_method = 'air probe' then 'field msr/obs' --do we need others? maa 11/24/2015
			else 'sample-routine' end --activitytypecode
		,samp_matrix.external_value   --activitiymedianame
		,convert(varchar,s.sample_date,101)  --activitystartdate
		,coalesce(param_name,'{--' + isnull(ra.chemical_name,'') + '--}')   --characteristic name
		,case when r.detect_flag = 'n' then 'not detected'  --resultdetectionconditiontext
			 end
		,case when r.detect_flag = 'y' then equis.significant_figures(equis.unit_conversion(r.result_numeric,r.result_unit,coalesce(@target_unit,mg.default_units, r.result_unit),default),equis.significant_figures_get(r.result_text),default) end    --resultmeasure - resultmeasurevalue
		,case when (r.result_unit = 'su' or r.result_unit = 's.u.' or r.result_unit = 'ph units') then 'nu' else r.result_unit end    --resultmeasure - measureunitcode
		,r.interpreted_qualifiers  --resultmeasure - measurequalifiercode
		,case when t.fraction = 't' or t.fraction = 'n' then 'total'
			when t.fraction = 'd' then 'dissolved'
			else '--check dt_result.fraction--' end  --resultsamplefractiontext 
		,case when t.analytic_method  like '%calc%' then 'calculated' else 'actual' end  --resultvaluetypename
	
		--note: we should tie this approval code such that field params are "approved" even if they're not validated 
		--rather than dependin the list of field params hard-coded here.
		--maa i based it on the result_type_code = 'fld' instead
		,case when r.result_type_code = 'fld'
				then 'final'
			when r.validated_yn = 'n' and s.sample_method = 'air probe'
				then 'final' 
			when r.validated_yn = 'y' then 'final'
			else 'preliminary' end --resultstatusidentifier

		,case when r.result_type_code = 'trg' then coalesce(s.sample_method, 'stndrd_scp') end --samplecollectionmethod - methodidentifier 
		,case when r.result_type_code = 'trg' then coalesce(fs.equipment_code,'pump/bailer') end--samplecollectionequipmentname
		,coalesce(wqx_mth.wqx_method, '{' + t.analytic_method + '}')  --resultanalyticalmethod - methodidentifier
		,coalesce(wqx_mth.context,'--check rt_remap_detail--') --resultanalyticalmethod - methodidentifiercontext
	
		,coalesce(r.reporting_detection_limit, case 
			when r.detect_flag = 'n' then equis.significant_figures(equis.unit_conversion(r.reporting_detection_limit,r.result_unit,coalesce(@target_unit,mg.default_units, r.result_unit),default),equis.significant_figures_get(r.reporting_detection_limit),default)
			else '0' --for field results and other results that don't have a limit, this got rejected when blank
			end) --detectionquantitationlimitmeasure 
		,case when (r.result_unit = 'su' or r.result_unit = 's.u.' or r.result_unit = 'ph units') then 'nu' else r.result_unit end --detectionquantitationlimitmeasure - measureunitcode
		,case
			when r.result_type_code = 'fld' then 'instrument detection level' --for field results, this got rejected when blank
 			when @limit_type is null then  
				case when r.reporting_detection_limit is not null then 'reporting limit'    --detectionquantitationlimittypename
				when r.method_detection_limit is not null then 'method detection level'    --detectionquantitationlimittypename
				else '--check no value in reporting_detection_limit or in method_detection_limit--' end
			when @limit_type = 'pql' then 'practical quantitation limit' --detectionquantitationlimittypename
			when @limit_type = 'mdl' then 'method detection level'    --detectionquantitationlimittypename
			when @limit_type = 'rl' then 'reporting limit'
			else '--check no value in reporting_detection_limit or in method_detection_limit--' end		
		,null --leave resultcomment  out'analyticaldatapackagevalidationstag=s2bvm;this represents a stage_2b_validation_manual'  --resultcomment 

			from  dt_location l


			inner join dbo.dt_sample s
				on l.facility_id =  s.facility_id
				and l.sys_loc_code = s.sys_loc_code
			inner join dbo.dt_test t 
				on t.facility_id = t.facility_id and
				s.sample_id = t.sample_id 
			inner join dt_result r
				on t.facility_id = r.facility_id and
				 t.test_id = r.test_id 
	
			inner join dt_field_sample fs 
				on s.facility_id = fs.facility_id and
				 s.sample_id = fs.sample_id

			inner join rt_analyte ra
				on r.cas_rn = ra.cas_rn

			inner join (select analytic_method, fraction, cas_rn ,parameter,grp_name, param_report_order, mag_report_order, default_units  from ##mthgrps) mg --limit test records to selected analytical parameters
			on t.analytic_method = mg.analytic_method and r.cas_rn = mg.cas_rn
			and (case when t.fraction = 'D' then 'D' else 'T'end) = mg.fraction  --return only D or T (for T or N)
	

		inner join @wqx_locs wxl on l.facility_id = wxl.facility_id and l.sys_loc_code = wxl.sys_loc_code
    
		inner join equis.dbo.rt_matrix mx on s.matrix_code = mx.matrix_code  --matrix
    
		left join  equis.dbo.rt_sample_method sm on s.sample_method = sm.method_code  --sample method

		left join equis.dbo.hai_wqx_project_identifier wpi on s.facility_id = wpi.facility_id
			
	   --chemical 
		left join (select internal_value, external_value as param_name from equis.dbo.rt_remap_detail 
		where external_field = 'wqx_cas' and remap_code = 'epa_wqx') chem
			on r.cas_rn  = chem.internal_value 			

		 left join (select internal_value, external_value from equis.dbo.rt_remap_detail 
		where external_field = 'eimrt_samplesource' and remap_code = 'epa_wqx') samp_source
			on s.matrix_code = samp_source.internal_value 
		
		left join (select internal_value, external_value from equis.dbo.rt_remap_detail 
		where external_field = 'wqx_rt_matrix' and remap_code = 'epa_wqx') samp_matrix
			on s.matrix_code = samp_matrix.internal_value 
		
		left join (select internal_value, external_value as wqx_method, remark as context  from equis.dbo.rt_remap_detail  --anl method
		where external_field = 'wqx_mth' and remap_code = 'epa_wqx'
		) wqx_mth
			on t.analytic_method = wqx_mth.internal_value

		inner join @samp_select ss on ss.sample_id = s.sample_id and ss.facility_id = s.facility_id
    
	   where 
	   l.facility_id = @facility_id
			 --@location_groups,
			 --@locations,
		and s.sample_type_code in (select cast(value as varchar (20)) from fn_split(@sample_type))
		and s.task_code in (select cast(value as varchar (20)) from fn_split(@task_codes))
		and s.sample_date > = @start_date
		and s.sample_date < = @end_date
			 --@mth_grp,
			 --@param,
			 --null, --@fraction,
			 --@matrix_codes,
			 --@target_unit,
			 --@limit_type,
			 --@user_qual_def,
			 --@show_val_yn,

	   and (r.result_type_code = 'trg' or (r.result_type_code = 'fld' and not r.result_text is null))
	   and r.cas_rn not like '%teq%' and s.sample_type_code in ('n')
 
	end try

	begin catch
		select 'error in result output' as err_loc,error_message () as error_desc,error_line() as error_line
		raiserror('error in result output' ,0,1) with nowait
	end catch 
end	
--------------------------------------

if @rpt_flag = 'Result'
 begin
	update @wqx_result
	set ResultAnalyticalMethodIdentifier = external_value, ResultAnalyticalMethodIdentifierContext = remark
	 
	from @WQX_Result wr inner join (select internal_value , external_value, remark 
		from equis.dbo.rt_remap_detail rd where external_field = 'WQX_FieldParam_Mth') rt
		on wr.CharacteristicName  = rt.internal_value

 end
 
----*********************************************************************************************

if @rpt_flag = 'Result' --or @rpt_flag = 'Weather'
begin
select

	 ProjectIdentifier 
	,MonitoringLocationIdentifier 
    ,ActivityIdentifier 
	,ActivityTypeCode 
	,ActivityMediaName
	,ActivityStartDate 
	,CharacteristicName 
	,ResultMeasureValue 
	,ResultMeasureUnitCode 
	,ResultMeasureQualifierCode 
	,ResultDetectionConditionText
 	,ResultSampleFractionText   
	,ResultValueTypeName  
	,ResultStatusIdentifier
	,SampleCollectionMethodIdentifier
	,SampleCollectionEquipmentName
	,ResultAnalyticalMethodIdentifier  
	,ResultAnalyticalMethodIdentifierContext  
	,DetectionQuantitationLimitMeasureValue  
	,DetectionQuantitationLimitMeasureUnitCode  
	,DetectionQuantitationLimitTypeName  
	,ResultComment 
	
 from @WQX_Result --where ResultMeasureValue is not null

End
