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
    return "Oversizing of heating and cooling equipment is commonly accepted in real-world applications. In a previous study (Felts and Bailey 2000), more than 40% of the units surveyed were oversized by more than 25%, and 10% were oversized by more than 50%. System oversizing can ensure that the highest heating and cooling demands are met. But excessive oversizing of units can lead to increased equipment cycling with increased energy use due to efficiency losses. The fault intensity (F) for this fault is defined as the ratio of increased sizing compared to the correct sizing."
  end
  
  # human readable description of modeling approach
  def modeler_description
    return "This measure simulates the effect of oversized equipment at design by modifying the Sizing:Parameters object in EnergyPlus assigned to the heating and cooling system. One user input is required; percentage of increased sizing"
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new
	
	####################################################################################
	####################################################################################
	# make choice arguments for Coil:Cooling:DX:SingleSpeed
    coil_choice = OpenStudio::Ruleset::OSArgument.makeStringArgument('coil_choice', true)
    coil_choice.setDisplayName("Enter the name of the oversized coil object. If you want to impose the fault on all equipment, select #{$all_coil_selection}")
    coil_choice.setDefaultValue("#{$all_coil_selection}")
    args << coil_choice
	
	#make an argument for excessive sizing
    sizing_increase_percent = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("sizing_increase_percent",true)
    sizing_increase_percent.setDisplayName("Sizing Increase (between 0-50%).")
    sizing_increase_percent.setDefaultValue(10.0)
    args << sizing_increase_percent	
	####################################################################################
	####################################################################################

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
	
	####################################################################################
	####################################################################################
	coil_choice = runner.getStringArgumentValue('coil_choice', user_arguments)
    sizing_increase_percent = runner.getDoubleArgumentValue('sizing_increase_percent', user_arguments)
	
	#Initial Condition
	if coil_choice.eql?($all_coil_selection)
      runner.registerInitialCondition('Oversized Equipment at Design fault are being applied on all coils......')
    else
      runner.registerInitialCondition("Oversized Equipment at Design fault is being applied to the #{coil_choice}......")
    end
	
	#Input check
	if sizing_increase_percent < 0.0 || sizing_increase_percent > 50.0
      runner.registerError("Fault level #{sizing_increase_percent} for #{coil_choice} is outside the range from 0 to 50%. Exiting......")
      return false
    elsif sizing_increase_percent.abs < 0.001
      runner.registerAsNotApplicable("OversizedEquipmentAtDesign is not running for #{coil_choice}. Skipping......")
      return true
    end
	
	####################################################################################
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
	####################################################################################
	def changeratedcapacity1(objects, objectname, sizing_increase_percent, runner) #Coil Cooling DX Single Speed 1
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
		    #value_before_flow = object.ratedAirFlowRate.to_f
		    value_after_cap = value_before_cap + value_before_cap*sizing_increase_percent/100
		    #value_after_flow = value_before_flow + value_before_flow*sizing_increase_percent/100
		  
		    object.setRatedTotalCoolingCapacity(value_after_cap)
		    #object.setRatedAirFlowRate(value_after_flow)
		  
		    runner.registerInfo("Capacity of coil (#{object.name.to_s}) changed from #{value_before_cap.round(2)} W to #{value_after_cap.round(2)} W (#{sizing_increase_percent.round(0)}% increase).") 
	      end
		else
	      next
	    end
	  end
    end
	
	def changeratedcapacity2(objects, objectname, sizing_increase_percent, runner) #RoofTop Cooling Coil
	  #works for
	  #CoilCoolingDXTwoStageWithHumidityControlMode (CoilPerformanceDXCooling)
	  
      objects.each do |object| 
	    if object.name.to_s == objectname
		  perf = object.normalModeStage1CoilPerformance.get.clone.to_CoilPerformanceDXCooling.get		  
		  
		  autosized = perf.isGrossRatedTotalCoolingCapacityAutosized
		  if autosized
		    runner.registerInfo("Capacity of coil (#{object.name.to_s}) is autosized, skipping..")
		  else
		    value_before_cap = perf.grossRatedTotalCoolingCapacity.to_f
		    #value_before_flow = perf.ratedAirFlowRate.to_f
		    value_after_cap = value_before_cap + value_before_cap*sizing_increase_percent/100
		    #value_after_flow = value_before_flow + value_before_flow*sizing_increase_percent/100
		  
		    perf.setGrossRatedTotalCoolingCapacity(value_after_cap)
		    #perf.setRatedAirFlowRate(value_after_flow)
		  
		    runner.registerInfo("Capacity of coil (#{object.name.to_s}) changed from #{value_before_cap.round(2)} W to #{value_after_cap.round(2)} W (#{sizing_increase_percent.round(0)}% increase).")
	      end
		else
	      next
	    end
	  end
    end
	
	def changeratedcapacity3(objects, objectname, sizing_increase_percent, runner) 
	  #works for
	  #CoilCoolingDXTwoSpeed
	  
      objects.each do |object| 
	    if object.name.to_s == objectname
		  autosized1 = object.isRatedHighSpeedTotalCoolingCapacityAutosized
		  autosized2 = object.isRatedLowSpeedTotalCoolingCapacityAutosized
		  if autosized1
		    runner.registerInfo("Capacity of coil (#{object.name.to_s}_high) is autosized, skipping..")
			
			value_before_cap2 = object.ratedLowSpeedTotalCoolingCapacity.to_f
		    value_after_cap2 = value_before_cap2 + value_before_cap2*sizing_increase_percent/100
			
			runner.registerInfo("Capacity of coil (#{object.name.to_s}) changed from #{value_before_cap2.round(2)} W to #{value_after_cap2.round(2)} W (low) (#{sizing_increase_percent.round(0)}% increase).")
		  elsif autosized2
		    runner.registerInfo("Capacity of coil (#{object.name.to_s}_low) is autosized, skipping..")
			
			value_before_cap1 = object.ratedHighSpeedTotalCoolingCapacity.to_f
		    value_after_cap1 = value_before_cap1 + value_before_cap1*sizing_increase_percent/100
			
			runner.registerInfo("Capacity of coil (#{object.name.to_s}) changed from #{value_before_cap1.round(2)} W to #{value_after_cap1.round(2)} W (high) (#{sizing_increase_percent.round(0)}% increase).")
		  else
		    value_before_cap1 = object.ratedHighSpeedTotalCoolingCapacity.to_f
		    #value_before_flow1 = object.ratedHighSpeedAirFlowRate.to_f
		    value_after_cap1 = value_before_cap1 + value_before_cap1*sizing_increase_percent/100
		    #value_after_flow1 = value_before_flow1 + value_before_flow1*sizing_increase_percent/100
		  
		    value_before_cap2 = object.ratedLowSpeedTotalCoolingCapacity.to_f
		    #value_before_flow2 = object.ratedLowSpeedAirFlowRate.to_f
		    value_after_cap2 = value_before_cap2 + value_before_cap2*sizing_increase_percent/100
		    #value_after_flow2 = value_before_flow2 + value_before_flow2*sizing_increase_percent/100
		  
		    object.setRatedHighSpeedTotalCoolingCapacity(value_after_cap1)
		    #object.setRatedHighSpeedAirFlowRate(value_after_flow1)
		    object.setRatedLowSpeedTotalCoolingCapacity(value_after_cap2)
		    #object.setRatedLowSpeedAirFlowRate(value_after_flow2)
		  
		    runner.registerInfo("Capacity of coil (#{object.name.to_s}) changed from #{value_before_cap1.round(2)} W to #{value_after_cap1.round(2)} W (high) and from #{value_before_cap2.round(2)} W to #{value_after_cap2.round(2)} W (low) (#{sizing_increase_percent.round(0)}% increase).")
	      end 
		else
	      next
	    end
	  end
    end
	
	def changeratedcapacity4(objects, objectname, sizing_increase_percent, runner)
	  #works for
	  #CoilHeatingDXVariableRefrigerantFlow
	  
      objects.each do |object| 
	    if object.name.to_s == objectname
          autosized = object.isRatedTotalHeatingCapacityAutosized
		  if autosized
		    runner.registerInfo("Capacity of coil (#{object.name.to_s}) is autosized, skipping..")
		  else
		    value_before_cap = object.ratedTotalHeatingCapacity.to_f
		    #value_before_flow = object.ratedAirFlowRate.to_f
		    value_after_cap = value_before_cap + value_before_cap*sizing_increase_percent/100
		    #value_after_flow = value_before_flow + value_before_flow*sizing_increase_percent/100
		  
		    object.setRatedTotalHeatingCapacity(value_after_cap)
		    #object.setRatedAirFlowRate(value_after_flow)
		  
		    runner.registerInfo("Capacity of coil (#{object.name.to_s}) changed from #{value_before_cap.round(2)} W to #{value_after_cap.round(2)} W (#{sizing_increase_percent.round(0)}% increase).")
	      end
		else
	      next
	    end
	  end
    end
	
	def changeratedcapacity5(objects, objectname, sizing_increase_percent, runner)
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
		    value_after_cap = value_before_cap + value_before_cap*sizing_increase_percent/100
		  
		    object.setNominalCapacity(value_after_cap)
		  
		    runner.registerInfo("Capacity of coil (#{object.name.to_s}) changed from #{value_before_cap.round(2)} W to #{value_after_cap.round(2)} W (#{sizing_increase_percent.round(0)}% increase).")
	      end
		else
	      next
	    end
	  end
    end
	####################################################################################
	if coil_choice.eql?($all_coil_selection)
      straightcomponents = model.getStraightComponents
	  straightcomponents.each do |straightcomponent|
		componentname = straightcomponent.name.to_s
		changeratedcapacity1(coilcoolingdxsinglespeeds, componentname, sizing_increase_percent, runner)
	    changeratedcapacity1(coilcoolingdxvariablerefrigerantflows, componentname, sizing_increase_percent, runner)
	    changeratedcapacity2(coilcoolingdxtwostagewithhumiditycontrolmodes, componentname, sizing_increase_percent, runner)
	    changeratedcapacity3(coilcoolingdxtwospeeds, componentname, sizing_increase_percent, runner)
	    changeratedcapacity4(coilheatingdxvariablerefrigerantflows, componentname, sizing_increase_percent, runner)
	    changeratedcapacity5(coilheatinggass, componentname, sizing_increase_percent, runner)
	    changeratedcapacity5(coilheatingelectrics, componentname, sizing_increase_percent, runner)
      end	  
    else
	  changeratedcapacity1(coilcoolingdxsinglespeeds, coil_choice, sizing_increase_percent, runner)
	  changeratedcapacity1(coilcoolingdxvariablerefrigerantflows, coil_choice, sizing_increase_percent, runner)
	  changeratedcapacity2(coilcoolingdxtwostagewithhumiditycontrolmodes, coil_choice, sizing_increase_percent, runner)
	  changeratedcapacity3(coilcoolingdxtwospeeds, coil_choice, sizing_increase_percent, runner)
	  changeratedcapacity4(coilheatingdxvariablerefrigerantflows, coil_choice, sizing_increase_percent, runner)
	  changeratedcapacity5(coilheatinggass, coil_choice, sizing_increase_percent, runner)
	  changeratedcapacity5(coilheatingelectrics, coil_choice, sizing_increase_percent, runner)
	end
	####################################################################################
	####################################################################################

	#Final Condition
	if coil_choice.eql?($all_coil_selection)
      runner.registerFinalCondition('Oversized Equipment at Design fault applied on all coils......')
    else
      runner.registerFinalCondition("Oversized Equipment at Design fault applied to the #{coil_choice}......")
    end

    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
OversizedEquipmentAtDesign.new.registerWithApplication
