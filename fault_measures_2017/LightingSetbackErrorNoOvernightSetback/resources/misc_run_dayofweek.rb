# The file contains functions to pass arguments from OpenStudio inputs to the
# measure script. They are used to avoid the function run to be too long.

def applyfaulttothermalzone_no_setback(thermalzone, start_month, end_month, dayofweek, runner, setpoint_values, model)
  # This function applies the NoOvernightSetback fault to the thermostat
  # setpoint schedules

  # get thermostat schedules
  dualsetpoint, dualsetpointexist = obtainthermostatschedule_alt(thermalzone, runner)
  return false unless dualsetpointexist

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
  OsLib_FDD_hvac.addnewscheduleruleset_alt(heatingrulesetschedule, start_month, end_month, dayofweek)
  OsLib_FDD_hvac.addnewscheduleruleset_alt(coolingrulesetschedule, start_month, end_month, dayofweek)

  setpoint_values = OsLib_FDD_hvac.gather_thermostat_avg_high_low_values_alt(thermalzone, heatingrulesetschedule, coolingrulesetschedule, setpoint_values, runner, model, 'final')

  # assign the heating and cooling temperature schedule with faults to the thermostat
  OsLib_FDD_hvac.addnewsetpointschedules_alt(dualsetpoint, heatingrulesetschedule, coolingrulesetschedule)

  # assign the thermostat to the zone
  thermalzone.setThermostatSetpointDualSetpoint(dualsetpoint)

  return setpoint_values

end

##########################################################
##########################################################
def applyfaulttolight_no_setback(light, start_month, end_month, dayofweek, runner, setpoint_values, model)
  
  scheds = []
  light.each do |ligh|
	scheds << ligh.schedule
  end
  lightingrulesetschedule = scheds[0].get.to_Schedule.get.clone.to_ScheduleRuleset.get
  
  setpoint_values = gather_light_avg_high_low_values(light, lightingrulesetschedule, setpoint_values, runner, model, 'initial')

  # alter schedules
  addnewscheduleruleset(lightingrulesetschedule, start_month, end_month, dayofweek, runner)

  setpoint_values = gather_light_avg_high_low_values(light, lightingrulesetschedule, setpoint_values, runner, model, 'final')

  # assign the modified schedule to the light
  light[0].setSchedule(lightingrulesetschedule)

  return setpoint_values

end
##########################################################
##########################################################