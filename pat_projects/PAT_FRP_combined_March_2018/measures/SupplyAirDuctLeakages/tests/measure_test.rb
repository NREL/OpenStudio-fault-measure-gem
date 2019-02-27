require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

class SupplyAirDuctLeakages_Test < MiniTest::Unit::TestCase

  def test_single_terminal

    # create an instance of the measure
    measure = SupplyAirDuctLeakages.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + '/frp_baseline_generic_sch.osm')
    model = translator.loadModel(path)
    assert(!model.empty?)
    model = model.get

    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)

    # get arguments
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # set argument values to good values
    airterminal_choice = arguments[0].clone
    assert(airterminal_choice.setValue("Room 103 VAV Reheat"))
    argument_map["airterminal_choice"] = airterminal_choice

    # run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result
    show_output(result)
    assert_equal("Success", result.value.valueName)

    # save the workspace to output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/single_terminal_output.idf")
    workspace.save(output_file_path,true)

  end

  def test_all_terminals

    # create an instance of the measure
    measure = SupplyAirDuctLeakages.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + '/frp_baseline_generic_sch.osm')
    model = translator.loadModel(path)
    assert(!model.empty?)
    model = model.get

    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)

    # get arguments
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # set argument values to good values
    airterminal_choice = arguments[0].clone
    assert(airterminal_choice.setValue("* ALL Terminals Selected *"))
    argument_map["airterminal_choice"] = airterminal_choice

    # run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result
    show_output(result)
    assert_equal("Success", result.value.valueName)

    # save the workspace to output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/all_terminals_output.idf")
    workspace.save(output_file_path,true)

  end

end
