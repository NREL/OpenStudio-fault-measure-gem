# This script contains functions that will be used in EnergyPlus measure scripts most of the time

def name_cut(complexname)
  # return a name that is trimmed without space and symbols
  return complexname.clone.gsub!(/[^0-9A-Za-z]/, '')
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
