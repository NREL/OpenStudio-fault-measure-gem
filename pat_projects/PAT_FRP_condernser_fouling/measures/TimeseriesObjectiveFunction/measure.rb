# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

require 'csv'
require 'time'
require 'json'
require 'erb'

# start the measure
class TimeseriesObjectiveFunction < OpenStudio::Ruleset::ReportingUserScript

  # human readable name
  def name
    return "TimeSeries Objective Function"
  end

  # human readable description
  def description
    return "Creates Objective Function from Timeseries Data"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Creates Objective Function from Timeseries Data.  The measure applies a Norm at each timestep between the difference of CSV metered data and SQL model data. A timeseries plot can also be created.  Possible outputs are 'cvrmse', 'nmbe', 'simdata' = sum of the simulated data, 'csvdata' = sum of metered data, 'diff' = P Norm between the metered and simulated data if Norm is 1 or 2, else its just the Difference."
  end

  # define the arguments that the user will input
  def arguments()
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # the name of the sql file
    csv_name = OpenStudio::Ruleset::OSArgument.makeStringArgument("csv_name", true)
    csv_name.setDisplayName("Path to CSV file for the metered data")
    csv_name.setDescription("Path to CSV file including file name.")
    csv_name.setDefaultValue("../../../lib/resources/mtr.csv")
    args << csv_name
    
    csv_time_header = OpenStudio::Ruleset::OSArgument.makeStringArgument("csv_time_header", true)
    csv_time_header.setDisplayName("CSV Time Header")
    csv_time_header.setDescription("CSV Time Header Value. Used to determine the timestamp column in the CSV file")
    csv_time_header.setDefaultValue("Date/Time")
    args << csv_time_header
    
    csv_var = OpenStudio::Ruleset::OSArgument.makeStringArgument("csv_var", true)
    csv_var.setDisplayName("CSV variable name")
    csv_var.setDescription("CSV variable name. Used to determine the variable column in the CSV file")
    csv_var.setDefaultValue("Whole Building:Facility Total Electric Demand Power [W](TimeStep)")
    args << csv_var
    
    convert_data_chs = OpenStudio::StringVector.new
    convert_data_chs << 'F to C'
    convert_data_chs << 'WH to J'
    convert_data_chs << 'CFM to m3/s'
    convert_data_chs << 'PSI to Pa'
    convert_data_chs << 'None'
    convert_data = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('convert_data', convert_data_chs, true)
    convert_data.setDisplayName("Convert Units")
    convert_data.setDescription("Convert Units in Metered Data")
    convert_data.setDefaultValue("None")
    args << convert_data
    
    csv_var_dn = OpenStudio::Ruleset::OSArgument.makeStringArgument("csv_var_dn", true)
    csv_var_dn.setDisplayName("CSV variable display name")
    csv_var_dn.setDescription("CSV variable display name. Not yet Implemented")
    csv_var_dn.setDefaultValue("")
    args << csv_var_dn
    
    years = OpenStudio::Ruleset::OSArgument.makeBoolArgument("year", true)
    years.setDisplayName("Year in csv data timestamp")
    years.setDescription("Is the Year in the csv data timestamp => mm:dd:yy or mm:dd (true/false)")
    years.setDefaultValue(true)
    args << years
    
    seconds = OpenStudio::Ruleset::OSArgument.makeBoolArgument("seconds", true)
    seconds.setDisplayName("Seconds in csv data timestamp")
    seconds.setDescription("Is the Seconds in the csv data timestamp => hh:mm:ss or hh:mm (true/false)")
    seconds.setDefaultValue(true)
    args << seconds
    
    sql_key = OpenStudio::Ruleset::OSArgument.makeStringArgument("key_value", true)
    sql_key.setDisplayName("SQL key value")
    sql_key.setDescription("SQL key value for the SQL query to find the variable in the SQL file")
    sql_key.setDefaultValue("")
    args << sql_key  

    sql_var = OpenStudio::Ruleset::OSArgument.makeStringArgument("timeseries_name", true)
    sql_var.setDisplayName("TimeSeries Name")
    sql_var.setDescription("TimeSeries Name for the SQL query to find the variable in the SQL file")
    sql_var.setDefaultValue("Facility Total Electric Demand Power")
    args << sql_var    
    
    reportfreq_chs = OpenStudio::StringVector.new
    reportfreq_chs << 'Detailed'
    reportfreq_chs << 'Timestep'
    reportfreq_chs << 'Hourly'
    reportfreq_chs << 'Daily'
    reportfreq_chs << 'Monthly'
    reportfreq_chs << 'RunPeriod'
    reporting_frequency = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('reporting_frequency', reportfreq_chs, true)
    reporting_frequency.setDisplayName("Reporting Frequency")
    reporting_frequency.setDescription("Reporting Frequency for SQL Query")
    reporting_frequency.setDefaultValue("Zone Timestep")
    args << reporting_frequency
    
    environment_period = OpenStudio::Ruleset::OSArgument.makeStringArgument("environment_period", true)
    environment_period.setDisplayName("Environment Period")
    environment_period.setDescription("Environment Period for SQL query")
    environment_period.setDefaultValue("RUN PERIOD 1")
    args << environment_period
    
    norm = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("norm", true)
    norm.setDisplayName("Norm of the difference of csv and sql")
    norm.setDescription("Norm of the difference of csv and sql. 1 is absolute value. 2 is euclidean distance. 3 is raw difference.")
    norm.setDefaultValue(1)
    args << norm   

    scale = OpenStudio::Ruleset::OSArgument.makeDoubleArgument("scale", true)
    scale.setDisplayName("Scale factor to apply to the difference")
    scale.setDescription("Scale factor to apply to the difference (1 is no scale)")
    scale.setDefaultValue(1)
    args << scale     

    find_avail = OpenStudio::Ruleset::OSArgument.makeBoolArgument("find_avail", true)
    find_avail.setDisplayName("Find Available data in the SQL file")
    find_avail.setDescription("Will RegisterInfo all the 'EnvPeriod', 'ReportingFrequencies', 'VariableNames', 'KeyValues' in the SQL file.  Useful for debugging SQL issues.")
    find_avail.setDefaultValue(true)
    args << find_avail 
        
    algorithm_download = OpenStudio::Ruleset::OSArgument.makeBoolArgument("algorithm_download", true)
    algorithm_download.setDisplayName("algorithm_download")
    algorithm_download.setDescription("Make JSON data available for algorithm_download (true/false)")
    algorithm_download.setDefaultValue(false)
    args << algorithm_download  
    
    plot_flag = OpenStudio::Ruleset::OSArgument.makeBoolArgument("plot_flag", true)
    plot_flag.setDisplayName("plot_flag timeseries data")
    plot_flag.setDescription("Create plot of timeseries data (true/false)")
    plot_flag.setDefaultValue(true)
    args << plot_flag
    
    plot_name = OpenStudio::Ruleset::OSArgument.makeStringArgument("plot_name", true)
    plot_name.setDisplayName("Plot name")
    plot_name.setDescription("Name to include in reporting file name.")
    plot_name.setDefaultValue("")
    args << plot_name
    
    verbose_messages = OpenStudio::Ruleset::OSArgument.makeBoolArgument("verbose_messages", true)
    verbose_messages.setDisplayName("verbose_messages")
    verbose_messages.setDescription("verbose messages.  Useful for debugging but MAJOR Performance Hit.")
    verbose_messages.setDefaultValue(false)
    args << verbose_messages 
    
    warning_messages = OpenStudio::Ruleset::OSArgument.makeBoolArgument("warning_messages", true)
    warning_messages.setDisplayName("warning_messages")
    warning_messages.setDescription("Warn on missing data.")
    warning_messages.setDefaultValue(true)
    args << warning_messages

    add_first_zero_for_plots = OpenStudio::Ruleset::OSArgument.makeBoolArgument("add_first_zero_for_plots", true)
    add_first_zero_for_plots.setDisplayName("add_first_zero_for_plots")
    add_first_zero_for_plots.setDescription("Add a point of zero value to the plot at the beginning of the runperiod.")
    add_first_zero_for_plots.setDefaultValue(false)
    args << add_first_zero_for_plots
    
    add_last_zero_for_plots = OpenStudio::Ruleset::OSArgument.makeBoolArgument("add_last_zero_for_plots", true)
    add_last_zero_for_plots.setDisplayName("add_last_zero_for_plots")
    add_last_zero_for_plots.setDescription("Add a point of zero value to the plot at the end of the runperiod.")
    add_last_zero_for_plots.setDefaultValue(false)
    args << add_last_zero_for_plots
    
    return args
  end

  # adds output requests ahead of EnergyPlus simulation
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)

    result = OpenStudio::IdfObjectVector.new

    # use the built-in error checking
    unless runner.validateUserArguments(arguments, user_arguments)
      return result
    end

    # gather required values from user arguments
    key = runner.getStringArgumentValue('key_value', user_arguments)
    variable = runner.getStringArgumentValue('timeseries_name', user_arguments)
    timestep = runner.getStringArgumentValue('reporting_frequency', user_arguments)

    # add output request using values from user argument
    if key == "no_key" # could also look for variable.include?(":Electricity")
      result << OpenStudio::IdfObject.load("Output:Meter,#{variable},#{timestep};").get
    else
      result << OpenStudio::IdfObject.load("Output:Variable,#{key},#{variable},#{timestep};").get
    end

    return result
  end

  # outputs for PAT
  def outputs
    result = OpenStudio::Measure::OSOutputVector.new

    # calibration metrics
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('diff') # kWh
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('simdata') # kWh
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('csvdata') # %
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('cvrmse') # %
    result << OpenStudio::Measure::OSOutput.makeDoubleOutput('nmbe') # kWh

    return result
  end
  
  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(), user_arguments)
      return false
    end

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Cannot find last model.")
      return false
    end
    model = model.get

    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError("Cannot find last sql file.")
      return false
    end
    sqlFile = sqlFile.get
    model.setSqlFile(sqlFile)
    
    # assign the user inputs to variables
    csv_name = runner.getStringArgumentValue("csv_name", user_arguments)
    csv_time_header = runner.getStringArgumentValue("csv_time_header", user_arguments)
    csv_var = runner.getStringArgumentValue("csv_var", user_arguments)
    csv_var_dn = runner.getStringArgumentValue("csv_var_dn", user_arguments)
    years = runner.getBoolArgumentValue("year", user_arguments)
    seconds = runner.getBoolArgumentValue("seconds", user_arguments)

    sql_key = runner.getStringArgumentValue("key_value", user_arguments)
    # PAT fails on empty string or even a space as string, even though runs fine in OS app, as hack adding "no_key" method which converts to empty string here
    if sql_key.include?("no_key") then sql_key = "" end

    sql_var = runner.getStringArgumentValue("timeseries_name", user_arguments)
    norm = runner.getDoubleArgumentValue("norm", user_arguments)
    scale = runner.getDoubleArgumentValue("scale", user_arguments)
    find_avail = runner.getBoolArgumentValue("find_avail", user_arguments) 
    verbose_messages = runner.getBoolArgumentValue("verbose_messages", user_arguments)
    warning_messages = runner.getBoolArgumentValue("warning_messages", user_arguments)
    algorithm_download = runner.getBoolArgumentValue("algorithm_download", user_arguments)
    plot_flag = runner.getBoolArgumentValue("plot_flag", user_arguments)
    plot_name = runner.getStringArgumentValue("plot_name", user_arguments)
    environment_period = runner.getStringArgumentValue("environment_period", user_arguments)
    reporting_frequency = runner.getStringArgumentValue("reporting_frequency", user_arguments)
    convert_data = runner.getStringArgumentValue("convert_data", user_arguments)
    last_zero = runner.getBoolArgumentValue("add_last_zero_for_plots", user_arguments)
    first_zero = runner.getBoolArgumentValue("add_first_zero_for_plots", user_arguments)
    @name = plot_name
    # Method to translate from OpenStudio's time formatting
    # to Javascript time formatting
    # OpenStudio time
    # 2009-May-14 00:10:00   Raw string
    # Javascript time
    # 2009/07/12 12:34:56
    def to_JSTime(os_time)
      js_time = os_time.to_s
      # Replace the '-' with '/'
      js_time = js_time.gsub('-','/')
      # Replace month abbreviations with numbers
      js_time = js_time.gsub('Jan','01')
      js_time = js_time.gsub('Feb','02')
      js_time = js_time.gsub('Mar','03')
      js_time = js_time.gsub('Apr','04')
      js_time = js_time.gsub('May','05')
      js_time = js_time.gsub('Jun','06')
      js_time = js_time.gsub('Jul','07')
      js_time = js_time.gsub('Aug','08')
      js_time = js_time.gsub('Sep','09')
      js_time = js_time.gsub('Oct','10')
      js_time = js_time.gsub('Nov','11')
      js_time = js_time.gsub('Dec','12')
      
      return js_time

    end 

    #setup convert
    if convert_data == 'F to C'
      convert = 0.5556
    elsif convert_data == 'WH to J' 
      convert = 3600
    elsif convert_data == 'CFM to m3/s'
      convert = 0.00047    
    elsif convert_data == 'PSI to Pa'
      convert = 6894.76
    else convert_data == 'None'
      convert = 1
    end
    
    diff = 0.0
    simdata = 0.0
    csvdata = 0.0
    ySum = 0.0
    squaredError = 0.0
    sumError = 0.0
    n = 0
    cvrmse = 0
    nmbe = 0
    #map = {'Whole Building:Facility Total Electric Demand Power [W](TimeStep)'=>['Whole Building','Facility Total Electric Demand Power'],'OCCUPIED_TZ:Zone Mean Air Temperature [C](TimeStep)'=>['OCCUPIED_TZ','Zone Mean Air Temperature']}

    map = {"#{csv_var}" => { key: sql_key, var: sql_var, index: 0 }}
    cal = {1=>'January',2=>'February',3=>'March',4=>'April',5=>'May',6=>'June',7=>'July',8=>'August',9=>'September',10=>'October',11=>'November',12=>'December'}
    runner.registerInfo("csv_name: #{csv_name}")
    
    csv = CSV.read(csv_name, :encoding => 'ISO-8859-1')
    #sql = OpenStudio::SqlFile.new(OpenStudio::Path.new('sim.sql'))
    sql = sqlFile
    #environment_period = sql.availableEnvPeriods[3]
    runner.registerInfo("environment_period: #{environment_period}")
    environment_periods = environment_period.split(',')
    runner.registerInfo("environment_periods: #{environment_periods}")
    runner.registerInfo("map: #{map}")
    runner.registerInfo("")
    
    if find_avail 
      ts = sql.availableTimeSeries
      runner.registerInfo("available timeseries: #{ts}")
      runner.registerInfo("")
      envs = sql.availableEnvPeriods
      envs.each do |env_s|
        freqs = sql.availableReportingFrequencies(env_s)
        runner.registerInfo("available EnvPeriod: #{env_s}, available ReportingFrequencies: #{freqs}")
        freqs.each do |freq|
          vn = sql.availableVariableNames(env_s,freq.to_s)
          runner.registerInfo("available variable names: #{vn}")
          vn.each do |v|  
            kv = sql.availableKeyValues(env_s,freq.to_s,v)
            runner.registerInfo("variable names: #{v}")
            runner.registerInfo("available key value: #{kv}")
          end
        end  
      end  
    end
    runner.registerInfo("year: #{years}")
    runner.registerInfo("seconds: #{seconds}")
    if !years && seconds
    # mm:dd hh:mm:ss
      # check day time splits into two valid parts
      if !csv[1][0].split(' ')[0].nil? && !csv[1][0].split(' ')[1].nil?
        #check remaining splits are valid
        if !csv[1][0].split(' ')[0].split('/')[0].nil? && !csv[1][0].split(' ')[0].split('/')[1].nil? && !csv[1][0].split(' ')[1].split(':')[0].nil? && !csv[1][0].split(' ')[1].split(':')[1].nil? && !csv[1][0].split(' ')[1].split(':')[2].nil?
          runner.registerInfo("CSV Time format is correct: #{csv[1][0]} mm:dd hh:mm:ss")
        else
          runner.registerError("CSV Time format not correct: #{csv[1][0]}. Selected format is mm:dd hh:mm:ss")
          return false
        end      
      else  
        runner.registerError("CSV Time format not correct: #{csv[1][0]}. Does not split into 'day time'. Selected format is mm:dd hh:mm:ss")
        return false
      end 
    elsif !years && !seconds
    # mm:dd hh:mm
      # check day time splits into two valid parts
      if !csv[1][0].split(' ')[0].nil? && !csv[1][0].split(' ')[1].nil?
        #check remaining splits are valid
        if !csv[1][0].split(' ')[0].split('/')[0].nil? && !csv[1][0].split(' ')[0].split('/')[1].nil? && !csv[1][0].split(' ')[1].split(':')[0].nil? && !csv[1][0].split(' ')[1].split(':')[1].nil?
          runner.registerInfo("CSV Time format is correct: #{csv[1][0]} mm:dd hh:mm")
        else
          runner.registerError("CSV Time format not correct: #{csv[1][0]}. Selected format is mm:dd hh:mm")
          return false
        end      
      else  
        runner.registerError("CSV Time format not correct: #{csv[1][0]}. Does not split into 'day time'. Selected format is mm:dd hh:mm")
        return false
      end 
    elsif years && !seconds
    # mm:dd:yy hh:mm
      # check day time splits into two valid parts
      if !csv[1][0].split(' ')[0].nil? && !csv[1][0].split(' ')[1].nil?
        #check remaining splits are valid
        if !csv[1][0].split(' ')[0].split('/')[0].nil? && !csv[1][0].split(' ')[0].split('/')[1].nil? && !csv[1][0].split(' ')[0].split('/')[2].nil? && !csv[1][0].split(' ')[1].split(':')[0].nil? && !csv[1][0].split(' ')[1].split(':')[1].nil?
          runner.registerInfo("CSV Time format is correct: #{csv[1][0]} mm:dd:yy hh:mm")
        else
          runner.registerError("CSV Time format not correct: #{csv[1][0]}. Selected format is mm:dd:yy hh:mm")
          return false
        end      
      else  
        runner.registerError("CSV Time format not correct: #{csv[1][0]}. Does not split into 'day time'. Selected format is mm:dd:yy hh:mm")
        return false
      end 
    elsif years && seconds
    # mm:dd:yy hh:mm:ss
      # check day time splits into two valid parts
      if !csv[1][0].split(' ')[0].nil? && !csv[1][0].split(' ')[1].nil?
        #check remaining splits are valid
        if !csv[1][0].split(' ')[0].split('/')[0].nil? && !csv[1][0].split(' ')[0].split('/')[1].nil? && !csv[1][0].split(' ')[0].split('/')[2].nil? && !csv[1][0].split(' ')[1].split(':')[0].nil? && !csv[1][0].split(' ')[1].split(':')[1].nil? && !csv[1][0].split(' ')[1].split(':')[2].nil?
          runner.registerInfo("CSV Time format is correct: #{csv[1][0]} mm:dd:yy hh:mm:ss")
        else
          runner.registerError("CSV Time format not correct: #{csv[1][0]}. Selected format is mm:dd:yy hh:mm:ss")
          return false
        end      
      else  
        runner.registerError("CSV Time format not correct: #{csv[1][0]}. Does not split into 'day time'. Selected format is mm:dd:yy hh:mm:ss")
        return false
      end 
    end    
    
    temp_sim = []
    temp_mtr = []
    temp_norm = []
    runner.registerInfo("Begin timeseries parsing")
    #get timezone info
    tzs = model.getSite.timeZone.to_s
    runner.registerInfo("timezone = #{tzs}")
    if tzs.to_i >= 0  #positive number
      if tzs.to_i < 10 #one digit
        tz = "+0#{tzs.to_i}:00"
      else  #two digit
        tz = "+#{tzs.to_i}:00"
      end              
    else #negative number
      if tzs.to_i * -1 < 10 #one digit
        tz = "-0#{tzs.to_i * -1}:00"
      else #two digit
        tz = "-#{tzs.to_i * -1}:00"
      end
    end
    runner.registerInfo("timezone = #{tz}")
    #export for plotting
    all_series = []
    csv[0].each do |hdr|
      if (hdr.to_s != csv_time_header.to_s)
        if !map.key? hdr
          runner.registerInfo("CSV hdr #{hdr} is not in map: #{map}, skipping") if verbose_messages
          next
        end
        runner.registerInfo("hdr is: #{hdr}")
        runner.registerInfo("csv_var is: #{csv_var}")
        #next unless map.key? hdr
        key = map[hdr][:key]
        var = map[hdr][:var]
        diff_index = map[hdr][:index]
        runner.registerInfo("var: #{var}")
        runner.registerInfo("key: #{key}")        
        
        # Store the timeseries data to hash for later
        # export to the HTML file
        series = {}
        series["name"] = "#{key} Simulated"
        series["type"] = "#{var}"
        series["color"] = "blue"
        data = []    
        series2 = {}
        series2["name"] = "#{key} Metered"
        series2["type"] = "#{var}"
        series2["color"] = "red"
        data2 = []    
        environment_periods.each do |environment_p|
          runner.registerInfo("sqlcall: #{environment_p},#{reporting_frequency},#{var},#{key}")  
          if sql.timeSeries(environment_p,reporting_frequency,var,key).is_initialized
            ser = sql.timeSeries(environment_p,reporting_frequency,var,key).get
          else
            runner.registerWarning("sql.timeSeries not initialized environment_p: #{environment_p},reporting_frequency: #{reporting_frequency},var: #{var},key: #{key}.")
            next
          end
          date_times = ser.dateTimes
          first_date = date_times[0]
          last_date = date_times[-1]      
          if date_times.size >= 2
            delta = OpenStudio::Time.new((date_times[1]-date_times[0]).days,(date_times[1]-date_times[0]).hours,(date_times[1]-date_times[0]).minutes,(date_times[1]-date_times[0]).seconds) 
          end
          runner.registerInfo("first_date: #{first_date}") if verbose_messages
          runner.registerInfo("last_date: #{last_date}") if verbose_messages
          #if
            series["units"] = ser.units
            series2["units"] = ser.units
          #end
          #add 0 for plotting
          if first_zero
            runner.registerInfo("adding first_zero: #{first_date-delta}")
            point = {}
            point["y"] = 0.0
            point["time"] = to_JSTime(first_date-delta)
            data << point
            point2 = {}
            point2["y"] = 0.0
            point2["time"] = to_JSTime(first_date-delta)
            data2 << point2
          end
                    
          csv.each_index do |row|
            if row > 0
              if csv[row][0].nil?
                if warning_messages
                  runner.registerWarning("empty csv row number #{row}")
                end
                next
              end
              mon = csv[row][0].split(' ')[0].split('/')[0].to_i
              day = csv[row][0].split(' ')[0].split('/')[1].to_i
              if !csv[row][0].split(' ')[0].split('/')[2].nil?
                year = csv[row][0].split(' ')[0].split('/')[2].to_i
              else
                year = nil            
              end
              hou = csv[row][0].split(' ')[1].split(':')[0].to_i
              min = csv[row][0].split(' ')[1].split(':')[1].to_i
              if !csv[row][0].split(' ')[1].split(':')[2].nil?
                sec = csv[row][0].split(' ')[1].split(':')[2].to_i
              else
                sec = nil            
              end
              if year == nil
                dat = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(cal[mon]),day)
              else
                #dat = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(cal[mon]),day,year)
                #hack since year is not in the sql file correctly
                dat = OpenStudio::Date.new(OpenStudio::MonthOfYear.new(cal[mon]),day)
              end
              if sec == nil
                tim = OpenStudio::Time.new(0,hou,min,0)
              else
                tim = OpenStudio::Time.new(0,hou,min,sec)
              end            
              dtm = OpenStudio::DateTime.new(dat,tim)
              if !(dtm >= first_date && dtm <= last_date)
                if warning_messages
                  runner.registerWarning("CSV DateTime #{dtm} is not in SQL Timeseries Dates")
                end
                next
              end
              if year == nil
                if sec == nil
                  etim = Time.new(2009, mon, day, hou, min, 0, tz).to_i * 1000
                else
                  etim = Time.new(2009, mon, day, hou, min, sec, tz).to_i * 1000
                end
              else
                if sec == nil
                #hack since year is not in the sql file correctly
                  #etim = Time.new(year, mon, day, hou, min, 0, tz).to_i * 1000
                  etim = Time.new(2009, mon, day, hou, min, 0, tz).to_i * 1000
                else
                #hack since year is not in the sql file correctly
                  #etim = Time.new(year, mon, day, hou, min, sec, tz).to_i * 1000
                  etim = Time.new(2009, mon, day, hou, min, sec, tz).to_i * 1000
                end
              end
              runner.registerInfo("dtm: #{dtm}") if verbose_messages
              csv[row].each_index do |col|
                if col > 0
                  mtr = csv[row][col].to_s
                  #try converting
                  if convert == 0.5556  #this is a temperature
                    if mtr != 'NAN'
                      mtr = (mtr.to_f - 32) * convert
                    else
                      next
                      #mtr = 0
                    end                  
                  else
                    if mtr != 'NAN'
                      mtr = mtr.to_f * convert
                    else
                      next
                      #mtr = 0
                    end
                  end
                  if csv[0][col] == hdr                   
                    sim = ser.value(dtm)
                    #store timeseries for plotting
                    point = {}
                    point["y"] = sim.round(6)
                    point["time"] = to_JSTime(dtm)
                    data << point
                    point2 = {}
                    point2["y"] = mtr.to_f.round(6)
                    point2["time"] = to_JSTime(dtm)
                    data2 << point2
                    
                    if norm == 1
                      dif = scale.to_f * (mtr.to_f - sim.to_f).abs
                    elsif norm == 2  
                      dif = (scale.to_f * (mtr.to_f - sim.to_f))**2
                    else
                      dif = scale.to_f * (mtr.to_f - sim.to_f)
                    end
                    
                    squaredError = squaredError + (mtr.to_f - sim.to_f)**2
                    sumError = sumError + (mtr.to_f - sim.to_f)
                    ySum = ySum + mtr.to_f
                    n = n + 1
                    
                    temp_sim << [etim,sim.to_f]
                    temp_mtr << [etim,mtr.to_f] 
                    #temp_norm << [etim,dif.to_f]                  
                    diff = diff + dif.to_f
                    simdata = simdata + sim.to_f
                    csvdata = csvdata + mtr.to_f
                    runner.registerInfo("mtr value is #{mtr}") if verbose_messages
                    runner.registerInfo("sim value is #{sim}") if verbose_messages
                    runner.registerInfo("dif value is #{dif}") if verbose_messages
                    runner.registerInfo("diff value is #{diff.inspect}") if verbose_messages
                  end
                end
              end
            end
          end
          #add 0 for plotting
          if last_zero
            runner.registerInfo("add last_zero: #{last_date+delta}")
            point = {}
            point["y"] = 0.0
            point["time"] = to_JSTime(last_date+delta)
            data << point
            point2 = {}
            point2["y"] = 0.0
            point2["time"] = to_JSTime(last_date+delta)
            data2 << point2
          end
        end
        series["displayname"] = plot_name
        series2["displayname"] = plot_name
        series["data"] = data
        series2["data"] = data2
        all_series << series
        all_series << series2
        yBar = [ySum/n,1e-19].max
        cvrmse = 100.0 * Math::sqrt(squaredError/n) / yBar
        nmbe = 100.0 * (sumError/n) / yBar
        series["cvrmse"] = cvrmse.round(6)
        series["nmbe"] = nmbe.round(6)
        series2["cvrmse"] = cvrmse.round(6)
        series2["nmbe"] = nmbe.round(6)

        if algorithm_download
          require "csv"
          CSV.open("timeseries#{plot_name}.csv", "wb") do |csv|
            csv << ["Simulation Time", "Simulated Value", "Metered time", "Metered Value"]
            data.size.times do |i|
              csv << [data[i]['time'],data[i]['y'],data2[i]['time'],data2[i]['y']]
            end
          end
        end

      else
        runner.registerInfo("Found Time Header: #{csv_time_header}")
      end
    end

    #results = {"metadata" => {"tz" => tzs.to_i, "variables" => {"variable" => csv_var, "variable_display_name" => csv_var_dn}}, "data_mtr" => temp_mtr, "data_sim" => temp_sim, "data_diff" => temp_norm}
    #remove diff norm from results json
    results = {"metadata" => {"tz" => tzs.to_i, "variables" => {"variable" => csv_var, "variable_display_name" => csv_var_dn}}, "data_mtr" => temp_mtr, "data_sim" => temp_sim}
    runner.registerInfo("Saving timeseries_#{csv_var}.json") 
    FileUtils.mkdir_p(File.dirname("timeseries_#{csv_var}.json")) unless Dir.exist?(File.dirname("timeseries_#{csv_var}.json"))
    File.open("timeseries_#{csv_var}.json", 'wb') {|f| f << JSON.pretty_generate(results)}
    FileUtils.mkdir_p(File.dirname("allseries_#{csv_var}.json")) unless Dir.exist?(File.dirname("allseries_#{csv_var}.json"))
    File.open("allseries_#{csv_var}.json", 'wb') {|f| f << JSON.pretty_generate(all_series)}
    #check if analysis directory exists on server
    if algorithm_download
      if File.basename(File.expand_path(File.join(Dir.pwd,"../../../"))).split('_')[0] == "analysis"
        runner.registerInfo("Copying timeseries_#{csv_var}.json to downloads directory")  
        directory_name = File.expand_path(File.join(Dir.pwd,"../../../downloads"))
        Dir.mkdir(directory_name) unless File.exists?(directory_name)
        FileUtils.cp("timeseries_#{csv_var}.json",directory_name) 
        FileUtils.cp("allseries_#{csv_var}.json",directory_name)
        FileUtils.cp("timeseries#{plot_name}.csv",directory_name)
      end
    end  
    if norm == 2
      diff = Math::sqrt(diff)
    end
    
    runner.registerInfo("results: #{results}") if verbose_messages
    runner.registerValue("diff", diff, "")
    runner.registerValue("simdata", simdata, "")
    runner.registerValue("csvdata", csvdata, "")
    runner.registerValue("cvrmse", cvrmse, "")
    runner.registerValue("nmbe", nmbe, "")

    if plot_flag
      runner.registerInfo("start plotting")
      all_series = all_series.to_json
      # read in template
      html_in_path = "#{File.dirname(__FILE__)}/resources/report.html.erb"
      if File.exist?(html_in_path)
          html_in_path = html_in_path
      else
          html_in_path = "#{File.dirname(__FILE__)}/report.html.erb"
      end
      html_in = ""
      File.open(html_in_path, 'r') do |file|
        html_in = file.read
      end

      # configure template with variable values
      renderer = ERB.new(html_in)
      html_out = renderer.result(binding)
      
      # write html file
      if plot_name.empty?
        html_out_path = "./report_#{csv_var}.html"
      else  
        html_out_path = "./report_#{plot_name}.html"
      end
      File.open(html_out_path, 'w') do |file|
        file << html_out
        # make sure data is written to the disk one way or the other
        begin
          file.fsync
        rescue
          file.flush
        end
      end
    end
    sql.close()
    return true

  end
  
end

# register the measure to be used by the application
TimeseriesObjectiveFunction.new.registerWithApplication
