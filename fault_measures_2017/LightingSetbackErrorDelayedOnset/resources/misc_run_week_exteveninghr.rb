# The file contains functions to pass arguments from OpenStudio inputs to the
# measure script. They are used to avoid the function run to be too long.

# 11/18/2017 Lighting Setback Error measure developed based on HVAC Setback Error measure
# codes within ######## are modified parts

##########################################################
##########################################################
def applyfaulttolight_no_setback_ext_hr(light, ext_hr, start_month, end_month, dayofweek, runner, setpoint_values, model)
  
  scheds = []
  light.each do |ligh|
	scheds << ligh.schedule
  end
  lightingrulesetschedule = scheds[0].get.to_Schedule.get.clone.to_ScheduleRuleset.get
  
  setpoint_values = gather_light_avg_high_low_values(light, lightingrulesetschedule, setpoint_values, runner, model, 'initial')

  # alter schedules
  addnewscheduleruleset_ext_hr(lightingrulesetschedule, ext_hr, start_month, end_month, dayofweek, 'evening', runner)

  setpoint_values = gather_light_avg_high_low_values(light, lightingrulesetschedule, setpoint_values, runner, model, 'final')

  # assign the modified schedule to the light
  light[0].setSchedule(lightingrulesetschedule)

  return setpoint_values

end
##########################################################
##########################################################