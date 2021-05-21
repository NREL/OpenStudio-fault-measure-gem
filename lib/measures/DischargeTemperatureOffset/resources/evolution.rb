class Evolution
  attr_reader :fault_intensity_key
  def initialize(fault_key)
    @fault_key = fault_key
    @fault_intensity_key = "#{@fault_key}_intensity"
  end

  def add_user_arguments(args)
    # make a double argument for the time required for fault to reach full level
    time_constant = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('time_constant', false)
    time_constant.setDisplayName('Enter the time required for fault to reach full level [hr]')
    time_constant.setDefaultValue(0)
    args << time_constant

    # make a double argument for the start month
    start_month = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('start_month', false)
    start_month.setDisplayName('Enter the month (1-12) when the fault starts to occur')
    start_month.setDefaultValue(1)
    args << start_month

    # make a double argument for the start date
    start_date = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('start_date', false)
    start_date.setDisplayName('Enter the date (1-28/30/31) when the fault starts to occur')
    start_date.setDefaultValue(1)
    args << start_date

    # make a double argument for the start time
    start_time = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('start_time', false)
    start_time.setDisplayName('Enter the time of day (0-24) when the fault starts to occur')
    start_time.setDefaultValue(0)
    args << start_time

    # make a double argument for the end month
    end_month = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('end_month', false)
    end_month.setDisplayName('Enter the month (1-12) when the fault ends')
    end_month.setDefaultValue(12)
    args << end_month

    # make a double argument for the end date
    end_date = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('end_date', false)
    end_date.setDisplayName('Enter the date (1-28/30/31) when the fault ends')
    end_date.setDefaultValue(31)
    args << end_date

    # make a double argument for the end time
    end_time = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('end_time', false)
    end_time.setDisplayName('Enter the time of day (0-24) when the fault ends')
    end_time.setDefaultValue(24)
    args << end_time
  end

  def read_user_arguments(runner, user_arguments, workspace)
    @time_constant = runner.getDoubleArgumentValue('time_constant', user_arguments).to_s
    @start_month = runner.getDoubleArgumentValue('start_month', user_arguments).to_s
    @start_date = runner.getDoubleArgumentValue('start_date', user_arguments).to_s
    @start_time = runner.getDoubleArgumentValue('start_time', user_arguments).to_s
    @end_month = runner.getDoubleArgumentValue('end_month', user_arguments).to_s
    @end_date = runner.getDoubleArgumentValue('end_date', user_arguments).to_s
    @end_time = runner.getDoubleArgumentValue('end_time', user_arguments).to_s
    dts = workspace.getObjectsByType('Timestep'.to_IddObjectType)
    dts.each do |dt|
      @time_step = (1./dt.getString(0).get.clone.to_f).to_s
    end
  end

  def add_program(workspace)
    string_objects = []
    string_objects << "
    EnergyManagementSystem:GlobalVariable,
      #{@fault_intensity_key};              !- Erl Variable 1 Name"
    string_objects << "
    EnergyManagementSystem:OutputVariable,
      Fault Intensity,
      #{fault_intensity_key},
      Averaged,
      ZoneTimeStep;"
    string_objects << "
    Output:Variable,
      *,
      Fault Intensity,
      timestep;"
    string_objects << "
    EnergyManagementSystem:Program,
      fault_evolution_#{@fault_key}_program,                    !- Name
      SET SM = #{@start_month},              !- Program Line 1
      SET SD = #{@start_date},              !- Program Line 2
      SET ST = #{@start_time},
      SET EM = #{@end_month},
      SET ED = #{@end_date},
      SET ET = #{@end_time},
      SET tau = #{@time_constant},
      SET dt = #{@time_step},
      IF tau == 0,
      SET tau = 0.001,
      ENDIF,
      SET ut_start = SM*10000 + SD*100 + ST,
      SET ut_end = EM*10000 + ED*100 + ET,
      SET ut_actual = Month*10000 + DayOfMonth*100 + CurrentTime,
      IF (ut_actual>=ut_start) && (ut_actual<=ut_end),
      SET #{@fault_intensity_key} = #{@fault_intensity_key} + dt/tau,
      IF  #{@fault_intensity_key}>=1.0,
      SET  #{@fault_intensity_key} = 1.0,
      ENDIF,
      ELSE,
      SET #{@fault_intensity_key} = #{@fault_intensity_key} - dt/tau,
      IF #{@fault_intensity_key} <= 0.0,
      SET #{@fault_intensity_key} = 0.0,
      ENDIF,
      ENDIF;"
    string_objects << "
    EnergyManagementSystem:Program,
      fault_evolution_#{@fault_key}_initializer_program,                    !- Name
      SET #{@fault_intensity_key} = 0;"
    string_objects << "
    EnergyManagementSystem:ProgramCallingManager,
      fault_evolution_#{@fault_key}_program_manager,                  !- Name
      BeginTimestepBeforePredictor,  !- EnergyPlus Model Calling Point
      fault_evolution_#{@fault_key}_program;                    !- Program Name 1"
    string_objects << "
    EnergyManagementSystem:ProgramCallingManager,
      fault_evolution_#{@fault_key}_initializer_program_manager,                  !- Name
      BeginNewEnvironment,  !- EnergyPlus Model Calling Point
      fault_evolution_#{@fault_key}_initializer_program;                    !- Program Name 1"
    string_objects.each do |string_object|
      idf_object = OpenStudio::IdfObject.load(string_object)
      workspace.addObject(idf_object.get)
    end
  end
end
