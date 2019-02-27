# This ruby script creates EnergyPlus Objects to simulate refrigerant-sidefaults
# faults in Coil:Cooling:DX:SingleSpeed objects

require "#{File.dirname(__FILE__)}/misc_eplus_func"

def faultintensity_adjustmentfactor(string_objects, time_constant, time_step, start_month, start_date, start_time, end_month, end_date, end_time, sh_coil_choice)

  #append transient fault adjustment factor
  ##################################################
  string_objects << "
    EnergyManagementSystem:Program,
      AF_P_#{$faultnow}_"+sh_coil_choice+",                    !- Name
      SET SM = "+start_month+",              !- Program Line 1
      SET SD = "+start_date+",              !- Program Line 2
      SET ST = "+start_time+",              !- A4
      SET EM = "+end_month+",              !- A5
      SET ED = "+end_date+",             !- A6
      SET ET = "+end_time+",             !- A7
      SET tau = "+time_constant+",          !- A8
      SET dt = "+time_step+",           !- A9
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
        SET AF_previous = @TrendValue AF_trend_#{$faultnow}_"+sh_coil_choice+" 1,  !- A64			
        SET AF_current_#{$faultnow}_"+sh_coil_choice+" = AF_previous + dt/tau,  !- A65
        IF AF_current_#{$faultnow}_"+sh_coil_choice+">1.0,       !- A66
          SET AF_current_#{$faultnow}_"+sh_coil_choice+" = 1.0,    !- A67
        ENDIF,                   !- A68
        IF AF_previous>=1.0,     !- A69
          SET AF_current_#{$faultnow}_"+sh_coil_choice+" = 1.0,    !- A70
        ENDIF,                   !- A71
      ELSE,                    !- A72
        SET AF_previous = 0.0,   !- A73
        SET AF_current_#{$faultnow}_"+sh_coil_choice+" = 0.0,    !- A74
      ENDIF;                   !- A75
  "
  
  string_objects << "
    EnergyManagementSystem:GlobalVariable,				
      AF_current_#{$faultnow}_"+sh_coil_choice+";              !- Erl Variable 1 Name
  "
			  
  string_objects << "
    EnergyManagementSystem:TrendVariable,				
      AF_Trend_#{$faultnow}_"+sh_coil_choice+",                !- Name
      AF_current_#{$faultnow}_"+sh_coil_choice+",              !- EMS Variable Name
      1;                       !- Number of Timesteps to be Logged
  "
			
  string_objects << "
	EnergyManagementSystem:ProgramCallingManager,
      AF_PCM_#{$faultnow}_"+sh_coil_choice+",                  !- Name
      AfterPredictorAfterHVACManagers,  !- EnergyPlus Model Calling Point
      AF_P_#{$faultnow}_"+sh_coil_choice+";                    !- Program Name 1
  "
  ##################################################
  
  return string_objects
  
end

def no_fault_schedules(workspace, scheduletypelimitname, string_objects)
  # This function creates constant schedules at zero and one throughout the year
  # so that it can be referenced by fault calculation functions when the fault level
  # is zero
  # workspace is a WorkSpace object with E+ objects in the building model_name
  #
  # scheduletypelimitname is a string with the name of a fractional schedule type limits
  # objects that bounds schedule values between 0 and 1
  #
  # string_objects is an array object storing strings formatted as E+ objects. These objects
  # will be added to the E+ model at the end of the run function in the Measure script calling
  # this function

  # create a schedule of one and zero to indicate that other faults do not exist
  const_fault_schs = workspace.getObjectsByType('Schedule:Constant'.to_IddObjectType)
  zero_fault_sch = false
  one_fault_sch = false
  const_fault_schs.each do |const_fault_sch|
    if const_fault_sch.getString(0).to_s.eql?('ZERO_FAULT')
      zero_fault_sch = true
    end
    if const_fault_sch.getString(0).to_s.eql?('ONE_FAULT')
      one_fault_sch = true
    end
  end

  # only create the schedules when the schedules do not exist
  unless zero_fault_sch
    string_objects << "
      Schedule:Constant,
        ZERO_FAULT,         !- Name
        #{scheduletypelimitname},                       !- Schedule Type Limits Name
        0;                    !- Hourly Value
    "
  end
  unless one_fault_sch
    string_objects << "
      Schedule:Constant,
        ONE_FAULT,         !- Name
        #{scheduletypelimitname},                       !- Schedule Type Limits Name
        1;                    !- Hourly Value
    "
  end

  return string_objects
end

# define function to write EMS main program to alter the temperature curve
def main_program_entry(workspace, string_objects, coil_choice, curve_name, para, model_name, fault_lvl)
  # This function writes an E+ object that embed the temperature modulation
  # curve in the Coil:Cooling:DX:SingleSpeed object with fault the fault model
  #
  # workspace is a WorkSpace object with E+ objects in the building model_name
  #
  # string_objects is an array object storing strings formatted as E+ objects. These objects
  # will be added to the E+ model at the end of the run function in the Measure script calling
  # this function
  #
  # coil_choice is a string that is the name of the Coil:Cooling:DX:SingleSpeed object
  # to be faulted
  #
  # curve_name is a string that contains the name of an Curve:Biquadratic object
  #
  # para is an array containing the coefficients and limits of an Curve:Biquadratic
  # object. This Curve:Biquadratic object defines the temperature modulation curve.
  #
  # model_name is a string that defines what should be altered. Q for cooling capacity,
  # EIR for energy-input-ratio, etc.

  # only write EMS program of the new curve if the program does not exist
  sh_coil_choice = coil_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
  if sh_coil_choice.eql?(nil)
    sh_coil_choice = coil_choice
  end
  
  ##################################################
  sh_curve_name = curve_name.clone.gsub!(/[^0-9A-Za-z]/, '')
  if sh_curve_name.eql?(nil)
    sh_curve_name = curve_name
  end
  
  emsprograms = workspace.getObjectsByType('EnergyManagementSystem:Program'.to_IddObjectType)
  writeprogram = true
  emsprograms.each do |emsprogram|
    if emsprogram.getString(0).to_s.eql?('DXCoolingCoilDegradation' + sh_coil_choice + model_name + sh_curve_name)
      writeprogram = false
      break
    end
  end
  ##################################################

  if writeprogram
    string_objects << "
      EnergyManagementSystem:Program,
        DXCoolingCoilDegradation#{sh_coil_choice + model_name + sh_curve_name}, !- Name
        SET TTmp = CoilInletDBT#{sh_coil_choice}, !- Program Line 1
        SET WTmp = CoilInletW#{sh_coil_choice},   !- Program Line 2
        SET PTmp = Pressure#{sh_coil_choice},     !- <none>
        SET MyWB = @TwbFnTdbWPb TTmp WTmp PTmp,  !- <none>
        SET IVOne = MyWB,       !- <none>
        SET IVTwo = OAT#{sh_coil_choice},         !- <none>
        SET C1 = #{para[0]},  !- <none>
        SET C2 = #{para[1]},  !- <none>
        SET C3 = #{para[2]},  !- <none>
        SET C4 = #{para[3]},  !- <none>
        SET C5 = #{para[4]},  !- <none>
        SET C6 = #{para[5]},  !- <none>
        SET IVOneMin = #{para[6]},  !- <none>
        SET IVOneMax = #{para[7]},  !- <none>
        SET IVTwoMin = #{para[8]},  !- <none>
        SET IVTwoMax = #{para[9]},  !- <none>
        IF IVOne < IVOneMin,
          SET IVOne = IVOneMin,
        ENDIF,  !- <none>
        IF IVOne > IVOneMax,
          SET IVOne = IVOneMax,
        ENDIF,  !- <none>
        IF IVTwo < IVTwoMin,
          SET IVTwo = IVTwoMin,
        ENDIF,  !- <none>
        IF IVTwo > IVTwoMax,
          SET IVTwo = IVTwoMax,
        ENDIF,  !- <none>
        SET IVThree = IVOne*IVTwo,  !- <none>
        SET OriCurve = (C1+(C2*IVOne) + (C3*IVOne*IVone) + (C4*IVTwo) + (C5*IVTwo*IVTwo) + (C6*IVThree)),  !- <none>
        SET FAULT_ADJ_RATIO = 1.0, !- <none>
        SET #{$faultnow}FaultLevel_#{sh_coil_choice} = #{fault_lvl.to_s}*AF_current_#{$faultnow}_"+sh_coil_choice+",   !- <none>
        RUN #{$faultnow}_ADJUST_#{sh_coil_choice}_#{model_name}_#{sh_curve_name}, !- Calling subrountines that adjust the cooling capacity based on fault type
        SET FAULT_ADJ_RATIO = #{$faultnow}_FAULT_ADJ_RATIO_#{sh_coil_choice}*FAULT_ADJ_RATIO,     !- <none>
        SET #{model_name}Curve#{sh_coil_choice}#{sh_curve_name} = (OriCurve*FAULT_ADJ_RATIO);  !- <none>
    "
    # create the ProgramCaller, required actuators, etc. that are only required by this program
    string_objects << "
      EnergyManagementSystem:ProgramCallingManager,
      EMSCallDXCoolingCoilDegradation#{sh_coil_choice}#{model_name}, !- Name
      AfterPredictorBeforeHVACManagers, !- EnergyPlus Model Calling Point
      DXCoolingCoilDegradation#{sh_coil_choice}#{model_name}#{sh_curve_name}; !- Program Name 1
    "

    string_objects << "
      EnergyManagementSystem:Actuator,
        #{model_name}Curve#{sh_coil_choice}#{sh_curve_name},          !- Name
        #{curve_name},           !- Actuated Component Unique Name
        Curve,                   !- Actuated Component Type
        Curve Result;            !- Actuated Component Control Type
    "

    string_objects << "
      EnergyManagementSystem:OutputVariable,
        #{model_name}CurveValue#{sh_coil_choice},           !- Name
        #{model_name}Curve#{sh_coil_choice}#{sh_curve_name},          !- EMS Variable Name
        Averaged,                !- Type of Data in Variable
        ZoneTimeStep,            !- Update Frequency
        ,                        !- EMS Program or Subroutine Name
        ;                        !- Units
    "
  end

  return string_objects
end

def dummy_fault_sub_add(workspace, string_objects, coilcooling, fault_choice = 'CA', coil_choice, model_name, coiltype, coilperformancedxcooling, curve_index)
  # This function adds any dummy subroutine that does nothing. It's used when the fault is not modeled
  add_sub = true
  ##################################################
  sh_coil_choice = coil_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
  if sh_coil_choice.eql?(nil)
    sh_coil_choice = coil_choice
  end
  
  if coiltype == 1 #SINGLESPEED
	curve_str = pass_string(coilcooling, curve_index)
  elsif coiltype == 2 #TWOSTAGEWITHHUMIDITYCONTROLMODE
	curve_str = pass_string(coilperformancedxcooling, curve_index)
  end

  curvebiquadratics = get_workspace_objects(workspace, 'Curve:Biquadratic')
  curve_name, paraq, no_curve = para_biquadratic_limit(curvebiquadratics, curve_str)
  
  sh_curve_name = curve_name.clone.gsub!(/[^0-9A-Za-z]/, '')
  if sh_curve_name.eql?(nil)
    sh_curve_name = curve_name
  end
  ##################################################

  subroutines = workspace.getObjectsByType('EnergyManagementSystem:Subroutine'.to_IddObjectType)
  subroutines.each do |subroutine|
    if subroutine.getString(0).to_s.eql?("#{fault_choice}_ADJUST_#{sh_coil_choice}_#{model_name}_#{sh_curve_name}")
      add_sub = false
      break
    end
  end

  if add_sub
    string_objects << "
      EnergyManagementSystem:Subroutine,
        #{fault_choice}_ADJUST_#{sh_coil_choice}_#{model_name}_#{sh_curve_name}, !- Name
        SET #{fault_choice}_FAULT_ADJ_RATIO_#{sh_coil_choice} = 1.0,  !- <none>
    "

    # add global variables when needed
    write_global_fr = true
    ems_globalvars = workspace.getObjectsByType('EnergyManagementSystem:GlobalVariable'.to_IddObjectType)
    ems_globalvars.each do |ems_globalvar|
      if ems_globalvar.getString(0).to_s.eql?("#{fault_choice}_FAULT_ADJ_RATIO_#{sh_coil_choice}")
        write_global_fr = false
      end
    end

    if write_global_fr
      str_added = "
        EnergyManagementSystem:GlobalVariable,
          #{fault_choice}_FAULT_ADJ_RATIO_#{sh_coil_choice};                !- Name
      "
      unless string_objects.include?(str_added)
        string_objects << str_added
      end
    end
  end

  return string_objects
end

def general_adjust_function_cfd(workspace, coil_choice, string_objects, coilcooling, model_name, para, fault_name, coiltype, coilperformancedxcooling, curve_index)
  # This function appends the program and the required variables that calculate the fault impact ratio
  # into the EnergyPlus IDF file

  ##################################################
  sh_coil_choice = coil_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
  if sh_coil_choice.eql?(nil)
    sh_coil_choice = coil_choice
  end
  
  if coiltype == 1 #SINGLESPEED
	curve_str = pass_string(coilcooling, curve_index)
  elsif coiltype == 2 #TWOSTAGEWITHHUMIDITYCONTROLMODE
	curve_str = pass_string(coilperformancedxcooling, curve_index)
  end

  curvebiquadratics = get_workspace_objects(workspace, 'Curve:Biquadratic')
  curve_name, paraq, no_curve = para_biquadratic_limit(curvebiquadratics, curve_str)
  
  sh_curve_name = curve_name.clone.gsub!(/[^0-9A-Za-z]/, '')
  if sh_curve_name.eql?(nil)
    sh_curve_name = curve_name
  end
  ##################################################

  fault_level_name = "#{fault_name}FaultLevel_#{sh_coil_choice}"
  fir_name = "#{fault_name}_FAULT_ADJ_RATIO_#{sh_coil_choice}"
  
  final_line = "
    EnergyManagementSystem:Subroutine,
      #{fault_name}_ADJUST_#{sh_coil_choice}_#{model_name}_#{sh_curve_name}, !- Name
	  IF #{fault_level_name}*AF_current_#{$faultnow}_"+sh_coil_choice+" >= 0.99, !- <none>
      SET #{fir_name} = 99.0, !- <none>
      ELSE, !- <none>
      SET #{fir_name} = (#{fault_level_name}*AF_current_#{$faultnow}_"+sh_coil_choice+")/(1.0-(#{fault_level_name}*AF_current_#{$faultnow}_"+sh_coil_choice+")),  !- <none>
      ENDIF,
      SET #{fir_name} = 1.0+#{fir_name}*#{para[0]};  !- <none>
    "

  # before addition, delete any dummy subrountine with the same name in the workspace
  subroutines = workspace.getObjectsByType('EnergyManagementSystem:Subroutine'.to_IddObjectType)
  subroutines.each do |subroutine|
    if subroutine.getString(0).to_s.eql?("#{fault_name}_ADJUST_#{sh_coil_choice}_#{model_name}_#{sh_curve_name}")
      workspace.removeObject(subroutine.handle)  # should have only one of them
      break
    end
  end
  string_objects << final_line

  # set up global variables, if needed
  write_global_ch_fl = true
  write_global_ch_fr = true
  ems_globalvars = workspace.getObjectsByType('EnergyManagementSystem:GlobalVariable'.to_IddObjectType)
  ems_globalvars.each do |ems_globalvar|
    if ems_globalvar.getString(0).to_s.eql?(fault_level_name)
      write_global_ch_fl = false
    end
    if ems_globalvar.getString(0).to_s.eql?(fir_name)
      write_global_ch_fr = false
    end
  end

  if write_global_ch_fl
    str_added = "
      EnergyManagementSystem:GlobalVariable,
        #{fault_level_name};                !- Name
    "
    unless string_objects.include?(str_added)  # only add global variables if they are not added by the same Measure script
      string_objects << str_added
    end
  end

  if write_global_ch_fr
    str_added = "
      EnergyManagementSystem:GlobalVariable,
        #{fir_name};                !- Name
    "
    unless string_objects.include?(str_added)
      string_objects << str_added
    end
  end

  return string_objects, workspace
end
