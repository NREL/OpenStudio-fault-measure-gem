# The file contains functions to pass arguments from OpenStudio inputs to the
# measure script. They are used to avoid the function run to be too long.

def applyfaulttothermalzone_evening_setback(thermalzone, ext_hr, start_month, end_month, dayofweek, runner, setpoint_values, model)
  # This function applies the ExtendEveningThermostatSetpointWeek fault to the thermostat
  # setpoint schedules

  # get thermostat schedules
  dualsetpoint, dualsetpointexist = obtainthermostatschedule(thermalzone, runner)
  return true unless dualsetpointexist

  # get heating schedule
  heatingrulesetschedule, rulesetscheduleexist = \
    getschedulerulesetfromsetpointschedule(dualsetpoint.heatingSetpointTemperatureSchedule,thermalzone,runner)
  return false unless rulesetscheduleexist

  # get cooling schedule
  coolingrulesetschedule , rulesetscheduleexist = \
    getschedulerulesetfromsetpointschedule(dualsetpoint.coolingSetpointTemperatureSchedule,thermalzone,runner)
  return false unless rulesetscheduleexist

  setpoint_values = gather_thermostat_avg_high_low_values(thermalzone, heatingrulesetschedule, coolingrulesetschedule, setpoint_values, runner, model, 'initial')

  # alter schedules
  addnewscheduleruleset_ext_hr(heatingrulesetschedule, ext_hr, start_month, end_month, dayofweek, 'evening')
  addnewscheduleruleset_ext_hr(coolingrulesetschedule, ext_hr, start_month, end_month, dayofweek, 'evening')

  setpoint_values = gather_thermostat_avg_high_low_values(thermalzone, heatingrulesetschedule, coolingrulesetschedule, setpoint_values, runner, model, 'final')

  # assign the heating and cooling temperature schedule with faults to the thermostat
  addnewsetpointschedules(dualsetpoint, heatingrulesetschedule, coolingrulesetschedule)

  # assign the thermostat to the zone
  thermalzone.setThermostatSetpointDualSetpoint(dualsetpoint)
end