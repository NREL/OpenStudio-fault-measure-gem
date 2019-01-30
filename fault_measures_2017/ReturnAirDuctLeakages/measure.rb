#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require "#{File.dirname(__FILE__)}/resources/ControllerOutdoorAirFlow_DuctLeakage"

$allchoices = '* ALL Controller:OutdoorAir *'
$faulttype = 'DL'

# start the measure
class ReturnAirDuctLeakages < OpenStudio::Ruleset::WorkspaceUserScript

  # human readable name
  def name
    return 'Return Air Duct Leakages'
  end

  # human readable description
  def description
    return "The return duct of an air system typically operates at negative pressure, thus the leakage in the return duct (outside of conditioned space) results in increased heating and cooling load due to unconditioned air being drawn into the return duct and mixing with return air from conditioned spaces. This measure simulates the return air leakage by modifying the Controller:OutdoorAir object in EnergyPlus."
  end

  # human readable description of workspace approach
  def modeler_description
    return "Nine user inputs are required to simulate the fault and, based on these inputs, this fault model simulates the return air duct leakage by introducing additional outdoor air (based on the leakage ratio) through the economizer object. Equation (2) shows the calculation of outdoor airflow rate in the economizer (qdot_(oa,F)) at a faulted condition where qdot_oa is the outdoor airflow rate for ventilation, qdot_(ra,tot) is the return airflow rate, F is the fault intensity and AF is the adjustment factor. qdot_(oa,F) = qdot_oa + qdot_(ra,tot)∙F∙AF. The second term represents the outdoor airflow rate introduced to the duct due to leakage. The fault intensity (F) for this fault is defined as the unconditioned air introduced to return air stream at full load condition as a ratio of the total return airflow rate. The time required for the fault to reach the full level is only required when user wants to model dynamic fault evolution. If dynamic fault evolution is not necessary for the user, it can be defined as zero and the fault intensity will be imposed as a step function with user defined value. However, by defining the time required for the fault to reach the full level, fault starting month/date/time and fault ending month/date/time, the adjustment factor AF is calculated at each time step starting from the starting month/date/time to gradually impose fault intensity based on the user specified time frame. AF is calculated as follows, AF_current = AF_previous + dt/tau where AF_current is the adjustment factor calculated based on the previously calculated adjustment factor (AF_previous), simulation timestep (dt) and the time required for the fault to reach the full level (tau)."
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new
    
    #make choice arguments for economizers
    controlleroutdoorairs = workspace.getObjectsByType("Controller:OutdoorAir".to_IddObjectType)
    chs = OpenStudio::StringVector.new
    controlleroutdoorairs.each do |controlleroutdoorair|
      chs << controlleroutdoorair.name.to_s
    end
    econ_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('econ_choice', chs, true)
    econ_choice.setDisplayName('Outdoor air controller affected by the leakage of unconditioned air from the ambient.')
    econ_choice.setDefaultValue(chs[0].to_s)
    args << econ_choice
	
	#make a double argument for the return duct leakage
    leak_ratio = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('leak_ratio', false)
    leak_ratio.setDisplayName('Enter the unconditioned air introduced to return air stream at full load condition as a ratio of the total return airflow rate [0-1].')
    leak_ratio.setDefaultValue(0.1)  #default fault level to be 10%
    args << leak_ratio
	
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
    leak_ratio = runner.getDoubleArgumentValue('leak_ratio',user_arguments)
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
    if leak_ratio == 0
      runner.registerAsNotApplicable("#{name} is not running with zero fault level. Skipping......")
      return true
    end
    
    runner.registerInitialCondition("Imposing Return Duct Leakage on #{econ_choice}.")
  
    #find the RTU to change
    no_econ_found = true
    applicable = true
    controlleroutdoorairs = workspace.getObjectsByType('Controller:OutdoorAir'.to_IddObjectType)
    controlleroutdoorairs.each do |controlleroutdoorair|
      if controlleroutdoorair.getString(0).to_s.eql?(econ_choice) || econ_choice.eql?($allchoices)
        no_econ_found = false
        
        #check applicability of the model        
        if controlleroutdoorair.getString(8).to_s.eql?('MinimumFlowWithBypass')
          runner.registerAsNotApplicable("MinimumFlowWithBypass in #{econ_choice} is not supported. Skipping......")
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
		  oacontrollername = econ_choice.clone.gsub!(/[^0-9A-Za-z]/, '')
		  
		  ######################################################################################
		  
		  if controlleroutdoorair.getString(7).to_s.eql?('NoEconomizer')
		    runner.registerInfo("Current model is not using the economizer. EMS will override the outdoor air flow rate with the actuator.")
			if leak_ratio >= 0.00
			  leakratio = "#{leak_ratio}"
		    else
			  leakratio = "-#{leak_ratio}"
		    end
		    nodename_ma = controlleroutdoorair.getString(3)
			runner.registerInfo("Mixed air outlet node name for reference = #{nodename_ma}")
			
			string_objects << "			
			  EnergyManagementSystem:Sensor,
				SA_#{$faulttype}, !- Name
				#{nodename_ma}, !- Output:Variable or Output:Meter Index Key Name
				System Node Mass Flow Rate; !- Output:Variable or Output:Meter Name
			"
			string_objects << "
			  EnergyManagementSystem:Actuator,
				OA_#{$faulttype}, !- Name
				#{econ_choice}, !- Actuated Component Unique Name
				Outdoor Air Controller, !- Actuated Component Type
				Air Mass Flow Rate; !- Actuated Component Control Type
			"
			string_objects << "
			  EnergyManagementSystem:Program,
				RA_#{$faulttype}, !- Name
				set FI_#{$faulttype}_RA = "+leakratio+", !- Program Line 1
				set OA_#{$faulttype} = SA_#{$faulttype}*FI_#{$faulttype}_RA*AF_current_#{$faulttype}_#{oacontrollername}; !- Program Line 2
			"
			string_objects << "
			  EnergyManagementSystem:ProgramCallingManager,
				PCM_#{$faulttype}, !- Name
				InsideHVACSystemIterationLoop, !- EnergyPlus Model Calling Point
				RA_#{$faulttype}; !- Program Name 1
			"
			strings_objects = faultintensity_adjustmentfactor(string_objects, time_constant, time_step, start_month, start_date, start_time, end_month, end_date, end_time, oacontrollername)
		  else	
            main_body = econ_ductleakage_ems_main_body(workspace, controlleroutdoorair, leak_ratio, oacontrollername)
            string_objects << main_body
           
            #append other objects
            strings_objects = econ_ductleakage_ems_other(string_objects, workspace, controlleroutdoorair)
		    strings_objects = faultintensity_adjustmentfactor(string_objects, time_constant, time_step, start_month, start_date, start_time, end_month, end_date, end_time, oacontrollername)
		  end
		  ######################################################################################

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
      runner.registerFinalCondition("Imposed Return Duct Leakage on #{econ_choice}.")
    else
      runner.registerAsNotApplicable("#{name} is not running for #{econ_choice} because of inapplicability. Skipping......")
    end

    return true

  end
  
end

# register the measure to be used by the application
ReturnAirDuctLeakages.new.registerWithApplication
