# This script contains functions that will be used in EnergyPlus measure scripts most of the time

def name_cut(complexname)
  # return a name that is trimmed without space and symbols
  return complexname.clone.gsub!(/[^0-9A-Za-z]/, '')
end

def pass_string(object, index)
  # This function passes the string marked by index in the object
  return object.getString(index).to_s
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
