require 'erb'
require 'time'
require 'json'

# start the measure
class ThermostatBiasReportingAnalysisSpreadSheet < OpenStudio::Ruleset::ReportingUserScript
  def name
    return 'ThermostatBiasReportingAnalysisSpreadSheet'
  end

  def description
    return 'This measure changes the zone air temperature readings in eplusout.sql file so that the zone air temperature is showing the biased reading rather than the true reading of the thermostats. This Measure is only useful when it is being run with the OpenStudio Analysis Spreadsheet operation.'
  end

  def modeler_description
    return 'This measure reads the workflow json file to know the location and the bias of the faulted thermostat and adjust the "Zone Air Temperature" in the output database "eplusout.sql". It adjusts the database according to the bias level, the starting month and the ending month of the OpenStudio Measure ThermostatBias. Even if you are running multiple calls of the Measure script ThermostatBias, you only need to call this Measure once only and this measure will change all the faulted zones appropriately. Please notice that this measure must be called before any reporting measures that utilize the values of the biased thermostat readings.'
  end

  # define the arguments that the user will input
  def arguments
    args = OpenStudio::Ruleset::OSArgumentVector.new

    return args
  end # end the arguments method

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # use the built-in error checking
    unless runner.validateUserArguments(arguments, user_arguments)
      return false
    end

    # find sqlfile path
    sqlfile = runner.lastEnergyPlusSqlFile
    if sqlfile.empty?
      runner.registerError('Cannot find last sql file.')
      return false
    end
    sqlfile = sqlfile.get
    sqlpath = sqlfile.path.to_s

    # get runmanager file path from sql path
    # find the location of string for either 'eplusout.sql'
    filename = 'measure_attributes.json'
    jsonpath = ''
    if sqlpath.include?('eplusout.sql')
      jsonpath = sqlpath.sub! 'eplusout.sql', filename
      runner.registerInfo("Locate #{filename} at #{jsonpath}")
    end

    if jsonpath.eql?('')
      runner.registerError("Cannot find #{filename}")
      return false
    end

    # read the json file
    jsonfile = open(jsonpath)
    jsoninfo = jsonfile.read
    begin
      measures = JSON.parse(jsoninfo)
    rescue JSON::ParserError => e
      runner.registerError("JSON::Exception occurred to open #{filename}")
      runner.registerError(e.message)
      runner.registerError(e.backtrace.inspect)
      return false
    end
    jsonfile.close

    # pass the ThermostatBias information to info entry
    fault_info = []
    measures.each do |key, value|
      if measures[key.to_s]['source'].to_s.eql?('ThermostatBias')
        zone_name = measures[key.to_s]['zone'].to_s
        info_entry = []
        # entering information of the faulted zone and the bias
        info_entry << zone_name.upcase  # name of zone in capital letters
        info_entry << measures[key.to_s]['bias_level'].to_f  # bias level
        info_entry << month_determination(measures[key.to_s]['start_month'].to_s)  # integer representing the starting month
        info_entry << month_determination(measures[key.to_s]['end_month'].to_s)  # integer representing the ending month
        fault_info << info_entry  # record the name and bias of zone thermostat
        runner.registerInfo("Zone #{zone_name.upcase} added with #{info_entry[1]}, #{info_entry[2]} and #{info_entry[3]}")
      end
    end

    # read measure script inputs
    bias_var_name = 'Zone Air Temperature'  # The characters in this name are not all capitalized

    fault_info.each do |zone_name, offset, start_month, end_month|
      # find the location of data needed: zone air temperature
      indexes = sqlfile.execAndReturnVectorOfString('SELECT ReportVariableDataDictionaryIndex FROM ReportVariableDataDictionary;').get
      reportvariabledatadictionaryindexs = []
      indexes.each do |index|
        id_str = index.to_s
        key = sqlfile.execAndReturnFirstString("SELECT KeyValue FROM ReportVariableDataDictionary WHERE ReportVariableDataDictionaryIndex=#{id_str};").get
        var_name = sqlfile.execAndReturnFirstString("SELECT VariableName FROM ReportVariableDataDictionary WHERE ReportVariableDataDictionaryIndex=#{id_str};").get
        if key.to_s.eql?(zone_name) && var_name.to_s.eql?(bias_var_name)
          reportvariabledatadictionaryindexs << id_str
          runner.registerInfo("Zone Air Temperature in #{zone_name} located with row information #{id_str}, #{key} and #{var_name}")
        end
      end

      # offset the data
      first_edit = false
      count = 0
      if reportvariabledatadictionaryindexs.length > 0  # only run if the value ti be offset is in the sql db
        reportvariabledatadictionaryindexs.each do |index|
          times = sqlfile.execAndReturnVectorOfInt("SELECT TimeIndex FROM TIME WHERE Month>=#{start_month} AND Month <=#{end_month};").get
          runner.registerInfo("Times obtained as #{times[0]} to #{times[times.length - 1]}")
          rowids = sqlfile.execAndReturnVectorOfString(
            "SELECT rowid FROM ReportVariableData WHERE ReportVariableDataDictionaryIndex=#{index}"\
            " AND TimeIndex>=#{times[0]} AND TimeIndex<=#{times[times.length - 1]};"
          ).get
          runner.registerInfo("Rowids obtained as #{rowids[0]} to #{rowids[rowids.length - 1]}")
          sqlfile.execute("SAVEPOINT CHANGE#{count};") # create savepoint
          rowids.each do |rowid|
            id_str = rowid.to_i.to_s
            var_val = sqlfile.execAndReturnFirstDouble("SELECT VariableValue FROM ReportVariableData WHERE rowid=#{id_str};").get
            errorcode = sqlfile.execute("UPDATE ReportVariableData SET VariableValue=#{var_val + offset} WHERE rowid=#{id_str};")
            unless first_edit
              runner.registerInfo("Zone Air Temperature in #{zone_name} adjusted by #{offset}")
              first_edit = true
            end
          end
          sqlfile.execute('COMMIT;')
          count += 1
        end
      end
    end

    sqlfile.close  # close at the moment for debugging. May remain opened in the final code.

    return true
  end # end the run method

  def row_vec_conversion(rows)
    # row is an array with each entry contained in another one-cell arrays
    # this function is used to convert rows into one array only in the form of strings
    gd_array = []
    rows.each do |row|
      gd_array << row[0].to_s
    end
    return gd_array
  end

  def month_determination(month)
    # return a number to represent the month given the string
    mon_str = (month.to_s)[0, 3].upcase
    mon_array = %w(JAN FEB MAR APR MAY JUN JUL AUG SEP OCT NOV DEC)
    (0..mon_array.length - 1).each do |i|
      if mon_str.eql?(mon_array[i])
        return i + 1
      end
    end
    return 0
  end
end # end the measure

# this allows the measure to be use by the application
ThermostatBiasReportingAnalysisSpreadSheet.new.registerWithApplication
