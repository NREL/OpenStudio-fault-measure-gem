#This ruby script creates EnergyPlus Objects to simulate refrigerant-side faults
#faults in Chiller:Electric:EIR object

#This function creates constant schedules at zero and one throughout the year
#so that it can be referenced by fault calculation functions when the fault level
#is zero
def no_fault_schedules(workspace, scheduletypelimitname, string_objects)

  #workspace is a WorkSpace object with E+ objects in the building model_name
  
  #scheduletypelimitname is a string with the name of a fractional schedule type limits
  #objects that bounds schedule values between 0 and 1
  
  #string_objects is an array object storing strings formatted as E+ objects. These objects
  #will be added to the E+ model at the end of the run function in the Measure script calling
  #this function

  #create a schedule of one and zero to indicate that other faults do not exist
  const_fault_schs = workspace.getObjectsByType("Schedule:Constant".to_IddObjectType)
  zero_fault_sch = false
  one_fault_sch = false
  const_fault_schs.each do |const_fault_sch|
    if const_fault_sch.getString(0).to_s.eql?("ZERO_FAULT")
      zero_fault_sch = true
    end
    if const_fault_sch.getString(0).to_s.eql?("ONE_FAULT")
      one_fault_sch = true
    end
  end
  
  #only create the schedules when the schedules do not exist
  if not zero_fault_sch
    string_objects << "
      Schedule:Constant,
        ZERO_FAULT,         !- Name
        "+scheduletypelimitname+",                       !- Schedule Type Limits Name
        0;                    !- Hourly Value
    "
  end
  if not one_fault_sch
    string_objects << "
      Schedule:Constant,
        ONE_FAULT,         !- Name
        "+scheduletypelimitname+",                       !- Schedule Type Limits Name
        1;                    !- Hourly Value
    "
  end
  
  return string_objects
  
end

#define function to write EMS main program to alter the temperature curve
def main_program_entry(workspace, string_objects, chiller_choice, curve_name, para, model_name)

  #This function writes an E+ object that embed the temperature modulation
  #curve in the Coil:Cooling:DX:SingleSpeed object with fault the fault model

  #workspace is a WorkSpace object with E+ objects in the building model_name
  
  #string_objects is an array object storing strings formatted as E+ objects. These objects
  #will be added to the E+ model at the end of the run function in the Measure script calling
  #this function
  
  #chiller_choice is a string that is the name of the Coil:Cooling:DX:SingleSpeed object
  #to be faulted
  
  #curve_name is a string that contains the name of an Curve:Biquadratic object
  
  #para is an array containing the coefficients and limits of an Curve:Biquadratic
  #object. This Curve:Biquadratic object defines the temperature modulation curve.
  
  #model_name is a string that defines what should be altered. Q for cooling capacity,
  #EIR for energy-input-ratio, etc.

  #only write EMS program of the new curve if the program does not exist
  sh_chiller_choice = chiller_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
  
  emsprograms = workspace.getObjectsByType("EnergyManagementSystem:Program".to_IddObjectType)
  writeprogram = true
  emsprograms.each do |emsprogram|
    if emsprogram.getString(0).to_s.eql?("ChillerElectricEIRDegradation"+sh_chiller_choice+model_name)
      writeprogram = false
      break
    end
  end
  
  if writeprogram
    string_objects << "
      EnergyManagementSystem:Program,
        ChillerElectricEIRDegradation"+sh_chiller_choice+model_name+", !- Name
        SET CoTmp = CondInlet"+sh_chiller_choice+", !- Program Line 1
        SET EvTmp = EvapOutlet"+sh_chiller_choice+",   !- Program Line 2
        SET IVOne = EvTmp,       !- <none>
        SET IVTwo = CoTmp,         !- <none>
        SET C1 = "+para[0]+",  !- <none>
        SET C2 = "+para[1]+",  !- <none>
        SET C3 = "+para[2]+",  !- <none>
        SET C4 = "+para[3]+",  !- <none>
        SET C5 = "+para[4]+",  !- <none>
        SET C6 = "+para[5]+",  !- <none>
        SET IVOneMin = "+para[6]+",  !- <none>
        SET IVOneMax = "+para[7]+",  !- <none>
        SET IVTwoMin = "+para[8]+",  !- <none>
        SET IVTwoMax = "+para[9]+",  !- <none>
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

def dummy_fault_prog_add(workspace, string_objects, fault_type="CA", chiller_choice, model_name)

  #This function adds any dummy subroutine that does nothing. It's used when the fault is not modeled
  
  add_sub = true
  sh_chiller_choice = chiller_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
  
  subroutines = workspace.getObjectsByType("EnergyManagementSystem:Program".to_IddObjectType)
  subroutines.each do |subroutine|
    if subroutine.getString(0).to_s.eql?(fault_type+"_ADJUST_"+sh_chiller_choice+"_"+model_name)
      add_sub = false
      break
    end
  end
  
  if add_sub
    string_objects << "
      EnergyManagementSystem:Program,
        "+fault_type+"_ADJUST_"+sh_chiller_choice+"_"+model_name+", !- Name
        SET "+fault_type+"_FAULT_ADJ_RATIO = 1.0,  !- <none>
    "
    
    #add global variables when needed
    write_global_fr = true
    ems_globalvars = workspace.getObjectsByType("EnergyManagementSystem:GlobalVariable".to_IddObjectType)
    ems_globalvars.each do |ems_globalvar|
      if ems_globalvar.getString(0).eql?(fault_type+"_FAULT_ADJ_RATIO")
        write_global_ch_fr = false
      end
    end
    
    if write_global_fr
      str_added = "
        EnergyManagementSystem:GlobalVariable,
          "+fault_type+"_FAULT_ADJ_RATIO;                !- Name
      "
      if not string_objects.include?(str_added)
        string_objects << str_added
      end
    end
    
  end
  
  return string_objects
  
end

def fault_level_sensor_sch_insert(workspace, string_objects, fault_type="CA", chiller_choice, sch_choice)

  #This function appends an EMS sensor to direct the fault level schedule to the EMS program.
  #If an arbitrary schedule exists before insertion, remove the old one and apply the new one.
  
  sch_obj_name = fault_type+"FaultDegrade"+chiller_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
  
  ems_sensors = workspace.getObjectsByType("EnergyManagementSystem:Sensor".to_IddObjectType)
  ems_sensors.each do |ems_sensor|
    if ems_sensor.getString(0).eql?(sch_obj_name)
      removed_sensors = ems_sensor.remove()
      break
    end
  end
  
  string_objects << "
    EnergyManagementSystem:Sensor,
      "+sch_obj_name+",                !- Name
      "+sch_choice+",       !- Output:Variable or Output:Meter Index Key Name
      Schedule Value;    !- Output:Variable or Output:Meter Name     
  "
  
  return string_objects

end


def fault_adjust_function(workspace, string_objects, fault_type, chillerelectriceir, model_name, para)

  #This function creates an Energy Management System Subroutine that calculates the adjustment factor
  #for power consumption of Chiller:Electric:EIR system that has refrigerant level different
  #from manufacturer recommendation
  
  #string_objects is an array object storing strings formatted as E+ objects. These objects
  #will be added to the E+ model at the end of the run function in the Measure script calling
  #this function
  
  #fault_type is a string used to indicate what type of fault it is
  
  #chillerelectriceir is a WorkSpace object directing towards the Coil:Cooling:DX:SingleSpeed
  #to be fautled
  
  #para is an array containing the coefficients for the fault model
  
  chiller_choice = chillerelectriceir.getString(0).to_s
  sh_chiller_choice = chiller_choice.clone.gsub!(/[^0-9A-Za-z]/, '')

  #get the reference capacity in kW
  ref_cap = chillerelectriceir.getDouble(1).to_f  # in W
  
  final_line = "
    EnergyManagementSystem:Program,
      #{fault_type}_ADJUST_"+sh_chiller_choice+"_"+model_name+", !- Name
      SET Qevap = EvapQ"+sh_chiller_choice+",  !- Check if calculation is needed
      IF Qevap > 0.001,
      SET CoTmp = CondInlet"+sh_chiller_choice+", !- Program Line 1
      SET EvTmp = EvapOutlet"+sh_chiller_choice+",   !- Program Line 2
      SET Qadj = #{sh_chiller_choice}q, !- Program Line 3 that starts the capacity calculation
      SET EvInTmp = EvapInlet"+sh_chiller_choice+",
      SET Qavail = Qadj*#{chillerelectriceir.getString(1).to_s}, !- Program Line 4 to get the maximum heat transfer rate at steady
      IF Qavail < Qevap,
      SET Qevap = Qavail,  !- Check if the availble chiller capacity is lower than the required load
      ENDIF,
      SET Qevap = Qevap/#{ref_cap}, !- noramlize the capacity values accordingly
      SET #{fault_type}FaultLevel = #{fault_type}FaultDegrade"+sh_chiller_choice+", !- <none>
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
      SET #{fault_type}_FAULT_ADJ_RATIO = (C1+C2*(EvTmp+273.15)+C3*(CoTmp+273.15)+C4*Qevap),  !- <none>
      SET #{fault_type}_FAULT_ADJ_RATIO = (#{fault_type}_FAULT_ADJ_RATIO+C5*Qevap*Qevap),  !- <none>
      SET #{fault_type}_FAULT_ADJ_RATIO = #{fault_type}_FAULT_ADJ_RATIO*#{fault_type}_FAULT_ADJ_RATIO, !- <none>
      SET #{fault_type}_FAULT_ADJ_RATIO = #{fault_type}_FAULT_ADJ_RATIO*#{fault_type}FaultLevel, !- <none>
      SET #{fault_type}_FAULT_ADJ_RATIO = 1.0+#{fault_type}_FAULT_ADJ_RATIO;  !- only for NC
      ELSE,
      SET #{fault_type}_FAULT_ADJ_RATIO = 1.0, !- <none>
      ENDIF,
    "

  string_objects << final_line
  
  #set up global variables, if needed
  write_global_ch_fl = true
  write_global_ch_fr = true
  ems_globalvars = workspace.getObjectsByType("EnergyManagementSystem:GlobalVariable".to_IddObjectType)
  ems_globalvars.each do |ems_globalvar|
    if ems_globalvar.getString(0).eql?("#{fault_type}FaultLevel")
      write_global_ch_fl = false
    end
    if ems_globalvar.getString(0).eql?("#{fault_type}_FAULT_ADJ_RATIO")
      write_global_ch_fr = false
    end
  end
  
  if write_global_ch_fl
    str_added = "
      EnergyManagementSystem:GlobalVariable,
        #{fault_type}FaultLevel;                !- Name
    "
    if not string_objects.include?(str_added)  #only add global variables if they are not added by the same Measure script
      string_objects << str_added
    end
  end
  
  if write_global_ch_fl
    str_added = "
      EnergyManagementSystem:GlobalVariable,
        #{fault_type}_FAULT_ADJ_RATIO;                !- Name
    "
    if not string_objects.include?(str_added)
      string_objects << str_added
    end
  end
  
  return string_objects, workspace

end
