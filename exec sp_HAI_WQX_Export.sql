

declare @facility_id int = (select facility_id from dt_facility where facility_name like '%yak%')
insert into rt_remap_detail(external_field, external_value, internal_value, status_flag, remap_code, remark)
	select distinct
	'WQX_mth'
	,analytic_method
	,analytic_method
	,'A'
	,'EPA_WQX'
	,'Haley Aldrich'
	 from dt_test
	where facility_id = @facility_id
	and analytic_method like '%calc%'
	and analytic_method not in (
		select
	internal_value
	from rt_remap_detail
	where remap_code = 'EPA_WQX'
	and external_field = 'WQX_mth')


