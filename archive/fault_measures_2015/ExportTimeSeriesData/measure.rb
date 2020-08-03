# ExportTimeSeriesData generates data that is required for the FDD OpenStudio LDRD.

# Author: Henry Horsey (github: henryhorsey / rHorsey)
# Creation Date: 1/16/2015

require 'erb'
require 'time'
require 'tzinfo'
require 'multi_json'

#start the measure
class ExportTimeSeriesData < OpenStudio::Ruleset::ReportingUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "ExportTimeSeriesData"
  end
  
  #define the arguments that the user will input
  def arguments()
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make an argument for days to report as measured from the last timestep in the simulation run
    days_to_report = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("days_to_report",true)
    days_to_report.setDisplayName("Days to Report")
    days_to_report.setDefaultValue(366)
    args << days_to_report

    #make an argument for exporting json
    export_json = OpenStudio::Ruleset::OSArgument::makeBoolArgument("export_json",true)
    export_json.setDisplayName("Export JSON")
    export_json.setDefaultValue("true")
    args << export_json

    #make an argument for exporting csv
    export_csv = OpenStudio::Ruleset::OSArgument::makeBoolArgument("export_csv",true)
    export_csv.setDisplayName("Export CSV")
    export_csv.setDefaultValue("false")
    args << export_csv

    #make an argument for exporting zinc
    export_zinc = OpenStudio::Ruleset::OSArgument::makeBoolArgument("export_zinc",true)
    export_zinc.setDisplayName("Export ZINC")
    export_zinc.setDefaultValue("false")
    args << export_zinc

    #make units format haystack complient
    enable_haystack_units = OpenStudio::Ruleset::OSArgument::makeBoolArgument("enable_haystack_units",true)
    enable_haystack_units.setDisplayName("Format Units to be Project Haystack Complient")
    enable_haystack_units.setDefaultValue("true")
    args << enable_haystack_units

    #make an argument for exporting rDataFrame
    # export_rDataFrame = OpenStudio::Ruleset::OSArgument::makeBoolArgument("export_rDataFrame",true)
    # export_rDataFrame.setDisplayName("Export R DataFrame")
    # export_rDataFrame.setDefaultValue("false")
    # args << export_rDataFrame

    #make an argument for datetime standard
    datetime_handles = OpenStudio::StringVector.new
    datetime_display_names = OpenStudio::StringVector.new

    datetime_handles << "tz_database"
    datetime_handles << "utc_epoc"
    datetime_handles << "iso8601"
    datetime_display_names << "TZ Database "
    datetime_display_names << "UTC Epoc Time"
    datetime_display_names << "ISO-8601"

    datetime_standard = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("datetime_standard", datetime_handles, datetime_display_names, true)
    datetime_standard.setDisplayName("DateTime Standard")
    datetime_standard.setDefaultValue("tz_database")
    args << datetime_standard

    #make an argument for timezone area a la project haystack and the TZ Database
    #please see http://en.wikipedia.org/wiki/List_of_tz_database_time_zones
    tz_area_handles = OpenStudio::StringVector.new
    tz_area_display_names = OpenStudio::StringVector.new

    tz_area_handles << "Africa"
    tz_area_handles << "America"
    tz_area_handles << "Antarctica"
    tz_area_handles << "Arctic"
    tz_area_handles << "Asia"
    tz_area_handles << "Atlantic"
    tz_area_handles << "Australia"
    tz_area_handles << "Europe"
    tz_area_handles << "Indian"
    tz_area_handles << "Pacific"
    tz_area_handles << "GMT"
    tz_area_display_names << "Africa"
    tz_area_display_names << "America"
    tz_area_display_names << "Antarctica"
    tz_area_display_names << "Arctic"
    tz_area_display_names << "Asia"
    tz_area_display_names << "Atlantic"
    tz_area_display_names << "Australia"
    tz_area_display_names << "Europe"
    tz_area_display_names << "Indian"
    tz_area_display_names << "Pacific"
    tz_area_display_names << "Use GMT from WeatherFile"    

    tz_area = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("tz_area", tz_area_handles, tz_area_display_names, true)
    tz_area.setDisplayName("TZ Area Standard")
    tz_area.setDefaultValue("GMT")
    args << tz_area

    #make an argument for timezone city al la project haystack and the TZ Database
    #please see http://en.wikipedia.org/wiki/List_of_tz_database_time_zones
    tz_city = OpenStudio::Ruleset::OSArgument::makeStringArgument("tz_city",true)
    tz_city.setDisplayName("TZ City Standard")
    tz_city.setDefaultValue("N-A")
    args << tz_city

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)
    
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(), user_arguments)
      return false
    end

    # This measure requires ruby 2.0.0 for the JSON and regex
    if RUBY_VERSION < "2.0.0"     
      runner.registerError("This Measure requires Ruby 2.0.0 or higher.  You have Ruby #{RUBY_VERSION}.")
      return false
    end
    
    # get the last model
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Cannot find last model.")
      return false
    end
    model = model.get

    # get the last sql file and link it to the model
    sql = runner.lastEnergyPlusSqlFile
    if sql.empty?
      runner.registerError("Cannot find last sql file.")
      return false
    end
    sql = sql.get
    model.setSqlFile(sql)

    # Get the user inputs
    days_to_report = runner.getIntegerArgumentValue("days_to_report",user_arguments)
    export_json = runner.getBoolArgumentValue("export_json",user_arguments)
    export_csv = runner.getBoolArgumentValue("export_csv",user_arguments)
    export_zinc = runner.getBoolArgumentValue("export_zinc",user_arguments)
    enable_haystack_units = runner.getBoolArgumentValue("enable_haystack_units",user_arguments)
    # export_rDataFrame = runner.getBoolArgumentValue("export_rDataFrame",user_arguments)
    datetime_standard = runner.getStringArgumentValue("datetime_standard",user_arguments) 
    tz_area = runner.getStringArgumentValue("tz_area",user_arguments)
    tz_city = runner.getStringArgumentValue("tz_city",user_arguments)

    # Check that user requested between 1 and 365 days
    if days_to_report < 1 or days_to_report > 365
      runner.registerError("You requested #{days_to_report} days.  Must be between 1 and 365.")
      return false
    end
    
    # Check that datetime selected is supported
    unless datetime_standard == "utc_epoc" || datetime_standard == "iso8601" || datetime_standard == "tz_database"
      runner.registerError("You requested DateTime Standard be equal to  #{datetime_standard}, however only 'utc_epoc', 'iso8601', and 'tz_database' are supported.")
      return false
    end

    # Chech that at least one export format is set to true
    if !export_json && !export_csv && !export_zinc
      runner.registerError("No export format was specified. Please select one of the available formats and rerun this measure.")
      return false
    end

    #Check that if datetime is set to 'tz_database' tz_area has been selected and TZInfo can find read the location
    if datetime_standard == "tz_database"
      unless tz_area.empty?
        if tz_area == "GMT"
          os_timezone = model.getSite.timeZone.to_s
          hour = os_timezone[/[0-9]+/]
          if hour.length == 2 && hour[0] == "0"
            hour = hour[1]
          end
          os_timezone[0] == "-" ? hour = "-#{hour}" : hour = "+#{hour}"
          begin
            tz = TZInfo::Timezone.new("Etc/GMT#{hour}") 
          rescue Exception => e
            runner.registerError("Attempted to use 'Etc/GMT#{hour}' for timezone definition in TZInfo gem. Failed with error message: #{e.message} in #{e.backtrace.inspect}")
            return false
          end
          tz_city = "GMT#{hour}"
        else
          begin
            tz = TZInfo::Timezone.new("#{tz_area}/#{tz_city}")
          rescue Exception => e
            runner.registerError("Attempted to use '#{tz_area}/#{tz_city}' for timezone definition in TZInfo gem. Failed with error message: #{e.message} in #{e.backtrace.inspect}")
            return false
          end 
        end
      else
        runner.registerError("TZ Area Standard not selected while DateTime Standard has been set to TZ Database. Exiting.")
      end
    end

    # Get the weather file (as opposed to design day) run period, which will typically be 'RUN PERIOD 1'
    ann_env_pd = nil
    mult_env_pd_flag = false
    sql.availableEnvPeriods.each do |env_period|
      envType = sql.environmentType(env_period)
      if envType.is_initialized
        if envType.get == "WeatherRunPeriod".to_EnvironmentType
          if ann_env_pd
            mult_env_pd_flag = true
          end
          ann_env_pd = env_period
        end
      end
    end
    if mult_env_pd_flag
        runner.registerWarning("More than one suitable enviromental period found. Using the period enumerated last.")
    end
    runner.registerInfo("Using enviromental period #{ann_env_pd} for all SQL calls.")

    #get timezone from site if not using TZInfo
    if datetime_standard != 'tz_database'
      os_timezone = model.getSite.timeZone.to_s
      hour = os_timezone[/[0-9]+/]
      if hour.length == 1
        hour = "0#{hour}"
      end
      os_timezone[0] == '-' ? hour = "-#{hour}" : hour = "+#{hour}"
      minute = os_timezone[/[.][0-9]+/][1..2]
      if minute.length == 1
        minute = "0#{minute}"
      end
      timezone = "#{hour}:#{minute}"
    end

    #extract the data from the sql in a output-agnostic process
    #get the cols data for each output variable / meter and extract each associated time series
    sql_start_time = Time.now
    output_time_series = {}
    reporting_frequency = "Zone Timestep"
    var_num = 0
    cols = []
    cols[0] = {}
    cols[0]['name'] = 'ts'
    datetime_standard == 'tz_database' ? cols[0]['tz'] = tz_city : cols[0]['tz'] = "GMT#{timezone}"
    cols[0]['dis'] = 'Timestep'
    timeseriesinfo = nil
    variableNames = sql.availableVariableNames(ann_env_pd, reporting_frequency)
    variableNames.each do |variableName|
      keyValues = sql.availableKeyValues(ann_env_pd, reporting_frequency, variableName.to_s)
      keyValues.each do |keyValue|
        var_num += 1
        timeseries = sql.timeSeries(ann_env_pd, reporting_frequency, variableName.to_s, keyValue.to_s)
        if timeseries.is_initialized
          cols[var_num] = {}
          cols[var_num]['name'] = "v#{var_num-1}"
          timeseries = timeseries.get
          timeseriesinfo = timeseries
          if timeseries.units == 'J'
            if keyValue != ''
              cols[var_num]['id'] = "#{r_col("#{keyValue.to_s}:#{variableName.to_s}")}"
            else
              cols[var_num]['id'] = "#{r_col("#{variableName.to_s}")}"
            end
            cols[var_num]['units'] = 'W'
            cols[var_num]['dis'] = "#{cols[var_num]['id']} [#{cols[var_num]['units']}]"
            output_time_series[var_num-1] = timeseries / timeseries.intervalLength.get.totalSeconds
          else
            if keyValue != ""
              cols[var_num]['id'] = "#{r_col("#{keyValue.to_s}:#{variableName.to_s}")} [#{timeseries.units}]"
            else
              cols[var_num]['id'] = "#{r_col("#{variableName.to_s}")}"
            end
            cols[var_num]['units'] = "#{timeseries.units}"
            cols[var_num]['dis'] = "#{cols[var_num]['id']} [#{cols[var_num]['units']}]"
            output_time_series[var_num-1] = timeseries
          end
          cols[var_num]['id'] = ["@",cols[var_num]['id']].join
        end
      end
    end

    #error if no timeseries were found in the attached SQL file
    if var_num == 0
      runner.registerError("No output meters or variables found in the SQL file. Exiting.")
      return false
    end

    #initialize datetime vector and get start / end times
    runner.registerInfo("The time series interval length is #{timeseriesinfo.intervalLength.get.to_s}, which in seconds totals #{timeseriesinfo.intervalLength.get.totalSeconds}.")
    sql_end_time = Time.now
    runner.registerInfo("The SQL read portion took #{sql_end_time - sql_start_time} seconds.")
    hash_start_time = Time.now
    ts_times = output_time_series[0].dateTimes
    num_time_steps = ts_times.size - 1
    end_date = ts_times[num_time_steps]
    start_date = end_date - OpenStudio::Time.new(days_to_report,0,0,0)
    start_index = ((1- (end_date.toEpochLong.to_f - start_date.toEpochLong) / (end_date.toEpochLong - ts_times[0].toEpochLong)) * num_time_steps).to_i
    if start_index < 0
      start_index = 0
      available_days = timeseriesinfo.intervalLength.get.totalDays * num_time_steps
      runner.registerWarning("Unable to provide #{days_to_report} days of data, as only #{available_days} days were run by Energy Plus in the Run Period #{ann_env_pd}. Providing #{available_days} days of data.")
    end
    end_index = num_time_steps
    ts_times = ts_times[start_index..end_index]
    os_vec_lookup = start_index..end_index

    #create row structure and insert the desired time format
    rows = []
    if datetime_standard == 'iso8601'
      start_dateString = fix_ISO8601(start_date.toISO8601,timezone)
      end_dateString = fix_ISO8601(end_date.toISO8601,timezone)
      ts_times.each_with_index do |timestep,index|
        rows[index] = {}
        rows[index]['ts'] = fix_ISO8601(timestep.toISO8601,timezone)
      end
    elsif datetime_standard == 'utc_epoc'
      start_dateString = start_date.toEpochLong
      end_dateString = end_date.toEpochLong
      ts_times.each_with_index do |timestep,index|
        rows[index] = {}
        rows[index]['ts'] = timestep.toEpochLong
      end
    else
      start_dateString = os8601_toTZ(start_date.toISO8601,tz_city)
      end_dateString = os8601_toTZ(end_date.toISO8601,tz_city)
      ts_times.each_with_index do |timestep,index|
        rows[index] = {}
        rows[index]['ts'] = os8601_toTZ(timestep.toISO8601,tz_city)
      end
    end

    #create meta data
    meta = {}
    meta['ver'] = "2.0"
    meta['hisStart'] = "#{start_dateString}"
    meta ['hisEnd'] = "#{end_dateString}"

    #extract 
    output_time_series.keys.each do |key|
      os_vec = output_time_series[key].values
      var_name = "v#{key}"
      os_vec_lookup.each_with_index do |val, index|
        rows[index][var_name] = os_vec[val]
      end
    end

    hash_end_time = Time.now
    runner.registerInfo("The hash creation process took #{hash_end_time - hash_start_time} seconds.")
    
    #establish the unit_lookup to allow for getting units based on variable names
    unit_lookup = {}
    cols.each do |col|
      if col['name'] == 'ts'
        unit_lookup["#{col['name']}"] = ''
      else
        unit_lookup["#{col['name']}"] = col['units']
      end
    end

    #write CSV output to file if requested
    if export_csv
      csv_start_time = Time.now
      csv_rows = []
      csv_meta = []
      cols.each do |col|
        csv_meta << col['dis']
      end
      csv_rows[0] = csv_meta.join(',')
      if enable_haystack_units
        for i in 0..(rows.length-1)
          row = []
          cols.each do |col|
            row << [rows[i][col['name']],unit_lookup[col['name']]].join
          end
          csv_rows << row.join(',')
        end
      else
        for i in 0..(rows.length-1)
          row = []
          cols.each do |col|
            row << rows[i][col['name']]
          end
          csv_rows << row.join(',')
        end
      end
      File.open("./out.csv", 'wb') do |file|
        csv_rows.each do |elem|
          file.puts elem
        end
      end
      csv_end_time = Time.now
      runner.registerInfo("Time series CSV data file saved in #{File.expand_path('.')}. Total time spent writing out.csv was #{csv_end_time - csv_start_time} seconds.")
    end

    #write Zinc output to file if requested
    if export_zinc
      zinc_start_time = Time.now
      zinc_rows = []
      zinc_meta = []
      meta.keys.each do |key|
        if key == "ver"
          zinc_meta << "#{key}: \"#{meta[key]}\""
        end
      end
      meta.keys.each do |key|
        if key != "ver"
          zinc_meta << "#{key}: #{meta[key]}"
        end
      end
      zinc_meta = zinc_meta.join(' ')
      zinc_rows[0] = zinc_meta
      zinc_cols = []
      cols.each do |col|
        if !zinc_cols.empty? then zinc_cols << ',' end
        col.keys.each do |key|
          if key == 'name'
            zinc_cols << col[key]
          end
        end
        col.keys.each do |key|
          if key != 'name'
            zinc_cols << [key,["\"",col[key],"\""].join].join(':')
          end
        end
      end
      zinc_rows[1] = zinc_cols.join(' ')
      if enable_haystack_units
        for i in 0..(rows.length-1)
          row = []
          cols.each do |col|
            row << [rows[i][col['name']],unit_lookup[col['name']]].join
          end
          zinc_rows << row.join(',')
        end
      else
        for i in 0..(rows.length-1)
          row = []
          cols.each do |col|
            row << rows[i][col['name']]
          end
          zinc_rows << row.join(',')
        end
      end
      File.open("./out.zinc", 'wb') do |file|
        zinc_rows.each do |elem|
          file.puts elem
        end
      end
      zinc_end_time = Time.now
      runner.registerInfo("Time series ZINC data file saved in #{File.expand_path('.')}. Total time spent writing out.zinc was #{zinc_end_time - zinc_start_time} seconds.")
    end

    #write JSON output file if requested
    if export_json
      json_start_time = Time.now
      json_out = {}
      json_out['meta'] = meta
      json_out['cols'] = cols
      json_rows = []
      rows.each do |row|
        row_hash = {}
        cols.each do |col|
          if col['name'] == 'ts'
            row_hash['ts'] = row['ts']
          end
        end
        if enable_haystack_units
          cols.each do |col|
            if col['name'] != 'ts'
              row_hash[col['name']] = row[col['name']]
              row_hash["#{col['name']}.unit"] = col['units']
            end
          end
        else
          cols.each do |col|
            if col['name'] != 'ts'
              row_hash[col['name']] = row[col['name']]
            end
          end
        end
        json_rows << row_hash
      end
      json_out['rows'] = json_rows
      File.open("./out.json", 'wb') do |file|
        file.puts MultiJson.dump(json_out)
      end
      json_end_time = Time.now
      runner.registerInfo("Time series JSON data file saved in #{File.expand_path('.')}. Total time spent writing out.json was #{json_end_time - json_start_time} seconds.")
    end

    #closing the sql file
    sql.close()

    return true

  end #end the run method

  def r_col(eplus_col)
    return eplus_col.gsub(/\s\[.+/,"").gsub(": ","_").gsub(":","_").gsub(" ","_").downcase
  end
 
  def fix_ISO8601(wrong_format,weatherfile_timezone)
    return "#{wrong_format[0..3]}-#{wrong_format[4..5]}-#{wrong_format[6..7]}T#{wrong_format[9..10]}:#{wrong_format[11..12]}:#{wrong_format[13..14]}#{weatherfile_timezone}"
  end

  def os8601_toTZ(os8601,tz_city_code)
    return "#{os8601[0..3]}-#{os8601[4..5]}-#{os8601[6..7]}T#{os8601[9..10]}:#{os8601[11..12]}:#{os8601[13..14]} #{tz_city_code}"
  end

end #end the measure

#this allows the measure to be use by the application
ExportTimeSeriesData.new.registerWithApplication