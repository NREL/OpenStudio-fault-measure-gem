# The file contains functions to pass arguments from OpenStudio inputs to the
# measure script. They are used to avoid the function run to be too long.

def applyfaulttothermalzone_evening_setback(thermalzone, ext_hr, start_month, end_month, dayofweek, runner, setpoint_values, model)
  # This function applies the ExtendEveningThermostatSetpointWeek fault to the thermostat
  # setpoint schedules

  # get thermostat schedules
  dualsetpoint, dualsetpointexist = obtainthermostatschedule_alt(thermalzone, runner)
  return true unless dualsetpointexist

  # get heating schedule
  heatingrulesetschedule, rulesetscheduleexist = \
    OsLib_FDD_hvac.getschedulerulesetfromsetpointschedule_alt(dualsetpoint.heatingSetpointTemperatureSchedule,thermalzone,runner)
  return false unless rulesetscheduleexist

  # get cooling schedule
  coolingrulesetschedule , rulesetscheduleexist = \
    OsLib_FDD_hvac.getschedulerulesetfromsetpointschedule_alt(dualsetpoint.coolingSetpointTemperatureSchedule,thermalzone,runner)
  return false unless rulesetscheduleexist

  setpoint_values = OsLib_FDD_hvac.gather_thermostat_avg_high_low_values_alt(thermalzone, heatingrulesetschedule, coolingrulesetschedule, setpoint_values, runner, model, 'initial')

  # alter schedules
  OsLib_FDD_hvac.addnewscheduleruleset_ext_hr_alt(heatingrulesetschedule, ext_hr, start_month, end_month, dayofweek, 'evening')
  OsLib_FDD_hvac.addnewscheduleruleset_ext_hr_alt(coolingrulesetschedule, ext_hr, start_month, end_month, dayofweek, 'evening')

  setpoint_values = OsLib_FDD_hvac.gather_thermostat_avg_high_low_values_alt(thermalzone, heatingrulesetschedule, coolingrulesetschedule, setpoint_values, runner, model, 'final')

  # assign the heating and cooling temperature schedule with faults to the thermostat
  OsLib_FDD_hvac.addnewsetpointschedules_alt(dualsetpoint, heatingrulesetschedule, coolingrulesetschedule)

  # assign the thermostat to the zone
  thermalzone.setThermostatSetpointDualSetpoint(dualsetpoint)
end

def applyfaulttolight_no_setback_ext_hr_evening(light, ext_hr, start_month, end_month, dayofweek, runner, setpoint_values, model)
  
  scheds = []
  light.each do |ligh|
	scheds << ligh.schedule
  end
  lightingrulesetschedule = scheds[0].get.to_Schedule.get.clone.to_ScheduleRuleset.get
  if light.size > 1
    runner.registerWarning("#{light.space.name} has more than one light object. Only changing the schedule for #{light[0].name}.")
  end

  setpoint_values = gather_light_avg_high_low_values(light, lightingrulesetschedule, setpoint_values, runner, model, 'initial')

  # alter schedules
  addnewscheduleruleset_ext_hr(lightingrulesetschedule, ext_hr, start_month, end_month, dayofweek, 'evening', runner)

  setpoint_values = gather_light_avg_high_low_values(light, lightingrulesetschedule, setpoint_values, runner, model, 'final')

  # assign the modified schedule to the light
  light[0].setSchedule(lightingrulesetschedule)

  return setpoint_values

end

def applyfaulttopeople(people, light, ext_hr, start_month, end_month, dayofweek, runner, setpoint_values, model)
  
  scheds_occ = []
  people.each do |peopl|
	scheds_occ << peopl.numberofPeopleSchedule
  end
  peoplerulesetschedule = scheds_occ[0].get.to_Schedule.get.clone.to_ScheduleRuleset.get
  
  scheds_ltg = []
  light.each do |ligh|
	scheds_ltg << ligh.schedule
  end
  lightingrulesetschedule = scheds_ltg[0].get.to_Schedule.get.clone.to_ScheduleRuleset.get
  
  setpoint_values = gather_light_avg_high_low_values(people, peoplerulesetschedule, setpoint_values, runner, model, 'initial')

  # alter schedules
  addnewscheduleruleset_occupancy(lightingrulesetschedule, peoplerulesetschedule, ext_hr, start_month, end_month, dayofweek, 'evening', runner)

  setpoint_values = gather_light_avg_high_low_values(light, lightingrulesetschedule, setpoint_values, runner, model, 'final')

  # assign the modified schedule to the people
  light[0].setSchedule(lightingrulesetschedule)

  return setpoint_values

end
