# This script contains functions that will be used in EnergyPlus measure scripts most of the time
def is_number? string
  # use this method to see if a variable in EMS starts with a number
  true if Float(string) rescue false
end

def replace_common_strings(string)
  # replace some of the common strings created by the prototype building to shorter strings
  string_new = string.downcase
  hash = {
    "zone" => "Z",
    "office" => "O",
    "whole" => "W",
    "building" => "B",
    "story" => "St",
    "ground" => "Gr",
    "watercooled" => "WC",
    "rotary screw" => "RS",
    "chiller" => "Chlr",
    "tons" => "T",
    "kw/ton" => "kW",
    "90.1-2007" => "2007"
  }
  hash.each { |k, v| string_new.gsub!(k, v) }
  return string_new
end

def name_cut(complexname)
  # return a name that is trimmed without space and symbols
  return complexname.clone.gsub!(/[^0-9A-Za-z]/, '')
end

def pass_string(object, index = 0)
  # This function passes the string marked by index in the object
  # If no index is given, default returning the first string

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
