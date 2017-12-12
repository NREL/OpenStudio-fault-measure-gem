#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require "#{File.dirname(__FILE__)}/resources/TransferCurveParameters"
require "#{File.dirname(__FILE__)}/resources/ScheduleSearch"
require "#{File.dirname(__FILE__)}/resources/EnterCoefficients"
require "#{File.dirname(__FILE__)}/resources/faultcalculationcoilcoolingdx_CAF"
require "#{File.dirname(__FILE__)}/resources/FaultDefinitions"
    
#define number of parameters in the model
$q_para_num = 5
$eir_para_num = 5
$faultnow = 'CAF'
$all_coil_selection = '* ALL Coil Selected *'

# start the measure
class CondenserFanDegradation < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "Condenser Fan Degradation"
  end

  # human readable description
  def description
    return "Motor efficiency degrades when a motor suffers from a bearing or a stator winding fault. This fault causes the motor to draw higher electrical current without changing the fluid flow. Both a bearing fault and a stator winding fault can be modeled by increasing the power consumption of the condenser fan without changing the airflow of the condenser fan. This measure simulates the condenser fan degradation by modifying the Coil:Cooling:DX:SingleSpeed object in EnergyPlus assigned to the heating and cooling system. The fault intensity (F) for this fault is defined as the reduction in motor efficiency as a fraction of the non-faulted motor efficiency."
  end

  # human readable description of workspace approach
  def modeler_description
    return "Three user inputs are required and, based on these user inputs, the EIR in the DX cooling coil model is recalculated to reflect the faulted operation as shown in the equation below, where EIRF is the faulted EIR, W ̇_fan is the fan power, W ̇_cool is the DX  coil power, and F is the fault intensity. EIR_F/EIR=1+(W ̇_fan/W ̇_cool)*(F/(1-F)). This fault model also requires the ratio of condenser fan power to the power consumption of compressor and condenser fan as a user input parameter."
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #make choice arguments for Coil:Cooling:DX:SingleSpeed
    coil_choice = OpenStudio::Ruleset::OSArgument::makeStringArgument("coil_choice", true)
    coil_choice.setDisplayName("Enter the name of the faulted Coil:Cooling:DX:SingleSpeed object. If you want to impose the fault on all coils, select #{$all_coil_selection}")
    coil_choice.setDefaultValue($all_coil_selection)
    args << coil_choice
    
    #choice of schedules for the presence of fault. 0 for no fault and other numbers means fault level
    #schedule 
    sch_choice = OpenStudio::Ruleset::OSArgument::makeStringArgument("sch_choice", true)
    sch_choice.setDisplayName("Enter the name of the schedule of the fault level. If you do not have a schedule, leave this blank.")
    sch_choice.setDefaultValue("")
    args << sch_choice  #FUTURE: detect empty string later for users who provide no schedule, and delete schedule_exist
	
    #make a double argument for the fault level
    #it should range between 0 and 0.9. 0 means no degradation
    #and 0.9 means that percentage drop of COP is 90% and percentage drop of cooling load is also 90%
    fault_lvl = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("fault_lvl", false)
    fault_lvl.setDisplayName("Fan motor efficiency degradation ratio [-]")
    fault_lvl.setDefaultValue(0.5)  #default fouling level to be 50%
    args << fault_lvl
	
    #make a double argument for the fault level
    #it should range between 0 and 0.9. 0 means no degradation
    #and 0.9 means that percentage drop of COP is 90% and percentage drop of cooling load is also 90%
    fan_power_ratio = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("fan_power_ratio", false)
    fan_power_ratio.setDisplayName("Ratio of condenser fan motor power consumption to combined power consumption of condenser fan and compressor at rated condition.")
    fan_power_ratio.setDefaultValue(0.091747081)  #defaulted calcualted to be 0.0917
    args << fan_power_ratio
    
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
    coil_choice_all = runner.getStringArgumentValue('coil_choice',user_arguments)
    sch_choice = runner.getStringArgumentValue('sch_choice',user_arguments)
    fault_lvl = runner.getDoubleArgumentValue('fault_lvl',user_arguments)
    fan_power_ratio = runner.getDoubleArgumentValue('fan_power_ratio',user_arguments)
    
    #create schedule_exist
    schedule_exist = true
    if sch_choice.eql?("")
      schedule_exist = false
    end
    
    if (schedule_exist || fault_lvl != 0) # only continue if the user is running the module
    
      runner.registerInitialCondition("Imposing performance degradation on "+coil_choice_all+".")
      
      #read data for scheduletypelimits
      scheduletypelimits = workspace.getObjectsByType("ScheduleTypeLimits".to_IddObjectType)
      
      #if a user-defined schedule is used, check if the schedule exists and if the schedule has the correct schedule type limits
      if schedule_exist
        
        #check if the schedule exists
        bool_schedule, schedule_type_limit, schedule_code = schedule_search(workspace, sch_choice)
        
        if not bool_schedule
          runner.registerError("User-defined schedule "+sch_choice+" does not exist. Exiting......")
          return false
        end
        
        #check schedule type limit of the schedule, if it is not bounded between 0 and 1, reject it
        scheduletypelimits.each do |scheduletypelimit|
          if scheduletypelimit.getString(0).to_s.eql?(schedule_type_limit)
            if scheduletypelimit.getString(1).to_s.to_f < 0 || scheduletypelimit.getString(1).to_s.to_f > 1
              runner.registerError("User-defined schedule "+sch_choice+" has a ScheduleTypeLimits outside the range 0 to 1.0. Exiting......")
              return false
            end
            break
          end
        end
        
      else
      
        #if there is no user-defined schedule, check if the fouling level is positive
        if fault_lvl < 0.0 || fault_lvl > 0.99
          runner.registerError("Fault level #{fault_lvl} for "+coil_choice_all+" is oustide the range from 0 to 0.99. Exiting......")
          return false
        end
        
      end
    
      #find the DX unit to change
      no_RTU_changed = true
      existing_coils = []
	    
      ##################################################
      # find the single speed DX unit to change
      ##################################################
      coilcoolingdxsinglespeeds = workspace.getObjectsByType("Coil:Cooling:DX:SingleSpeed".to_IddObjectType)
      coilcoolingdxsinglespeeds.each do |coilcoolingdxsinglespeed|
        if coilcoolingdxsinglespeed.getString(0).to_s.eql?(coil_choice_all) | coil_choice_all.eql?($all_coil_selection)
          
          coil_choice = coilcoolingdxsinglespeed.getString(0).to_s
          no_RTU_changed = false
		
	  ##################################################
	  coiltype = 1 #Coil:Cooling:DX:SingleSpeed
	  ##################################################
    
          sh_coil_choice = coil_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
          if sh_coil_choice.eql?(nil)
            sh_coil_choice = coil_choice
          end

          #check the type of unit. Raise an error if it is not air-cooled
          if not coilcoolingdxsinglespeed.getString(20).to_s.eql?("AirCooled")
            runner.registerError(coil_choice+" is not air cooled. Impossible to impose condenser fan motor efficiency degradation. Exiting......")
            return false
          end
          
          #create an empty string_objects to be appended into the .idf file
          string_objects = []
          
          #create a faulted schedule. If schedule_exist is 1, create a schedule that the fault exists
          #all the time. Otherwise, create a schedule that the fault does not happens
          
          #check if the Fractional Schedule Type Limit exists and create it if
          #it doesn't. It's going to be used by the schedule in this script.
          print_fractional_schedule = true
          scheduletypelimitname = "Fraction"
          scheduletypelimits.each do |scheduletypelimit|
            if scheduletypelimit.getString(0).to_s.eql?(scheduletypelimitname)
              if not (scheduletypelimit.getString(1).to_s.to_f >= 0 && scheduletypelimit.getString(2).to_s.to_f <= 1 && scheduletypelimit.getString(3).to_s.eql?("Continuous"))
                #if the existing ScheduleTypeLimits does not satisfy the requirement, generate the ScheduleTypeLimits with a unique name
                scheduletypelimitname = "Fraction"+sh_coil_choice
              else
                print_fractional_schedule = false
              end
              break
            end
          end
          if print_fractional_schedule
            string_objects << "
              ScheduleTypeLimits,
                "+scheduletypelimitname+",                             !- Name
                0,                                      !- Lower Limit Value {BasedOnField A3}
                1,                                      !- Upper Limit Value {BasedOnField A3}
                Continuous;                             !- Numeric Type
            "
          end
          
          #if the schedule does not exist, create a new schedule according to fault_lvl
          if not schedule_exist
            #set a unique name for the schedule according to the component and the fault
            sch_choice = "CAFDegradactionFactor"+sh_coil_choice+"_SCH"
            
            #create a Schedule:Compact object with a schedule type limit "Fractional" that are usually 
            #created in OpenStudio for continuous schedules bounded by 0 and 1
            string_objects << "
              Schedule:Constant,
                "+sch_choice+",         !- Name
                "+scheduletypelimitname+",                       !- Schedule Type Limits Name
                #{fault_lvl};                    !- Hourly Value
            "
          end
          
          #create schedules with zero and one all the time for zero fault scenarios
          string_objects = no_fault_schedules(workspace, scheduletypelimitname, string_objects)
          
          #create energyplus management system code to alter the cooling capacity and EIR of the coil object
          
          #introduce code to modify the temperature curve for cooling capacity
          
          #obtaining the coefficients in the original EIR curve
          curve_name = coilcoolingdxsinglespeed.getString(11).to_s
          curvebiquadratics = workspace.getObjectsByType("Curve:Biquadratic".to_IddObjectType)
          curve_nameEIR, paraEIR, no_curve = para_biquadratic_limit(curvebiquadratics, curve_name)
          if no_curve
            runner.registerError("No Temperature Adjustment Curve for "+coil_choice+" EIR. Exiting......")
            return false
          end
          
          # obtain the name of an outdoor air node
          outdoor_node = ""
          outdoorairnodelists = workspace.getObjectsByType("OutdoorAir:NodeList".to_IddObjectType)
          outdoorairnodelists.each do |outdoorairnodelist|
            outdoor_node = outdoorairnodelist.getString(0).to_s  #all are the same
            break
          end
          
          #write EMS program of the new curve
          string_objects = main_program_entry(workspace, string_objects, coil_choice, curve_nameEIR, paraEIR, "EIR")
          
          #pass the minimum and maximum values of model inputs to ca_q_para and ca_eir_para tio insert them to the subroutines          
          eir_para = [fan_power_ratio]
          
          #write the EMS subroutines
	  ##################################################
          string_objects, workspace = caf_adjust_function(workspace, string_objects, coilcoolingdxsinglespeed, "EIR", eir_para, coiltype, [], 11)
	  ##################################################
          
          #write dummy subroutines for other faults, and make sure that it is not current fault
          $model_names.each do |model_name|
            $other_faults.each do |other_fault|
              if not other_fault.eql?("CAF")
		##################################################
                string_objects = dummy_fault_sub_add(workspace, string_objects, coilcoolingdxsinglespeed, other_fault, coil_choice, model_name, coiltype, [], 9)
		##################################################
              end
            end
          end
          
          #write EMS sensors for schedules of fault levels
          string_objects = fault_level_sensor_sch_insert(workspace, string_objects, "CAF", coil_choice, sch_choice)
          
          # write variable definition for EMS programs
          
          #EMS Sensors to the workspace
          
          #check if the sensors are added previously by other fault models
          pressure_sensor_name = "Pressure"+sh_coil_choice
          db_sensor_name = "CoilInletDBT"+sh_coil_choice
          humidity_sensor_name = "CoilInletW"+sh_coil_choice
          oat_sensor_name = "OAT"+sh_coil_choice
          pressure_sensor_write = true
          db_sensor_write = true
          humidity_sensor_write = true
          oat_sensor_write = true
          
          ems_sensors = workspace.getObjectsByType("EnergyManagementSystem:Sensor".to_IddObjectType)
          ems_sensors.each do |ems_sensor|
            sensor_name = ems_sensor.getString(0).to_s
            if sensor_name.eql?(pressure_sensor_name)
              pressure_sensor_write = false
            end
            if sensor_name.eql?(db_sensor_name)
              db_sensor_write = false
            end
            if sensor_name.eql?(humidity_sensor_name)
              humidity_sensor_write = false
            end
            if sensor_name.eql?(oat_sensor_name)
              oat_sensor_write = false
            end
          end
          
          if pressure_sensor_write
            string_objects << "
              EnergyManagementSystem:Sensor,
                Pressure"+sh_coil_choice+",                !- Name
                "+outdoor_node+",       !- Output:Variable or Output:Meter Index Key Name
                System Node Pressure;    !- Output:Variable or Output:Meter Name
            "
          end
          
          if db_sensor_write
            string_objects << "
              EnergyManagementSystem:Sensor,
                CoilInletDBT"+sh_coil_choice+",            !- Name
                "+coilcoolingdxsinglespeed.getString(7).to_s+",  !- Output:Variable or Output:Meter Index Key Name
                System Node Temperature; !- Output:Variable or Output:Meter Name
            "
          end
          
          if humidity_sensor_write
            string_objects << "
              EnergyManagementSystem:Sensor,
                CoilInletW"+sh_coil_choice+",              !- Name
                "+coilcoolingdxsinglespeed.getString(7).to_s+",  !- Output:Variable or Output:Meter Index Key Name
                System Node Humidity Ratio;  !- Output:Variable or Output:Meter Name
            "
          end
          
          if oat_sensor_write
            string_objects << "
              EnergyManagementSystem:Sensor,
                OAT"+sh_coil_choice+",                     !- Name
                "+outdoor_node+",       !- Output:Variable or Output:Meter Index Key Name
                System Node Temperature; !- Output:Variable or Output:Meter Name
            "
          end
          
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
        else
          existing_coils << coilcoolingdxsinglespeed.getString(0).to_s
        end
      end
      
      ##################################################
      # find the two stage DX unit to change
      ##################################################
      coilcoolingdxtwostagewithhumiditycontrolmodes = get_workspace_objects(workspace, 'Coil:Cooling:DX:TwoStageWithHumidityControlMode')
      coilcoolingdxtwostagewithhumiditycontrolmodes.each do |coilcoolingdxtwostagewithhumiditycontrolmode|
	coilperformancedxcoolings = workspace.getObjectsByType(coilcoolingdxtwostagewithhumiditycontrolmode.getString(8).to_s.to_IddObjectType)
	coilperformancedxcoolings.each do |coilperformancedxcooling|
  
          if coilcoolingdxtwostagewithhumiditycontrolmode.getString(0).to_s.eql?(coil_choice_all) | coil_choice_all.eql?($all_coil_selection)
          
            coil_choice = coilcoolingdxtwostagewithhumiditycontrolmode.getString(0).to_s
            no_RTU_changed = false
		  
	    coiltype = 2 #Coil:Cooling:DX:TwoStageWithHumidityControlMode
    
            sh_coil_choice = coil_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
            if sh_coil_choice.eql?(nil)
              sh_coil_choice = coil_choice
            end

          
            #create an empty string_objects to be appended into the .idf file
            string_objects = []
          
            #create a faulted schedule. If schedule_exist is 1, create a schedule that the fault exists
            #all the time. Otherwise, create a schedule that the fault does not happens
          
            #check if the Fractional Schedule Type Limit exists and create it if
            #it doesn't. It's going to be used by the schedule in this script.
            print_fractional_schedule = true
            scheduletypelimitname = "Fraction"
            scheduletypelimits.each do |scheduletypelimit|
              if scheduletypelimit.getString(0).to_s.eql?(scheduletypelimitname)
                if not (scheduletypelimit.getString(1).to_s.to_f >= 0 && scheduletypelimit.getString(2).to_s.to_f <= 1 && scheduletypelimit.getString(3).to_s.eql?("Continuous"))
                  #if the existing ScheduleTypeLimits does not satisfy the requirement, generate the ScheduleTypeLimits with a unique name
                  scheduletypelimitname = "Fraction"+sh_coil_choice
                else
                  print_fractional_schedule = false
                end
                break
              end
            end
            if print_fractional_schedule
              string_objects << "
                ScheduleTypeLimits,
                  "+scheduletypelimitname+",                             !- Name
                  0,                                      !- Lower Limit Value {BasedOnField A3}
                  1,                                      !- Upper Limit Value {BasedOnField A3}
                  Continuous;                             !- Numeric Type
              "
            end
          
            #if the schedule does not exist, create a new schedule according to fault_lvl
            if not schedule_exist
              #set a unique name for the schedule according to the component and the fault
              sch_choice = "CAFDegradactionFactor"+sh_coil_choice+"_SCH"
            
              #create a Schedule:Compact object with a schedule type limit "Fractional" that are usually 
              #created in OpenStudio for continuous schedules bounded by 0 and 1
              string_objects << "
                Schedule:Constant,
                  "+sch_choice+",         !- Name
                  "+scheduletypelimitname+",                       !- Schedule Type Limits Name
                  #{fault_lvl};                    !- Hourly Value
              "
            end
          
            #create schedules with zero and one all the time for zero fault scenarios
            string_objects = no_fault_schedules(workspace, scheduletypelimitname, string_objects)
          
            #create energyplus management system code to alter the cooling capacity and EIR of the coil object
          
            #introduce code to modify the temperature curve for cooling capacity
          
            #obtaining the coefficients in the original EIR curve
	    curve_str = pass_string(coilperformancedxcooling, 8)
	    curvebiquadratics = get_workspace_objects(workspace, 'Curve:Biquadratic')
            curve_nameEIR, paraEIR, no_curve = para_biquadratic_limit(curvebiquadratics, curve_str)
		  
            if no_curve
              runner.registerError("No Temperature Adjustment Curve for "+coil_choice+" EIR. Exiting......")
              return false
            end
          
            # obtain the name of an outdoor air node
            outdoor_node = ""
            outdoorairnodelists = workspace.getObjectsByType("OutdoorAir:NodeList".to_IddObjectType)
            outdoorairnodelists.each do |outdoorairnodelist|
              outdoor_node = outdoorairnodelist.getString(0).to_s  #all are the same
              break
            end
          
            #write EMS program of the new curve
            string_objects = main_program_entry(workspace, string_objects, coil_choice, curve_nameEIR, paraEIR, "EIR")
          
            #pass the minimum and maximum values of model inputs to ca_q_para and ca_eir_para tio insert them to the subroutines          
            eir_para = [fan_power_ratio]
          
            #write the EMS subroutines
            string_objects, workspace = caf_adjust_function(workspace, string_objects, coilcoolingdxtwostagewithhumiditycontrolmode, "EIR", eir_para, coiltype, coilperformancedxcooling, 8)
          
            #write dummy subroutines for other faults, and make sure that it is not current fault
            $model_names.each do |model_name|
              $other_faults.each do |other_fault|
                if not other_fault.eql?("CAF")
                  # string_objects = dummy_fault_sub_add(workspace, string_objects, other_fault, coil_choice, model_name)
		  string_objects = dummy_fault_sub_add(workspace, string_objects, coilcoolingdxtwostagewithhumiditycontrolmode, other_fault, coil_choice, model_name, coiltype, coilperformancedxcooling, 6)
                end
              end
            end
          
            #write EMS sensors for schedules of fault levels
            string_objects = fault_level_sensor_sch_insert(workspace, string_objects, "CAF", coil_choice, sch_choice)
          
            # write variable definition for EMS programs
          
            #EMS Sensors to the workspace
          
            #check if the sensors are added previously by other fault models
            pressure_sensor_name = "Pressure"+sh_coil_choice
            db_sensor_name = "CoilInletDBT"+sh_coil_choice
            humidity_sensor_name = "CoilInletW"+sh_coil_choice
            oat_sensor_name = "OAT"+sh_coil_choice
            pressure_sensor_write = true
            db_sensor_write = true
            humidity_sensor_write = true
            oat_sensor_write = true
          
            ems_sensors = workspace.getObjectsByType("EnergyManagementSystem:Sensor".to_IddObjectType)
            ems_sensors.each do |ems_sensor|
              sensor_name = ems_sensor.getString(0).to_s
              if sensor_name.eql?(pressure_sensor_name)
                pressure_sensor_write = false
              end
              if sensor_name.eql?(db_sensor_name)
                db_sensor_write = false
              end
              if sensor_name.eql?(humidity_sensor_name)
                humidity_sensor_write = false
              end
              if sensor_name.eql?(oat_sensor_name)
                 oat_sensor_write = false
              end
            end
          
            if pressure_sensor_write
              string_objects << "
                EnergyManagementSystem:Sensor,
                  Pressure"+sh_coil_choice+",                !- Name
                  "+outdoor_node+",       !- Output:Variable or Output:Meter Index Key Name
                  System Node Pressure;    !- Output:Variable or Output:Meter Name
              "
            end
          
            if db_sensor_write
              string_objects << "
                EnergyManagementSystem:Sensor,
                  CoilInletDBT"+sh_coil_choice+",            !- Name
                  "+coilcoolingdxtwostagewithhumiditycontrolmode.getString(2).to_s+",  !- Output:Variable or Output:Meter Index Key Name
                  System Node Temperature; !- Output:Variable or Output:Meter Name
              "
            end
          
            if humidity_sensor_write
              string_objects << "
                EnergyManagementSystem:Sensor,
                  CoilInletW"+sh_coil_choice+",              !- Name
                  "+coilcoolingdxtwostagewithhumiditycontrolmode.getString(2).to_s+",  !- Output:Variable or Output:Meter Index Key Name
                  System Node Humidity Ratio;  !- Output:Variable or Output:Meter Name
              "
            end
          
            if oat_sensor_write
              string_objects << "
                EnergyManagementSystem:Sensor,
                  OAT"+sh_coil_choice+",                     !- Name
                  "+outdoor_node+",       !- Output:Variable or Output:Meter Index Key Name
                  System Node Temperature; !- Output:Variable or Output:Meter Name
              "
            end
          
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
          else
            existing_coils << coilcoolingdxtwostagewithhumiditycontrolmode.getString(0).to_s
          end
        end
      end
      ##################################################
	    
      #give an error for the name if no DX unit is changed
      if no_RTU_changed
        runner.registerError("Measure CondenserFanDegradation cannot find "+coil_choice_all+". Exiting......")
        coils_msg = "Only coils "
        existing_coils.each do |existing_coil|
          coils_msg = coils_msg+existing_coil+", "
        end
        coils_msg = coils_msg+"were found."
        runner.registerError(coils_msg)
        return false
      end

      # report final condition of workspace
      runner.registerFinalCondition("Imposed performance degradation on "+coil_choice_all+".")
    else
      runner.registerAsNotApplicable("CondenserFanDegradation is not running for "+coil_choice_all+". Skipping......")
    end

    return true

  end
  
end

# register the measure to be used by the application
CondenserFanDegradation.new.registerWithApplication
