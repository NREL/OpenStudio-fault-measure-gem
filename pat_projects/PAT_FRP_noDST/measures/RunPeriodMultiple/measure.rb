#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see your EnergyPlus installation or the URL below for information on EnergyPlus objects
# http://apps1.eere.energy.gov/buildings/energyplus/pdfs/inputoutputreference.pdf

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on workspace objects (click on "workspace" in the main window to view workspace objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/utilities/html/idf_page.html

#start the measure
class RunPeriodMultiple < OpenStudio::Ruleset::WorkspaceUserScript

  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Set Multiple Run Period Object"
  end

  # human readable description
  def description
    return "Set Multiple Run Period Object"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Set Multiple Run Period Object"
  end

  #define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #RunPeriodName
    runPeriodName = OpenStudio::Ruleset::OSArgument::makeStringArgument("runPeriodName",false)
    runPeriodName.setDisplayName("Run Period Name")
    runPeriodName.setDefaultValue("August")
    args << runPeriodName
    
    #BeginMonth
    beginMonth = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("beginMonth",false)
    beginMonth.setDisplayName("Begin Month (integer)")
    beginMonth.setDefaultValue(8)
    args << beginMonth

    #BeginDay
    beginDay = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("beginDay",false)
    beginDay.setDisplayName("Begin Day (integer)")
    beginDay.setDefaultValue(7)
    args << beginDay
    
    #EndMonth
    endMonth = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("endMonth",false)
    endMonth.setDisplayName("End Month (integer)")
    endMonth.setDefaultValue(8)
    args << endMonth

    #EndDay
    endDay = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("endDay",false)
    endDay.setDisplayName("End Day (integer)")
    endDay.setDefaultValue(8)
    args << endDay
    
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

    #assign the user inputs to variables
    runPeriodName = runner.getStringArgumentValue("runPeriodName",user_arguments)
    beginMonth = runner.getIntegerArgumentValue("beginMonth",user_arguments)
    endMonth = runner.getIntegerArgumentValue("endMonth",user_arguments)
    beginDay = runner.getIntegerArgumentValue("beginDay",user_arguments)
    endDay = runner.getIntegerArgumentValue("endDay",user_arguments)
    
    runPeriod = workspace.getObjectsByType("RunPeriod".to_IddObjectType)
    
    runner.registerInitialCondition("The building has #{runPeriod.size} Run Period objects.")
      
    new_object_string = "
    RunPeriod,  
      #{runPeriodName},  !- Name
      #{beginMonth},  !- Begin Month
      #{beginDay},  !- Begin Day of Month
      #{endMonth},  !- End Month
      #{endDay},  !- End Day of Month
      UseWeatherFile,  !- Day of Week for Start Day
      No,  !- Use Weather File Holidays and Special Days
      No,  !- Use Weather File Daylight Saving Period
      No,  !- Apply Weekend Holiday Rule
      Yes,  !- Use Weather File Rain Indicators
      Yes,  !- Use Weather File Snow Indicators
      1;    !- Number of Times Runperiod to be Repeated
    "
    
    idfObject = OpenStudio::IdfObject::load(new_object_string)
    object = idfObject.get
    wsObject = workspace.addObject(object)
    new_object = wsObject.get
    
    runPeriod = workspace.getObjectsByType("RunPeriod".to_IddObjectType)
    runner.registerFinalCondition("The building now has #{runPeriod.size} Run Period objects.")

    return true

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
RunPeriodMultiple.new.registerWithApplication