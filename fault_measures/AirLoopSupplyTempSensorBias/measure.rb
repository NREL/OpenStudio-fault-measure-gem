#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require "#{File.dirname(__FILE__)}/resources/ScheduleSearch"
$allloopchoices = '* All AirLoops *'

# start the measure
class AirLoopSupplyTempSensorBias < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "Air Loop Supply Temperature Sensor Bias"
  end

  # human readable description
  def description
    return "This Measure simulates the effect of a bias of the supply air temperature of an AirLoop equipment."
  end

  # human readable description of workspace approach
  def workspaceer_description
    return "To use this Measure, enter the name of the appropriate AirLoop object that has a SetpointManager object at its supply air. Then, the Measure will change the setpoint of the supply air according to the bias you enter at the other input. However, if the SetpointManager calculates its setpoint from another temperature setpoint, the setpoint at supply air is not physically compared to the supply air temperature in a real building and that setpoint will not be offset to model the bias."
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #make choice arguments for Coil:Cooling:DX:SingleSpeed
    airloophvac_choice = OpenStudio::Ruleset::OSArgument::makeStringArgument("airloophvac_choice", true)
    airloophvac_choice.setDisplayName("Enter the name of the faulted AirLoopHVAC object with a SetpointManager at its supply air. For all AirLoopHVAC objects, enter #{$allloopchoices}")
    airloophvac_choice.setDefaultValue($allloopchoices)
    args << airloophvac_choice
	
    #make a double argument for the bias level
    bias_level = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("bias_level", false)
    bias_level.setDisplayName("Enter the bias level (K).")
    bias_level.setDefaultValue(2)  #default fouling level to be 30%
    args << bias_level
    
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
    runner.registerInitialCondition("Imposing bias to supply air temperature sensors.")
    airloophvac_choice = runner.getStringArgumentValue('airloophvac_choice',user_arguments)
    if airloophvac_choice.eql?($allloopchoices)
      airloops = workspace.getObjectsByType("AirLoopHVAC".to_IddObjectType)
      airloops.each do |airloop|
        unless _imposing_bias(workspace, runner, user_arguments, airloop.getString(0).to_s)
          return false
        end
      end
    else
      return _imposing_bias(workspace, runner, user_arguments, airloophvac_choice)
    end
  end

  def _imposing_bias(workspace, runner, user_arguments, airloophvac_choice)
    ctrl_var = "Temperature"
    bias_level = runner.getDoubleArgumentValue('bias_level',user_arguments)
    
    str_setpoint_choice = airloophvac_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
    if str_setpoint_choice.eql?(nil)
      str_setpoint_choice = airloophvac_choice
    end
    
    if bias_level != 0 # only continue if the user is running the module
    
      runner.registerInfo("Imposing bias level on "+airloophvac_choice+".")
      
      #find the node at the supply air outlet of the airloophvac object
      setpoint_choice = ""
      node_name_airloophvac = ""
      findairloophvac = false
      airloophvacs = workspace.getObjectsByType("AirLoopHVAC".to_IddObjectType)
      airloophvacs.each do |airloophvac|
        if airloophvac.getString(0).to_s.eql?(airloophvac_choice)
          node_name_airloophvac = airloophvac.getString(9).to_s
          findairloophvac = true
        end
        if findairloophvac
          break
        end
      end
      if not findairloophvac
        runner.registerError("Cannot find "+airloophvac_choice+". Exiting......")
        return false        
      end
      
      #find the setpoint manager
      ctrl_var = ctrl_var.downcase.clone
      ems_added = false
      manager_types = ["SetpointManager:Scheduled", "SetpointManager:Scheduled:DualSetpoint", "SetpointManager:OutdoorAirReset", "SetpointManager:SingleZone:Reheat", "SetpointManager:SingleZone:Heating", "SetpointManager:SingleZone:Cooling", "SetpointManager:SingleZone:Humidity:Minimum", "SetpointManager:SingleZone:Humidity:Maximum", "SetpointManager:Warmest", "SetpointManager:Coldest", "SetpointManager:WarmestTemperatureFlow", "SetpointManager:MultiZone:Cooling:Average", "SetpointManager:MultiZone:Heating:Average", "SetpointManager:MultiZone:MinimumHumidity:Average", "SetpointManager:MultiZone:MaximumHumidity:Average", "SetpointManager:MultiZone:Humidity:Minimum", "SetpointManager:MultiZone:Humidity:Maximum", "SetpointManager:FollowOutdoorAirTemperature", "SetpointManager:FollowSystemNodeTemperature", "SetpointManager:FollowGroundTemperature", "SetpointManager:CondenserEnteringReset", "SetpointManager:CondenserEnteringReset:Ideal", "SetpointManager:MixedAir", "SetpointManager:OutdoorAirPretreat", "SetpointManager:SingleZone:OneStageCooling", "SetpointManager:SingleZone:OneStageHeating"]
      manager_types.each do |manager_type|
        managers = workspace.getObjectsByType(manager_type.to_IddObjectType)
        managers.each do |manager|
            
          #identify the name of the node that the sensor locates
          node_name = ""
          if manager_type.eql?("SetpointManager:Scheduled") or manager_type.eql?("SetpointManager:SingleZone:Humidity:Minimum") or manager_type.eql?("SetpointManager:SingleZone:Humidity:Maximum")
            node_name = manager.getString(3).to_s
          elsif manager_type.eql?("SetpointManager:Scheduled:DualSetpoint") or manager_type.eql?("SetpointManager:MultiZone:Heating:Average") or manager_type.eql?("SetpointManager:MultiZone:MinimumHumidity:Average") or manager_type.eql?("SetpointManager:MultiZone:MaximumHumidity:Average") or manager_type.eql?("SetpointManager:MultiZone:Humidity:Minimum") or manager_type.eql?("SetpointManager:MultiZone:Humidity:Maximum") or manager_type.eql?("SetpointManager:SingleZone:OneStageCooling") or manager_type.eql?("SetpointManager:SingleZoneOneStageHeating") or manager_type.eql?("SetpointManager:CondenserEnteringReset:Ideal")
            node_name = manager.getString(4).to_s
          elsif manager_type.eql?("SetpointManager:SingleZone:Reheat") or manager_type.eql?("SetpointManager:SingleZone:Heating") or manager_type.eql?("SetpointManager:SingleZone:Cooling") or manager_type.eql?("SetpointManager:FollowSystemNodeTemperature")
            node_name = manager.getString(7).to_s
          elsif manager_type.eql?("SetpointManager:OutdoorAirPretreat")
            node_name = manager.getString(10).to_s
          elsif manager_type.eql?("SetpointManager:Warmest") or manager_type.eql?("SetpointManager:Coldest") or manager_type.eql?("SetpointManager:WarmestTemperatureFlow") or manager_type.eql?("SetpointManager:FollowOutdoorAirTemperature") or manager_type.eql?("SetpointManager:FollowGroundTemperature") or manager_type.eql?("SetpointManager:OutdoorAirReset")
            node_name = manager.getString(6).to_s
          elsif manager_type.eql?("SetpointManager:CondenserEnteringReset")
            node_name = manager.getString(9).to_s
          elsif manager_type.eql?("SetpointManager:MixedAir")
            node_name = manager.getString(5).to_s
          end
          
          #check all nodelist
          if node_name.eql?("")
            runner.registerError("Measure AirLoopSupplyTempSensorBias cannot find matching SetpointManager for node name. Exiting...... Please check measure.rb manually.")
            return false
          end
            
          # if node_name.to_s.eql?(node_name_airloophvac)
          if true # one node may be listed under a NodeList
            ems_added = true #manager found
            setpoint_choice = manager.getString(0).to_s
            
            #check control variable
            ctrl_var_correct = false
            int_ctrl_var = manager.getString(1).to_s.downcase.clone
            if int_ctrl_var.include?("maximum")
              int_ctrl_var = int_ctrl_var.clone.gsub!("maximum", '')
            end
            if int_ctrl_var.include?("minimum")
              int_ctrl_var = int_ctrl_var.clone.gsub!("minimum", '')
            end
            if manager_type.eql?("SetpointManager:SingleZone:Humidity:Minimum") or manager_type.eql?("SetpointManager:SingleZone:Humidity:Maximum") or manager_type.eql?("SetpointManager:MultiZone:MinimumHumidity:Average") or manager_type.eql?("SetpointManager:MultiZone:MaximumHumidity:Average") or manager_type.eql?("SetpointManager:MultiZone:Humidity:Minimum") or manager_type.eql?("SetpointManager:MultiZone:Humidity:Maximum")
              if ctrl_var.eql?("humidityratio")
                ctrl_var_correct = true
              end
            elsif manager_type.eql?("SetpointManager:Scheduled:DualSetpoint") or manager_type.eql?("SetpointManager:SingleZone:Reheat") or manager_type.eql?("SetpointManager:SingleZone:Heating") or manager_type.eql?("SetpointManager:SingleZone:Cooling") or manager_type.eql?("SetpointManager:MixedAir") or manager_type.eql?("SetpointManager:Warmest") or manager_type.eql?("SetpointManager:Coldest") or manager_type.eql?("SetpointManager:WarmestTemperatureFlow") or manager_type.eql?("SetpointManager:MultiZone:Cooling:Average") or manager_type.eql?("SetpointManager:MultiZone:Heating:Average") or manager_type.eql?("SetpointManager:FollowOutdoorAirTemperature") or manager_type.eql?("SetpointManager:FollowSystemNodeTemperature") or manager_type.eql?("SetpointManager:FollowGroundTemperature") or manager_type.eql?("SetpointManager:CondenserEnteringReset") or manager_type.eql?("SetpointManager:CondenserEnteringReset:Ideal") or manager_type.eql?("SetpointManager:SingleZone:OneStageCooling") or manager_type.eql?("SetpointManager:SingleZoneOneStageHeating") or manager_type.eql?("SetpointManager:OutdoorAirReset")
              if ctrl_var.eql?("temperature")
                ctrl_var_correct = true
              end
            else
              if ctrl_var.eql?(int_ctrl_var)
                ctrl_var_correct = true
              end
            end
            if not ctrl_var_correct
              runner.registerError("Control variables do not match as "+int_ctrl_var.to_s+" and "+ctrl_var.to_s+". Exiting......")
              return false
            end
            
            nodelists = workspace.getObjectsByType("NodeList".to_IddObjectType)
            nodelists.each do |nodelist|
              if nodelist.getString(0).to_s.eql?(node_name)
                runner.registerError("Nodelist is found instead of node. Maybe the result of error......")
                # return false
              end
            end
            
            #write ems to offset the setpoints
            hum_offset = false
            string_objects = []
            id = ""
            max_str = ""
            min_str = ""
            if ctrl_var.eql?("temperature")
              id = "tmp"
              ctrl_var = "Temperature"
              max_str = "High"
              min_str = "Low"
            elsif ctrl_var.eql?("humidityratio")
              id = "hum"
              ctrl_var = "Humidity Ratio"
              max_str = "Maximum"
              min_str = "Minimum"
              hum_offset = true
            else
              runner.registerError("Original control variable setpoint cannot be read as sensor. Exiting......")
              return false
            end
            
            setpt_offset_str = ""
            if bias_level > 0
              setpt_offset_str = "-#{bias_level}"
            else
              setpt_offset_str = "+#{-bias_level}"
            end
            
            #check if the main setpoint should be offset according to the type of the setpointmanager
            setpt_offset_str_main = "+0.0"
            main_offset = false
            new_max = 1000.0 #impossible to reach
            new_min = -1000.0 #impossible to reach
            setpt_offset_str_min = setpt_offset_str
            setpt_offset_str_max = setpt_offset_str
            #it should only be offset if the setpoint is not used to infer to setpoints at other locations such as thermostat
            if manager_type.eql?("SetpointManager:Scheduled") or manager_type.eql?("SetpointManager:Scheduled:DualSetpoint") or manager_type.eql?("SetpointManager:OutdoorAirReset") or manager_type.eql?("SetpointManager:MixedAir") or manager_type.eql?("SetpointManager:OutdoorAirPretreat") or manager_type.eql?("SetpointManager:FollowOutdoorAirTemperature") or manager_type.eql?("SetpointManager:FollowSystemNodeTemperature") or manager_type.eql?("SetpointManager:FollowGroundTemperature") or manager_type.eql?("SetpointManager:CondenserEnteringReset")
              setpt_offset_str_main = setpt_offset_str
              main_offset = true
            end
            #check maximum and minimum temperature that does not has its own setpoint
            if manager_type.eql?("SetpointManager:SingleZone:Reheat") or manager_type.eql?("SetpointManager:SingleZone:Heating") or manager_type.eql?("SetpointManager:SingleZone:Cooling") or (manager_type.eql?("SetpointManager:OutdoorAirPretreat") and ctrl_var.eql?("Temperature")) or manager_type.eql?("SetpointManager:MultiZone:Cooling:Average") or manager_type.eql?("SetpointManager:MultiZone:Heating:Average")
              manager.setDouble(2, manager.getDouble(2).to_f-bias_level) # set new minimum
              manager.setDouble(3, manager.getDouble(3).to_f-bias_level)  # set new maximum
            elsif manager_type.eql?("SetpointManager:Warmest") or manager_type.eql?("SetpointManager:Coldest") or manager_type.eql?("SetpointManager:WarmestTemperatureFlow")
              manager.setDouble(3, manager.getDouble(3).to_f-bias_level) # set new minimum 
              manager.setDouble(4, manager.getDouble(4).to_f-bias_level) # set new maximum
            end
            #for some setpointmanagers, the minimum and maximum setpoints managers are inferring the setpoint to other sensors, and should not be offset as well
            if manager_type.eql?("SetpointManager:SingleZone:Humidity:Minimum") or manager_type.eql?("SetpointManager:MultiZone:MinimumHumidity:Average") or manager_type.eql?("SetpointManager:MultiZone:Humidity:Minimum") 
              setpt_offset_str_min = "+0.0"
            end
            if manager_type.eql?("SetpointManager:SingleZone:Humidity:Maximum") or manager_type.eql?("SetpointManager:MultiZone:MaximumHumidity:Average") or manager_type.eql?("SetpointManager:MultiZone:Humidity:Maximum") 
              setpt_offset_str_max = "+0.0"
            end
            
            main_prog_str = ""
            main_prog_str = "
              EnergyManagementSystem:Program,
                Bias"+str_setpoint_choice+id+", !- Name
            "
            main_prog_str = main_prog_str+"
              SET "+str_setpoint_choice+id+"PT = OLD"+str_setpoint_choice+id+"PT"+setpt_offset_str_main+", !- Program Line 1
              SET "+str_setpoint_choice+id+"MAXPT = OLD"+str_setpoint_choice+id+"MAXPT"+setpt_offset_str_min+", !- Program Line 2
              SET "+str_setpoint_choice+id+"MINPT = OLD"+str_setpoint_choice+id+"MINPT"+setpt_offset_str_max+"; !- Program Line 3
            "
            string_objects << main_prog_str
            
            string_objects << "
              EnergyManagementSystem:ProgramCallingManager,
                EMSCallBias"+str_setpoint_choice+id+", !- Name
                InsideHVACSystemIterationLoop, !- EnergyPlus Model Calling Point
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
              EnergyManagementSystem:Actuator,
                "+str_setpoint_choice+id+"MAXPT,          !- Name
                "+node_name+",           !- Actuated Component Unique Name
                System Node Setpoint,                   !- Actuated Component Type
                "+ctrl_var+" Maximum Setpoint;            !- Actuated Component Control Type
            "
    
            string_objects << "
              EnergyManagementSystem:Actuator,
                "+str_setpoint_choice+id+"MINPT,          !- Name
                "+node_name+",           !- Actuated Component Unique Name
                System Node Setpoint,                   !- Actuated Component Type
                "+ctrl_var+" Minimum Setpoint;            !- Actuated Component Control Type
            "
            
            string_objects << "
              EnergyManagementSystem:Sensor,
                OLD"+str_setpoint_choice+id+"PT,                     !- Name
                "+node_name+",       !- Output:Variable or Output:Meter Index Key Name
                System Node Setpoint "+ctrl_var+"; !- Output:Variable or Output:Meter Name
            "
            
            string_objects << "
              EnergyManagementSystem:Sensor,
                OLD"+str_setpoint_choice+id+"MAXPT,                     !- Name
                "+node_name+",       !- Output:Variable or Output:Meter Index Key Name
                System Node Setpoint "+max_str+" "+ctrl_var+"; !- Output:Variable or Output:Meter Name
            "
            
            string_objects << "
              EnergyManagementSystem:Sensor,
                OLD"+str_setpoint_choice+id+"MINPT,                     !- Name
                "+node_name+",       !- Output:Variable or Output:Meter Index Key Name
                System Node Setpoint "+min_str+" "+ctrl_var+"; !- Output:Variable or Output:Meter Name
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
        if ems_added
          break
        end
      end
      
      # error message for inapplicability
      if not ems_added
        runner.registerError("Measure AirLoopSupplyTempSensorBias is inapplicable to or cannot find "+airloophvac_choice+". Exiting......")
        return false
      end
      
      runner.registerInfo("Imposed bias on "+ctrl_var+" sensor at "+airloophvac_choice+".")
    else
      runner.registerAsNotApplicable("Zero bias on "+ctrl_var+" sensor at "+airloophvac_choice+".")
    end
    return true
  end
  
end

# register the measure to be used by the application
AirLoopSupplyTempSensorBias.new.registerWithApplication
