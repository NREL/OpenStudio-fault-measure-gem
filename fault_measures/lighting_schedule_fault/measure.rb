# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class LightingScheduleFault < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Lighting Schedule Fault"
  end

  # human readable description
  def description
    return "Replace this text with an explanation of what the measure does in terms that can be understood by a general building professional audience (building owners, architects, engineers, contractors, etc.).  This description will be used to create reports aimed at convincing the owner and/or design team to implement the measure in the actual building design.  For this reason, the description may include details about how the measure would be implemented, along with explanations of qualitative benefits associated with the measure.  It is good practice to include citations in the measure if the description is taken from a known source or if specific benefits are listed."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Replace this text with an explanation for the energy modeler specifically.  It should explain how the measure is modeled, including any requirements about how the baseline model must be set up, major assumptions, citations of references to applicable modeling resources, etc.  The energy modeler should be able to read this description and understand what changes the measure is making to the model and why these changes are being made.  Because the Modeler Description is written for an expert audience, using common abbreviations for brevity is good practice."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # argument for fraction of possible space floor area fault is applied to.
    fault_fractional_value = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("fault_fractional_value", true)
    fault_fractional_value.setDisplayName("Fault Fractional impact control")
    fault_fractional_value.setDefaultValue(1.0)
    fault_fractional_value.setDescription("Argument for fraction of possible space floor area fault is applied to.")
    args << fault_fractional_value

    # todo - add a bool argument to indicate if building has any occupancy controls, if it does not then don't skip even if space type is in occupancy_controlled_space_types array

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    fault_fractional_value = runner.getDoubleArgumentValue("fault_fractional_value", user_arguments)

    # todo - make sure fault_fractional_value is between 0 and 1

    # todo - populate with space types that have occupancy controls
    occupancy_controlled_space_types = []
    occupancy_controlled_space_types << "Banquet"

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getSchedules.size} schedules.")

    model.getSpaceTypes.each do |space_type|

      standard_space_type = space_type.standardsSpaceType
      if standard_space_type.is_initialized
        standard_space_type = standard_space_type.get
      else
        runner.registerWarning("Skipping #{space_type.name} it doesn't have standard space typ.e")
        next
      end

      # check if space type is on list to be skipped
      if occupancy_controlled_space_types.include?(standard_space_type)
        runner.registerInfo("Don't alter lights for space types that are #{standard_space_type}.")
        next
      end

      runner.registerInfo("Altering lighting schedules for Space Type #{space_type.name} which has standard type of #{standard_space_type}.")

      # todo - make a hash of cloned schedules and don't re-clone a measure again check this before clone, and populate it after
      # todo - this only makes sense if we assume that all lighting schedules that will be altered, are altered in the same way.
      cloned_lighting_schedules = {} # key is original schedule, value is cloned schedule

      # get lights for space
      space_type.lights.each do |light|
        runner.registerInfo("Found light named #{light.name}")

        # get lighting schedule
        orig_sch = light.schedule
        if not orig_sch.is_initialized
          runner.registerWarning("#{light.name} doesn't have a schedule and won't be altered.")
          next
        else

          # todo - skip with warning if not ScheduleRuleset, don't want to write code to handle multiple types of schedules

          orig_sch = orig_sch.get
        end

        # clone lighting schedule
        new_sch = orig_sch.clone(model).to_Schedule.get
        new_sch.setName("#{standard_space_type}_fault_#{orig_sch.name}")

        # connect to schedule with light
        light.setSchedule(new_sch)


        # todo - alter schedule as needed

      end


      # todo - look for lights assigned directly to spaces
      space_type.spaces.each do |space|

        # todo - get lights, then clone and alter schedules

      end

    end

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.getSchedules.size} schedules.")

    return true

  end
  
end

# register the measure to be used by the application
LightingScheduleFault.new.registerWithApplication
