#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

require 'date'
require_relative 'resources/global_const'
require_relative 'resources/misc_arguments'
require_relative 'resources/util'

#start the measure
class ThermostatBias < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "ThermostatBias"
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # make choice argument for thermal zone
    zone_handles, zone_display_names = pass_zone(model, $allzonechoices)
    zone = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
        'zone', zone_display_names, zone_display_names, true
    )
    zone.setDisplayName("Zone. Choose #{$allzonechoices} if you want to impose the fault in all zones")
    args << zone

    #make choice argument for thermal zone
    # todo - may need to update this to handle *Entire Building* as an option, or can run this multiple times on same model across different zones
    zone = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("zone", zone_display_names, zone_display_names, true)
    zone.setDisplayName("Zone")
    args << zone

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

    # heating season setpoint bias
    bias_level = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("bias_level", false)
    bias_level.setDisplayName("Enter the constant setpoint bias level [K] [0=Non faulted case]")
    bias_level.setDefaultValue(0)
    args << bias_level

    start_month = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("start_month", months, true)
    start_month.setDisplayName("Fault active start month")
    start_month.setDefaultValue("January")
    args << start_month

    end_month = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("end_month", months, true)
    end_month.setDisplayName("Fault active end month")
    end_month.setDefaultValue("December")
    args << end_month

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    if runner.getDoubleArgumentValue("bias_level",user_arguments) != 0

      start_month = runner.getStringArgumentValue("start_month",user_arguments)
      end_month = runner.getStringArgumentValue("end_month",user_arguments)

      s_month = {"January"=>1,"February"=>2,"March"=>3,"April"=>4,"May"=>5,"June"=>6,"July"=>7,"August"=>8,"September"=>9,"October"=>10,"November"=>11,"December"=>12}[start_month]
      e_month = {"January"=>1,"February"=>2,"March"=>3,"April"=>4,"May"=>5,"June"=>6,"July"=>7,"August"=>8,"September"=>9,"October"=>10,"November"=>11,"December"=>12}[end_month]
      e_day = {"January"=>31,"February"=>28,"March"=>31,"April"=>30,"May"=>31,"June"=>30,"July"=>31,"August"=>31,"September"=>30,"October"=>31,"November"=>30,"December"=>31}[end_month]

      if s_month > e_month
        runner.registerError("Invalid fault start/end month combination.")
        return false
      end

      active_months = Array.new
      (s_month..e_month).to_a.each do |month|
        active_months << month
      end

      # faulted/non-faulted state at each timestep
      timestepfaultstate = TimestepFaultState.new(model)
      timestepfaultstate.make("./faulted_timesteps.csv",
                              [active_months],
                              [[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32]],
                              [["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]],
                              [[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24]])

      # get the heating and cooling season setpoint offsets
      biasLevel = runner.getDoubleArgumentValue("bias_level",user_arguments)

      # todo - add in initial and final condition

      # loop through selected thermal zones (array of 1 or all zones)
      thermalzones = obtainzone('zone', model, runner, user_arguments)
      thermalzones.each do |thermalzone|

        thermostatsetpointdualsetpoint = thermalzone.thermostatSetpointDualSetpoint
        if thermostatsetpointdualsetpoint.empty?
          runner.registerWarning("Cannot find existing thermostat for thermal zone '#{thermalzone.name}'. No changes made ot this zone.")
          next
        end
        thermostatsetpointdualsetpoint = thermostatsetpointdualsetpoint.get.clone.to_ThermostatSetpointDualSetpoint.get

        # Heating
        schedule = thermostatsetpointdualsetpoint.heatingSetpointTemperatureSchedule
        if schedule.is_initialized and schedule.get.to_Schedule.is_initialized and schedule.get.to_Schedule.get.to_ScheduleRuleset.is_initialized
          heatingrulesetschedule = schedule.get.to_Schedule.get.clone.to_ScheduleRuleset.get
        else
          runner.registerWarning("Skipping #{thermalzone.name} because it is either missing heating setpoint schedule or the schedule is not ScheduleRulesets.")
          next
        end

        h_rules = heatingrulesetschedule.scheduleRules

        h_rules.each_with_index do |h_rule,i|

          rule_name = h_rule.name
          dayschedule_name = h_rule.daySchedule.name
          h_rule_clone = h_rule.clone
          h_rule_clone = h_rule_clone.to_ScheduleRule.get
          h_rule_clone.setName("#{rule_name} with new start/end dates")
          h_rule_clone.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(start_month),1))
          h_rule_clone.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(end_month),e_day))
          h_ruleday_clone = h_rule_clone.daySchedule
          h_ruleday_clone.setName("#{dayschedule_name} with offset")
          times = h_ruleday_clone.times
          values = h_ruleday_clone.values
          h_ruleday_clone.clearValues
          for i in 0..(times.size - 1)
            h_ruleday_clone.addValue(times[i], values[i] - biasLevel)
          end

          # todo - better to edit existing rules
          heatingrulesetschedule.setScheduleRuleIndex(h_rule_clone, [0, h_rule.ruleIndex-1].max)

        end

        # todo - seems better to replace default day vs. building up a rule to replace it
        defaultday_name = heatingrulesetschedule.defaultDaySchedule.name
        h_defaultday_clone = heatingrulesetschedule.defaultDaySchedule.clone
        h_defaultday_clone = h_defaultday_clone.to_ScheduleDay.get
        times = h_defaultday_clone.times
        values = h_defaultday_clone.values
        defaultday_rule = OpenStudio::Model::ScheduleRule.new(heatingrulesetschedule)
        defaultday_rule.setName("#{defaultday_name} with new start/end dates")
        defaultday_rule.setApplySunday(true)
        defaultday_rule.setApplyMonday(true)
        defaultday_rule.setApplyTuesday(true)
        defaultday_rule.setApplyWednesday(true)
        defaultday_rule.setApplyThursday(true)
        defaultday_rule.setApplyFriday(true)
        defaultday_rule.setApplySaturday(true)
        defaultday_rule.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(start_month),1))
        defaultday_rule.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(end_month),e_day))
        default_day = defaultday_rule.daySchedule
        default_day.setName("#{defaultday_name} with offset")
        default_day.clearValues
        for i in 0..(times.size - 1)
          default_day.addValue(times[i], values[i] - biasLevel)
        end

        heatingrulesetschedule.setScheduleRuleIndex(defaultday_rule,h_rules.length*2)

        # Cooling
        # todo - similar comments to heating
        schedule = thermostatsetpointdualsetpoint.coolingSetpointTemperatureSchedule
        if schedule.is_initialized and schedule.get.to_Schedule.is_initialized and schedule.get.to_Schedule.get.to_ScheduleRuleset.is_initialized
          coolingrulesetschedule = schedule.get.to_Schedule.get.clone.to_ScheduleRuleset.get
        else
          runner.registerWarning("Skipping #{thermalzone.name} because it is either missing cooling setpoint schedule or the schedule is not ScheduleRulesets.")
          next
        end

        c_rules = coolingrulesetschedule.scheduleRules

        c_rules.each_with_index do |c_rule,i|

          rule_name = c_rule.name
          dayschedule_name = c_rule.daySchedule.name
          c_rule_clone = c_rule.clone
          c_rule_clone = c_rule_clone.to_ScheduleRule.get
          c_rule_clone.setName("#{rule_name} with new start/end dates")
          c_rule_clone.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(start_month),1))
          c_rule_clone.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(end_month),e_day))
          c_ruleday_clone = c_rule_clone.daySchedule
          c_ruleday_clone.setName("#{dayschedule_name} with offset")
          times = c_ruleday_clone.times
          values = c_ruleday_clone.values
          c_ruleday_clone.clearValues
          for i in 0..(times.size - 1)
            c_ruleday_clone.addValue(times[i], values[i] - biasLevel)
          end

          coolingrulesetschedule.setScheduleRuleIndex(c_rule_clone, [0, c_rule.ruleIndex-1].max)

        end

        defaultday_name = coolingrulesetschedule.defaultDaySchedule.name
        c_defaultday_clone = coolingrulesetschedule.defaultDaySchedule.clone
        c_defaultday_clone = c_defaultday_clone.to_ScheduleDay.get
        times = c_defaultday_clone.times
        values = c_defaultday_clone.values
        defaultday_rule = OpenStudio::Model::ScheduleRule.new(coolingrulesetschedule)
        defaultday_rule.setName("#{defaultday_name} with new start/end dates")
        defaultday_rule.setApplySunday(true)
        defaultday_rule.setApplyMonday(true)
        defaultday_rule.setApplyTuesday(true)
        defaultday_rule.setApplyWednesday(true)
        defaultday_rule.setApplyThursday(true)
        defaultday_rule.setApplyFriday(true)
        defaultday_rule.setApplySaturday(true)
        defaultday_rule.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(start_month),1))
        defaultday_rule.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(end_month),e_day))
        default_day = defaultday_rule.daySchedule
        default_day.setName("#{defaultday_name} with offset")
        default_day.clearValues
        for i in 0..(times.size - 1)
          default_day.addValue(times[i], values[i] - biasLevel)
        end

        coolingrulesetschedule.setScheduleRuleIndex(defaultday_rule,c_rules.length*2)

        #assign the heating temperature schedule with faults to the thermostat
        thermostatsetpointdualsetpoint.setHeatingSetpointTemperatureSchedule(heatingrulesetschedule)

        #assign the cooling temperature schedule with faults to the thermostat
        thermostatsetpointdualsetpoint.setCoolingSetpointTemperatureSchedule(coolingrulesetschedule)

        #assign the thermostat to the zone
        thermalzone.setThermostatSetpointDualSetpoint(thermostatsetpointdualsetpoint)
      end

    end

    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
ThermostatBias.new.registerWithApplication