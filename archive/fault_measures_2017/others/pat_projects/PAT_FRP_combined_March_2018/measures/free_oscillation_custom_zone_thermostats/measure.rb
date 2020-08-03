# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class FreeOscillationCustomZoneThermostats < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "Free Oscillation Custom Zone Thermostats"
  end

  # human readable description
  def description
    return "This is for use when you want to regulate zones to specific temperatures before cutting the HVAC system off for free oscillation analysis. A constat schedule is used for the entire run period. Zones that do not have a thermostat won't be altered"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Argument will be made for each zone in the model and another argument for the deadband size between the heating and cooling setpoints that will center on the entered temperature."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # the name of the space to add to the model
    deadband = OpenStudio::Measure::OSArgument.makeDoubleArgument("deadband", true)
    deadband.setDisplayName("Deadband Size")
    deadband.setUnits("F")
    deadband.setDefaultValue(0.2)
    args << deadband

    # the name of the space to add to the model
    preset_shift = OpenStudio::Measure::OSArgument.makeDoubleArgument("preset_shift", true)
    preset_shift.setDisplayName("Preset Shift")
    preset_shift.setUnits("F")
    preset_shift.setDefaultValue(-4 )
    args << preset_shift

=begin
    # target temperature for each zone
    model.getThermalZones.sort.each do |zone|

      next if !zone.thermostatSetpointDualSetpoint.is_initialized

      # the name of the zone to add argument for
      zone_arg = OpenStudio::Measure::OSArgument.makeDoubleArgument("#{zone.name.to_s.downcase.gsub(" ","_")}_target", true)
      zone_arg.setDisplayName("Deadband Size For #{zone.name.to_s}")
      zone_arg.setUnits("F")
      zone_arg.setDefaultValue(20.0)
      args << zone_arg
    end
=end

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getThermalZones.size} zones.")

    deadband = runner.getDoubleArgumentValue("deadband",user_arguments)
    deadband_si =  OpenStudio.convert(deadband,'R','K').get
    preset_shift = runner.getDoubleArgumentValue("preset_shift",user_arguments)
    preset_shift_si =  OpenStudio.convert(preset_shift,'R','K').get

    # hard coded for FRP insead fo using dynamic arguments
    zone_targets ={}
    zone_targets['Room 102'] = 80.3 # orig value was 80.3
    zone_targets['Room 103'] = 82.1
    zone_targets['Room 104'] = 45.0 # orig value was 80.6
    zone_targets['Room 105'] = 81.8 # orig value was 81.8
    zone_targets['Room 106'] = 81.2
    zone_targets['Room 202'] = 83.0 # orig value was 83.0
    zone_targets['Room 203'] = 83.5 # orig value was 83.5
    zone_targets['Room 204'] = 83.5
    zone_targets['Room 205'] = 93.0 # orig value was 85.0
    zone_targets['Room 206'] = 84.1 # orig value was 84.1

    altered_zones = []
    model.getThermalZones.sort.each do |zone|

      next if !zone.thermostatSetpointDualSetpoint.is_initialized

      # create unique thermostat and assign it to the zone
      thermostat = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(model)
      zone.setThermostatSetpointDualSetpoint(thermostat)

      # target
      #target_ip = runner.getDoubleArgumentValue("#{zone.name.to_s.downcase.gsub(" ","_")}_target",user_arguments)
      target_ip = zone_targets[zone.name.to_s] + preset_shift_si
      runner.registerInfo("#{zone.name.to_s}")
      target_si = OpenStudio.convert(target_ip.to_f,'F','C').get

      # heating setpoint
      htg_sch = OpenStudio::Model::ScheduleConstant.new(model)
      htg_sch.setName("#{zone.name.to_s} htg")
      htg_sch.setValue(target_si - (deadband_si/2.0))
      runner.registerInfo("#{zone.name.to_s} htg #{target_si - (deadband_si/2.0)}")
      thermostat.setHeatingSetpointTemperatureSchedule(htg_sch)

      # cooling setpoint
      clg_sch = OpenStudio::Model::ScheduleConstant.new(model)
      clg_sch.setName("#{zone.name.to_s} clg")
      clg_sch.setValue(target_si + (deadband_si/2.0))
      runner.registerInfo("#{zone.name.to_s} clg #{target_si + (deadband_si/2.0)}")
      thermostat.setCoolingSetpointTemperatureSchedule(clg_sch)

      altered_zones << zone

    end

    # report final condition of model
    runner.registerFinalCondition("Thermostats were altered for #{altered_zones.size} zones.")

    return true

  end
  
end

# register the measure to be used by the application
FreeOscillationCustomZoneThermostats.new.registerWithApplication
