# This ruby script creates EnergyPlus Objects to simulate refrigerant-sidefaults
# faults in Coil:Cooling:DX:SingleSpeed objects

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

def caf_adjust_function(workspace, string_objects, coilcooling, model_name, para, coiltype, coilperformancedxcooling, curve_index)
  # This function creates an Energy Management System Subroutine that calculates the adjustment factor
  # for EIR of Coil:Cooling:DX:SingleSpeed system that has its condenser fan motor faulted
  #
  # string_objects is an array object storing strings formatted as E+ objects. These objects
  # will be added to the E+ model at the end of the run function in the Measure script calling
  # this function
  #
  # coilcooling is a WorkSpace object directing towards the Coil:Cooling:DX:SingleSpeed
  # to be fautled
  #
  # model_name is a string that defines what should be altered. Q for cooling capacity,
  # EIR for energy-input-ratio, etc.
  #
  # para is an array containing the coefficients for the fault model

  coil_choice = coilcooling.getString(0).to_s
  sh_coil_choice = coil_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
  if sh_coil_choice.eql?(nil)
    sh_coil_choice = coil_choice
  end
  
  ##################################################
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
  
  #rated_cop = coilcooling.getDouble(4).to_f
  if coiltype == 1 #SINGLESPEED
    rated_cop = coilcooling.getDouble(4).to_f
  elsif coiltype == 2 #TWOSTAGEWITHHUMIDITYCONTROLMODE
    rated_cop = coilperformancedxcooling.getDouble(3).to_f
  end
  ##################################################

  final_line = "
    EnergyManagementSystem:Subroutine,
      CAF_ADJUST_#{sh_coil_choice}_#{model_name}_#{sh_curve_name}, !- Name
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
  if write_global_ca_fr
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

def pass_string(object, index = 0)
  # This function passes the string marked by index in the object
  # If no index is given, default returning the first string

  return object.getString(index).to_s
end

def get_workspace_objects(workspace, objname)
  # This function returns the workspace objects falling into the category
  # indicated by objname
  return workspace.getObjectsByType(objname.to_IddObjectType)
end

def para_biquadratic_limit(curvebiquadratics, curve_name)
  para = []
  no_curve = true
  curvebiquadratics.each do |curvebiquadratic|
    if curvebiquadratic.getString(0).to_s.eql?(curve_name)
      (1..10).each do |i|
        para << curvebiquadratic.getString(i).to_s
      end
      no_curve = false
      break
    end
  end
  return curve_name, para, no_curve
end