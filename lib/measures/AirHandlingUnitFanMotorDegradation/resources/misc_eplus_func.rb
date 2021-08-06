# This script contains functions that will be used in EnergyPlus measure scripts most of the time

def is_number? string
  # use this method to see if a variable in EMS starts with a number
  true if Float(string) rescue false
end

def replace_common_strings(string)
  # add more if some unnecessarily long string is bothering you
  string_new = string.downcase
  hash = {
    "zone" => "Z",
    "office" => "O",
    "whole" => "W",
    "building" => "B",
    "story" => "St",
    "ground" => "Gr",
    "navy" => "N",
    "lf59" => "59",
    "urn" => "U",
    "wshp" => "WS"
  }
  hash.each { |k, v| string_new.gsub!(k, v) }
  return string_new
end

def name_cut(complexname)
  # return a name that is trimmed without space and symbols
  if complexname.clone.gsub!(/[^0-9A-Za-z]/, '').nil?
    return complexname
  else
    return complexname.clone.gsub!(/[^0-9A-Za-z]/, '')
  end
end

