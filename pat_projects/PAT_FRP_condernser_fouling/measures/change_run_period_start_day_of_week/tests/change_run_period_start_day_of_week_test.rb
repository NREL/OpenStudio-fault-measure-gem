require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

class ChangeRunPeriodStartDayOfWeek_Test < MiniTest::Unit::TestCase

  def test_good_argument_values

    # create an instance of the measure
    measure = ChangeRunPeriodStartDayOfWeek.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty workspace
    workspace = OpenStudio::Workspace.new("Draft".to_StrictnessLevel, "EnergyPlus".to_IddFileType)

    # get arguments
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)


    # run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result
    assert_equal("Success", result.value.valueName)

  end

end
