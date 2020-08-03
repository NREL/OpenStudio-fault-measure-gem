# Condenser Fouling

## Description

  def description
    return "Condenser fouling occurs when litter, dirt, or dust accumulates on or between the fins of a condenser of an air conditioner located in the outdoor environment. The blockage reduces the airflow across the condenser and increases the condensing temperature in the refrigerant circuit. The elevated temperature increases the pressure difference across the compressor and reduces the equipment efficiency. This fault is categorized as a fault that occur in the vapor compression system during the operation stage. This fault measure is based on an empirical model and simulates condenser fouling by modifying the Coil:Cooling:DX:SingleSpeed or Coil:Cooling:DX:TwoStageWithHumiditycontrolmodes object in EnergyPlus assigned to the heating and cooling system. The fault intensity (F) for this fault is defined as the ratio of reduction in condenser coil airflow at full load with the application range of 0 to 0.5 (50% reduction)."
  end
  
## Modeler Description

  def modeler_description
    return "Thirty two user inputs (DX coil where the fault occurs / Percentage reduction of condenser airflow / rated cooling capacity / rated sensible heat ratio / rated volumetric flow rate / maximum fault intensity / empirical model coefficients / minimum-maximum evaporator air inlet wet-bulb temperature / minimum-maximum condenser air inlet dry-bulb temperature / minimum-maximum rated COP / percentage change of UA with increase of fault level / time required for fault to reach full level / fault starting month / fault starting date / fault starting time / fault ending month / fault ending date / fault ending time) can be defined or remained with default values. Based on user inputs, the cooling capacity (Q ̇_cool) and EIR in the DX cooling coil model is recalculated to reflect the faulted operation. The time required for the fault to reach the full level is only required when the user wants to model fault evolution. If the fault evolution is not necessary for the user, it can be defined as zero and F will be imposed as a step function with the user defined value. However, by defining the time required for the fault to reach the full level, fault starting month/date/time and fault ending month/date/time, the adjustment factor AF is calculated at each time step starting from the starting month/date/time to gradually impose F based on the user specified time frame. AF is calculated as follows, AF_current = AF_previous + dt/tau where AF_current is the adjustment factor calculated based on the previously calculated adjustment factor (AF_previous), simulation timestep (dt) and the time required for the fault to reach the full level (tau)."
  end
  
## Measure Type

EnergyPlus Measure

## Taxonomy

HVAC.Cooling

## Arguments 

def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

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
		
    coil_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("coil_choice", list, true)
    coil_choice.setDisplayName("Enter the name of the faulted Coil:Cooling:DX:SingleSpeed object. If you want to impose the fault on all coils, select #{$all_coil_selection}")
    coil_choice.setDefaultValue($all_coil_selection)
    args << coil_choice

    fault_lvl = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('fault_lvl', false)
    fault_lvl.setDisplayName('Percentage reduction of condenser airflow [-]')
    fault_lvl.setDefaultValue(0.1)  # defaulted at 10%
    args << fault_lvl

    q_rat = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('q_rat', true)
    q_rat.setDisplayName('Rated cooling capacity of the cooling coil for bypass factor model adjustment. If your system is autosized or you do not know what this is, please run the OS Measure Auto Size to Hard Size before this Measure. If your system is hard sized, leave this value at -1.0. (W)')
    q_rat.setDefaultValue(-1.0)
    args << q_rat

    shr_rat = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('shr_rat', true)
    shr_rat.setDisplayName('Rated sensible heat ratio of the cooling coil for bypass factor model adjustment. If your system is autosized or you do not know what this is, please run the OS Measure Auto Size to Hard Size before this Measure. If your system is hard sized, leave this value at -1.0.')
    shr_rat.setDefaultValue(-1.0)
    args << shr_rat

    vol_rat = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('vol_rat', true)
    vol_rat.setDisplayName('Rated air flow rate of the cooling coil for bypass factor model adjustment. If your system is autosized or you do not know what this is, please run the OS Measure Auto Size to Hard Size before this Measure. If your system is hard sized, leave this value at -1.0. (m3/s)')
    vol_rat.setDefaultValue(-1.0)
    args << vol_rat

    min_fl = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('min_fl', true)
    min_fl.setDisplayName('Maximum value of fault level [-]')
    min_fl.setDefaultValue(0.5)
    args << min_fl


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

    bf_para = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('bf_para', false)
    bf_para.setDisplayName('Percentage change of UA with increase of fault level level (% of UA/% of fault level)')
    bf_para.setDefaultValue(0.00)  # default change of bypass factor level with fault level in %
    args << bf_para

    time_constant = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('time_constant', false)
    time_constant.setDisplayName('Enter the time required for fault to reach full level [hr]')
    time_constant.setDefaultValue(0)  #default is zero
    args << time_constant
	
    start_month = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_month', false)
    start_month.setDisplayName('Enter the month (1-12) when the fault starts to occur')
    start_month.setDefaultValue(6)  #default is June
    args << start_month
	
    start_date = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_date', false)
    start_date.setDisplayName('Enter the date (1-28/30/31) when the fault starts to occur')
    start_date.setDefaultValue(1)  #default is 1st day of the month
    args << start_date
	
    start_time = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_time', false)
    start_time.setDisplayName('Enter the time of day (0-24) when the fault starts to occur')
    start_time.setDefaultValue(9)  #default is 9am
    args << start_time
	
    end_month = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('end_month', false)
    end_month.setDisplayName('Enter the month (1-12) when the fault ends')
    end_month.setDefaultValue(12)  #default is Decebmer
    args << end_month
	
    end_date = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('end_date', false)
    end_date.setDisplayName('Enter the date (1-28/30/31) when the fault ends')
    end_date.setDefaultValue(31)  #default is last day of the month
    args << end_date
	
    end_time = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('end_time', false)
    end_time.setDisplayName('Enter the time of day (0-24) when the fault ends')
    end_time.setDefaultValue(23)  #default is 11pm
    args << end_time

    return args
  end
  
## Initial Condition

runner.registerInitialCondition("Imposing performance degradation on #{coil_choice}.")

## Final Condition

runner.registerFinalCondition("Imposed performance degradation on #{coil_choice}.")

## Not Applicable

    runner.registerAsNotApplicable("CondenserFouling is not running for #{coil_choice}. Skipping......")

## Warning

n/a

## Error

    runner.registerError("Fault level #{fault_lvl} for #{coil_choice} is outside the range from 0 to 1. Exiting......")
    runner.registerError("#{coil_choice} is not air cooled. Impossible to continue in CondenserFouling. Exiting......")
    runner.registerError("No Temperature Adjustment Curve for #{coil_choice} #{curve_name} model. Exiting......")
    runner.registerError("Measure CondenserFouling cannot find #{coil_choice}. Exiting......")

## Information

•	Measures below share the same resource codes.
•	Condenser Fouling
•	Liquid-line Restriction
•	Nonstandard Charging
•	Presence of Noncondensable
•	Works with, 
•	Coil:Cooling:DX:SingleSpeed 
•	Coil:Cooling:DX:TwoStageWithHumidityControlMode.
•	Future refinement items are,
•	Capability to work with other DX models.
•	Capability of generic autosizing to hardsizing.
Code Outline
•	Define arguments.
•	Find the DX unit where fault occurs.
•	Check whether fault intensity value is valid between 0-1.
•	Check rated SHR in the selected DX unit and replace with degraded value... shr_modification
•	Create string object in idf (with EMS) for fault implementation.
•	Create fractional schedule object for fault level implementation... _create_schedules_and_typelimits
•	Create schedule object according to fault level... _create_schedule_objects_create_schedule_objects
•	Returns workspace object in certain category... get_workspace_objects
•	Trim name without space and symbols... name_cut
•	Create schedule object with zero and one... no_fault_schedules
•	Append EMS code for altering cooling capacity and EIR due to fault... _write_ems_curves
•	Write EMS code to generate capacity and EIR performance curve... _write_q_and_eir_curves
•	Write EMS code to alter performance curve... _write_curves
•	Get parameters from biquadratic function... para_biquadratic_limit
•	Write EMS main program to alter temperature curve... main_program_entry
•	Write EMS code to alter capacity and EIR performance... _write_q_and_eir_adj_routine
•	Returns parameters for capacity and EIR calculation... _get_parameters
•	Returns list of parameters min & max temperature & COP... _get_ext_from_argumets
•	Returns an array of coefficients... runner_pass_coefficients
•	Write EMS code to calculate fault impact ratio... general_adjust_function
•	Write dummy EMS code in case of fault is not modeled... dummy_fault_sub_add
•	Append EMS code for defining EMS sensor object... _write_ems_sensors
•	Create EMS sensor object... ems_sensor_str
•	Check whether the same object already exists... check_exist_workspace_objects
•	Append EMS code for defining EMS output object.
•	Append EMS code that calculates the adjustment factor (AF)… faultintensity_adjustmentfactor

## Tests

●	Test invalid user argument values to make sure measure fails gracefully
●	Test different levels of fault intensity
●	Test different sets of rated conditions
●	Test different sets of coefficients for regression model



