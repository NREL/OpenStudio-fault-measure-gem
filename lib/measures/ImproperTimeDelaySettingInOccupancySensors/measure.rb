# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

# 11/20/2017 Improper Time Delay Setting in Occupancy Sensors measure developed based on Lighting Setback Error (Delayed Onset) measure
# codes within ######## are modified parts

require 'date'
require 'openstudio-standards' # this is used to get min/max values from thermostat schedules for reporting purposes

# require all .rb files in resources folder
Dir[File.dirname(__FILE__) + '/resources/*.rb'].each {|file| require file }

# resource file modules
include OsLib_FDD
include OsLib_FDD_occ

# start the measure
class ImproperTimeDelaySettingInOccupancySensors < OpenStudio::Ruleset::ModelUserScript
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Improper Time Delay Setting in Occupancy Sensors'
  end

  # simple human readable description
  def description
    return "Compared to scheduled lighting operation, using an occupancy sensor for the lighting control is more suitable when the space is intermittently occupied. In other words, when the space is left with the lights on for large amount of portion throughout the day, it is better to use the occupancy sensor to save the lighting energy consumption. However, setting a time delay in the occupancy sensor is a trade-off between occupant’s visual discomfort and energy savings. If the time delay is too short, chances increase for energy savings. But on the other side, lights being on and off too often increases visual discomfort for occupants in the space. 15 minutes of time delay is common in the real application, however, the setting can be improperly implemented in the field. This fault measure is based on a physical model where certain parameter(s) is changed in EnergyPlus to mimic the faulted operation; thus simulates the effect of an improper time delay setting in occupancy sensors by modifying the Schedule:Compact object in EnergyPlus assigned to lighting schedules. This fault is categorized as a fault that occur in the lighting system (controller) during the operation stage. The fault intensity (F) is defined as the delayed time setting (in hours)."
  end

  # detailed human readable description about how to use the measure
  def modeler_description
    return "The measure detects the original occupancy schedule applied in EnergyPlus, and adjusts the lighting schedule assigned to the selected zone according to the occupancy schedule with the time delay applied based on the user inputs. Five different user inputs are required to simulate the fault; zone where the fault occurs; starting month of the faulted operation, ending month of the faulted operation, day of the week when the fault occurs, time delay in hours."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # make choice argument for thermal zone
    zone_handles, zone_display_names = pass_zone(model, $allzonechoices)
    zone = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
      'zone', zone_display_names, zone_display_names, true
    )
    zone.setDefaultValue("* All Zones *")
    zone.setDisplayName("Zone. Choose #{$allzonechoices} if you want to impose the fault in all zones")
    args << zone

    osmonths = OpenStudio::StringVector.new
    $months.each do |month|
      osmonths << month
    end

    start_month = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
      'start_month', osmonths, true
    )
    start_month.setDisplayName('Fault active start month')
    start_month.setDefaultValue($months[0])
    args << start_month

    end_month = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
      'end_month', osmonths, true
    )
    end_month.setDisplayName('Fault active end month')
    end_month.setDefaultValue($months[11])
    args << end_month

    osdaysofweeks = OpenStudio::StringVector.new
    $dayofweeks.each do |day|
      osdaysofweeks << day
    end
    osdaysofweeks << $all_days
    osdaysofweeks << $weekdaysonly
    osdaysofweeks << $weekendonly
    dayofweek = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
      'dayofweek', osdaysofweeks, true
    )
    dayofweek.setDisplayName('Day of the week')
    dayofweek.setDefaultValue($all_days)
    args << dayofweek

    ext_hr = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('ext_hr', true)
    ext_hr.setDisplayName(
      'Number of operating hours delayed.'
    )
    ext_hr.setDefaultValue(1)
    args << ext_hr

    return args
    # note: the Assignment Branch Condition size is left higher than the
    # recommended minimum by Rubocop because the argument definition
    # functions are left in measure.rb to create json files automatically
  end # end the arguments method

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # get inputs
    ext_hr = runner.getDoubleArgumentValue('ext_hr', user_arguments)
    if ext_hr != 0
      start_month, end_month, thermalzones, dayofweek = \
        get_thermostat_inputs(model, runner, user_arguments)

      # create empty has to poulate when loop through zones
      setpoint_values = create_initial_final_setpoint_values_hash
		
      zone = runner.getStringArgumentValue('zone', user_arguments)
      lights = obtainlight(zone, model, runner, user_arguments)
	  
      ###########################################################################
      peoples = obtainpeople(zone, model, runner, user_arguments)
      peoples.each do |people|
        next if not people.size > 0
        lights.each do |light|
	      next if not light.size > 0
          results = applyfaulttopeople(people, light, ext_hr, start_month, end_month, dayofweek, runner, setpoint_values, model)
	    end
      end
	  
      if setpoint_values[:initial_ltg_min].size > 0
        runner.registerInitialCondition("Initial occupancy profile in affected zones range from #{setpoint_values[:initial_ltg_min].min.round(1)} to #{setpoint_values[:initial_ltg_max].max.round(1)}")
        runner.registerFinalCondition("Final occupancy profile in affected zones range from #{setpoint_values[:final_ltg_min].min.round(1)} to #{setpoint_values[:final_ltg_max].max.round(1)}.")
      else
        runner.registerAsNotApplicable("No changes made, selected zones may not have had schedules, or schedules may not have been ScheduleRulesets.")
      end
      ###########################################################################

    else
      runner.registerAsNotApplicable('Zero hour extension in Measure ' \
                                     'Improper Time Delay Setting in Occupancy Sensors. ' \
                                     'Exiting......')
    end

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
ImproperTimeDelaySettingInOccupancySensors.new.registerWithApplication
