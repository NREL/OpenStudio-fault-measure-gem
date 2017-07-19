# The file contains functions to pass arguments from OpenStudio inputs to the
# measure script. They are used to avoid the function run to be too long.

# obtainzone moved to misc_arguemnts.rb which is used by other measures

def applyfaulttothermalzone(thermalzone, start_month, end_month, dayofweek, runner, num_hours_in_year, setpoint_values)
  # This function applies the NoOvernightSetback fault to the thermostat
  # setpoint schedules

  # get thermostat schedules
  dualsetpoint, dualsetpointexist = obtainthermostatschedule(thermalzone, runner)
  return false unless dualsetpointexist

  # get heating schedule
  heatingrulesetschedule, rulesetscheduleexist = \
    getschedulerulesetfromsetpointschedule(dualsetpoint.heatingSetpointTemperatureSchedule,thermalzone,runner)
  return false unless rulesetscheduleexist

  # get cooling schedule
  coolingrulesetschedule , rulesetscheduleexist = \
    getschedulerulesetfromsetpointschedule(dualsetpoint.coolingSetpointTemperatureSchedule,thermalzone,runner)
  return false unless rulesetscheduleexist

  # gather initial thermostat range and average temp
  avg_htg_si = heatingrulesetschedule.annual_equivalent_full_load_hrs/num_hours_in_year
  min_max = heatingrulesetschedule.annual_min_max_value
  runner.registerInfo("Initial annual average heating setpoint for #{thermalzone.name} #{avg_htg_si.round(1)} C, with a range of #{min_max['min'].round(1)} C to #{min_max['max'].round(1)} C.")
  setpoint_values[:init_htg_min] << min_max['min']
  setpoint_values[:init_htg_max] << min_max['max']

  avg_clg_si = coolingrulesetschedule.annual_equivalent_full_load_hrs/num_hours_in_year
  min_max = coolingrulesetschedule.annual_min_max_value
  runner.registerInfo("Initial annual average cooling setpoint for #{thermalzone.name} #{avg_clg_si.round(1)} C, with a range of #{min_max['min'].round(1)} C to #{min_max['max'].round(1)} C.")
  setpoint_values[:init_clg_min] << min_max['min']
  setpoint_values[:init_clg_max] << min_max['max']

  # alter schedules
  addnewscheduleruleset(heatingrulesetschedule, start_month, end_month, dayofweek)
  addnewscheduleruleset(coolingrulesetschedule, start_month, end_month, dayofweek)

  # gather final thermostat range and average temp
  avg_htg_si = heatingrulesetschedule.annual_equivalent_full_load_hrs/num_hours_in_year
  min_max = heatingrulesetschedule.annual_min_max_value
  runner.registerInfo("Final annual average heating setpoint for #{thermalzone.name} #{avg_htg_si.round(1)} C, with a range of #{min_max['min'].round(1)} C to #{min_max['max'].round(1)} C.")
  setpoint_values[:final_htg_min] << min_max['min']
  setpoint_values[:final_htg_max] << min_max['max']

  avg_clg_si = coolingrulesetschedule.annual_equivalent_full_load_hrs/num_hours_in_year
  min_max = coolingrulesetschedule.annual_min_max_value
  runner.registerInfo("Final annual average cooling setpoint for #{thermalzone.name} #{avg_clg_si.round(1)} C, with a range of #{min_max['min'].round(1)} C to #{min_max['max'].round(1)} C.")
  setpoint_values[:final_clg_min] << min_max['min']
  setpoint_values[:final_clg_max] << min_max['max']

  # assign the heating and cooling temperature schedule with faults to the thermostat
  addnewsetpointschedules(dualsetpoint, heatingrulesetschedule, coolingrulesetschedule)

  # assign the thermostat to the zone
  thermalzone.setThermostatSetpointDualSetpoint(dualsetpoint)

  return setpoint_values

end
