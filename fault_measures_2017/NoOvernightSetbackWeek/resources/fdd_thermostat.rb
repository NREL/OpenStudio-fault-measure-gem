module OsLib_FDD

  # global variable for ending date and ending time of the day
  require_relative 'global_const'

  def getschedulerulesetfromsetpointschedule(schedule,thermalzone,runner)
    # This function returns a deep copy of the ScheduleRuleset object within
    # the Schedule object made to reduce the ABC of function applyfaulttothermalzone

    # create a new object because the old one may be used by other thermal zones
    # and we want to keep that intact

    if schedule.is_initialized and schedule.get.to_Schedule.is_initialized and schedule.get.to_Schedule.get.to_ScheduleRuleset.is_initialized
      return schedule.get.to_Schedule.get.clone.to_ScheduleRuleset.get, true
    else
      runner.registerWarning("Skipping #{thermalzone.name} because it is either missing heating or cooling setpoint schedule, or those schedules are not ScheduleRulesets.")
      return '', false
    end

  end

  def obtainthermostatschedule(thermalzone, runner)
    # This function helps to obtain the ThermostatDualSetpoint object from the
    # OpenStudio object of the chosen zone

    thermostatsetpointdualsetpoint = thermalzone.thermostatSetpointDualSetpoint
    if thermostatsetpointdualsetpoint.empty?
      runner.registerWarning(
          "Cannot find existing thermostat for thermal zone '#{thermalzone.name}', " \
      'skipping. No changes made.'
      )
      return '', false
    end
    thermostatsetpointdualsetpoint = \
    thermostatsetpointdualsetpoint.get.clone.to_ThermostatSetpointDualSetpoint.get

    return thermostatsetpointdualsetpoint, true
  end

  def addnewsetpointschedules(dualsetpoint, heatingrulesetschedule,
                              coolingrulesetschedule)
    # This function adds the new heating and cooling schedule to the DualSetpoint
    # object

    # assign the heating temperature schedule with faults to the thermostat
    dualsetpoint.setHeatingSetpointTemperatureSchedule(heatingrulesetschedule)

    # assign the cooling temperature schedule with faults to the thermostat
    dualsetpoint.setCoolingSetpointTemperatureSchedule(coolingrulesetschedule)
  end

# todo - this results in unused default profile and extra rules, would be nice to clean up how this works.
  def addnewscheduleruleset(heatorcoolscheduleruleset, start_month,
                            end_month, dayofweek)
    # This function accepts schedules rulesets of heating or cooling, analyzes the
    # priority and default rules in the schedule and add new schedules with the
    # evening offsets back to the model. start_month is the string for the starting
    # month when the NoOvernightSetback fault starts, and end_month is the string for
    # the ending month that the fault ends.

    # get ending date
    e_day = $e_days[end_month]

    # create new priority rule for default day schedule first
    defaultday_clone = \
    heatorcoolscheduleruleset.defaultDaySchedule.to_ScheduleDay.get
    oritimes = defaultday_clone.times
    orivalues = defaultday_clone.values
    createnewdefaultdayofweekrule(heatorcoolscheduleruleset, oritimes, orivalues,
                                  start_month, end_month, e_day, dayofweek)

    # change the schedule rules of the priority rules first
    createnewpriroityrules(heatorcoolscheduleruleset, start_month,
                           end_month, e_day, dayofweek)
  end

  def createnewpriroityrules(heatorcoolscheduleruleset, start_month,
                             end_month, e_day, dayofweek)
    # This function creates new priority rules to impose NoOvernightSetback fault
    # to the schedules of thermostat setpoint

    rules = heatorcoolscheduleruleset.scheduleRules
    rules.each_with_index do |rule, i|
      next unless checkscheduleruledayofweek(rule, dayofweek)
      # create new rules with a higher priority than the present one
      rule_clone = OpenStudio::Model::ScheduleRule.new(heatorcoolscheduleruleset)
      copydayscheduletimesandvalues(rule.daySchedule, rule_clone.daySchedule)
      setcommoninformation(rule_clone, rule.name, start_month, end_month, e_day)
      propagateeveningchangeovervalue(rule_clone)
      compareandchangedayofweek(rule_clone, rule, dayofweek)
    end
  end

  def checkscheduleruledayofweek(scheduleRule, dayofweek)
    # This function checks if a certain sceduleRule is applied to the dayofweek
    case dayofweek
      when 'Monday'
        return scheduleRule.applyMonday
      when 'Tuesday'
        return scheduleRule.applyTuesday
      when 'Wednesday'
        return scheduleRule.applyWednesday
      when 'Thursday'
        return scheduleRule.applyThursday
      when 'Friday'
        return scheduleRule.applyFriday
      when 'Saturday'
        return scheduleRule.applySaturday
      when 'Sunday'
        return scheduleRule.applySunday
      when $all_days
        return checkschedulerulemultidayofweek(scheduleRule, $dayofweeks)
      when $weekdaysonly
        return checkschedulerulemultidayofweek(scheduleRule, $weekdays)
      when $weekendonly
        return checkschedulerulemultidayofweek(scheduleRule, $weekend)
      else
        return false
    end
  end

  def checkschedulerulemultidayofweek(scheduleRule, dayofweeks)
    # This function checks if a certain sceduleRule is applied to any days in
    # dayofweeks
    dayofweeks.each do |fixday|
      # return true as far as one of them is true
      return true if checkscheduleruledayofweek(scheduleRule, fixday)
    end
    return false
  end

  def compareandchangedayofweek(scheduleRule, oldscheduleRule, dayofweeks)
    # This function compares the applied days between ones in oldscheduleRule
    # and ones in dayofweeks, and only apply the day to scheduleRule when
    # the day exists in both the applied days and the dayofweeks

    # check if multiple day computation is needed
    fixdays = []
    applyallday(scheduleRule, false)
    case dayofweeks
      when $all_days
        fixdays = $dayofweeks
      when $weekdaysonly
        fixdays = $weekdays
      when $weekendonly
        fixdays = $weekend
      else
        # only one single day is involved. change it normally
        changedayofweek(scheduleRule, dayofweeks)
        return true
    end

    # check the applied days in the old rule and see if it should be
    # imposed in the new rule
    fixdays.each do |fixday|
      if checkscheduleruledayofweek(oldscheduleRule, fixday)
        applydayofweek(scheduleRule, fixday)
      end
    end
    return true
  end

  def changedayofweek(scheduleRule, dayofweek)
    # This function changes to ScheduleRule object so that it is only applied
    # to dayofweek
    applyallday(scheduleRule, false)
    applydayofweek(scheduleRule, dayofweek)
  end

  def applydayofweek(scheduleRule, dayofweek)
    # set apply to a specific day according to the string in dayofweek
    case dayofweek
      when 'Monday'
        scheduleRule.setApplyMonday(true)
      when 'Tuesday'
        scheduleRule.setApplyTuesday(true)
      when 'Wednesday'
        scheduleRule.setApplyWednesday(true)
      when 'Thursday'
        scheduleRule.setApplyThursday(true)
      when 'Friday'
        scheduleRule.setApplyFriday(true)
      when 'Saturday'
        scheduleRule.setApplySaturday(true)
      when 'Sunday'
        scheduleRule.setApplySunday(true)
      when $all_days
        applyallday(scheduleRule, true)
      when $weekdaysonly
        applymultidayofweek(scheduleRule, $weekdays)
      when $weekendonly
        applymultidayofweek(scheduleRule, $weekend)
      else
        return false
    end
    return true
  end

  def applymultidayofweek(scheduleRule, dayofweeks)
    # set application to multiple days in a week
    dayofweeks.each do |fixday|
      next if applydayofweek(scheduleRule, fixday)
      return false
    end
    return true
  end

  def createnewdefaultdayofweekrule(heatorcoolscheduleruleset, oritimes, orivalues,
                                    start_month, end_month, e_day, dayofweek)
    # This function create a priority rule based on default day rule that is applied
    # to dayofweek only

    defaultday_rule = \
    OpenStudio::Model::ScheduleRule.new(heatorcoolscheduleruleset)
    copydayscheduletimesandvalues(heatorcoolscheduleruleset.defaultDaySchedule,
                                  defaultday_rule.daySchedule)
    setcommoninformation(defaultday_rule,
                         heatorcoolscheduleruleset.defaultDaySchedule.name,
                         start_month, end_month, e_day)
    changedayofweek(defaultday_rule, dayofweek)
    propagateeveningchangeovervaluewithextrainfo(defaultday_rule, oritimes,
                                                 orivalues)
  end

  def copydayscheduletimesandvalues(sourcedayschedule, todayschedule)
    # copy the times and values from sourcedayschedule to todayschedule
    todayschedule.clearValues
    times = sourcedayschedule.times
    values = sourcedayschedule.values
    times.zip(values).each do |time, value|
      todayschedule.addValue(time, value)
    end
  end

  def setcommoninformation(scheduleRule, name, start_month, end_month, e_day)
    # This function sets the name, the starting month and the ending month
    # of the given OpenStudio ScheduleRule object
    scheduleRule.setName("#{name} with new start/end dates")
    scheduleRule.setStartDate(
        OpenStudio::Date.new(OpenStudio::MonthOfYear.new(start_month), 1)
    )
    scheduleRule.setEndDate(
        OpenStudio::Date.new(OpenStudio::MonthOfYear.new(end_month), e_day)
    )
  end

  def applyallday(scheduleRule, on)
    # This function sets the scheduleRule in the input to switch on
    # or off all day of the week
    scheduleRule.setApplySunday(on)
    scheduleRule.setApplyMonday(on)
    scheduleRule.setApplyTuesday(on)
    scheduleRule.setApplyWednesday(on)
    scheduleRule.setApplyThursday(on)
    scheduleRule.setApplyFriday(on)
    scheduleRule.setApplySaturday(on)
  end

  def propagateeveningchangeovervalue(scheduleRule)
    # This function analyzes the OpenStudio::mode::ScheduleRule object at the
    # inputs to find the temperature setpoint before the building closure in
    # the evening. It returns a value indicating the setpoint. It then
    # propagates the changeover value according to the assumed startup and
    # shutdown time of the zone.

    scheduleday = scheduleRule.daySchedule
    scheduleday.setName("#{scheduleday.name} with NoOvernightSetback")
    times = scheduleday.times
    values = scheduleday.values
    finval, changetime = finvalandchangetime(times, values)
    newtimesandvaluestosceduleday(times, values, finval, changetime, scheduleday)
  end

  def propagateeveningchangeovervaluewithextrainfo(scheduleRule, times, values)
    # This function obtains the times and values vector from the user
    # to find the temperature setpoint before the building closure in
    # the evening. It returns a value indicating the setpoint. It then
    # propagates the changeover value according to the assumed startup and
    # shutdown time of the zone. It passes all the new information to the user
    # defined scheduleRule

    scheduleday = scheduleRule.daySchedule
    scheduleday.setName("#{scheduleday.name} with NoOvernightSetback")
    finval, changetime = finvalandchangetime(times, values)
    newtimesandvaluestosceduleday(times, values, finval, changetime, scheduleday)
  end

  def finvalandchangetime(times, values)
    # This function finds the value of setpoint in the evening with NoOvernightSetback
    # fault, and returns the setpoint and the end time of daytime building operation

    finval = values[0] # default
    preval = values[0]
    changetime = times[0]
    times.zip(values).each do |time, value|
      # any setpoint change after 3pm should be a result of shutdown
      next unless time.hours >= $end_hour
      finval = value
      changetime = time
      break
    end

    return finval, changetime
  end

  def newtimesandvaluestosceduleday(times, values, finval, changetime, scheduleday)
    # This function is used to replace times and values in scheduleday
    # with user-specified values. If the times are outside the
    # hours of building daytime operation, it replaces the values
    # with finval.

    scheduleday.clearValues
    # force the first setpoint of the day and any setpoint in the evening
    # to be the same as the daytime setpoint
    (0..(times.length - 1)).each do |ind|
      hour = times[ind].hours
      if ind == 0 || times[ind] > changetime
        scheduleday.addValue(times[ind], finval)
      else
        scheduleday.addValue(times[ind], values[ind])
      end
    end
  end

  # methods above are in NoOvernightThermostatSetback
  # methods below are only in ExtendEveningThermostatSetpoint and ExtendMorningThermostatSetpoint

  def createnewruleandcopy(scheduleruleset, olddayschedule, start_month, end_month, e_day)
    # return a new rule with dayschedule the same as the olddayschedule for a user-defined
    # starting month and ending month. Afterwards, it is imposed to the ScheduleRuleset scheduleruleset.
    # day of week is also specified according to user preference
    rule_clone = OpenStudio::Model::ScheduleRule.new(scheduleruleset)
    copydayscheduletimesandvalues(olddayschedule, rule_clone.daySchedule)
    setcommoninformation(rule_clone, olddayschedule.name, start_month,
                         end_month, e_day)
    return rule_clone
  end

  def findchangetime(times, values)
    # This function finds the closing time of the building for extension
    # according to the thermostat schedule

    if times.length > 1
      return times[-2]
    else
      return times[0]
    end
  end

  def shifttimevector(times, values, ext_hr, changetime)
    # This function shifts the time vector according to the extension
    # in ext_hr. If the extension passes midnight, it terminates the
    # extension at midnight, and dispose the midnight value in the
    # times and values vector. It returns a new Time object with the
    # shifted time

    newtime = times[0]
    if times.length > 1  # no extension if the setpoint is a constant
      ind = times.index(changetime)
      newhours, newminutes = newhrandmin(times, values, ind, ext_hr)
      newtime = OpenStudio::Time.new(times[ind].days, newhours, newminutes, 0)
    end
    return newtime
  end

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

  def roundtointeger(floatnum)
    # This function rounds a float to an integer

    return floatnum.round.to_i
  end

  def roundclock(newhours, newminutes)
    # This function adjusts the integers in hours and minutes
    # so that minutes will not exceed 60 upon calculation

    if newminutes >= 60
      newhours += 1
      newminutes -= 60
    end
    return newhours, newminutes
  end

  def midnightadjust(newhours, newminutes, times, values, ind)
    # This function checks the times vector to see if the
    # second last vector passes midnight. If it does, remove
    # the last entry in times and values

    newhours, newminutes = roundclock(newhours, newminutes)
    if newhours >= 24
      newhours = 23
      newminutes = 59
    end
    return newhours, newminutes
  end

end