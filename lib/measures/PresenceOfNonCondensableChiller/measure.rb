# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require "#{File.dirname(__FILE__)}/resources/TransferCurveParameters"
require "#{File.dirname(__FILE__)}/resources/ScheduleSearch"
require "#{File.dirname(__FILE__)}/resources/EnterCoefficients"
require "#{File.dirname(__FILE__)}/resources/FaultCalculationChillerElectricEIR"
require "#{File.dirname(__FILE__)}/resources/FaultDefinitions"
require "#{File.dirname(__FILE__)}/resources/misc_func"

# define number of parameters in the model
$power_para_num = 6
$fault_type = 'NC'
$all_chiller_selection = '* ALL Chillers Selected *'

# start the measure
class PresenceOfNoncondensableChiller < OpenStudio::Ruleset::WorkspaceUserScript
  # human readable name
  def name
    return 'Presence Of Noncondensable in Chiller'
  end

  # human readable description
  def description
    return 'Following Cheung and Braun (2016), this Measure simulates the effect of noncondensable fault fault of water-cooled chillers with shell-and-tube condensers and evaporators to the building performance.'
  end

  # human readable description of workspace approach
  def modeler_description
    return 'To use this Measure, choose the Chiller:Electric:EIR object to be faulted and a schedule of fault level. Define the fault level as the ratio of the amount of refrigerant inside the object to the charge level recommended by the manufacturer. If the fault level is outside the range of zero and one, an error will occur. If the HVAC system is autosized, please run/apply the hardsizing OS measure before this Measure.'
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    list = OpenStudio::StringVector.new
    list << $all_chiller_selection
	  
    chillerelecs = workspace.getObjectsByType("Chiller:Electric:EIR".to_IddObjectType)
    chillerelecs.each do |chillerelec|
      list << chillerelec.name.to_s
    end

    #TODO: adding more chiller objects

    # make choice arguments for Chiller:Electric:EIR
    chiller_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("chiller_choice", list, true)
    chiller_choice.setDisplayName("Select the name of the faulted chiller. If you want to impose the fault on all chillers, select #{$all_chiller_selection}")
    chiller_choice.setDefaultValue($all_chiller_selection)
    args << chiller_choice

    # choice of schedules for the presence of fault. 0 for no fault and other numbers means fault level
    # schedule
    sch_choice = OpenStudio::Ruleset::OSArgument.makeStringArgument('sch_choice', false)
    sch_choice.setDisplayName('Enter the name of the schedule of the fault level. If you do not have a schedule, leave this blank.')
    sch_choice.setDefaultValue('')
    args << sch_choice

    # make a double argument for the fault level
    fault_level = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('fault_level', false)
    fault_level.setDisplayName('Ratio of the mass of noncondensable in the refrigerant circuit to the mass of noncondensable that the refrigerant circuit can hold at standard atmospheric pressure.')
    fault_level.setDefaultValue(0.03)
    args << fault_level

    # fault level limits
    max_fl = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('max_fl', true)
    max_fl.setDisplayName('Maximum value of fault level')
    max_fl.setDefaultValue(0.05) # default maximum level to be overcharged by 40%
    args << max_fl

    # noncondensable fault fault model
    args = enter_coefficients(args, $power_para_num, 'power_fault', [-18.86, -0.1033, 0.1616, 0.3135, 3.150, 0.8737], ' for the noncondensable fault fault model')

    min_evap_tmp_fault = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('min_evap_tmp_fault', true)
    min_evap_tmp_fault.setDisplayName('Minimum value of evaporator water outlet temperature for the noncondensable fault fault model (C)')
    min_evap_tmp_fault.setDefaultValue(4.0)
    args << min_evap_tmp_fault

    max_evap_tmp_fault = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('max_evap_tmp_fault', true)
    max_evap_tmp_fault.setDisplayName('Maximum value of evaporator water outlet temperature for the noncondensable fault fault model (C)')
    max_evap_tmp_fault.setDefaultValue(11.6)
    args << max_evap_tmp_fault

    min_cond_tmp_fault = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('min_cond_tmp_fault', true)
    min_cond_tmp_fault.setDisplayName('Minimum value of condenser inlet temperature for the noncondensable fault fault model (C)')
    min_cond_tmp_fault.setDefaultValue(17.8)
    args << min_cond_tmp_fault

    max_cond_tmp_fault = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('max_cond_tmp_fault', true)
    max_cond_tmp_fault.setDisplayName('Maximum value of condenser inlet temperature for the noncondensable fault fault model (C)')
    max_cond_tmp_fault.setDefaultValue(30.0)
    args << max_cond_tmp_fault

    min_cap_fault = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('min_cap_fault', true)
    min_cap_fault.setDisplayName('Minimum ratio of evaporator heat transfer rate to the reference capacity for the noncondensable fault fault model')
    min_cap_fault.setDefaultValue(0.274)
    args << min_cap_fault

    max_cap_fault = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('max_cap_fault', true)
    max_cap_fault.setDisplayName('Maximum ratio of evaporator heat transfer rate to the reference capacity for the noncondensable fault fault model')
    max_cap_fault.setDefaultValue(1.0)
    args << max_cap_fault

    return args
  end

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

    # obtain values
    chiller_choice, sch_choice, fault_level = pass_inputs(runner, user_arguments)

    # create schedule_exist
    schedule_exist = check_schedule_exist(sch_choice)

    if schedule_exist || (fault_level != 1 && $fault_type == 'CH') || (fault_level != 0 && $fault_type != 'CH') # only continue if the user is running the module
      # start add ems program
      return impose_fault(workspace, runner, user_arguments, chiller_choice, sch_choice, fault_level, schedule_exist)
    end

    runner.registerAsNotApplicable("PresenceOfNoncondensableChiller is not running for #{chiller_choice}. Skipping......")
    return true
  end

  def pass_inputs(runner, user_arguments)
    # function to return inputs stored in user_arguments
    chiller_choice = runner.getStringArgumentValue('chiller_choice', user_arguments)
    sch_choice = runner.getStringArgumentValue('sch_choice', user_arguments)
    fault_level = runner.getDoubleArgumentValue('fault_level', user_arguments)
    return chiller_choice, sch_choice, fault_level
  end

  def check_schedule_exist(sch_choice)
    # check if a schedule exists
    return true unless sch_choice.eql?('')
    return false
  end

  def impose_fault(workspace, runner, user_arguments, chiller_choice, sch_choice, fault_level, schedule_exist)
    # function to execute error checking and addition of ems after confirming that user input types are correct
    # start add ems program
    runner.registerInitialCondition("Imposing performance degradation on #{chiller_choice}.")

    # error checking for schedule type limits and fault levels
    scheduletypelimits, stl_error = check_schedule_or_lvl_error(workspace, runner, sch_choice, schedule_exist, fault_level)
    # if a user-defined schedule is used, check if the schedule exists and if the schedule has the correct schedule type limits
    if stl_error
      return false
    end

    # find the chiller to change
    no_chiller_changed, existing_coils = check_chiller(workspace, runner, user_arguments, chiller_choice, sch_choice, fault_level, scheduletypelimits)

    # give an error for the name if no chiller is changed
    if no_chiller_changed
      return error_msg_for_not_rtu(runner, chiller_choice, existing_coils)
    end

    # report final condition of workspace
    runner.registerFinalCondition("Imposed performance degradation on #{chiller_choice}.")
    return true
  end

  def check_chiller(workspace, runner, user_arguments, chiller_choice, sch_choice, fault_level, scheduletypelimits)
    # function to check which chiller to change
    no_chiller_changed = true
    existing_coils = []
    chillerelectriceirs = workspace.getObjectsByType('Chiller:Electric:EIR'.to_IddObjectType)
    chillerelectriceirs.each do |chillerelectriceir|
      current_coil = pass_string(chillerelectriceir, 0)
      existing_coils << current_coil

      if chiller_choice.eql?($all_chiller_selection)
        runner.registerInfo("all available chillers in the model selected for fault imposing")
        no_chiller_changed  = false
        chiller_choice_actual = current_coil
        add_ems(workspace, runner, user_arguments, chiller_choice_actual, sch_choice, fault_level, scheduletypelimits, chillerelectriceir)
      elsif current_coil.eql?(chiller_choice)
        runner.registerInfo("chiller named #{chiller_choice} in the model selected for fault imposing")
        no_chiller_changed  = false
        add_ems(workspace, runner, user_arguments, chiller_choice, sch_choice, fault_level, scheduletypelimits, chillerelectriceir)
        break
      end
      
    end
    return no_chiller_changed, existing_coils
  end

  def check_schedule_or_lvl_error(workspace, runner, sch_choice, schedule_exist, fault_level)
    # read data for scheduletypelimits
    scheduletypelimits = workspace.getObjectsByType('ScheduleTypeLimits'.to_IddObjectType)
    if schedule_exist
      # check if the schedule exists
      bool_schedule, schedule_type_limit, schedule_code = schedule_search(workspace, sch_choice)
      unless bool_schedule
        runner.registerError("User-defined schedule #{sch_choice} does not exist. Exiting......")
        return scheduletypelimits, true
      end

      # check schedule type limit of the schedule, if it is not bounded higher than 1, reject it
      scheduletypelimits.each do |scheduletypelimit|
        next unless pass_string(scheduletypelimit, 0).eql?(schedule_type_limit)
        if pass_string(scheduletypelimit, 2).to_f < 1
          runner.registerError("User-defined schedule #{sch_choice} has a ScheduleTypeLimits with lower limit smaller than 1. Exiting......")
          return scheduletypelimits, true
        end
      end
    else
      # if there is no user-defined schedule, check if the fouling level is positive
      if fault_level < 1.0 and $fault_type == 'CH'
        runner.registerError("Fault level #{fault_level} in AteCheungChillerNonCondensable is lower than 1.0. Exiting......")
        return scheduletypelimits, true
      elsif fault_level < 0.0
        runner.registerError("Fault level #{fault_level} in AteCheungChillerNonCondensable is negative. Exiting......")
        return scheduletypelimits, true
      end
    end
    return scheduletypelimits, false
  end

  def add_ems(workspace, runner, user_arguments, chiller_choice, sch_choice, fault_level, scheduletypelimits, chillerelectriceir)
    # function to add ems code
    sh_chiller_choice = name_cut(replace_common_strings(chiller_choice))
    runner.registerInfo("in add_ems method: variable '#{chiller_choice}' is shortend to '#{sh_chiller_choice}' to avoid max character limit in EMS")
    if is_number?(sh_chiller_choice[0])
      runner.registerInfo("in add_ems method: variable '#{sh_chiller_choice}' starts with number which is not compatible with EMS")
      sh_chiller_choice = "a"+sh_chiller_choice
      runner.registerInfo("in add_ems method: variable replaced to '#{sh_chiller_choice}'")
    end 
    
    schedule_exist = check_schedule_exist(sch_choice) # to avoid long function input. Regenerate here

    # create an empty string_objects to be appended into the .idf file
    string_objects = []

    # check if the Fractional Schedule Type Limit exists and create it if
    # it doesn't. It's going to be used by the schedule in this script.
    # The schedule name is also updated from here on.
    string_objects, sch_choice = insert_schedules(runner, workspace, string_objects, schedule_exist, fault_level, scheduletypelimits, sh_chiller_choice, sch_choice)

    # create energyplus management system code to alter the cooling capacity and EIR of the coil object
    string_objects = insert_curves_and_equations(workspace, runner, user_arguments, string_objects, sh_chiller_choice, chillerelectriceir, sch_choice)

    # write EMS sensors for schedules of fault levels
    string_objects = fault_level_sensor_sch_insert(runner, workspace, string_objects, $fault_type, sh_chiller_choice, sch_choice)

    # write an EMS program to multiply all multipliers from all faults and the program caller
    string_objects = insert_multiplier_and_caller(runner, workspace, string_objects, chillerelectriceir, sh_chiller_choice)

    # write variable definition for EMS programs
    # EMS Sensors to the workspace
    # check if the sensors are added previously by other fault models
    string_objects = insert_ems_sensors(workspace, string_objects, chillerelectriceir, chiller_choice, sh_chiller_choice)

    # only add Output:EnergyManagementSystem if it does not exist in the code
    string_objects = add_output_ems_record(workspace, string_objects)

    # before addition, delete any dummy subrountine with the same name in the workspace
    # add all of the strings to workspace to create IDF objects
    clear_redundant_program(workspace, string_objects, sh_chiller_choice)
  end

  def insert_schedules(runner, workspace, string_objects, schedule_exist, fault_level, scheduletypelimits, sh_chiller_choice, sch_choice)
    # check if the Fractional Schedule Type Limit exists and create it if
    # it doesn't. It's going to be used by the schedule in this script.
    scheduletypelimitname, string_objects = check_schedule_print(string_objects, scheduletypelimits, sh_chiller_choice)

    # if a schedule does not exist, create a new schedule according to fault_level
    unless schedule_exist
      sch_choice, string_objects = schedule_creation(runner, string_objects, sh_chiller_choice, fault_level, scheduletypelimitname)
    end

    # create schedules with zero and one all the time for zero fault scenarios
    string_objects = no_fault_schedules(workspace, scheduletypelimitname, string_objects)

    # schedule definition complete. Insert all of them.
    return insert_objects(workspace, string_objects), sch_choice
  end

  def insert_curves_and_equations(workspace, runner, user_arguments, string_objects, sh_chiller_choice, chillerelectriceir, sch_choice)
    # write the EMS programs for curves
    string_objects = insert_multi_curves(runner, workspace, string_objects, chillerelectriceir, sh_chiller_choice)

    # write the EMS programs with the minimum and maximum values of model inputs to ca_q_para and ca_eir_para tio insert them to the programs
    string_objects = insert_main_body(workspace, runner, user_arguments, string_objects, sh_chiller_choice, chillerelectriceir)

    return string_objects
  end

  def insert_multi_curves(runner, workspace, string_objects, chillerelectriceir, sh_chiller_choice)
    # obtaining the coefficients in the original Q curve
    string_objects = insert_curves(runner, workspace, string_objects, chillerelectriceir, sh_chiller_choice, 'q', 7)

    # obtaining the coefficients in the original EIR curve
    string_objects = insert_curves(runner, workspace, string_objects, chillerelectriceir, sh_chiller_choice, 'eir', 8)

    # original curves rewritten. Insert all of them.
    return insert_objects(workspace, string_objects)
  end

  def insert_main_body(workspace, runner, user_arguments, string_objects, sh_chiller_choice, chillerelectriceir)
    # function to insert the main body of the ems calculation procedure

    # write the EMS programs with the minimum and maximum values of model inputs to ca_q_para and ca_eir_para tio insert them to the programs
    string_objects = fault_adjust_function(runner, workspace, string_objects, $fault_type, chillerelectriceir, sh_chiller_choice, 'power', para_list_return(runner, user_arguments))

    # write dummy programs for other faults, and make sure that it is not current fault
    $other_faults.each do |other_fault|
      unless other_fault.eql?($fault_type)
        string_objects = dummy_fault_prog_add(runner, workspace, string_objects, other_fault, sh_chiller_choice, 'power')
      end
    end
    return string_objects
  end

  def insert_multiplier_and_caller(runner, workspace, string_objects, chillerelectriceir, sh_chiller_choice)
    # write an EMS program to multiply all multipliers from all faults
    string_objects = write_ems_all_multipliers(workspace, string_objects, chillerelectriceir, sh_chiller_choice)

    # write the main program caller
    string_objects = write_ems_program_caller(runner, workspace, string_objects, sh_chiller_choice)

    return string_objects
  end

  def insert_ems_sensors(workspace, string_objects, chillerelectriceir, chiller_choice, sh_chiller_choice)
    string_objects = add_cond_db_in_sensor(workspace, string_objects, chillerelectriceir, sh_chiller_choice)
    string_objects = add_evap_db_out_sensor(workspace, string_objects, chillerelectriceir, sh_chiller_choice)
    string_objects = add_evap_db_in_sensor(workspace, string_objects, chillerelectriceir, sh_chiller_choice)
    string_objects = add_evap_mdot_sensor(workspace, string_objects, chillerelectriceir, sh_chiller_choice)
    string_objects = add_evap_q_sensor(workspace, string_objects, chillerelectriceir, chiller_choice, sh_chiller_choice)
    return string_objects
  end

  def check_schedule_print(string_objects, scheduletypelimits, sh_chiller_choice)
    # This function determines if a schedule type limit is needed for the faulted schedule.
    # It checks if an existing schedule type limit object exists first. If the schedule does not exist
    # or is inappropriate, it will suggest to create a new schedule
    print_fractional_schedule = true
    scheduletypelimitname = 'Fraction'
    scheduletypelimits.each do |scheduletypelimit|
      next unless pass_string(scheduletypelimit, 0).eql?(scheduletypelimitname)
      if pass_string(scheduletypelimit, 1).to_f >= 1 && pass_string(scheduletypelimit, 3).eql?('Continuous')
        # if the existing ScheduleTypeLimits does not satisfy the requirement, generate the ScheduleTypeLimits with a unique name
        print_fractional_schedule = false
      else
        scheduletypelimitname = "Fraction#{sh_chiller_choice}"
      end
      break
    end
    if print_fractional_schedule
      string_objects << "
        ScheduleTypeLimits,
          #{scheduletypelimitname},                             !- Name
          0.0,                                      !- Lower Limit Value {BasedOnField A3}
          100,                                    !- Upper Limit Value {BasedOnField A3}
          Continuous;                             !- Numeric Type
      "
    end
    return scheduletypelimitname, string_objects
  end

  def insert_curves(runner, workspace, string_objects, chillerelectriceir, sh_chiller_choice, model_name, curve_index)
    # insert curve objects written in Erl into string_objects
    curve_name = pass_string(chillerelectriceir, curve_index)
    curvebiquadratics = workspace.getObjectsByType('Curve:Biquadratic'.to_IddObjectType)
    curve_name, para, no_curve = para_biquadratic_limit(curvebiquadratics, curve_name)
    string_objects = main_program_entry(runner, workspace, string_objects, sh_chiller_choice, curve_name, para, model_name, $fault_type)
    return string_objects
  end

  def schedule_creation(runner, string_objects, sh_chiller_choice, fault_level, scheduletypelimitname)
    # set a unique name for the schedule according to the component and the fault
    sch_choice = "#{$fault_type}DegradactionFactor#{sh_chiller_choice}_SCH"

    if $fault_type.eql?('CH')
      fault_level -= 1.0
    end

    # create a Schedule:Compact object with a schedule type limit "Fractional" that are usually
    # created in OpenStudio for continuous schedules bounded by 0 and 1
    string_objects << "
      Schedule:Constant,
        #{sch_choice},         !- Name
        #{scheduletypelimitname},                       !- Schedule Type Limits Name
        #{fault_level};                    !- Hourly Value
    "
    return sch_choice, string_objects # return the schedule name
  end

  def para_list_return(runner, user_arguments)
    # return a list of parameters that used to calculate power consumption
    max_fl, oc_power_para, min_evap_tmp_fault, max_evap_tmp_fault, min_cond_tmp_fault, max_cond_tmp_fault, min_cap_fault, max_cap_fault = pass_eqn_para(runner, user_arguments)
    power_para = []
    power_para.push(max_fl)
    power_para += oc_power_para
    power_para.push(min_evap_tmp_fault, max_evap_tmp_fault, min_cond_tmp_fault, max_cond_tmp_fault, min_cap_fault, max_cap_fault)
    return power_para
  end

  def pass_eqn_para(runner, user_arguments)
    # function to return all parameters in the equation in user_arguments
    max_fl = runner.getDoubleArgumentValue('max_fl', user_arguments)
    oc_power_para = runner_pass_coefficients(runner, user_arguments, $power_para_num, 'power_fault')
    min_evap_tmp_fault = runner.getDoubleArgumentValue('min_evap_tmp_fault', user_arguments)
    max_evap_tmp_fault = runner.getDoubleArgumentValue('max_evap_tmp_fault', user_arguments)
    min_cond_tmp_fault = runner.getDoubleArgumentValue('min_cond_tmp_fault', user_arguments)
    max_cond_tmp_fault = runner.getDoubleArgumentValue('max_cond_tmp_fault', user_arguments)
    min_cap_fault = runner.getDoubleArgumentValue('min_cap_fault', user_arguments)
    max_cap_fault = runner.getDoubleArgumentValue('max_cap_fault', user_arguments)
    return max_fl, oc_power_para, min_evap_tmp_fault, max_evap_tmp_fault, min_cond_tmp_fault, max_cond_tmp_fault, min_cap_fault, max_cap_fault
  end

  def write_ems_all_multipliers(workspace, string_objects, chillerelectriceir, sh_chiller_choice)
    # This function writes and ems program for all fault ratio multipliers
    unless check_ems_all_multipliers_exist(workspace, sh_chiller_choice)
      final_line = "
        EnergyManagementSystem:Program,
          FINAL_ADJUST_#{sh_chiller_choice}_power, !- Name
          SET PowerCurveResult#{sh_chiller_choice} = #{sh_chiller_choice}eir, !- Program 1
        "
      $other_faults.each do |other_fault|
        final_line = "#{final_line}
          SET PowerCurveResult#{sh_chiller_choice} = PowerCurveResult#{sh_chiller_choice}*#{other_fault}_FAULT_ADJ_RATIO, !-<none>
        "
      end
      string_objects << final_line + '; !- <none>'
      string_objects << "
        EnergyManagementSystem:Actuator,
          PowerCurveResult#{sh_chiller_choice},          !- Name
          #{pass_string(chillerelectriceir, 8)},  !- Actuated Component Unique Name
          Curve,                   !- Actuated Component Type
          Curve Result;            !- Actuated Component Control Type
      "
      string_objects << "
        EnergyManagementSystem:OutputVariable,
          PowerCurveEMSValue#{sh_chiller_choice},           !- Name
          PowerCurveResult#{sh_chiller_choice},          !- EMS Variable Name
          Averaged,                !- Type of Data in Variable
          ZoneTimeStep,            !- Update Frequency
          ,                        !- EMS Program or program Name
          ;                        !- Units
      "
    end
    return string_objects
  end

  def check_ems_all_multipliers_exist(workspace, sh_chiller_choice)
    # This function checks if an ems program for all fault ratio multipliers are needed
    programs = workspace.getObjectsByType('EnergyManagementSystem:Program'.to_IddObjectType)
    programs.each do |program|
      return true if pass_string(program, 0).eql?("FINAL_ADJUST_#{sh_chiller_choice}_power")
    end
    return false
  end

  def write_ems_program_caller(runner, workspace, string_objects, sh_chiller_choice)
    # This function writes an ems program caller to call the programs
    final_line = "
      EnergyManagementSystem:ProgramCallingManager,
        PCM_#{sh_chiller_choice}power, !- Name
        AfterPredictorBeforeHVACManagers, !- EnergyPlus Model Calling Point
        Chiller_#{sh_chiller_choice}q, !-<none>
        Chiller_#{sh_chiller_choice}eir, !-<none>
    "
    $other_faults.each do |other_fault|
      final_line += "#{other_fault}_ADJUST_#{sh_chiller_choice}_power,"
    end
    final_line += "FINAL_ADJUST_#{sh_chiller_choice}_power;"
    string_objects << final_line
    return string_objects
  end

  def check_ems_program_caller_exist(workspace, sh_chiller_choice)
    # This function checks if an ems program caller is needed
    ems_callers = workspace.getObjectsByType('EnergyManagementSystem:ProgramCallingManager'.to_IddObjectType)
    ems_callers.each do |ems_caller|
      return true if pass_string(ems_caller, 0).to_s.eql?("PCM_#{sh_chiller_choice}power")
    end
    return false
  end

  def add_cond_db_in_sensor(workspace, string_objects, chillerelectriceir, sh_chiller_choice)
    # add a sensor of condenser inlet dry-bulb temperature to ems program
    sensor_name = "CondInlet#{sh_chiller_choice}_#{$fault_type}"
    ems_sensors = workspace.getObjectsByType('EnergyManagementSystem:GlobalVariable'.to_IddObjectType)
    unless check_name_in_list(sensor_name, ems_sensors)
      outnode_fl = pass_string(chillerelectriceir, 16)
      if outnode_fl.eql?('')  # if it is not indicated as water node, use one of the outdoor node
        outnodes = workspace.getObjectsByType('OutdoorAir:NodeList'.to_IddObjectType)
        outnodes.each do |outnode|
          outnode_fl = pass_string(outnode, 0)
          break
        end
      end
      string_objects << "
        EnergyManagementSystem:Sensor,
          #{sensor_name},                !- Name
          #{outnode_fl},       !- Output:Variable or Output:Meter Index Key Name
          System Node Temperature;    !- Output:Variable or Output:Meter Name
      "
    end
    return string_objects
  end

  def add_evap_db_out_sensor(workspace, string_objects, chillerelectriceir, sh_chiller_choice)
    # add a sensor of condenser inlet dry-bulb temperature to ems program
    sensor_name = "EvapOutlet#{sh_chiller_choice}_#{$fault_type}"
    ems_sensors = workspace.getObjectsByType('EnergyManagementSystem:GlobalVariable'.to_IddObjectType)
    unless check_name_in_list(sensor_name, ems_sensors)
      string_objects << "
        EnergyManagementSystem:Sensor,
          #{sensor_name},            !- Name
          #{pass_string(chillerelectriceir, 15)},  !- Output:Variable or Output:Meter Index Key Name
          System Node Temperature; !- Output:Variable or Output:Meter Name
      "
    end
    return string_objects
  end

  def add_evap_db_in_sensor(workspace, string_objects, chillerelectriceir, sh_chiller_choice)
    # add a sensor of condenser inlet dry-bulb temperature to ems program
    sensor_name = "EvapInlet#{sh_chiller_choice}_#{$fault_type}"
    ems_sensors = workspace.getObjectsByType('EnergyManagementSystem:GlobalVariable'.to_IddObjectType)
    unless check_name_in_list(sensor_name, ems_sensors)
      string_objects << "
        EnergyManagementSystem:Sensor,
          #{sensor_name},            !- Name
          #{pass_string(chillerelectriceir, 14)},  !- Output:Variable or Output:Meter Index Key Name
          System Node Temperature; !- Output:Variable or Output:Meter Name
      "
    end
    return string_objects
  end

  def add_evap_mdot_sensor(workspace, string_objects, chillerelectriceir, sh_chiller_choice)
    # add a sensor of condenser inlet dry-bulb temperature to ems program
    sensor_name = "Evap#{sh_chiller_choice}Mdot_#{$fault_type}"
    ems_sensors = workspace.getObjectsByType('EnergyManagementSystem:GlobalVariable'.to_IddObjectType)
    unless check_name_in_list(sensor_name, ems_sensors)
      string_objects << "
        EnergyManagementSystem:Sensor,
          #{sensor_name},            !- Name
          #{pass_string(chillerelectriceir, 15)},  !- Output:Variable or Output:Meter Index Key Name
          System Node Mass Flow Rate; !- Output:Variable or Output:Meter Name
      "
    end
    return string_objects
  end

  def add_evap_q_sensor(workspace, string_objects, chillerelectriceir, chiller_choice, sh_chiller_choice)
    # add a sensor of condenser inlet dry-bulb temperature to ems program
    sensor_name = "EvapQ#{sh_chiller_choice}_#{$fault_type}"
    ems_sensors = workspace.getObjectsByType('EnergyManagementSystem:GlobalVariable'.to_IddObjectType)
    unless check_name_in_list(sensor_name, ems_sensors)
      plantloop_name = findplantloopname(workspace, chiller_choice)
      string_objects << "
        EnergyManagementSystem:Sensor,
          #{sensor_name},            !- Name
          #{plantloop_name},  !- Output:Variable or Output:Meter Index Key Name
          Plant Supply Side Cooling Demand Rate; !- Output:Variable or Output:Meter Name
      "
    end
    return string_objects
  end

  def findplantloopname(workspace, chiller_choice)
    # return the name of the plant loop where the chiller lies
    plantloop_name = ''
    plantloopequiplists = workspace.getObjectsByType('PlantEquipmentList'.to_IddObjectType)
    plantloopequiplists.each do |plantloopequiplist|
      (1..(plantloopequiplist.numFields - 1)).each do |ind|
        next unless plantloopequiplist.getString(ind).to_s.eql?(chiller_choice)
        plantloop_name = pass_string(plantloopequiplist, 0).sub(' Cooling Equipment List', '')
        break
      end
    end
    return plantloop_name
  end

  def check_name_in_list(name, objects)
    # This function checks if a name exists in the name of a list of objects
    name_exist = false
    objects.each do |object|
      next unless pass_string(object, 0).eql?(name)
      name_exist = true
      break
    end
    return name_exist
  end

  def add_output_ems_record(workspace, string_objects)
    # only add Output:EnergyManagementSystem if it does not exist in the code
    outputemss = workspace.getObjectsByType('Output:EnergyManagementSystem'.to_IddObjectType)
    return string_objects unless outputemss.size == 0
    string_objects << '
      Output:EnergyManagementSystem,
        Verbose,                 !- Actuator Availability Dictionary Reporting
        Verbose,                 !- Internal Variable Availability Dictionary Reporting
        ErrorsOnly;                 !- EMS Runtime Language Debug Output Level
    '
    return string_objects
  end

  def clear_redundant_program(workspace, string_objects, sh_chiller_choice)
    # This function does a cleanup for redundant dummy programs before the end of the Measure script.
    # It does insertion as well
    programs = workspace.getObjectsByType('EnergyManagementSystem:Program'.to_IddObjectType)
    program_remove_bool = false
    program_remove = ''
    programs.each do |program|
      next unless pass_string(program, 0).eql?("#{$fault_type}_ADJUST_#{sh_chiller_choice}_power")
      program_remove = program
      program_remove_bool = true
      break
    end
    # remove before insertion
    # return unless program_remove_bool
    if program_remove_bool
      program_remove.remove
      # remove the associated caller as well
      program_callers = workspace.getObjectsByType('EnergyManagementSystem:ProgramCallingManager'.to_IddObjectType)
      program_callers.each do |program_caller|
        if pass_string(program_caller, 0).eql?("PCM_#{sh_chiller_choice}power")
          program_call_remove = program_caller
          program_call_remove.remove
          break
        end
      end
    end
    # insert program first before exiting
    return insert_objects(workspace, string_objects)
  end

  def error_msg_for_not_rtu(runner, chiller_choice, existing_coils)
    # This function returns an error message when the coil in user inputs cannot be found
    runner.registerError("Measure PresenceOfNoncondensableChiller cannot find #{chiller_choice}. Exiting......")
    coils_msg = 'Only coils '
    existing_coils.each do |existing_coil|
      coils_msg += ("#{existing_coil}, ")
    end
    coils_msg += 'were found.'
    runner.registerError(coils_msg)
    return false
  end
end

# register the measure to be used by the application
PresenceOfNoncondensableChiller.new.registerWithApplication
