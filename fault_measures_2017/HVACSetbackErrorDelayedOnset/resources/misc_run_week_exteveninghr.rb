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