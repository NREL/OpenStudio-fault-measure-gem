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

  emsprograms = workspace.getObjectsByType('EnergyManagementSystem:Program'.to_IddObjectType)
  writeprogram = true
  emsprograms.each do |emsprogram|
    if emsprogram.getString(0).to_s.eql?('DXCoolingCoilDegradation' + sh_coil_choice + model_name)
      writeprogram = false
      break
    end
  end

  if writeprogram
    string_objects << "
      EnergyManagementSystem:Program,
        DXCoolingCoilDegradation#{sh_coil_choice + model_name}, !- Name
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
        RUN #{$faultnow}_ADJUST_#{sh_coil_choice}_#{model_name}, !- Calling subrountines that adjust the cooling capacity based on condenser fouling
        SET FAULT_ADJ_RATIO = #{$faultnow}_FAULT_ADJ_RATIO*FAULT_ADJ_RATIO,     !- The next few lines will be filled by other refrigerant-side faults in the future
        SET FAULT_ADJ_RATIO = CH_FAULT_ADJ_RATIO*FAULT_ADJ_RATIO,     !- The next few lines will be filled by other refrigerant-side faults in the future
        SET #{model_name}Curve#{sh_coil_choice} = (OriCurve*FAULT_ADJ_RATIO);  !- <none>
    "

    # create the ProgramCaller, required actuators, etc. that are only required by this program
    string_objects << "
      EnergyManagementSystem:ProgramCallingManager,
      EMSCallDXCoolingCoilDegradation#{sh_coil_choice}#{model_name}, !- Name
      AfterPredictorBeforeHVACManagers, !- EnergyPlus Model Calling Point
      DXCoolingCoilDegradation#{sh_coil_choice}#{model_name}; !- Program Name 1
    "

    string_objects << "
      EnergyManagementSystem:Actuator,
        #{model_name}Curve#{sh_coil_choice},          !- Name
        #{curve_name},           !- Actuated Component Unique Name
        Curve,                   !- Actuated Component Type
        Curve Result;            !- Actuated Component Control Type
    "

    string_objects << "
      EnergyManagementSystem:OutputVariable,
        #{model_name}CurveValue#{sh_coil_choice},           !- Name
        #{model_name}Curve#{sh_coil_choice},          !- EMS Variable Name
        Averaged,                !- Type of Data in Variable
        ZoneTimeStep,            !- Update Frequency
        ,                        !- EMS Program or Subroutine Name
        ;                        !- Units
    "
  end

  return string_objects
end

def dummy_fault_sub_add(workspace, string_objects, fault_choice = 'CA', coil_choice, model_name)
  # This function adds any dummy subroutine that does nothing. It's used when the fault is not modeled
  add_sub = true
  sh_coil_choice = coil_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
  if sh_coil_choice.eql?(nil)
    sh_coil_choice = coil_choice
  end

  subroutines = workspace.getObjectsByType('EnergyManagementSystem:Subroutine'.to_IddObjectType)
  subroutines.each do |subroutine|
    if subroutine.getString(0).to_s.eql?("#{fault_choice}_ADJUST_#{sh_coil_choice}_#{model_name}")
      add_sub = false
      break
    end
  end

  if add_sub
    string_objects << "
      EnergyManagementSystem:Subroutine,
        #{fault_choice}_ADJUST_#{sh_coil_choice}_#{model_name}, !- Name
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

def general_adjust_function(workspace, string_objects, coilcoolingdxsinglespeed, model_name, para, fault_name)
  # This function appends the program and the required variables that calculate the fault impact ratio
  # into the EnergyPlus IDF file

  coil_choice = coilcoolingdxsinglespeed.getString(0).to_s
  sh_coil_choice = coil_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
  rated_cop = coilcoolingdxsinglespeed.getDouble(4).to_f

  fault_level_name = "#{fault_name}FaultLevel"
  fir_name = "#{fault_name}_FAULT_ADJ_RATIO"
  
  final_line = "
    EnergyManagementSystem:Subroutine,
      #{fault_name}_ADJUST_#{sh_coil_choice}_#{model_name}, !- Name
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
    if subroutine.getString(0).to_s.eql?("#{fault_name}_ADJUST_#{sh_coil_choice}_#{model_name}")
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
