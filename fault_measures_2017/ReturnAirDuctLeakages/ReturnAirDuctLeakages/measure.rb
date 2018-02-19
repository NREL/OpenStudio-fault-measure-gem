#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require "#{File.dirname(__FILE__)}/resources/ControllerOutdoorAirFlow_DuctLeakage"

$allchoices = '* ALL Controller:OutdoorAir *'

# start the measure
class ReturnAirDuctLeakages < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return 'Return Air Duct Leakages'
  end

  # human readable description
  def description
    return "The return duct of an air system typically operates at negative pressure, thus the leakage in the return duct (outside of conditioned space) results in increased heating and cooling load due to unconditioned air being drawn into the return duct and mixing with return air from conditioned spaces. This measure simulates the return air leakage by modifying the Controller:OutdoorAir object in EnergyPlus."
  end

  # human readable description of workspace approach
  def modeler_description
    return "Two user inputs (outdoor air controller affected by the leakage of unconditioned air from the ambient, unconditioned air introduced to return air stream at full load condition as a ratio of the total airflow rate, F) are required to simulate the fault and, based on these inputs, this fault model simulates the return air duct leakage by introducing additional outdoor air (based on the leakage ratio) through the economizer object. Equation (2) shows the calculation of outdoor airflow rate in the economizer (qdot_(oa,F)) at a faulted condition where qdot_oa is the outdoor airflow rate for ventilation, qdot_(ra,tot) is the return airflow rate, and F is the fault intensity. qdot_(oa,F) = qdot_oa + qdot_(ra,tot)∙F. The second term represents the outdoor airflow rate introduced to the duct due to leakage. The fault intensity (F) for this fault is defined as the unconditioned air introduced to return air stream at full load condition as a ratio of the total return airflow rate."
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    ##################################################
    #make choice arguments for economizers
    controlleroutdoorairs = workspace.getObjectsByType("Controller:OutdoorAir".to_IddObjectType)
    chs = OpenStudio::StringVector.new
    controlleroutdoorairs.each do |controlleroutdoorair|
      chs << controlleroutdoorair.name.to_s
    end
    econ_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('econ_choice', chs, true)
    econ_choice.setDisplayName("Outdoor air controller affected by the leakage of unconditioned air from the ambient")
    econ_choice.setDefaultValue(chs[0].to_s)
    args << econ_choice
    ##################################################
	
    #make a double argument for the return duct leakage
    leak_ratio = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('leak_ratio', false)
    leak_ratio.setDisplayName('Enter the unconditioned air introduced to return air stream at full load condition as a ratio of the total return airflow rate.')
    leak_ratio.setDefaultValue(0.1)  #default fault level to be 10%
    args << leak_ratio

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
    leak_ratio = runner.getDoubleArgumentValue('leak_ratio',user_arguments)
    if leak_ratio == 0
      runner.registerAsNotApplicable("#{name} is not running with zero fault level. Skipping......")
      return true
    end
    
    runner.registerInitialCondition("Imposing Return Duct Leakage on #{econ_choice}.")
  
    #find the RTU to change
    no_econ_found = true
    applicable = true
    controlleroutdoorairs = workspace.getObjectsByType('Controller:OutdoorAir'.to_IddObjectType)
    controlleroutdoorairs.each do |controlleroutdoorair|
      if controlleroutdoorair.getString(0).to_s.eql?(econ_choice) || econ_choice.eql?($allchoices)
        no_econ_found = false
        
        #check applicability of the model        
        if controlleroutdoorair.getString(8).to_s.eql?('MinimumFlowWithBypass')
          runner.registerAsNotApplicable("MinimumFlowWithBypass in #{econ_choice} is not supported. Skipping......")
          applicable = false
        elsif controlleroutdoorair.getString(14).to_s.eql?('LockoutWithHeating') or controlleroutdoorair.getString(14).to_s.eql?("LockoutWithCompressor")
          runner.registerAsNotApplicable(controlleroutdoorair.getString(14).to_s+" in #{econ_choice} is not supported. Skipping......")
          applicable = false
        elsif controlleroutdoorair.getString(25).to_s.eql?('BypassWhenOAFlowGreaterThanMinimum')
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
                    
          main_body = econ_ductleakage_ems_main_body(workspace, controlleroutdoorair, leak_ratio)
          
          string_objects << main_body
          
          #append other objects
          strings_objects = econ_ductleakage_ems_other(string_objects, workspace, controlleroutdoorair)
          
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
      runner.registerFinalCondition("Imposed Return Duct Leakage on #{econ_choice}.")
    else
      runner.registerAsNotApplicable("#{name} is not running for #{econ_choice} because of inapplicability. Skipping......")
    end

    return true

  end
  
end

# register the measure to be used by the application
ReturnAirDuctLeakages.new.registerWithApplication
