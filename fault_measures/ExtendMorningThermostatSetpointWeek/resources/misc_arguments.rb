# The file contains functions to pass arguments from OpenStudio inputs to the
# measure script. They are used to avoid the function arguments to be too long.

def pass_zone(model, allchoices)
  # This function returns the zone handle and zone display name in
  # the OpenStudio model so that they can be used as part of the
  # arguments in the measure script

  # make a choice argument for model objects
  zone_handles = OpenStudio::StringVector.new
  zone_display_names = OpenStudio::StringVector.new

  # putting model object and names into hash
  zone_args = model.getThermalZones
  zone_args_hash = {}
  zone_args.each do |zone_arg|
    zone_args_hash[zone_arg.name.to_s] = zone_arg
  end

  # looping through sorted hash of model objects
  zone_args_hash.sort.map do |key, value|
    zone_handles << value.handle.to_s
    zone_display_names << key
  end
  zone_handles << ''
  zone_display_names << allchoices

  return zone_handles, zone_display_names
end
