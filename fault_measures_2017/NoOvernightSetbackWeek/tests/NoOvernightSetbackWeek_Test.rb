require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require_relative '../measure.rb'
require 'fileutils'

class NoOvernightSetbackWeek_Test < MiniTest::Unit::TestCase

  # method to apply arguments, run measure, and assert results (only populate args hash with non-default argument values)
  def apply_measure_to_model(test_name, args, model_name = nil, result_value = 'Success', warnings_count = 0, info_count = nil)

    # create an instance of the measure
    measure = NoOvernightSetbackWeek.new

    # create an instance of a runner
    runner = OpenStudio::Ruleset::OSRunner.new

    if model_name.nil?
      # make an empty model
      model = OpenStudio::Model::Model.new
    else
      # load the test model
      translator = OpenStudio::OSVersion::VersionTranslator.new
      path = OpenStudio::Path.new(File.dirname(__FILE__) + "/" + model_name)
      model = translator.loadModel(path)
      assert((not model.empty?))
      model = model.get
    end

    # get arguments
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Ruleset.convertOSArgumentVectorToMap(arguments)

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args.has_key?(arg.name)
        assert(temp_arg_var.setValue(args[arg.name]),"could not set #{arg.name} to #{args[arg.name]}.")
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    puts "measure results for #{test_name}"
    show_output(result)

    # assert that it ran correctly
    if result_value.nil? then result_value = 'Success' end
    assert_equal(result_value, result.value.valueName)

    # check count of warning and info messages
    unless info_count.nil? then assert(result.info.size == info_count) end
    unless warnings_count.nil? then assert(result.warnings.size == warnings_count, "warning count (#{result.warnings.size}) did not match expectation (#{warnings_count})") end

    # if 'Fail' passed in make sure at least one error message (while not typical there may be more than one message)
    if result_value == 'Fail' then assert(result.errors.size >= 1) end

    # save the model to test output directory
    output_file_path = OpenStudio::Path.new(File.dirname(__FILE__) + "/output/#{test_name}_test_output.osm")
    model.save(output_file_path,true)
  end

  def test_single_zone
    args = {}
    args["zone"] = 'Cafe_Flr_1 ZN'

    apply_measure_to_model(__method__.to_s.gsub('test_',''), args, 'temp_2004_lg_hotel_chicago.osm')
  end

  # todo - this test model has had thermostat setpoints removed from basement, but it still has thermostatSetpointDualSetpoint object, so it doesn't test that section of code
  def test_all_zones
    args = {}
    args["zone"] = '* All Zones *'

    apply_measure_to_model(__method__.to_s.gsub('test_',''), args, 'temp_2004_lg_hotel_chicago.osm',"Success",1)
  end

  def test_partial_year
    args = {}
    args["zone"] = 'Cafe_Flr_1 ZN'
    args["start_month"] = 'May'
    args["end_month"] = 'August'
    apply_measure_to_model(__method__.to_s.gsub('test_',''), args, 'temp_2004_lg_hotel_chicago.osm')
  end

  def test_monday
    args = {}
    args["zone"] = 'Cafe_Flr_1 ZN'
    args["osdaysofweeks"] = 'Monday'
    apply_measure_to_model(__method__.to_s.gsub('test_',''), args, 'temp_2004_lg_hotel_chicago.osm')
  end

  def test_weekdays
    args = {}
    args["zone"] = 'Cafe_Flr_1 ZN'
    args["osdaysofweeks"] = 'Weekdays'
    apply_measure_to_model(__method__.to_s.gsub('test_',''), args, 'temp_2004_lg_hotel_chicago.osm')
  end

  def test_not_faulted
    args = {}
    args["zone"] = 'Cafe_Flr_1 ZN'
    args["osdaysofweeks"] = 'Not faulted'
    apply_measure_to_model(__method__.to_s.gsub('test_',''), args, 'temp_2004_lg_hotel_chicago.osm')
  end

end
