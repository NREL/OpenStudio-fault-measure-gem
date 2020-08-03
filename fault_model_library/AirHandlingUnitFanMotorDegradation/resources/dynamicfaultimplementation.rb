# This ruby script creates EnergyPlus Objects to simulate refrigerant-sidefaults
# faults in Coil:Cooling:DX:SingleSpeed objects

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