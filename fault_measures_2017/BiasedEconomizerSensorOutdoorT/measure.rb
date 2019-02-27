#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require "#{File.dirname(__FILE__)}/resources/ControllerOutdoorAirFlow_T"

$allchoices = '* ALL Controller:OutdoorAir *'
$faulttype = 'OAT'				   

# start the measure
class BiasedEconomizerSensorOAT < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return 'Biased Economizer Sensor: Outdoor Temperature'
  end

  # human readable description
  def description
    return "When sensors drift and are not regularly calibrated, it causes a bias. Sensor readings often drift from their calibration with age, causing equipment control algorithms to produce outputs that deviate from their intended function. This fault is categorized as a fault that occur in the economizer system (sensor) during the operation stage. This fault measure is based on a physical model where certain parameter(s) is changed in EnergyPlus to mimic the faulted operation; thus simulates the biased economizer sensor (outdoor temperature) by modifying Controller:OutdoorAir object in EnergyPlus assigned to the heating and cooling system. The fault intensity (F) is defined as the biased temperature level (K). A positive number means that the sensor is reading a temperature higher than the true temperature."
  end

  # human readable description of workspace approach
  def modeler_description
    return "Nine user inputs are required and, based on these user inputs, the outdoor air temperature reading in the economizer will be replaced by the equation below, ToaF = Toa + F*AF, where ToaF is the biased outdoor air temperature reading, Toa is the actual outdoor air temperature, F is the fault intensity and AF is the adjustment factor. To use this measure, choose the Controller:OutdoorAir object to be faulted. Set the level of temperature sensor bias in K that you want at the outdoors for the economizer during the simulation period. For example, setting 2 means the sensor is reading 28C when the actual temperature is 26C. The time required for the fault to reach the full level is only required when the user wants to model fault evolution. If the fault evolution is not necessary for the user, it can be defined as zero and F will be imposed as a step function with the user defined value. However, by defining the time required for the fault to reach the full level, fault starting month/date/time and fault ending month/date/time, the adjustment factor AF is calculated at each time step starting from the starting month/date/time to gradually impose F based on the user specified time frame. AF is calculated as follows, AF_current = AF_previous + dt/tau where AF_current is the adjustment factor calculated based on the previously calculated adjustment factor (AF_previous), simulation timestep (dt) and the time required for the fault to reach the full level (tau)."
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    ##################################################
    #make choice arguments for economizers
    controlleroutdoorairs = workspace.getObjectsByType("Controller:OutdoorAir".to_IddObjectType)
    chs = OpenStudio::StringVector.new
    controlleroutdoorairs.each do |controlleroutdoorair|
      chs << controlleroutdoorair.name.to_s
    end
    econ_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('econ_choice', chs, true)
    econ_choice.setDisplayName("Choice of economizers.")
    econ_choice.setDefaultValue(chs[0].to_s)
    args << econ_choice
    ##################################################
	
    #make a double argument for the temperature sensor bias
    out_t_bias = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('out_t_bias', false)
    out_t_bias.setDisplayName('Enter the bias level of the outdoor air temperature sensor. A positive number means that the sensor is reading a temperature higher than the true temperature. [K]')
    out_t_bias.setDefaultValue(-2)  #default fault level to be -2K
    args << out_t_bias
	
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
    start_month.setDefaultValue(6)  #default is June
    args << start_month
	
	#make a double argument for the start date
    start_date = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_date', false)
    start_date.setDisplayName('Enter the date (1-28/30/31) when the fault starts to occur')
    start_date.setDefaultValue(1)  #default is 1st day of the month
    args << start_date
	
	#make a double argument for the start time
    start_time = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_time', false)
    start_time.setDisplayName('Enter the time of day (0-24) when the fault starts to occur')
    start_time.setDefaultValue(9)  #default is 9am
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
    if !runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end
    
    #obtain values
    econ_choice = runner.getStringArgumentValue('econ_choice',user_arguments)
    out_t_bias = runner.getDoubleArgumentValue('out_t_bias',user_arguments)
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
	 runner.registerInfo("Simulation Timestep = #{1./dt.getString(0).get.clone.to_f}")
	 time_step = (1./dt.getString(0).get.clone.to_f).to_s
	end
	##################################################
    bias_sensor = "OA"
    if out_t_bias == 0
      runner.registerAsNotApplicable("#{name} is not running with zero fault level. Skipping......")
      return true
    end
    
    runner.registerInitialCondition("Imposing Sensor Bias on #{econ_choice}.")
  
    #find the RTU to change
    no_econ_found = true
    applicable = true
    controlleroutdoorairs = workspace.getObjectsByType('Controller:OutdoorAir'.to_IddObjectType)
    controlleroutdoorairs.each do |controlleroutdoorair|
      if controlleroutdoorair.getString(0).to_s.eql?(econ_choice) || econ_choice.eql?($allchoices)
        no_econ_found = false
        
        #check applicability of the model        
        if controlleroutdoorair.getString(8).to_s.eql?('MinimumFlowWithBypass')
          runner.registerAsNotApplicable("MinimumFlowWithBypass in #{econ_choice} is not an economizer and is not supported. Skipping......")
          applicable = false
        elsif controlleroutdoorair.getString(14).to_s.eql?('LockoutWithHeating') or controlleroutdoorair.getString(14).to_s.eql?("LockoutWithCompressor")
          runner.registerAsNotApplicable(controlleroutdoorair.getString(14).to_s+" in #{econ_choice} is not supported. Skipping......")
          applicable = false
        elsif controlleroutdoorair.getString(25).to_s.eql?('BypassWhenOAFlowGreaterThanMinimum')
          runner.registerAsNotApplicable(controlleroutdoorair.getString(25).to_s+" in #{econ_choice} is not supported. Skipping......")
          applicable = false
        end
        
        if applicable  #skip the modeling procedure if the model is not supported
          #create an empty string_objects to be appended into the .idf file
          string_objects = []
          
          #append the main EMS program objects to the idf file
          
          #main program differs as the options at controlleroutdoorair differs
          #create a new string for the main program to start appending the required
          #EMS routine to it
          ##################################################
		  oacontrollername = econ_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
		  ##################################################        
		  
          main_body = econ_t_sensor_bias_ems_main_body(workspace, bias_sensor, controlleroutdoorair, [0.0, out_t_bias], oacontrollername)
          
          string_objects << main_body
          
          #append other objects
          strings_objects = econ_t_sensor_bias_ems_other(string_objects, workspace, bias_sensor, controlleroutdoorair)
		  ##################################################
		  strings_objects = faultintensity_adjustmentfactor(string_objects, time_constant, time_step, start_month, start_date, start_time, end_month, end_date, end_time, oacontrollername)
		  ##################################################
          
          #add all of the strings to workspace to create IDF objects
          string_objects.each do |string_object|
            idfObject = OpenStudio::IdfObject::load(string_object)
            object = idfObject.get
            wsObject = workspace.addObject(object)
          end
        end
      end
    end
    
    #give an error for the name if no RTU is changed
    if no_econ_found
      runner.registerError("Measure #{name} cannot find #{econ_choice}. Exiting......")
      return false
    elsif applicable
      # report final condition of workspace
      runner.registerFinalCondition("Imposed Sensor Bias on #{econ_choice}.")
    else
      runner.registerAsNotApplicable("#{name} is not running for #{econ_choice} because of inapplicability. Skipping......")
    end

    return true

  end
  
end

# register the measure to be used by the application
BiasedEconomizerSensorOAT.new.registerWithApplication
