require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'

begin
  require 'openstudio_measure_tester/test_helper'
rescue LoadError
  puts "OpenStudio Measure Tester Gem not installed -- will not be able to aggregate and dashboard the results of tests"
end

require_relative '../measure.rb'
require 'minitest/autorun'

class SpaceTypeAndConstructionSetWizard_Test < MiniTest::Test

  
  def test_empty_seed

    test_name = "empty_seed"
     
    # create an instance of the measure
    measure = SpaceTypeAndConstructionSetWizard.new
    
    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EmptySeedModel.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get
    
    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(6, arguments.size)
    count = -1
    assert_equal("building_type", arguments[count += 1].name)
    assert_equal("template", arguments[count += 1].name)
    assert_equal("climate_zone", arguments[count += 1].name)
    assert_equal("create_space_types", arguments[count += 1].name)
    assert_equal("create_construction_set", arguments[count += 1].name)
    assert_equal("set_building_defaults", arguments[count += 1].name)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    count = -1

    building_type = arguments[count += 1].clone
    #assert(building_type.setValue("MidriseApartment"))
    assert(building_type.setValue("RetailStandalone"))
    argument_map["building_type"] = building_type

    template = arguments[count += 1].clone
    #assert(template.setValue("DOE Ref 2004"))
    assert(template.setValue("90.1-2007"))
    argument_map["template"] = template

    climate_zone = arguments[count += 1].clone
    assert(climate_zone.setValue("ASHRAE 169-2006-5A"))
    argument_map["climate_zone"] = climate_zone

    create_space_types = arguments[count += 1].clone
    assert(create_space_types.setValue(true))
    argument_map["create_space_types"] = create_space_types

    create_construction_set = arguments[count += 1].clone
    assert(create_construction_set.setValue(true))
    argument_map["create_construction_set"] = create_construction_set

    set_building_defaults = arguments[count += 1].clone
    assert(set_building_defaults.setValue(false))
    argument_map["set_building_defaults"] = set_building_defaults

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    #assert(result.warnings.size == 1)
    #assert(result.info.size == 2)

    # save the model in an output directory
    output_dir = File.expand_path('output', File.dirname(__FILE__))
    FileUtils.mkdir output_dir unless Dir.exist? output_dir
    model.save("#{output_dir}/#{test_name}_test.osm", true)
  end

  def test_med_off

    test_name = "med_of"

    # create an instance of the measure
    measure = SpaceTypeAndConstructionSetWizard.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/EmptySeedModel.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(6, arguments.size)
    count = -1
    assert_equal("building_type", arguments[count += 1].name)
    assert_equal("template", arguments[count += 1].name)
    assert_equal("climate_zone", arguments[count += 1].name)
    assert_equal("create_space_types", arguments[count += 1].name)
    assert_equal("create_construction_set", arguments[count += 1].name)
    assert_equal("set_building_defaults", arguments[count += 1].name)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    count = -1

    building_type = arguments[count += 1].clone
    assert(building_type.setValue("MediumOffice"))
    argument_map["building_type"] = building_type

    template = arguments[count += 1].clone
    #assert(template.setValue("DOE Ref 2004"))
    assert(template.setValue("90.1-2013"))
    argument_map["template"] = template

    climate_zone = arguments[count += 1].clone
    assert(climate_zone.setValue("ASHRAE 169-2006-3B"))
    argument_map["climate_zone"] = climate_zone

    create_space_types = arguments[count += 1].clone
    assert(create_space_types.setValue(true))
    argument_map["create_space_types"] = create_space_types

    create_construction_set = arguments[count += 1].clone
    assert(create_construction_set.setValue(true))
    argument_map["create_construction_set"] = create_construction_set

    set_building_defaults = arguments[count += 1].clone
    assert(set_building_defaults.setValue(true))
    argument_map["set_building_defaults"] = set_building_defaults

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    #assert(result.warnings.size == 1)
    #assert(result.info.size == 2)

    # save the model in an output directory
    output_dir = File.expand_path('output', File.dirname(__FILE__))
    FileUtils.mkdir output_dir unless Dir.exist? output_dir
    model.save("#{output_dir}/#{test_name}_test.osm", true)
  end

  def test_two_story_bar

    test_name = "two_story_bar"

    # create an instance of the measure
    measure = SpaceTypeAndConstructionSetWizard.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/two_story_bar.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(6, arguments.size)
    count = -1
    assert_equal("building_type", arguments[count += 1].name)
    assert_equal("template", arguments[count += 1].name)
    assert_equal("climate_zone", arguments[count += 1].name)
    assert_equal("create_space_types", arguments[count += 1].name)
    assert_equal("create_construction_set", arguments[count += 1].name)
    assert_equal("set_building_defaults", arguments[count += 1].name)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    count = -1

    building_type = arguments[count += 1].clone
    #assert(building_type.setValue("MidriseApartment"))
    assert(building_type.setValue("RetailStandalone"))
    argument_map["building_type"] = building_type

    template = arguments[count += 1].clone
    #assert(template.setValue("DOE Ref 2004"))
    assert(template.setValue("90.1-2007"))
    argument_map["template"] = template

    climate_zone = arguments[count += 1].clone
    assert(climate_zone.setValue("ASHRAE 169-2006-5A"))
    argument_map["climate_zone"] = climate_zone

    create_space_types = arguments[count += 1].clone
    assert(create_space_types.setValue(true))
    argument_map["create_space_types"] = create_space_types

    create_construction_set = arguments[count += 1].clone
    assert(create_construction_set.setValue(true))
    argument_map["create_construction_set"] = create_construction_set

    set_building_defaults = arguments[count += 1].clone
    assert(set_building_defaults.setValue(true))
    argument_map["set_building_defaults"] = set_building_defaults

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    #assert(result.warnings.size == 1)
    #assert(result.info.size == 2)

    # save the model in an output directory
    output_dir = File.expand_path('output', File.dirname(__FILE__))
    FileUtils.mkdir output_dir unless Dir.exist? output_dir
    model.save("#{output_dir}/#{test_name}_test.osm", true)
  end

  def test_super_market

    test_name = "super_market"

    # create an instance of the measure
    measure = SpaceTypeAndConstructionSetWizard.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/two_story_bar.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(6, arguments.size)
    count = -1
    assert_equal("building_type", arguments[count += 1].name)
    assert_equal("template", arguments[count += 1].name)
    assert_equal("climate_zone", arguments[count += 1].name)
    assert_equal("create_space_types", arguments[count += 1].name)
    assert_equal("create_construction_set", arguments[count += 1].name)
    assert_equal("set_building_defaults", arguments[count += 1].name)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    count = -1

    building_type = arguments[count += 1].clone
    assert(building_type.setValue("SuperMarket"))
    argument_map["building_type"] = building_type

    template = arguments[count += 1].clone
    #assert(template.setValue("DOE Ref 2004"))
    assert(template.setValue("90.1-2013"))
    argument_map["template"] = template

    climate_zone = arguments[count += 1].clone
    assert(climate_zone.setValue("ASHRAE 169-2006-5A"))
    argument_map["climate_zone"] = climate_zone

    create_space_types = arguments[count += 1].clone
    assert(create_space_types.setValue(true))
    argument_map["create_space_types"] = create_space_types

    create_construction_set = arguments[count += 1].clone
    assert(create_construction_set.setValue(true))
    argument_map["create_construction_set"] = create_construction_set

    set_building_defaults = arguments[count += 1].clone
    assert(set_building_defaults.setValue(true))
    argument_map["set_building_defaults"] = set_building_defaults

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    #assert(result.warnings.size == 1)
    #assert(result.info.size == 2)

    # save the model in an output directory
    output_dir = File.expand_path('output', File.dirname(__FILE__))
    FileUtils.mkdir output_dir unless Dir.exist? output_dir
    model.save("#{output_dir}/#{test_name}_test.osm", true)
  end

  # this is pre-data center in large office
  def test_lg_off_pre_1980

    test_name = "lg_off_pre_1980"

    # create an instance of the measure
    measure = SpaceTypeAndConstructionSetWizard.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/two_story_bar.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(6, arguments.size)
    count = -1
    assert_equal("building_type", arguments[count += 1].name)
    assert_equal("template", arguments[count += 1].name)
    assert_equal("climate_zone", arguments[count += 1].name)
    assert_equal("create_space_types", arguments[count += 1].name)
    assert_equal("create_construction_set", arguments[count += 1].name)
    assert_equal("set_building_defaults", arguments[count += 1].name)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    count = -1

    building_type = arguments[count += 1].clone
    assert(building_type.setValue("LargeOffice"))
    argument_map["building_type"] = building_type

    template = arguments[count += 1].clone
    #assert(template.setValue("DOE Ref 2004"))
    assert(template.setValue("DOE Ref Pre-1980"))
    argument_map["template"] = template

    climate_zone = arguments[count += 1].clone
    assert(climate_zone.setValue("ASHRAE 169-2006-5A"))
    argument_map["climate_zone"] = climate_zone

    create_space_types = arguments[count += 1].clone
    assert(create_space_types.setValue(true))
    argument_map["create_space_types"] = create_space_types

    create_construction_set = arguments[count += 1].clone
    assert(create_construction_set.setValue(true))
    argument_map["create_construction_set"] = create_construction_set

    set_building_defaults = arguments[count += 1].clone
    assert(set_building_defaults.setValue(true))
    argument_map["set_building_defaults"] = set_building_defaults

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    #assert(result.warnings.size == 1)
    #assert(result.info.size == 2)

    # save the model in an output directory
    output_dir = File.expand_path('output', File.dirname(__FILE__))
    FileUtils.mkdir output_dir unless Dir.exist? output_dir
    model.save("#{output_dir}/#{test_name}_test.osm", true)
  end

  # this is pre-data center in large office
  def test_small_hotel_2007

    test_name = "small_hotel_2007"

    # create an instance of the measure
    measure = SpaceTypeAndConstructionSetWizard.new

    # create an instance of a runner
    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)

    # load the test model
    translator = OpenStudio::OSVersion::VersionTranslator.new
    path = OpenStudio::Path.new(File.dirname(__FILE__) + "/two_story_bar.osm")
    model = translator.loadModel(path)
    assert((not model.empty?))
    model = model.get

    # get arguments and test that they are what we are expecting
    arguments = measure.arguments(model)
    assert_equal(6, arguments.size)
    count = -1
    assert_equal("building_type", arguments[count += 1].name)
    assert_equal("template", arguments[count += 1].name)
    assert_equal("climate_zone", arguments[count += 1].name)
    assert_equal("create_space_types", arguments[count += 1].name)
    assert_equal("create_construction_set", arguments[count += 1].name)
    assert_equal("set_building_defaults", arguments[count += 1].name)

    # set argument values to good values and run the measure on model with spaces
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    count = -1

    building_type = arguments[count += 1].clone
    assert(building_type.setValue("SmallHotel"))
    argument_map["building_type"] = building_type

    template = arguments[count += 1].clone
    assert(template.setValue("90.1-2007"))
    argument_map["template"] = template

    climate_zone = arguments[count += 1].clone
    assert(climate_zone.setValue("ASHRAE 169-2006-7A"))
    argument_map["climate_zone"] = climate_zone

    create_space_types = arguments[count += 1].clone
    assert(create_space_types.setValue(true))
    argument_map["create_space_types"] = create_space_types

    create_construction_set = arguments[count += 1].clone
    assert(create_construction_set.setValue(true))
    argument_map["create_construction_set"] = create_construction_set

    set_building_defaults = arguments[count += 1].clone
    assert(set_building_defaults.setValue(true))
    argument_map["set_building_defaults"] = set_building_defaults

    measure.run(model, runner, argument_map)
    result = runner.result
    show_output(result)
    assert(result.value.valueName == "Success")
    #assert(result.warnings.size == 1)
    #assert(result.info.size == 2)

    # save the model in an output directory
    output_dir = File.expand_path('output', File.dirname(__FILE__))
    FileUtils.mkdir output_dir unless Dir.exist? output_dir
    model.save("#{output_dir}/#{test_name}_test.osm", true)
  end

end
