# Oversized Equipment at Design

## Description

    def description
    return "Oversizing of heating and cooling equipment is commonly accepted in real-world applications. In a previous study, more than 40% of the units surveyed were oversized by more than 25%, and 10% were oversized by more than 50%. System oversizing can ensure that the highest heating and cooling demands are met. But excessive oversizing of units can lead to increased equipment cycling with increased energy use due to efficiency losses. This fault is categorized as a fault that occur in the HVAC system during the design stage. This fault measure is based on a physical model where certain parameter(s) is changed in EnergyPlus to mimic the faulted operation; thus simulates oversized equipment by modifying Sizing:Parameters object in EnergyPlus. The fault intensity (F) is defined as the ratio of increased sizing compared to the correct sizing."
  end
  
## Modeler Description

  def modeler_description
    return "This measure simulates the effect of oversized equipment at design by modifying the Sizing:Parameters object and capacity fields in coil objects in EnergyPlus assigned to the heating and cooling system. One user input is required; percentage of increased sizing. Current measure applicable to following objects; coilcoolingdxsinglespeed, coilcoolingdxtwospeed,  coilcoolingdxtwostagewithhumiditycontrolmode, coilcoolingdxvariablerefrigerantflow, coilheatingdxvariablerefrigerantflow, coilheatinggas, coilheatingelectric."
  end
  
## Measure Type

OpenStudio Measure 
	
## Taxonomy

HVAC.Whole System

## Arguments 

  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    list = OpenStudio::StringVector.new
    list << $all_coil_selection
	
    coilcoolingdxsinglespeeds = model.getCoilCoolingDXSingleSpeeds
    coilcoolingdxsinglespeeds.each do |coilcoolingdxsinglespeed|
      list << coilcoolingdxsinglespeed.name.to_s
    end
    coilcoolingdxtwospeeds = model.getCoilCoolingDXTwoSpeeds
    coilcoolingdxtwospeeds.each do |coilcoolingdxtwospeed|
      list << coilcoolingdxtwospeed.name.to_s
    end
    coilcoolingdxtwostagewithhumiditycontrolmodes = model.getCoilCoolingDXTwoStageWithHumidityControlModes
    coilcoolingdxtwostagewithhumiditycontrolmodes.each do |coilcoolingdxtwostagewithhumiditycontrolmode|
      list << coilcoolingdxtwostagewithhumiditycontrolmode.name.to_s
    end
    coilcoolingdxvariablerefrigerantflows = model.getCoilCoolingDXVariableRefrigerantFlows
    coilcoolingdxvariablerefrigerantflows.each do |coilcoolingdxvariablerefrigerantflow|
      list << coilcoolingdxvariablerefrigerantflow.name.to_s
    end
	
    coilheatingdxvariablerefrigerantflows = model.getCoilHeatingDXVariableRefrigerantFlows
    coilheatingdxvariablerefrigerantflows.each do |coilheatingdxvariablerefrigerantflow|
      list << coilheatingdxvariablerefrigerantflow.name.to_s
    end
    coilheatinggass = model.getCoilHeatingGass
    coilheatinggass.each do |coilheatinggas|
      list << coilheatinggas.name.to_s
    end
    coilheatingelectrics = model.getCoilHeatingElectrics
    coilheatingelectrics.each do |coilheatingelectric|
      list << coilheatingelectric.name.to_s
    end
	
    coil_choice = OpenStudio::Ruleset::OSArgument.makeChoiceArgument('coil_choice', list, true)
    coil_choice.setDisplayName("Enter the name of the oversized coil object. If you want to impose the fault on all equipment, select #{$all_coil_selection}")
    coil_choice.setDefaultValue("#{$all_coil_selection}")
    args << coil_choice
	
    sizing_increase_percent = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("sizing_increase_percent",true)
    sizing_increase_percent.setDisplayName("Sizing Increase (between 0-50%).")
    sizing_increase_percent.setDefaultValue(10.0)
    args << sizing_increase_percent	
    
    return args
  end
  
## Initial Condition

    runner.registerInitialCondition('Oversized Equipment at Design fault are being applied on all coils......')
    runner.registerInitialCondition("Oversized Equipment at Design fault is being applied to the #{coil_choice}......")

## Final Condition

    runner.registerFinalCondition('Oversized Equipment at Design fault applied on all coils......')
    runner.registerFinalCondition("Oversized Equipment at Design fault applied to the #{coil_choice}......")
	
## Not Applicable

    runner.registerAsNotApplicable("Fault intensity #{sizing_increase_percent} is defined too small. Skipping......")

## Warning

n/a

## Error

    runner.registerError("Fault intensity #{sizing_increase_percent} is defined outside the range from 0 to 50%. Exiting......")

## Information

•	Modifies sizing:parameter and capacity field in coil objects based on fault intensity. 
•	Works with, 
•	Coil:Cooling:Dx:SingleSpeed
•	Coil:Cooling:Dx:TwoSpeed
•	Coil:Cooling:Dx:TwoStageWithHumidityControlMode
•	Coil:Cooling:Dx:VariableRefrigerantFlow
•	Coil:Heating:Dx:VariableRefrigerantFlow
•	Coil;Heating:Gas
•	Coil;Heating:Electric
Code Outline
•	Define arguments (coil where fault occurs, percentage of increased sizing parameter).
•	Check whether fault intensity (percentage of increased sizing parameter) is reasonably defined within 0-50%.
•	Modify capacity based on the fault intensity.
•	If all coils are selected, 
•	Modify sizing parameter based on fault intensity
•	Heating sizing parameter
•	Cooling sizing parameter
•	Read component names that are defined in the model and modify capacity field in the selected coils that has the same name.
•	Coilcoolingdxsinglespeed
•	Coilcoolingdxvariablerefrigerantflow
•	Coilcoolingdxtwostagewithhumiditycontrolmode
•	Coilcoolingdxtwospeed
•	Coilheatingdxvariablerefrigerantflow
•	Coilheatinggas
•	Coilheatingelectric
•	And if one coil object is selected,
•	Modify capacity field in the selected coil that has the same name.
•	Coilcoolingdxsinglespeed
•	Coilcoolingdxvariablerefrigerantflow
•	Coilcoolingdxtwostagewithhumiditycontrolmode
•	Coilcoolingdxtwospeed
•	Coilheatingdxvariablerefrigerantflow
•	Coilheatinggas
•	Coilheatingelectric

## Tests

●	Test invalid user argument values to make sure measure fails gracefully
●	Test different coil types.
