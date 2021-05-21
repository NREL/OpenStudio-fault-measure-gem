# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/
require_relative 'resources/helpers'
require_relative 'resources/evolution'

ALL_LOOP_SELECTION = '* ALL Air Loops Selected *'.freeze
# start the measure
class DischargeTemperatureOffset < OpenStudio::Measure::EnergyPlusMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Discharge Temperature Offset'
  end

  # human readable description
  def description
    return 'This measure models the faulted condition of a discharge air temperature sensor/setpoint where is has a bias from what it should be.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'This measure models this fault by first appending a duct to the faulted supply loop after the supply outlet node. The setpoint value from that node is then applied to the new node with an offset as determined by the loop. The mixed air setpoint managers are then pointed to the new outlet node.'
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Measure::OSArgumentVector.new

    loops = workspace.getObjectsByType('AirLoopHVAC'.to_IddObjectType)

    names = OpenStudio::StringVector.new
    names << ALL_LOOP_SELECTION
    handles = OpenStudio::StringVector.new
    handles << ALL_LOOP_SELECTION

    loops.each do |loop|
      names << loop.name.get.to_s
      handles << loop.handle.to_s
    end

    loop_choice = OpenStudio::Ruleset::OSArgument.makeChoiceArgument('loop_choice', names, true)
    loop_choice.setDisplayName('Enter the name of the loop to apply the discharge setpoint offset on')
    loop_choice.setDefaultValue(ALL_LOOP_SELECTION)
    args << loop_choice

    offset = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('offset', true)
    offset.setDisplayName('Offset Temp')
    offset.setDefaultValue(0.0)
    args << offset

    @evolution = Evolution.new('DTO')
    @evolution.add_user_arguments(args)

    return args
  end

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

    loop_choice = runner.getStringArgumentValue('loop_choice', user_arguments)
    offset = runner.getDoubleArgumentValue('offset', user_arguments)
    @evolution.read_user_arguments(runner, user_arguments, workspace)
    @evolution.add_program(workspace)
    if loop_choice.eql? ALL_LOOP_SELECTION
      loops = workspace.getObjectsByType('AirLoopHVAC'.to_IddObjectType)
      loops.each do |loop|
        applyToLoop(runner, workspace, loop, offset, @evolution.fault_intensity_key)
      end
    else
      loop = workspace.getObjectByTypeAndName('AirLoopHVAC'.to_IddObjectType, loop_choice).get
      applyToLoop(runner, workspace, loop, offset, @evolution.fault_intensity_key)
    end
    return true
  end
end

# register the measure to be used by the application
DischargeTemperatureOffset.new.registerWithApplication
