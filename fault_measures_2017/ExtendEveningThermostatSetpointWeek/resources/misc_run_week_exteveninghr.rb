# The file contains functions to pass arguments from OpenStudio inputs to the
# measure script. They are used to avoid the function run to be too long.

def applyfaulttothermalzone(thermalzone, ext_hr, start_month, end_month, dayofweek, runner, setpoint_values, model)
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
  addnewscheduleruleset_ext_hr(heatingrulesetschedule, ext_hr, start_month, end_month, dayofweek)
  addnewscheduleruleset_ext_hr(coolingrulesetschedule, ext_hr, start_month, end_month, dayofweek)

  setpoint_values = gather_thermostat_avg_high_low_values(thermalzone, heatingrulesetschedule, coolingrulesetschedule, setpoint_values, runner, model, 'final')

  # assign the heating and cooling temperature schedule with faults to the thermostat
  addnewsetpointschedules(dualsetpoint, heatingrulesetschedule, coolingrulesetschedule)

  # assign the thermostat to the zone
  thermalzone.setThermostatSetpointDualSetpoint(dualsetpoint)
end

# todo - different code for morning and evening fault
def findchangetime(times, values)
  # This function finds the closing time of the building for extension
  # according to the thermostat schedule

  if times.length > 1
    return times[-2]
  else
    return times[0]
  end
end

# todo - different code for morning and evening fault
def newhrandmin(times, values, ind, ext_hr)
  # This function returns the hours and minutes for substitution
  # in the vector times from the time object indicated by index ind. The
  # new time object will consist of the time shifted according to ext_hr.
  # It also removes the last entry in times and values vector when needed

  hr = ext_hr.floor
  newhours = roundtointeger(times[ind].hours) + hr
  # do not correct upwards
  newminutes = roundtointeger(times[ind].minutes) + ((ext_hr - hr) * 60).floor
  newhours, newminutes = midnightadjust(newhours, newminutes,
                                        times, values, ind)
  return newhours, newminutes
end