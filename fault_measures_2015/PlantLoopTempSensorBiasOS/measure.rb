# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

require 'date'
require "#{File.dirname(__FILE__)}/resources/util"

# start the measure
class PlantLoopTempSensorBiasOS < OpenStudio::Ruleset::ModelUserScript
  def name
    return 'Plant Equipment Temperature Sensor Bias'
  end

  # human readable description
  def description
    return 'This Measure simulates the effect of a bias of a temperature sensor along the plant loop.'
  end

  # human readable description of workspace approach
  def modeler_description
    return 'To use this Measure, enter the name of the appropriate PlantLoop object. Enter the level of bias you want to impose at the sensor.'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # make a choice argument for model objects
    plantloop_handles = OpenStudio::StringVector.new
    plantloop_display_names = OpenStudio::StringVector.new

    # putting model object and names into hash
    plantloop_args = model.getPlantLoops
    plantloop_args_hash = {}
    plantloop_args.each do |plantloop_arg|
      plantloop_args_hash[plantloop_arg.name.to_s] = plantloop_arg
    end

    # looping through sorted hash of model objects
    plantloop_args_hash.sort.map do |key, value|
      plantloop_handles << value.handle.to_s
      plantloop_display_names << key
    end

    # make choice argument for plantloop
    plantloop = OpenStudio::Ruleset::OSArgument.makeChoiceArgument('plantloop', plantloop_handles, plantloop_display_names, true)
    plantloop.setDisplayName('Choose the PlantLoop where its Loop Temperature sensor is faulted.')
    plantloop.setDefaultValue(plantloop_display_names[0])
    args << plantloop

    months = OpenStudio::StringVector.new
    months << 'January'
    months << 'February'
    months << 'March'
    months << 'April'
    months << 'May'
    months << 'June'
    months << 'July'
    months << 'August'
    months << 'September'
    months << 'October'
    months << 'November'
    months << 'December'

    # heating season setpoint bias
    bias_level = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('bias_level', false)
    bias_level.setDisplayName('Enter the constant bias [0=Non faulted case] (K)')
    bias_level.setDefaultValue(2)
    args << bias_level

    start_month = OpenStudio::Ruleset::OSArgument.makeChoiceArgument('start_month', months, true)
    start_month.setDisplayName('Fault active start month')
    start_month.setDefaultValue('January')
    args << start_month

    end_month = OpenStudio::Ruleset::OSArgument.makeChoiceArgument('end_month', months, true)
    end_month.setDisplayName('Fault active end month')
    end_month.setDefaultValue('December')
    args << end_month

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    runner.registerInitialCondition('Running PlantLoopTempSensorBiasOS......')

    if runner.getDoubleArgumentValue('bias_level', user_arguments) != 0

      start_month = runner.getStringArgumentValue('start_month', user_arguments)
      end_month = runner.getStringArgumentValue('end_month', user_arguments)

      s_month = { 'January' => 1, 'February' => 2, 'March' => 3, 'April' => 4, 'May' => 5, 'June' => 6, 'July' => 7, 'August' => 8, 'September' => 9, 'October' => 10, 'November' => 11, 'December' => 12 }[start_month]
      e_month = { 'January' => 1, 'February' => 2, 'March' => 3, 'April' => 4, 'May' => 5, 'June' => 6, 'July' => 7, 'August' => 8, 'September' => 9, 'October' => 10, 'November' => 11, 'December' => 12 }[end_month]
      e_day = { 'January' => 31, 'February' => 28, 'March' => 31, 'April' => 30, 'May' => 31, 'June' => 30, 'July' => 31, 'August' => 31, 'September' => 30, 'October' => 31, 'November' => 30, 'December' => 31 }[end_month]

      if s_month > e_month
        runner.registerError('Invalid fault start/end month combination.')
        return false
      end

      active_months = []
      (s_month..e_month).to_a.each do |month|
        active_months << month
      end

      # faulted/non-faulted state at each timestep
      timestepfaultstate = TimestepFaultState.new(model)
      timestepfaultstate.make('./faulted_timesteps.csv',
                              [active_months],
                              [[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32]],
                              [%w(Sunday Monday Tuesday Wednesday Thursday Friday Saturday)],
                              [[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24]])

      # get the heating and cooling season setpoint offsets
      setpointoffset = runner.getDoubleArgumentValue('bias_level', user_arguments)
      setpointoffset = -setpointoffset

      plantloop = runner.getOptionalWorkspaceObjectChoiceValue('plantloop', user_arguments, model)

      # check the plantloop for reasonableness
      if plantloop.empty?
        handle = runner.getStringArgumentValue('plantloop', user_arguments)
        if handle.empty?
          runner.registerError('No plantloop was chosen.')
        else
          runner.registerError("The selected plantloop with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
        end
        return false
      end  # end of if zone.empty?

      # find the setpoint manager involved
      # currently work with SetpointManager:Scheduled only
      plantloop = plantloop.get.to_PlantLoop.get
      setpoint_node = plantloop.loopTemperatureSetpointNode
      runner.registerInfo("Found node #{setpoint_node.name}.")

      setpointmanagerscheduleds = model.getSetpointManagerScheduleds
      plantloop_setpointmanagerscheduleds = []
      found_setpointmanagerschedueld = false
      setpointmanagerscheduleds.each do |setpointmanagerscheduled|
        if setpointmanagerscheduled.setpointNode.get.name.to_s.eql?(setpoint_node.name.to_s)
          # check the control variable of setpoint manager
          ctrl_var = setpointmanagerscheduled.controlVariable.to_s
          if ctrl_var.eql?('Temperature') || ctrl_var.eql?('MaximumTemperature') || ctrl_var.eql?('MinimumTemperature')
            runner.registerInfo("Found OS:SetpointManager:Scheduled #{setpointmanagerscheduled.name}.")
            plantloop_setpointmanagerscheduleds << setpointmanagerscheduled
            found_setpointmanagerschedueld = true
          end
        end
      end
      unless found_setpointmanagerschedueld
        runner.registerError('The PlantLoop loop temperature is not controlled with SetpointManager:Scheduled and the Measure PlantLoopTempSensorBiasOS is not applicable to the model. Terminating......')
        return false
      end

      # loop through all related SetpointManager:Scheduled to offset all temperature, maximum temperature or minimum temperature schedule
      plantloop_setpointmanagerscheduleds.each do |plantloop_setpointmanagerscheduled|
        setpointschedule = plantloop_setpointmanagerscheduled.schedule

        # offsetting
        rulesetschedule = setpointschedule.clone.to_ScheduleRuleset.get

        rules = rulesetschedule.scheduleRules
        runner.registerInfo("Found OS:Schedule:Ruleset #{rulesetschedule.name} with #{rules.length} rules.")

        rules.each_with_index do |h_rule, i|
          rule_name = h_rule.name
          dayschedule_name = h_rule.daySchedule.name
          h_rule_clone = h_rule.clone
          h_rule_clone = h_rule_clone.to_ScheduleRule.get
          h_rule_clone.setName("#{rule_name} with new start/end dates")
          h_rule_clone.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(start_month), 1))
          h_rule_clone.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(end_month), e_day))
          h_ruleday_clone = h_rule_clone.daySchedule
          h_ruleday_clone.setName("#{dayschedule_name} with offset")
          times = h_ruleday_clone.times
          values = h_ruleday_clone.values
          h_ruleday_clone.clearValues
          (0..(times.size - 1)).each do |ii|
            h_ruleday_clone.addValue(times[ii], values[ii] + setpointoffset)
          end

          rulesetschedule.setScheduleRuleIndex(h_rule_clone, i)
        end

        defaultday_name = rulesetschedule.defaultDaySchedule.name
        h_defaultday_clone = rulesetschedule.defaultDaySchedule.clone
        h_defaultday_clone = h_defaultday_clone.to_ScheduleDay.get
        times = h_defaultday_clone.times
        values = h_defaultday_clone.values
        defaultday_rule = OpenStudio::Model::ScheduleRule.new(rulesetschedule)
        defaultday_rule.setName("#{defaultday_name} with new start/end dates")
        defaultday_rule.setApplySunday(true)
        defaultday_rule.setApplyMonday(true)
        defaultday_rule.setApplyTuesday(true)
        defaultday_rule.setApplyWednesday(true)
        defaultday_rule.setApplyThursday(true)
        defaultday_rule.setApplyFriday(true)
        defaultday_rule.setApplySaturday(true)
        defaultday_rule.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(start_month), 1))
        defaultday_rule.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new(end_month), e_day))
        default_day = defaultday_rule.daySchedule
        default_day.setName("#{defaultday_name} with offset")
        default_day.clearValues
        (0..(times.size - 1)).each do |i|
          default_day.addValue(times[i], values[i] + setpointoffset)
        end

        rulesetschedule.setScheduleRuleIndex(defaultday_rule, rules.length * 2)

        # assign the schedules with faults to the setpoint manager
        plantloop_setpointmanagerscheduled.setSchedule(rulesetschedule)
      end

      runner.registerFinalCondition("Imposed bias level on #{plantloop.name}.")
    else
      runner.registerFinalCondition('Bias level on PlantLoopTempSensorBiasOS is zero. Exiting......')
    end

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
PlantLoopTempSensorBiasOS.new.registerWithApplication
