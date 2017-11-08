#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require "#{File.dirname(__FILE__)}/resources/ControllerOutdoorAirFlow"

$allchoices = '* ALL Controller:OutdoorAir *'

# start the measure
class EconomizerOutdoorRHSensorBiasFault < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return 'Biased Economizer Sensor: Outdoor RH'
  end

  # human readable description
  def description
    return 'When sensors drift and are not regularly calibrated, it causes a ' \
	'bias. Sensor readings often drift from their calibration with age, ' \
	'causing equipment control algorithms to produce outputs that deviate ' \
	'from their intended function. A positive bias in the economizer outdoor ' \
        'relative humidity (RH) sensor leads to a higher estimate in the outdoor ' \
	'air enthalpy, which shifts the economizer switch-off point and could ' \
	'cause higher cooling or heating energy consumption. This measure ' \
	'simulates the biased economizer sensor (outdoor air RH) by modifying ' \
	'the Controller:OutdoorAir object in EnergyPlus assigned to the heating ' \
	'and cooling system. The fault intensity (F) for this fault is defined ' \
	'as the biased RH level (%)'
  end

  # human readable description of workspace approach
  def workspaceer_description
    return 'Two user inputs are required, based on these user inputs, the ' \
	'outdoor air RH reading in the economizer will be replaced by the ' \
	'equation below, where RH_(oa,F) is the biased outdoor air RH ' \
	'reading, RH_oa is the actual outdoor air RH, and F is the fault ' \
	'intensity. ' \
	'RH_oa_F = RH_oa + F ' \	  
	'To use this measure, choose the Controller:OutdoorAir object to be ' \
	'faulted. Set the level of relative humidity sensor bias between 0 to 1 ' \
	'that you want at the outdoor air duct for the economizer during the ' \
	'simulation period. For example, setting F=3 means the sensor is reading ' \
	'25% when the actual relative humidity is 22%. You can also impose a ' \
	'schedule of the presence of fault during the simulation period. If a ' \
	'schedule name is not given, the model assumes that the fault is present ' \
	'during the entire simulation period.'
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #choose the Controller:OutdoorAir to be faulted
    econ_choice = OpenStudio::Ruleset::OSArgument.makeStringArgument('econ_choice', true)
    econ_choice.setDisplayName("Enter the name of the faulted Controller:OutdoorAir object. To impose the fault on all economizers, enter #{$allchoices}")
    econ_choice.setDefaultValue($allchoices)  #name of economizer for the EC building
    args << econ_choice
	
    #make a double argument for the relative humidity sensor bias
    oa_rh_bias = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("oa_rh_bias", false)
    oa_rh_bias.setDisplayName("Enter the bias level of the return air relative humidity sensor. A positive number means that the sensor is reading a relative humidity higher than the true relative humidity.")
    oa_rh_bias.setDefaultValue(0)  #default fouling level to be 0%
    args << oa_rh_bias

    return args
  end

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end
    
    #obtain values
    econ_choice = runner.getStringArgumentValue('econ_choice',user_arguments)
    oa_rh_bias = runner.getDoubleArgumentValue('oa_rh_bias',user_arguments)/100 #normalize from % to dimensionless
    bias_sensor = "OA"
    if oa_rh_bias == 0
      runner.registerAsNotApplicable("#{name} is not running with zero fault level. Skipping......")
      return true
    end
    
    runner.registerInitialCondition("Imposing Sensor Bias on #{econ_choice}.")
  
    #find the RTU to change
    no_econ_found = true
    applicable = true
    controlleroutdoorairs = workspace.getObjectsByType("Controller:OutdoorAir".to_IddObjectType)
    controlleroutdoorairs.each do |controlleroutdoorair|
      if controlleroutdoorair.getString(0).to_s.eql?(econ_choice) || econ_choice.eql?($allchoices)
        no_econ_found = false
        
        #check applicability of the model        
        if controlleroutdoorair.getString(8).to_s.eql?("MinimumFlowWithBypass")
          runner.registerAsNotApplicable("MinimumFlowWithBypass in #{econ_choice} is not an economizer and is not supported. Skipping......")
          applicable = false
        elsif controlleroutdoorair.getString(14).to_s.eql?("LockoutWithHeating") or controlleroutdoorair.getString(14).to_s.eql?("LockoutWithCompressor")
          runner.registerAsNotApplicable(controlleroutdoorair.getString(14).to_s+" in #{econ_choice} is not supported. Skipping......")
          applicable = false
        elsif controlleroutdoorair.getString(25).to_s.eql?("BypassWhenOAFlowGreaterThanMinimum")
          runner.registerAsNotApplicable(controlleroutdoorair.getString(25).to_s+" in #{econ_choice} is not supported. Skipping......")
          applicable = false
        end
        
        if applicable  #skip the modeling procedure if the model is not supported
          #create an empty string_objects to be appended into the .idf file
          string_objects = []
          
          #append the main EMS program objects to the idf file
          
          #main program differs as the options at controlleroutdoorair differs
          #create a new string for the main program to start appending the required
          #EMS routine to it
                    
          main_body = econ_rh_sensor_bias_ems_main_body(workspace, bias_sensor, controlleroutdoorair, [0.0, oa_rh_bias])
          
          string_objects << main_body
          
          #append other objects
          strings_objects = econ_rh_sensor_bias_ems_other(string_objects, workspace, bias_sensor, controlleroutdoorair)
          
          #add all of the strings to workspace to create IDF objects
          string_objects.each do |string_object|
            idfObject = OpenStudio::IdfObject::load(string_object)
            object = idfObject.get
            wsObject = workspace.addObject(object)
          end
        end
          
      end
    end
    
    #give an error for the name if no RTU is changed
    if no_econ_found
      runner.registerError("Measure #{name} cannot find #{econ_choice}. Exiting......")
      return false
    elsif applicable
      # report final condition of workspace
      runner.registerFinalCondition("Imposed Sensor Bias on #{econ_choice}.")
    else
      runner.registerAsNotApplicable("#{name} is not running for #{econ_choice} because of inapplicability. Skipping......")
    end

    return true

  end
  
end

# register the measure to be used by the application
EconomizerOutdoorRHSensorBiasFault.new.registerWithApplication
