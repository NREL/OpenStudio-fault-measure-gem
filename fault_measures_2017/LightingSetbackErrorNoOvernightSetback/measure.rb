# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

# 11/18/2017 Lighting Setback Error measure developed based on HVAC Setback Error measure
# codes within ######## are modified parts
require 'date'
require 'openstudio-standards' # this is used to get min/max values from thermostat schedules for reporting purposes

# require all .rb files in resources folder
Dir[File.dirname(__FILE__) + '/resources/*.rb'].each {|file| require file }

# resource file modules
include OsLib_FDD

# start the measure
class LightingSetbackErrorNoOvernightSetback < OpenStudio::Ruleset::ModelUserScript
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'Lighting Setback Error: No Overnight Setback'
  end

  # simple human readable description
  def description
    return "Lighting should be turned off or at least reduced during unoccupied hours. However, some commissioning studies have found noticeable lighting energy use at night either because lighting schedules are improperly configured or occupants forget to turn off lights when vacating a building (Haasl, Stum, and Arney 1996; Kahn, Potter, and Haasl 2002). This measure simulates the effect of having no setback during unoccupied hours by modifying the Schedule:Compact object in EnergyPlus assigned to lighting schedules. The fault intensity (F) for this fault is defined as the absence of overnight lighting setback (binary)."
  end

  # detailed human readable description about how to use the measure
  def modeler_description
    return "Four different user inputs are required; zone where the fault occurs, starting month of the faulted operation, ending month of the faulted operation, day of the week when the fault occurs. The measure detects the original (non-faulted) lighting schedule applied in EnergyPlus automatically, and adjusts the schedule based on user inputs."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # make choice argument for thermal zone
    zone_handles, zone_display_names = pass_zone(model, $allzonechoices)
    zone = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
      'zone', zone_display_names, zone_display_names, true
    )
    zone.setDefaultValue(zone_display_names[0])
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
      runner.registerAsNotApplicable('Measure LightingSetbackErrorNoOvernightSetback not run')
    else
      start_month = runner.getStringArgumentValue('start_month', user_arguments)
      end_month = runner.getStringArgumentValue('end_month', user_arguments)
      thermalzones = obtainzone('zone', model, runner, user_arguments)

      # create empty has to poulate when loop through zones
      setpoint_values = create_initial_final_setpoint_values_hash

      ###########################################################################
      ###########################################################################
      zone = runner.getStringArgumentValue('zone', user_arguments)
      lights = obtainlight(zone, model, runner, user_arguments)
	  
      # apply fault
      lights.each do |light|
	next if not light.size > 0
        results = applyfaulttolight_no_setback(light, start_month, end_month, dayofweek, runner, setpoint_values, model)

        # populate hash for min max values across zones
        if not results == false
          setpoint_values = results
        end
      end
      ###########################################################################
      ###########################################################################

      # register initial and final condition
      if setpoint_values[:initial_ltg_min].size > 0
        runner.registerInitialCondition("Initial lighting profile in affected zones range from #{setpoint_values[:initial_ltg_min].min.round(1)} to #{setpoint_values[:initial_ltg_max].max.round(1)}")
        runner.registerFinalCondition("Final lighting profile in affected zones range from #{setpoint_values[:final_ltg_min].min.round(1)} to #{setpoint_values[:final_ltg_max].max.round(1)}.")
      else
        runner.registerAsNotApplicable("No changes made, selected zones may not have had setpoint schedules, or they schedules may not have been ScheduleRulesets.")
      end

    end

    return true
  end # end the run method
  
  def get_workspace_objects(workspace, objname)
  # This function returns the workspace objects falling into the category
  # indicated by objname
    return workspace.getObjectsByType(objname.to_IddObjectType)
  end

end # end the measure

# this allows the measure to be use by the application
LightingSetbackErrorNoOvernightSetback.new.registerWithApplication
