#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

require 'date'
require 'openstudio-standards' # this is used to get min/max values from thermostat schedules for reporting purposes

# require all .rb files in resources folder
Dir[File.dirname(__FILE__) + '/resources/*.rb'].each {|file| require file }

# resource file modules
include OsLib_FDD

#start the measure
class ThermostatBias < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Thermostat Measurement Bias"
  end
  
  # human readable description
  def description
    return "Drift of the thermostat temperature sensor over time can lead to increased energy use and/or reduced occupant comfort. This measure simulates a biased thermostat by modifying the Schedule:Compact object in EnergyPlus assigned to heating and cooling set points. The fault intensity (F) for this fault is defined as the thermostat measurement bias (K), which is also specified as one of the inputs."
  end
  
  # human readable description of modeling approach
  def modeler_description
    return "Four user inputs are required and, based on these user inputs, the original (non-faulted) heating and cooling set point schedules in the building model will be replaced with a biased temperature set point by the equation below. If the reading of the thermostat is biased with +1oC, the actual space temperature should be maintained 1oC lower than the reading. Thus, the set point for the space is corrected by subtracting the original set point from the biased level. T_(stpt,heat,F)=T_(stpt,heat)-F / T_(stpt,cool,F)=T_(stpt,cool)-F"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # make choice argument for thermal zone
    zone_handles, zone_display_names = pass_zone(model, $allzonechoices)
    zone = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
        'zone', zone_display_names, zone_display_names, true
    )
    zone.setDefaultValue(zone_display_names[0])
    zone.setDisplayName("Zone. Choose #{$allzonechoices} if you want to impose the fault in all zones")
    args << zone

    #make choice argument for thermal zone
    #zone = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("zone", zone_display_names, zone_display_names, true)
    #zone.setDisplayName("Zone")
    #args << zone

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

      # add in initial and final condition
      setpoint_values = {}
      setpoint_values[:init_htg_min] = []
      setpoint_values[:init_htg_max] = []
      setpoint_values[:init_clg_min] = []
      setpoint_values[:init_clg_max] = []
      setpoint_values[:final_htg_min] = []
      setpoint_values[:final_htg_max] = []
      setpoint_values[:final_clg_min] = []
      setpoint_values[:final_clg_max] = []

      # num_hours_in_year constant
      if model.yearDescription.is_initialized and model.yearDescription.get.isLeapYear
        num_hours_in_year = 8784.0
      else
        num_hours_in_year = 8760.0 # if no yearDescripiton then assumed year 2009 is not leap year
      end

      # loop through selected thermal zones (array of 1 or all zones)
      thermalzones = obtainzone('zone', model, runner, user_arguments)
      thermalzones.each do |thermalzone|

        # get thermostat
        thermostatsetpointdualsetpoint = thermalzone.thermostatSetpointDualSetpoint
        if thermostatsetpointdualsetpoint.empty?
          runner.registerWarning("Cannot find existing thermostat for thermal zone '#{thermalzone.name}'. No changes made ot this zone.")
          next
        end
        thermostatsetpointdualsetpoint = thermostatsetpointdualsetpoint.get.clone.to_ThermostatSetpointDualSetpoint.get

        # get heating and cooling schedules (moving here so changes and reporting only happen if both exist)
        heatingrulesetschedule = thermostatsetpointdualsetpoint.heatingSetpointTemperatureSchedule
        if heatingrulesetschedule.is_initialized and heatingrulesetschedule.get.to_Schedule.is_initialized and heatingrulesetschedule.get.to_Schedule.get.to_ScheduleRuleset.is_initialized
          heatingrulesetschedule = heatingrulesetschedule.get.to_Schedule.get.clone.to_ScheduleRuleset.get
        else
          runner.registerWarning("Skipping #{thermalzone.name} because it is either missing heating setpoint schedule or the schedule is not ScheduleRulesets.")
          next
        end
        coolingrulesetschedule = thermostatsetpointdualsetpoint.coolingSetpointTemperatureSchedule
        if coolingrulesetschedule.is_initialized and coolingrulesetschedule.get.to_Schedule.is_initialized and coolingrulesetschedule.get.to_Schedule.get.to_ScheduleRuleset.is_initialized
          coolingrulesetschedule = coolingrulesetschedule.get.to_Schedule.get.clone.to_ScheduleRuleset.get
        else
          runner.registerWarning("Skipping #{thermalzone.name} because it is either missing cooling setpoint schedule or the schedule is not ScheduleRulesets.")
          next
        end

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

        # Alter Heating
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

        # Alter Cooling
        # todo - similar comments to heating
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

      end

      # register initial and final condition
      if setpoint_values[:init_htg_min].size > 0
        runner.registerInitialCondition("Initial heating setpoints in affected zones range from #{setpoint_values[:init_htg_min].min.round(1)} C to #{setpoint_values[:init_htg_max].max.round(1)} C. Initial cooling setpoints in affected zones range from #{setpoint_values[:init_clg_min].min.round(1)} C to #{setpoint_values[:init_clg_max].max.round(1)} C.")
        runner.registerFinalCondition("Final heating setpoints in affected zones range from #{setpoint_values[:final_htg_min].min.round(1)} C to #{setpoint_values[:final_htg_max].max.round(1)} C. Final cooling setpoints in affected zones range from #{setpoint_values[:final_clg_min].min.round(1)} C to #{setpoint_values[:final_clg_max].max.round(1)} C.")
      else
        runner.registerAsNotApplicable("No changes made, selected zones may not have had setpoint schedules, or they schedules may not have been ScheduleRulesets.")
      end

    else
      runner.registerAsNotApplicable("No changes made thermostat bias of 0.0 requested.")
    end

    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
ThermostatBias.new.registerWithApplication
