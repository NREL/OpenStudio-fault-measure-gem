# This ruby script creates EnergyPlus Objects to simulate refrigerant-sidefaults
# faults in Coil:Cooling:DX:SingleSpeed objects

def faultintensity_adjustmentfactor(string_objects, time_constant, time_step, start_month, start_date, start_time, end_month, end_date, end_time, oacontrollername)

    #append transient fault adjustment factor
    string_objects << "
      EnergyManagementSystem:Program,
        AF_P_#{$faulttype}_#{oacontrollername},                    !- Name
        SET SM = #{start_month},              !- Program Line 1
        SET SD = #{start_date},              !- Program Line 2
        SET ST = #{start_time},             
        SET EM = #{end_month},              
        SET ED = #{end_date},             
        SET ET = #{end_time},             
        SET tau = #{time_constant},         
        SET dt = #{time_step},          
        IF tau == 0,
        SET tau = 0.001,
        ENDIF,
        SET ut_start = SM*10000 + SD*100 + ST,
        SET ut_end = EM*10000 + ED*100 + ET,
        SET ut_actual = Month*10000 + DayOfMonth*100 + CurrentTime,
        IF (ut_actual>=ut_start) && (ut_actual<=ut_end),  
        SET AF_previous = @TrendValue AF_trend_#{$faulttype}_#{oacontrollername} 1,  	
        SET AF_current_#{$faulttype}_#{oacontrollername} = AF_previous + dt/tau,  
        IF AF_current_#{$faulttype}_#{oacontrollername}>1.0,      
        SET AF_current_#{$faulttype}_#{oacontrollername} = 1.0,    
        ENDIF,                   
        IF AF_previous>=1.0,    
        SET AF_current_#{$faulttype}_#{oacontrollername} = 1.0,   
        ENDIF,                  
        ELSE,                   
        SET AF_previous = 0.0,  
        SET AF_current_#{$faulttype}_#{oacontrollername} = 0.0,  
        ENDIF;                  
    "
    string_objects << "
      EnergyManagementSystem:GlobalVariable,				
        AF_current_#{$faulttype}_#{oacontrollername};              !- Erl Variable 1 Name
    "
          
    string_objects << "
      EnergyManagementSystem:TrendVariable,				
        AF_Trend_#{$faulttype}_#{oacontrollername},                !- Name
        AF_current_#{$faulttype}_#{oacontrollername},              !- EMS Variable Name
        1;                       !- Number of Timesteps to be Logged
    "
        
    string_objects << "
    EnergyManagementSystem:ProgramCallingManager,
        AF_PCM_#{$faulttype}_#{oacontrollername},                  !- Name
        AfterPredictorAfterHVACManagers,  !- EnergyPlus Model Calling Point
        AF_P_#{$faulttype}_#{oacontrollername};                    !- Program Name 1
    "
    
    return string_objects
    
  end