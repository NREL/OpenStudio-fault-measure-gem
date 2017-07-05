require 'erb'
require 'time'
begin #skip it if it cannot be loaded; OS GUI can't load it and won't use it
  require 'sqlite3'
rescue LoadError
end

#start the measure
class ThermostatBiasReporting < OpenStudio::Ruleset::ReportingUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "ThermostatBiasReporting"
  end
  
  def description
    return "This measure changes the zone air temperature readings in eplusout.sql file so that the zone air temperature is showing the biased reading rather than the true reading of the thermostats."
  end
  
  def modeler_description
    return "This measure reads the workflow sql database 'run.db' to know the location and the bias of the faulted thermostat and adjust the 'Zone Air Temperature' in the output database 'eplusout.sql'. It adjusts the database according to the bias level, the starting month and the ending month of the OpenStudio Measure ThermostatBias. Even if you are running multiple calls of the Measure script ThermostatBias, you only need to call this Measure once only and this measure will change all the faulted zones appropriately. Please notice that this measure must be called before any reporting measures that utilize the values of the biased thermostat readings."
  end
  
  #define the arguments that the user will input
  def arguments()
    args = OpenStudio::Ruleset::OSArgumentVector.new

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    #use the built-in error checking
    if not runner.validateUserArguments(arguments(), user_arguments)
      return false
    end
    
    #find sqlfile path
    sqlFile = runner.lastEnergyPlusSqlFile
    if sqlFile.empty?
      runner.registerError("Cannot find last sql file.")
      return false
    end
    sqlFile = sqlFile.get
    sqlPath = sqlFile.path.to_s
    
    #get runmanager file path from sql path
    #find the location of string for either 'run\5-EnergyPlus-0\eplusout.sql' or 'run\6-EnergyPlus-0\eplusout.sql' or 'run/5-EnergyPlus-0/eplusout.sql' or 'run/5-EnergyPlus-0/eplusout.sql'
    filename = "run.db"
    pos_strings = ["run\\5-EnergyPlus-0\\eplusout.sql", "run\\6-EnergyPlus-0\\eplusout.sql", "run/5-EnergyPlus-0/eplusout.sql", "run/6-EnergyPlus-0/eplusout.sql"]
    # pos_strings = ["run\\eplusout.sql", "run/eplusout.sql"]
    rundbPath = ""
    pos_strings.each do |pos_string|
      if sqlPath.include?(pos_string)
        rundbPath = sqlPath.sub! pos_string, filename
        runner.registerInfo("Locate "+filename+" at "+rundbPath)
      end
    end
    if rundbPath.eql?("")
      runner.registerError("Cannot find run.db through "+sqlPath)
      return false
    end
    
    #check if sqlFile function can open rundb fil
    #rundbFile = OpenStudio::SqlFile.new(rundbPath)
    #result:
    #[openstudio.energyplus.SqlFile] <0> Trying unsupported EnergyPlus version 8.2
    #[openstudio.energyplus.SqlFile] <0> Trying unsupported EnergyPlus version 6.0
    #[openstudio.energyplus.SqlFile] <1> Exception while opening database at 'C:/Users/hcheung/AppData/Local/Temp/1/OpenStudio.ZM7012/resources/run.db': ResultsViewer is not compatible with this file.
    #OpenStudio::SqlFile cannot open sqlfile other than eplusout.sql
    
    #read run.db file
    #open sql table
    begin
      db = SQLite3::Database.open(rundbPath)
    rescue SQLite3::Exception => e 
      runner.registerError("SQLite3::Exception occurred to open run.db")
      runner.registerError(e.message)
      runner.registerError(e.backtrace.inspect)
      return false
    end
    
    #find the location and output the parameters in a vector of strings
    #find the lines of the rubyrequiredfiles entry for ThermostatBias fault
    begin
      stm = db.prepare("SELECT parentId_ from JobParam_ where value_ like '%ThermostatBias%';")
    rescue
      runner.registerError("SQLite3 cannot run the SELECT command correctly")
      runner.registerError(e.message)
      runner.registerError(e.backtrace.inspect)
      return false      
    end
    rows = stm.execute
    rubyrequiredfiles_ = []
    rows.each do |row|
      new_entry = true
      rubyrequiredfiles_.each do |rubyrequiredfile|
        if row[0].to_s.eql?(rubyrequiredfile)
          new_entry = false
        end
      end
      if new_entry
        rubyrequiredfiles_ << row[0].to_s
      end
    end
    stm.close if stm
    
    #record the parentIDs for the list of the ruby jobs from the lines of the rubyrequiredfiles
    execute_line = "SELECT parentId_ from JobParam_ where id_="+rubyrequiredfiles_[0]
    for i in 1..rubyrequiredfiles_.length-1
      execute_line = execute_line+" or id_="+rubyrequiredfiles_[i]
    end
    execute_line = execute_line+";"
    stm = db.prepare(execute_line)
    rows = stm.execute
    list_ids = row_vec_conversion(rows)
    stm.close if stm
    
    #find the ids of the argument values
    execute_line = "SELECT id_ from JobParam_ where (parentId_="+list_ids[0]
    for i in 1..list_ids.length-1
      execute_line = execute_line+" or parentId_="+list_ids[i]
    end
    execute_line = execute_line+") and value_='ruby_scriptparameters';";
    stm = db.prepare(execute_line)
    rows = stm.execute
    arglist_ids = row_vec_conversion(rows)
    stm.close if stm
    
    #print all values after joining them together for debugging    
    execute_line = "SELECT value_ from JobParam_ where (parentId_="+arglist_ids[0]
    for i in 1..arglist_ids.length-1
      execute_line = execute_line+" or parentId_="+arglist_ids[i]
    end
    execute_line = execute_line+");";
    stm = db.prepare(execute_line)
    rows = stm.execute
    run_args = row_vec_conversion(rows)
    stm.close if stm
    
    #find the zone that the thermostat is biased from the parameters and the model object
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Cannot find last model.")
      return false
    end
    model = model.get
    model.setSqlFile(sqlFile)
  
    #looping through sorted hash of model objects
    fault_info = []
    arglist_ids.each do |arglist_id|
      execute_line = "SELECT value_ from JobParam_ where parentId_="+arglist_id+";";
      stm = db.prepare(execute_line)
      rows = stm.execute
      run_args = row_vec_conversion(rows)
      stm.close if stm
      if run_args.length >= 7 #some of them do not contain relevant information. Check for skipping.
        zone_name = run_args[1].sub!('--argumentValue=', '').to_s
        info_entry = []
        #entering information of the faulted zone and the bias
        info_entry << zone_name.upcase  #name of zone in capital letters
        info_entry << run_args[3].sub!('--argumentValue=', '').to_f  #bias level
        info_entry << month_determination(run_args[5].sub!('--argumentValue=', '').to_s)  #integer representing the starting month
        info_entry << month_determination(run_args[7].sub!('--argumentValue=', '').to_s)  #integer representing the ending month
        fault_info << info_entry  #record the name and bias of zone thermostat
        runner.registerInfo("Find "+zone_name+" with "+info_entry[1].to_s+", "+info_entry[2].to_s+" and "+info_entry[3].to_s)
      end
    end
    
    #database closed
    db.close if db
    
    #read measure script inputs
    bias_var_name = "Zone Air Temperature"  #The characters in this name are not all capitalized
    fault_info.each do |zone_name, offset, start_month, end_month|
      #find the location of data needed: zone air temperature
      indexes = sqlFile.execAndReturnVectorOfString("SELECT ReportVariableDataDictionaryIndex FROM ReportVariableDataDictionary;").get
      reportvariabledatadictionaryindexs = []
      indexes.each do |index|
        id_str = index.to_s
        key = sqlFile.execAndReturnFirstString("SELECT KeyValue FROM ReportVariableDataDictionary WHERE ReportVariableDataDictionaryIndex="+id_str+";").get
        var_name = sqlFile.execAndReturnFirstString("SELECT VariableName FROM ReportVariableDataDictionary WHERE ReportVariableDataDictionaryIndex="+id_str+";").get
        if key.to_s.eql?(zone_name) and var_name.to_s.eql?(bias_var_name)
          reportvariabledatadictionaryindexs << id_str
          runner.registerInfo("Zone Air Temperature in "+zone_name+" located with row information "+id_str+", "+key+" and "+var_name+"")
        end
      end
      
      #offset the data      
      first_edit = false
      count = 0
      if reportvariabledatadictionaryindexs.length > 0  #only run if the value ti be offset is in the sql db
        reportvariabledatadictionaryindexs.each do |index|
          times = sqlFile.execAndReturnVectorOfInt("SELECT TimeIndex FROM TIME WHERE Month>=#{start_month} AND Month <=#{end_month};").get
          runner.registerInfo("Times obtained as #{times[0]} to #{times[times.length-1]}")
          rowids = sqlFile.execAndReturnVectorOfString(
            "SELECT rowid FROM ReportVariableData WHERE ReportVariableDataDictionaryIndex="+index+
            " AND TimeIndex>=#{times[0]} AND TimeIndex<=#{times[times.length-1]};"
          ).get
          runner.registerInfo("Rowids obtained as "+rowids[0]+" to "+rowids[rowids.length-1])
          sqlFile.execute("SAVEPOINT CHANGE"+count.to_s+";") #create savepoint
          rowids.each do |rowid|
            id_str = rowid.to_i.to_s
            var_val = sqlFile.execAndReturnFirstDouble("SELECT VariableValue FROM ReportVariableData WHERE rowid="+id_str+";").get
            errorcode = sqlFile.execute("UPDATE ReportVariableData SET VariableValue=#{var_val+offset} WHERE rowid="+id_str+";")
            if not first_edit
              runner.registerInfo("Zone Air Temperature in "+zone_name+" adjusted by #{offset}")
              first_edit = true
            end
          end
          sqlFile.execute("COMMIT;")
          count = count+1
        end
      end
    end
    
    sqlFile.close  #close at the moment for debugging. May remain opened in the final code.
    
    return true

  end #end the run method
  
  def row_vec_conversion(rows)
    #row is an array with each entry contained in another one-cell arrays
    #this function is used to convert rows into one array only in the form of strings
    gd_array = []
    rows.each do |row|
      gd_array << row[0].to_s
    end
    return gd_array
  end
  
  def month_determination(month)
    #return a number to represent the month given the string
    mon_str = (month.to_s)[0,3].upcase
    mon_array = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC']
    for i in 0..mon_array.length-1
      if mon_str.eql?(mon_array[i])
        return i+1
      end
    end
    return 0
  end

end #end the measure

#this allows the measure to be use by the application
ThermostatBiasReporting.new.registerWithApplication