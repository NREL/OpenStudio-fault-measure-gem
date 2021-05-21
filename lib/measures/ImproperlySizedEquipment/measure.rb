# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
require_relative 'resources/helpers'
require 'openstudio-standards'

ALL_EQUIPMENT_SELECTION = '* ALL Equipment Selected *'.freeze

class ImproperlySizedEquipment < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Improperly Sized Equipment'
  end

  # human readable description
  def description
    return 'A possible fault for HVAC equipment is improper sizing at the design stage. This fault is based on a physical model where certain perameter(s) are changed in EnergyPlus to mimic the faulted operation; this sumulated over and undersized equipment by modifying Sizing:Parameters object in EnergyPlus. The fault intensity (F) is defined as the ratio of the improper sizing relative to the corrent sizing.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'This measure simuated the effect of improperly sized equipment at design by modifying the Sizing:Parameters object and capacity fields in objects in Energy Plus. One user input is required; ratio of the desired improper size to the original sizing. '
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    names = OpenStudio::StringVector.new
    names << ALL_EQUIPMENT_SELECTION
    handles = OpenStudio::StringVector.new
    handles << ALL_EQUIPMENT_SELECTION

    Helper.get_all_equipment_objects(model).each do |object|
      names << object.name.to_s
      handles << object.handle.to_s
    end

    equip_choice = OpenStudio::Ruleset::OSArgument.makeChoiceArgument('equip_choice', handles, names, true)
    equip_choice.setDisplayName("Enter the name of the oversized coil object. If you want to impose the fault on all equipment, select \'Apply to all equipment\'")
    equip_choice.setDefaultValue(ALL_EQUIPMENT_SELECTION)
    args << equip_choice

    sizing_multiplier = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('sizing_ratio', true)
    sizing_multiplier.setDisplayName('Sizing Multiplier (greater than 0)')
    sizing_multiplier.setDefaultValue(1.0)
    args << sizing_multiplier

    hard_size = OpenStudio::Ruleset::OSArgument.makeBoolArgument('hard_size', true)
    hard_size.setDisplayName('Hard size model')
    hard_size.setDefaultValue(true)
    args << hard_size

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    equip_choice = runner.getStringArgumentValue('equip_choice', user_arguments)
    sizing_ratio = runner.getDoubleArgumentValue('sizing_ratio', user_arguments)
    hard_size = runner.getBoolArgumentValue('hard_size', user_arguments)
    if hard_size
      runner.registerInfo("Hard sizing model")
      standard = Standard.build('90.1-2004')
      if standard.model_run_sizing_run(model, "#{Dir.pwd}/SR1") == false
        return false
      end
      model.applySizingValues
      runner.registerInfo("Applying hard sized values")
    end

    if sizing_ratio.negative?
      runner.registerError("sizing_ratio: #{sizing_ratio} is less than 0, please make it a value greater than 0 and try again")
    end
    
    if equip_choice == ALL_EQUIPMENT_SELECTION
      runner.registerInfo("all equipment selected")
      Helper.get_all_equipment_objects(model).each do |object|
        Helper.change_rated_capacity(object, sizing_ratio, runner)
      end
    else
      obj = model.getModelObject(OpenStudio.toUUID(equip_choice))
      return if obj.empty?
      obj = obj.get
      Helper.change_rated_capacity(obj, sizing_ratio, runner)
    end

    return true
  end
end

# register the measure to be used by the application
ImproperlySizedEquipment.new.registerWithApplication
