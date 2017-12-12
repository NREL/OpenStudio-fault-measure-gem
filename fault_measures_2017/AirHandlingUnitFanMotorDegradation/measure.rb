# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require "#{File.dirname(__FILE__)}/resources/ScheduleSearch"

$allchoices = '* ALL Fan objects *'

# start the measure
class AirHandlingUnitFanMotorDegradation < OpenStudio::Ruleset::WorkspaceUserScript
  # human readable name
  def name
    return 'Air Handling Unit Fan Motor Degradation'
  end

  # human readable description
  def description
    return "Fan motor degradation occurs due to bearing and stator winding faults, leading to a decrease in motor efficiency and an increase in overall fan power consumption. This measure simulates the air handling unit fan motor degradation by modifying either the Fan:ConstantVolume, Fan:VariableVolume, or the Fan:OnOff objects in EnergyPlus assigned to the ventilation system. The fault intensity (F) for this fault is defined as the ratio of fan motor efficiency degradation."
  end

  # human readable description of workspace approach
  def modeler_description
    return "Two user inputs are required and, based on these user inputs, the fan efficiency is recalculated to reflect the faulted operation as shown below, where η_(fan,tot,F) is the degraded total efficiency under faulted condition, η_(fan,tot) is the total efficiency under normal condition, and F is the fault intensity. η_(fan,tot,F) = η_(fan,tot)∙(1-F)"
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    ##################################################
    list = OpenStudio::StringVector.new
    cvs = workspace.getObjectsByType("Fan:ConstantVolume".to_IddObjectType)
    cvs.each do |cv|
      list << cv.name.to_s
    end
	
    ofs = workspace.getObjectsByType("Fan:OnOff".to_IddObjectType)
      ofs.each do |of|
      list << of.name.to_s
    end
	
	  vvs = workspace.getObjectsByType("Fan:VariableVolume".to_IddObjectType)
      vvs.each do |vv|
      list << vv.name.to_s
    end
	
    list << $allchoices
	
    # make choice arguments for fan
    fan_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("fan_choice", list, true)
    fan_choice.setDisplayName("Enter the name of the faulted Fan:ConstantVolume, Fan:OnOff object or Fan:VariableVolume. If you want to impose the fault on all fan objects in the building, enter #{$allchoices}")
    fan_choice.setDefaultValue($allchoices)
    args << fan_choice
    ##################################################

    # make a double argument for the fault level
    # it should range between 0 and 1. 0 means no degradation
    eff_degrad_fac = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('eff_degrad_fac', false)
    eff_degrad_fac.setDisplayName('Degradation factor of the total efficiency of the fan during the simulation period. If the fan is not faulted, set it to zero.')
    eff_degrad_fac.setDefaultValue(0.15)  # default fouling level to be 15%
    args << eff_degrad_fac

    # choice of schedules for the presence of fault. 0 for no fault and 1 means total degradation
    sch_choice = OpenStudio::Ruleset::OSArgument.makeStringArgument('sch_choice', false)
    sch_choice.setDisplayName('Enter the name of the schedule of the fault level. If you do not have a schedule, leave this blank.')
    sch_choice.setDefaultValue('')
    args << sch_choice

    return args
  end

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

    # obtain values
    fan_choice = runner.getStringArgumentValue('fan_choice', user_arguments)
    eff_degrad_fac = runner.getDoubleArgumentValue('eff_degrad_fac', user_arguments)
    sch_choice = runner.getStringArgumentValue('sch_choice', user_arguments)

    runner.registerInitialCondition("Imposing airflow restriction on #{fan_choice}.")

    # create schedule_exist
    schedule_exist = true
    if sch_choice.eql?('')
      schedule_exist = false
    end

    # read data for scheduletypelimits
    scheduletypelimits = workspace.getObjectsByType('ScheduleTypeLimits'.to_IddObjectType)

    # if a user-defined schedule is used, check if the schedule exists and if the schedule has the correct schedule type limits
    if schedule_exist
      # check if the schedule exists
      bool_schedule, schedule_type_limit, schedule_code = schedule_search(workspace, sch_choice)

      unless bool_schedule
        runner.registerError("User-defined schedule #{sch_choice} does not exist. Exiting......")
        return false
      end

      # check schedule type limit of the schedule, if it is not bounded between 0 and 1, reject it
      scheduletypelimits.each do |scheduletypelimit|
        if scheduletypelimit.getString(0).to_s.eql?(schedule_type_limit)
          if scheduletypelimit.getString(1).to_s.to_f < 0 || scheduletypelimit.getString(1).to_s.to_f > 1
            runner.registerError("User-defined schedule #{sch_choice} has a ScheduleTypeLimits outside the range 0 to 1.0. Exiting......")
            return false
          end
          break
        end
      end
    else
      # if there is no user-defined schedule, check if the fouling level is between 0 and 1
      if eff_degrad_fac < 0.0 || eff_degrad_fac > 1.0
        runner.registerError("Fan Efficiency Degradation Level #{eff_degrad_fac} for #{fan_choice} is outside the range 0 to 1.0. Exiting......")
        return false
      end
    end

    # create energyplus management system code to alter the maximum volumetric flow rate at the fan
    # create an empty string_objects to be appended into the .idf file
    string_objects = []

    # check if the Fractional Schedule Type Limit exists and create it if
    # it doesn't. It's going to be used by the schedule in this script.
    print_fractional_schedule = true
    scheduletypelimitname = 'Fraction'
    scheduletypelimits.each do |scheduletypelimit|
      if scheduletypelimit.getString(0).to_s.eql?(scheduletypelimitname)
        if scheduletypelimit.getString(1).to_s.to_f < 0 || scheduletypelimit.getString(2).to_s.to_f > 1 || !scheduletypelimit.getString(3).to_s.eql?('Continuous')
          print_fractional_schedule = false
        else
          # if the existing ScheduleTypeLimits does not satisfy the requirement, generate the ScheduleTypeLimits with a unique name
          scheduletypelimitname = "Fraction#{fan_choice.gsub(/\s+/, '').gsub('*', '')}"
        end
        break
      end
    end
    if print_fractional_schedule
      string_objects << "
        ScheduleTypeLimits,
          #{scheduletypelimitname},                             !- Name
          0,                                      !- Lower Limit Value {BasedOnField A3}
          1,                                      !- Upper Limit Value {BasedOnField A3}
          Continuous;                             !- Numeric Type
      "
    end

    # if the schedule does not exist, create a new schedule according to vol_ratio
    unless schedule_exist
      # set a unique name for the schedule according to the component and the fault
      sch_choice = "Bearing#{fan_choice.gsub(/\s+/, '').gsub('*', '')}_SCH"

      # create a Schedule:Compact object with a schedule type limit "Fractional" that are usually
      # created in OpenStudio for continuous schedules bounded by 0 and 1
      string_objects << "
        Schedule:Constant,
          #{sch_choice},         !- Name
          #{scheduletypelimitname},                       !- Schedule Type Limits Name
          #{eff_degrad_fac};                    !- Hourly Value
      "
    end

    # find the fan object to change (only Fan:ConstantVolume and Fan:OnOff will compute the correct reduction now)
    no_fan_changed = true
    object_types = %w(Fan:ConstantVolume Fan:OnOff Fan:VariableVolume) # "Fan:ZoneExhaust" to be added later

    # initialize the object for the branch
    branchs = workspace.getObjectsByType('Branch'.to_IddObjectType)
    branch_owner = branchs[0]

    object_type_chosen = object_types[0]
    follow_system = false
    airloop_name = ''
    zone_name = ''
    fannames = []
    old_effs = []
    new_deltap = 0.0
    object_types.each do |object_type|
      fans = workspace.getObjectsByType(object_type.to_IddObjectType)
      fan_chosen = fans[0]
      fans.each do |fan|
        if fan.getString(0).to_s.eql?(fan_choice) || fan_choice.eql?($allchoices)
          fan_chosen = fan
          object_type_chosen = object_type
          no_fan_changed = false
          fannames << fan.getString(0).to_s
          # calculate the new fan efficiency and pressure rise at the new rated condition
          # only calculate the new value if the fan object is found
          old_effs << fan_chosen.getDouble(2).to_f
        end
      end

      # check if the fan is autosized
      # unless no_fan_changed
        # # find the branch the fan belongs to
        # branch_located = false
        # name_branch = ''
        # branchs.each do |branch|
          # numfield = branch.numFields
          # (0..numfield).each do |i|
            # if branch.getString(i).to_s.eql?(fan_chosen.getString(0).to_s)
              # branch_owner = branch
              # name_branch = branch.getString(0).to_s
              # break
            # end
          # end
          # if branch_located
            # break
          # end
        # end
      # end
    end

    # give an error for the name if no RTU is changed
    if no_fan_changed
      runner.registerError("Measure FanMotorDegradation cannot find #{fan_choice}. Skipping......")
      return true
    end

    # write EMS Program, ProgramCallingManager and Actuators to change fan efficiency value at the degraded condition
    sch_obj_name = "Sen#{sch_choice}"
    string_objects << "
      EnergyManagementSystem:Sensor,
        #{sch_obj_name},                !- Name
        #{sch_choice},       !- Output:Variable or Output:Meter Index Key Name
        Schedule Value;    !- Output:Variable or Output:Meter Name
    "

    fannames.zip(old_effs).each do |fanname, old_eff|
      fanshortname = fanname.gsub(/\s+/, '').gsub('*', '')

      string_objects << "
        EnergyManagementSystem:Program,
          EfficiencyChange#{fanshortname},          !- Name
          SET TEMP = #{old_eff}*#{sch_obj_name};          !- Program Line 1
          SET NewEfficiency#{fanshortname} = #{old_eff}-TEMP;          !- Program Line 1
      "

      string_objects << "
        EnergyManagementSystem:ProgramCallingManager,
          EMSCallEfficiencyChange#{fanshortname},          !- Name
          AfterPredictorBeforeHVACManagers, !- EnergyPlus Model Calling Point, EndofSystemSizing will not impose the value correctly
          EfficiencyChange#{fanshortname}; !- Program Name 1
      "

      string_objects << "
        EnergyManagementSystem:Actuator,
          NewEfficiency#{fanshortname},  !- Name
          #{fanname},           !- Actuated Component Unique Name
          Fan,        !- Actuated Component Type
          Fan Total Efficiency;            !- Actuated Component Control Type
      "
    end

    # only add Output:EnergyManagementSystem if it does not exist in the code
    outputemss = workspace.getObjectsByType('Output:EnergyManagementSystem'.to_IddObjectType)
    if outputemss.size == 0
      string_objects << '
        Output:EnergyManagementSystem,
          Verbose,                 !- Actuator Availability Dictionary Reporting
          Verbose,                 !- Internal Variable Availability Dictionary Reporting
          ErrorsOnly;                 !- EMS Runtime Language Debug Output Level
      '
    end

    # add all of the strings to workspace to create IDF objects
    string_objects.each do |string_object|
      idfobject = OpenStudio::IdfObject.load(string_object)
      object = idfobject.get
      wsobject = workspace.addObject(object)
    end

    # report final condition of workspace
    runner.registerFinalCondition("Imposed efficiency degradation level at #{eff_degrad_fac} on #{fan_choice}.")

    return true
  end
end

# register the measure to be used by the application
AirHandlingUnitFanMotorDegradation.new.registerWithApplication
