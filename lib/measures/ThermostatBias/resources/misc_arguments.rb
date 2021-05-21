# The file contains functions to pass arguments from OpenStudio inputs to the
# measure script. They are used to avoid the function arguments to be too long.

# 11/18/2017 Lighting Setback Error measure developed based on HVAC Setback Error measure
# codes within ######## are modified parts

module OsLib_FDD

  require_relative 'global_const'

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
      zone_args_hash[zone_arg.name.to_s] = zone_arg unless zone_arg.isPlenum || zone_arg.canBePlenum
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

  def obtainzone(strname, model, runner, user_arguments)
    # This function helps to obtain the zone information from user arguments.
    # It returns the ThermalZone OpenStudio object of the chosen zone
    zones = model.getThermalZones.select { |zone| !zone.isPlenum && !zone.canBePlenum }
    thermalzone = runner.getStringArgumentValue(strname, user_arguments)
    if thermalzone.eql?($allzonechoices)
      return zones
    else
      thermalzones = []
      zones.each do |zone|
        next unless thermalzone.to_s == zone.name.to_s
        thermalzones << zone
        break
      end
      return thermalzones
    end
  end
  
  ##########################################################
  ##########################################################
  def obtainlight(zone, model, runner, user_arguments)
    # This function helps to obtain the light information from user arguments.
    # It returns the Lights OpenStudio object of the chosen zone
    array = []

    if zone.eql?($allzonechoices)
      model.getSpaces.each do |space|
        array << space.lights
      end
      model.getSpaceTypes.each do |space_type|
        next if not space_type.spaces.size > 0
        array << space_type.lights
      end
      return array
    else
	    model.getThermalZones.each do |zone2|
        next unless zone2.name.to_s == zone
        zone2.spaces.each do |space|
          space.hardApplySpaceType(false) # pulls in lights that were in space type
          array << space.lights
        end
        #break
      end
      return array
    end
  end

  def obtainpeople(zone, model, runner, user_arguments)
    # This function helps to obtain the people information from user arguments.
    # It returns the people OpenStudio object of the chosen zone
    array = []

    if zone.eql?($allzonechoices)
      model.getSpaces.each do |space|
        array << space.people
      end
      model.getSpaceTypes.each do |space_type|
        next if not space_type.spaces.size > 0
        array << space_type.people
      end
      return array
    else
      model.getThermalZones.each do |zone2|
        next unless zone2.name.to_s == zone
        zone2.spaces.each do |space|
          space.hardApplySpaceType(false) # pulls in lights that were in space type
          array << space.people
        end
        #break
      end
      return array
    end
  end
  ##########################################################
  ##########################################################

end
