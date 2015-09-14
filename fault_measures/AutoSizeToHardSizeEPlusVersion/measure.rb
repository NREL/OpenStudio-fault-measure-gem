# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

# Acknowledgement
# This Measure is written by Andrew Parker at NREL and is given to the FDD algorithm
# development team in 2/2015

# start the measure
class AutoSizeToHardSizeEPlusVersion < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Auto Size To Hard Size with EnergyPlus Version as Input"
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
    
    eplus_version = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('eplus_version', false)
    eplus_version.setDisplayName('EnergyPlus version in use')
    eplus_version.setDefaultValue(8.2)
    
    args << eplus_version

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    
    # get eplus version
    eplus_version = runner.getDoubleArgumentValue('eplus_version', user_arguments)

    # Load the libraries
    # HVAC sizing
    require_relative 'resources/HVACSizing.Model'
    
    # for logging
    msg_log = OpenStudio::StringStreamLogSink.new
    msg_log.setLogLevel(OpenStudio::Info)

    # Make a directory for the sizing run
    run_directory = "#{Dir.pwd}/SizingRun"
    if !Dir.exists?(run_directory)
      Dir.mkdir(run_directory)
    end    

    # Perform a sizing run
    model.runSizingRun("#{run_directory}", eplus_version)    
    
    # Hard-size all HVAC equipment in modeler_description
    if not model.applySizingValues
      runner.registerError("Cannot find the previous sql file with the sizing information.")
      return false
    end

    # Get all the log messages and put into output
    # for users to see.
    msg_log.logMessages.each do |msg|
      # DLM: you can filter on log channel here for now
      if /openstudio\.model\..*/.match(msg.logChannel)
        # Skip the annoying/bogus "Skipping layer" warnings
        next if msg.logMessage.include?("Skipping layer")
        if msg.logLevel == OpenStudio::Info
          runner.registerInfo(msg.logMessage)
        elsif msg.logLevel == OpenStudio::Warn
          runner.registerWarning(msg.logMessage)
        elsif msg.logLevel == OpenStudio::Error
          runner.registerError(msg.logMessage)
        end
      end
    end
 
    return true

  end
  
end

# register the measure to be used by the application
AutoSizeToHardSizeEPlusVersion.new.registerWithApplication
