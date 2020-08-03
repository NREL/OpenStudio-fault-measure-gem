#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

#start the measure

$all_coil_selection = '* ALL Coil Selected *'

class OversizedEquipmentAtDesign < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Oversized Equipment at Design"
  end
  
  # human readable description
  def description
    return "Oversizing of heating and cooling equipment is commonly accepted in real-world applications. In a previous study, more than 40% of the units surveyed were oversized by more than 25%, and 10% were oversized by more than 50%. System oversizing can ensure that the highest heating and cooling demands are met. But excessive oversizing of units can lead to increased equipment cycling with increased energy use due to efficiency losses. This fault is categorized as a fault that occur in the HVAC system during the design stage. This fault measure is based on a physical model where certain parameter(s) is changed in EnergyPlus to mimic the faulted operation; thus simulates oversized equipment by modifying Sizing:Parameters object in EnergyPlus. The fault intensity (F) is defined as the ratio of increased sizing compared to the correct sizing."
  end
  
  # human readable description of modeling approach
  def modeler_description
    return "This measure simulates the effect of oversized equipment at design by modifying the Sizing:Parameters object and capacity fields in coil objects in EnergyPlus assigned to the heating and cooling system. One user input is required; percentage of increased sizing. Current measure applicable to following objects; coilcoolingdxsinglespeed, coilcoolingdxtwospeed,  coilcoolingdxtwostagewithhumiditycontrolmode, coilcoolingdxvariablerefrigerantflow, coilheatingdxvariablerefrigerantflow, coilheatinggas, coilheatingelectric."
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    list = OpenStudio::StringVector.new
    list << $all_coil_selection
	
    #Cooling coils
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
    #Heating coils
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
	
    #make an argument for excessive sizing
    sizing_increase_ratio = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("sizing_increase_ratio",true)
    sizing_increase_ratio.setDisplayName("Sizing Increase Ratio (between 0-1).")
    sizing_increase_ratio.setDefaultValue(0.1)
    args << sizing_increase_ratio	
    
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    
    coil_choice = runner.getStringArgumentValue('coil_choice', user_arguments)
    sizing_increase_ratio = runner.getDoubleArgumentValue('sizing_increase_ratio', user_arguments)
	
    #Initial Condition
    if coil_choice.eql?($all_coil_selection)
      runner.registerInitialCondition('Oversized Equipment at Design fault are being applied on all coils......')
    else
      runner.registerInitialCondition("Oversized Equipment at Design fault is being applied to the #{coil_choice}......")
    end
	
    #Input check
    if sizing_increase_ratio < 0.0 || sizing_increase_ratio > 0.5
      runner.registerError("Fault intensity #{sizing_increase_ratio} is defined outside the range from 0 to 50%. Exiting......")
      return false
    elsif sizing_increase_ratio.abs < 0.001
      runner.registerAsNotApplicable("Fault intensity #{sizing_increase_ratio} is defined too small. Skipping......")
      return true
    end
	
    
    #Coil Types (limitation on type of coils of this measure)
    #Cooling coils
    coilcoolingdxsinglespeeds = model.getCoilCoolingDXSingleSpeeds
    coilcoolingdxtwospeeds = model.getCoilCoolingDXTwoSpeeds
    coilcoolingdxtwostagewithhumiditycontrolmodes = model.getCoilCoolingDXTwoStageWithHumidityControlModes
    coilcoolingdxvariablerefrigerantflows = model.getCoilCoolingDXVariableRefrigerantFlows
    #Heating coils
    coilheatingdxvariablerefrigerantflows = model.getCoilHeatingDXVariableRefrigerantFlows
    coilheatinggass = model.getCoilHeatingGass
    coilheatingelectrics = model.getCoilHeatingElectrics
	
	if coil_choice.eql?($all_coil_selection)
	  	  
      sizingparameter_h = model.getSizingParameters.heatingSizingFactor
      sizingparameter_c = model.getSizingParameters.coolingSizingFactor  
      sizingparameter_h_after = sizingparameter_h + sizingparameter_h*sizing_increase_ratio
      sizingparameter_c_after = sizingparameter_c + sizingparameter_c*sizing_increase_ratio
      model.getSizingParameters.setHeatingSizingFactor(sizingparameter_h_after)
      model.getSizingParameters.setCoolingSizingFactor(sizingparameter_c_after)
	  
      runner.registerInfo("Sizing parameter for heating changed from #{sizingparameter_h.round(2)} --> #{model.getSizingParameters.heatingSizingFactor.round(2)} and for cooling changed from #{sizingparameter_c.round(2)} --> #{model.getSizingParameters.coolingSizingFactor.round(2)}")
	  
      straightcomponents = model.getStraightComponents
      straightcomponents.each do |straightcomponent|
	    componentname = straightcomponent.name.to_s
	    changeratedcapacity1(coilcoolingdxsinglespeeds, componentname, sizing_increase_ratio, runner)
	    changeratedcapacity1(coilcoolingdxvariablerefrigerantflows, componentname, sizing_increase_ratio, runner)
	    changeratedcapacity2(coilcoolingdxtwostagewithhumiditycontrolmodes, componentname, sizing_increase_ratio, runner)
	    changeratedcapacity3(coilcoolingdxtwospeeds, componentname, sizing_increase_ratio, runner)
	    changeratedcapacity4(coilheatingdxvariablerefrigerantflows, componentname, sizing_increase_ratio, runner)
	    changeratedcapacity5(coilheatinggass, componentname, sizing_increase_ratio, runner)
	    changeratedcapacity5(coilheatingelectrics, componentname, sizing_increase_ratio, runner)
      end	  
    else
      changeratedcapacity1(coilcoolingdxsinglespeeds, coil_choice, sizing_increase_ratio, runner)
      changeratedcapacity1(coilcoolingdxvariablerefrigerantflows, coil_choice, sizing_increase_ratio, runner)
      changeratedcapacity2(coilcoolingdxtwostagewithhumiditycontrolmodes, coil_choice, sizing_increase_ratio, runner)
      changeratedcapacity3(coilcoolingdxtwospeeds, coil_choice, sizing_increase_ratio, runner)
      changeratedcapacity4(coilheatingdxvariablerefrigerantflows, coil_choice, sizing_increase_ratio, runner)
      changeratedcapacity5(coilheatinggass, coil_choice, sizing_increase_ratio, runner)
      changeratedcapacity5(coilheatingelectrics, coil_choice, sizing_increase_ratio, runner)
    end

    #Final Condition
    if coil_choice.eql?($all_coil_selection)
      runner.registerFinalCondition('Oversized Equipment at Design fault applied on all coils......')
    else
      runner.registerFinalCondition("Oversized Equipment at Design fault applied to the #{coil_choice}......")
    end

    return true

  end #end the run method

end #end the measure

def changeratedcapacity1(objects, objectname, sizing_increase_ratio, runner)
  #works for
  #CoilCoolingDXSingleSpeed
  #CoilCoolingDXVariableRefrigerantFlow
	  
  objects.each do |object| 
    if object.name.to_s == objectname
	  autosized = object.isRatedTotalCoolingCapacityAutosized
	  if autosized
	    runner.registerInfo("Capacity of coil (#{object.name.to_s}) is autosized, skipping..")
	  else
	    value_before_cap = object.ratedTotalCoolingCapacity.to_f
	    value_after_cap = value_before_cap + value_before_cap*sizing_increase_ratio
		  
	    object.setRatedTotalCoolingCapacity(value_after_cap)
	    #object.setRatedAirFlowRate(value_after_flow)
		  
	    runner.registerInfo("Capacity of coil (#{object.name.to_s}) changed from #{value_before_cap.round(2)} W to #{value_after_cap.round(2)} W (#{(sizing_increase_ratio*100).round(0)}% increase).") 
	  end
	else
	  next
	end
  end
end
	
def changeratedcapacity2(objects, objectname, sizing_increase_ratio, runner)
  #works for
  #CoilCoolingDXTwoStageWithHumidityControlMode (CoilPerformanceDXCooling)
	  
  objects.each do |object| 
    if object.name.to_s == objectname
	  if not (object.normalModeStage1CoilPerformance.empty? && object.normalModeStage1Plus2CoilPerformance.empty?)
	    perf1 = object.normalModeStage1CoilPerformance.get
        perf2 = object.normalModeStage1Plus2CoilPerformance.get
		autosized1 = perf1.isGrossRatedTotalCoolingCapacityAutosized
		autosized2 = perf2.isGrossRatedTotalCoolingCapacityAutosized
	    if autosized1
	      runner.registerInfo("Capacity of coil (#{object.name.to_s}: #{perf1.name}) is autosized, skipping..")
		elsif autosized2
		  runner.registerInfo("Capacity of coil (#{object.name.to_s}: #{perf2.name}) is autosized, skipping..")
	    else
	      value_before_cap1 = perf1.grossRatedTotalCoolingCapacity.to_f
		  value_before_cap2 = perf2.grossRatedTotalCoolingCapacity.to_f
	      value_after_cap1 = value_before_cap1 + value_before_cap1*sizing_increase_ratio
		  value_after_cap2 = value_before_cap2 + value_before_cap2*sizing_increase_ratio
	      perf1.setGrossRatedTotalCoolingCapacity(value_after_cap1)
		  perf2.setGrossRatedTotalCoolingCapacity(value_after_cap2)
	      runner.registerInfo("Capacity of coil (#{perf1.name}: #{value_before_cap1.round(2)} W --> #{value_after_cap1.round(2)} W / #{perf2.name}: #{value_before_cap2.round(2)} W --> #{value_after_cap2.round(2)} W) increased #{(sizing_increase_ratio*100).round(0)}%.")
	    end
	  else
	    next
      end		
	else
	  next
	end
  end
end
	
def changeratedcapacity3(objects, objectname, sizing_increase_ratio, runner) 
  #works for
  #CoilCoolingDXTwoSpeed
	  
  objects.each do |object| 
    if object.name.to_s == objectname
	  autosized1 = object.isRatedHighSpeedTotalCoolingCapacityAutosized
	  autosized2 = object.isRatedLowSpeedTotalCoolingCapacityAutosized
	  if autosized1
	    runner.registerInfo("Capacity of coil (#{object.name.to_s}_high) is autosized, skipping..")
			
	    value_before_cap2 = object.ratedLowSpeedTotalCoolingCapacity.to_f
	    value_after_cap2 = value_before_cap2 + value_before_cap2*sizing_increase_ratio
			
	    runner.registerInfo("Capacity of coil (#{object.name.to_s}) changed from #{value_before_cap2.round(2)} W to #{value_after_cap2.round(2)} W (low) (#{(sizing_increase_ratio*100).round(0)}% increase).")
	  elsif autosized2
	    runner.registerInfo("Capacity of coil (#{object.name.to_s}_low) is autosized, skipping..")
			
        value_before_cap1 = object.ratedHighSpeedTotalCoolingCapacity.to_f
	    value_after_cap1 = value_before_cap1 + value_before_cap1*sizing_increase_ratio
			
	    runner.registerInfo("Capacity of coil (#{object.name.to_s}) changed from #{value_before_cap1.round(2)} W to #{value_after_cap1.round(2)} W (high) (#{(sizing_increase_ratio*100).round(0)}% increase).")
	  else
	    value_before_cap1 = object.ratedHighSpeedTotalCoolingCapacity.to_f
	    value_after_cap1 = value_before_cap1 + value_before_cap1*sizing_increase_ratio
		  
	    value_before_cap2 = object.ratedLowSpeedTotalCoolingCapacity.to_f
	    value_after_cap2 = value_before_cap2 + value_before_cap2*sizing_increase_ratio
		  
	    object.setRatedHighSpeedTotalCoolingCapacity(value_after_cap1)
	    object.setRatedLowSpeedTotalCoolingCapacity(value_after_cap2)
		  
	    runner.registerInfo("Capacity of coil (#{object.name.to_s}) changed from #{value_before_cap1.round(2)} W to #{value_after_cap1.round(2)} W (high) and from #{value_before_cap2.round(2)} W to #{value_after_cap2.round(2)} W (low) (#{(sizing_increase_ratio*100).round(0)}% increase).")
	  end 
	else
	  next
	end
  end
end
	
def changeratedcapacity4(objects, objectname, sizing_increase_ratio, runner)
  #works for
  #CoilHeatingDXVariableRefrigerantFlow
	  
  objects.each do |object| 
	if object.name.to_s == objectname
      autosized = object.isRatedTotalHeatingCapacityAutosized
	  if autosized
	    runner.registerInfo("Capacity of coil (#{object.name.to_s}) is autosized, skipping..")
	  else
	    value_before_cap = object.ratedTotalHeatingCapacity.to_f
	    value_after_cap = value_before_cap + value_before_cap*sizing_increase_ratio
		  
	    object.setRatedTotalHeatingCapacity(value_after_cap)
		  
	    runner.registerInfo("Capacity of coil (#{object.name.to_s}) changed from #{value_before_cap.round(2)} W to #{value_after_cap.round(2)} W (#{(sizing_increase_ratio*100).round(0)}% increase).")
	  end
	else
	  next
	end
  end
end
	
def changeratedcapacity5(objects, objectname, sizing_increase_ratio, runner)
  #works for
  #CoilHeatingGas
  #CoilHeatingElectric
	  
  objects.each do |object| 
    if object.name.to_s == objectname
      autosized = object.isNominalCapacityAutosized
      if autosized
        runner.registerInfo("Capacity of coil (#{object.name.to_s}) is autosized, skipping..")
      else
        value_before_cap = object.nominalCapacity.to_f
        value_after_cap = value_before_cap + value_before_cap*sizing_increase_ratio
		  
        object.setNominalCapacity(value_after_cap)
	  
        runner.registerInfo("Capacity of coil (#{object.name.to_s}) changed from #{value_before_cap.round(2)} W to #{value_after_cap.round(2)} W (#{(sizing_increase_ratio*100).round(0)}% increase).")
      end
    else
      next
    end
  end
end

#this allows the measure to be use by the application
OversizedEquipmentAtDesign.new.registerWithApplication
