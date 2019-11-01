# Condenser Fan Degradation

## Description

  def description
    return "Motor efficiency degrades when a motor suffers from a bearing or a stator winding fault. This fault causes the motor to draw higher electrical current without changing the fluid flow. Both a bearing fault and a stator winding fault can be modeled by increasing the power consumption of the condenser fan without changing the airflow of the condenser fan. This fault is categorized as a fault that occur in the vapor compression system during the operation stage. This fault measure is based on an empirical model and simulates the condenser fan degradation by modifying the Coil:Cooling:DX:SingleSpeed object in EnergyPlus assigned to the heating and cooling system. The fault intensity (F) is defined as the reduction in motor efficiency as a fraction of the non-faulted motor efficiency with the application range of 0 to 0.3 (30% degradation)."
  end
  
## Modeler Description

  def modeler_description
    return "Three user inputs are required and, based on these user inputs, the EIR in the DX cooling coil model is recalculated to reflect the faulted operation as shown in the equation below, EIR_F/EIR=1+(W ̇_fan/W ̇_cool)*(F/(1-F)), where EIR_F is the faulted EIR, W ̇_fan is the fan power, W ̇_cool is the DX  coil power, and F is the fault intensity. This fault model also requires the ratio of condenser fan power to the power consumption of compressor and condenser fan as a user input parameter."
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
    
    sch_choice = OpenStudio::Ruleset::OSArgument::makeStringArgument("sch_choice", true)
    sch_choice.setDisplayName("Enter the name of the schedule of the fault level. If you do not have a schedule, leave this blank.")
    sch_choice.setDefaultValue("")
    args << sch_choice  #FUTURE: detect empty string later for users who provide no schedule, and delete schedule_exist
	
    fault_lvl = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("fault_lvl", false)
    fault_lvl.setDisplayName("Fan motor efficiency degradation ratio [-]")
    fault_lvl.setDefaultValue(0.5)  #default fouling level to be 50%
    args << fault_lvl

    fan_power_ratio = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("fan_power_ratio", false)
    fan_power_ratio.setDisplayName("Ratio of condenser fan motor power consumption to combined power consumption of condenser fan and compressor at rated condition.")
    fan_power_ratio.setDefaultValue(0.091747081)  #defaulted calcualted to be 0.0917
    args << fan_power_ratio
    
    return args
  end
  
## Initial Condition

runner.registerInitialCondition("Imposing performance degradation on "+coil_choice_all+".")

## Final Condition

runner.registerFinalCondition("Imposed performance degradation on "+coil_choice_all+".")

## Not Applicable

    runner.registerAsNotApplicable("CondenserFanDegradation is not running for "+coil_choice_all+". Skipping......")

## Warning

n/a

## Error

    runner.registerError("User-defined schedule "+sch_choice+" does not exist. Exiting......")
    runner.registerError("User-defined schedule "+sch_choice+" has a ScheduleTypeLimits outside the range 0 to 1.0. Exiting......")
    runner.registerError("Fault level #{degrd_lvl} for "+coil_choice_all+" is oustide the range from 0 to 0.99. Exiting......")
    runner.registerError(coil_choice+" is not air cooled. Impossible to impose condenser fan motor efficiency degradation. Exiting......")
    runner.registerError("No Temperature Adjustment Curve for "+coil_choice+" EIR. Exiting......")
    runner.registerError("Measure CondenserFanDegradation cannot find "+coil_choice_all+". Exiting......")

## Information

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
•	Create string object in idf (with EMS) for fault implementation.
•	Create fractional schedule object for fault level implementation... _create_schedules_and_typelimits
•	Create schedule object according to fault level... _create_schedule_objects_create_schedule_objects
•	Returns workspace object in certain category... get_workspace_objects
•	Trim name without space and symbols... name_cut
•	Create schedule object with zero and one... no_fault_schedules
•	Append EMS code for altering EIR due to fault... _write_ems_curves
•	Write EMS code to generate EIR performance curve... _write_q_and_eir_curves
•	Write EMS code to alter performance curve... _write_curves
•	Get parameters from biquadratic function... para_biquadratic_limit
•	Write EMS main program to alter temperature curve... main_program_entry
•	Write EMS code to alter EIR performance... _write_q_and_eir_adj_routine
•	Returns parameters for EIR calculation... _get_parameters
•	Write EMS code to calculate fault impact ratio... general_adjust_function
•	Write dummy EMS code in case of fault is not modeled... dummy_fault_sub_add
•	Append EMS code for defining EMS sensor object... _write_ems_sensors
•	Create EMS sensor object... ems_sensor_str
•	Check whether the same object already exists... check_exist_workspace_objects
•	Append EMS code for defining EMS output object.
•	Append EMS code that calculates the adjustment factor (AF)… faultintensity_adjustmentfactor

## Tests
●	Test model with and without schedule of fault presence
●	Test invalid user argument values to make sure measure fails gracefully



