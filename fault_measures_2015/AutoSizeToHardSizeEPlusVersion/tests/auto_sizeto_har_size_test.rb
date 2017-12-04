require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class AutoSizeToHardSizeEPlusVersion_Test < MiniTest::Unit::TestCase

  def test_good_argument_values
    # create an instance of the measure
    measure = AutoSizeToHardSizeEPlusVersion.new

    # create runner with empty OSW
    osw = OpenStudio::WorkflowJSON.new
    puts "hello"
    puts osw
    osw_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/test.osw")
    osw = OpenStudio::WorkflowJSON.load(osw_path).get
    runner = OpenStudio::Measure::OSRunner.new(osw)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/1204_a.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # create hash of argument values.
    # If the argument has a default that you want to use, you don't need it in the hash
    args_hash = {}
    #args_hash["space_name"] = "New Space"

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.has_key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end


    # temporarily change directory to the run directory and run the measure
    start_dir = Dir.pwd
    begin

      # make directory
      output_dir = "#{File.dirname(__FILE__)}/output/good_argument_values"
      FileUtils.mkdir_p(output_dir) unless File.exists?(output_dir)
      Dir.chdir(output_dir)

      # todo - try to run with CLI in test to get rid of [openstudio.measure.OSRunner] Cannot find current Workflow Step
      #cli_path = OpenStudio.getOpenStudioCLI
      #workflow_path = '../../test.osw'
      #workflow_path = File.absolute_path(workflow_path)
      #cmd = "\"#{cli_path}\" run -m -w \"#{workflow_path}\""
      #system(cmd)

      # run the measure
      measure.run(model, runner, argument_map)
      result = runner.result

      # show the output
      show_output(result)

      # assert that it ran correctly
      assert_equal("Success", result.value.valueName)
      #assert(result.info.size == 1)
      #assert(result.warnings.size == 0)
    ensure
      Dir.chdir(start_dir)
    end

    # save the model to test output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/good_argument_values/test_output.osm")
    model.save(output_file_path,true)
  end

end
