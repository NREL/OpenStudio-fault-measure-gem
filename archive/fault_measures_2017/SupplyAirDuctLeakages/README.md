# Supply Air Duct Leakages

## Description

  def description
    return "Duct leakage can be caused by torn or missing external duct wrap, poor workmanship around duct takeoffs and fittings, disconnected ducts, improperly installed duct mastic, and temperature and pressure cycling. Conditioned air leaking to an unconditioned space in buildings increases the equipment heating or cooling demand and can increase fan power for variable air volume systems. This fault is categorized as a fault that occur in the ventilation system (duct) during the operation stage. This fault measure is based on a physical model where certain parameter(s) is changed in EnergyPlus to mimic the faulted operation; thus simulates supply air leakage by modifying the ZoneHVAC:AirDistributionUnit object in EnergyPlus. The fault intensity (F) is defined as the ratio of the leakage flow relative to supply flow."       
  end
  
## Modeler Description

  def workspaceer_description
    return "Two user inputs are required to simulate the fault. The ZoneHVAC:AirDistributionUnit object has two leakage options (upstream and downstream leakages) available. For supply duct leakage, the leakage ratio (leakage flow relative to supply flow) is applied to the downstream leakage parameter and the upstream leakage parameter is replaced with zero in the object. To use this Measure, choose the AirTerminal object to be faulted and a ratio of leakage flow rate to the airflow directed to the zone upstream to the leak. Equation, r_(leak,dnst,F) = 1 - ( 1 - r_(leak,dnst) ) * ( 1 - F ) provides an expression for the downstream leakage ratio (r_(leak,dnst,F)) under faulty conditions in terms of a normal leakage ratio (r_(leak,dnst)) and a fault intensity (F) defined as the ratio of the leakage flow relative to supply flow."
  end
  
## Measure Type

EnergyPlus Measure

## Taxonomy

HVAC.Ventilation

## Arguments 

  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    list = OpenStudio::StringVector.new
    atsdus = workspace.getObjectsByType("AirTerminal:SingleDuct:Uncontrolled".to_IddObjectType)
    atsdus.each do |atsdu|
      list << atsdu.name.to_s
    end
    atddcvs = workspace.getObjectsByType("AirTerminal:DualDuct:ConstantVolume".to_IddObjectType)
    atddcvs.each do |atddcv|
      list << atddcv.name.to_s
    end
    atddvavs = workspace.getObjectsByType("AirTerminal:DualDuct:VAV".to_IddObjectType)
    atddvavs.each do |atddvav|
      list << atddvav.name.to_s
    end
	atddvavoas = workspace.getObjectsByType("AirTerminal:DualDuct:VAV:OutdoorAir".to_IddObjectType)
    atddvavoas.each do |atddvavoa|
      list << atddvavoa.name.to_s
    end
	atsdcvrs = workspace.getObjectsByType("AirTerminal:SingleDuct:ConstantVolume:Reheat".to_IddObjectType)
    atsdcvrs.each do |atsdcvr|
      list << atsdcvr.name.to_s
    end
	atsdvavrs = workspace.getObjectsByType("AirTerminal:SingleDuct:VAV:Reheat".to_IddObjectType)
    atsdvavrs.each do |atsdvavr|
      list << atsdvavr.name.to_s
    end
	atsdvavnrs = workspace.getObjectsByType("AirTerminal:SingleDuct:VAV:NoReheat".to_IddObjectType)
    atsdvavnrs.each do |atsdvavnr|
      list << atsdvavnr.name.to_s
    end
	atsdspiurs = workspace.getObjectsByType("AirTerminal:SingleDuct:SeriesPIU:Reheat".to_IddObjectType)
    atsdspiurs.each do |atsdspiur|
      list << atsdspiur.name.to_s
    end
	atsdppiurs = workspace.getObjectsByType("AirTerminal:SingleDuct:ParallelPIU:Reheat".to_IddObjectType)
    atsdppiurs.each do |atsdppiur|
      list << atsdppiur.name.to_s
    end
	atsdcvfpis = workspace.getObjectsByType("AirTerminal:SingleDuct:ConstantVolume:FourPipeInduction".to_IddObjectType)
    atsdcvfpis.each do |atsdcvfpi|
      list << atsdcvfpi.name.to_s
    end
	atsdvavrvsfs = workspace.getObjectsByType("AirTerminal:SingleDuct:VAV:Reheat:VariableSpeedFan".to_IddObjectType)
    atsdvavrvsfs.each do |atsdvavrvsf|
      list << atsdvavrvsf.name.to_s
    end
	atsdvavhacrs = workspace.getObjectsByType("AirTerminal:SingleDuct:VAV:HeatAndCool:Reheat".to_IddObjectType)
    atsdvavhacrs.each do |atsdvavhacr|
      list << atsdvavhacr.name.to_s
    end
	atsdvavhacnrs = workspace.getObjectsByType("AirTerminal:SingleDuct:VAV:HeatAndCool:NoReheat".to_IddObjectType)
    atsdvavhacnrs.each do |atsdvavhacnr|
      list << atsdvavhacnr.name.to_s
    end
		
    airterminal_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("airterminal_choice", list, true)
    airterminal_choice.setDisplayName("Select the name of the faulted AirTerminal object")
    airterminal_choice.setDefaultValue(list[0].to_s)
    args << airterminal_choice

    leak_ratio = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('leak_ratio', false)
    leak_ratio.setDisplayName('Ratio of leak airflow between 0 and 0.3.')
    leak_ratio.setDefaultValue(0.1)  # default leakage level to be 10%
    args << leak_ratio

    return args
  end
  
## Initial Condition

runner.registerInitialCondition("Imposing duct leakages on #{airterminal_choice}.")

## Final Condition

    runner.registerFinalCondition("Imposed performance degradation on #{airterminal_choice}.")

## Not Applicable

    runner.registerAsNotApplicable("#{airterminal_choice} cannot leak because there are no return plenums for it to leak its airflow. Skipping......")
    runner.registerAsNotApplicable("SupplyAirDuctLeakages is not running for #{airterminal_choice}. Skipping......")

## Warning

n/a

## Error

    runner.registerError("Fault level #{leak_ratio} for #{airterminal_choice} is outside the range from 0 to 0.3. Exiting......")
    runner.registerError("Measure AirTerminalSupplyDownstreamLeakToReturn cannot find the ZoneHVAC:EquipmentList that contains #{airterminal_choice}. Exiting......")
    runner.registerError("Measure AirTerminalSupplyDownstreamLeakToReturn cannot find the AirLoopHVAC:ZoneSplitter that contains #{airterminal_choice}. Exiting......")
    runner.registerError("#{string_object} inserted unsuccessfully. Exiting......")

## Information

●	Works with,
●	ZoneHVAC:AirDistributionUnit
●	AirLoopHVAC:ReturnPlenum
●	Leakage at the downstream of zone terminal unit.
Code Outline
•	Define arguments (air terminal where fault occurs, fault level in constant value).
•	Check constant fault level value (within 0-0.3).
•	Replace object to AirTerminal:DingleDuct:ConstantVolume:Reheat if air terminal selected is AirTerminal:SingleDuct:Uncontrolled
•	Read fields from AirTerminal:SingleDuct:Uncontrolled
•	Read fields from ZoneHVAC:AirDistributionUnit if available
•	Change AirLoopHVAC:ZoneSplitter with new node name
•	Create new objects
•	AirTerminal:SingleDuct:ConstantVolume:Reheat
•	Coil:Heating:Electric
•	ZoneHVAC:AirDistributionUnit
•	Apply fault to the selected air terminal
•	Find AirLoopHVAC:ReturnPlenum connected to the selected air terminal
•	Check node connections
•	Modify Constant Downstream Leakage Fraction field based on the fault intensity defined by the user
•	Define small number for Nominal Upstream Leakage Fraction

## Tests

•	Test model with different air terminal object types
•	Test invalid user argument values to make sure measure fails gracefully



