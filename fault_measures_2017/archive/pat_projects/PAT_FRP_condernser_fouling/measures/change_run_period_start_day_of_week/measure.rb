# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class ChangeRunPeriodStartDayOfWeek < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return "Change RunPeriod Start Day Of Week"
  end

  # human readable description
  def description
    return "This is addressing issue with forward translation of OpenStudio Schedule Rulesets to Schedule Week in EnergyPlus. The start day of week for this logic appears to  apply that day of week to January 1st, however when the simulation is runEnergyPlus uses that as the day of the week for the RunPeriod, which for example may be July 25th, not January first. If I just change the start date."
  end

  # human readable description of modeling approach
  def modeler_description
    return "For this use case sill be adding additional run periods that also need proper schedule. Assumes this is run when just one run period in the model. "
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # argument for run period object type to use
    choices = OpenStudio::StringVector.new
    choices << "RunPeriod"
    choices << "RunPeriodCustomRange"
    run_period_type = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("run_period_type", choices,true)
    run_period_type.setDisplayName("Run Period Object Type to Use")
    run_period_type.setDefaultValue("RunPeriod")
    args << run_period_type

    return args
  end 

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # use the built-in error checking 
    if !runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

    # get argument
    run_period_type = runner.getStringArgumentValue("run_period_type",user_arguments)

    # report initial condition of model
    runPeriod = workspace.getObjectsByType("RunPeriod".to_IddObjectType)
    rp = runPeriod.first
    runner.registerInitialCondition("The building started with #{runPeriod.size} run periods.")

    # Get the last openstudio model
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Could not load last OpenStudio model, cannot apply measure.")
      return false
    end
    model = model.get

    # get the year
    year_description = model.yearDescription
    if not year_description.is_initialized
      runner.registerError("Can't identify year for model to choose proper start date for run period")
      return false
    end
    year_description = year_description.get
    year = year_description.calendarYear.get

    # get the begin date and month from the run period
    beginMonth = rp.getString(1).get.to_i
    beginDay = rp.getString(2).get.to_i

    # Returns the day of week (0-6, Sunday is zero).
    target_day_of_week = Date.new(year,beginMonth,beginDay).wday
    target_day_of_week =  Date::DAYNAMES[target_day_of_week]
    runner.registerInfo(" #{beginMonth}/#{beginDay}/#{year} is a #{target_day_of_week}")

    # update runperiod start day of week
    if run_period_type == "RunPeriodCustomRange"

      # add run period custom
      # custom range (for now assuming start and end year is same as OS:YearDescription calendarYear value)
      new_custom_run_period = "
      RunPeriod:CustomRange,
      #{rp.getString(0)} cr,   !- Name
      #{rp.getString(1)},      !- Begin Month
      #{rp.getString(2)},      !- Begin Day of Month
      #{year},                 !- Begin Year
      #{rp.getString(3)},      !- End Month
      #{rp.getString(4)},      !- End Day of Month
      #{year},                 !- End Year
      #{target_day_of_week},   !- Day of Week for Start Day
      #{rp.getString(6)},      !- Use Weather File Holidays and Special Days
      #{rp.getString(7)},      !- Use Weather File Daylight Saving Period
      #{rp.getString(8)},      !- Apply Weekend Holiday Rule
      #{rp.getString(9)},      !- Use Weather File Rain Indicators
      #{rp.getString(10)};     !- Use Weather File Snow Indicators
    "

      idfObject = OpenStudio::IdfObject::load(new_custom_run_period)
      run_period_custom = workspace.addObject(idfObject.get).get
      runner.registerInfo(run_period_custom.to_s)

      # delete run period
      rp.remove

    else
      rp.setString(5,target_day_of_week)
      rp.setString(13,year.to_s)
      runner.registerInfo(rp.to_s)
    end

    # report final condition of model
    runPeriod = workspace.getObjectsByType("RunPeriod".to_IddObjectType)
    runner.registerFinalCondition("The building finished with #{runPeriod.size} run periods.")
    
    return true
 
  end

end 

# register the measure to be used by the application
ChangeRunPeriodStartDayOfWeek.new.registerWithApplication
