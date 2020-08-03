# This script contains functions that will be used in EnergyPlus measure scripts most of the time

def name_cut(complexname)
  # return a name that is trimmed without space and symbols
  #####################################################
  if complexname.clone.gsub!(/[^0-9A-Za-z]/, '').nil?
    return complexname
  else
    return complexname.clone.gsub!(/[^0-9A-Za-z]/, '')
  end
  #####################################################
  #return complexname.clone.gsub!(/[^0-9A-Za-z]/, '')
end

def pass_string(object, index = 0)
  # This function passes the string marked by index in the object
  # If no index is given, default returning the first string

  return object.getString(index).to_s
end

def pass_float(object, index = 0)
  # This function passes the float marked by index in the object
  # If no index is given, default returning the first float

  return object.getString(index).to_s.to_f
end

def insert_objects(workspace, string_objects)
  # This function inserts objects in string_objects into workspace
  string_objects.each do |string_object|
    idfobject = OpenStudio::IdfObject.load(string_object)
    object = idfobject.get
    wsobject = workspace.addObject(object)
  end
  # resets string_objects
  return []
end

def get_workspace_objects(workspace, objname)
  # This function returns the workspace objects falling into the category
  # indicated by objname
  return workspace.getObjectsByType(objname.to_IddObjectType)
end

def find_outdoor_node_name(workspace)
  # This function returns a name of a random node of the outdoor environment

  outdoornodelist = get_workspace_objects(workspace, 'OutdoorAir:NodeList')
  return pass_string(outdoornodelist[0], 0)
end

def ems_programcaller_writer(program_names, callingpoint, string_objects)
  # This function writes an EMS program caller of the program defined by
  # program_names. The program_names is a list of name of EMS programs that
  # are to be executed by the EMS in the order of the names in program_names.
  # The Calling Point of the EMS program caller is written in callingpoint.
  # The EMS caller will then be pushed into the list string_objects and returns
  # true at the end.

  # create the header of the calling manager
  final_line =  "
    EnergyManagementSystem:ProgramCallingManager,
      EMSCall#{program_names[0]}, !- Name
      #{callingpoint}, !- EMS Calling Point
  "

  # append the program names into the calling manager
  # at the very last line, add a ;
  endindex = program_names.length - 1
  program_names.each_with_index do |program_name, index|
    if index < endindex
      final_line += "
        #{program_name}, !- Program Line #{index + 1}
      "
    else
      final_line += "
        #{program_name}; !- Program Line #{index + 1}
      "
    end
  end
  string_objects << final_line
  return true
end

def ems_output_writer(workspace, string_objects, err_check = false)
  # This function checks if an Output:EnergyManagementSystem object
  # exists in object workspace and appends one if it doesn't. If err_check
  # is true, it assumes the programmer is running the E+ file in debug mode
  # and will use the object, if not added, to output all calculation steps
  # in the *.edd file

  outputemss = get_workspace_objects(workspace, 'Output:EnergyManagementSystem')
  if outputemss.size == 0
    if err_check
      string_objects << '
        Output:EnergyManagementSystem,
          Verbose,                 !- Actuator Availability Dictionary Reporting
          Verbose,                 !- Internal Variable Availability Dictionary Reporting
          Verbose;                 !- EMS Runtime Language Debug Output Level
      '
    else
      string_objects << '
        Output:EnergyManagementSystem,
          Verbose,                 !- Actuator Availability Dictionary Reporting
          Verbose,                 !- Internal Variable Availability Dictionary Reporting
          ErrorsOnly;              !- EMS Runtime Language Debug Output Level
      '
    end
  end
  return true
end

def ems_sensor_str(name, keyname, output_var_name)
  # This function creates a string of EMS sensor statement according to the
  # name, keyname and output_var_name

  return "
    EnergyManagementSystem:Sensor,
      #{name},                    !- Name
      #{keyname},                 !- Output:Variable or Output:Meter Index Key Name
      #{output_var_name};         !- Output:Variable or Output:Meter Name
  "
end

def ems_actuator_str(name, component_name, component_type, control_variable)
  # This function creates a string of EMS actuator statement according to the
  # name, component_name, component_type and control_variable

  return "
    EnergyManagementSystem:Actuator,
      #{name},                   !- Name
      #{component_name},         !- Actuated Component Unique Name
      #{component_type},         !- Actuated Component Type
      #{control_variable};       !- Actuated Component Control Type
  "
end

def ems_globalvariable_str(name)
  # This function creates a string of EMS global variable statement
  # according to the name

  return "
    EnergyManagementSystem:GlobalVariable,
      #{name}; !- Name
  "
end

def outputvariable_str(keyvalue, variablename, reporting_frequency)
  # This function returns the string that creates an Output:Variable object
  # in E+ workspace
  return "
    Output:Variable,
      #{keyvalue}, !- Key Value
      #{variablename}, !- Variable Name
      #{reporting_frequency}; !- Reporting Frequency
  "
end

def outputmeter_str(name, reporting_frequency)
  # This function returns the string that creates an Output:Meter object
  # in E+ workspace
  return "
    Output:Meter,
      #{name}, !- Name
      #{reporting_frequency}; !- Reporting Frequency
  "
end

def append_workspace_objects(workspace, string_objects)
  # This function appends all strings in the list string_objects into
  # workspace. It resets string_objects to an empty string afterwards
  # and returns true

  while string_objects.length > 0
    # removing the first entry in string_objects
    string_object = string_objects.shift
    # adding the removed object to workspace
    idfobject = OpenStudio::IdfObject.load(string_object)
    object = idfobject.get
    wsobject = workspace.addObject(object)
  end
end

def ems_outputvariable_str(varname, emsname, typedata = 1,
                           freq = 1, local = '', units = '')
  # This function creates a string of EMS OutputVariable statement
  # for EMS variable emsnam to set it as an Output:Variable varname
  # typedata is the type of data (Averaged or Summed), with 1 for
  # Averaged (default) and other value for Summed. freq is the Update
  # frequency in Output:Variable, with 1 for ZoneTimestep (default) and
  # other values SystemTimestep. local is the name of the subrountine
  # where the emsname resides, and is defaulted empty to assume that the
  # variable is a global variable. units is the engineerign unit of the
  # variable emsname, and is defaulted to be empty (dimensionless).

  # convert options to strings
  typedatastr = 'Averaged'
  typedatastr = 'Summed' unless typedata == 1
  freqstr = 'ZoneTimestep'
  freqstr = 'SystemTimestep' unless freq == 1

  return "
    EnergyManagementSystem:OutputVariable,
      #{varname},                 !- Name
      #{emsname},                 !- EMS Variable Name
      #{typedatastr},             !- Type of Data in Variable
      #{freqstr},                 !- Update Frequency
      #{local},                   !- EMS Program or Subroutine Name
      #{units};                   !- Units
  "
end

def endstrchecker(index, ncase)
  # This function returns the ending string of an EnergyPlus object.
  # If index equals to ncase - 1, it returns a ';'. Otherwise, it returns
  # a ','

  return ',' unless index == ncase - 1
  return ';'
end

def check_exist_workspace_objects(workspace, name, objtype)
  # This function checks if an object named name with object type objtype
  # exists in E+ workspace

  objects = get_workspace_objects(workspace, objtype)
  objects.each do |object|
    return true if pass_string(object, 0).eql?(name)
  end
  return false
end

def ems_internalvariable_str(name, keyname, datatype)
  # This function creates a string of EMS internal variable statement
  # according to the name, keyname for key name of internal variable
  # and datatype for internal data type

  return "
    EnergyManagementSystem:InternalVariable,
      #{name}, !- Name
      #{keyname}, !- Internal Data Index Key Name
      #{datatype}; !- Internal Data Type
  "
end

def ems_outputvar_creator(newoutputname, emsvarname, typedata = 1,
                          freq = 1, subroutinename = '', units = '',
                          reportingfreq = 'timestep')
  # This function creates array of strings to output variables
  # in ems programs

  misc_objects = []
  # push in EMS OutputVariable
  misc_objects << ems_outputvariable_str(newoutputname, emsvarname,
                                         typedata, freq,
                                         subroutinename, units)
  # push in Output:Variable objects
  misc_objects << outputvariable_str('*', newoutputname, reportingfreq)

  return misc_objects
end

def append_string_objects(ori_strings, new_strings)
  # This function appends all objects in the array new_strings
  # to ori_strings and create a 1-d array at ori_strings. Returns
  # true

  new_strings.each do |new_string|
    ori_strings << new_string
  end
  ori_strings.flatten!
  return true
end
