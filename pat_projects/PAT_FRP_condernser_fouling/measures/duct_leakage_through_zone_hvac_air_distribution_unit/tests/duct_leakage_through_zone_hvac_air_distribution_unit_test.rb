require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

class DuctLeakageThroughZoneHVACAirDistributionUnit_Test < MiniTest::Unit::TestCase

  def test_good_argument_values

    # create an instance of the measure
    measure = DuctLeakageThroughZoneHVACAirDistributionUnit.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # make an empty workspace
    #workspace = OpenStudio::Workspace.new("Draft".to_StrictnessLevel, "EnergyPlus".to_IddFileType)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + '/in.osm')
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
    upstream_fraction = arguments[0].clone
    assert(upstream_fraction.setValue(0.2))
    argument_map["upstream_fraction"] = upstream_fraction

    # set argument values to good values
    downstream_fraction = arguments[1].clone
    assert(downstream_fraction.setValue(0.2))
    argument_map["downstream_fraction"] = downstream_fraction

    # run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result
    assert_equal("Success", result.value.valueName)

    # save the workspace to output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_output.idf")
    workspace.save(output_file_path,true)
  end

end
