# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require "#{File.dirname(__FILE__)}/resources/dynamicfaultimplementation"

$faultnow = 'FD'
$allchoices = '* ALL Fan objects *'

# start the measure
class AirHandlingUnitFanMotorDegradation < OpenStudio::Ruleset::WorkspaceUserScript
  # human readable name
  def name
    return 'Air Handling Unit Fan Motor Degradation'
  end

  # human readable description
  def description
    return "Fan motor degradation occurs due to bearing and stator winding faults, leading to a decrease in motor efficiency and an increase in overall fan power consumption. This fault is categorized as a fault that occur in the ventilation system (fan) during the operation stage. This fault measure is based on a semi-empirical model and simulates the air handling unit fan motor degradation by modifying either the Fan:ConstantVolume, Fan:VariableVolume, or the Fan:OnOff objects in EnergyPlus assigned to the ventilation system. The fault intensity (F) for this fault is defined as the ratio of fan motor efficiency degradation with the application range of 0 to 0.3 (30% degradation)."
  end

  # human readable description of workspace approach
  def modeler_description
    return "Nine user inputs are required and, based on these user inputs, the fan efficiency is recalculated to reflect the faulted operation. η_(fan,tot,F) = η_(fan,tot)∙(1-F), where η_(fan,tot,F) is the degraded total efficiency under faulted condition, η_(fan,tot) is the total efficiency under normal condition, and F is the fault intensity. The time required for the fault to reach the full level is only required when the user wants to model fault evolution. If the fault evolution is not necessary for the user, it can be defined as zero and the F will be imposed as a step function with the user defined value. However, by defining the time required for the fault to reach the full level, fault starting month/date/time and fault ending month/date/time, the adjustment factor AF is calculated at each time step starting from the starting month/date/time to gradually impose F based on the user specified time frame. AF is calculated as follows, AF_current = AF_previous + dt/tau where AF_current is the adjustment factor calculated based on the previously calculated adjustment factor (AF_previous), simulation timestep (dt) and the time required for the fault to reach the full level (tau)."
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    ##################################################
    list = OpenStudio::StringVector.new
    list << $allchoices
	  
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
	
	##################################################
    #Parameters for transient fault modeling
	#make a double argument for the time required for fault to reach full level 
    time_constant = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('time_constant', false)
    time_constant.setDisplayName('Enter the time required for fault to reach full level [hr]')
    time_constant.setDefaultValue(0)  #default is zero
    args << time_constant
	
	#make a double argument for the start month
    start_month = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_month', false)
    start_month.setDisplayName('Enter the month (1-12) when the fault starts to occur')
    start_month.setDefaultValue(1)  #default is January
    args << start_month
	
	#make a double argument for the start date
    start_date = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_date', false)
    start_date.setDisplayName('Enter the date (1-28/30/31) when the fault starts to occur')
    start_date.setDefaultValue(1)  #default is 1st day of the month
    args << start_date
	
	#make a double argument for the start time
    start_time = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_time', false)
    start_time.setDisplayName('Enter the time of day (0-24) when the fault starts to occur')
    start_time.setDefaultValue(1)  #default is 1am
    args << start_time
	
	#make a double argument for the end month
    end_month = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('end_month', false)
    end_month.setDisplayName('Enter the month (1-12) when the fault ends')
    end_month.setDefaultValue(12)  #default is Decebmer
    args << end_month
	
	#make a double argument for the end date
    end_date = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('end_date', false)
    end_date.setDisplayName('Enter the date (1-28/30/31) when the fault ends')
    end_date.setDefaultValue(31)  #default is last day of the month
    args << end_date
	
	#make a double argument for the end time
    end_time = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('end_time', false)
    end_time.setDisplayName('Enter the time of day (0-24) when the fault ends')
    end_time.setDefaultValue(23)  #default is 11pm
    args << end_time
    ##################################################

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
	##################################################
    time_constant = runner.getDoubleArgumentValue('time_constant',user_arguments).to_s
	start_month = runner.getDoubleArgumentValue('start_month',user_arguments).to_s
	start_date = runner.getDoubleArgumentValue('start_date',user_arguments).to_s
	start_time = runner.getDoubleArgumentValue('start_time',user_arguments).to_s
	end_month = runner.getDoubleArgumentValue('end_month',user_arguments).to_s
	end_date = runner.getDoubleArgumentValue('end_date',user_arguments).to_s
	end_time = runner.getDoubleArgumentValue('end_time',user_arguments).to_s
	time_step = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('time_step', false)
	dts = workspace.getObjectsByType('Timestep'.to_IddObjectType)
	dts.each do |dt|
	 runner.registerInfo("Simulation Timestep = #{1./dt.getString(0).get.clone.to_f} hour(s)")
	 time_step = (1./dt.getString(0).get.clone.to_f).to_s
	end
	##################################################

    runner.registerInitialCondition("Imposing airflow restriction on #{fan_choice}.")
	
	# if there is no user-defined schedule, check if the fouling level is between 0 and 1
    if eff_degrad_fac < 0.0 || eff_degrad_fac > 1.0
      runner.registerError("Fan Efficiency Degradation Level #{eff_degrad_fac} for #{fan_choice} is outside the range 0 to 1.0. Exiting......")
      return false
    end

    # create energyplus management system code to alter the maximum volumetric flow rate at the fan
    # create an empty string_objects to be appended into the .idf file
    string_objects = []

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
    end

    # give an error for the name if no RTU is changed
    if no_fan_changed
      runner.registerError("Measure FanMotorDegradation cannot find #{fan_choice}. Skipping......")
      return true
    end

    # write EMS Program, ProgramCallingManager and Actuators to change fan efficiency value at the degraded condition

    fannames.zip(old_effs).each do |fanname, old_eff|
      fanshortname = fanname.gsub(/\s+/, '').gsub('*', '')

      string_objects << "
        EnergyManagementSystem:Program,
          EfficiencyChange#{fanshortname},          !- Name
          SET NewEfficiency#{fanshortname} = #{old_eff}*(1-#{eff_degrad_fac}*AF_current_#{$faultnow}_"+fanshortname+");          !- Program Line 1
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
	  
	  ##################################################
	  faultintensity_adjustmentfactor(string_objects, time_constant, time_step, start_month, start_date, start_time, end_month, end_date, end_time, fanshortname)
	  ##################################################
	  
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
