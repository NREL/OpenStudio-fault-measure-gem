#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

# start the measure
class ReturnAirDuctLeakages < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "Return Air Duct Leakages"
  end

  # human readable description
  def description
    return "The return duct of an air system typically operates at negative pressure, thus the leakage in the return duct (outside of conditioned space) results in increased heating and cooling load due to unconditioned air being drawn into the return duct and mixing with return air from conditioned spaces. This measure simulates the return air leakage by modifying the Controller:OutdoorAir object in EnergyPlus."
  end

  # human readable description of workspace approach
  def modeler_description
    return "Two user inputs (economizer included in the air terminal unit where the fault occurs, unconditioned air introduced to return air stream at full load condition as a ratio of the total airflow rate, F) are required to simulate the fault and, based on these inputs, this fault model simulates the return air duct leakage by introducing additional outdoor air (based on the leakage ratio) through the economizer object. Equation (2) shows the calculation of outdoor airflow rate in the economizer (qdot_(oa,F)) at a faulted condition where qdot_oa is the outdoor airflow rate for ventilation, qdot_(ra,tot) is the return airflow rate, and F is the fault intensity. qdot_(oa,F) = qdot_oa + qdot_(ra,tot)∙F. The second term represents the outdoor airflow rate introduced to the duct due to leakage. The fault intensity (F) for this fault is defined as the unconditioned air introduced to return air stream at full load condition as a ratio of the total return airflow rate."
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #choose the Controller:OutdoorAir to be faulted
    econ_choice = OpenStudio::Ruleset::OSArgument::makeStringArgument("econ_choice", true)
    econ_choice.setDisplayName("Enter the name of the faulted Controller:OutdoorAir object included in the air terminal unit where the fault occurs")
    # econ_choice.setDefaultValue("asintakef4058507-81d6-4711-96a3-ca67f519872c controller")  #name of economizer for the EC building
    econ_choice.setDefaultValue("")  #name of economizer for the EC building
    args << econ_choice
	
	# make a double argument for the leakage ratio
    leak_ratio = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('leak_ratio', false)
    leak_ratio.setDisplayName('Ratio of leak airflow between 0 and 0.3.')
    leak_ratio.setDefaultValue(0.1)  # default leakage level to be 10%
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
    
    if leak_ratio !=0 # only continue if the user is running the module and the readings are sensible
    
      runner.registerInitialCondition("Imposing ReturnAirDuctLeakages on "+econ_choice+".")
    
      #find the economizer to change
      no_econ_found = true
      controlleroutdoorairs = workspace.getObjectsByType("Controller:OutdoorAir".to_IddObjectType)
      controlleroutdoorairs.each do |controlleroutdoorair|
        if controlleroutdoorair.getString(0).to_s.eql?(econ_choice)
          no_econ_found = false
	  mixedairnote_name = controlleroutdoorair.getString(3).to_s
          
          #create an empty string_objects to be appended into the .idf file
          string_objects = []
          
          #append FaultModel objects to the idf file
          
          #outdoor air sensor temperature bias
          if leak_ratio != 0
			
	  string_objects << "
            EnergyManagementSystem:Sensor,
              SA_FlowRate,                !- Name
              #{mixedairnote_name},       !- Output:Variable or Output:Meter Index Key Name
              System Node Mass Flow Rate;    !- Output:Variable or Output:Meter Name
          "
			
	  string_objects << "
            EnergyManagementSystem:InternalVariable,
              OA_Min,
              #{econ_choice},
	      Outdoor Air Controller Minimum Mass Flow Rate;
          "
			
	  string_objects << "
            EnergyManagementSystem:Program,
              OA_FlowRate_Recalculation, !- Name
              SET OA_FlowRate_Ctrl = OA_Min + SA_FlowRate*#{leak_ratio}, !- Program Line 1
          "
			
	  string_objects << "
            EnergyManagementSystem:ProgramCallingManager,
              OA_FlowRate_Modification, !- Name
              AfterPredictorBeforeHVACManagers, !- EnergyPlus Model Calling Point, only works when the SHR is autosized
              OA_FlowRate_Recalculation; !- Program Name 1
          "
			
	  string_objects << "
            EnergyManagementSystem:Actuator,
              OA_FlowRate_Ctrl, !- Name
              #{econ_choice}, !- Component Name
              Outdoor Air Controller, !- Actuated Component Type
              Air Mass Flow Rate; !- Actuated Component Control Type
          "
	
          end
          
          #add all of the strings to workspace to create IDF objects
          string_objects.each do |string_object|
            idfObject = OpenStudio::IdfObject::load(string_object)
            object = idfObject.get
            wsObject = workspace.addObject(object)
          end
            
        end
      end
      
      #give an error for the name if no RTU is changed
      if no_econ_found
        runner.registerError("Measure ReturnAirDuctLeakages cannot find "+econ_choice+". Exiting......")
        return false
      end

      # report final condition of workspace
      runner.registerFinalCondition("Imposed ReturnAirDuctLeakages on "+econ_choice+".")
    else
      runner.registerAsNotApplicable("ReturnAirDuctLeakages is not running for "+econ_choice+". Skipping......")
    end

    return true

  end
  
end

# register the measure to be used by the application
ReturnAirDuctLeakages.new.registerWithApplication
