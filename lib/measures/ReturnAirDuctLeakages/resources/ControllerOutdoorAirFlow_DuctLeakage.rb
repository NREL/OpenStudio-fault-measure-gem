#This Ruby script creates the main body of the EMS program that
#calculates the outdoor air mass flow rate because of a duct leakage

#This script is used by EnergyPlus Measure script

require_relative 'misc_eplus_func'

def faultintensity_adjustmentfactor(string_objects, time_constant, time_step, start_month, start_date, start_time, end_month, end_date, end_time, oacontrollername)

  #append transient fault adjustment factor
  ##################################################
  string_objects << "
    EnergyManagementSystem:Program,
      AF_P_#{$faulttype}_#{oacontrollername},                    !- Name
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
      SET AF_previous = @TrendValue AF_trend_#{$faulttype}_#{oacontrollername} 1,  !- A64			
      SET AF_current_#{$faulttype}_#{oacontrollername} = AF_previous + dt/tau,  !- A65			
      IF AF_current_#{$faulttype}_#{oacontrollername}>1.0,       !- A66
      SET AF_current_#{$faulttype}_#{oacontrollername} = 1.0,    !- A67
      ENDIF,                   !- A68
      IF AF_previous>=1.0,     !- A69
      SET AF_current_#{$faulttype}_#{oacontrollername} = 1.0,    !- A70
      ENDIF,                   !- A71
      ELSE,                    !- A72
      SET AF_previous = 0.0,   !- A73
      SET AF_current_#{$faulttype}_#{oacontrollername} = 0.0,    !- A74
      ENDIF;                   !- A75
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
  ##################################################
  
  return string_objects
  
end

def econ_ductleakage_ems_main_body(workspace, controlleroutdoorair, leak_ratio, oacontrollername)

  #workspace is the Workspace object in EnergyPlus Measure script
  #controlleroutdoorair is a workspace object representing the chose controller outdorrair object
  
  #create the program
  econ_choice = controlleroutdoorair.getString(0).to_s
  econ_short_name = name_cut(econ_choice)
  if leak_ratio >= 0.00
    leakratio = "#{leak_ratio}"
  else
    leakratio = "-#{leak_ratio}"
  end
  main_body = "
    EnergyManagementSystem:Program,
      t_bias"+name_cut(econ_choice)+"_#{$faulttype}, !- Name
      SET DELTASMALL = 0.00001, !- Program Line 1
      SET SMALLMASSFLOW = 0.001, !- Program Line 2
      SET SMALLVOLFLOW = 0.001, !- Program Line 3
      SET HIGHHUMCTRL = False, !- <none>
      SET NIGHTVENT = False, !- <none>
      SET ECON_OP = True, !- <none>
      SET MIX_FLOW_GB#{econ_short_name}_#{$faulttype} = "+name_cut(econ_choice)+"MixAirFlow_CTRL_#{$faulttype}, !- <none>
      IF MIX_FLOW_GB#{econ_short_name}_#{$faulttype} < SMALLMASSFLOW, !- Check if the duct has airflow
      SET FinalFlow = 0.00, !- <none>
      RETURN, !- <none>
      ENDIF, !- <none>
  "

  main_body = main_body+"
    SET RETTmp = "+name_cut(econ_choice)+"RETTemp1_#{$faulttype}, !- <none>
    SET RETHumRat = "+name_cut(econ_choice)+"RETOmega1_#{$faulttype}, !- <none>
    SET OATmp = "+name_cut(econ_choice)+"OATTemp1_#{$faulttype}, !- <none>
    SET OAHumRat = "+name_cut(econ_choice)+"OATOmega1_#{$faulttype}, !- <none>
    SET PTmp = "+name_cut(econ_choice)+"RETPressure1_#{$faulttype}, !- <none>
    IF PTmp < DELTASMALL, !- <none>
    SET PTmp = 101325.0, !- Zero pressure during warmup may crash the code
    ENDIF, !- <none>
    SET RETRH = @RhFnTdbWPb RETTmp RETHumRat PTmp, !- <none>
    SET ORI_RETENTH = @HFnTdbRhPb RETTmp RETRH PTmp, !- <none>
    SET ORI_RETHumRat = RETHumRat, !- <none>
    SET ORI_OAENTH = @HFnTdbW OATmp OAHumRat, !- <none>
    SET ORI_OAHumRat = OAHumRat, !- <none>
    SET RETENTH = @HFnTdbRhPb RETTmp RETRH PTmp, !- <none>
    SET RETHumRat = @WFnTdbH RETTmp RETENTH, !- Recalculate humidity ratio after the offset
    SET RETRHO = @RhoAirFnPbTdbW PTmp RETTmp RETHumRat, !- Calculate density before offsetting because density is not used by the controller
    SET OARH = @RhFnTdbWPb OATmp OAHumRat PTmp, !- <none>
    SET OAENTH = @HFnTdbRhPb OATmp OARH PTmp, !- <none>
    SET OAHumRat = @WFnTdbH OATmp OAENTH, !- Recalculate humidity ratio after the offset
  "
	
  main_body = main_body+"
      SET VDOT_DES = DesAirflow"+name_cut(econ_choice)+"_#{$faulttype}, !- <none>
      SET CMDOT_D = CMDesAirflow"+name_cut(econ_choice)+"_#{$faulttype}, !- <none>
      SET HMDOT_D = HMDesAirflow"+name_cut(econ_choice)+"_#{$faulttype}, !- <none>
      SET MDOT_DES = @Max CMDOT_D HMDOT_D, !- <none>
      SET MDOT_OA_MIN = MinOAMdot"+name_cut(econ_choice)+"_#{$faulttype}, !- <none>
      SET MDOT_OA_MAX = MaxOAMdot"+name_cut(econ_choice)+"_#{$faulttype}, !- <none>
      IF VDOT_DES > SMALLVOLFLOW, !- <none>
      SET MIN_FRAC = MDOT_OA_MIN/MDOT_DES, !- no if statement for airloop existence because the code won't work without an airloop
      SET MIN_FLOW = MDOT_OA_MIN, !- <none>
      ELSE, !- <none>
      SET MIN_FRAC = 0.0, !- <none>
      SET MIN_FLOW = 0.0, !- <none>
      ENDIF, !- <none>
  "
  
  if not controlleroutdoorair.getString(16).to_s.eql?("")  #Minimum Outdoor Air Schedule Name
    main_body = main_body+"
      SET MIN_SCH_VALUE = "+name_cut(econ_choice)+"_MIN_SCH_#{$faulttype}, !- <none>
      SET MIN_SCH_VALUE = @MAX MIN_SCH_VALUE 0.00, !- <none>
      SET MIN_SCH_VALUE = @MIN MIN_SCH_VALUE 1.00, !- <none>
      SET MIN_FRAC = MIN_SCH_VALUE*MIN_FRAC, !- <none>
    "
  else
    main_body = main_body+"
      SET MIN_SCH_VALUE = 1.0, !- <none>
    "
  end
  
  #do the Controller:MechanicalVentilation object calculation
  if not controlleroutdoorair.getString(19).to_s.eql?("")
    controllermechventilations = workspace.getObjectsByType("Controller:MechanicalVentilation".to_IddObjectType)
    outdoorairspecs = workspace.getObjectsByType("DesignSpecification:OutdoorAir".to_IddObjectType)
	#####################################################
	peoples = workspace.getObjectsByType("People".to_IddObjectType)
	#####################################################
    controllermechventilations.each do |controllermechventilation|
      if controllermechventilation.getString(0).to_s.eql?(controlleroutdoorair.getString(19).to_s)
        vent_num_zone = (controllermechventilation.numFields-5)/3
        main_body = main_body+"
          SET OA_MECH = 0.00, !- <none>
        "
        for i in 0..vent_num_zone-1  #for each zone
          outdoorairspecs.each do |outdoorairspec|
            if controllermechventilation.getString(4+3*i+2).to_s.eql?(outdoorairspec.getString(0).to_s)
              # zone_name = name_cut(outdoorairspec.getString(0).to_s)
              zone_name = name_cut(controllermechventilation.getString(4+3*i+1).to_s)
              if outdoorairspec.numFields == 7  #multiply the number with a schedule
                main_body = main_body+"
                  SET MECH_SCH = "+zone_name+"_OA_SCH_#{$faulttype}, !- NEED A SENSOR FOR THE SCHEDULE
                "
              else
                main_body = main_body+"
                  SET MECH_SCH = 1.0, !- No schedule
                "              
              end
              if outdoorairspec.getString(1).to_s.eql?("Sum") #add code for summation
                main_body = main_body+"
                  SET ZONE_VOL = "+zone_name+"_VOL_#{$faulttype}, !- NEED INTERNAL VARIABLE FOR ZONE VOLUME
                  SET ZONE_MUL = "+zone_name+"_MUL_#{$faulttype}, !- NEED INTERNAL VARIABLE FOR ZONE MULTIPLIER
                  SET ZONE_LIST_MUL = "+zone_name+"_LIST_MUL_#{$faulttype}, !- NEED INTERNAL VARIABLE FOR ZONE LIST MULTIPLIER
                "
				#####################################################
				if peoples.empty?
				  main_body = main_body+"
                    SET ZONE_PPL = 0, !- <none>
				  "
				else
				  peoples.each do |people|
			        if people.getString(1).to_s.eql?(controllermechventilation.getString(4+3*i+1).to_s)
				      main_body = main_body+"
                        SET ZONE_PPL = "+zone_name+"_PEOPLE#{bias_sensor}_T_#{$faulttype}, !- NEED SENSOR FOR ZONE People Occupant Count
				      "
				    else
				      main_body = main_body+"
                        SET ZONE_PPL = 0, !- <none>
				      "
				    end
				  end
			    end
				#####################################################
				main_body = main_body+"
                  SET IND_OA = #{outdoorairspec.getString(2).to_s}, !- Zone occupant flow rate
                  SET IND_OA = IND_OA*ZONE_MUL*ZONE_LIST_MUL*ZONE_PPL, !- <none>
                  SET OA_MECH = OA_MECH+IND_OA*MECH_SCH, !- <none>
                  SET ZONE_AREA = "+zone_name+"_AREA_#{$faulttype}, !- NEED INTERNAL VARIABLE FOR ZONE FLOOR AREA
                  SET IND_OA = "+outdoorairspec.getString(3).to_s+"*ZONE_AREA, !- Zone floor area flow rate
                  SET IND_OA = IND_OA*ZONE_MUL*ZONE_LIST_MUL, !- <none>
                  SET OA_MECH = OA_MECH+IND_OA*MECH_SCH, !- <none>
                  SET IND_OA = "+outdoorairspec.getString(4).to_s+", !- Zone volume flow rate
                  SET IND_OA = IND_OA*ZONE_MUL*ZONE_LIST_MUL, !- <none>
                  SET OA_MECH = OA_MECH+IND_OA*MECH_SCH, !- <none>
                  SET IND_OA = "+outdoorairspec.getString(5).to_s+"*ZONE_VOL, !- Zone air change flow rate
                  SET IND_OA = IND_OA*ZONE_MUL*ZONE_LIST_MUL, !- <none>
                  SET OA_MECH = OA_MECH+IND_OA*MECH_SCH, !- <none>
                "
              else #add code for maximum
                main_body = main_body+"
                  SET IND_OA_FIN = 0.0, !- For maximum calculation
                  SET ZONE_VOL = "+zone_name+"_VOL_#{$faulttype}, !- NEED INTERNAL VARIABLE FOR ZONE VOLUME
                  SET ZONE_MUL = "+zone_name+"_MUL_#{$faulttype}, !- NEED INTERNAL VARIABLE FOR ZONE MULTIPLIER
                  SET ZONE_LIST_MUL = "+zone_name+"_LIST_MUL_#{$faulttype}, !- NEED INTERNAL VARIABLE FOR ZONE LIST MULTIPLIER
                  SET ZONE_PPL = "+zone_name+"_PEOPLE_#{$faulttype}, !- NEED SENSOR FOR ZONE People Occupant Count
                  SET IND_OA = #{outdoorairspec.getString(2).to_s}, !- Zone occupant flow rate
                  SET IND_OA = IND_OA*ZONE_MUL*ZONE_LIST_MUL*ZONE_PPL, !- <none>
                  SET IND_OA_FIN = @Max IND_OA_FIN IND_OA, !- <none>
                  SET ZONE_AREA = "+zone_name+"_AREA_#{$faulttype}, !- NEED INTERNAL VARIABLE FOR ZONE FLOOR AREA
                  SET IND_OA = "+outdoorairspec.getString(3).to_s+"*ZONE_AREA, !- Zone floor area flow rate
                  SET IND_OA = IND_OA*ZONE_MUL*ZONE_LIST_MUL, !- <none>
                  SET IND_OA_FIN = @Max IND_OA_FIN IND_OA, !- <none>
                  SET IND_OA = "+outdoorairspec.getString(4).to_s+", !- Zone volume flow rate
                  SET IND_OA = IND_OA*ZONE_MUL*ZONE_LIST_MUL, !- <none>
                  SET IND_OA_FIN = @Max IND_OA_FIN IND_OA, !- <none>
                  SET IND_OA = "+outdoorairspec.getString(5).to_s+"*ZONE_VOL, !- Zone air change flow rate
                  SET IND_OA = IND_OA*ZONE_MUL*ZONE_LIST_MUL, !- <none>
                  SET IND_OA_FIN = @Max IND_OA_FIN IND_OA, !- <none>
                  SET OA_MECH = OA_MECH+IND_OA_FIN*MECH_SCH, !- <none>
                "
              end
            end
            #DesignSpecification:ZoneAirDistribution is only used by ProportionalControl mode that is not used in OpenStudio. Skipping......
          end
        end
        #calculate which outdoor flow fraction should be used
        main_body = main_body+"
          SET OA_MECH = OA_MECH*1.204, !- Multiply with standard air density
          SET MECH_MIN_FRAC = OA_MECH/MDOT_DES, !- Calculate the minimum fraction, need Fan PLR adjustment if possible
          SET MIN_FRAC = @Max MECH_MIN_FRAC MIN_FRAC, !- <none>
        "
      end
    end
  end
  
  main_body = main_body+"
    SET MIN_FRAC = @Max MIN_FRAC 0.0, !- <none>
    SET MIN_FRAC = @Min MIN_FRAC 1.0, !- <none>
    SET MIN_FLOW = MIN_FRAC*MDOT_DES, !- <none>
    SET TDiff = RETTmp-OATmp, !- <none>
    SET TDiff = @Abs TDiff, !- <none>
    IF TDiff > DELTASMALL, !- <none>
    SET OA_SIGN = (RETTmp-"+name_cut(econ_choice)+"MASetPoint1_#{$faulttype})/(RETTmp-OATmp), !- Initialize the signal
    ELSE, !- <none>
    IF RETTmp < "+name_cut(econ_choice)+"MASetPoint1_#{$faulttype} && RETTmp >= OATmp, !- <none>
    SET OA_SIGN = -1, !- <none>
    ELSEIF RETTmp < "+name_cut(econ_choice)+"MASetPoint1_#{$faulttype} && RETTmp < OATmp, !- <none>
    SET OA_SIGN = 1, !- <none>
    ELSEIF RETTmp >= "+name_cut(econ_choice)+"MASetPoint1_#{$faulttype} && RETTmp >= OATmp,
    SET OA_SIGN = 1, !- <none>
    ELSEIF RETTmp >= "+name_cut(econ_choice)+"MASetPoint1_#{$faulttype} && RETTmp < OATmp,
    SET OA_SIGN = -1, !- <none>
    ENDIF, !- <none>
    ENDIF, !- <none>
    SET OA_SIGN = @Max OA_SIGN MIN_FRAC, !- <none>
    SET OA_SIGN = @Min OA_SIGN 1.0, !- <none>
    SET ECON_FLOW_SCH_VAL = 0.0, !- <none>
  "
  
    
  if controlleroutdoorair.getString(7).to_s.eql?("NoEconomizer")
    main_body = main_body+"
      SET OA_SIGN = MIN_FRAC, !- No Economizer Case
      SET ECON_OP = False, !- <none>
      SET HIGHHUMCTRL = False, !- <none>
    "
  else
    if not controlleroutdoorair.getString(14).to_s.eql?("NoLockout") and not controlleroutdoorair.getString(14).to_s.eql?("")
      #check lockout type and calculation to see if the economizer is locked out
      main_body = main_body+"
        SET NO_LOCK_OUT = True, !- <none>
      "
      if controlleroutdoorair.getString(14).to_s.eql?("LockoutWithHeating") or controlleroutdoorair.getString(14).to_s.eql?("LockoutWithCompressor")
        #find the branch containing the economizer to see what objects are inside the airloop
        #need to find the air system for this and change to a unique variable name
        airsystem_name = ""
        sizing_option = "Noncoincident"  #default
        controllerlists = workspace.getObjectsByType("AirLoopHVAC:ControllerList".to_IddObjectType)
        controllerlists.each do |controllerlist|
          num_field = controllerlist.numFields
          for i in 0..num_field-1
            if controllerlist.getString(i).to_s.eql?(econ_choice)
              oas_name = controllerlist.getString(0).to_s.gsub(" Controller List","")
              branchs = workspace.getObjectsByType("Branch".to_IddObjectType)
              branchs.each do |branch|
                num_field2 = branch.numFields
                for ii in 0..num_field2-1
                  if branch.getString(ii).to_s.eql?(oas_name)
                    airsystem_name = branch.getString(0).to_s.gsub(" Supply Branch","").gsub(" Main Branch","")
                    main_body = main_body+"
                      SET LOCKOUT_POS = "+name_cut(airsystem_name)+"_Htg, !- <none>
                      IF LOCKOUT_POS > 0, !- <none>
                      SET NO_LOCK_OUT = False, !- <none>
                      ENDIF, !- <none>
                    "
                    if controlleroutdoorair.getString(14).to_s.eql?("LockoutWithCompressor")
                      #check if there is a compressor on the loop
                      #if there is, add code to check if the economizer should be locked out
                      main_body = main_body+"
                        SET LOCKOUT_POS = "+name_cut(airsystem_name)+"_Ctg, !- <none>
                        IF LOCKOUT_POS > 0, !- <none>
                        SET NO_LOCK_OUT = False, !- <none>
                        ENDIF, !- <none>
                      "
                    end
                  end
                end
              end
            end
          end
        end
      end
    else
      main_body = main_body+"
        SET NO_LOCK_OUT = True, !- <none>
      "
    end
    main_body = main_body+"
      IF NO_LOCK_OUT, !- No lockout mode
      IF MDOT_OA_MAX < SMALLMASSFLOW, !- <none>
      SET OA_SIGN = MIN_FRAC, !- <none>
      SET ECON_OP = False, !- <none>
      SET HIGHHUMCTRL = False, !- <none>
      ELSE, !- Running the economizer
      SET ECON_OP = True, !- <none>
      IF OATmp > "+name_cut(econ_choice)+"MASetPoint1_#{$faulttype}, !- <none>
      SET OA_SIGN = 1, !- <none>
      ENDIF, !- <none>
    "
    if controlleroutdoorair.getString(7).to_s.eql?("DifferentialDryBulb")
      main_body = main_body+"
        IF OATmp > RETTmp, !- DifferentialDryBulb
        SET OA_SIGN = MIN_FRAC, !- <none>
        SET ECON_OP = False, !- <none>
        ENDIF, !- <none>
      "
      main_body = main_body+check_setpoints(workspace, controlleroutdoorair)
    end
    if controlleroutdoorair.getString(7).to_s.eql?("FixedDryBulb") or controlleroutdoorair.getString(7).to_s.eql?("FixedEnthalpy") or controlleroutdoorair.getString(7).to_s.eql?("FixedDewPointAndDryBulb") or controlleroutdoorair.getString(7).to_s.eql?("ElectronicEnthalpy")
      main_body = main_body+check_setpoints(workspace, controlleroutdoorair)
    end
    if controlleroutdoorair.getString(7).to_s.eql?("DifferentialDryBulbAndEnthalpy")
      main_body = main_body+"
        IF OATmp > RETTmp, !- DifferentialDryBulb
        SET OA_SIGN = MIN_FRAC, !- <none>
        SET ECON_OP = False, !- <none>
        ENDIF, !- <none>
        IF OAENTH > RETENTH, !- DifferentialEnthalpy
        SET OA_SIGN = MIN_FRAC, !- <none>
        SET ECON_OP = False, !- <none>
        ENDIF, !- <none>
      "
      main_body = main_body+check_setpoints(workspace, controlleroutdoorair)
    end
    if controlleroutdoorair.getString(7).to_s.eql?("DifferentialEnthalpy")
      main_body = main_body+"
        IF OAENTH > RETENTH, !- DifferentialEnthalpy
        SET OA_SIGN = MIN_FRAC, !- <none>
        SET ECON_OP = False, !- <none>
        ENDIF, !- <none>
      "
      main_body = main_body+check_setpoints(workspace, controlleroutdoorair)
    end
    ###############################################################
    # modified "OATmp < #{controlleroutdoorair.getDouble(13).to_f}" from "OATmp-#{controlleroutdoorair.getDouble(13).to_f} < 0.0"
    ###############################################################
    if not controlleroutdoorair.getString(13).to_s.eql?("")  #Minimum dry-bulb limit
      main_body = main_body+"
        IF OATmp < #{controlleroutdoorair.getDouble(13).to_f}, !- Minimum dry-bulb limit
        SET OA_SIGN = MIN_FRAC, !- <none>
        SET ECON_OP = False, !- <none>
        ENDIF, !- <none>
      "
    end
    if controlleroutdoorair.getString(21).to_s.eql?("Yes")  #High humidity control check
      main_body = main_body+"
        IF ZoneHumidLOAD"+name_cut(econ_choice)+"_#{$faulttype} < 0.0, !- High Humidity Control
        SET HIGHHUMCTRL = True, !- <none>
        ENDIF, !- <none>
      "
      if controlleroutdoorair.getString(24).to_s.eql?("Yes")  #Control High Indoor Humidity Based on Outdoor Humidity Ratio
        main_body = main_body+"
          IF ZoneHumid"+name_cut(econ_choice)+"_#{$faulttype} <= OAHumRat, !- Control High Indoor Humidity Based on Outdoor Humidity Ratio
          SET HIGHHUMCTRL = False, !- Set it back to False
          ENDIF, !- <none>
        "
      end
    end
    if not controlleroutdoorair.getString(20).to_s.eql?("")  #Time of Day Economizer Control Schedule Name
      main_body = main_body+"
        SET ECON_FLOW_SCH_VAL = ECONCTRL"+name_cut(econ_choice)+"_SCH_#{$faulttype}, !- <none>
        IF ECON_FLOW_SCH_VAL > 0, !- <none>
        SET OA_SIGN = 1.0, !- <none>
        SET ECON_OP = True, !- <none>
        ENDIF,
      "
    end
    #ending the if statement for running the economizer
    main_body = main_body+"
      ENDIF, !- End Running the economizer statement
      ELSE, !- Lockout
      SET OA_SIGN = MIN_FRAC, !- add code to run no lockout case
      SET ECON_OP = False, !- <none>
      SET HIGHHUMCTRL = False, !- <none>
      ENDIF, !- End lockout if-statement
    "
  end
  
  #check if any served zone is controlled under night ventilation
  #TO BE ADDED LATER
  #SET IT TO FALSE FOR NOW
  main_body = main_body+"
    SET NIGHTVENT = False, !- <none>
  "
  
  #calculate the correct outdoor airflow
  main_body = main_body+"
    IF NIGHTVENT == 0,
    IF OA_SIGN > MIN_FRAC,
    IF OA_SIGN < 1.0,
    IF MIX_FLOW_GB#{econ_short_name}_#{$faulttype} > SMALLMASSFLOW, !- Check if the duct has airflow
    SET RETENTH_GB#{econ_short_name}_#{$faulttype} = ORI_RETENTH, !- to simulate feedback control, don't use measurement values
    SET RETHUMRAT_GB#{econ_short_name}_#{$faulttype} = ORI_RETHumRat, !- to simulate feedback control, don't use measurement values
    SET OAENTH_GB#{econ_short_name}_#{$faulttype} = ORI_OAENTH, !- to simulate feedback control, don't use measurement values
    SET OAHUMRAT_GB#{econ_short_name}_#{$faulttype} = ORI_OAHumRat, !- to simulate feedback control, don't use measurement values
    SET LOWLIMIT_GB#{econ_short_name}_#{$faulttype} = MIN_FRAC, !- <none>
    SET UPLIMIT_GB#{econ_short_name}_#{$faulttype} = 1, !- <none>
    SET MIXTEMPSET_GB#{econ_short_name}_#{$faulttype} = "+name_cut(econ_choice)+"MASetPoint1_#{$faulttype}, !-<none>
    RUN EMSSolveRegulaFalsi_OA_SIGN#{econ_short_name}_#{$faulttype}, !- <none>
    IF FLAG_GB#{econ_short_name}_#{$faulttype} > 0, !- <none>
    SET OA_SIGN = SOLN_GB#{econ_short_name}_#{$faulttype}, !- <none>
    ENDIF,
    ENDIF,
    ENDIF,
    ENDIF,
    ENDIF,
  "
  
  if controlleroutdoorair.getString(8).to_s.eql?("MinimumFlowWithBypass")  #Bypass effect
    main_body = main_body+"
      IF ECON_FLOW_SCH_VAL == 0.0, !- Bypass control
      SET OA_SIGN = MIN_FRAC
      ENDIF, !- <none>
    "
  end
  
  #humidity control calculation
  if controlleroutdoorair.getString(21).to_s.eql?("Yes")  #High humidity control check
    main_body = main_body+"
      IF HIGHHUMCTRL == True, !- high humidity control
      SET MIX_FLOW_GB#{econ_short_name}_#{$faulttype} = "+name_cut(econ_choice)+"MixAirFlow_CTRL_#{$faulttype}, !- <none>
      SET OA_SIGN_CAN = "+controlleroutdoorair.getString(23).to_s+", !- <none>
      SET OA_SIGN_CAN = OA_SIGN_CAN*MDOT_OA_MAX, !- <none>
      SET OA_SIGN_CAN = OA_SIGN_CAN/MIX_FLOW_GB#{econ_short_name}_#{$faulttype}, !- <none>
      SET OA_SIGN = @MAX OA_SIGN_CAN MIN_FRAC, !- <none>
      ENDIF,
    "
  end
  
  #night ventilation control
  main_body = main_body+"
    IF NIGHTVENT == True, !- <none>
    SET OA_SIGN = 1, !- <none>
    ENDIF,
  "
  
  main_body = main_body+"
    SET VDOT_OA_MIN = MDOT_OA_MIN/RETRHO, !- <none>
    IF VDOT_OA_MIN < 0.001,
    SET OA_SIGN_INIT = MIN_FRAC,
    SET ECON_OP = False, !- <none>
    ENDIF,
  "
  
  if not controlleroutdoorair.getString(17).to_s.eql?("")  #Minimum Fraction of Outdoor Air Schedule Name
    main_body = main_body+"
      SET MIN_SCH_VALUE = "+name_cut(econ_choice)+"_MIN_FRAC_SCH_#{$faulttype}, !- <none>
      SET MIN_SCH_VALUE = @Max MIN_SCH_VALUE 0.0, !- <none>
      SET MIN_SCH_VALUE = @Min MIN_SCH_VALUE 1.0, !- <none>
      IF MIN_SCH_VALUE > MIN_FRAC, !- <none>
      SET MIN_FRAC = MIN_SCH_VALUE, !- <none>
      SET MDOT_OA_MIN = MIN_FRAC*MIX_FLOW_GB#{econ_short_name}_#{$faulttype}, !- <none>
      ENDIF, !- <none>
      SET OA_SIGN = @Max OA_SIGN MIN_FRAC, !- <none>
    "
  end
  
  if not controlleroutdoorair.getString(18).to_s.eql?("")  #Maximum Fraction of Outdoor Air Schedule Name
    main_body = main_body+"
      SET MAX_SCH_VALUE = "+name_cut(econ_choice)+"_MAX_FRAC_SCH_#{$faulttype}, !- <none>
      SET MAX_SCH_VALUE = @Max MAX_SCH_VALUE 0.0, !- <none>
      SET MAX_SCH_VALUE = @Min MAX_SCH_VALUE 1.0, !- <none>
      IF MIN_FRAC > MAX_SCH_VALUE, !- <none>
      SET MIN_FRAC = MAX_SCH_VALUE, !- <none>
      SET MDOT_OA_MIN = MIN_FRAC*MIX_FLOW_GB#{econ_short_name}_#{$faulttype}, !- <none>
      ENDIF, !- <none>
      SET OA_SIGN = @Min OA_SIGN MAX_SCH_VALUE, !- <none>
    "
  end
  
  #calculate the outdoor airflow rate
  main_body = main_body+"
    SET FinalFlow = OA_SIGN*MIX_FLOW_GB#{econ_short_name}_#{$faulttype}, !- <none>
  "
  
  #make sure that it doesn't exceed the limits of ventilation
  if not controlleroutdoorair.getString(19).to_s.eql?("")
    main_body = main_body+"
      IF OA_MECH > FinalFlow, !- <none>
      SET FinalFlow = @Min OA_MECH MIX_FLOW_GB#{econ_short_name}_#{$faulttype}, !- <none>
      ENDIF, !- <none>
    "
  end
  
  #igore exhaust
  
  #check minimum at user input
  if controlleroutdoorair.getString(15).to_s.eql?("FixedMinimum")
    main_body = main_body+"
      SET OA_NEW = FinalFlow, !- <none>
      SET DUMMY = MinOAMdot"+name_cut(econ_choice)+", !- Name too long
      SET OA_NEW = @Max OA_NEW (DUMMY*MIN_SCH_VALUE), !- <none>
      SET FinalFlow = OA_NEW, !- <none>
    "
  end
  
  #check with mixed airflow
  main_body = main_body+"
    SET OA_NEW = FinalFlow, !- <none>
    SET OA_NEW = @Min OA_NEW MIX_FLOW_GB#{econ_short_name}_#{$faulttype}, !- <none>
    SET FinalFlow = OA_NEW, !- <none>
  "
  
  #check if the outdoorairflow exceeds the maximum
  main_body = main_body+"
    IF HIGHHUMCTRL == True,
    SET OA_NEW = FinalFlow, !- <none>
    SET OA_SIGN_NEW = @Max 1.0 OA_SIGN, !- <none>
    SET OA_NEW = @Min MDOT_OA_MAX*OA_SIGN_NEW OA_NEW, !- <none>
    SET FinalFlow = OA_NEW, !- <none>
    ELSE,
    SET OA_NEW = FinalFlow, !- <none>
    SET OA_NEW = @Min MDOT_OA_MAX OA_NEW, !- <none>
    SET FinalFlow = OA_NEW, !- <none>
    ENDIF, !- <none>
    SET "+name_cut(econ_choice)+"MDOT_OA_#{$faulttype} = FinalFlow + ("+name_cut(econ_choice)+"MixAirFlow_CTRL_#{$faulttype} - FinalFlow)*("+leakratio+")*AF_current_#{$faulttype}_#{oacontrollername}; !- <none>
  "
  
  return main_body
  
end

# The following script appends the EMS code representing the information in function checksetpoints

def check_setpoints(workspace, controlleroutdoorair)

  main_body = ""
  
  if not controlleroutdoorair.getString(9).to_s.eql?("")  #Economizer Maximum Limit Dry-Bulb Temperature
    main_body = main_body+"
      IF OATmp-#{controlleroutdoorair.getDouble(9).to_f}>0, !- Maximum Fixed dry bulb check
      SET OA_SIGN = MIN_FRAC, !- <none>
      SET ECON_OP = False, !- <none>
      ENDIF, !- <none>
    "
  end
  
  if not controlleroutdoorair.getString(10).to_s.eql?("")  #Economizer Maximum Limit Enthalpy
    main_body = main_body+"
      IF OAENTH-#{controlleroutdoorair.getDouble(10).to_f}>0, !- Maximum Fixed enthalpy
      SET OA_SIGN = MIN_FRAC, !- <none>
      SET ECON_OP = False, !- <none>
      ENDIF, !- <none>
    "
  end
  
  if not controlleroutdoorair.getString(11).to_s.eql?("")  #Economizer Maximum Limit Dewpoint Temperature
    main_body = main_body+"
      SET OATdew = @TdpFnWPb OAHumRat PTmp
      IF OATdew-#{controlleroutdoorair.getDouble(11).to_f}>0, !- Economizer Maximum Limit Dewpoint Temperature
      SET OA_SIGN = MIN_FRAC, !- <none>
      SET ECON_OP = False, !- <none>
      ENDIF, !- <none>
    "
  end
  
  if not controlleroutdoorair.getString(12).to_s.eql?("")  #Electronic enthalpy limit
    #find the curve
    curve_name = controlleroutdoorair.getString(12).to_s
    
    para = []
    limit = []
    curve_found = false
    curvequadratics = workspace.getObjectsByType("Curve:Quadratic".to_IddObjectType)
    curvequadratics.each do |curvequadratic|
      if curvequadratic.getString(0).to_s.eql?("curve_name")
        for i in 1..3
          para << curvequadratic.getString(i).to_s
        end
        para << "0"
        limit << curvequadratic.getString(4).to_s
        limit << curvequadratic.getString(5).to_s
        curve_found = true
        break
      end
    end
    if not curve_found
      curvecubics = workspace.getObjectsByType("Curve:Cubic".to_IddObjectType)
      curvecubics.each do |curvecubic|
        if curvecubic.getString(0).to_s.eql?("curve_name")
          for i in 1..4
            para << curvecubic.getString(i).to_s
          end
          limit << curvecubic.getString(5).to_s
          limit << curvecubic.getString(6).to_s
          curve_found = true
          break
        end
      end
    end
    
    #add the code
    main_body = main_body+"
      SET OATmpCurve = OATmp, !- Electronic enthalpy
      IF OATmp > "+limit[1]+", !- <none>
      SET OATmpCurve = "+limit[1]+", !- <none>
      ELSEIF OATmp < "+limit[0]+", !- <none>
      SET OATmpCurve = "+limit[0]+", !- <none>
      ENDIF, !- <none>
      SET C1 = "+para[0]+", ! -<none>
      SET C2 = "+para[1]+", ! -<none>
      SET C3 = "+para[2]+", ! -<none>
      SET C4 = "+para[3]+", ! -<none>
      SET ENTH_LIM = C1+C2*OATmpCurve, ! -<none>
      SET ENTH_LIM = ENTH_LIM+C3*OATmpCurve*OATmpCurve, ! -<none>
      SET ENTH_LIM = ENTH_LIM+C4*OATmpCurve*OATmpCurve*OATmpCurve, ! -<none>
      IF OAENTH > ENTH_LIM,
      SET OA_SIGN = MIN_FRAC, !- <none>
      SET ECON_OP = False, !- <none>
      ENDIF, !- <none>
    "  #add limits to the curve outputs later
  end
  
  return main_body
  
end


#The following script appends the necessary EMS objects to the code to run the program

def econ_ductleakage_ems_other(string_objects, workspace, controlleroutdoorair)

  #string_objects is an array containing the program and the program caller

  #workspace is the Workspace object in EnergyPlus Measure script
  
  #controlleroutdoorair is a workspace object representing the chose controller outdorrair object
  
  econ_choice = controlleroutdoorair.getString(0).to_s
  econ_short_name = name_cut(econ_choice)
  
  string_objects << "
    EnergyManagementSystem:Subroutine,
      RES_OA_SIGN#{econ_short_name}_#{$faulttype}, !- Name
      SET TEMP_OA_SIGN = OA_SIGN_GB#{econ_short_name}_#{$faulttype}, !- <none>
      SET TEMP_MIX_FLOW = MIX_FLOW_GB#{econ_short_name}_#{$faulttype}, !- <none>
      SET TEMP_OA_FLOW = TEMP_OA_SIGN*TEMP_MIX_FLOW, !- <none>
      SET RECFLOW1 = 0, !- <none>
      SET RECFLOW2 = TEMP_MIX_FLOW-TEMP_OA_FLOW, !- <none>
      SET RECIR_FLOW = @MAX RECFLOW1 RECFLOW2, !- <none>
      SET TEMP_RETENTH = RETENTH_GB#{econ_short_name}_#{$faulttype}, !- <none>
      SET TEMP_RETHUMRAT = RETHUMRAT_GB#{econ_short_name}_#{$faulttype}, !- <none>
      SET TEMP_OAENTH = OAENTH_GB#{econ_short_name}_#{$faulttype}, !- <none>
      SET TEMP_OAHUMRAT = OAHUMRAT_GB#{econ_short_name}_#{$faulttype}, !- <none>
      SET TEMP_MIXENTH = RECIR_FLOW*TEMP_RETENTH, !- <none>
      SET TEMP_MIXENTH = TEMP_MIXENTH+TEMP_OA_FLOW*TEMP_OAENTH, !- <none>
      SET TEMP_MIXENTH = TEMP_MIXENTH/TEMP_MIX_FLOW, !- <none>
      SET TEMP_MIXHUMRAT = RECIR_FLOW*TEMP_RETHUMRAT, !- <none>
      SET TEMP_MIXHUMRAT = TEMP_MIXHUMRAT+TEMP_OA_FLOW*TEMP_OAHUMRAT, !- <none>
      SET TEMP_MIXHUMRAT = TEMP_MIXHUMRAT/TEMP_MIX_FLOW, !- <none>
      SET TEMP_MIXTEMP = @TdbFnHW TEMP_MIXENTH TEMP_MIXHUMRAT, !- <none>
      SET TEMP_AA = MIXTEMPSET_GB#{econ_short_name}_#{$faulttype}-TEMP_MIXTEMP, !- <none>
      SET RESIDUAL_GB#{econ_short_name}_#{$faulttype} = TEMP_AA; !- <none>
  "
  
  string_objects << "
    EnergyManagementSystem:Subroutine,
      EMSSolveRegulaFalsi_OA_SIGN#{econ_short_name}_#{$faulttype}, !- Name
      SET OA_SIGN_GB#{econ_short_name}_#{$faulttype} = LOWLIMIT_GB#{econ_short_name}_#{$faulttype}, !- <none>
      RUN RES_OA_SIGN#{econ_short_name}_#{$faulttype}, !- <none>
      SET Y0 = RESIDUAL_GB#{econ_short_name}_#{$faulttype}, !- <none>
      SET OA_SIGN_GB#{econ_short_name}_#{$faulttype} = UPLIMIT_GB#{econ_short_name}_#{$faulttype}, !- <none>
      RUN RES_OA_SIGN#{econ_short_name}_#{$faulttype}, !- <none>
      SET Y1 = RESIDUAL_GB#{econ_short_name}_#{$faulttype}, !- <none>
      SET PROD = Y0*Y1, !- <none>
      IF Y0*Y1 > 0, !- <none>
      SET FLAG_GB#{econ_short_name}_#{$faulttype} = -2, !- <none>
      SET SOLN_GB#{econ_short_name}_#{$faulttype} = LOWLIMIT_GB#{econ_short_name}_#{$faulttype}, !- <none>
      RETURN, ! Error for solution
      ENDIF, !- <none>
      SET CONT = 1, !- <none>
      SET CONV = 0, !- <none>
      SET NITE = 0, !- <none>
      SET NITEMAX = 500, !- <none>
      WHILE CONT > 0, !- Start calculation
      SET DY = Y0-Y1, !- <none>
      IF DY < 1.d-10, !- <none>
      IF DY+1.d-10 > 0.0, !- <none>
      SET DY = 1.d-10, !- <none>
      ENDIF, !- <none>
      ENDIF, !- <none>
      SET XTemp = Y0*UPLIMIT_GB#{econ_short_name}_#{$faulttype}, !- <none>
      SET XTemp = (XTemp-Y1*LOWLIMIT_GB#{econ_short_name}_#{$faulttype})/DY, !- <none>
      SET OA_SIGN_GB#{econ_short_name}_#{$faulttype} = XTemp, !- <none>
      RUN RES_OA_SIGN#{econ_short_name}_#{$faulttype}, !- <none>
      SET YTemp = RESIDUAL_GB#{econ_short_name}_#{$faulttype}, !- <none>
      SET NITE = NITE+1, !- <none>
      IF YTemp < 0.0001 && YTemp+0.0001 > 0, !- <none>
      SET CONT = 0, !- <none>
      SET CONV = 1, !- <none>
      ELSEIF NITE > NITEMAX, !- <none>
      SET CONT = 0, !- <none>
      ENDIF, !- <none>
      IF CONT > 0.0d0, !- <none>
      IF Y0 < 0.0d0, !- <none>
      IF YTemp < 0.0d0, !- <none>
      SET LOWLIMIT_GB#{econ_short_name}_#{$faulttype} = XTemp, !- <none>
      SET Y0 = YTemp, !- <none>
      ELSE, !- <none>
      SET UPLIMIT_GB#{econ_short_name}_#{$faulttype} = XTemp, !- <none>
      SET Y1 = YTemp, !- <none>
      ENDIF, !- <none>
      ELSE, !- <none>
      IF YTemp < 0.0d0, !- <none>
      SET UPLIMIT_GB#{econ_short_name}_#{$faulttype} = XTemp, !- <none>
      SET Y1 = YTemp, !- <none>
      ELSE, !- <none>
      SET LOWLIMIT_GB#{econ_short_name}_#{$faulttype} = XTemp, !- <none>
      SET Y0 = YTemp, !- <none>
      ENDIF, !- <none>
      ENDIF, !- <none>
      ENDIF, !- <none>
      ENDWHILE, !- <none>
      IF CONV == 1, !- <none>
      SET FLAG_GB#{econ_short_name}_#{$faulttype} = NITE, !- <none>
      ELSE,
      SET FLAG_GB#{econ_short_name}_#{$faulttype} = -1, !- <none>
      ENDIF, !- <none>
      SET SOLN_GB#{econ_short_name}_#{$faulttype} = XTemp; !- <none>
  "
  
  string_objects << "
    EnergyManagementSystem:ProgramCallingManager,
      EMSCallt_bias"+name_cut(econ_choice)+", !- Name
      InsideHVACSystemIterationLoop,       !- EnergyPlus Model Calling Point
      t_bias"+name_cut(econ_choice)+"_#{$faulttype}, !- Name
  "
  
  string_objects << "      
    EnergyManagementSystem:GlobalVariable,
      RESIDUAL_GB#{econ_short_name}_#{$faulttype};
  "
  
  string_objects << "      
    EnergyManagementSystem:GlobalVariable,
      LOWLIMIT_GB#{econ_short_name}_#{$faulttype};
  "
  
  string_objects << "      
    EnergyManagementSystem:GlobalVariable,
      UPLIMIT_GB#{econ_short_name}_#{$faulttype};
  "
  
  string_objects << "      
    EnergyManagementSystem:GlobalVariable,
      FLAG_GB#{econ_short_name}_#{$faulttype};
  "
  
  string_objects << "      
    EnergyManagementSystem:GlobalVariable,
      SOLN_GB#{econ_short_name}_#{$faulttype};
  "
  
  string_objects << "      
    EnergyManagementSystem:GlobalVariable,
      OA_SIGN_GB#{econ_short_name}_#{$faulttype};
  "
  
  string_objects << "      
    EnergyManagementSystem:GlobalVariable,
      MIX_FLOW_GB#{econ_short_name}_#{$faulttype};
  "
  
  string_objects << "      
    EnergyManagementSystem:GlobalVariable,
      RETENTH_GB#{econ_short_name}_#{$faulttype};
  "
  
  string_objects << "      
    EnergyManagementSystem:GlobalVariable,
      RETHUMRAT_GB#{econ_short_name}_#{$faulttype};
  "
  
  string_objects << "      
    EnergyManagementSystem:GlobalVariable,
      OAENTH_GB#{econ_short_name}_#{$faulttype};
  "
  
  string_objects << "      
    EnergyManagementSystem:GlobalVariable,
      OAHUMRAT_GB#{econ_short_name}_#{$faulttype};
  "
  
  string_objects << "      
    EnergyManagementSystem:GlobalVariable,
      MIXTEMPSET_GB#{econ_short_name}_#{$faulttype};
  "
  
  string_objects << "   
    EnergyManagementSystem:Actuator,
      "+name_cut(econ_choice)+"MDOT_OA_#{$faulttype},        !- Name
      "+econ_choice+", !- Actuated Component Unique Name
      Outdoor Air Controller,                                  !- Actuated Component Type
      Air Mass Flow Rate;                           !- Actuated Component Control Type
  "
  
  # need to find the air system for this and change to a unique variable name
  airsystem_name = ""
  sizing_option = "Noncoincident"  #default
  controllerlists = workspace.getObjectsByType("AirLoopHVAC:ControllerList".to_IddObjectType)
  controllerlists.each do |controllerlist|
    num_field = controllerlist.numFields
    for i in 0..num_field-1
      if controllerlist.getString(i).to_s.eql?(econ_choice)
        oas_name = controllerlist.getString(0).to_s.gsub(" Controller List","")
        branchs = workspace.getObjectsByType("Branch".to_IddObjectType)
        branchs.each do |branch|
          num_field2 = branch.numFields
          for ii in 0..num_field2-1
            if branch.getString(ii).to_s.eql?(oas_name)
              airsystem_name = branch.getString(0).to_s.gsub(" Supply Branch","").gsub(" Main Branch","")
              #check the sizing option
              sizingsystems = workspace.getObjectsByType("Sizing:System".to_IddObjectType)
              sizingsystems.each do |sizingsystem|
                if sizingsystem.getString(0).to_s.eql?(airsystem_name)
                  sizing_option = sizingsystem.getString(10).to_s #Either Coincident or Noncoincident
                end
              end
            end
          end
        end
      end
    end
  end
  
  string_objects << "
    EnergyManagementSystem:InternalVariable,
      DesAirflow"+name_cut(econ_choice)+"_#{$faulttype},
      "+airsystem_name+",
      Intermediate Air System Main Supply Volume Flow Rate;
  "
  
  string_objects << "
    EnergyManagementSystem:InternalVariable,
      CMDesAirflow"+name_cut(econ_choice)+"_#{$faulttype},
      "+airsystem_name+",
      Intermediate Air System "+sizing_option+" Peak Cooling Mass Flow Rate;
  "
  
  string_objects << "
    EnergyManagementSystem:InternalVariable,
      HMDesAirflow"+name_cut(econ_choice)+"_#{$faulttype},
      "+airsystem_name+",
      Intermediate Air System "+sizing_option+" Peak Heating Mass Flow Rate;
  "
  
  string_objects << "
    EnergyManagementSystem:InternalVariable,
      MinOAMdot"+name_cut(econ_choice)+"_#{$faulttype},
      "+econ_choice+",
      Outdoor Air Controller Minimum Mass Flow Rate;
  "
  
  string_objects << "
    EnergyManagementSystem:InternalVariable,
      MaxOAMdot"+name_cut(econ_choice)+"_#{$faulttype},
      "+econ_choice+",
      Outdoor Air Controller Maximum Mass Flow Rate;
  "
  
  #add zone ventilation for the controller
  if not controlleroutdoorair.getString(19).to_s.eql?("")
    controllermechventilations = workspace.getObjectsByType("Controller:MechanicalVentilation".to_IddObjectType)
    outdoorairspecs = workspace.getObjectsByType("DesignSpecification:OutdoorAir".to_IddObjectType)
	#####################################################
	peoples = workspace.getObjectsByType("People".to_IddObjectType)
	#####################################################
    controllermechventilations.each do |controllermechventilation|
      if controllermechventilation.getString(0).to_s.eql?(controlleroutdoorair.getString(19).to_s)
        vent_num_zone = (controllermechventilation.numFields-5)/3
        for i in 0..vent_num_zone-1  #for each zone
          outdoorairspecs.each do |outdoorairspec|
            
	      oaschedule_name = outdoorairspec.getString(6).to_s
            
            if controllermechventilation.getString(4+3*i+2).to_s.eql?(outdoorairspec.getString(0).to_s)
              zone_name = controllermechventilation.getString(4+3*i+1).to_s
              # zone_name_tag = name_cut(outdoorairspec.getString(0).to_s)
              zone_name_tag = name_cut(zone_name)
              string_objects << "
                EnergyManagementSystem:InternalVariable,
                  "+zone_name_tag+"_VOL_#{$faulttype},
                  "+zone_name+",
                  Zone Air Volume;
              "
              string_objects << "
                EnergyManagementSystem:InternalVariable,
                  "+zone_name_tag+"_MUL_#{$faulttype},
                  "+zone_name+",
                  Zone Multiplier;
              "
              string_objects << "
                EnergyManagementSystem:InternalVariable,
                  "+zone_name_tag+"_LIST_MUL_#{$faulttype},
                  "+zone_name+",
                  Zone List Multiplier;
              "
              string_objects << "
                EnergyManagementSystem:InternalVariable,
                  "+zone_name_tag+"_AREA_#{$faulttype},
                  "+zone_name+",
                  Zone Floor Area;
              "
              #####################################################
              peoples.each do |people|
			    if people.getString(1).to_s.eql?(zone_name)
				  people_name = people.getString(0).to_s
				  string_objects << "
                    EnergyManagementSystem:Sensor,
                    "+zone_name_tag+"_PEOPLE#{bias_sensor}_T_#{$faulttype}, !- Name
                    "+people_name+",                        !- Output:Variable or Output:Meter Index Key Name
                    Zone People Occupant Count;                !- Output:Variable or Output:Meter Name
                  "
				end
			  end
			  #####################################################
              string_objects << "
                EnergyManagementSystem:Sensor,
                  "+zone_name_tag+"_OA_SCH_#{$faulttype}, !- Name
                  "+oaschedule_name+",                        !- Output:Variable or Output:Meter Index Key Name
                  Schedule Value;                !- Output:Variable or Output:Meter Name
              "
            end
          end
        end
      end
    end
  end
  
  string_objects << "
    EnergyManagementSystem:Sensor,
      "+name_cut(airsystem_name)+"_Htg_#{$faulttype},
      "+airsystem_name+",
      Air System Heating Coil Total Heating Energy;
  "
  
  string_objects << "
    EnergyManagementSystem:Sensor,
      "+name_cut(airsystem_name)+"_Ctg_#{$faulttype},
      "+airsystem_name+",
      Air System Cooling Coil Total Cooling Energy;
  "
  
  ret_node_name = controlleroutdoorair.getString(2).to_s
  string_objects << "
    EnergyManagementSystem:Sensor,
      "+name_cut(econ_choice)+"RETTemp1_#{$faulttype},  !- Name
      "+ret_node_name+",                        !- Output:Variable or Output:Meter Index Key Name
      System Node Temperature;                !- Output:Variable or Output:Meter Name
  "
  
  string_objects << "
    EnergyManagementSystem:Sensor,
      "+name_cut(econ_choice)+"RETOmega1_#{$faulttype},  !- Name
      "+ret_node_name+",                        !- Output:Variable or Output:Meter Index Key Name
      System Node Humidity Ratio;                !- Output:Variable or Output:Meter Name
  "
  
  string_objects << "
    EnergyManagementSystem:Sensor,
      "+name_cut(econ_choice)+"RETPressure1_#{$faulttype},  !- Name
      "+ret_node_name+",                        !- Output:Variable or Output:Meter Index Key Name
      System Node Pressure;                !- Output:Variable or Output:Meter Name
  "
  
  mx_node_name = controlleroutdoorair.getString(3).to_s
  string_objects << "
    EnergyManagementSystem:Sensor,
      "+name_cut(econ_choice)+"MASetPoint1_#{$faulttype},  !- Name
      "+mx_node_name+",                        !- Output:Variable or Output:Meter Index Key Name
      System Node Setpoint Temperature;                !- Output:Variable or Output:Meter Name
  "
  
  oa_node_name = controlleroutdoorair.getString(4).to_s
  string_objects << "
    EnergyManagementSystem:Sensor,
      "+name_cut(econ_choice)+"OATTemp1_#{$faulttype},  !- Name
      "+oa_node_name+",                        !- Output:Variable or Output:Meter Index Key Name
      System Node Temperature;                !- Output:Variable or Output:Meter Name
  "
  
  string_objects << "
    EnergyManagementSystem:Sensor,
      "+name_cut(econ_choice)+"OATOmega1_#{$faulttype},  !- Name
      "+oa_node_name+",                        !- Output:Variable or Output:Meter Index Key Name
      System Node Humidity Ratio;                !- Output:Variable or Output:Meter Name
  "
  
  string_objects << "
    EnergyManagementSystem:Sensor,
      "+name_cut(econ_choice)+"MixAirFlow_CTRL_#{$faulttype},  !- Name
      "+airsystem_name+",                        !- Output:Variable or Output:Meter Index Key Name
      Air System Mixed Air Mass Flow Rate;                !- Output:Variable or Output:Meter Name
  "
  
  if controlleroutdoorair.getString(21).to_s.eql?("Yes")
    humidistat_zone = controlleroutdoorair.getString(22).to_s
    
    # check high humidity control before adding
    string_objects << "
      EnergyManagementSystem:Sensor,
        ZoneHumid"+name_cut(econ_choice)+"_#{$faulttype},  !- Name
        "+humidistat_zone+",                        !- Output:Variable or Output:Meter Index Key Name
        Zone Air Humidity Ratio;                !- Output:Variable or Output:Meter Name
    "
    
    # check high humidity control before adding
    string_objects << "
      EnergyManagementSystem:Sensor,
        ZoneHumidLOAD"+name_cut(econ_choice)+"_#{$faulttype},  !- Name
        "+humidistat_zone+",                        !- Output:Variable or Output:Meter Index Key Name
        Zone Predicted Moisture Load to Humidifying Setpoint Moisture Transfer Rate;                !- Output:Variable or Output:Meter Name
    "
  end
  
  # Time of Day Economizer Control Schedule Name
  if not controlleroutdoorair.getString(20).to_s.eql?("")
    string_objects << "
      EnergyManagementSystem:Sensor,
        ECONCTRL"+name_cut(econ_choice)+"_SCH_#{$faulttype}, !- Name
        "+controlleroutdoorair.getString(20).to_s+", !- Schedule Name
        Schedule Value; !- Output:Variable
    "
  end
  
  #night ventilation schedule; only enables if night ventilation is considered
  if false
    string_objects << "
      EnergyManagementSystem:Sensor,
        NIGHTVENT_SCH_#{$faulttype}, !- Name
        [Schedule name from Ruby], !- Schedule Name
        Schedule Value; !- Output:Variable
    "
  end
  
  # Maximum Fraction of Outdoor Air Schedule Name
  if not controlleroutdoorair.getString(18).to_s.eql?("")
    string_objects << "
      EnergyManagementSystem:Sensor,
        "+name_cut(econ_choice)+"_MAX_FRAC_SCH_#{$faulttype}, !- Name
        "+controlleroutdoorair.getString(18).to_s+", !- Schedule Name
        Schedule Value; !- Output:Variable
    "
  end
  
  # Minimum Outdoor Air Schedule Name
  if not controlleroutdoorair.getString(16).to_s.eql?("")
    string_objects << "
      EnergyManagementSystem:Sensor,
        "+name_cut(econ_choice)+"_MIN_SCH_#{$faulttype}, !- Name
        "+controlleroutdoorair.getString(16).to_s+", !- Schedule Name
        Schedule Value; !- Output:Variable
    "
  end
  
  # Minimum Fraction of Outdoor Air Schedule Name
  if not controlleroutdoorair.getString(17).to_s.eql?("")
    string_objects << "
      EnergyManagementSystem:Sensor,
        "+name_cut(econ_choice)+"_MIN_FRAC_SCH_#{$faulttype}, !- Name
        "+controlleroutdoorair.getString(17).to_s+", !- Schedule Name
        Schedule Value; !- Output:Variable
    "
  end
  
  #EMS routine to change the relative humidity record before reporting
  
  # check workspace to see if the workspace has one before adding
  outputemss = workspace.getObjectsByType("Output:EnergyManagementSystem".to_IddObjectType)
  if outputemss.size == 0
    string_objects << "
      Output:EnergyManagementSystem,
        Verbose,                                !- Actuator Availability Dictionary Reporting
        Verbose,                                !- Internal Variable Availability Dictionary Reporting
        ErrorsOnly;                                !- EMS Runtime Language Debug Output Level - when deployed, set ErrorsOnly
    "
  end
  
  return string_objects

end
