# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require "#{File.dirname(__FILE__)}/resources/schedulesearch"
require "#{File.dirname(__FILE__)}/resources/misc_eplus_func"
$object_types = %w(Pump:ConstantSpeed Pump:VariableSpeed)
$err_check = true

# start the measure
class PumpMotorEfficiencyFault < OpenStudio::Ruleset::WorkspaceUserScript
  # human readable name
  def name
    return 'Pump Motor Efficiency Fault'
  end

  # human readable description
  def description
    return 'This Measure simulates the effect of pump motor efficiency ' \
      'degradation due to stator winding fault or motor bearing fault in ' \
      'air ducts to the building performance.'
  end

  # human readable description of workspace approach
  def workspaceer_description
    return 'To use this Measure, enter the Fan object (Pump:ConstantSpeed ' \
      'and Pump:VariableSpeed) to be faulted and a fault level as a ' \
      'degradation factor of fan efficiency. It does not work with any fan ' \
      'objects housed by other ZoneHVAC objects.'
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # make choice arguments for Coil:Cooling:DX:SingleSpeed
    pump_choice = OpenStudio::Ruleset::OSArgument.makeStringArgument('pump_choice', true)
    pump_choice.setDisplayName('Enter the name of the faulted Pump:ConstantSpeed and Pump:VariableSpeed')
    pump_choice.setDefaultValue('')
    args << pump_choice

    # make a double argument for the fault level
    # it should range between 0 and 1. 0 means no degradation
    # and 0.9 means that percentage drop of maximum volume flow rate is 90%
    eff_degrad_fac = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('eff_degrad_fac', false)
    eff_degrad_fac.setDisplayName('Degradation factor of the total efficiency of the fan during the simulation period. If the fan is not faulted, set it to zero.')
    eff_degrad_fac.setDefaultValue(0.15)  # default degradation level to be 15%
    args << eff_degrad_fac

    # choice of schedules for the presence of fault. 0 for no fault and 1 means total degradation
    sch_choice = OpenStudio::Ruleset::OSArgument.makeStringArgument('sch_choice', false)
    sch_choice.setDisplayName('Enter the name of the schedule of the fault level. If you do not have a schedule, leave this blank.')
    sch_choice.setDefaultValue('')
    args << sch_choice

    return args
  end

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # obtain values
    pump_choice, eff_degrad_fac, sch_choice, validation = \
      _get_inputs(workspace, runner, user_arguments)
    unless validation
      return false
    end

    # create schedule_exist
    schedule_exist = true
    if sch_choice.eql?('')
      schedule_exist = false
    end

    if schedule_exist # write ems codes

      return _ems_prep_and_write(workspace, runner, user_arguments,
                                 pump_choice, eff_degrad_fac, sch_choice)

    else # modify workspace entries
      if eff_degrad_fac == 0
        runner.registerAsNotApplicable(
          "Efficiency degradation at #{pump_choice} is zero. " \
          'Exiting PumpMotorEfficiencyFault ......'
        )
        return true
      end
      return _workspacechange(workspace, runner, user_arguments,
                              pump_choice, eff_degrad_fac)
    end

    # report final condition of workspace
    runner.registerFinalCondition("Imposed pump efficiency degradation at #{eff_degrad_fac} on #{pump_choice}.")

    return true
  end

  def _get_inputs(workspace, runner, user_arguments)
    # This function passes the inputs in user_arguments, other than the ones
    # to check if the function should run, to the run function. It also
    # returns an extra boolean false if the inputs are invalid

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(workspace), user_arguments)
      return '', 0, '', false
    end

    pump_choice = runner.getStringArgumentValue('pump_choice', user_arguments)
    eff_degrad_fac = runner.getDoubleArgumentValue('eff_degrad_fac', user_arguments)
    sch_choice = runner.getStringArgumentValue('sch_choice', user_arguments)
    runner.registerInitialCondition("Imposing pump efficiency degradation on #{pump_choice}.")
    return pump_choice, eff_degrad_fac, sch_choice, true
  end

  def _ems_prep_and_write(workspace, runner, user_arguments,
                          pump_choice, eff_degrad_fac, sch_choice)
    # This function returns true if it write ems code successfully
    # after more detailed checkeing of the user inputs

    # write schedules for fault model
    string_objects = []
    sch_choice, checkschedule = _checkscheduletypelimit(
      workspace, runner, pump_choice, eff_degrad_fac, sch_choice,
      string_objects
    )
    unless checkschedule
      return false
    end

    # find the old pump efficiency
    old_eff, eff_exist = _get_old_pump_efficiency(workspace, runner, pump_choice)
    unless eff_exist
      return false
    end

    # write EMS Program, ProgramCallingManager and Actuators to change fan efficiency value at the degraded condition
    _ems_code_writer(workspace, pump_choice, sch_choice, old_eff, string_objects)

    # add all of the strings to workspace to create IDF objects
    append_workspace_objects(workspace, string_objects)

    return true
  end

  def _workspacechange(workspace, runner, user_arguments, pump_choice, eff_degrad_fac)
    # This function changes the energyplus input entry to efficiency to change the efficiency
    # of the pump
    no_pump_changed = true
    $object_types.each do |object_type|
      pumps = get_workspace_objects(workspace, object_type)
      pump_chosen = pumps[0]
      pumps.each do |pump|
        if pass_string(pump, 0).eql?(pump_choice)
          pump_chosen = pump
          no_pump_changed = false
          old_eff = pass_float(pump_chosen, 6)
          new_eff = old_eff * (1.0 - eff_degrad_fac)
          pump_chosen.setDouble(6, new_eff)
          break
        end
      end
    end

    # give an error for the name if no RTU is changed
    if no_pump_changed
      runner.registerError("Measure PumpMotorEfficiencyFault cannot find #{pump_choice}. Exiting......")
      return false
    end

    return true
  end

  def _checkscheduletypelimit(workspace, runner, pump_choice, eff_degrad_fac,
                              sch_choice, string_objects)
    # This function checks if the existing schedule matches the limits.
    # If there is no schedule, create one and return the schedule name

    # create schedule_exist
    schedule_exist = true
    if sch_choice.eql?('')
      schedule_exist = false
    end

    # if a user-defined schedule is used, check if the schedule exists and
    # if the schedule has the correct schedule type limits
    if schedule_exist
      # check if the schedule exists
      bool_schedule, schedule_type_limit, schedule_code = \
        schedule_search(workspace, sch_choice)

      unless bool_schedule
        runner.registerError(
          "User-defined schedule #{sch_choice} does not exist. Exiting......"
        )
        return sch_choice, false
      end
    else
      # if there is no user-defined schedule, check if the fouling level
      # is between 0 and 1
      if eff_degrad_fac < 0.0 || eff_degrad_fac > 1.0
        runner.registerError(
          "Pump Efficiency Degradation Level #{eff_degrad_fac} for " \
          " #{pump_choice} is outside the range 0 to 1.0. Exiting......"
        )
        return sch_choice, false
      end
      pump_shortstr = name_cut(pump_choice)
      scheduletypelimitname = "Fraction#{pump_shortstr}"
      string_objects << "
        ScheduleTypeLimits,
          #{scheduletypelimitname},                             !- Name
          0,                                      !- Lower Limit Value {BasedOnField A3}
          1,                                      !- Upper Limit Value {BasedOnField A3}
          Continuous;                             !- Numeric Type
      "
      # set a unique name for the schedule according to the component and the fault
      sch_choice = "Bearing#{pump_shortstr}_SCH"

      # create a Schedule:Compact object with a schedule type limit "Fractional" that are usually
      # created in OpenStudio for continuous schedules bounded by 0 and 1
      string_objects << "
        Schedule:Constant,
          #{sch_choice},         !- Name
          #{scheduletypelimitname},                       !- Schedule Type Limits Name
          #{eff_degrad_fac};                    !- Hourly Value
      "
      return sch_choice, true
    end
  end

  def _get_old_pump_efficiency(workspace, runner, pump_choice)
    # This function returns the nominal efficiency of the faulted pump

    no_pump_changed = true
    old_eff = 0.0
    $object_types.each do |object_type|
      pumps = get_workspace_objects(workspace, object_type)
      pump_chosen = pumps[0]
      pumps.each do |pump|
        if pass_string(pump, 0).eql?(pump_choice)
          pump_chosen = pump
          no_pump_changed = false
          old_eff = pass_float(pump_chosen, 4)
          break
        end
      end
    end

    # give an error for the name if no RTU is changed
    if no_pump_changed
      runner.registerError("Measure PumpMotorEfficiencyFault cannot find #{pump_choice}. Exiting......")
      return old_eff, false
    end

    return old_eff, true
  end

  def _ems_code_writer(workspace, pump_choice, sch_choice, old_eff, string_objects)
    # This function writes ems code to string_objects
    pump_shortstr = name_cut(pump_choice)
    sch_obj_name = "Sen#{sch_choice}"

    string_objects << ems_sensor_str(sch_obj_name, sch_choice, 'Schedule Value')

    string_objects << "
      EnergyManagementSystem:Program,
        EfficiencyChange#{pump_shortstr},          !- Name
        SET TEMP = #{old_eff}*#{sch_obj_name};          !- Program Line 1
        SET NewEfficiency#{pump_shortstr} = #{old_eff}-TEMP;          !- Program Line 1
    "

    string_objects << "
      EnergyManagementSystem:ProgramCallingManager,
        EMSCallEfficiencyChange#{pump_shortstr},          !- Name
        AfterPredictorBeforeHVACManagers, !- EnergyPlus Model Calling Point, EndofSystemSizing will not impose the value correctly
        EfficiencyChange#{pump_shortstr}; !- Program Name 1
    "

    string_objects << ems_actuator_str("NewEfficiency#{pump_shortstr}",
                                       pump_choice, 'Pump',
                                       'Pump Pressure Rise')

    # only add Output:EnergyManagementSystem if it does not exist in the code
    ems_output_writer(workspace, string_objects, err_check = $err_check)

    return true
  end
end

# register the measure to be used by the application
PumpMotorEfficiencyFault.new.registerWithApplication
