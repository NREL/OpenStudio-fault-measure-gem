# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require "#{File.dirname(__FILE__)}/resources/misc_eplus_func" # eplus measure script does not like require_relative
require "#{File.dirname(__FILE__)}/resources/costcal"

# define global variables
$zonetempprogname = 'ZoneTempCopyForEval'
$zonerelhumprogname = 'ZoneRelHumCopyForEval'
$zonesetptprogname = 'ZoneSetptCopyForEval'
$eleccostprogname = 'ElecCostForEval'
$eleccostgbvar = 'ElecCostGb'
$gascostprogname = 'GasCostForEval'
$gascostgbvar = 'GasCostGb'
$totalcostprogname = 'TotalCostForEval'
$floorareaprogname = 'FloorAreaProg'
$strend = 'forOFE'
$err_check = false

# start the measure
class OutputForEvaluation < OpenStudio::Ruleset::WorkspaceUserScript
  # human readable name
  def name
    return 'Calculate new outputs for evaluating FDD algorithm performance'
  end

  # human readable description
  def description
    return 'This Measure creates new outputs by EMS for the evaluation of FDD' \
     ' algorithms. This includes real zone temperature, real setpoint ' \
     '(only correct in the baseline case), outdoor air volumetric flow ' \
     'rate (including infltration and mechanical ventilation), energy cost' \
     ' at each time instant (with average US cost), the number of zone' \
     ' occupant.'
  end

  # human readable description of workspace approach
  def modeler_description
    return 'This Meausre requires the electricity cost US$/kWh and the gas cost ' \
      'US$/therm for the calculation of energy cost per time instant'
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # make a double argument for electricity cost
    cost_per_kwh = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('cost_per_kwh', true)
    cost_per_kwh.setDisplayName('Enter the electricity cost (US$/kWh)')
    cost_per_kwh.setDefaultValue(0.0986)
    args << cost_per_kwh

    # offset level
    cost_per_ccf = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('cost_per_ccf', true)
    cost_per_ccf.setDisplayName('Enter the gas cost (US$/ccf)')
    cost_per_ccf.setDefaultValue(7.25)
    args << cost_per_ccf

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
    elec_cost_per_j, gas_cost_per_j = _get_inputs(runner, user_arguments)

    # write ems_program
    unless _ems_writer(workspace, runner, elec_cost_per_j, gas_cost_per_j)
      return false
    end

    # finish program
    runner.registerFinalCondition('Imposed ' \
                                  "#{$program_description_statement}")
    return true
  end

  def _ems_writer(workspace, runner, elec_cost_per_j, gas_cost_per_j)
    # This function contains all procedure of writing ems functions and all
    # error handling details. It returns true if there are no errors.
    # Otherwise false.

    # create strings of EMS program for zone real temperature
    string_objects = []
    programnames = _ems_program_writer(workspace, elec_cost_per_j,
                                       gas_cost_per_j, string_objects)

    # write ems caller for all programs
    ems_programcaller_writer(programnames,
                             'EndOfZoneTimestepAfterZoneReporting',
                             string_objects)

    # append zone infiltration flow rate Output:Variable,
    # zone mechanical ventilation flow rate Output:Variable,
    # an Output:Variable for Zone occupant count, and an Output:Variable
    # for environment temperature and an Output:Variable for environmental
    # relative humidity
    string_objects += [outputvariable_str(
      '*', 'Zone Infiltration Current Density Volume Flow Rate'
    ), outputvariable_str(
      '*', 'Zone Mechanical Ventilation Current Density Volume Flow Rate'
    ), outputvariable_str(
      '*', 'Zone People Occupant Count'
    ), outputvariable_str(
      '*', 'Site Outdoor Air Drybulb Temperature'
    ), outputvariable_str(
      '*', 'Site Outdoor Air Relative Humidity'
    ), outputvariable_str(
      '*', 'Zone Thermostat Heating Setpoint Temperature'
    ), outputvariable_str(
      '*', 'Zone Thermostat Cooling Setpoint Temperature'
    )]

    # append a string for Output:EnergyManagementSystem object
    ems_output_writer(workspace, string_objects, err_check = $err_check)

    # write all EMS code
    append_workspace_objects(workspace, string_objects)
    return true
  end

  def _get_inputs(runner, user_arguments)
    # This function passes the inputs in user_arguments, other than the ones
    # to check if the function should run, to the run function.

    cost_per_kwh = runner.getDoubleArgumentValue('cost_per_kwh', user_arguments)
    cost_per_ccf = runner.getDoubleArgumentValue('cost_per_ccf', user_arguments)
    runner.registerInitialCondition('Imposing ' \
                                    "#{$program_description_statement}")
    return elec_cost_conversion(cost_per_kwh), gas_cost_conversion(cost_per_ccf)
  end

  def _ems_program_writer(workspace, elec_cost_per_j,
                          gas_cost_per_j, string_objects)
    # This function creates all ems programs and all related EMS and Output:Variable
    # objects to output real zone air temperature, zone setpoint temperature,
    # electricity cost, gas cost, total energy cost and zone area. Return an array
    # of all EMS Program names, and append all object statements in string_objects.

    programnames = []
    programnames << _ems_temp_program_writer(workspace, string_objects)
    programnames << _ems_relhum_program_writer(workspace, string_objects)

    # create strings of EMS program for zone setpoint temperature
    programnames << _ems_tempsetpt_program_writer(workspace, string_objects)

    # create strings of EMS program that estimates the energy cost per timestep
    programnames << _ems_eleccost_program_writer(workspace, elec_cost_per_j,
                                                 string_objects)
    programnames << _ems_gascost_program_writer(workspace, gas_cost_per_j,
                                                string_objects)
    programnames << _ems_energycost_program_writer(workspace, string_objects)

    # create strings for an EMS program to output zone area
    programnames << _ems_zonearea_program_writer(workspace, string_objects)

    return programnames
  end

  def _ems_temp_program_writer(workspace, string_objects)
    # This function writes an ems program that copies the zone temperature
    # to another variable so that it will not be affected by any reporting
    # measure for thermostat bias. It generates one EMS program for copying
    # temperature and multiple EMS:Sensor, EMS:OutputVarialbe and OutputVariable
    # objects to output the real zone temperature. Returns the program name.

    misc_objects = []
    prog_line = "
      EnergyManagementSystem:Program,
        #{$zonetempprogname}, !- Name
    "
    zones = get_workspace_objects(workspace, 'Zone')
    ncase = zones.length
    zones.each_with_index do |zone, i|
      # create sensors for zone air temperature
      # and push in EMS OutputVariable and Output:Variable objects
      int_prog_line, int_misc_objects = _ems_temp_program_statement_writer(zone, i, ncase)
      prog_line += int_prog_line
      misc_objects += int_misc_objects
    end
    # enter the EMS program first before other things
    append_string_objects(string_objects, misc_objects.unshift(prog_line))

    return $zonetempprogname
  end

  def _ems_temp_program_statement_writer(zone, index, ncase)
    # This function returns an intermediate program line and an array of sensor and
    # output:variable object of the EMS program that copies zone air temperature

    zone_name = pass_string(zone, 0)
    emsoldvarname = _unique_name_generator(zone_name, 'OriTemp')
    emsnewvarname = "#{emsoldvarname}EMSRealTemp"
    prog_line = "
      SET #{emsnewvarname} = #{emsoldvarname}#{endstrchecker(index, ncase)} !- Program Line
    "
    # create sensors for zone air temperature
    # and push in EMS OutputVariable and Output:Variable objects
    misc_objects = \
      [ems_sensor_str(emsoldvarname, zone_name, 'Zone Air Temperature')] + \
      ems_outputvar_creator("#{zone_name} Real Temperature", emsnewvarname,
                            1, 1, $zonetempprogname, 'C')

    return prog_line, misc_objects
  end

  def _ems_relhum_program_writer(workspace, string_objects)
    # This function writes an ems program that copies the zone relative humidity
    # to another variable so that it will not be affected by any reporting
    # measure for thermostat bias. It generates one EMS program for copying
    # relative humidity and multiple EMS:Sensor, EMS:OutputVarialbe and OutputVariable
    # objects to output the real zone relative humidity. Returns the program name.

    misc_objects = []
    prog_line = "
      EnergyManagementSystem:Program,
        #{$zonerelhumprogname}, !- Name
    "
    zones = get_workspace_objects(workspace, 'Zone')
    ncase = zones.length
    zones.each_with_index do |zone, i|
      # create sensors for zone air temperature
      # and push in EMS OutputVariable and Output:Variable objects
      int_prog_line, int_misc_objects = _ems_relhum_program_statement_writer(zone, i, ncase)
      prog_line += int_prog_line
      misc_objects += int_misc_objects
    end
    # enter the EMS program first before other things
    append_string_objects(string_objects, misc_objects.unshift(prog_line))

    return $zonerelhumprogname
  end

  def _ems_relhum_program_statement_writer(zone, index, ncase)
    # This function returns an intermediate program line and an array of sensor and
    # output:variable object of the EMS program that copies zone air relative humidity

    zone_name = pass_string(zone, 0)
    emsoldvarname = _unique_name_generator(zone_name, 'OriRelHum')
    emsnewvarname = "#{emsoldvarname}EMSRealRelHum"
    prog_line = "
      SET #{emsnewvarname} = #{emsoldvarname}#{endstrchecker(index, ncase)} !- Program Line
    "
    # create sensors for zone air temperature
    # and push in EMS OutputVariable and Output:Variable objects
    misc_objects = \
      [ems_sensor_str(emsoldvarname, zone_name, 'Zone Air Relative Humidity')] + \
      ems_outputvar_creator("#{zone_name} Real Relative Humidity", emsnewvarname,
                            1, 1, $zonerelhumprogname, '%')

    return prog_line, misc_objects
  end

  def _ems_tempsetpt_program_writer(workspace, string_objects)
    # This function writes an ems program that copies the zone setpoint temperature
    # to another variable so that it will not be affected by any reporting
    # measure for thermostat bias. It generates one EMS program for copying
    # temperature and multiple EMS:Sensor, EMS:OutputVarialbe and OutputVariable
    # objects to output the real zone temperature. Returns the program name.

    misc_objects = []
    prog_line = "
      EnergyManagementSystem:Program,
        #{$zonesetptprogname}, !- Name
    "
    zones = get_workspace_objects(workspace, 'Zone')
    ncase = zones.length
    zones.each_with_index do |zone, i|
      # not all zone has setpoints. Check that first
      next unless _findzonenode(workspace, pass_string(zone, 0))
      int_prog_line, int_misc_objects = \
        _ems_tempsetpt_program_statement_writer(workspace, zone, i, ncase)
      prog_line += int_prog_line
      misc_objects += int_misc_objects
    end
    # enter the EMS program first before other things
    append_string_objects(string_objects, misc_objects.unshift(prog_line))

    return $zonesetptprogname
  end

  def _ems_tempsetpt_program_statement_writer(workspace, zone, index, ncase)
    # This function returns an intermediate program line and an array of sensor and
    # output:variable object of the EMS program that copies zone setpoint temperature

    zone_name = pass_string(zone, 0)
    emsoldvarname = _unique_name_generator(zone_name, 'Setpt')
    emsnewvarname = "#{emsoldvarname}EMSRealTemp"
    prog_line = "
      SET #{emsnewvarname} = #{emsoldvarname}#{endstrchecker(index, ncase)} !- Program Line
    "
    # create sensors for zone air temperature with the system node name
    #  and push in EMS OutputVariable and Output:Variable objects
    misc_objects = [
      ems_sensor_str(
        emsoldvarname, _findzonenode(workspace, zone_name),
        'System Node Setpoint Temperature'
      )
    ] + ems_outputvar_creator(
      "#{zone_name} Real Setpoint Temperature",
      emsnewvarname, 1, 1, $zonesetptprogname, 'C'
    )

    return prog_line, misc_objects
  end

  def _findzonenode(workspace, zone_name)
    # This function returns the node name of the zone named as zone_name.
    # Return false if it cannot find it

    zoneconns = get_workspace_objects(workspace,
                                      'ZoneHVAC:EquipmentConnections')
    zoneconns.each do |zoneconn|
      next unless pass_string(zoneconn, 0).eql?(zone_name)
      return pass_string(zoneconn, 4)
    end
    return false
  end

  def  _ems_eleccost_program_writer(workspace, elec_cost_per_j, string_objects)
    # This function creates a statement that estimates (by EMS) and
    # outputs (by OutputVariable) electricity cost per timestep.

    elecamoutnname = "ElecAmount#{$strend}"
    string_objects << "
      EnergyManagementSystem:Program,
        #{$eleccostprogname}, !- Name
        SET #{$eleccostgbvar} = #{elecamoutnname}*#{elec_cost_per_j}; !- Program Line
      "
    # create a sensor for electricity:facility
    string_objects << ems_sensor_str(elecamoutnname, '',
                                     'Electricity:Facility')
    # create an output variable for electricity cost
    string_objects << ems_outputvar_creator(
      'Estimated facility electricity cost per timestep',
      $eleccostgbvar, 1, 1, $eleccostprogname, 'US$'
    )
    # create a global variable to store the electricity cost
    string_objects << ems_globalvariable_str($eleccostgbvar)
    string_objects.flatten!

    return $eleccostprogname
  end

  def  _ems_gascost_program_writer(workspace, gas_cost_per_j, string_objects)
    # This function creates a statement that estimates (by EMS) and
    # outputs (by OutputVariable) gas cost per timestep.

    gasamoutnname = "GasAmount#{$strend}"
    string_objects << "
      EnergyManagementSystem:Program,
        #{$gascostprogname}, !- Name
        SET #{$gascostgbvar} = #{gasamoutnname}*#{gas_cost_per_j}; !- Program Line
      "
    # create a sensor for gastricity:facility
    string_objects << ems_sensor_str(gasamoutnname, '',
                                     'Gas:Facility')
    # create an output variable for gas cost
    string_objects << ems_outputvar_creator('Estimated gas cost per ' \
                                            'timestep',
                                            $gascostgbvar, 1, 1,
                                            $gascostprogname, 'US$')
    # create a global variable to store the gastricity cost
    string_objects << ems_globalvariable_str($gascostgbvar)
    string_objects.flatten!

    return $gascostprogname
  end

  def _ems_energycost_program_writer(workspace, string_objects)
    # This function creates a statement that estimates (by EMS) and
    # outputs (by OutputVariable) total energy cost per timestep.

    totalcostname = "TotalEnergyCost#{$strend}"
    string_objects << "
      EnergyManagementSystem:Program,
        #{$totalcostprogname}, !- Name
        SET #{totalcostname} = #{$gascostgbvar}+#{$eleccostgbvar}; !- Program Line
      "
    # create an output variable for total energy cost
    string_objects << ems_outputvar_creator('Estimated totel energy ' \
                                            'cost per timestep',
                                            totalcostname, 1, 1,
                                            $totalcostprogname, 'US$')
    string_objects.flatten!

    return $totalcostprogname
  end

  def _ems_zonearea_program_writer(workspace, string_objects)
    # This function outputs the floor area of all zones

    misc_objects = []
    prog_line = "
      EnergyManagementSystem:Program,
        #{$floorareaprogname}, !- Name
    "
    zones = get_workspace_objects(workspace, 'Zone')
    ncase = zones.length
    zones.each_with_index do |zone, i|
      int_prog_line, int_misc_objects = \
        _ems_zonearea_program_statement_writer(zone, i, ncase)
      prog_line += int_prog_line
      misc_objects += int_misc_objects
    end
    # enter the EMS program first before other things
    append_string_objects(string_objects, misc_objects.unshift(prog_line))

    return $floorareaprogname
  end

  def _ems_zonearea_program_statement_writer(zone, index, ncase)
    # This function returns an intermediate program line and an array of sensor and
    # output:variable object of the EMS program that copies zone area

    zone_name = pass_string(zone, 0)
    floorareavarname = _unique_name_generator(zone_name, 'Area')
    newfloorareavarname = "#{floorareavarname}EMS"
    prog_line = "
      SET #{newfloorareavarname} = #{floorareavarname}#{endstrchecker(index, ncase)} !- Program Line
    "
    # create sensors for zone air temperature
    # and push in EMS OutputVariable and Output:Variable objects
    misc_objects = [
      ems_internalvariable_str(floorareavarname, zone_name, 'Zone Floor Area')
    ] + ems_outputvar_creator("#{zone_name} Floor Area",
                              newfloorareavarname, 1, 1, $floorareaprogname, 'm2')

    return prog_line, misc_objects
  end

  def _unique_name_generator(zone_choice, varname)
    # This function stores a pseudo-unique names of variables depending
    # on the name of the zone and returns the names

    return varname + name_cut(zone_choice) + $strend
  end
end

# register the measure to be used by the application
OutputForEvaluation.new.registerWithApplication
