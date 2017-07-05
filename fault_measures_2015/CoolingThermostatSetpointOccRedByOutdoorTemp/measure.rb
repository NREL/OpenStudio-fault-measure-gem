# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require "#{File.dirname(__FILE__)}/resources/misc_eplus_func" # eplus measure script does not like require_relative

# define global variables
$heatsch = 1
$coolsch = 2
$outtmp = 'OutTmp'
$zonename = 'Zone'
$strend = 'forCoolSetptOccChange'
$heatsch_value = 'HeatSetptSch'
$coolsch_value = 'CoolSetptSch'
$occ_value = 'OccCount'
$program_name = 'CoolSetptOffsetbyOutTmp'
$setpt_act_name = 'FinalCoolSetpt'
$program_description_statement = 'cooling setpoint shift'
$err_check = false
$allzonechoices = '* All Zones *'

# start the measure
class CoolingThermostatSetpointOccRedByOutdoorTemp < OpenStudio::Ruleset::WorkspaceUserScript
  # human readable name
  def name
    return 'Thermostat cooling setpoint manual change by outdoor temperature'
  end

  # human readable description
  def description
    return 'This Measure offsets the thermostat cooling setpoint ' \
           'according to the outdoor temperature' \
           ' and to simulate the manual change of thermostat setpoint when ' \
           'outdoor temperature is higher than certain value and the ' \
           'building is occupied.'
  end

  # human readable description of workspace approach
  def modeler_description
    return 'To use this Measure, choose the zone to be faulted. Enter the ' \
           'minimum outdoor temperature that the occupant will reduce the ' \
           'outdoor temperature manually and ' \
           'the offset that the occupant will impose on the thermostat.'
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # make string arguments for zones
    zone_choice = OpenStudio::Ruleset::OSArgument.makeStringArgument('zone_choice', true)
    zone_choice.setDisplayName("Enter the name of the zone. Choose #{$allzonechoices} if you want to impose the fault in all zones")
    zone_choice.setDefaultValue($allzonechoices)
    args << zone_choice

    # make a double argument for outdoor air temperature
    min_oa_tmp = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('min_oa_tmp', false)
    min_oa_tmp.setDisplayName('Enter the minimum outdoor air temperature (C)')
    min_oa_tmp.setDefaultValue(35)
    args << min_oa_tmp

    # offset level
    offset_lvl = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('offset_lvl', true)
    offset_lvl.setDisplayName('Enter the expected occupant offset to the thermostat (C)')
    offset_lvl.setDefaultValue(2)
    args << offset_lvl

    return args
  end

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

    # obtain values
    zone_choice, min_oa_tmp, offset_lvl = _get_inputs(runner,
                                                      user_arguments)

    if offset_lvl > 0 # only continue if the system is faulted

      if zone_choice.eql?($allzonechoices)
        zones = get_workspace_objects(workspace, 'Sizing:Zone')
        zones.each do |zone|
          # write ems_program
          unless _ems_writer(workspace, runner, pass_string(zone),
                             min_oa_tmp, offset_lvl)
            return false
          end
        end
      else
        # write ems_program
        unless _ems_writer(workspace, runner, zone_choice,
                           min_oa_tmp, offset_lvl)
          return false
        end
      end
    elsif offset_lvl < 0 # say that the inputs are invalid
      runner.registerAsNotApplicable(
        "#{offset_lvl} in CoolingThermostatSetpointOccRedByOutdoorTemp" \
        ' is smaller than 0K. Skipping......'
      )
    else # not applicable
      runner.registerAsNotApplicable(
        'CoolingThermostatSetpointOccRedByOutdoorTemp is not running ' \
        "for #{zone_choice}. Skipping......"
      )
    end
    # finish program
    runner.registerFinalCondition('Imposed ' \
                                  "#{$program_description_statement}.")
    return true
  end

  def _ems_writer(workspace, runner, zone_choice, min_oa_tmp, offset_lvl)
    # This function contains all procedure of writing ems functions and all
    # error handling details. It returns true if there are no errors.
    # Otherwise false.

    # create strings of EMS program and program caller to override the
    # setpoint and offset the setpoint when outdoor temperature is higher
    # than the user value
    string_objects = []
    emsprogramname = _ems_program_writer(workspace, zone_choice, min_oa_tmp,
                                         offset_lvl, string_objects)
    ems_programcaller_writer([emsprogramname],
                             'BeginTimestepBeforePredictor', string_objects)

    # create strings of EMS sensors to get the schedule value of the cooling
    # setpoint, the outdoor temperature and occupant schedule
    _ems_outdoor_node_sensor(workspace, zone_choice, string_objects)
    unless _ems_setpt_sch_sensor(workspace, runner, zone_choice, string_objects)
      return false
    end
    _ems_occ_sch_sensor(workspace, zone_choice, string_objects)

    # create strings of an EMS actuator to override the Cooling
    # Setpoint of the zone
    _ems_coolingsetpt_actuator(zone_choice, string_objects)

    # append a string for Output:EnergyManagementSystem object
    ems_output_writer(workspace, string_objects, err_check = $err_check)

    # write all EMS code
    append_workspace_objects(workspace, string_objects)

    # finish zone
    runner.registerInfo('Imposed ' \
                        "#{$program_description_statement}" \
                        "on #{zone_choice}.")
    return true
  end

  def _get_inputs(runner, user_arguments)
    # This function passes the inputs in user_arguments, other than the ones
    # to check if the function should run, to the run function.

    zone_choice = runner.getStringArgumentValue('zone_choice', user_arguments)
    min_oa_tmp = runner.getDoubleArgumentValue('min_oa_tmp', user_arguments)
    offset_lvl = runner.getDoubleArgumentValue('offset_lvl', user_arguments)
    runner.registerInitialCondition('Imposing ' \
                                    "#{$program_description_statement} on"\
                                    "#{zone_choice}.")
    return zone_choice, min_oa_tmp, offset_lvl
  end

  def _ems_program_writer(workspace, zone_choice,
                          min_oa_tmp, offset_lvl, string_objects)
    # This function writes an ems program that changes the cooling setpoint in
    # the zone zon_choice depending on the outdoor temperature. If the outdoor
    # air temperature is above min_oa_tmp (in C), it reduces the setpoint by
    # offset_lvl. It pushes the program string into string_objects
    # and always returns the name of the program

    emsprogramname = _unique_name_generator(zone_choice, $program_name)
    string_objects << "
      EnergyManagementSystem:Program,
        #{emsprogramname}, !- Name
        SET OutTmp = #{_unique_name_generator(zone_choice, $outtmp)}, !- Declare variables
        SET OffSet = #{offset_lvl},
        SET MinOutTmp = #{min_oa_tmp},
        SET HeatOriSetpt = #{_unique_name_generator(zone_choice, $heatsch_value)},
        SET CoolOriSetpt = #{_unique_name_generator(zone_choice, $coolsch_value)},
        SET OccValue = #{_unique_name_generator(zone_choice, $occ_value)},
        IF OutTmp > MinOutTmp && OccValue > 0.001, !- Impose the offset when there are people adjusting the thermostat setpt. by outdoor temperature
        SET #{_unique_name_generator(zone_choice, $setpt_act_name)} = CoolOriSetpt-OffSet,
        IF HeatOriSetpt > #{_unique_name_generator(zone_choice, $setpt_act_name)}, !- use the heating setpoint instead if the heating setpoint becomes too low
        SET #{_unique_name_generator(zone_choice, $setpt_act_name)} = HeatOriSetpt,
        ENDIF,
        ELSE,
        SET #{_unique_name_generator(zone_choice, $setpt_act_name)} = CoolOriSetpt,
        ENDIF;
    "

    return emsprogramname
  end

  def _unique_name_generator(zone_choice, varname)
    # This function stores a pseudo-unique names of variables depending
    # on the name of the zone and returns the names

    return varname + name_cut(zone_choice) + $strend
  end

  def _ems_outdoor_node_sensor(workspace, zone_choice, string_objects)
    # This function creates an EMS sensor for outdoor temperature
    # into the string_objects

    # find the name of the system node referring to the outdoor temperature
    outdoornodename = find_outdoor_node_name(workspace)

    string_objects << ems_sensor_str(_unique_name_generator(zone_choice,
                                                            $outtmp),
                                     outdoornodename,
                                     'System Node Temperature')

    return true
  end

  def _ems_setpt_sch_sensor(workspace, runner, zone_choice, string_objects)
    # This function pushes the ems sensor script for cooling setpoint schedule
    # to string_objects. It returns true if the schedule can be found. Otherwise,
    # it returns false.

    # find the Schedule:Year object related to the zone through
    # ThermostatSetpoint:DualSetpoint and ZoneControl:Thermostat object
    heatsch_name, coolsch_name, sch_exist =  _get_setpt_sch(workspace, zone_choice)
    unless sch_exist
      runner.registerError("Cannot find #{zone_choice} in "\
                           'CoolingThermostatSetpointOccRedByOutdoorTemp.' \
                           ' Exiting......')
      return false
    end

    # append the required string to string_objects
    string_objects << ems_sensor_str(_unique_name_generator(zone_choice,
                                                            $heatsch_value),
                                     heatsch_name,
                                     'Schedule Value')
    string_objects << ems_sensor_str(_unique_name_generator(zone_choice,
                                                            $coolsch_value),
                                     coolsch_name,
                                     'Schedule Value')
    return true
  end

  def _get_setpt_sch(workspace, zone_choice)
    # This function finds the names of the Schedule:Year objects that contains the
    # setpoints of the zone named zone_choice in workspace. It returns the
    # name of the heating setpoint schedule and cooling setpoint schedule and a true
    # boolean if it finds the zone. Otherwise, it returns multiple false.

    zonectrl, zoneexist = _find_zonectrl(workspace, zone_choice)
    return false, false, false unless zoneexist
    thermostatname = pass_string(zonectrl, 5)

    # find the name of the heating setpoint schedule
    return _fin_thermostat_sch(workspace, thermostatname, $heatsch),
      _fin_thermostat_sch(workspace, thermostatname, $coolsch), true
  end

  def _find_zonectrl(workspace, zone_choice)
    # This function returns the ZoneControl:Thermostat object related to zone_choice.
    # It returns two falses if the zone cannot be found, and returns the
    # ZoneControl:Thermostat object and a true if it finds the zone

    zonectrls = get_workspace_objects(workspace, 'ZoneControl:Thermostat')
    return false, false unless zonectrls.length > 0
    finzonectrl = zonectrls[0]
    zonectrls.each do |zonectrl|
      zone_name = pass_string(zonectrl, 1)
      if zone_name.eql?(zone_choice)
        finzonectrl = zonectrl
        break
      end
    end
    return finzonectrl, true
  end

  def _fin_thermostat_sch(workspace, thermostatname, schpos = 1)
    # This function returns the name of the setpoint schedule in the
    # thermostatname. When schpos = 1, it returns the heating setpoint
    # schedule name. If schpos = 2, it returns the cooling setpoint schedule
    # name.

    thermostatsetpts = \
      get_workspace_objects(workspace, 'ThermostatSetpoint:DualSetpoint')
    thermostatsetptsch = pass_string(thermostatsetpts[0], schpos)
    thermostatsetpts.each do |thermostatsetpt|
      curthermostatname = pass_string(thermostatsetpt, 0)
      if curthermostatname.eql?(thermostatname)
        thermostatsetptsch = pass_string(thermostatsetpt, schpos)
        break
      end
    end
    return thermostatsetptsch
  end

  def _ems_occ_sch_sensor(workspace, zone_choice, string_objects)
    # This function imposes an EMS sensor for the people count
    # in the zone

    string_objects << ems_sensor_str(_unique_name_generator(zone_choice,
                                                            $occ_value),
                                     zone_choice,
                                     'Zone People Occupant Count')
    return true
  end

  def _ems_coolingsetpt_actuator(zone_choice, string_objects)
    # This function pushes an EMS actuator for the zone cooling setpoint
    # of the zone zone_choice into string_objects. It returns true after that.

    string_objects << ems_actuator_str(_unique_name_generator(zone_choice,
                                                              $setpt_act_name),
                                       zone_choice, 'Zone Temperature Control',
                                       'Cooling Setpoint')
    return true
  end
end

# register the measure to be used by the application
CoolingThermostatSetpointOccRedByOutdoorTemp.new.registerWithApplication
