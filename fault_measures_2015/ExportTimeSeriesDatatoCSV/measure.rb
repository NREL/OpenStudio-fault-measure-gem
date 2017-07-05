require 'erb'
require 'time'
require 'csv'

#start the measure
class ExportTimeSeriesDatatoCSV < OpenStudio::Ruleset::ReportingUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "ExportTimeSeriesDatatoCSV"
  end
  
  #define the arguments that the user will input
  def arguments()
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make an argument for days to report
    # days_to_report = OpenStudio::Ruleset::OSArgument::makeIntegerArgument("days_to_report",true)
    # days_to_report.setDisplayName("Days to Report")
    # days_to_report.setDefaultValue(5)
    # args << days_to_report

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    #use the built-in error checking
    if not runner.validateUserArguments(arguments(), user_arguments)
      return false
    end

    # Get the user inputs
    # days_to_report = runner.getIntegerArgumentValue("days_to_report",user_arguments)
    days_to_report = 365

    # Check that user requested between 1 and 365 days
    if days_to_report < 1 or days_to_report > 365
      runner.registerError("You requested #{days_to_report} days. Must be between 1 and 365.")
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

    #get the weather file run period (as opposed to design day run period)
    ann_env_pd = nil
    sqlFile.availableEnvPeriods.each do |env_pd|
      env_type = sqlFile.environmentType(env_pd)
      if env_type.is_initialized
        if env_type.get == OpenStudio::EnvironmentType.new("WeatherRunPeriod")
          ann_env_pd = env_pd
        end
      end
    end

    sql_start_time = Time.new
    csv_array = []
    output_time_series = {}
    reporting_frequency = "Zone Timestep"
    #header = ["OS_time", "day_of_week"]
	header = ["OS_time"]
    timeseriesinfo = nil
    variableNames = sqlFile.availableVariableNames(ann_env_pd, reporting_frequency)
    variableNames.each do |variableName|
      keyValues = sqlFile.availableKeyValues(ann_env_pd, reporting_frequency, variableName.to_s)
      keyValues.each do |keyValue|
        timeseries = sqlFile.timeSeries(ann_env_pd, reporting_frequency, variableName.to_s, keyValue.to_s)
        if timeseries.is_initialized
          timeseries = timeseries.get
          timeseriesinfo = timeseries
          if timeseries.units == "J"
            if keyValue != ""
              header << "#{r_col("#{keyValue.to_s}:#{variableName.to_s}")} [W]"
            else
              header << "#{r_col("#{variableName.to_s}")} [W]"
            end
            output_time_series[header[-1]] = timeseries / timeseries.intervalLength.get.totalSeconds
          else
            if keyValue != ""
              header << "#{r_col("#{keyValue.to_s}:#{variableName.to_s}")} [#{timeseries.units}]"
            else
              header << "#{r_col("#{variableName.to_s}")} [#{timeseries.units}]"
            end
            output_time_series[header[-1]] = timeseries
          end
        end
      end
    end
    runner.registerInfo("The time series interval length is #{timeseriesinfo.intervalLength.get}, which in seconds totals #{timeseriesinfo.intervalLength.get.totalSeconds}.")
	csv_array << header
    sql_end_time = Time.new
    ts_times = output_time_series[output_time_series.keys[0]].dateTimes
    num_time_steps = ts_times.size - 1
    end_date = ts_times[num_time_steps]
    start_date = end_date - OpenStudio::Time.new(days_to_report,0,0,0)

    pre_values = {}
    for key in output_time_series.keys
      pre_values[key] = output_time_series[key].values
    end

    for i in 0..num_time_steps
      time = ts_times[i]
      next if time <= start_date or time > end_date
      row = []
      row << time
	  #time = time.to_s
	  #month = {"Jan"=>1,"Feb"=>2,"Mar"=>3,"Apr"=>4,"May"=>5,"Jun"=>6,"Jul"=>7,"Aug"=>8,"Sep"=>9,"Oct"=>10,"Nov"=>11,"Dec"=>12}[time[5..7]]
	  #time_object = Time.new(time[0..3].to_f, month, time[9..10].to_f, time[12..13].to_f, time[15..16].to_f, time[18..19].to_f)
	  #row << time_object.wday
      # in correct order of the header
      #for key in header[2..-1]
	  for key in header[1..-1]
        val = pre_values[key][i]
        row << val
      end
      csv_array << row
    end

    end_time = Time.new

    puts "SQL time #{sql_end_time-sql_start_time}"
    puts "Loop time #{end_time-sql_end_time}"

    File.open("./out.csv", 'wb') do |file|
      csv_array.each do |elem|
        file.puts elem.join(',')
      end
    end

    runner.registerInfo("Time series data file saved in #{File.expand_path('.')}.")

	objfunc = true
	if objfunc
		# Measured
		measured = CSV.read("#{File.dirname(__FILE__)}/resources/zone_air_temps_hg_restaurant.csv").transpose
		# Predicted
		predicted = CSV.read("./out.csv").transpose		
		for m in measured
			measured_col = m[0]
			m = m[1..-1].map(&:to_f)
			for p in predicted
				predicted_col = p[0]
				next if predicted_col.nil? or measured_col.nil?
				if predicted_col.include? measured_col
					p = p[1..-1].map(&:to_f)
					p_minus_m = m.zip(p).map { |x, y| y - x }
					p_minus_m_sqrd = p_minus_m.map { |x| x ** 2 }
					sum_p_minus_m_sqrd = p_minus_m_sqrd.inject{ |sum, x| sum + x }
					sqrt_sum_p_minus_m_sqrd = Math.sqrt(sum_p_minus_m_sqrd)
					cvrmse = sqrt_sum_p_minus_m_sqrd * 100 / ( m.inject{ |sum, x| sum + x } / m.size )
					runner.registerValue("#{measured_col}_cvrmse",cvrmse,"%")
					break
				end				
			end
		end
	end
	
    #closing the sql file
    sqlFile.close()

    return true

  end #end the run method

  def r_col(eplus_col)
    return eplus_col.gsub(/\s\[.+/,"").gsub(": ","_").gsub(":","_").gsub(" ","_").downcase
  end

end #end the measure

#this allows the measure to be use by the application
ExportTimeSeriesDatatoCSV.new.registerWithApplication