# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require "#{File.dirname(__FILE__)}/resources/transfercurveparameters"
require "#{File.dirname(__FILE__)}/resources/faultcalculationcoilcoolingdx_CFD"
require "#{File.dirname(__FILE__)}/resources/faultdefinitions"
require "#{File.dirname(__FILE__)}/resources/misc_eplus_func"

# define number of parameters in the model
$q_para_num = 6
$eir_para_num = 6
$faultnow = 'CAF'
$err_check = false
$all_coil_selection = '* ALL Coil Selected *'

# start the measure
class CondenserFanDegradation < OpenStudio::Ruleset::WorkspaceUserScript
  # human readable name
  def name
    return 'Condenser Fan Degradation'
  end

  # human readable description
  def description
    return "Motor efficiency degrades when a motor suffers from a bearing or a stator winding fault. This fault causes the motor to draw higher electrical current without changing the fluid flow. Both a bearing fault and a stator winding fault can be modeled by increasing the power consumption of the condenser fan without changing the airflow of the condenser fan. This fault is categorized as a fault that occur in the vapor compression system during the operation stage. This fault measure is based on an empirical model and simulates the condenser fan degradation by modifying the Coil:Cooling:DX:SingleSpeed object in EnergyPlus assigned to the heating and cooling system. The fault intensity (F) is defined as the reduction in motor efficiency as a fraction of the non-faulted motor efficiency with the application range of 0 to 0.3 (30% degradation)."
  end

  # human readable description of workspace approach
  def modeler_description
    return "Three user inputs are required and, based on these user inputs, the EIR in the DX cooling coil model is recalculated to reflect the faulted operation as shown in the equation below, EIR_F/EIR=1+(W ̇_fan/W ̇_cool)*(F/(1-F)), where EIR_F is the faulted EIR, W ̇_fan is the fan power, W ̇_cool is the DX  coil power, and F is the fault intensity. This fault model also requires the ratio of condenser fan power to the power consumption of compressor and condenser fan as a user input parameter."
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    ##################################################
    list = OpenStudio::StringVector.new
    list << $all_coil_selection
	  
    singlespds = workspace.getObjectsByType("Coil:Cooling:DX:SingleSpeed".to_IddObjectType)
    singlespds.each do |singlespd|
      list << singlespd.name.to_s
    end
	
    twostages = workspace.getObjectsByType("Coil:Cooling:DX:TwoStageWithHumidityControlMode".to_IddObjectType)
      twostages.each do |twostage|
      list << twostage.name.to_s
    end
		
    #make choice arguments for Coil:Cooling:DX:SingleSpeed
    coil_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("coil_choice", list, true)
    coil_choice.setDisplayName("Enter the name of the faulted Coil:Cooling:DX:SingleSpeed object. If you want to impose the fault on all coils, select #{$all_coil_selection}")
    coil_choice.setDefaultValue($all_coil_selection)
    args << coil_choice
    ##################################################

    # make a double argument for the fault level
    fault_lvl = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("fault_lvl", false)
    fault_lvl.setDisplayName("Fan motor efficiency degradation ratio [-]")
    fault_lvl.setDefaultValue(0.5)  #default fouling level to be 50%
    args << fault_lvl
	
	fan_power_ratio = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("fan_power_ratio", false)
    fan_power_ratio.setDisplayName("Ratio of condenser fan motor power consumption to combined power consumption of condenser fan and compressor at rated condition.")
    fan_power_ratio.setDefaultValue(0.091747081)  #defaulted calcualted to be 0.0917
    args << fan_power_ratio

	##################################################
    #Parameters for transient fault modeling
	
	#make a double argument for the time required for fault to reach full level 
    time_constant = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('time_constant', false)
    time_constant.setDisplayName('Enter the time required for fault to reach full level [hr]')
    time_constant.setDefaultValue(0)  #default is zero
    args << time_constant
	
	#make a double argument for the start month
    start_month = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_month', false)
    start_month.setDisplayName('Enter the month (1-12) when the fault starts to occur')
    start_month.setDefaultValue(6)  #default is June
    args << start_month
	
	#make a double argument for the start date
    start_date = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_date', false)
    start_date.setDisplayName('Enter the date (1-28/30/31) when the fault starts to occur')
    start_date.setDefaultValue(1)  #default is 1st day of the month
    args << start_date
	
	#make a double argument for the start time
    start_time = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_time', false)
    start_time.setDisplayName('Enter the time of day (0-24) when the fault starts to occur')
    start_time.setDefaultValue(9)  #default is 9am
    args << start_time
	
	#make a double argument for the end month
    end_month = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('end_month', false)
    end_month.setDisplayName('Enter the month (1-12) when the fault ends')
    end_month.setDefaultValue(12)  #default is Decebmer
    args << end_month
	
	#make a double argument for the end date
    end_date = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('end_date', false)
    end_date.setDisplayName('Enter the date (1-28/30/31) when the fault ends')
    end_date.setDefaultValue(31)  #default is last day of the month
    args << end_date
	
	#make a double argument for the end time
    end_time = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('end_time', false)
    end_time.setDisplayName('Enter the time of day (0-24) when the fault ends')
    end_time.setDefaultValue(23)  #default is 11pm
    args << end_time
    ##################################################

    return args
  end

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # obtain values
    coil_choice, fault_lvl, fault_lvl_check = _get_inputs(workspace, runner, user_arguments)
    unless fault_lvl_check == 'continue'
      return fault_lvl_check
    end
    
    ##################################################
    fault_lvl = runner.getDoubleArgumentValue('fault_lvl', user_arguments)
    ##################################################
    time_constant = runner.getDoubleArgumentValue('time_constant',user_arguments).to_s
	start_month = runner.getDoubleArgumentValue('start_month',user_arguments).to_s
	start_date = runner.getDoubleArgumentValue('start_date',user_arguments).to_s
	start_time = runner.getDoubleArgumentValue('start_time',user_arguments).to_s
	end_month = runner.getDoubleArgumentValue('end_month',user_arguments).to_s
	end_date = runner.getDoubleArgumentValue('end_date',user_arguments).to_s
	end_time = runner.getDoubleArgumentValue('end_time',user_arguments).to_s
	time_step = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('time_step', false)
	dts = workspace.getObjectsByType('Timestep'.to_IddObjectType)
	dts.each do |dt|
	 runner.registerInfo("Simulation Timestep = #{1./dt.getString(0).get.clone.to_f}")
	 time_step = (1./dt.getString(0).get.clone.to_f).to_s
	end
	################################################## 
    rtu_changed = false
    existing_coils = []

    ##################################################
    # find the single speed DX unit to change
    ##################################################
    #SINGLE SPEED
    coilcoolingdxsinglespeeds = get_workspace_objects(workspace, 'Coil:Cooling:DX:SingleSpeed')
    coilcoolingdxsinglespeeds.each do |coilcoolingdxsinglespeed|
      
      coiltype = 1
      existing_coils << pass_string(coilcoolingdxsinglespeed, 0)
      next unless pass_string(coilcoolingdxsinglespeed, 0).eql?(coil_choice) | coil_choice.eql?($all_coil_selection)
      runner.registerInfo("Found single speed coil named #{coilcoolingdxsinglespeed.getString(0)}")
      rtu_changed = _write_ems_string(workspace, runner, user_arguments, pass_string(coilcoolingdxsinglespeed, 0), fault_lvl, coilcoolingdxsinglespeed, coiltype, time_constant, time_step, start_month, start_date, start_time, end_month, end_date, end_time)
      unless rtu_changed
        return false
      end
      # break
    end
    ##################################################
    # find the two stage DX unit to change
    ##################################################
    #TWO STAGE WITH HUMIDITY CONTROL MODE
    coilcoolingdxtwostagewithhumiditycontrolmodes = get_workspace_objects(workspace, 'Coil:Cooling:DX:TwoStageWithHumidityControlMode')
    coilcoolingdxtwostagewithhumiditycontrolmodes.each do |coilcoolingdxtwostagewithhumiditycontrolmode|
      
      coiltype = 2
      existing_coils << pass_string(coilcoolingdxtwostagewithhumiditycontrolmode, 0)
      next unless pass_string(coilcoolingdxtwostagewithhumiditycontrolmode, 0).eql?(coil_choice) | coil_choice.eql?($all_coil_selection)
      runner.registerInfo("Found two stage coil named #{coilcoolingdxtwostagewithhumiditycontrolmode.getString(0)}")
      rtu_changed = _write_ems_string(workspace, runner, user_arguments, pass_string(coilcoolingdxtwostagewithhumiditycontrolmode, 0), fault_lvl, coilcoolingdxtwostagewithhumiditycontrolmode, coiltype, time_constant, time_step, start_month, start_date, start_time, end_month, end_date, end_time)
      unless rtu_changed
        return false
      end
      # break
      
      # if need absolute CLI path use code below
      #cli_path = OpenStudio.getOpenStudioCLI.to_s
      #runner.registerInfo(cli_path.to_s)
      #energy_plus_path = cli_path.gsub("bin/openstudio","EnergyPlus/energyplus")
      #runner.registerInfo(energy_plus_path)

      # get weather file
      epw_path = runner.lastEpwFilePath
      if epw_path.empty?
        runner.registerError('Cannot find last epw path.')
        return false
      end
      epw_path = epw_path.get.to_s

      # run simulation design days only
      workspace.save("dd_sim.idf",true)
      cmd = "energyplus -w #{epw_path} -D dd_sim.idf"
      runner.registerInfo(cmd)
      system(cmd)
      
    end
    ##################################################

    # give an error for the name if no DX unit is changed
    return _return_err_message_for_not_unit(runner, existing_coils, coil_choice) unless rtu_changed

    # report final condition of workspace
    return true
  end

  def _get_inputs(workspace, runner, user_arguments)
    # use the built-in error checking
    unless runner.validateUserArguments(arguments(workspace), user_arguments)
      return '', 0.0, false
    end

    # function to return inputs stored in user_arguments
    coil_choice = runner.getStringArgumentValue('coil_choice', user_arguments)
    fault_lvl = runner.getDoubleArgumentValue('fault_lvl', user_arguments)
    fault_lvl_check = _check_fault_lvl(runner, coil_choice, fault_lvl)
    return coil_choice, fault_lvl, fault_lvl_check
  end

  def _check_fault_lvl(runner, coil_choice, fault_lvl)
    # This function checks if the fault level values are valid
    if fault_lvl < 0.0 || fault_lvl > 1.0
      runner.registerError("Fault level #{fault_lvl} for #{coil_choice} is outside the range from 0 to 1. Exiting......")
      return false
    elsif fault_lvl.abs < 0.001
      runner.registerAsNotApplicable("CondenserFanDegradation is not running for #{coil_choice}. Skipping......")
      return true
    end
    return 'continue'
  end

  def _write_ems_string(workspace, runner, user_arguments, coil_choice, fault_lvl, coilcooling, coiltype, time_constant, time_step, start_month, start_date, start_time, end_month, end_date, end_time)
    # check component validity
    
    ##################################################
    if coiltype == 1 #SINGLESPEED
      unless pass_string(coilcooling, 20).eql?('AirCooled')
        runner.registerError("#{coil_choice} is not air cooled. Impossible to continue in CondenserFanDegradation. Exiting......")
        return false
      end
    end
    ##################################################

    # create an empty string_objects to be appended into the .idf file
    runner.registerInitialCondition("Imposing performance degradation on #{coil_choice}.")
    sh_coil_choice = name_cut(coil_choice)

    # create a faulted schedule with a new schedule type limit
    string_objects, sch_choice = _create_schedules_and_typelimits(workspace, coil_choice, fault_lvl, [])

    # create energyplus management system code to alter the EIR of the coil object
    string_objects, workspace = _write_ems_curves(workspace, runner, user_arguments, coil_choice, coilcooling, string_objects, coiltype, fault_lvl)

    # write variable definition for EMS programs
    # EMS Sensors to the workspace
    # check if the sensors are added previously by other fault models
    _write_ems_sensors(workspace, runner, coilcooling, sh_coil_choice, string_objects, find_outdoor_node_name(workspace), coiltype)
	
	#Fault intensity adjustment factor for dynamic modeling
	faultintensity_adjustmentfactor(string_objects, time_constant, time_step, start_month, start_date, start_time, end_month, end_date, end_time, sh_coil_choice)

    return _wrapping_up(runner, workspace, coil_choice, string_objects)
  end

  def _create_schedules_and_typelimits(workspace, coil_choice, fault_lvl, string_objects)
    # function to create schedules and corresponding limits
    # create a faulted schedule with a new schedule type limit
    sch_choice, scheduletypelimitname = _create_schedule_objects_create_schedule_objects(
      workspace, coil_choice, fault_lvl, string_objects
    )

    # create schedules with zero and one all the time for zero fault scenarios
    string_objects = no_fault_schedules(workspace, scheduletypelimitname, string_objects)
    return string_objects, sch_choice
  end

  def _return_err_message_for_not_unit(runner, existing_coils, coil_choice)
    runner.registerError("Measure CondenserFanDegradation cannot find #{coil_choice}. Exiting......")
    coils_msg = 'Only coils '
    existing_coils.each do |existing_coil|
      coils_msg += (existing_coil + ', ')
    end
    coils_msg += 'were found.'
    runner.registerError(coils_msg)
    return false
  end

  def _create_schedule_objects_create_schedule_objects(workspace, coil_choice, fault_lvl, string_objects)
    # This function creates statements of schedules of fault level. Return name of schedule

    scheduletypelimits = get_workspace_objects(workspace, 'ScheduleTypeLimits')
    sh_coil_choice = name_cut(coil_choice)
    scheduletypelimitname = "Fraction#{sh_coil_choice}"
    sch_choice = "#{$faultnow}DegradactionFactor#{sh_coil_choice}_S#{$faultnow}"
    string_objects << "
      ScheduleTypeLimits,
        #{scheduletypelimitname},                             !- Name
        0,                                      !- Lower Limit Value {BasedOnField A3}
        1,                                      !- Upper Limit Value {BasedOnField A3}
        Continuous;                             !- Numeric Type
    "
    string_objects << "
      Schedule:Constant,
        #{sch_choice},         !- Name
        #{scheduletypelimitname},                       !- Schedule Type Limits Name
        #{fault_lvl};                    !- Hourly Value
    "
    return sch_choice, scheduletypelimitname
  end

  def _write_ems_curves(workspace, runner, user_arguments, coil_choice, coilcooling, string_objects, coiltype, fault_lvl)
    # This function writes the original and adjustment curves in EMS
    string_objects = _write_q_and_eir_curves(workspace, coil_choice, coilcooling, string_objects, runner, coiltype, fault_lvl)
    string_objects, workspace = _write_q_and_eir_adj_routine(workspace, runner, user_arguments, coil_choice, coilcooling, string_objects, coiltype, fault_lvl)
    return string_objects, workspace
  end

  def _write_q_and_eir_curves(workspace, coil_choice, coilcooling, string_objects, runner, coiltype, fault_lvl)
    # This function appends and returns the string_objects with ems program statements. It also
    # returns a boolean to indicate if the addition is successful

    # curves generated by OpenStudio. No need to check
    ##################################################
    if coiltype == 1 #SINGLESPEED
      string_objects, curve_exist = _write_curves(workspace, coil_choice, coilcooling, string_objects, 'EIR', 11, runner, coiltype, [], fault_lvl)
    elsif coiltype == 2 #TWOSTAGEWITHHUMIDITYCONTROLMODE
      coilperformancedxcoolings = workspace.getObjectsByType(coilcooling.getString(8).to_s.to_IddObjectType)
      coilperformancedxcoolings.each do |coilperformancedxcooling|
	    string_objects, curve_exist = _write_curves(workspace, coil_choice, coilcooling, string_objects, 'EIR', 8, runner, coiltype, coilperformancedxcooling, fault_lvl)
      end
    end
    ##################################################
    return string_objects
  end

  def _write_q_and_eir_adj_routine(workspace, runner, user_arguments, coil_choice, coilcooling, string_objects, coiltype, fault_lvl)
    # This function writes the adjustment routines of the EIR curves to impose faults

    eir_para = _get_parameters(runner, user_arguments)

    # write the EMS subroutines
    ##################################################
    if coiltype == 1 #SINGLESPEED
      string_objects, workspace = general_adjust_function_cfd(workspace, coil_choice, string_objects, coilcooling, 'EIR', eir_para, $faultnow, coiltype, [], 11)
    elsif coiltype == 2 #TWOSTAGEWITHHUMIDITYCONTROLMODE
      coilperformancedxcoolings = workspace.getObjectsByType(coilcooling.getString(8).to_s.to_IddObjectType)
      coilperformancedxcoolings.each do |coilperformancedxcooling|
        string_objects, workspace = general_adjust_function_cfd(workspace, coil_choice, string_objects, coilcooling, 'EIR', eir_para, $faultnow, coiltype, coilperformancedxcooling, 8)
      end
    end

    # write dummy subroutines for other faults, and make sure that it is not current fault
    $model_names.each do |model_name|
      $other_faults.each do |other_fault|
	if coiltype == 1 #SINGLESPEED
      string_objects = dummy_fault_sub_add(workspace, string_objects, coilcooling, other_fault, coil_choice, model_name, coiltype, [], 9) unless other_fault.eql?($faultnow)
    elsif coiltype == 2 #TWOSTAGEWITHHUMIDITYCONTROLMODE
      coilperformancedxcoolings = workspace.getObjectsByType(coilcooling.getString(8).to_s.to_IddObjectType)
	  coilperformancedxcoolings.each do |coilperformancedxcooling|
	    string_objects = dummy_fault_sub_add(workspace, string_objects, coilcooling, other_fault, coil_choice, model_name, coiltype, coilperformancedxcooling, 6) unless other_fault.eql?($faultnow)
	  end
	end
      end
    end
    ##################################################
    return string_objects, workspace
  end

  def _write_curves(workspace, coil_choice, coilcooling, string_objects, curve_name, curve_index, runner, coiltype, coilperformancedxcooling, fault_lvl)
    ##################################################
    if coiltype == 1 #SINGLESPEED
      curve_str = pass_string(coilcooling, curve_index)
    elsif coiltype == 2 #TWOSTAGEWITHHUMIDITYCONTROLMODE
      curve_str = pass_string(coilperformancedxcooling, curve_index)
    end
    ##################################################
    curvebiquadratics = get_workspace_objects(workspace, 'Curve:Biquadratic')
    curve_nameq, paraq, no_curve = para_biquadratic_limit(curvebiquadratics, curve_str)

    if no_curve
      runner.registerError("No Temperature Adjustment Curve for #{coil_choice} #{curve_name} model. Exiting......")
      return string_objects, false
    end
    ##################################################
    sh_coil_choice = coil_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
    if sh_coil_choice.eql?(nil)
      sh_coil_choice = coil_choice
    end
    sh_curve_name = curve_nameq.clone.gsub!(/[^0-9A-Za-z]/, '')
    if sh_curve_name.eql?(nil)
      sh_curve_name = curve_nameq
    end
    ##################################################
    string_objects = main_program_entry(workspace, string_objects, coil_choice, curve_nameq, paraq, curve_name, fault_lvl)
    return string_objects, true
  end

  def _get_parameters(runner, user_arguments)
    # This function returns the parameters for Q and EIR calculation
    ##################################################
    fan_power_ratio = runner.getDoubleArgumentValue('fan_power_ratio', user_arguments)

    eir_para = [fan_power_ratio]
    eir_para.flatten!
	##################################################
    return eir_para
  end

  def _write_ems_sensors(workspace, runner, coilcooling, sh_coil_choice, string_objects, outdoor_node, coiltype)
    # This function checks if the sensors exist before writing
    pressure_sensor_name = "Pressure#{sh_coil_choice}"
    db_sensor_name = "CoilInletDBT#{sh_coil_choice}"
    humidity_sensor_name = "CoilInletW#{sh_coil_choice}"
    oat_sensor_name = "OAT#{sh_coil_choice}"
    
    ##################################################
    if coiltype == 1 #SINGLESPEED
      inlet_node = pass_string(coilcooling, 7)
    elsif coiltype == 2 #TWOSTAGEWITHHUMIDITYCONTROLMODE
      inlet_node = pass_string(coilcooling, 2)
    end
    ##################################################

    string_objects << ems_sensor_str(pressure_sensor_name, outdoor_node, 'System Node Pressure') unless check_exist_workspace_objects(workspace, pressure_sensor_name, 'EnergyManagementSystem:Sensor')
    string_objects << ems_sensor_str(db_sensor_name, inlet_node, 'System Node Temperature') unless check_exist_workspace_objects(workspace, db_sensor_name, 'EnergyManagementSystem:Sensor')
    string_objects << ems_sensor_str(humidity_sensor_name, inlet_node, 'System Node Humidity Ratio') unless check_exist_workspace_objects(workspace, humidity_sensor_name, 'EnergyManagementSystem:Sensor')
    string_objects << ems_sensor_str(oat_sensor_name, outdoor_node, 'System Node Temperature') unless check_exist_workspace_objects(workspace, oat_sensor_name, 'EnergyManagementSystem:Sensor')
  end

  def _check_autosize(givenstr)
    # Thie function checks if the string in givenstr is 'autosize'
    return givenstr.downcase.eql?('autosize')
  end

  def _wrapping_up(runner, workspace, coil_choice, string_objects)
    # This function wraps up the ending part of ems code writing

    # only add Output:EnergyManagementSystem if it does not exist in the code
    ems_output_writer(workspace, string_objects, err_check = $err_check)

    # add all of the strings to workspace to create IDF objects
    append_workspace_objects(workspace, string_objects)

    runner.registerFinalCondition("Imposed performance degradation on #{coil_choice}.")
    return true
  end
end

# register the measure to be used by the application
CondenserFanDegradation.new.registerWithApplication
