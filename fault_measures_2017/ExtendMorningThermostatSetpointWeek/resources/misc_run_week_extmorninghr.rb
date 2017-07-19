# The file contains functions to pass arguments from OpenStudio inputs to the
# measure script. They are used to avoid the function run to be too long.

# global variable for ending date and ending time of the day
require_relative 'global_const'

def getinputs(model, runner, user_arguments)
  # This function passes the inputs in user_arguments, other than the ones
  # to check if the function should run, to the run function. For
  # ExtendMorningThermostatSetpoint, it is start_month, end_month and
  # thermalzone

  start_month = runner.getStringArgumentValue('start_month', user_arguments)
  end_month = runner.getStringArgumentValue('end_month', user_arguments)
  thermalzones = obtainzone('zone', model, runner, user_arguments)
  dayofweek = runner.getStringArgumentValue('dayofweek', user_arguments)
  return start_month, end_month, thermalzones, dayofweek
end

# obtainzone moved to misc_arguemnts.rb which is used by other measures

def applyfaulttothermalzone(thermalzone, ext_hr, start_month, end_month, dayofweek, runner, num_hours_in_year, setpoint_values)
  # This function applies the ExtendMorningThermostatSetpointWeek fault to the thermostat
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
  addnewscheduleruleset(heatingrulesetschedule, ext_hr, start_month, end_month, dayofweek)
  addnewscheduleruleset(coolingrulesetschedule, ext_hr, start_month, end_month, dayofweek)

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
end

# todo - this method is has ext_hr arg not fouund in uses of this method in other measures
def addnewscheduleruleset(heatorcoolscheduleruleset, ext_hr, start_month,
                          end_month, dayofweek)
  # This function accepts schedules rulesets of heating or cooling, analyzes the
  # priority and default rules in the schedule and add new schedules with the
  # evening offsets back to the model. start_month is the string for the starting
  # month when the ExtendMorningThermostatSetpointWeek fault starts, and end_month is the string for
  # the ending month that the fault ends.

  # get ending date
  e_day = $e_days[end_month]

  # create new priority rule for default day schedule
  defaultday_clone = \
    heatorcoolscheduleruleset.defaultDaySchedule.to_ScheduleDay.get
  oritimes = defaultday_clone.times
  orivalues = defaultday_clone.values
  createnewdefaultdayofweekrule(heatorcoolscheduleruleset, ext_hr,
                                oritimes, orivalues, start_month,
                                end_month, e_day, dayofweek)

  # change the schedule rules of the priority rules first
  createnewpriroityrules(heatorcoolscheduleruleset, ext_hr,
                         start_month, end_month, e_day, dayofweek)
end

# todo - this method is has ext_hr arg not found in uses of this method in other measures
def createnewpriroityrules(heatorcoolscheduleruleset, ext_hr, start_month,
                           end_month, e_day, dayofweek)
  # This function creates new priority rules to impose ExtendMorningThermostatSetpointWeek fault
  # to the schedules of thermostat setpoint

  # iterate rules with the lowest priority first and skip the highest priority rule
  # that was just created with the default rule
  rules = heatorcoolscheduleruleset.scheduleRules
  (1..(rules.length - 1)).each do |i|
    rule = rules[-i]
    if checkscheduleruledayofweek(rule, dayofweek)
      # create new rules with the highest priority among existing ones if it hasn't been just created
      # and the rule is applicable to the related dayofweek
      rule_clone = createnewruleandcopy(heatorcoolscheduleruleset, rule.daySchedule,
                                        start_month, end_month, e_day)
      compareandchangedayofweek(rule_clone, rule, dayofweek)
      propagateeveningchangeovervalue(rule_clone, ext_hr)
    end
  end
end

# todo - this method is has ext_hr arg not found in uses of this method in other measures
def createnewdefaultdayofweekrule(heatorcoolscheduleruleset, ext_hr, oritimes, orivalues,
                                  start_month, end_month, e_day, dayofweek)
  # This function create a priority rule based on default day rule that is applied
  # to dayofweek only

  new_defaultday_rule = createnewruleandcopy(
    heatorcoolscheduleruleset, heatorcoolscheduleruleset.defaultDaySchedule,
    start_month, end_month, e_day
  )
  changedayofweek(new_defaultday_rule, dayofweek)
  propagateeveningchangeovervaluewithextrainfo(new_defaultday_rule, ext_hr,
                                               oritimes, orivalues)
end

# todo - this method is has ext_hr arg not found in uses of this method in other measures
def propagateeveningchangeovervalue(scheduleRule, ext_hr)
  # This function analyzes the OpenStudio::mode::ScheduleRule object at the
  # inputs to find the temperature setpoint before the building closure in
  # the evening. It returns a value indicating the setpoint. It then
  # propagates the changeover value according to the assumed startup and
  # shutdown time of the zone.

  scheduleday = scheduleRule.daySchedule
  scheduleday.setName("#{scheduleday.name} with ExtendMorningThermostatSetpointWeek")
  times = scheduleday.times
  values = scheduleday.values
  changetime = findchangetime(times, values)
  newtimesandvaluestosceduleday(times, values, ext_hr, changetime, scheduleday)
end

# todo - this method is has ext_hr arg not found in uses of this method in other measures
def propagateeveningchangeovervaluewithextrainfo(scheduleRule, ext_hr, times, values)
  # This function obtains the times and values vector from the user
  # to find the temperature setpoint before the building closure in
  # the evening. It returns a value indicating the setpoint. It then
  # propagates the changeover value according to the assumed startup and
  # shutdown time of the zone. It passes all the new information to the user
  # defined scheduleRule

  scheduleday = scheduleRule.daySchedule
  scheduleday.setName("#{scheduleday.name} with ExtendMorningThermostatSetpointWeek")
  changetime = findchangetime(times, values)
  newtimesandvaluestosceduleday(times, values, ext_hr, changetime, scheduleday)
end

def findchangetime(times, values)
  # This function finds the closing time of the building for extension
  # according to the thermostat schedule

  # should be the first one for the morning extension
  return times[0]
end

# todo - this method is has ext_hr arg not found in uses of this method in other measures
def newtimesandvaluestosceduleday(times, values, ext_hr, changetime, scheduleday)
  # This function is used to replace times and values in scheduleday
  # with user-specified values. If the times are outside the
  # hours of building daytime operation, it extends the operation schedule
  # by extended hour

  scheduleday.clearValues
  # force the first setpoint of the day and any setpoint in the evening
  # to be the same as the daytime setpoint
  newtime = shifttimevector(times, values, ext_hr, changetime)
  times.zip(values).each do |time, value|
    if time == changetime
      scheduleday.addValue(newtime, value)
    else
      scheduleday.addValue(time, value)
    end
  end
end
