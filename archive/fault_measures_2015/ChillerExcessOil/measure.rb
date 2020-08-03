#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require "#{File.dirname(__FILE__)}/resources/TransferCurveParameters"
require "#{File.dirname(__FILE__)}/resources/ScheduleSearch"
require "#{File.dirname(__FILE__)}/resources/EnterCoefficients"
require "#{File.dirname(__FILE__)}/resources/FaultCalculationChillerElectricEIR"
require "#{File.dirname(__FILE__)}/resources/FaultDefinitions"
    
#define number of parameters in the model
$power_para_num = 5
$fault_type = "EO"

# start the measure
class ChillerExcessOil < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "Water-cooled chiller getting too much oil"
  end

  # human readable description
  def description
    return "This Measure simulates the effect of excessive oil of water-cooled chillers with shell-and-tube condensers and evaporators to the building performance."
  end

  # human readable description of workspace approach
  def modeler_description
    return "To use this Measure, choose the Chiller:Electric:EIR object to be faulted and a schedule of fault level. Define the fault level as the relative difference of the mass of oil in the chiller to the oil level recommended by the manufacturer. If the fault level is outside the range of zero and one, an error will occur."
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #make choice arguments for Coil:Cooling:DX:SingleSpeed
    chiller_choice = OpenStudio::Ruleset::OSArgument::makeStringArgument("chiller_choice", true)
    chiller_choice.setDisplayName("Enter the name of the faulted Chiller:Electric:EIR object")
    chiller_choice.setDefaultValue("")
    args << chiller_choice
    
    #choice of schedules for the presence of fault. 0 for no fault and other numbers means fault level
    #schedule 
    sch_choice = OpenStudio::Ruleset::OSArgument::makeStringArgument("sch_choice", true)
    sch_choice.setDisplayName("Enter the name of the schedule of the fault level. If you do not have a schedule, leave this blank.")
    sch_choice.setDefaultValue("")
    args << sch_choice  #FUTURE: detect empty string later for users who provide no schedule, and delete schedule_exist
	
    #make a double argument for the fault level
    fault_level = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("fault_level", false)
    fault_level.setDisplayName("Excessive oil level of the Chiller:Electric:EIR object. This model only simulates overcharged condition so the number should be between 0 and 1.")
    fault_level.setDefaultValue(0.5)  #default fouling level to be 10%
    args << fault_level
    
    #fault level limits
    max_fl = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("max_fl", true)
    max_fl.setDisplayName("Maximum value of fault level")
    max_fl.setDefaultValue(0.73)
    args << max_fl
    
    #excessive oil model
    args = enter_coefficients(args, $power_para_num, "power_fault", [-0.989165632, 0.004217863, 0.000153174, 0.465680947, -0.547522198], " for the excessive oil model")
        
    min_evap_tmp_fault = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("min_evap_tmp_fault", true)
    min_evap_tmp_fault.setDisplayName("Minimum value of evaporator water outlet temperature for the excessive oil model (C)")
    min_evap_tmp_fault.setDefaultValue(4.2)  #the first number is observed from the training data, and the second number is an adjustment for range
    args << min_evap_tmp_fault
    
    max_evap_tmp_fault = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("max_evap_tmp_fault", true)
    max_evap_tmp_fault.setDisplayName("Maximum value of evaporator water outlet temperature for the excessive oil model (C)")
    max_evap_tmp_fault.setDefaultValue(10.6)
    args << max_evap_tmp_fault
    
    min_cond_tmp_fault = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("min_cond_tmp_fault", true)
    min_cond_tmp_fault.setDisplayName("Minimum value of condenser inlet temperature for the excessive oil model (C)")
    min_cond_tmp_fault.setDefaultValue(17.2)
    args << min_cond_tmp_fault
    
    max_cond_tmp_fault = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("max_cond_tmp_fault", true)
    max_cond_tmp_fault.setDisplayName("Maximum value of condenser inlet temperature for the excessive oil model (C)")
    max_cond_tmp_fault.setDefaultValue(30.0)
    args << max_cond_tmp_fault
    
    min_cap_fault = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("min_cap_fault", true)
    min_cap_fault.setDisplayName("Minimum ratio of evaporator heat transfer rate to the reference capacity for the excessive oil model (kW)")
    min_cap_fault.setDefaultValue(0.27)
    args << min_cap_fault
    
    max_cap_fault = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("max_cap_fault", true)
    max_cap_fault.setDisplayName("Maximum value of reference capacity for the excessive oil model (kW)")
    max_cap_fault.setDefaultValue(1.0)
    args << max_cap_fault
    
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
    chiller_choice = runner.getStringArgumentValue('chiller_choice',user_arguments)
    sch_choice = runner.getStringArgumentValue('sch_choice',user_arguments)
    fault_level = runner.getDoubleArgumentValue('fault_level',user_arguments)
    max_fl = runner.getDoubleArgumentValue('max_fl',user_arguments)
    oc_power_para = runner_pass_coefficients(runner, user_arguments, $power_para_num, "power_fault")
    min_evap_tmp_fault = runner.getDoubleArgumentValue('min_evap_tmp_fault',user_arguments)
    max_evap_tmp_fault = runner.getDoubleArgumentValue('max_evap_tmp_fault',user_arguments)
    min_cond_tmp_fault = runner.getDoubleArgumentValue('min_cond_tmp_fault',user_arguments)
    max_cond_tmp_fault = runner.getDoubleArgumentValue('max_cond_tmp_fault',user_arguments)
    min_cap_fault = runner.getDoubleArgumentValue('min_cap_fault',user_arguments)
    max_cap_fault = runner.getDoubleArgumentValue('max_cap_fault',user_arguments)
    
    #create schedule_exist
    schedule_exist = true
    if sch_choice.eql?("")
      schedule_exist = false
    end
    
    sh_chiller_choice = chiller_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
    
    if (schedule_exist || fault_level != 0) # only continue if the user is running the module
    # if (schedule_exist || true) # only continue if the user is running the module
    
      runner.registerInitialCondition("Imposing performance degradation on "+chiller_choice+".")
      
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
        
      else
      
        #if there is no user-defined schedule, check if the fouling level is positive
        if fault_level < 0.0 or fault_level > 1.0
          runner.registerError("Fault level #{fault_level} for "+chiller_choice+" is outside the range of 0.0 to 1.0. Exiting......")
          return false
        end
        
      end
    
      #find the RTU to change
      no_RTU_changed = true
      existing_coils = []
      chillerelectriceirs = workspace.getObjectsByType("Chiller:Electric:EIR".to_IddObjectType)
      chillerelectriceirs.each do |chillerelectriceir|
        if chillerelectriceir.getString(0).to_s.eql?(chiller_choice)
          no_RTU_changed = false
          
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
              if not (scheduletypelimit.getString(1).to_s.to_f >= 1 && scheduletypelimit.getString(3).to_s.eql?("Continuous"))
                #if the existing ScheduleTypeLimits does not satisfy the requirement, generate the ScheduleTypeLimits with a unique name
                scheduletypelimitname = "Fraction"+sh_chiller_choice
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
                0.0,                                      !- Lower Limit Value {BasedOnField A3}
                100,                                    !- Upper Limit Value {BasedOnField A3}
                Continuous;                             !- Numeric Type
            "
          end
          
          #if the schedule does not exist, create a new schedule according to fault_level
          if not schedule_exist
            #set a unique name for the schedule according to the component and the fault
            sch_choice = "#{$fault_type}DegradactionFactor"+sh_chiller_choice+"_SCH"
            
            if $fault_type.eql?("CH")
              fault_level = fault_level-1.0
            end

            #create a Schedule:Compact object with a schedule type limit "Fractional" that are usually 
            #created in OpenStudio for continuous schedules bounded by 0 and 1
            string_objects << "
              Schedule:Constant,
                "+sch_choice+",         !- Name
                "+scheduletypelimitname+",                       !- Schedule Type Limits Name
                #{fault_level};                    !- Hourly Value
            "
          end
          
          #create schedules with zero and one all the time for zero fault scenarios
          string_objects = no_fault_schedules(workspace, scheduletypelimitname, string_objects)
          
          # schedule definition complete. Insert all of them.
          string_objects.each do |string_object|
            idfObject = OpenStudio::IdfObject::load(string_object)
            object = idfObject.get
            wsObject = workspace.addObject(object)
          end
          string_objects = []
          
          #create energyplus management system code to alter the cooling capacity and EIR of the coil object
          
          #introduce code to modify the temperature curve for cooling capacity
          
          #obtaining the coefficients in the original Q curve
          curve_name = chillerelectriceir.getString(7).to_s
          curvebiquadratics = workspace.getObjectsByType("Curve:Biquadratic".to_IddObjectType)
          curve_nameQ, paraQ, no_curve = para_biquadratic_limit(curvebiquadratics, curve_name)
          if no_curve
            runner.registerError("No Temperature Adjustment Curve for "+chiller_choice+" cooling capacity. Exiting......")
            return false
          end
          
          #obtaining the coefficients in the original EIR curve
          curve_name = chillerelectriceir.getString(8).to_s
          curvebiquadratics = workspace.getObjectsByType("Curve:Biquadratic".to_IddObjectType)
          curve_nameEIR, paraEIR, no_curve = para_biquadratic_limit(curvebiquadratics, curve_name)
          if no_curve
            runner.registerError("No Temperature Adjustment Curve for "+chiller_choice+" EIR. Exiting......")
            return false
          end          
          
          #write EMS program of the new curve
          string_objects = main_program_entry(workspace, string_objects, chiller_choice, curve_nameQ, paraQ, "q")
          string_objects = main_program_entry(workspace, string_objects, chiller_choice, curve_nameEIR, paraEIR, "eir")
          
          # original curves rewritten. Insert all of them.
          string_objects.each do |string_object|
            idfObject = OpenStudio::IdfObject::load(string_object)
            object = idfObject.get
            wsObject = workspace.addObject(object)
          end
          string_objects = []
          
          #pass the minimum and maximum values of model inputs to ca_q_para and ca_eir_para tio insert them to the programs
          power_para = []
          power_para.push(max_fl)
          power_para = power_para+oc_power_para
          power_para.push(min_evap_tmp_fault, max_evap_tmp_fault, min_cond_tmp_fault, max_cond_tmp_fault, min_cap_fault, max_cap_fault)
          
          #write the EMS programs
          string_objects, workspace = fault_adjust_function(workspace, string_objects, $fault_type, chillerelectriceir, "power", power_para)
          
          #write dummy programs for other faults, and make sure that it is not current fault
          $other_faults.each do |other_fault|
            if not other_fault.eql?($fault_type)
              string_objects = dummy_fault_prog_add(workspace, string_objects, other_fault, chiller_choice, "power")
            end
          end
          
          #write EMS sensors for schedules of fault levels
          string_objects = fault_level_sensor_sch_insert(workspace, string_objects, $fault_type, chiller_choice, sch_choice)
          
          #write an EMS program to multiply all multipliers from all faults
          no_add = false
          programs = workspace.getObjectsByType("EnergyManagementSystem:Program".to_IddObjectType)
          programs.each do |program|
            if program.getString(0).to_s.eql?("FINAL_ADJUST_"+sh_chiller_choice+"_power")
              no_add = true
              break
            end
          end
          if !no_add
            final_line = "
              EnergyManagementSystem:Program,
                FINAL_ADJUST_"+sh_chiller_choice+"_power, !- Name
                SET PowerCurveResult"+sh_chiller_choice+" = #{sh_chiller_choice}eir, !- Program 1                
              "
            countmax = $other_faults.length
            count = 1
            $other_faults.each do |other_fault|
              final_line = final_line+"
                SET PowerCurveResult"+sh_chiller_choice+" = PowerCurveResult"+sh_chiller_choice+"*#{other_fault}_FAULT_ADJ_RATIO"
              if count < countmax
                final_line = final_line+", !- <none>"
              else
                final_line = final_line+"; !- <none>"
                break
              end
              count = count+1
            end
            string_objects << final_line
            string_objects << "
              EnergyManagementSystem:Actuator,
                PowerCurveResult"+sh_chiller_choice+",          !- Name
                #{chillerelectriceir.getString(8).to_s},  !- Actuated Component Unique Name
                Curve,                   !- Actuated Component Type
                Curve Result;            !- Actuated Component Control Type
            "
            string_objects << "
              EnergyManagementSystem:OutputVariable,
                PowerCurveEMSValue"+sh_chiller_choice+",           !- Name
                PowerCurveResult"+sh_chiller_choice+",          !- EMS Variable Name
                Averaged,                !- Type of Data in Variable
                ZoneTimeStep,            !- Update Frequency
                ,                        !- EMS Program or program Name
                ;                        !- Units
            "
          end
          
          ems_call_write = true
          ems_callers = workspace.getObjectsByType("EnergyManagementSystem:ProgramCallingManager".to_IddObjectType)
          ems_callers.each do |ems_caller|
            if ems_caller.getString(0).to_s.eql?("EMSCallChillerElectricEIRDegradation"+sh_chiller_choice+"power")
              ems_call_write = false
              break
            end
          end
          
          #write the main program caller
          if ems_call_write
            final_line = "
              EnergyManagementSystem:ProgramCallingManager,
                EMSCallChillerElectricEIRDegradation"+sh_chiller_choice+"power, !- Name
                AfterPredictorBeforeHVACManagers, !- EnergyPlus Model Calling Point
                ChillerElectricEIRDegradation"+sh_chiller_choice+"q, !- Program Name 1
                ChillerElectricEIRDegradation"+sh_chiller_choice+"eir, !- Program Name 2
            "
            $other_faults.each do |other_fault|
              final_line = final_line+"
                #{other_fault}_ADJUST_"+sh_chiller_choice+"_power,
              "
            end
            final_line = final_line+"
              FINAL_ADJUST_"+sh_chiller_choice+"_power;
            "
            string_objects << final_line
          end
          
          # write variable definition for EMS programs
          
          #EMS Sensors to the workspace
          
          #check if the sensors are added previously by other fault models
          cond_db_in_name = "CondInlet"+sh_chiller_choice
          evap_db_out_name = "EvapOutlet"+sh_chiller_choice
          evap_db_in_name = "EvapInlet"+sh_chiller_choice+"Tmp"
          evap_mdot_name = "Evap"+sh_chiller_choice+"Mdot"
          evap_q_name = "EvapQ"+sh_chiller_choice
          cond_db_in_write = true
          evap_db_out_write = true
          evap_db_in_write = true
          evap_mdot_write = true
          evap_q_write = true
          
          ems_sensors = workspace.getObjectsByType("EnergyManagementSystem:GlobalVariable".to_IddObjectType)
          ems_sensors.each do |ems_sensor|
            sensor_name = ems_sensor.getString(0).to_s
            if sensor_name.eql?(cond_db_in_name)
              cond_db_in_write = false
            end
            if sensor_name.eql?(evap_db_out_name)
              evap_db_out_write = false
            end
            if sensor_name.eql?(evap_db_in_name)
              evap_db_in_write = false
            end
            if sensor_name.eql?(evap_mdot_name)
              evap_mdot_write = false
            end
            if sensor_name.eql?(evap_q_name)
              evap_q_write = false
            end
          end
          
          if cond_db_in_write
            outnode_fl = chillerelectriceir.getString(16).to_s
            if outnode_fl.eql?("")  # if it is not indicated as water node, use one of the outdoor node
              outnodes = workspace.getObjectsByType("OutdoorAir:NodeList".to_IddObjectType)
              outnodes.each do |outnode|
                outnode_fl = outnode.getString(0).to_s
                break
              end
            end
            string_objects << "
              EnergyManagementSystem:Sensor,
                "+cond_db_in_name+",                !- Name
                "+outnode_fl+",       !- Output:Variable or Output:Meter Index Key Name
                System Node Temperature;    !- Output:Variable or Output:Meter Name
            "
          end
          
          if evap_db_out_write
            string_objects << "
              EnergyManagementSystem:Sensor,
                "+evap_db_out_name+",            !- Name
                "+chillerelectriceir.getString(15).to_s+",  !- Output:Variable or Output:Meter Index Key Name
                System Node Temperature; !- Output:Variable or Output:Meter Name
            "
          end
          
          if evap_db_in_write
            string_objects << "
              EnergyManagementSystem:Sensor,
                "+evap_db_in_name+",            !- Name
                "+chillerelectriceir.getString(0).to_s+",  !- Output:Variable or Output:Meter Index Key Name
                Chiller Evaporator Inlet Temperature; !- Output:Variable or Output:Meter Name
            "
          end
          
          if evap_mdot_write
            string_objects << "
              EnergyManagementSystem:Sensor,
                "+evap_mdot_name+",            !- Name
                "+chillerelectriceir.getString(15).to_s+",  !- Output:Variable or Output:Meter Index Key Name
                System Node Mass Flow Rate; !- Output:Variable or Output:Meter Name
            "
          end
          
          if evap_q_write
            plantloop_name = ""
            plantloopequiplists = workspace.getObjectsByType("PlantEquipmentList".to_IddObjectType)
            plantloopequiplists.each do |plantloopequiplist|
              equiplistfields = plantloopequiplist.numFields
              for ind in 1..(equiplistfields-1)
                if plantloopequiplist.getString(ind).to_s.eql?(chiller_choice)
                  plantloop_name = plantloopequiplist.getString(0).to_s.sub(" Cooling Equipment List", "")
                  break
                end
              end
            end
            string_objects << "
              EnergyManagementSystem:Sensor,
                "+evap_q_name+",            !- Name
                "+plantloop_name+",  !- Output:Variable or Output:Meter Index Key Name
                Plant Supply Side Cooling Demand Rate; !- Output:Variable or Output:Meter Name
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
  
          #before addition, delete any dummy subrountine with the same name in the workspace
          programs = workspace.getObjectsByType("EnergyManagementSystem:Program".to_IddObjectType)
          program_remove_bool = false
          program_remove = ""
          programs.each do |program|
            if program.getString(0).to_s.eql?("#{$fault_type}_ADJUST_"+sh_chiller_choice+"_power")
              program_remove = program
              program_remove_bool = true
              break
            end
          end
  
          string_objects.each do |string_object|
            idfObject = OpenStudio::IdfObject::load(string_object)
            object = idfObject.get
            wsObject = workspace.addObject(object)
          end

          if program_remove_bool
            program_remove.remove
          end

        else
          existing_coils << chillerelectriceir.getString(0).to_s
        end
      end
      
      #give an error for the name if no RTU is changed
      if no_RTU_changed
        runner.registerError("Measure ChillerExcessOil cannot find "+chiller_choice+". Exiting......")
        coils_msg = "Only coils "
        existing_coils.each do |existing_coil|
          coils_msg = coils_msg+existing_coil+", "
        end
        coils_msg = coils_msg+"were found."
        runner.registerError(coils_msg)
        return false
      end

      # report final condition of workspace
      runner.registerFinalCondition("Imposed performance degradation on "+chiller_choice+".")
    else
      runner.registerAsNotApplicable("ChillerExcessOil is not running for "+chiller_choice+". Skipping......")
    end

    return true

  end
  
end

# register the measure to be used by the application
ChillerExcessOil.new.registerWithApplication
