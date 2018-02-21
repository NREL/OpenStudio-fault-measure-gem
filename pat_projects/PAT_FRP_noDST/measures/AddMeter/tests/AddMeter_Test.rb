require 'openstudio'

require 'openstudio/ruleset/ShowRunnerOutput'

require "#{File.dirname(__FILE__)}/../measure.rb"

require 'minitest/autorun'

class AddMeter_Test < MiniTest::Unit::TestCase

  def test_AddMeter_BadInput

    # create an instance of the measure
    measure = AddMeter.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(2, arguments.size)
    assert_equal("meter_name", arguments[0].name)
    assert_equal("reporting_frequency", arguments[1].name)

    # set argument values to bad values and run the measure
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    meter_name = arguments[0].clone
    assert(meter_name.setValue(""))
    argument_map["meter_name"] = meter_name
    measure.run(model, runner, argument_map)
    result = runner.result
    assert(result.value.valueName == "Fail")

  end

  def test_AddMeter_GoodInput

    # create an instance of the measure
    measure = AddMeter.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # make an empty model
    model = OpenStudio::Model::Model.new

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Ruleset::OSArgumentMap.new
    meter_name = arguments[0].clone
    assert(meter_name.setValue("JustATest"))
    argument_map["meter_name"] = meter_name
    reporting_frequency = arguments[1].clone
    assert(reporting_frequency.setValue("hourly"))
    argument_map["reporting_frequency"] = reporting_frequency
    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 0)
    assert(result.info.size == 1)

    #attempt to add a second meter
    # create an instance of the measure
    measure = AddMeter.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    measure.run(model, runner, argument_map)

    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    assert(result.warnings.size == 1)
    assert(result.info.size == 0)

  end

end
