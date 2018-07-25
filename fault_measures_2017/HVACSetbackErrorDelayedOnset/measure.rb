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
include OsLib_FDD_hvac

# start the measure
class HVACSetbackErrorDelayedOnset < OpenStudio::Ruleset::ModelUserScript
  # define the name that a user will see, this method may be deprecated as
  # the display name in PAT comes from the name field in measure.xml
  def name
    return 'HVAC Setback Error: Delayed Onset'
  end

  # simple human readable description
  def description
    return "Thermostat schedules are employed to raise set points for cooling and lower set points for heating at night, to switch fan operation from being continuously on during occupied times to being coupled to cooling or heating demands at other times, and to close ventilation dampers during unoccupied periods. Faults can occur due to malfunctioning, unprogrammed, or incorrectly programmed or scheduled thermostats, leading to increased energy consumption and/or compromised comfort and air quality. This fault is categorized as a fault that occur in the HVAC system (controller) during the operation stage. This fault measure is based on a physical model where certain parameter(s) is changed in EnergyPlus to mimic the faulted operation; thus simulates the effect of overnight HVAC setback being delayed until unoccupied hours by modifying the Schedule:Compact object in EnergyPlus assigned to thermostat set point schedules. The fault intensity (F) defined as the delay in onset of overnight HVAC setback (in hours)."
  end

  # detailed human readable description about how to use the measure
  def modeler_description
    return "Five different user inputs are required to simulate the fault. The measure detects the original (non-faulted) thermostat schedule applied in EnergyPlus automatically, and adjusts the evening schedule based on user inputs. Note that this measure only works for buildings that become unoccupied before midnight. To use this Measure, choose the Zone that is faulted, and the period of time when you want the fault to occur. You should also enter the number of hours that the extension sustains. The measure will detect the thermostat schedule of the automatically, and adjust the evening schedule to the daytime schedule. Note that this measure only works for buildings close before midnight. You also need to choose one day in a week (Monday, Tuesday, .....) to simulate weekly fault occurence."
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
      'Number of operating hours extended to the evening.'
    )
    ext_hr.setDefaultValue(1)
    args << ext_hr

    # extend air loop availability with same intensity as thermostat setpoint
    ext_hr_airloop = OpenStudio::Measure::OSArgument.makeBoolArgument('ext_hr_airloop', true)
    ext_hr_airloop.setDisplayName('Extend Air Loop Availability with same intensity as thermostat setpoint')
    ext_hr_airloop.setDefaultValue(true)
    args << ext_hr_airloop

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
    ext_hr_airloop = runner.getBoolArgumentValue('ext_hr_airloop', user_arguments)
    air_loops = []

    if ext_hr != 0
      start_month, end_month, thermalzones, dayofweek = \
        get_thermostat_inputs_alt(model, runner, user_arguments)

      # create empty has to poulate when loop through zones
      setpoint_values = create_initial_final_setpoint_values_hash_alt

      # apply fault
        thermalzones.each do |thermalzone|
        applyfaulttothermalzone_evening_setback(
          thermalzone, ext_hr, start_month, end_month, dayofweek, runner, setpoint_values, model
        )
          if thermalzone.airLoopHVAC.is_initialized
            air_loops << thermalzone.airLoopHVAC.get
          end
        end

      if ext_hr_airloop
        runner.registerInfo("Altering availability schedule for air loops serving selected zones.")
        air_loops.uniq.each do |air_loop|
          sch = air_loop.availabilitySchedule
          if sch.to_ScheduleRuleset.is_initialized
            sch = sch.clone.to_ScheduleRuleset.get
            air_loop.setAvailabilitySchedule(sch)
            OsLib_FDD_hvac.addnewscheduleruleset_ext_hr_alt(sch, ext_hr, start_month, end_month, dayofweek, 'evening')
          end
        end
      end

      # todo - this isn't useful here, since range isn't change, maybe I should calculate weighted building average thermostat based on floor area or zone volume.
      # register initial and final condition
      if setpoint_values[:initial_htg_min].size > 0
        runner.registerInitialCondition("Initial heating setpoints in affected zones range from #{setpoint_values[:initial_htg_min].min.round(1)} C to #{setpoint_values[:initial_htg_max].max.round(1)} C. Initial cooling setpoints in affected zones range from #{setpoint_values[:initial_clg_min].min.round(1)} C to #{setpoint_values[:initial_clg_max].max.round(1)} C.")
        runner.registerFinalCondition("Final heating setpoints in affected zones range from #{setpoint_values[:final_htg_min].min.round(1)} C to #{setpoint_values[:final_htg_max].max.round(1)} C. Final cooling setpoints in affected zones range from #{setpoint_values[:final_clg_min].min.round(1)} C to #{setpoint_values[:final_clg_max].max.round(1)} C.")
      else
        runner.registerAsNotApplicable("No changes made, selected zones may not have had setpoint schedules, or they schedules may not have been ScheduleRulesets.")
      end

    else
      runner.registerAsNotApplicable('Zero hour extension in Measure ' \
                                     'HVACSetbackErrorDelayedOnset. ' \
                                     'Exiting......')
    end

    return true
  end # end the run method
end # end the measure

# this allows the measure to be use by the application
HVACSetbackErrorDelayedOnset.new.registerWithApplication
