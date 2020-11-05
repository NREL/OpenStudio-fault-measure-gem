# Duct Fouling

## Description

  def description
    return "Ducts are fouled by dust that accumulates in the filter and/or fins of heat exchangers in the indoor air ducts. The accumulation increases the flow resistance of the air duct and changes the airflow and pressure drop across the duct in accordance with the controls of the fan rotational speed. This fault is categorized as a fault that occur in the ventilation system during the operation stage. This fault measure is based on an empirical model and simulates duct fouling by modifying either Fan:ConstantVolume, Fan:VariableVolume, Fan:OnOff, or Fan:VariableVolume objects in EnergyPlus assigned to the air system. F is the fault intensity defined as the reduction in evaporator coil airflow at full load condition as a ratio of the design airflow rate with the application range of 0 to 0.5 (50% reduction)."
  end
  
## Modeler Description

  def modeler_description
    return "Two additional user inputs are required. Based on these user inputs, the maximum supply airflow rate parameter defined in fan objects is replaced based on equation, mdot_(a,max,F) = mdot_(a,max)∙(1-F), where mdot_(a,max,F) is the maximum airflow rate of the faulted condition, mdot_(a,max) is the maximum airflow rate under normal conditions, and F is the fault intensity defined as the reduction in evaporator coil airflow at full load condition as a ratio of the design airflow rate.  There is a pressure rise (r_pd) parameter that is also required in fan objects in order to properly reflect evaporator fouling. Equation, F = 1-√((1+r_pd-c_F)/(1-c_F ))  shows the relation between F and r_pd that is used to calculate the pressure rise based on the fault intensity level. cF is the coefficient that is determined based on the training data set."
  end
  
## Measure Type

OpenStudio Measure 

## Taxonomy

HVAC.Ventilation

## Arguments 

  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    airloophvacs = model.getAirLoopHVACs
    chs = OpenStudio::StringVector.new
    chs << $allahuchoice
    airloophvacs.each do |airloophvac|
      chs << airloophvac.name.to_s
    end
    equip_name = OpenStudio::Ruleset::OSArgument.makeChoiceArgument('equip_name', chs, true)  #  use the names for choices of equipment
    equip_name.setDisplayName('Choice of AirLoopHVAC objects. If you want to impose it on all AHUs, choose * ALL AHUs *')
    equip_name.setDefaultValue($allahuchoice)
    args << equip_name
    
    evap_flow_reduction = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('evap_flow_reduction', true)
    evap_flow_reduction.setDefaultValue(0.1)
    evap_flow_reduction.setDisplayName('Decrease of air mass flow rate ratio when the fans are running at their maximum speed (0-1). (-)')
    args << evap_flow_reduction
    
    args = enter_coefficients(args, 1, 'fanCurve', [1.4048])

    return args
  end
  
## Initial Condition

runner.registerInitialCondition('Fouling are being applied on all AHUs......')
runner.registerInitialCondition(“Fouling is being applied to the #{equip_name}......")

## Final Condition

runner.registerFinalCondition('Fouling are applied on all AHUs......')
runner.registerFinalCondition("Fouling is applied to the #{equip_name}......")

## Not Applicable

    runner.registerAsNotApplicable("Fouling level is zero. Skipping the Measure #{name}")

## Warning

n/a

## Error
    runner.registerError("User defined fouling level in Measure #{name} is negative. Exiting......")
    runner.registerError("The resultant mass flow rate in Measure #{name} is negative. Exiting......")
    runner.registerError("Cannot find the airflow corresponding to the minimum power consumption. Exiting......")
    runner.registerError("Dekker method fails with x_high at #{x_high}, x_low at #{x_low}, y_new at #{y_new} and mulp at #{mulp}. Exiting......")

## Information

•	Works with, 
•	Fan:ConstantVolume
•	Fan:VariableVolume 
•	Fan:OnOff
Code Outline
•	Define arguments (AHU where fault occurs and flow reduction due to fouling).
•	Check user defined flow reduction value due to fouling is within 0-1. 
•	Find the AHU and apply fault based on user inputs.
•	Find Fan:ConstantVolume object in the AHU and apply fault.
•	If the fan flow rate is hard sized, then skip.
•	Else, change the fan configuration based on user defined fault intensity.
•	Pressure rise.
•	Maximum flow rate.
•	Find Fan:VariableVolume object in the AHU and apply fault.
•	If the fan flow rate is hard sized, then skip.
•	Else, change the fan configuration based on user defined fault intensity.
•	Pressure rise.
•	Maximum flow rate.
•	Fan power minimum flow fraction.
•	Fan power minimum air flow rate. 
•	Find Fan:OnOff object in the AHU and apply fault.
•	If the fan flow rate is hard sized, then skip.
•	Else, change the fan configuration based on user defined fault intensity.
•	Pressure rise.
•	Maximum flow rate.

## Tests

●	Test invalid user argument values to make sure measure fails gracefully.
●	Test three fan objects (Fan:ConstantVolume, Fan:VariableVolume, Fan:OnOff). 
