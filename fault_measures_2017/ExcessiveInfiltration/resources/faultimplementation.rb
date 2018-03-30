# This script contains functions that will be used in EnergyPlus measure scripts most of the time

def alter_performance(model, object, space_infiltration_increase_percent, runner, schedule_const, start_month, start_date, start_time, end_month, end_date, end_time, time_constant, time_step, short_name)

  #add ems code for dynamic fault evolution
  dynamicfaultevolution(model, runner, object, start_month, start_date, start_time, end_month, end_date, end_time, time_constant, time_step, schedule_const, short_name, space_infiltration_increase_percent)
  #edit instance based on percentage increase
  instance = object
  if not instance.designFlowRate.empty?
    #new_infiltration_design_flow_rate = instance.setDesignFlowRate(instance.designFlowRate.get + instance.designFlowRate.get*space_infiltration_increase_percent*0.01)
	new_infiltration_design_flow_rate = instance.setSchedule(schedule_const)
  elsif not instance.flowperSpaceFloorArea.empty?
    #new_infiltration_flow_floor_area = instance.setFlowperSpaceFloorArea(instance.flowperSpaceFloorArea.get + instance.flowperSpaceFloorArea.get*space_infiltration_increase_percent*0.01)
    new_infiltration_flow_floor_area = instance.setSchedule(schedule_const)
  elsif not instance.flowperExteriorSurfaceArea.empty?
    #new_infiltration_flow_ext_sarea = instance.setFlowperExteriorSurfaceArea(instance.flowperExteriorSurfaceArea.get + instance.flowperExteriorSurfaceArea.get*space_infiltration_increase_percent*0.01)
	new_infiltration_flow_ext_sarea = instance.setSchedule(schedule_const)
  elsif not instance.flowperExteriorWallArea.empty?
    #new_infiltration_flow_ext_warea = instance.setFlowperExteriorWallArea(instance.flowperExteriorWallArea.get + instance.flowperExteriorWallArea.get*space_infiltration_increase_percent*0.01)
	new_infiltration_flow_ext_warea = instance.setSchedule(schedule_const)
  elsif not instance.airChangesperHour.empty?
    #new_infiltration_ach = instance.setAirChangesperHour(instance.airChangesperHour.get + instance.airChangesperHour.get*space_infiltration_increase_percent*0.01)
	new_infiltration_ach = instance.setSchedule(schedule_const)
  else
    runner.registerWarning("'#{instance.name}' is used by one or more instances and has no load values.")
  end 
  
end  
   
	
def alter_performance_ela(object, space_infiltration_increase_percent, runner, schedule_const, start_month, start_date, start_time, end_month, end_date, end_time, time_constant, time_step, short_name)

  #add ems code for dynamic fault evolution
  dynamicfaultevolution(model, runner, object, start_month, start_date, start_time, end_month, end_date, end_time, time_constant, time_step, schedule_const, short_name, space_infiltration_increase_percent)
  
  #edit instance based on percentage increase
  instance = object
  
  if not instance.effectiveAirLeakageArea.to_s.empty?
    #new_infiltration_ela = instance.setEffectiveAirLeakageArea(instance.effectiveAirLeakageArea + instance.effectiveAirLeakageArea*space_infiltration_increase_percent*0.01)
	new_infiltration_ela = instance.setSchedule(schedule_const)
  else
    runner.registerWarning("'#{instance.name}' is used by one or more instances and has no load values.")
  end
  
end


def dynamicfaultevolution(model, runner, object, start_month, start_date, start_time, end_month, end_date, end_time, time_constant, time_step, schedule_const, short_name, space_infiltration_increase_percent)
    
    #################################################################################
	#check whether there is original schedule object used for infiltration
	#################################################################################
	sch_original = object.schedule.get
	#################################################################################
	#create EMS objects for implementing dynamic fault evolution
	#################################################################################
	#create ems objects
	ems_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    ems_gv = OpenStudio::Model::EnergyManagementSystemGlobalVariable.new(model, "AF_current_#{$faultnow}_#{short_name}")
    ems_tv = OpenStudio::Model::EnergyManagementSystemTrendVariable.new(model, "AF_current_#{$faultnow}_#{short_name}")
    ems_programcallingmanager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    ems_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(schedule_const, "Schedule:Constant", "Schedule Value")
	#################################################################################
	#define EMS:Sensor
	output_var = "Schedule Value"
    output_var_sch = OpenStudio::Model::OutputVariable.new(output_var, model)
    ems_sensor = OpenStudio::Model::EnergyManagementSystemSensor.new(model, output_var_sch)	
	ems_sensor.setName("sch_original_#{$faultnow}_#{short_name}")
	ems_sensor.setKeyName(sch_original.name.to_s)
	#################################################################################
	#define EMS:program for calculating fault level at each time step
	ems_program.setName("emsprogram_#{$faultnow}_#{short_name}")
	program_body = <<-EMS
	  SET FLPERCENTAGE = #{space_infiltration_increase_percent}
      SET SM = #{start_month},              !- Program Line 1
      SET SD = #{start_date},              !- Program Line 2
      SET ST = #{start_time},              !- A4
      SET EM = #{end_month},              !- A5
      SET ED = #{end_date},             !- A6
      SET ET = #{end_time},             !- A7
      SET tau = #{time_constant},          !- A8
      SET dt = #{time_step},           !- A9
	  IF tau == 0,
	    SET tau = 0.001,
	  ENDIF,
      SET ActualTime = (DayOfYear-1.0)*24.0 + CurrentTime,  !- A10
      IF SM == 1,              !- A11
        SET T_SM = 0,            !- A12
      ELSEIF SM == 2,          !- A13
        SET T_SM = 744,          !- A14
      ELSEIF SM == 3,          !- A15
        SET T_SM = 1416,         !- A16
      ELSEIF SM == 4,          !- A17
        SET T_SM = 2160,         !- A18
      ELSEIF SM == 5,          !- A19
        SET T_SM = 2880,         !- A20
      ELSEIF SM == 6,          !- A21
        SET T_SM = 3624,         !- A22
      ELSEIF SM == 7,          !- A23
        SET T_SM = 4344,         !- A24
      ELSEIF SM == 8,          !- A25
        SET T_SM = 5088,         !- A26
      ELSEIF SM == 9,          !- A27
        SET T_SM = 5832,         !- A28
      ELSEIF SM == 10,         !- A29
        SET T_SM = 6552,         !- A30
      ELSEIF SM == 11,         !- A31
        SET T_SM = 7296,         !- A32
      ELSEIF SM == 12,         !- A33
        SET T_SM = 8016,         !- A34
      ENDIF,                   !- A35
      IF EM == 1,              !- A36
        SET T_EM = 0,            !- A37
      ELSEIF EM == 2,          !- A38
        SET T_EM = 744,          !- A39
      ELSEIF EM == 3,          !- A40
        SET T_EM = 1416,         !- A41
      ELSEIF EM == 4,          !- A42
        SET T_EM = 2160,         !- A43
      ELSEIF EM == 5,          !- A44
        SET T_EM = 2880,         !- A45
      ELSEIF EM == 6,          !- A46
        SET T_EM = 3624,         !- A47
      ELSEIF EM == 7,          !- A48
        SET T_EM = 4344,         !- A49
      ELSEIF EM == 8,          !- A50
        SET T_EM = 5088,         !- A51
      ELSEIF EM == 9,          !- A52
        SET T_EM = 5832,         !- A53
      ELSEIF EM == 10,         !- A54
        SET T_EM = 6552,         !- A55
      ELSEIF EM == 11,         !- A56
        SET T_EM = 7296,         !- A57
      ELSEIF EM == 12,         !- A58
        SET T_EM = 8016,         !- A59
      ENDIF,                   !- A60
      SET StartTime = T_SM + (SD-1)*24 + ST,  !- A61
      SET EndTime = T_EM + (ED-1)*24 + ET,  !- A62
      IF (ActualTime>=StartTime) && (ActualTime<=EndTime),  !- A63
        SET AF_previous = @TrendValue emstv_#{$faultnow}_#{short_name} 1,  !- A64			
        SET AF_current_#{$faultnow}_#{short_name} = AF_previous + dt/tau,  !- A65
        IF AF_current_#{$faultnow}_#{short_name}>1.0,       !- A66
          SET AF_current_#{$faultnow}_#{short_name} = 1.0,    !- A67
        ENDIF,                   !- A68
        IF AF_previous>=1.0,     !- A69
          SET AF_current_#{$faultnow}_#{short_name} = 1.0,    !- A70
        ENDIF,                   !- A71
      ELSE,                    !- A72
        SET AF_previous = 0.0,   !- A73
        SET AF_current_#{$faultnow}_#{short_name} = 0.0,    !- A74
	  ENDIF,
	  SET SCH = sch_original_#{$faultnow}_#{short_name}
	  SET AF = AF_current_#{$faultnow}_#{short_name}
	  SET FL_#{$faultnow}_#{short_name} = SCH*(1+FLPERCENTAGE/100*AF)
    EMS
	ems_program.setBody(program_body)	
	#################################################################################
	#define EMS:ProgramCallingManager
	ems_tv.setName("emstv_#{$faultnow}_#{short_name}")
	ems_tv.setNumberOfTimestepsToBeLogged(1)
	#################################################################################
	#define EMS:TrendVariable
	ems_programcallingmanager.addProgram(ems_program)
	ems_programcallingmanager.setName("emspcm_#{$faultnow}_#{short_name}")
	ems_programcallingmanager.setCallingPoint("AfterPredictorBeforeHVACManagers") #BeginTimestepBeforePredictor/AfterPredictorBeforeHVACManagers/AfterPredictorAfterHVACManagers
	#################################################################################
	#define EMS:Actuator
	ems_actuator.setName("FL_#{$faultnow}_#{short_name}")
	#################################################################################
	#Code below was used to apply dynamic fault evolution with Schedule:File object. However, I wasn't able to find the OpenStudio class for Schedule:File object.
	#################################################################################
	#calculate fault starting time and ending time (0-8760)
	# if start_month == 1
      # t_start_month = 0
    # elsif start_month == 2
      # t_start_month = 744
    # elsif start_month == 3
      # t_start_month = 1416
    # elsif start_month == 4
      # t_start_month = 2160
    # elsif start_month == 5
      # t_start_month = 2880
    # elsif start_month == 6
      # t_start_month = 3624
    # elsif start_month == 7
      # t_start_month = 4344
    # elsif start_month == 8
      # t_start_month = 5088
    # elsif start_month == 9
      # t_start_month = 5832
    # elsif start_month == 10
      # t_start_month = 6552
    # elsif start_month == 11
      # t_start_month = 7296
    # elsif start_month == 12
      # t_start_month = 8016
    # end
    # if end_month == 1
      # t_end_month = 0
    # elsif end_month == 2
      # t_end_month = 744
    # elsif end_month == 3
      # t_end_month = 1416
    # elsif end_month == 4
      # t_end_month = 2160
    # elsif end_month == 5
      # t_end_month = 2880
    # elsif end_month == 6
      # t_end_month = 3624
    # elsif end_month == 7
      # t_end_month = 4344
    # elsif end_month == 8
      # t_end_month = 5088
    # elsif end_month == 9
      # t_end_month = 5832
    # elsif end_month == 10
      # t_end_month = 6552
    # elsif end_month == 11
      # t_end_month = 7296
    # elsif end_month == 12
      # t_end_month = 8016
    # end
	# time_start = t_start_month + (start_date-1)*24 + start_time
    # time_end = t_end_month + (end_date-1)*24 + end_time
	#################################################################################
	#create a text file includes fault level variation throughout the year based on user inputs
	# schedule_input_file = File.new("faultlvlschedule.txt", "w") 
	# iter = 1
	# fl = 0.0
	# loop do
	  # if iter == 8761
	    # break
	  # end
	  # if iter<time_start
	    # schedule_input_file.puts("#{iter}	0")
	  # elsif iter>time_start && iter<time_end
	    # fl_current = fl.to_f+1/time_constant
		
		# if fl_current>1
		  # fl_current = 1
		# end
		
	    # schedule_input_file.puts("#{iter}	#{fl_current}")
	  # else
	    # schedule_input_file.puts("#{iter}	0")
	  # end	  
	  # fl = fl_current
	  # iter += 1
	# end  
	# schedule_input_file.close
	#################################################################################
	#Create Schedule:File object and apply fault level schedule
	#schedule_file = model.getScheduleFiles? (wasn't able to find Schedule:File class)
	#################################################################################
	
end


def name_cut(complexname)
  # return a name that is trimmed without space and symbols
  return complexname.clone.gsub!(/[^0-9A-Za-z]/, '')
end
