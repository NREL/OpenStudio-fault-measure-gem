# This ruby script creates EnergyPlus Objects to simulate refrigerant-sidefaults
# faults in Coil:Cooling:DX:SingleSpeed objects

require "#{File.dirname(__FILE__)}/misc_eplus_func"

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
def main_program_entry(workspace, string_objects, coil_choice, curve_name, para, model_name)
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
        SET #{$faultnow}FaultLevel = #{$faultnow}FaultDegrade#{sh_coil_choice},   !- <none>
        RUN #{$faultnow}_ADJUST_#{sh_coil_choice}_#{model_name}_#{sh_curve_name}, !- Calling subrountines that adjust the cooling capacity based on fault type
        SET FAULT_ADJ_RATIO = #{$faultnow}_FAULT_ADJ_RATIO*FAULT_ADJ_RATIO,     !- <none>
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
        SET #{fault_choice}_FAULT_ADJ_RATIO = 1.0,  !- <none>
    "

    # add global variables when needed
    write_global_fr = true
    ems_globalvars = workspace.getObjectsByType('EnergyManagementSystem:GlobalVariable'.to_IddObjectType)
    ems_globalvars.each do |ems_globalvar|
      if ems_globalvar.getString(0).to_s.eql?("#{fault_choice}_FAULT_ADJ_RATIO")
        write_global_fr = false
      end
    end

    if write_global_fr
      str_added = "
        EnergyManagementSystem:GlobalVariable,
          #{fault_choice}_FAULT_ADJ_RATIO;                !- Name
      "
      unless string_objects.include?(str_added)
        string_objects << str_added
      end
    end
  end

  return string_objects
end

def fault_level_sensor_sch_insert(workspace, string_objects, fault_choice = 'CA', coil_choice, sch_choice)
  # This function appends an EMS sensor to direct the fault level schedule to the EMS program.
  # If an arbitrary schedule exists before insertion, remove the old one and apply the new one.

  sch_coil_choice = coil_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
  if sch_coil_choice.eql?(nil)
    sch_coil_choice = coil_choice
  end
  sch_obj_name = "#{fault_choice}FaultDegrade#{sch_coil_choice}"

  ems_sensors = workspace.getObjectsByType('EnergyManagementSystem:Sensor'.to_IddObjectType)
  ems_sensors.each do |ems_sensor|
    if ems_sensor.getString(0).to_s.eql?(sch_obj_name)
      removed_sensors = ems_sensor.remove
      break
    end
  end

  string_objects << "
    EnergyManagementSystem:Sensor,
      #{sch_obj_name},                !- Name
      #{sch_choice},       !- Output:Variable or Output:Meter Index Key Name
      Schedule Value;    !- Output:Variable or Output:Meter Name
  "

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

  fault_level_name = "#{fault_name}FaultLevel"
  fir_name = "#{fault_name}_FAULT_ADJ_RATIO"
  
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

def ca_adjust_function(workspace, string_objects, coilcoolingdxsinglespeed, model_name, para)
  # This function creates an Energy Management System Subroutine that calculates the adjustment factor
  # for cooling capacity or EIR of Coil:Cooling:DX:SingleSpeed system that has its condenser fouled
  #
  # string_objects is an array object storing strings formatted as E+ objects. These objects
  # will be added to the E+ model at the end of the run function in the Measure script calling
  # this function
  #
  # coilcoolingdxsinglespeed is a WorkSpace object directing towards the Coil:Cooling:DX:SingleSpeed
  # to be fautled
  #
  # model_name is a string that defines what should be altered. Q for cooling capacity,
  # EIR for energy-input-ratio, etc.
  #
  # para is an array containing the coefficients for the fault model

  coil_choice = coilcoolingdxsinglespeed.getString(0).to_s
  sh_coil_choice = coil_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
  if sh_coil_choice.eql?(nil)
    sh_coil_choice = coil_choice
  end
  rated_cop = coilcoolingdxsinglespeed.getDouble(4).to_f

  fault_level_name = 'CAFaultLevel'
  fir_name = 'CA_FAULT_ADJ_RATIO'
  
  final_line = "
    EnergyManagementSystem:Subroutine,
      CH_ADJUST_#{sh_coil_choice}_#{model_name}, !- Name
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
    if subroutine.getString(0).to_s.eql?("CA_ADJUST_#{sh_coil_choice}_#{model_name}")
      workspace.removeObject(subroutine.handle)  # should have only one of them
      break
    end
  end
  string_objects << final_line

  # set up global variables, if needed
  write_global_ca_fl = true
  write_global_ca_fr = true
  ems_globalvars = workspace.getObjectsByType('EnergyManagementSystem:GlobalVariable'.to_IddObjectType)
  ems_globalvars.each do |ems_globalvar|
    if ems_globalvar.getString(0).to_s.eql?('CAFaultLevel')
      write_global_ca_fl = false
    end
    if ems_globalvar.getString(0).to_s.eql?('CA_FAULT_ADJ_RATIO')
      write_global_ca_fr = false
    end
  end

  if write_global_ca_fl
    str_added = '
      EnergyManagementSystem:GlobalVariable,
        CAFaultLevel;                !- Name
    '
    unless string_objects.include?(str_added)  # only add global variables if they are not added by the same Measure script
      string_objects << str_added
    end
  end
  if write_global_ch_fr
    str_added = '
      EnergyManagementSystem:GlobalVariable,
        CA_FAULT_ADJ_RATIO;                !- Name
    '
    unless string_objects.include?(str_added)
      string_objects << str_added
    end
  end
  return string_objects, workspace
end

def caf_adjust_function(workspace, string_objects, coilcoolingdxsinglespeed, model_name, para)
  # This function creates an Energy Management System Subroutine that calculates the adjustment factor
  # for EIR of Coil:Cooling:DX:SingleSpeed system that has its condenser fan motor faulted
  #
  # string_objects is an array object storing strings formatted as E+ objects. These objects
  # will be added to the E+ model at the end of the run function in the Measure script calling
  # this function
  #
  # coilcoolingdxsinglespeed is a WorkSpace object directing towards the Coil:Cooling:DX:SingleSpeed
  # to be fautled
  #
  # model_name is a string that defines what should be altered. Q for cooling capacity,
  # EIR for energy-input-ratio, etc.
  #
  # para is an array containing the coefficients for the fault model

  coil_choice = coilcoolingdxsinglespeed.getString(0).to_s
  sh_coil_choice = coil_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
  if sh_coil_choice.eql?(nil)
    sh_coil_choice = coil_choice
  end
  rated_cop = coilcoolingdxsinglespeed.getDouble(4).to_f

  final_line = "
    EnergyManagementSystem:Subroutine,
      CAF_ADJUST_#{sh_coil_choice}_#{model_name}, !- Name
      IF CAFFaultLevel >= 0.99, !- <none>
      SET CAF_FAULT_ADJ_RATIO = 99.0, !- <none>
      ELSE, !- <none>
      SET CAF_FAULT_ADJ_RATIO = CAFFaultLevel/(1.0-CAFFaultLevel),  !- <none>
      ENDIF,
      SET CAF_FAULT_ADJ_RATIO = 1.0+CAF_FAULT_ADJ_RATIO*#{para[0]};  !- <none>
    "

  # before addition, delete any dummy subrountine with the same name in the workspace
  subroutines = workspace.getObjectsByType('EnergyManagementSystem:Subroutine'.to_IddObjectType)
  subroutines.each do |subroutine|
    if subroutine.getString(0).to_s.eql?("CAF_ADJUST_#{sh_coil_choice}_#{model_name}")
      workspace.removeObject(subroutine.handle)  # should have only one of them
      break
    end
  end

  string_objects << final_line

  # set up global variables, if needed
  write_global_ca_fl = true
  write_global_ca_fr = true
  ems_globalvars = workspace.getObjectsByType('EnergyManagementSystem:GlobalVariable'.to_IddObjectType)
  ems_globalvars.each do |ems_globalvar|
    if ems_globalvar.getString(0).to_s.eql?('CAFFaultLevel')
      write_global_ca_fl = false
    end
    if ems_globalvar.getString(0).to_s.eql?('CAF_FAULT_ADJ_RATIO')
      write_global_ca_fr = false
    end
  end

  if write_global_ca_fl
    str_added = '
      EnergyManagementSystem:GlobalVariable,
        CAFFaultLevel;                !- Name
    '
    unless string_objects.include?(str_added)  # only add global variables if they are not added by the same Measure script
      string_objects << str_added
    end
  end
  if write_global_ch_fr
    str_added = '
      EnergyManagementSystem:GlobalVariable,
        CAF_FAULT_ADJ_RATIO;                !- Name
    '
    unless string_objects.include?(str_added)
      string_objects << str_added
    end
  end
  return string_objects, workspace
end

def ch_adjust_function(workspace, string_objects, coilcoolingdxsinglespeed, model_name, para)
  # This function creates an Energy Management System Subroutine that calculates the adjustment factor
  # for cooling capacity or EIR of Coil:Cooling:DX:SingleSpeed system that has refrigerant level different
  # from manufacturer recommendation
  #
  # string_objects is an array object storing strings formatted as E+ objects. These objects
  # will be added to the E+ model at the end of the run function in the Measure script calling
  # this function
  #
  # coilcoolingdxsinglespeed is a WorkSpace object directing towards the Coil:Cooling:DX:SingleSpeed
  # to be fautled
  #
  # model_name is a string that defines what should be altered. Q for cooling capacity,
  # EIR for energy-input-ratio, etc.
  #
  # para is an array containing the coefficients for the fault model

  coil_choice = coilcoolingdxsinglespeed.getString(0).to_s
  sh_coil_choice = coil_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
  rated_cop = coilcoolingdxsinglespeed.getDouble(4).to_f

  fault_level_name = 'CHFaultLevel'
  fir_name = 'CH_FAULT_ADJ_RATIO'
  
  final_line = "
    EnergyManagementSystem:Subroutine,
      CH_ADJUST_#{sh_coil_choice}_#{model_name}, !- Name
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
    if subroutine.getString(0).to_s.eql?("CH_ADJUST_#{sh_coil_choice}_#{model_name}")
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
    if ems_globalvar.getString(0).to_s.eql?('CHFaultLevel')
      write_global_ch_fl = false
    end
    if ems_globalvar.getString(0).to_s.eql?('CH_FAULT_ADJ_RATIO')
      write_global_ch_fr = false
    end
  end

  if write_global_ch_fl
    str_added = '
      EnergyManagementSystem:GlobalVariable,
        CHFaultLevel;                !- Name
    '
    unless string_objects.include?(str_added)  # only add global variables if they are not added by the same Measure script
      string_objects << str_added
    end
  end

  if write_global_ch_fr
    str_added = '
      EnergyManagementSystem:GlobalVariable,
        CH_FAULT_ADJ_RATIO;                !- Name
    '
    unless string_objects.include?(str_added)
      string_objects << str_added
    end
  end

  return string_objects, workspace
end

def ll_adjust_function(workspace, string_objects, coilcoolingdxsinglespeed, model_name, para)
  # This function creates an Energy Management System Subroutine that calculates the adjustment factor
  # for cooling capacity or EIR of Coil:Cooling:DX:SingleSpeed system that has liquid line restriction
  # problem
  #
  # string_objects is an array object storing strings formatted as E+ objects. These objects
  # will be added to the E+ model at the end of the run function in the Measure script calling
  # this function
  #
  # coilcoolingdxsinglespeed is a WorkSpace object directing towards the Coil:Cooling:DX:SingleSpeed
  # to be fautled
  #
  # model_name is a string that defines what should be altered. Q for cooling capacity,
  # EIR for energy-input-ratio, etc.
  #
  # para is an array containing the coefficients for the fault model

  coil_choice = coilcoolingdxsinglespeed.getString(0).to_s
  sh_coil_choice = coil_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
  rated_cop = coilcoolingdxsinglespeed.getDouble(4).to_f

  fault_level_name = 'LLFaultLevel'
  fir_name = 'LL_FAULT_ADJ_RATIO'
  
  final_line = "
    EnergyManagementSystem:Subroutine,
      CH_ADJUST_#{sh_coil_choice}_#{model_name}, !- Name
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
    if subroutine.getString(0).to_s.eql?("LL_ADJUST_#{sh_coil_choice}_#{model_name}")
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
    if ems_globalvar.getString(0).to_s.eql?('LLFaultLevel')
      write_global_ch_fl = false
    end
    if ems_globalvar.getString(0).to_s.eql?('LL_FAULT_ADJ_RATIO')
      write_global_ch_fr = false
    end
  end

  if write_global_ch_fl
    str_added = '
      EnergyManagementSystem:GlobalVariable,
        LLFaultLevel;                !- Name
    '
    unless string_objects.include?(str_added)  # only add global variables if they are not added by the same Measure script
      string_objects << str_added
    end
  end

  if write_global_ch_fr
    str_added = '
      EnergyManagementSystem:GlobalVariable,
        LL_FAULT_ADJ_RATIO;                !- Name
    '
    unless string_objects.include?(str_added)
      string_objects << str_added
    end
  end

  return string_objects, workspace
end

def nc_adjust_function(workspace, string_objects, coilcoolingdxsinglespeed, model_name, para)
  # This function creates an Energy Management System Subroutine that calculates the adjustment factor
  # for cooling capacity or EIR of Coil:Cooling:DX:SingleSpeed system that has non-condensable in
  # the refrigerant system
  #
  # string_objects is an array object storing strings formatted as E+ objects. These objects
  # will be added to the E+ model at the end of the run function in the Measure script calling
  # this function
  #
  # coilcoolingdxsinglespeed is a WorkSpace object directing towards the Coil:Cooling:DX:SingleSpeed
  # to be fautled
  #
  # model_name is a string that defines what should be altered. Q for cooling capacity,
  # EIR for energy-input-ratio, etc.
  #
  # para is an array containing the coefficients for the fault model

  coil_choice = coilcoolingdxsinglespeed.getString(0).to_s
  sh_coil_choice = coil_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
  rated_cop = coilcoolingdxsinglespeed.getDouble(4).to_f

  fault_level_name = 'NCFaultLevel'
  fir_name = 'NC_FAULT_ADJ_RATIO'
  
  final_line = "
    EnergyManagementSystem:Subroutine,
      CH_ADJUST_#{sh_coil_choice}_#{model_name}, !- Name
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
    if subroutine.getString(0).to_s.eql?("NC_ADJUST_#{sh_coil_choice}_#{model_name}")
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
    if ems_globalvar.getString(0).to_s.eql?('NCFaultLevel')
      write_global_ch_fl = false
    end
    if ems_globalvar.getString(0).to_s.eql?('NC_FAULT_ADJ_RATIO')
      write_global_ch_fr = false
    end
  end

  if write_global_ch_fl
    str_added = '
      EnergyManagementSystem:GlobalVariable,
        NCFaultLevel;                !- Name
    '
    unless string_objects.include?(str_added)  # only add global variables if they are not added by the same Measure script
      string_objects << str_added
    end
  end

  if write_global_ch_fr
    str_added = '
      EnergyManagementSystem:GlobalVariable,
        NC_FAULT_ADJ_RATIO;                !- Name
    '
    unless string_objects.include?(str_added)
      string_objects << str_added
    end
  end

  return string_objects, workspace
end

def tadp_solver(workspace, runner, t_adp, slope_adp, p_atm, t_in, w_in)
  thres = 0.0001
  negthres = -1.0*Thres
  error = 1000.0
  errorlast = error
  deltatadp = 5.0
  it = 1
  while error > thres || error < negthres && it < 100 do
    if it > 1
      t_adp = t_adp + deltatadp
    end
    w_adp = 0 ############################################PSYCHFUNCTION(t_adp, 1.0, p_atm) 
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
  negthres = -1.0*Thres
  error = 1000.0
  errorlast = error
  deltatout = 5.0
  it = 1
  while error > thres || error < negthres && it < 100 do
    if it > 1
      t_out = t_out + deltatout
    end
    w_out = 0.0 ############################################PSYCHFUNCTION(t_out, h_out)
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
  h_in = 2000 ############################################PSYCHFUNCTION(t_tmp, w_tmp)
  rho_in = 1.2 ############################################PSYCHFUNCTION(p_tmp, t_tmp, w_tmp)
  mdot_a = rho_in*vdot_rat
  deltah = qdot_rat/mdot_a
  h_tin_wout = h_in - (1 - shr_rat)*deltah
  w_out = 0.01 ############################################PSYCHFUNCTION(t_tmp, h_tin_wout)
  h_out = h_in - deltah
  t_out = 26 ############################################PSYCHFUNCTION(h_out, w_out)
  deltat = t_tmp - t_out
  deltaw = w_tmp - w_out
  slope_adp = deltaw/deltat
  t_adp = t_out - 1.0
  t_in = t_tmp
  w_in = w_tmp
  p_atm = p_tmp
  
  t_adp, w_adp = tadp_solver(workspace, runner, t_adp, slope_adp, p_atm, t_in, w_in)
  
  h_adp = 2000 ############################################PSYCHFUNCTION(t_adp, w_adp)
  bf = (h_out - h_adp)/(h_in - h_adp)
  adjao = 1 + bf_para*fault_lvl
  ao = (-1.0*mdot_a*ln(BF))*adjao ############################################MATH LIBRARY??
  bf = exp((-1.0*ao)/mdot_a) ############################################MATH LIBRARY??
  
  h_adp = ((bf*h_in) - h_out)/(bf - 1.0)
  
  t_adp = 26 ############################################PSYCHFUNCTION(h_adp, p_tmp)
  w_adp = 0.001 ############################################PSYCHFUNCTION(t_adp, h_adp)
  
  deltat = t_tmp - t_adp
  deltaw = w_tmp - w_adp
  
  slope_adp = deltaw/deltatadptout
  t_out = t_adp + 1.0
  h_out = h_out 
  t_in = t_tmp
  w_in = w_tmp
  p_atm = p_tmp
  
  t_out, w_out = tout_solver(workspace, runner, t_out, h_out, slope_adp, p_atm, t_in, w_in)
  
  if w_out >= w_tmp
    shr_new = 1.0
  else
    h_fg_adp = 2000 ############################################PSYCHFUNCTION(w_adp, t_adp)
    qdot_lat = h_fg_adp*(w_tmp - w_out)
    shr_new = 1.0 - qdot_lat*(h_in - h_out)
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
