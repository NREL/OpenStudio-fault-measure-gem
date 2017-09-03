#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

# start the measure
class EconomizerPotentialMixedTempSensorBiasFault < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "Economizer Mixed Air Temperature Sensor Bias Fault"
  end

  # human readable description
  def description
    return 'When sensors drift and are not regularly calibrated, it causes a ' \
	'bias. Sensor readings often drift from their calibration with age, ' \
	'causing equipment control algorithms to produce outputs that deviate ' \
	'from their intended function. This measure ' \
	'simulates the biased economizer sensor (mixed air temperature) ' \
	'by modifying the Controller:OutdoorAir object in EnergyPlus assigned ' \
	'to the heating and cooling system. The fault intensity (F) defined as ' \
	'the biased temperature level (K)'
  end

  # human readable description of workspace approach
  def workspaceer_description
    return 'Two user inputs are required and, based on these user inputs, ' \
	'the mixed air temperature reading in the economizer will be replaced ' \
	'by the equation below, where T_(ma,F) is the biased mixed air ' \
	'temperature reading, T_ma is the actual mixed air temperature, and F ' \
	'is the fault intensity.' \
	' T_(ma,F) = T_ma + F ' \	  
	'To use this Measure, choose the Controller:OutdoorAir object to be ' \
	'faulted. Set the level of temperature sensor bias that you want at the ' \
	'mixed air duct for the economizer during the simulation period. The ' \
	'algorithm checks if a real sensor exists in the mixed air chamber, and ' \
	'set up the bias at the sensor appropriately if it exists. For instance, ' \
	'SetpointManager:MixedAir does not model a real temperature sensor in ' \
	'the mixed air chamber, and will not be affected by this model.'
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #choose the Controller:OutdoorAir to be faulted
    econ_choice = OpenStudio::Ruleset::OSArgument::makeStringArgument("econ_choice", true)
    econ_choice.setDisplayName("Enter the name of the faulted Controller:OutdoorAir object")
    econ_choice.setDefaultValue("Controller Outdoor Air 1")  #name of economizer for the EC building
    args << econ_choice
	
    #make a double argument for the temperature sensor bias
    mix_temp_bias = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("mix_temp_bias", false)
    mix_temp_bias.setDisplayName("Enter the bias level of the mixed air temperature sensor. A positive number means that the sensor is reading a temperature higher than the true temperature. (K)")
    mix_temp_bias.setDefaultValue(2)  # default bias level at 2K
    args << mix_temp_bias

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
    mix_temp_bias = runner.getDoubleArgumentValue('mix_temp_bias',user_arguments)
    bias_sensor = "MIX"
    
    runner.registerInitialCondition("Imposing Sensor Bias on "+econ_choice+".")
    
    str_setpoint_choice = econ_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
    if str_setpoint_choice.eql?(nil)
      str_setpoint_choice = setpoint_choice
    end
  
    #find the RTU to change
    no_econ_found = true
    applicable = true
    controlleroutdoorairs = workspace.getObjectsByType("Controller:OutdoorAir".to_IddObjectType)
    controlleroutdoorairs.each do |controlleroutdoorair|
      if controlleroutdoorair.getString(0).to_s.eql?(econ_choice)
        no_econ_found = false
        
        if applicable  #skip the modeling procedure if the model is not supported
          #create an empty string_objects to be appended into the .idf file
          string_objects = []
          
          #get the node name of the mixed air chamber
          mixnodename = controlleroutdoorair.getString(3).to_s
          
          #check the type of SetpointManager object used at the mixed air chamber
          manager_types = ["SetpointManager:Scheduled", "SetpointManager:Scheduled:DualSetpoint", "SetpointManager:OutdoorAirReset", "SetpointManager:SingleZone:Reheat", "SetpointManager:SingleZone:Heating", "SetpointManager:SingleZone:Cooling", "SetpointManager:SingleZone:Humidity:Minimum", "SetpointManager:SingleZone:Humidity:Maximum", "SetpointManager:Warmest", "SetpointManager:Coldest", "SetpointManager:WarmestTemperatureFlow", "SetpointManager:MultiZone:Cooling:Average", "SetpointManager:MultiZone:Heating:Average", "SetpointManager:FollowOutdoorAirTemperature", "SetpointManager:FollowSystemNodeTemperature", "SetpointManager:FollowGroundTemperature", "SetpointManager:CondenserEnteringReset", "SetpointManager:CondenserEnteringReset:Ideal", "SetpointManager:MixedAir", "SetpointManager:OutdoorAirPretreat", "SetpointManager:SingleZone:OneStageCooling", "SetpointManager:SingleZone:OneStageHeating"]
          manager_types.each do |manager_type|
            managers = workspace.getObjectsByType(manager_type.to_IddObjectType)
            mixnodeloc = -1
            # only check manager types that are related to temperature
            if manager_type.eql?("SetpointManager:Scheduled")
              mixnodeloc = 3
            elsif manager_type.eql?("SetpointManager:Scheduled:DualSetpoint") or manager_type.eql?("SetpointManager:MultiZone:Cooling:Average") or manager_type.eql?("SetpointManager:MultiZone:Heating:Average") or manager_type.eql?("SetpointManager:SingleZone:OneStageCooling") or manager_type.eql?("SetpointManager:SingleZone:OneStageHeating)")
              mixnodeloc = 4
            elsif manager_type.eql?("SetpointManager:MixedAir")
              mixnodeloc = 5
            elsif manager_type.eql?("SetpointManager:OutdoorAirReset") or manager_type.eql?("SetpointManager:Warmest") or manager_type.eql?("SetpointManager:Coldest") or manager_type.eql?("SetpointManager:WarmestTemperatureFlow") or manager_type.eql?("SetpointManager:FollowOutdoorAirTemperature") or manager_type.eql?("SetpointManager:FollowGroundTemperature")
              mixnodeloc = 6
            elsif manager_type.eql?("SetpointManager:SingleZone:Reheat") or manager_type.eql?("SetpointManager:SingleZone:Heating") or manager_type.eql?("SetpointManager:SingleZone:Cooling") or manager_type.eql?("SetpointManager:FollowSystemNodeTemperature")
              mixnodeloc = 7
            elsif manager_type.eql?("SetpointManager:OutdoorAirPretreat")
              mixnodeloc = 10
            end
            if mixnodeloc > -1
              managers.each do |manager|
                if manager.getString(mixnodeloc).to_s.eql?(mixnodename)
                  
                  #identify the name of the node that the sensor locates
                  node_name = mixnodename
                  
                  #check all nodelist
                  nodelists = workspace.getObjectsByType("NodeList".to_IddObjectType)
                  nodelists.each do |nodelist|
                    if nodelist.getString(0).to_s.eql?(node_name)
                      runner.registerError("Nodelist is found instead of node. Exiting......")
                      return false
                    end
                  end
                  
                  # for some setpoint managers, change the maximum and minimum temperature if their physical sensor does not provide a fixed setpoint
                  if manager_type.eql?("SetpointManager:OutdoorAirReset")
                    (2..5).each do |ind|
                      manager.setDouble(ind, manager.getDouble(ind).to_f-mix_temp_bias)
                    end
                    if !manager.getString(7).to_s.eql?("")
                      (8..11).each do |ind|
                        manager.setDouble(ind, manager.getDouble(ind).to_f-mix_temp_bias)
                      end
                    end
                  elsif manager_type.eql?("SetpointManager:SingleZone:Reheat") or manager_type.eql?("SetpointManager:SingleZone:Heating") or manager_type.eql?("SetpointManager:SingleZone:Cooling") or manager_type.eql?("SetpointManager:OutdoorAirPretreat") or manager_type.eql?("SetpointManager:MultiZone:Cooling:Average") or manager_type.eql?("SetpointManager:MultiZone:Heating:Average")
                    (2..3).each do |ind|
                      manager.setDouble(ind, manager.getDouble(ind).to_f-mix_temp_bias)
                    end
                  elsif manager_type.eql?("SetpointManager:Warmest") or manager_type.eql?("SetpointManager:Coldest") or manager_type.eql?("SetpointManager:WarmestTemperatureFlow")
                    (3..4).each do |ind|
                      manager.setDouble(ind, manager.getDouble(ind).to_f-mix_temp_bias)
                    end
                  elsif manager_type.eql?("SetpointManager:FollowOutdoorAirTemperature") or manager_type.eql?("SetpointManager:FollowGroundTemperature")
                    (3..5).each do |ind|
                      manager.setDouble(ind, manager.getDouble(ind).to_f-mix_temp_bias)
                    end
                  elsif manager_type.eql?("SetpointManager:FollowSystemNodeTemperature")
                    (4..6).each do |ind|
                      manager.setDouble(ind, manager.getDouble(ind).to_f-mix_temp_bias)
                    end
                  elsif manager_type.eql?("SetpointManager:SingleZone:OneStageCooling") or manager_type.eql?("SetpointManager:SingleZoneOneStageHeating")
                    (1..2).each do |ind|
                      manager.setDouble(ind, manager.getDouble(ind).to_f-mix_temp_bias)
                    end
                  # for some setpoint managers, add ems code to shift the setpoint upon calculation
                  # write ems to offset the setpoints
                  elsif manager_type.eql?("SetpointManager:Scheduled") or manager_type.eql?("SetpointManager:Scheduled:DualSetpoint") or manager_type.eql?("SetpointManager:ReturnAirBypassFlow")
                    # only continue if the schedule is a schedule of temperature
                    if manager_type.eql?("SetpointManager:ReturnAirBypassFlow") or manager.getString(1).to_s.include?("Temperature")
                  
                      string_objects = []
                      id = "tmp"
                      ctrl_var = "Temperature"
                      
                      setpt_offset_str = ""
                      if mix_temp_bias > 0
                        setpt_offset_str = "-#{mix_temp_bias}"
                      else
                        setpt_offset_str = "+#{-mix_temp_bias}"
                      end
                      
                      string_objects << "
                        EnergyManagementSystem:Program,
                          Bias"+str_setpoint_choice+id+", !- Name
                          SET "+str_setpoint_choice+id+"PT = OLD"+str_setpoint_choice+id+"PT"+setpt_offset_str+"; !- Program Line 1
                      "
                      
                      string_objects << "
                        EnergyManagementSystem:ProgramCallingManager,
                          EMSCallBias"+str_setpoint_choice+id+", !- Name
                          AfterPredictorAfterHVACManagers, !- EnergyPlus Model Calling Point
                          Bias"+str_setpoint_choice+id+"; !- Program Name 1                
                      "
              
                      string_objects << "
                        EnergyManagementSystem:Actuator,
                          "+str_setpoint_choice+id+"PT,          !- Name
                          "+node_name+",           !- Actuated Component Unique Name
                          System Node Setpoint,                   !- Actuated Component Type
                          "+ctrl_var+" Setpoint;            !- Actuated Component Control Type
                      "
                      
                      string_objects << "
                        EnergyManagementSystem:Sensor,
                          OLD"+str_setpoint_choice+id+"PT,                     !- Name
                          "+node_name+",       !- Output:Variable or Output:Meter Index Key Name
                          System Node Setpoint "+ctrl_var+"; !- Output:Variable or Output:Meter Name
                      "
                
                      # only add Output:EnergyManagementSystem if it does not exist in the code
                      outputemss = workspace.getObjectsByType("Output:EnergyManagementSystem".to_IddObjectType)
                      if outputemss.size == 0
                        string_objects << "
                          Output:EnergyManagementSystem,
                            Verbose,                 !- Actuator Availability Dictionary Reporting
                            Verbose,                 !- Internal Variable Availability Dictionary Reporting
                            ErrorsOnly;                 !- EMS Runtime Language Debug Output Level
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
                end
              end
            end
          end
        end
      end
    end
    
    #give an error for the name if no RTU is changed
    if no_econ_found
      runner.registerError("Measure EconomizerPotentialMixedTempSensorBiasFault cannot find "+econ_choice+". Exiting......")
      return false
    elsif applicable
      # report final condition of workspace
      runner.registerFinalCondition("Imposed Sensor Bias on "+econ_choice+".")
    else
      runner.registerAsNotApplicable("EconomizerPotentialMixedTempSensorBiasFault is not running for "+econ_choice+" because of inapplicability. Skipping......")
    end

    return true

  end
  
end

# register the measure to be used by the application
EconomizerPotentialMixedTempSensorBiasFault.new.registerWithApplication
