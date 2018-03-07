# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require "#{File.dirname(__FILE__)}/resources/transfercurveparameters"
require "#{File.dirname(__FILE__)}/resources/schedulesearch"
require "#{File.dirname(__FILE__)}/resources/entercoefficients"
require "#{File.dirname(__FILE__)}/resources/faultcalculationcoilcoolingdx"
require "#{File.dirname(__FILE__)}/resources/faultdefinitions"
require "#{File.dirname(__FILE__)}/resources/misc_eplus_func"
require "#{File.dirname(__FILE__)}/resources/psychrometric"

# define number of parameters in the model
$q_para_num = 6
$eir_para_num = 6
$faultnow = 'CA'
$err_check = false
$all_coil_selection = '* ALL Coil Selected *'

# start the measure
class CondenserFouling < OpenStudio::Ruleset::WorkspaceUserScript
  # human readable name
  def name
    return 'Condenser Fouling'
  end

  # human readable description
  def description
    return "Condenser fouling occurs when litter, dirt, or dust accumulates on or between the fins of a condenser of an air conditioner located in the outdoor environment. The blockage reduces the airflow across the condenser and increases the condensing temperature in the refrigerant circuit. The elevated temperature increases the pressure difference across the compressor and reduces the equipment efficiency. This measure simulates condenser fouling by modifying the Coil:Cooling:DX:SingleSpeed object in EnergyPlus assigned to the heating and cooling system. The fault intensity (F) for this fault is defined as the ratio of reduction in condenser coil airflow at full load."
  end

  # human readable description of workspace approach
  def modeler_description
    return "Thirty two user inputs (DX coil where the fault occurs / Percentage reduction of condenser airflow / rated cooling capacity / rated sensible heat ratio / rated volumetric flow rate / minimum-maximum evaporator air inlet wet-bulb temperature / minimum-maximum condenser air inlet dry-bulb temperature / minimum/maximum rated COP / percentage change of UA with increase of fault level / time required for fault to reach full level / fault starting month / fault starting date / fault starting time / fault ending month / fault ending date / fault ending time) can be defined or remained with default values. Based on user inputs, the cooling capacity (Q ̇_cool) and EIR in the DX cooling coil model is recalculated to reflect the faulted operation. The time required for the fault to reach the full level is only required when user wants to model dynamic fault evolution. If dynamic fault evolution is not necessary for the user, it can be defined as zero and the fault intensity will be imposed as a step function with user defined value. However, by defining the time required for the fault to reach the full level, fault starting month/date/time and fault ending month/date/time, the adjustment factor AF is calculated at each time step starting from the starting month/date/time to gradually impose fault intensity based on the user specified time frame. AF is calculated as follows, AF_current = AF_previous + dt/tau where AF_current is the adjustment factor calculated based on the previously calculated adjustment factor (AF_previous), simulation timestep (dt) and the time required for the fault to reach the full level (tau)."
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
    fault_lvl = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('fault_lvl', false)
    fault_lvl.setDisplayName('Percentage reduction of condenser airflow [-]')
    fault_lvl.setDefaultValue(0.1)  # defaulted at 10%
    args << fault_lvl

    # rated cooling capacity
    q_rat = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('q_rat', true)
    q_rat.setDisplayName('Rated cooling capacity of the cooling coil for bypass factor model adjustment. If your system is autosized or you do not know what this is, please run the OS Measure Auto Size to Hard Size before this Measure. If your system is hard sized, leave this value at -1.0. (W)')
    q_rat.setDefaultValue(-1.0)
    args << q_rat

    # rated sensible heat ratio
    shr_rat = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('shr_rat', true)
    shr_rat.setDisplayName('Rated sensible heat ratio of the cooling coil for bypass factor model adjustment. If your system is autosized or you do not know what this is, please run the OS Measure Auto Size to Hard Size before this Measure. If your system is hard sized, leave this value at -1.0.')
    shr_rat.setDefaultValue(-1.0)
    args << shr_rat

    # rated volumetric flow rate
    vol_rat = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('vol_rat', true)
    vol_rat.setDisplayName('Rated air flow rate of the cooling coil for bypass factor model adjustment. If your system is autosized or you do not know what this is, please run the OS Measure Auto Size to Hard Size before this Measure. If your system is hard sized, leave this value at -1.0. (m3/s)')
    vol_rat.setDefaultValue(-1.0)
    args << vol_rat

    # fault level limits
    min_fl = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('min_fl', true)
    min_fl.setDisplayName('Maximum value of fault level [-]')
    min_fl.setDefaultValue(0.5)
    args << min_fl

    # coefficients of models should be inputs.
    # the model simulates the ratio of the cooling capacity and EIR of the faulted system to the ones of the non-faulted case
    # the form of the model is
    # RATIO = 1 + FaultLevel*(a1+a2*Tdb,i+a3*Twb,i+a4*Tc,i+a5*FaultLevel+a6*FaultLevel*FaultLevel+a7*(Rated COP))

    # undercharging model
    args = enter_coefficients(args, $q_para_num, "Q_#{$faultnow}", [-2.216200, 5.631500, -3.119900, 0.224920, -0.762450, -0.072843], '')
    args = enter_coefficients(args, $eir_para_num, "EIR_#{$faultnow}", [-5.980600, 0.947900, 4.381600, -1.066700, 2.914200, 0.090476], '')

    min_wb_tmp_uc = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('min_wb_tmp_uc', true)
    min_wb_tmp_uc.setDisplayName('Minimum value of evaporator air inlet wet-bulb temperature [C]')
    min_wb_tmp_uc.setDefaultValue(12.8)  # the first number is observed from the training data, and the second number is an adjustment for range
    args << min_wb_tmp_uc

    max_wb_tmp_uc = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('max_wb_tmp_uc', true)
    max_wb_tmp_uc.setDisplayName('Maximum value of evaporator air inlet wet-bulb temperature [C]')
    max_wb_tmp_uc.setDefaultValue(23.9)
    args << max_wb_tmp_uc

    min_cond_tmp_uc = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('min_cond_tmp_uc', true)
    min_cond_tmp_uc.setDisplayName('Minimum value of condenser air inlet temperature [C]')
    min_cond_tmp_uc.setDefaultValue(18.3)
    args << min_cond_tmp_uc

    max_cond_tmp_uc = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('max_cond_tmp_uc', true)
    max_cond_tmp_uc.setDisplayName('Maximum value of condenser air inlet temperature [C]')
    max_cond_tmp_uc.setDefaultValue(46.1)
    args << max_cond_tmp_uc

    min_cop_uc = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('min_cop_uc', true)
    min_cop_uc.setDisplayName('Minimum value of rated COP')
    min_cop_uc.setDefaultValue(3.74)
    args << min_cop_uc

    max_cop_uc = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('max_cop_uc', true)
    max_cop_uc.setDisplayName('Maximum value of rated COP')
    max_cop_uc.setDefaultValue(4.69)
    args << max_cop_uc 

    # model for BF offset
    bf_para = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('bf_para', false)
    bf_para.setDisplayName('Percentage change of UA with increase of fault level level (% of UA/% of fault level)')
    bf_para.setDefaultValue(0.00)  # default change of bypass factor level with fault level in %
    args << bf_para
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
    bf_para = runner.getDoubleArgumentValue('bf_para', user_arguments)
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
      
      qdot_rat = coilcoolingdxsinglespeed.getString(2).get.clone.to_f
      shr_rat = coilcoolingdxsinglespeed.getString(3).get.clone.to_f
      vdot_rat = coilcoolingdxsinglespeed.getString(5).get.clone.to_f
      shr_fault = shr_modification(workspace, runner, qdot_rat, shr_rat, vdot_rat, bf_para, fault_lvl)
      coilcoolingdxsinglespeed.setString(3, shr_fault.to_s)
      
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
      
      coilperformancedxcoolings = workspace.getObjectsByType(coilcoolingdxtwostagewithhumiditycontrolmode.getString(8).to_s.to_IddObjectType)
      coilperformancedxcoolings.each do |coilperformancedxcooling|
	qdot_rat = coilperformancedxcooling.getString(1).get.clone.to_f
	shr_rat = coilperformancedxcooling.getString(2).get.clone.to_f
	vdot_rat = coilperformancedxcooling.getString(4).get.clone.to_f
	shr_fault = shr_modification(workspace, runner, qdot_rat, shr_rat, vdot_rat, bf_para, fault_lvl)
	coilperformancedxcooling.setString(2, shr_fault.to_s)
      end
      
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
      runner.registerAsNotApplicable("CondenserFouling is not running for #{coil_choice}. Skipping......")
      return true
    end
    return 'continue'
  end

  def _write_ems_string(workspace, runner, user_arguments, coil_choice, fault_lvl, coilcooling, coiltype, time_constant, time_step, start_month, start_date, start_time, end_month, end_date, end_time)
    # check component validity
    
    ##################################################
    if coiltype == 1 #SINGLESPEED
      unless pass_string(coilcooling, 20).eql?('AirCooled')
        runner.registerError("#{coil_choice} is not air cooled. Impossible to continue in CondenserFouling. Exiting......")
        return false
      end
    end
    ##################################################

    # create an empty string_objects to be appended into the .idf file
    runner.registerInitialCondition("Imposing performance degradation on #{coil_choice}.")
    sh_coil_choice = name_cut(coil_choice)

    # create a faulted schedule with a new schedule type limit
    string_objects, sch_choice = _create_schedules_and_typelimits(workspace, coil_choice, fault_lvl, [])

    # create energyplus management system code to alter the cooling capacity and EIR of the coil object
    # introduce code to modify the temperature curve for cooling capacity
    # obtaining the coefficients in the original Q curve
    string_objects, workspace = _write_ems_curves(workspace, runner, user_arguments, coil_choice, coilcooling, string_objects, coiltype)

    # write EMS sensors for schedules of fault levels
    string_objects = fault_level_sensor_sch_insert(workspace, string_objects, $faultnow, coil_choice, sch_choice)

    # write variable definition for EMS programs
    # EMS Sensors to the workspace
    # check if the sensors are added previously by other fault models
    _write_ems_sensors(workspace, runner, coilcooling, sh_coil_choice, string_objects, find_outdoor_node_name(workspace), coiltype)
	#Fault intensity adjustment factor for dynamic modeling
	faultintensity_adjustmentfactor(string_objects, time_constant, time_step, start_month, start_date, start_time, end_month, end_date, end_time, fault_lvl, sch_choice)


    # create EMS for adjusting the bypass factor according to the fault level
    # stored in the form of rated SHR
    # check if cooling capacity and volumetric airflow are rated or manual
    # _configure_shr(runner, user_arguments, coilcooling, fault_lvl, coil_choice, string_objects)

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
    runner.registerError("Measure CondenserFouling cannot find #{coil_choice}. Exiting......")
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

  def _write_ems_curves(workspace, runner, user_arguments, coil_choice, coilcooling, string_objects, coiltype)
    # This function writes the original and adjustment curves in EMS
    string_objects = _write_q_and_eir_curves(workspace, coil_choice, coilcooling, string_objects, runner, coiltype)
    string_objects, workspace = _write_q_and_eir_adj_routine(workspace, runner, user_arguments, coil_choice, coilcooling, string_objects, coiltype)
    return string_objects, workspace
  end

  def _write_q_and_eir_curves(workspace, coil_choice, coilcooling, string_objects, runner, coiltype)
    # This function appends and returns the string_objects with ems program statements. It also
    # returns a boolean to indicate if the addition is successful

    # curves generated by OpenStudio. No need to check
    ##################################################
    if coiltype == 1 #SINGLESPEED
      string_objects, curve_exist = _write_curves(workspace, coil_choice, coilcooling, string_objects, 'Q', 9, runner, coiltype, [])
      string_objects, curve_exist = _write_curves(workspace, coil_choice, coilcooling, string_objects, 'EIR', 11, runner, coiltype, [])
    elsif coiltype == 2 #TWOSTAGEWITHHUMIDITYCONTROLMODE
      coilperformancedxcoolings = workspace.getObjectsByType(coilcooling.getString(8).to_s.to_IddObjectType)
      coilperformancedxcoolings.each do |coilperformancedxcooling|
	string_objects, curve_exist = _write_curves(workspace, coil_choice, coilcooling, string_objects, 'Q', 6, runner, coiltype, coilperformancedxcooling)
	string_objects, curve_exist = _write_curves(workspace, coil_choice, coilcooling, string_objects, 'EIR', 8, runner, coiltype, coilperformancedxcooling)
      end
    end
    ##################################################
    return string_objects
  end

  def _write_q_and_eir_adj_routine(workspace, runner, user_arguments, coil_choice, coilcooling, string_objects, coiltype)
    # This function writes the adjustment routines of the Q and EIR curves to impose faults

    # pass the minimum and maximum values of model inputs to ca_q_para and ca_eir_para to insert them to the subroutines
    q_para, eir_para = _get_parameters(runner, user_arguments)

    # write the EMS subroutines
    ##################################################
    if coiltype == 1 #SINGLESPEED
      string_objects, workspace = general_adjust_function(workspace, coil_choice, string_objects, coilcooling, 'Q', q_para, $faultnow, coiltype, [], 9)
      string_objects, workspace = general_adjust_function(workspace, coil_choice, string_objects, coilcooling, 'EIR', eir_para, $faultnow, coiltype, [], 11)
    elsif coiltype == 2 #TWOSTAGEWITHHUMIDITYCONTROLMODE
      coilperformancedxcoolings = workspace.getObjectsByType(coilcooling.getString(8).to_s.to_IddObjectType)
      coilperformancedxcoolings.each do |coilperformancedxcooling|
	string_objects, workspace = general_adjust_function(workspace, coil_choice, string_objects, coilcooling, 'Q', q_para, $faultnow, coiltype, coilperformancedxcooling, 6)
        string_objects, workspace = general_adjust_function(workspace, coil_choice, string_objects, coilcooling, 'EIR', eir_para, $faultnow, coiltype, coilperformancedxcooling, 8)
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

  def _write_curves(workspace, coil_choice, coilcooling, string_objects, curve_name, curve_index, runner, coiltype, coilperformancedxcooling)
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
    string_objects = main_program_entry(workspace, string_objects, coil_choice, curve_nameq, paraq, curve_name)
    return string_objects, true
  end

  def _get_parameters(runner, user_arguments)
    # This function returns the parameters for Q and EIR calculation

    min_fl = runner.getDoubleArgumentValue('min_fl', user_arguments)
    max_max_para = _get_ext_from_argumets(runner, user_arguments)

    uc_q_para = runner_pass_coefficients(runner, user_arguments, $q_para_num, "Q_#{$faultnow}")
    q_para = [min_fl, uc_q_para, max_max_para]
    q_para.flatten!

    uc_eir_para = runner_pass_coefficients(runner, user_arguments, $eir_para_num, "EIR_#{$faultnow}")
    eir_para = [min_fl, uc_eir_para, max_max_para]
    eir_para.flatten!

    return q_para, eir_para
  end

  def _get_ext_from_argumets(runner, user_arguments)
    # This function returns a list of parameters corresponding to minimums and maximums temperature
    # and rated COP to the model

    min_wb_tmp_uc = runner.getDoubleArgumentValue('min_wb_tmp_uc', user_arguments)
    max_wb_tmp_uc = runner.getDoubleArgumentValue('max_wb_tmp_uc', user_arguments)
    min_cond_tmp_uc = runner.getDoubleArgumentValue('min_cond_tmp_uc', user_arguments)
    max_cond_tmp_uc = runner.getDoubleArgumentValue('max_cond_tmp_uc', user_arguments)
    min_cop_uc = runner.getDoubleArgumentValue('min_cop_uc', user_arguments)
    max_cop_uc = runner.getDoubleArgumentValue('max_cop_uc', user_arguments)

    return [min_wb_tmp_uc, max_wb_tmp_uc, min_cond_tmp_uc, max_cond_tmp_uc, min_cop_uc, max_cop_uc]
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

  def _configure_shr(runner, user_arguments, coilcoolingdxsinglespeed, fault_lvl, coil_choice, string_objects)
    # change shr code if needed
    usercap, usershr, uservol = _change_shr_input(runner, user_arguments, coilcoolingdxsinglespeed)
    _write_shr_change_code(runner, user_arguments, fault_lvl, usercap, usershr, uservol, coil_choice, string_objects)
  end

  def _change_shr_input(runner, user_arguments, coilcoolingdxsinglespeed)
    usercap = runner.getDoubleArgumentValue('q_rat', user_arguments)
    usershr = runner.getDoubleArgumentValue('shr_rat', user_arguments)
    uservol = runner.getDoubleArgumentValue('vol_rat', user_arguments)
    unless _check_autosize(pass_string(coilcoolingdxsinglespeed, 2))
      usercap = pass_float(coilcoolingdxsinglespeed, 2)
    end
    unless _check_autosize(pass_string(coilcoolingdxsinglespeed, 3))
      usershr = pass_float(coilcoolingdxsinglespeed, 3)
      # set the shr back to autosize so that it can be overwritten by this code later
      coilcoolingdxsinglespeed.setString(3, 'autosize')
    end
    unless _check_autosize(pass_string(coilcoolingdxsinglespeed, 5))
      uservol = pass_float(coilcoolingdxsinglespeed, 5)
    end
    return usercap, usershr, uservol
  end

  def _check_autosize(givenstr)
    # Thie function checks if the string in givenstr is 'autosize'
    return givenstr.downcase.eql?('autosize')
  end

  def _write_shr_change_code(runner, user_arguments, fault_lvl, usercap, usershr, uservol, coil_choice, string_objects)
    # This function writes the code to change rated SHR according to the model
    return if usercap == -1.0 || usershr == -1.0 || uservol == -1.0
    bf_para = runner.getDoubleArgumentValue('bf_para', user_arguments)
    sh_coil_choice = name_cut(coil_choice)
    # start writing the program
    string_objects << "
      EnergyManagementSystem:Program,
        #{$faultnow}_DXSHRMod#{sh_coil_choice}, !- Name
        SET TTmp = 26.7, !- Program Line 1
        SET WTmp = 0.011152,   !- Program Line 2
        SET PTmp = 101325.0,     !- <none>
        SET Hin = @HFnTdbW TTmp WTmp,  !- <none>
        SET Rhoin = @RhoAirFnPbTdbW PTmp TTmp WTmp,  !- <none>
        SET Qrat = #{usercap}, !- <none>
        SET SHRrat = #{usershr}, !- <none>
        SET Volrat = #{uservol}, !- <none>
        SET Mdota = Rhoin*Volrat, !- <none>
        SET DeltaH = Qrat/mdota, !- <none>
        SET HTinWout = Hin-(1-SHRrat)*DeltaH, !- <none>
        SET Wout = @WFnTdbH TTmp HTinWout, !- <none>
        SET Hout = Hin-DeltaH, !- <none>
        SET Tout = @TdbFnHW Hout Wout, !- <none>
        SET DeltaT = TTmp-Tout, !- <none>
        SET DeltaW = WTmp-Wout, !- <none>
        SET Slopeadp#{$faultnow}#{sh_coil_choice} = DeltaW/DeltaT, !- <none>
        SET Tadp#{$faultnow}#{sh_coil_choice} = Tout-1.0, !- <none>
        SET Tin#{$faultnow}#{sh_coil_choice} = TTmp, !- <none>
        SET Win#{$faultnow}#{sh_coil_choice} = WTmp, !- <none>
        SET Patm#{$faultnow}#{sh_coil_choice} = PTmp, !- <none>
        RUN TADP#{$faultnow}#{sh_coil_choice}SOLVER, !- <none>
        SET Tadp = Tadp#{$faultnow}#{sh_coil_choice}, !- <none>
        SET Wadp = Wadp#{$faultnow}#{sh_coil_choice}, !- <none>
        SET Hadp = @HFnTdbW Tadp Wadp, !- <none>
        SET BF = Hout-Hadp, !- <none>
        SET BF = BF/(Hin-Hadp), !- <none>
        SET Ao = @Ln BF, !- <none>
        SET Ao = mdota*Ao, !- <none>
        SET Ao = -1.0*Ao, !- <none>
        SET adjAo = #{bf_para}*#{fault_lvl}, !- <none>
        SET adjAo = 1+adjAo, !- <none>
        SET Ao = Ao*adjAo, !- <none>
        SET BF = -1.0*Ao, !- <none>
        SET BF = BF/mdota, !- <none>
        SET BF = @Exp BF, !- <none>
        SET Hadp = BF*Hin, !- <none>
        SET Hadp = Hadp-Hout, !- <none>
        SET Hadp = Hadp/(BF-1.0), !- <none>
        SET Tadp = @TsatFnHPb Hadp PTmp, !- <none>
        SET Wadp = @WFnTdbH Tadp Hadp, !- <none>
        SET DeltaT = TTmp-Tadp, !- <none>
        SET DeltaW = WTmp-Wadp, !- <none>
        SET Slopeadp#{$faultnow}#{sh_coil_choice} = DeltaW/DeltaT, !- <none>
        SET Tout#{$faultnow}#{sh_coil_choice} = Tadp+1.0, !- <none>
        SET Hout#{$faultnow}#{sh_coil_choice} = Hout, !- <none>
        SET Tin#{$faultnow}#{sh_coil_choice} = TTmp, !- <none>
        SET Win#{$faultnow}#{sh_coil_choice} = WTmp, !- <none>
        SET Patm#{$faultnow}#{sh_coil_choice} = PTmp, !- <none>
        RUN TOUT#{$faultnow}#{sh_coil_choice}SOLVER, !- <none>
        SET Tout = Tout#{$faultnow}#{sh_coil_choice}, !- <none>
        SET Wout = Wout#{$faultnow}#{sh_coil_choice}, !- <none>
        IF Wout >= WTmp, !- <none>
        SET SHRnew = 1.0,
        ELSE,
        SET Hfgadp = @HfgAirFnWTdb Wadp Tadp, !- To ensure that a drop of w causes SHR to be below 1
        SET qlat = WTmp-Wout,
        SET qlat = Hfgadp*qlat,
        SET SHRnew = 1.0-qlat/(Hin-Hout),
        ENDIF,
        SET SHRnew#{$faultnow}#{sh_coil_choice} = SHRnew;
    "

    string_objects << "
      EnergyManagementSystem:ProgramCallingManager,
      EMSCall#{$faultnow}_DXSHRMod#{sh_coil_choice}, !- Name
      AfterComponentInputReadIn, !- EnergyPlus Model Calling Point, only works when the SHR is autosized
      #{$faultnow}_DXSHRMod#{sh_coil_choice}; !- Program Name 1
    "

    string_objects << "
      EnergyManagementSystem:Actuator,
        SHRnew#{$faultnow}#{sh_coil_choice}, !- Name
        #{coil_choice}, !- Component Name
        Coil:Cooling:DX:SingleSpeed, !- Actuated Component Type
        Autosized Rated Sensible Heat Ratio; !- Actuated Component Control Type
    "

    string_objects << "
      EnergyManagementSystem:Program,
        TADP#{$faultnow}#{sh_coil_choice}SOLVER, !- Iteratively calculate the Tadp to match the slope
        SET Tadp = Tadp#{$faultnow}#{sh_coil_choice}, !- <none>
        SET Slopeadp = Slopeadp#{$faultnow}#{sh_coil_choice}, !- <none>
        SET PTmp = Patm#{$faultnow}#{sh_coil_choice}, !- <none>
        SET Tin = Tin#{$faultnow}#{sh_coil_choice}, !- <none>
        SET Win = Win#{$faultnow}#{sh_coil_choice}, !- <none>
        SET Thres = 0.0001,
        SET NegThres = -1.0*Thres,
        SET Error = 1000.0,
        SET Errorlast = Error,
        SET DeltaTadp = 5.0,
        SET IT = 1,
        WHILE ((Error > Thres || Error < NegThres) && IT < 100), !- Method from DXCoils.cc in EnergyPlus
        IF IT > 1,
        SET Tadp = Tadp+DeltaTadp,
        ENDIF,
        SET Wadp = @WFnTdbRhPb Tadp 1.0 PTmp,
        SET Slope = Win-Wadp,
        SET Slope = Slope/(Tin-Tadp),
        SET Error = Slope-Slopeadp,
        SET Error = Error/Slopeadp,
        IF IT > 1,
        IF Error > 0.0 && Errorlast <= 0.0,
        SET DeltaTadp = DeltaTadp/2.0,
        SET DeltaTadp = -1.0*DeltaTadp,
        ELSEIF Error <= 0.0 && Errorlast > 0.0,
        SET DeltaTadp = DeltaTadp/2.0,
        SET DeltaTadp = -1.0*DeltaTadp,
        ELSEIF Error > 0.0 && Errorlast > 0.0 && Error > Errorlast,
        SET DeltaTadp = -1.0*DeltaTadp,
        ELSEIF Error < 0.0 && Errorlast < 0.0 && Error < Errorlast,
        SET DeltaTadp = -1.0*DeltaTadp,
        ENDIF,
        ENDIF,
        SET IT = IT+1,
        SET Errorlast = Error,
        ENDWHILE,
        SET Tadp#{$faultnow}#{sh_coil_choice} = Tadp,
        SET Wadp#{$faultnow}#{sh_coil_choice} = Wadp;
    "

    string_objects << "
      EnergyManagementSystem:Program,
        TOUT#{$faultnow}#{sh_coil_choice}SOLVER, !- Iteratively calculate the Tadp to match the slope
        SET Tout = Tout#{$faultnow}#{sh_coil_choice}, !- <none>
        SET Hout = Hout#{$faultnow}#{sh_coil_choice}, !- <none>
        SET Slopeadp = Slopeadp#{$faultnow}#{sh_coil_choice}, !- <none>
        SET PTmp = Patm#{$faultnow}#{sh_coil_choice}, !- <none>
        SET Tin = Tin#{$faultnow}#{sh_coil_choice}, !- <none>
        SET Win = Win#{$faultnow}#{sh_coil_choice}, !- <none>
        SET Thres = 0.0001,
        SET NegThres = -1.0*Thres,
        SET Error = 1000.0,
        SET Errorlast = Error,
        SET DeltaTout = 5.0,
        SET IT = 1,
        WHILE ((Error > Thres || Error < NegThres) && IT < 100), !- Method from DXCoils.cc in EnergyPlus
        IF IT > 1,
        SET Tout = Tout+DeltaTout,
        ENDIF,
        SET Wout = @WFnTdbH Tout Hout,
        SET Slope = Win-Wout,
        SET Slope = Slope/(Tin-Tout),
        SET Error = Slope-Slopeadp,
        SET Error = Error/Slopeadp,
        IF IT > 1,
        IF Error > 0.0 && Errorlast <= 0.0,
        SET DeltaTout = DeltaTout/2.0,
        SET DeltaTout = -1.0*DeltaTout,
        ELSEIF Error <= 0.0 && Errorlast > 0.0,
        SET DeltaTout = DeltaTout/2.0,
        SET DeltaTout = -1.0*DeltaTout,
        ELSEIF Error > 0.0 && Errorlast > 0.0 && Error > Errorlast,
        SET DeltaTout = -1.0*DeltaTout,
        ELSEIF Error < 0.0 && Errorlast < 0.0 && Error < Errorlast,
        SET DeltaTout = -1.0*DeltaTout,
        ENDIF,
        ENDIF,
        SET IT = IT+1,
        SET Errorlast = Error,
        ENDWHILE,
        SET Tout#{$faultnow}#{sh_coil_choice} = Tout,
        SET Wout#{$faultnow}#{sh_coil_choice} = Wout;
    "

    # add global variables
    _add_gb_var(string_objects, sh_coil_choice)
  end

  def _add_gb_var(string_objects, sh_coil_choice)
    global_vars = [
      "Tadp#{$faultnow}#{sh_coil_choice}", "Slopeadp#{$faultnow}#{sh_coil_choice}",
      "Patm#{$faultnow}#{sh_coil_choice}", "Tin#{$faultnow}#{sh_coil_choice}",
      "Win#{$faultnow}#{sh_coil_choice}", "Wadp#{$faultnow}#{sh_coil_choice}",
      "Tout#{$faultnow}#{sh_coil_choice}", "Wout#{$faultnow}#{sh_coil_choice}",
      "Hout#{$faultnow}#{sh_coil_choice}"
    ]
    global_vars.each do |global_var|
      string_objects << ems_globalvariable_str(global_var)
    end
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
CondenserFouling.new.registerWithApplication
