# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

require 'date'
require 'openstudio-standards' # this is used to get min/max values from thermostat schedules for reporting purposes

# require all .rb files in resources folder
Dir[File.dirname(__FILE__) + '/resources/*.rb'].each {|file| require file }

# resource file modules
include OsLib_FDD

# start the measure
class HVACSetbackErrorNoOvernightSetback < OpenStudio::Ruleset::ModelUserScript
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'HVAC Setback Error: No Overnight Setback'
  end

  # simple human readable description
  def description
    return "Thermostat schedules are employed to raise set points for cooling and lower set points for heating at night, to switch fan operation from being continuously on during occupied times to being coupled to cooling or heating demands at other times, and to close ventilation dampers during unoccupied periods. Faults can occur due to malfunctioning, unprogrammed, or incorrectly programmed or scheduled thermostats, leading to increased energy consumption and/or compromised comfort and air quality. This measure simulates the effect of having no overnight setback by modifying the Schedule:Compact object in EnergyPlus assigned to thermostat set point schedules. The fault intensity (F) for this fault is defined as the absence of overnight HVAC setback (binary)."
  end

  # detailed human readable description about how to use the measure
  def modeler_description
    return "Four different user inputs are required to simulate the fault. The measure detects the original (non-faulted) thermostat schedule applied in EnergyPlus automatically, and adjusts the evening schedule by removing the overnight setback and replacing it with the daytime schedule. To use this Measure, choose the zone that is faulted, and the period of time what you want the fault to occur. The measure will detect the thermostat schedule of the automatically, and adjust the evening schedule to the daytime schedule. You also need to choose one day in a week (Monday, Tuesday, .....) to simulate weekly fault occurence."
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
    osdaysofweeks << $not_faulted
    osdaysofweeks << $all_days
    osdaysofweeks << $weekdaysonly
    osdaysofweeks << $weekendonly
    dayofweek = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
      'dayofweek', osdaysofweeks, true
    )
    dayofweek.setDisplayName('Day of the week')
    dayofweek.setDefaultValue($all_days)
    args << dayofweek

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
    dayofweek = runner.getStringArgumentValue('dayofweek', user_arguments)
    if dayofweek == $not_faulted
      runner.registerAsNotApplicable('Measure HVACSetbackErrorNoOvernightSetback not run')
    else
      start_month = runner.getStringArgumentValue('start_month', user_arguments)
      end_month = runner.getStringArgumentValue('end_month', user_arguments)
      thermalzones = obtainzone('zone', model, runner, user_arguments)

      # create empty has to poulate when loop through zones
      setpoint_values = create_initial_final_setpoint_values_hash

      # apply fault
      thermalzones.each do |thermalzone|
        results = applyfaulttothermalzone_no_setback(thermalzone, start_month, end_month, dayofweek, runner, setpoint_values, model)

        # populate hash for min max values across zones
        if not results == false
          setpoint_values = results
        end
      end

      # register initial and final condition
      if setpoint_values[:initial_htg_min].size > 0
        runner.registerInitialCondition("Initial heating setpoints in affected zones range from #{setpoint_values[:initial_htg_min].min.round(1)} C to #{setpoint_values[:initial_htg_max].max.round(1)} C. Initial cooling setpoints in affected zones range from #{setpoint_values[:initial_clg_min].min.round(1)} C to #{setpoint_values[:initial_clg_max].max.round(1)} C.")
        runner.registerFinalCondition("Final heating setpoints in affected zones range from #{setpoint_values[:final_htg_min].min.round(1)} C to #{setpoint_values[:final_htg_max].max.round(1)} C. Final cooling setpoints in affected zones range from #{setpoint_values[:final_clg_min].min.round(1)} C to #{setpoint_values[:final_clg_max].max.round(1)} C.")
      else
        runner.registerAsNotApplicable("No changes made, selected zones may not have had setpoint schedules, or they schedules may not have been ScheduleRulesets.")
      end

    end

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
HVACSetbackErrorNoOvernightSetback.new.registerWithApplication
