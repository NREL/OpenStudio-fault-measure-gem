# This ruby script creates EnergyPlus Objects to simulate refrigerant-side faults
# faults in Chiller:Electric:EIR object

# require_relative 'misc_func'

def pass_string(object, index = 0)
  # This function passes the string marked by index in the object
  # If no index is given, default returning the first string

  return object.getString(index).to_s
end

def no_fault_schedules(workspace, scheduletypelimitname, string_objects)
  # This function creates constant schedules at zero and one throughout the year
  # so that it can be referenced by fault calculation functions when the fault level
  # is zero
  #
  # workspace is a WorkSpace object with E+ objects in the building model_name
  #
  # scheduletypelimitname is a string with the name of a fractional schedule type limits
  # objects that bounds schedule values between 0 and 1
  #
  # string_objects is an array object storing strings formatted as E+ objects. These objects
  # will be added to the E+ model at the end of the run function in the Measure script calling
  # this function
  #
  # create a schedule of one and zero to indicate that other faults do not exist
  schnames = %w(ZERO_FAULT ONE_FAULT)
  schnames.each do |schname|
    unless addconstant_sch(workspace, schname)
      string_objects << "
        Schedule:Constant,
          #{schname},         !- Name
          #{scheduletypelimitname},                       !- Schedule Type Limits Name
          #{val_check(schname)};                    !- Hourly Value
      "
    end
  end
  return string_objects
end

def addconstant_sch(workspace, schname)
  # check if the schedules of zero fault and one fault is needed
  const_fault_schs = workspace.getObjectsByType('Schedule:Constant'.to_IddObjectType)
  const_fault_schs.each do |const_fault_sch|
    next unless pass_string(const_fault_sch, 0).eql?(schname)
    return true
  end
  return false
end

def val_check(name)
  # This function checks what the value of the schedule should be with the string name
  return '1' unless name == 'ZERO_FAULT'
  return '0'
end

def main_program_entry(workspace, string_objects, chiller_choice, curve_name, para, model_name)
  # define function to write EMS main program to alter the temperature curve
  #
  # This function writes an E+ object that embed the temperature modulation
  # curve in the Coil:Cooling:DX:SingleSpeed object with fault the fault model
  #
  # workspace is a WorkSpace object with E+ objects in the building model_name
  #
  # string_objects is an array object storing strings formatted as E+ objects. These objects
  # will be added to the E+ model at the end of the run function in the Measure script calling
  # this function
  #
  # chiller_choice is a string that is the name of the Coil:Cooling:DX:SingleSpeed object
  # to be faulted
  #
  # curve_name is a string that contains the name of an Curve:Biquadratic object
  #
  # para is an array containing the coefficients and limits of an Curve:Biquadratic
  # object. This Curve:Biquadratic object defines the temperature modulation curve.
  #
  # model_name is a string that defines what should be altered. Q for cooling capacity,
  # EIR for energy-input-ratio, etc.
  #
  # only write EMS program of the new curve if the program does not exist
  sh_chiller_choice = name_cut(chiller_choice)

  if need_emswriteprogramcurve(workspace, sh_chiller_choice, model_name)
    string_objects << "
      EnergyManagementSystem:Program,
        ChillerElectricEIRDegradation#{sh_chiller_choice}#{model_name}, !- Name
        SET CoTmp = CondInlet#{sh_chiller_choice}, !- Program Line 1
        SET EvTmp = EvapOutlet#{sh_chiller_choice},   !- Program Line 2
        SET IVOne = EvTmp,       !- <none>
        SET IVTwo = CoTmp,         !- <none>
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
        SET #{sh_chiller_choice}#{model_name} = C1+(C2*IVOne), !- <none>
        SET #{sh_chiller_choice}#{model_name} = #{sh_chiller_choice}#{model_name} + (C3*IVOne*IVone), !- <none>
        SET #{sh_chiller_choice}#{model_name} = #{sh_chiller_choice}#{model_name} + (C4*IVTwo), !- <none>
        SET #{sh_chiller_choice}#{model_name} = #{sh_chiller_choice}#{model_name} + (C5*IVTwo*IVTwo), !- <none>
        SET #{sh_chiller_choice}#{model_name} = #{sh_chiller_choice}#{model_name} + (C6*IVThree); !- <none>
    "

    string_objects << "
      EnergyManagementSystem:GlobalVariable,
        #{sh_chiller_choice}#{model_name};                !- Name
    "
  end
  return string_objects
end

def need_emswriteprogramcurve(workspace, sh_chiller_choice, model_name)
  # check if the main emsprogram for curves is needed
  emsprograms = workspace.getObjectsByType('EnergyManagementSystem:Program'.to_IddObjectType)
  emsprograms.each do |emsprogram|
    return false if pass_string(emsprogram, 0).eql?("ChillerElectricEIRDegradation#{sh_chiller_choice}#{model_name}")
  end
  return true
end

def dummy_fault_prog_add(workspace, string_objects, fault_type = 'CA', chiller_choice, model_name)
  # This function adds any dummy subroutine that does nothing. It's used when the fault is not modeled
  sh_chiller_choice = name_cut(chiller_choice)

  unless check_emswriteprogram_exist(workspace, sh_chiller_choice, model_name, fault_type)
    string_objects << "
      EnergyManagementSystem:Program,
        #{fault_type}_ADJUST_#{sh_chiller_choice}_#{model_name}, !- Name
        SET #{fault_type}_FAULT_ADJ_RATIO = 1.0,  !- <none>
    "
  end

  # add global variables when needed
  unless check_gb_var(workspace, fault_type)
    str_added = "
      EnergyManagementSystem:GlobalVariable,
        #{fault_type}_FAULT_ADJ_RATIO;                !- Name
    "
    unless string_objects.include?(str_added)
      string_objects << str_added
    end
  end
  return string_objects
end

def check_emswriteprogram_exist(workspace, sh_chiller_choice, model_name, fault_type)
  # check if an emsprogram for dummy fault ratio is needed
  subroutines = workspace.getObjectsByType('EnergyManagementSystem:Program'.to_IddObjectType)
  subroutines.each do |subroutine|
    return true if pass_string(subroutine, 0).eql?("#{fault_type}_ADJUST_#{sh_chiller_choice}_#{model_name}")
  end
  return false
end

def fault_level_sensor_sch_insert(workspace, string_objects, fault_type = 'CA', chiller_choice, sch_choice)
  # This function appends an EMS sensor to direct the fault level schedule to the EMS program.
  # If an arbitrary schedule exists before insertion, remove the old one and apply the new one.
  sch_obj_name = "#{fault_type}FaultDegrade#{name_cut(chiller_choice)}"

  ems_sensors = workspace.getObjectsByType('EnergyManagementSystem:Sensor'.to_IddObjectType)
  ems_sensors.each do |ems_sensor|
    if pass_string(ems_sensor, 0).eql?(sch_obj_name)
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

def fault_adjust_function(workspace, string_objects, fault_type, chillerelectriceir, model_name, para)
  # This function creates an Energy Management System Subroutine that calculates the adjustment factor
  # for power consumption of Chiller:Electric:EIR system that has refrigerant level different
  # from manufacturer recommendation
  #
  # string_objects is an array object storing strings formatted as E+ objects. These objects
  # will be added to the E+ model at the end of the run function in the Measure script calling
  # this function
  #
  # fault_type is a string used to indicate what type of fault it is
  #
  # chillerelectriceir is a WorkSpace object directing towards the Coil:Cooling:DX:SingleSpeed
  # to be fautled
  #
  # para is an array containing the coefficients for the fault model
  sh_chiller_choice = name_cut(pass_string(chillerelectriceir, 0))

  string_objects << "
    EnergyManagementSystem:Program,
      #{fault_type}_ADJUST_#{sh_chiller_choice}_#{model_name}, !- Name
      SET Qevap = EvapQ#{sh_chiller_choice},  !- Check if calculation is needed
      IF Qevap > 0.001,
      SET CoTmp = CondInlet#{sh_chiller_choice}, !- Program Line 1
      SET EvTmp = EvapOutlet#{sh_chiller_choice},   !- Program Line 2
      SET Qadj = #{sh_chiller_choice}q, !- Program Line 3 that starts the capacity calculation
      SET EvInTmp = EvapInlet#{sh_chiller_choice},
      SET Qavail = Qadj*#{pass_string(chillerelectriceir, 1)}, !- Program Line 4 to get the maximum heat transfer rate at steady
      IF Qavail < Qevap,
      SET Qevap = Qavail,  !- Check if the availble chiller capacity is lower than the required load
      ENDIF,
      SET Qevap = Qevap/#{chillerelectriceir.getDouble(1).to_f}, !- noramlize the capacity values accordingly
      SET #{fault_type}FaultLevel = #{fault_type}FaultDegrade#{sh_chiller_choice}, !- <none>
      #{emsprogram_boundary_check(fault_type, para)}
      SET #{fault_type}_FAULT_ADJ_RATIO = (C1+C2*(EvTmp+273.15)+C3*(CoTmp+273.15)+C4*Qevap),  !- <none>
      SET #{fault_type}_FAULT_ADJ_RATIO = (#{fault_type}_FAULT_ADJ_RATIO+C5*Qevap*Qevap),  !- <none>
      SET #{fault_type}_FAULT_ADJ_RATIO = #{fault_type}_FAULT_ADJ_RATIO*#{fault_type}_FAULT_ADJ_RATIO, !- <none>
      SET #{fault_type}_FAULT_ADJ_RATIO = #{fault_type}_FAULT_ADJ_RATIO*#{fault_type}FaultLevel, !- <none>
      SET #{fault_type}_FAULT_ADJ_RATIO = 1.0+#{fault_type}_FAULT_ADJ_RATIO*#{fault_type}FaultLevel,  !- <none>
      ELSE,
      SET #{fault_type}_FAULT_ADJ_RATIO = 1.0, !- <none>
      ENDIF,
    "

  # set up global variables, if needed
  unless check_gb_var(workspace, fault_type, str_end = 'FaultLevel')
    str_added = "
      EnergyManagementSystem:GlobalVariable,
        #{fault_type}FaultLevel;                !- Name
    "
    unless string_objects.include?(str_added)  # only add global variables if they are not added by the same Measure script
      string_objects << str_added
    end
  end

  unless check_gb_var(workspace, fault_type)
    str_added = "
      EnergyManagementSystem:GlobalVariable,
        #{fault_type}_FAULT_ADJ_RATIO;                !- Name
    "
    unless string_objects.include?(str_added)
      string_objects << str_added
    end
  end
  return string_objects
end

def check_gb_var(workspace, fault_type, str_end = '_FAULT_ADJ_RATIO')
  # check if a global variable for the dummy program is needed
  ems_globalvars = workspace.getObjectsByType('EnergyManagementSystem:GlobalVariable'.to_IddObjectType)
  ems_globalvars.each do |ems_globalvar|
    return true if pass_string(ems_globalvar, 0).eql?("#{fault_type}#{str_end}")
  end
  return false
end

def emsprogram_boundary_check(fault_type, para)
  # write Erl program to check if the inputs to the ems program exceed the user-defined limits
  return "
    IF #{fault_type}FaultLevel > #{para[0]},  !- <none>
    SET #{fault_type}FaultLevel = #{para[0]},  !- <none>
    ENDIF, !-<none>
    SET C1 = #{para[1]},  !- <none>
    SET C2 = #{para[2]},  !- <none>
    SET C3 = #{para[3]},  !- <none>
    SET C4 = #{para[4]},  !- <none>
    SET C5 = #{para[5]},  !- <none>
    SET MinEvTmp = #{para[6]},  !- <none>
    IF EvTmp < MinEvTmp,  !- <none>
    SET EvTmp = MinEvTmp,  !- <none>
    ENDIF, !-<none>
    SET MaxEvTmp = #{para[7]},  !- <none>
    IF EvTmp > MaxEvTmp,  !- <none>
    SET EvTmp = MaxEvTmp,  !- <none>
    ENDIF, !-<none>
    SET MinCoTmp = #{para[8]},  !- <none>
    IF CoTmp < MinCoTmp,  !- <none>
    SET CoTmp = MinCoTmp,  !- <none>
    ENDIF, !-<none>
    SET MaxCoTmp = #{para[9]},  !- <none>
    IF CoTmp > MaxCoTmp,  !- <none>
    SET CoTmp = MaxCoTmp,  !- <none>
    ENDIF, !-<none>
    SET MinQavail = #{para[10]},  !- <none>
    IF Qevap < MinQavail,  !- <none>
    SET Qevap = MinQavail,  !- <none>
    ENDIF, !-<none>
    SET MaxQavail = #{para[11]},  !- <none>
    IF Qevap > MaxQavail,  !- <none>
    SET Qevap = MaxQavail,  !- <none>
    ENDIF, !-<none>
  "
end
