#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require 'date'
# require "#{File.dirname(__FILE__)}/resources/timestepfaultstate"

#start the measure
class ReheatSensorBiasOS < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Reheat sensor bias"
  end
  
  def description
    return "Impose a sensor bias at the reheat temperature sensor of an air terminal (VAV box or constant volume diffuser)"
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make choice arguments for airterminals with reheat
    chs = OpenStudio::StringVector.new
    default_string = ""
    first_loop = false
    types = ["AirTerminalSingleDuctVAVReheat", "AirTerminalSingleDuctConstantVolumeReheat", "AirTerminalSingleDuctVAVHeatAndCoolReheat"]
    types.each do |type|
      airterminals = model.getAirTerminalSingleDuctVAVReheats
      if type.eql?("AirTerminalSingleDuctConstantVolumeReheat")
        airterminals = model.getAirTerminalSingleDuctConstantVolumeReheats
      elsif type.eql?("AirTerminalSingleDuctVAVHeatAndCoolReheat")
        airterminals = model.getAirTerminalSingleDuctVAVHeatAndCoolReheats
      end
      if not airterminals.eql?(NilClass)
        airterminals.each do |airterminal|
          chs << airterminal.name.to_s
          if not first_loop
            default_string = airterminal.name.to_s
            first_loop = true
          end
        end
      end
    end
    airterminal_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("airterminal_choice", chs, true)
    airterminal_choice.setDisplayName("Choice of air terminals")
    if first_loop
      airterminal_choice.setDefaultValue(default_string)
    end
    args << airterminal_choice
	
    #make a double argument for the damper position
    #it should range between 0 and 1. 0 means completely closed damper
    #and 1 means fully opened damper
    bias_lvl = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("bias_lvl", false)
    bias_lvl.setDisplayName("Bias level of the reheat temperature sensor (K)")
    bias_lvl.setDefaultValue(2)  #default position to be fully closed
    args << bias_lvl
	
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
	
    #obtain values
    airterminal_choice = runner.getStringArgumentValue('airterminal_choice',user_arguments)
    bias_lvl = runner.getDoubleArgumentValue('bias_lvl',user_arguments)
    
    runner.registerInitialCondition("Imposing sensor bias #{bias_lvl}K on "+airterminal_choice+" reheat temperature sensor......")
    
    #check if the damper position is between 0 and 1
    if bias_lvl == 0.0
      runner.registerAsNotApplicable("No bias on "+airterminal_choice+". Skipping......")
      return true
    end
    
    # find the air terminal to be offset
    airterminal_model = model.getAirTerminalSingleDuctVAVReheats[0]
    found = false
    types = ["AirTerminalSingleDuctVAVReheat", "AirTerminalSingleDuctConstantVolumeReheat", "AirTerminalSingleDuctVAVHeatAndCoolReheat"]
    types.each do |type|
      airterminals = model.getAirTerminalSingleDuctVAVReheats
      if type.eql?("AirTerminalSingleDuctConstantVolumeReheat")
        airterminals = model.getAirTerminalSingleDuctConstantVolumeReheats
      elsif type.eql?("AirTerminalSingleDuctVAVHeatAndCoolReheat")
        airterminals = model.getAirTerminalSingleDuctVAVHeatAndCoolReheats
      end
      airterminals.each do |airterminal|
        if airterminal.name.to_s.eql?(airterminal_choice)
          airterminal_model = airterminal
          found = true
        end
        if found
          break
        end
      end
      if found
        break
      end
    end
    if not found
      runner.registerError("Cannot find "+airterminal_choice+"!")
      return false
    end
    
    #offset the maximum reheat air temperature
    runner.registerInfo("Imposing maximum reheat temperature #{airterminal_model.maximumReheatAirTemperature-bias_lvl}. Continue......")
    airterminal_model.setMaximumReheatAirTemperature(airterminal_model.maximumReheatAirTemperature-bias_lvl)
    
    runner.registerFinalCondition("Imposed sensor bias #{bias_lvl}K on "+airterminal_choice+" reheat temperature sensor......")
    
    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
ReheatSensorBiasOS.new.registerWithApplication
