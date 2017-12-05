require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'

require_relative '../measure.rb'

class NonStandardCharging_Test < MiniTest::Unit::TestCase

  def test_all_coils

    # create an instance of the measure
    measure = NonStandardCharging.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EnvelopeAndLoadTestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)

    # get arguments
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values
    args_hash = {}

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result
    show_output(result)
    assert_equal("Success", result.value.valueName)

    # save the workspace to output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_all_coils.idf")
    workspace.save(output_file_path,true)
  end

  def test_single_coil

    # create an instance of the measure
    measure = NonStandardCharging.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EnvelopeAndLoadTestModel_01.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)

    # get arguments
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values
    args_hash = {}
    args_hash["coil_choice"] = "Coil Cooling DX Single Speed 4"

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(workspace, runner, argument_map)
    result = runner.result
    show_output(result)
    assert_equal("Success", result.value.valueName)

    # save the workspace to output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_single_coil.idf")
    workspace.save(output_file_path,true)
  end

  def test_two_stage

    # create an instance of the measure
    measure = NonStandardCharging.new

    # create an instance of a runner
    osw_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/test.osw")
    osw = OpenStudio::WorkflowJSON.load(osw_path).get
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/1204_b.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # forward translate OSM file to IDF file
    ft = OpenStudio::EnergyPlus::ForwardTranslator.new
    workspace = ft.translateModel(model)

    # get arguments
    arguments = measure.arguments(workspace)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values
    args_hash = {}
    args_hash["coil_choice"] = "RoofTop Cooling Coil"

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash[arg.name]
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # set last weather file
    epw = OpenStudio::Path.new(File.dirname(__FILE__)) / OpenStudio::Path.new('USA_TN_Knoxville-McGhee.Tyson.AP.723260_TMY3.epw')
    runner.setLastEpwFilePath(epw.to_s)

    # temporarily change directory to the run directory and run the measure (added since this will have sizing run)
    start_dir = Dir.pwd
    begin

      # make directory
      output_dir = "#{File.dirname(__FILE__)}/output/two_stage"
      FileUtils.mkdir_p(output_dir) unless File.exists?(output_dir)
      Dir.chdir(output_dir)

      # run the measure
      measure.run(workspace, runner, argument_map)
      result = runner.result

      # show the output
      show_output(result)

      # assert that it ran correctly
      assert_equal("Success", result.value.valueName)
    ensure
      Dir.chdir(start_dir)
    end

    # save the workspace to output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/test_two_stage.idf")
    workspace.save(output_file_path,true)
  end

end
