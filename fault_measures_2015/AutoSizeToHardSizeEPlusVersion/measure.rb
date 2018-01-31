# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# Acknowledgement
# This Measure is written by Andrew Parker at NREL and is given to the FDD algorithm
# development team in 2/2015
# updated in 11/2017 based for OpenStudio 2.x openstudio-standards based solution

# start the measure
class AutoSizeToHardSizeEPlusVersion < OpenStudio::Ruleset::ModelUserScript

  require 'openstudio-standards'

  # human readable name
  def name
    return "Auto Size To Hard Size"
  end

  # human readable description
  def description
    return ""
  end

  # human readable description of modeling approach
  def modeler_description
    return ""
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # Run a sizing run and attach the resulting
    # sql file to the model.  Hard sizing methods
    # won't work unless the model has a sql file.
    model.runSizingRun("#{Dir.pwd}")

    # Hard sizing every object in the model.
    model.applySizingValues

    # Log the openstudio-standards messages to the runner
    log_messages_to_runner(runner, false)

    return true
  end

end

# register the measure to be used by the application
AutoSizeToHardSizeEPlusVersion.new.registerWithApplication
