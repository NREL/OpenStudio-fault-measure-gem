#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

require 'date'
require "#{File.dirname(__FILE__)}/resources/util"

#start the measure
class NoReset < OpenStudio::Ruleset::ModelUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "NoReset"
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # #make a bool argument for not running the measure
    # run_me = OpenStudio::Ruleset::OSArgument::makeBoolArgument("run_me", true)
    # run_me.setDisplayName("Run Measure ThermostatBias")
    # run_me.setDefaultValue(false)
    # args << run_me

    #make a choice argument for model objects
    zone_handles = OpenStudio::StringVector.new
    zone_display_names = OpenStudio::StringVector.new

    #putting model object and names into hash
    zone_args = model.getThermalZones
    zone_args_hash = {}
    zone_args.each do |zone_arg|
      zone_args_hash[zone_arg.name.to_s] = zone_arg
    end

    #looping through sorted hash of model objects
    zone_args_hash.sort.map do |key,value|
      zone_handles << value.handle.to_s
      zone_display_names << key
    end

    #make choice argument for thermal zone
    zone = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("zone", zone_display_names, zone_display_names, true)
    zone.setDisplayName("Zone")
    args << zone

    # days = OpenStudio::StringVector.new
    # days << "No Fault"
    # days << "Sunday"
    # days << "Monday"
    # days << "Tuesday"
    # days << "Wednesday"
    # days << "Thursday"
    # days << "Friday"
    # days << "Saturday"

    months = OpenStudio::StringVector.new
    months << "January"
    months << "February"
    months << "March"
    months << "April"
    months << "May"
    months << "June"
    months << "July"
    months << "August"
    months << "September"
    months << "October"
    months << "November"
    months << "December"

    no_reset = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("no_reset", true)
    no_reset.setDisplayName("Day of the week which is set to default day schedule [1=Sunday, 2=Monday, ...] [0=Non faulted case]")
    no_reset.setDefaultValue(0)
    args << no_reset

    start_month = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("start_month", months, true)
    start_month.setDisplayName("Fault active start month")
    start_month.setDefaultValue("January")
    args << start_month

    end_month = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("end_month", months, true)
    end_month.setDisplayName("Fault active end month")
    end_month.setDefaultValue("December")
    args << end_month

    # no_reset_cooling = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("no_reset_cooling", days, true)
    # no_reset_cooling.setDisplayName("Day of the week which doesn't receive its cooling reset")
    # no_reset_cooling.setDefaultValue("No Fault")
    # args << no_reset_cooling
    #
    # c_start_month = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("c_start_month", months, true)
    # c_start_month.setDisplayName("Cooling: fault active start month")
    # c_start_month.setDefaultValue("January")
    # args << c_start_month
    #
    # c_end_month = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("c_end_month", months, true)
    # c_end_month.setDisplayName("Cooling: fault active end month")
    # c_end_month.setDefaultValue("December")
    # args << c_end_month

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    if runner.getIntegerArgumentValue("no_reset",user_arguments) != 0

      no_reset = runner.getIntegerArgumentValue("no_reset",user_arguments)
      no_reset = {1=>"Sunday",2=>"Monday",3=>"Tuesday",4=>"Wednesday",5=>"Thursday",6=>"Friday",7=>"Saturday"}[no_reset]
      # no_reset_cooling = runner.getStringArgumentValue("no_reset_cooling",user_arguments)

      start_month = runner.getStringArgumentValue("start_month",user_arguments)
      end_month = runner.getStringArgumentValue("end_month",user_arguments)
      # c_start_month = runner.getStringArgumentValue("c_start_month",user_arguments)
      # c_end_month = runner.getStringArgumentValue("c_end_month",user_arguments)

      s_month = {"January"=>1,"February"=>2,"March"=>3,"April"=>4,"May"=>5,"June"=>6,"July"=>7,"August"=>8,"September"=>9,"October"=>10,"November"=>11,"December"=>12}[start_month]
      e_month = {"January"=>1,"February"=>2,"March"=>3,"April"=>4,"May"=>5,"June"=>6,"July"=>7,"August"=>8,"September"=>9,"October"=>10,"November"=>11,"December"=>12}[end_month]
      e_day = {"January"=>31,"February"=>28,"March"=>31,"April"=>30,"May"=>31,"June"=>30,"July"=>31,"August"=>31,"September"=>30,"October"=>31,"November"=>30,"December"=>31}[end_month]
      # c_s_month = {"January"=>1,"February"=>2,"March"=>3,"April"=>4,"May"=>5,"June"=>6,"July"=>7,"August"=>8,"September"=>9,"October"=>10,"November"=>11,"December"=>12}[c_start_month]
      # c_e_month = {"January"=>1,"February"=>2,"March"=>3,"April"=>4,"May"=>5,"June"=>6,"July"=>7,"August"=>8,"September"=>9,"October"=>10,"November"=>11,"December"=>12}[c_end_month]
      # c_e_day = {"January"=>31,"February"=>28,"March"=>31,"April"=>30,"May"=>31,"June"=>30,"July"=>31,"August"=>31,"September"=>30,"October"=>31,"November"=>30,"December"=>31}[c_end_month]

      if s_month > e_month
        runner.registerError("Invalid fault start/end month combination.")
        return false
      end
      # if c_s_month > c_e_month
      #   runner.registerError("Invalid cooling start/end month combination.")
      #   return false
      # end

      active_months = Array.new
      (s_month..e_month).to_a.each do |month|
        active_months << month
      end
      # c_active_months = Array.new
      # (c_s_month..c_e_month).to_a.each do |month|
      #   c_active_months << month
      # end

      # faulted/non-faulted state at each timestep
      timestepfaultstate = TimestepFaultState.new(model)
      timestepfaultstate.make("./faulted_timesteps.csv",
                              [active_months],
                              [[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32]],
                              [[no_reset]],
                              [[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24]])

      thermalzone = runner.getStringArgumentValue("zone",user_arguments)
	  model.getThermalZones.each do |zone|
		if thermalzone.to_s == zone.name.to_s
			thermalzone = zone
			break
		end
	  end
	  
      # #check the thermalzone for reasonableness
      # if thermalzone.empty?
        # handle = runner.getStringArgumentValue("zone",user_arguments)
        # if handle.empty?
          # runner.registerError("No zone was chosen.")
        # else
          # runner.registerError("The selected zone with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        # end
        # return false
      # else
        # if not thermalzone.get.to_ThermalZone.empty?
          # thermalzone = thermalzone.get.to_ThermalZone.get
        # else
          # runner.registerError("Script Error - argument not showing up as zone.")
          # return false
        # end
      # end  #end of if zone.empty?

      thermostatsetpointdualsetpoint = thermalzone.thermostatSetpointDualSetpoint
      if thermostatsetpointdualsetpoint.empty?
        runner.registerWarning("Cannot find existing thermostat for thermal zone '#{thermalzone.name}', skipping. No changes made.")
      end
      thermostatsetpointdualsetpoint = thermostatsetpointdualsetpoint.get.clone.to_ThermostatSetpointDualSetpoint.get

      # Heating
      heatingrulesetschedule = thermostatsetpointdualsetpoint.heatingSetpointTemperatureSchedule.get.to_Schedule.get.clone.to_ScheduleRuleset.get

      h_rule = OpenStudio::Model::ScheduleRule.new(heatingrulesetschedule)
      h_rule.setName("#{no_reset} with default day schedule")
      # copy to the day schedule the ruleset's DEFAULT day schedule
      h_rule_default_day = heatingrulesetschedule.defaultDaySchedule
      times = h_rule_default_day.times
      values = h_rule_default_day.values
      h_rule_clone_day_schedule = h_rule.daySchedule
      h_rule_clone_day_schedule.clearValues
      for i in 0..(times.size - 1)
        h_rule_clone_day_schedule.addValue(times[i], values[i])
      end
      # apply the new fault range
      h_rule.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(start_month),1))
      h_rule.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(end_month),e_day))
      # apply only the selected day of week
      h_rule.setApplySunday(false)
      h_rule.setApplyMonday(false)
      h_rule.setApplyTuesday(false)
      h_rule.setApplyWednesday(false)
      h_rule.setApplyThursday(false)
      h_rule.setApplyFriday(false)
      h_rule.setApplySaturday(false)
      if no_reset == "Sunday"
        h_rule.setApplySunday(true)
      elsif no_reset == "Monday"
        h_rule.setApplyMonday(true)
      elsif no_reset == "Tuesday"
        h_rule.setApplyTuesday(true)
      elsif no_reset == "Wednesday"
        h_rule.setApplyWednesday(true)
      elsif no_reset == "Thursday"
        h_rule.setApplyThursday(true)
      elsif no_reset == "Friday"
        h_rule.setApplyFriday(true)
      elsif no_reset == "Saturday"
        h_rule.setApplySaturday(true)
      end
      runner.registerInfo("Setting #{no_reset}=false for heating '#{h_rule.name}' rule with priority #{h_rule.ruleIndex} in '#{thermalzone.name}'.")
      heatingrulesetschedule.setScheduleRuleIndex(h_rule,0)

      #assign the heating temperature schedule with faults to the thermostat
      thermostatsetpointdualsetpoint.setHeatingSetpointTemperatureSchedule(heatingrulesetschedule)

      # Cooling
      coolingrulesetschedule = thermostatsetpointdualsetpoint.coolingSetpointTemperatureSchedule.get.to_Schedule.get.clone.to_ScheduleRuleset.get

      c_rule = OpenStudio::Model::ScheduleRule.new(coolingrulesetschedule)
      c_rule.setName("#{no_reset} with default day schedule")
      # copy to the day schedule the ruleset's DEFAULT day schedule
      c_rule_default_day = coolingrulesetschedule.defaultDaySchedule
      times = c_rule_default_day.times
      values = c_rule_default_day.values
      c_rule_clone_day_schedule = c_rule.daySchedule
      c_rule_clone_day_schedule.clearValues
      for i in 0..(times.size - 1)
        c_rule_clone_day_schedule.addValue(times[i], values[i])
      end
      # apply the new fault range
      c_rule.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(start_month),1))
      c_rule.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(end_month),e_day))
      # apply only the selected day of week
      c_rule.setApplySunday(false)
      c_rule.setApplyMonday(false)
      c_rule.setApplyTuesday(false)
      c_rule.setApplyWednesday(false)
      c_rule.setApplyThursday(false)
      c_rule.setApplyFriday(false)
      c_rule.setApplySaturday(false)
      if no_reset == "Sunday"
        c_rule.setApplySunday(true)
      elsif no_reset == "Monday"
        c_rule.setApplyMonday(true)
      elsif no_reset == "Tuesday"
        c_rule.setApplyTuesday(true)
      elsif no_reset == "Wednesday"
        c_rule.setApplyWednesday(true)
      elsif no_reset == "Thursday"
        c_rule.setApplyThursday(true)
      elsif no_reset == "Friday"
        c_rule.setApplyFriday(true)
      elsif no_reset == "Saturday"
        c_rule.setApplySaturday(true)
      end
      runner.registerInfo("Setting #{no_reset}=false for cooling '#{c_rule.name}' rule with priority #{c_rule.ruleIndex} in '#{thermalzone.name}'.")
      coolingrulesetschedule.setScheduleRuleIndex(c_rule,0)

      #assign the cooling temperature schedule with faults to the thermostat
      thermostatsetpointdualsetpoint.setCoolingSetpointTemperatureSchedule(coolingrulesetschedule)

      #assign the thermostat to the zone
      thermalzone.setThermostatSetpointDualSetpoint(thermostatsetpointdualsetpoint)

    end

    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
NoReset.new.registerWithApplication