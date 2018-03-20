# This ruby script creates EnergyPlus Objects to simulate refrigerant-sidefaults
# faults in Coil:Cooling:DX:SingleSpeed objects

require "#{File.dirname(__FILE__)}/misc_eplus_func"
require "#{File.dirname(__FILE__)}/psychrometric"

def faultintensity_adjustmentfactor(string_objects, time_constant, time_step, start_month, start_date, start_time, end_month, end_date, end_time, sh_coil_choice)

  #append transient fault adjustment factor
  ##################################################
  string_objects << "
    EnergyManagementSystem:Program,
      AF_P,                    !- Name
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
        SET AF_previous = @TrendValue AF_trend 1,  !- A64			
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
      AF_Trend,                !- Name
      AF_current_#{$faultnow}_"+sh_coil_choice+",              !- EMS Variable Name
      1;                       !- Number of Timesteps to be Logged
  "
			
  string_objects << "
	EnergyManagementSystem:ProgramCallingManager,
      AF_PCM,                  !- Name
      AfterPredictorAfterHVACManagers,  !- EnergyPlus Model Calling Point
      AF_P;                    !- Program Name 1
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

def general_adjust_function(workspace, coil_choice, string_objects, coilcooling, model_name, para, fault_name, coiltype, coilperformancedxcooling, curve_index)
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
  
  if coiltype == 1 #SINGLESPEED
    rated_cop = coilcooling.getDouble(4).to_f
  elsif coiltype == 2 #TWOSTAGEWITHHUMIDITYCONTROLMODE
    rated_cop = coilperformancedxcooling.getDouble(3).to_f
  end
  ##################################################

  fault_level_name = "#{fault_name}FaultLevel_#{sh_coil_choice}"
  fir_name = "#{fault_name}_FAULT_ADJ_RATIO_#{sh_coil_choice}"
  
  final_line = "
    EnergyManagementSystem:Subroutine,
      #{fault_name}_ADJUST_#{sh_coil_choice}_#{model_name}_#{sh_curve_name}, !- Name
      SET TTmp = CoilInletDBT#{sh_coil_choice}, !- Program Line 1
      SET WTmp = CoilInletW#{sh_coil_choice},   !- Program Line 2
      SET PTmp = Pressure#{sh_coil_choice},     !- <none>
      SET MyWB = @TwbFnTdbWPb TTmp WTmp PTmp,  !- <none>
      SET OAT = OAT#{sh_coil_choice},   !- <none>
      SET RATCOP = #{rated_cop}, !-<none>
      IF #{fault_level_name} > #{para[0]},  !- <none>
      SET #{fault_level_name} = #{para[0]},  !- <none>
      ENDIF, !-<none>
      SET C1 = #{para[1]},  !- <none>
      SET C2 = #{para[2]},  !- <none>
      SET C3 = #{para[3]},  !- <none>
      SET C4 = #{para[4]},  !- <none>
      SET C5 = #{para[5]},  !- <none>
      SET C6 = #{para[6]},  !- <none>
      SET MINWB = #{para[7]},  !- <none>
      IF MyWB < MINWB,  !- <none>
      SET MyWB = MINWB,  !- <none>
      ENDIF, !-<none>
      SET MAXWB = #{para[8]},  !- <none>
      IF MyWB > MAXWB,  !- <none>
      SET MyWB = MAXWB,  !- <none>
      ENDIF, !-<none>
      SET MINOAT = #{para[9]},  !- <none>
      IF OAT < MINOAT,  !- <none>
      SET OAT = MINOAT,  !- <none>
      ENDIF, !-<none>
      SET MAXOAT = #{para[10]},  !- <none>
      IF OAT > MAXOAT,  !- <none>
      SET OAT = MAXOAT,  !- <none>
      ENDIF, !-<none>
      SET MINCOP = #{para[11]},  !- <none>
      IF RATCOP < MINCOP,  !- <none>
      SET RATCOP = MINCOP,  !- <none>
      ENDIF, !-<none>
      SET MAXCOP = #{para[12]},  !- <none>
      IF RATCOP > MAXCOP,  !- <none>
      SET RATCOP = MAXCOP,  !- <none>
      ENDIF, !-<none>
      SET MyWB = MyWB/273.15+1.0, !- <none>
      SET OAT = OAT/273.15+1.0, !- <none>
      SET #{fir_name} = (C1+C2*MyWB+C3*OAT+C4*#{fault_level_name}),  !- <none>
      SET #{fir_name} = (#{fir_name}+C5*#{fault_level_name}*#{fault_level_name}),  !- <none>
      SET #{fir_name} = (#{fir_name}+C6*RATCOP),  !- <none>
      SET #{fir_name} = (1+#{fault_level_name}*#{fir_name});  !- <none>
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

def tadp_solver(workspace, runner, t_adp, slope_adp, p_atm, t_in, w_in)
  thres = 0.0001
  negthres = -1.0*thres
  error = 1000.0
  errorlast = error
  deltatadp = 5.0
  it = 1
  while error > thres || error < negthres && it < 100 do
    if it > 1
      t_adp = t_adp + deltatadp
    end
    w_adp = psych(p_atm, 'tdb', t_adp, 'rh', 1.0, 'w', unittype='SI') #@WFnTdbRhPb Tadp 1.0 PTmp 
    slope = (w_in - w_adp)/(t_in - t_adp)
    error = (slope - slope_adp)/slope_adp
    if it > 1
      if error > 0.0 && errorlast <= 0.0
	deltatadp = -1.0*(deltatadp/2.0)
      elsif error <= 0.0 && errorlast > 0.0
	deltatadp = -1.0*(deltatadp/2.0)
      elsif error > 0.0 && errorlast > 0.0 && error > errorlast
	deltatadp = -1.0*deltatadp
      elsif error < 0.0 && errorlast < 0.0 && error < errorlast
	deltatadp = -1.0*deltatadp
      end
    end
    it = it + 1
    errorlast = error
  end
  t_adp_new = t_adp
  w_adp_new = w_adp
  
  return t_adp_new, w_adp_new
  
  #Original EMS code
  # TADPNCCoilCoolingDXSingleSpeed1SOLVER,  !- Name
  # SET Tadp = TadpNCCoilCoolingDXSingleSpeed1, !- Program Line 1
  # SET Slopeadp = SlopeadpNCCoilCoolingDXSingleSpeed1, !- Program Line 2
  # SET PTmp = PatmNCCoilCoolingDXSingleSpeed1, !- Program Line 3
  # SET Tin = TinNCCoilCoolingDXSingleSpeed1, !- Program Line 4
  # SET Win = WinNCCoilCoolingDXSingleSpeed1, !- Program Line 5
  # SET Thres = 0.0001,                     !- Program Line 6
  # SET NegThres = -1.0*Thres,              !- Program Line 7
  # SET Error = 1000.0,                     !- Program Line 8
  # SET Errorlast = Error,                  !- Program Line 9
  # SET DeltaTadp = 5.0,                    !- Program Line 10
  # SET IT = 1,                             !- Program Line 11
  # WHILE ((Error > Thres || Error < NegThres) && IT < 100), !- Program Line 12
  # IF IT > 1,                              !- Program Line 13
  # SET Tadp = Tadp+DeltaTadp,              !- Program Line 14
  # ENDIF,                                  !- Program Line 15
  # SET Wadp = @WFnTdbRhPb Tadp 1.0 PTmp,   !- Program Line 16
  # SET Slope = Win-Wadp,                   !- Program Line 17
  # SET Slope = Slope/(Tin-Tadp),           !- Program Line 18
  # SET Error = Slope-Slopeadp,             !- Program Line 19
  # SET Error = Error/Slopeadp,             !- Program Line 20
  # IF IT > 1,                              !- Program Line 21
  # IF Error > 0.0 && Errorlast <= 0.0,     !- Program Line 22
  # SET DeltaTadp = DeltaTadp/2.0,          !- Program Line 23
  # SET DeltaTadp = -1.0*DeltaTadp,         !- Program Line 24
  # ELSEIF Error <= 0.0 && Errorlast > 0.0, !- Program Line 25
  # SET DeltaTadp = DeltaTadp/2.0,          !- Program Line 26
  # SET DeltaTadp = -1.0*DeltaTadp,         !- Program Line 27
  # ELSEIF Error > 0.0 && Errorlast > 0.0 && Error > Errorlast, !- Program Line 28
  # SET DeltaTadp = -1.0*DeltaTadp,         !- Program Line 29
  # ELSEIF Error < 0.0 && Errorlast < 0.0 && Error < Errorlast, !- Program Line 30
  # SET DeltaTadp = -1.0*DeltaTadp,         !- Program Line 31
  # ENDIF,                                  !- Program Line 32
  # ENDIF,                                  !- Program Line 33
  # SET IT = IT+1,                          !- Program Line 34
  # SET Errorlast = Error,                  !- Program Line 35
  # ENDWHILE,                               !- Program Line 36
  # SET TadpNCCoilCoolingDXSingleSpeed1 = Tadp, !- Program Line 37
  # SET WadpNCCoilCoolingDXSingleSpeed1 = Wadp; !- Program Line 38
end

def tout_solver(workspace, runner, t_out, h_out, slope_adp, p_atm, t_in, w_in)
  thres = 0.0001
  negthres = -1.0*thres
  error = 1000.0
  errorlast = error
  deltatout = 5.0
  it = 1
  while error > thres || error < negthres && it < 100 do
    if it > 1
      t_out = t_out + deltatout
    end
    w_out = psych(p_atm, 'tdb', t_out, 'h', h_out/1000.0, 'w', unittype='SI') #@WFnTdbH Tout Hout
    slope = (w_in - w_out)/(t_in - t_out)
    error = (slope - slope_adp)/slope_adp
    if it > 1
      if error > 0.0 && errorlast <= 0.0
	deltatout = -1.0*(deltatout/2.0)
      elsif error <= 0.0 && errorlast > 0.0
	deltatout = -1.0*(deltatout/2.0)
      elsif error > 0.0 && errorlast > 0.0 && error > errorlast
	deltatout = -1.0*deltatout
      elsif error < 0.0 && errorlast < 0.0 && error < errorlast
	deltatout = -1.0*deltatout
      end
    end
    it = it + 1
    errorlast = error
  end
  t_out_new = t_out
  w_out_new = w_out
  
  return t_out_new, w_out_new
  
  #Original EMS code
  # TOUTNCCoilCoolingDXSingleSpeed1SOLVER,  !- Name
  # SET Tout = ToutNCCoilCoolingDXSingleSpeed1, !- Program Line 1
  # SET Hout = HoutNCCoilCoolingDXSingleSpeed1, !- Program Line 2
  # SET Slopeadp = SlopeadpNCCoilCoolingDXSingleSpeed1, !- Program Line 3
  # SET PTmp = PatmNCCoilCoolingDXSingleSpeed1, !- Program Line 4
  # SET Tin = TinNCCoilCoolingDXSingleSpeed1, !- Program Line 5
  # SET Win = WinNCCoilCoolingDXSingleSpeed1, !- Program Line 6
  # SET Thres = 0.0001,                     !- Program Line 7
  # SET NegThres = -1.0*Thres,              !- Program Line 8
  # SET Error = 1000.0,                     !- Program Line 9
  # SET Errorlast = Error,                  !- Program Line 10
  # SET DeltaTout = 5.0,                    !- Program Line 11
  # SET IT = 1,                             !- Program Line 12
  # WHILE ((Error > Thres || Error < NegThres) && IT < 100), !- Program Line 13
  # IF IT > 1,                              !- Program Line 14
  # SET Tout = Tout+DeltaTout,              !- Program Line 15
  # ENDIF,                                  !- Program Line 16
  # SET Wout = @WFnTdbH Tout Hout,          !- Program Line 17
  # SET Slope = Win-Wout,                   !- Program Line 18
  # SET Slope = Slope/(Tin-Tout),           !- Program Line 19
  # SET Error = Slope-Slopeadp,             !- Program Line 20
  # SET Error = Error/Slopeadp,             !- Program Line 21
  # IF IT > 1,                              !- Program Line 22
  # IF Error > 0.0 && Errorlast <= 0.0,     !- Program Line 23
  # SET DeltaTout = DeltaTout/2.0,          !- Program Line 24
  # SET DeltaTout = -1.0*DeltaTout,         !- Program Line 25
  # ELSEIF Error <= 0.0 && Errorlast > 0.0, !- Program Line 26
  # SET DeltaTout = DeltaTout/2.0,          !- Program Line 27
  # SET DeltaTout = -1.0*DeltaTout,         !- Program Line 28
  # ELSEIF Error > 0.0 && Errorlast > 0.0 && Error > Errorlast, !- Program Line 29
  # SET DeltaTout = -1.0*DeltaTout,         !- Program Line 30
  # ELSEIF Error < 0.0 && Errorlast < 0.0 && Error < Errorlast, !- Program Line 31
  # SET DeltaTout = -1.0*DeltaTout,         !- Program Line 32
  # ENDIF,                                  !- Program Line 33
  # ENDIF,                                  !- Program Line 34
  # SET IT = IT+1,                          !- Program Line 35
  # SET Errorlast = Error,                  !- Program Line 36
  # ENDWHILE,                               !- Program Line 37
  # SET ToutNCCoilCoolingDXSingleSpeed1 = Tout, !- Program Line 38
  # SET WoutNCCoilCoolingDXSingleSpeed1 = Wout; !- Program Line 39
end

def shr_modification(workspace, runner, qdot_rat, shr_rat, vdot_rat, bf_para, fault_lvl)
  t_tmp = 26.7
  w_tmp = 0.011152
  p_tmp = 101325.0
  h_in = psych(p_tmp, 'tdb', t_tmp, 'w', w_tmp, 'h', unittype='SI')*1000 #@HFnTdbW TTmp WTmp
  rho_in = psych(p_tmp, 'tdb', t_tmp, 'w', w_tmp, 'MAD', unittype='SI') #@RhoAirFnPbTdbW PTmp TTmp WTmp  
  mdot_a = rho_in*vdot_rat
  deltah = qdot_rat/mdot_a
  h_tin_wout = h_in - (1 - shr_rat)*deltah
  w_out = psych(p_tmp, 'tdb', t_tmp, 'h', h_tin_wout/1000.0, 'w', unittype='SI') #@WFnTdbH TTmp HTinWout
  h_out = h_in - deltah
  t_out = psych(p_tmp, 'h', h_out/1000.0, 'w', w_out, 'tdb', unittype='SI') #@TdbFnHW Hout Wout  
  deltat = t_tmp - t_out
  deltaw = w_tmp - w_out
  slope_adp = deltaw/deltat
  t_adp = t_out - 1.0
  t_in = t_tmp
  w_in = w_tmp
  p_atm = p_tmp
  t_adp, w_adp = tadp_solver(workspace, runner, t_adp, slope_adp, p_atm, t_in, w_in)
  h_adp = psych(p_atm, 'tdb', t_adp, 'w', w_adp, 'h', unittype='SI')*1000 #@HFnTdbW Tadp Wadp
  bf = (h_out - h_adp)/(h_in - h_adp)  
  adjao = 1 + bf_para*fault_lvl
  ao = (-1.0*mdot_a*(Math.log(bf)))*adjao 
  bf = Math.exp((-1.0*ao)/mdot_a) 
  h_adp = ((bf*h_in) - h_out)/(bf - 1.0)
  
  ############################################################
  w_iter = 0.004
  error_iter = 100.0
  while error_iter >= 0.01 do
	dsat_iter = psych(p_atm, 'h', h_adp/1000.0, 'w', w_iter, 'DSat', unittype='SI')
	tdb_iter = psych(p_atm, 'h', h_adp/1000.0, 'w', w_iter, 'tdb', unittype='SI')
	error_iter = (1 - dsat_iter)
	w_iter = w_iter + 0.0001	
  end
  ############################################################
  
  t_adp = tdb_iter #@TsatFnHPb Hadp PTmp
  w_adp = psych(p_atm, 'tdb', t_adp, 'h', h_adp/1000.0, 'w', unittype='SI') #@WFnTdbH Tadp Hadp
   
  deltat = t_tmp - t_adp
  deltaw = w_tmp - w_adp
  
  slope_adp = deltaw/deltat
  t_out = t_adp + 1.0
  h_out = h_out 
  t_in = t_tmp
  w_in = w_tmp
  p_atm = p_tmp
  
  t_out, w_out = tout_solver(workspace, runner, t_out, h_out, slope_adp, p_atm, t_in, w_in)
  
  if w_out >= w_tmp
    shr_new = 1.0
  else	
    ############################################################
    h_g = 2500940.0 + 1858.95*t_adp #EnergyPlus PsychRoutines
    h_f = 4180.0*t_adp #EnergyPlus PsychRoutines
    h_fg_adp = h_g - h_f #EnergyPlus PsychRoutines
    # h_fg_adp = -0.4121*t_adp**2.0 - 2351.91*t_adp + 2501084.59 #Saturated Air Properties (Incropera)
    ############################################################
    qdot_lat = h_fg_adp*(w_tmp - w_out)
    shr_new = 1.0 - qdot_lat/(h_in - h_out)
  end
  
  return shr_new

  #Original EMS code
  # NC_DXSHRModCoilCoolingDXSingleSpeed1,   !- Name
  # SET TTmp = 26.7,                        !- Program Line 1
  # SET WTmp = 0.011152,                    !- Program Line 2
  # SET PTmp = 101325.0,                    !- Program Line 3
  # SET Hin = @HFnTdbW TTmp WTmp,           !- Program Line 4
  # SET Rhoin = @RhoAirFnPbTdbW PTmp TTmp WTmp, !- Program Line 5
  # SET Qrat = 1000.0,                      !- Program Line 6
  # SET SHRrat = 0.687,                     !- Program Line 7
  # SET Volrat = 0.05,                      !- Program Line 8
  # SET Mdota = Rhoin*Volrat,               !- Program Line 9
  # SET DeltaH = Qrat/mdota,                !- Program Line 10
  # SET HTinWout = Hin-(1-SHRrat)*DeltaH,   !- Program Line 11
  # SET Wout = @WFnTdbH TTmp HTinWout,      !- Program Line 12
  # SET Hout = Hin-DeltaH,                  !- Program Line 13
  # SET Tout = @TdbFnHW Hout Wout,          !- Program Line 14
  # SET DeltaT = TTmp-Tout,                 !- Program Line 15
  # SET DeltaW = WTmp-Wout,                 !- Program Line 16
  # SET SlopeadpNCCoilCoolingDXSingleSpeed1 = DeltaW/DeltaT, !- Program Line 17
  # SET TadpNCCoilCoolingDXSingleSpeed1 = Tout-1.0, !- Program Line 18
  # SET TinNCCoilCoolingDXSingleSpeed1 = TTmp, !- Program Line 19
  # SET WinNCCoilCoolingDXSingleSpeed1 = WTmp, !- Program Line 20
  # SET PatmNCCoilCoolingDXSingleSpeed1 = PTmp, !- Program Line 21
  # RUN TADPNCCoilCoolingDXSingleSpeed1SOLVER, !- Program Line 22
  # SET Tadp = TadpNCCoilCoolingDXSingleSpeed1, !- Program Line 23
  # SET Wadp = WadpNCCoilCoolingDXSingleSpeed1, !- Program Line 24
  # SET Hadp = @HFnTdbW Tadp Wadp,          !- Program Line 25
  # SET BF = Hout-Hadp,                     !- Program Line 26
  # SET BF = BF/(Hin-Hadp),                 !- Program Line 27
  # SET Ao = @Ln BF,                        !- Program Line 28
  # SET Ao = mdota*Ao,                      !- Program Line 29
  # SET Ao = -1.0*Ao,                       !- Program Line 30
  # SET adjAo = 0.373*0.4,                  !- Program Line 31
  # SET adjAo = 1+adjAo,                    !- Program Line 32
  # SET Ao = Ao*adjAo,                      !- Program Line 33
  # SET BF = -1.0*Ao,                       !- Program Line 34
  # SET BF = BF/mdota,                      !- Program Line 35
  # SET BF = @Exp BF,                       !- Program Line 36
  # SET Hadp = BF*Hin,                      !- Program Line 37
  # SET Hadp = Hadp-Hout,                   !- Program Line 38
  # SET Hadp = Hadp/(BF-1.0),               !- Program Line 39
  # SET Tadp = @TsatFnHPb Hadp PTmp,        !- Program Line 40
  # SET Wadp = @WFnTdbH Tadp Hadp,          !- Program Line 41
  # SET DeltaT = TTmp-Tadp,                 !- Program Line 42
  # SET DeltaW = WTmp-Wadp,                 !- Program Line 43
  # SET SlopeadpNCCoilCoolingDXSingleSpeed1 = DeltaW/DeltaT, !- Program Line 44
  # SET ToutNCCoilCoolingDXSingleSpeed1 = Tadp+1.0, !- Program Line 45
  # SET HoutNCCoilCoolingDXSingleSpeed1 = Hout, !- Program Line 46
  # SET TinNCCoilCoolingDXSingleSpeed1 = TTmp, !- Program Line 47
  # SET WinNCCoilCoolingDXSingleSpeed1 = WTmp, !- Program Line 48
  # SET PatmNCCoilCoolingDXSingleSpeed1 = PTmp, !- Program Line 49
  # RUN TOUTNCCoilCoolingDXSingleSpeed1SOLVER, !- Program Line 50
  # SET Tout = ToutNCCoilCoolingDXSingleSpeed1, !- Program Line 51
  # SET Wout = WoutNCCoilCoolingDXSingleSpeed1, !- Program Line 52
  # IF Wout >= WTmp,                        !- Program Line 53
  # SET SHRnew = 1.0,                       !- Program Line 54
  # ELSE,                                   !- Program Line 55
  # SET Hfgadp = @HfgAirFnWTdb Wadp Tadp,   !- Program Line 56
  # SET qlat = WTmp-Wout,                   !- Program Line 57
  # SET qlat = Hfgadp*qlat,                 !- Program Line 58
  # SET SHRnew = 1.0-qlat/(Hin-Hout),       !- Program Line 59
  # ENDIF,                                  !- Program Line 60
  # SET SHRnewNCCoilCoolingDXSingleSpeed1 = SHRnew; !- Program Line 61
end
