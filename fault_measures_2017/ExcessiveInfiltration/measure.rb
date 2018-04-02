#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

require "#{File.dirname(__FILE__)}/resources/faultimplementation"

$faultnow = 'EI'

#start the measure
class ExcessiveInfiltration < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "Excessive Infiltration"
  end
  
  # human readable description
  def description
    return "Excessive infiltration around the building envelope occurs by the unintentional introduction of outside air into a building, typically through cracks in the building envelope and through use of windows and doors. Infiltration is driven by pressure differences between indoors and outdoors of the building caused by wind and by air buoyancy forces known commonly as the stack effect (ASHRAE Handbook Fundamentals, 2005). Excessive infiltration can affect thermal comfort, indoor air quality, heating and cooling demand, and moisture damage of building envelope components (Emmerich et al., 2005). The fault intensity is defined as the percentage of excessive infiltration around the building envelope compared to the non-faulted condition."
  end
  
  # human readable description of modeling approach
  def modeler_description
    return "The user input of the percentage of excessive infiltration is applied to one of either four variables (Design Flow Rate, Flow per Zone Floor Area, Flow per Exterior Surface Area, Air Changes per Hour) in ZoneInfiltration:DesignFlowRate object and one variable (Effective Air Leakage Area) in ZoneInfiltration:EffectiveLeakageArea depending on the user’s choice of infiltration implementation method to impose fault over the original (non-faulted) configuration. The modified value (Infil_m) is calculated as Infil_m = Infil_o * (1+F/100), where Infil_o is the original value defined in the infiltration object and F is the percentage of excessive infiltration. The time required for the fault to reach the full level is only required when user wants to model dynamic fault evolution. If dynamic fault evolution is not necessary for the user, it can be defined as zero and the fault intensity will be imposed as a step function with user defined value. However, by defining the time required for the fault to reach the full level, fault starting month/date/time and fault ending month/date/time, the adjustment factor AF is calculated at each time step starting from the starting month/date/time to gradually impose fault intensity based on the user specified time frame. AF is calculated as follows, AF_current = AF_previous + dt/tau where AF_current is the adjustment factor calculated based on the previously calculated adjustment factor (AF_previous), simulation timestep (dt) and the time required for the fault to reach the full level (tau)."
  end

  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make a choice argument for model objects
    thermalzone_handles = OpenStudio::StringVector.new
    thermalzone_display_names = OpenStudio::StringVector.new

    #putting model object and names into hash
    thermalzone_args = model.getSpaces
    thermalzone_args_hash = {}
    thermalzone_args.each do |thermalzone_arg|
      thermalzone_args_hash[thermalzone_arg.name.to_s] = thermalzone_arg
    end
	
	#looping through sorted hash of model objects
    thermalzone_args_hash.sort.map do |key,value|
      thermalzone_handles << value.handle.to_s
      thermalzone_display_names << key
    end
	thermalzone_display_names << "*Entire Building*"

    #add building to string vector with space type
    building = model.getBuilding
    thermalzone_handles << building.handle.to_s 

    #make a choice argument for space type
    thermalzone = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("thermalzone", thermalzone_handles, thermalzone_display_names)
    thermalzone.setDisplayName("Apply the Measure to a Specific Space Type or to the Entire Model.")
    thermalzone.setDefaultValue("*Entire Building*") #if no space type is chosen this will run on the entire building
    args << thermalzone

    #make an argument for excessive infiltration percentage
    space_infiltration_increase_percent = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("space_infiltration_increase_percent",true)
    space_infiltration_increase_percent.setDisplayName("Space Infiltration Increase (%).")
    space_infiltration_increase_percent.setDefaultValue(20.0)
    args << space_infiltration_increase_percent
	
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
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    object = runner.getOptionalWorkspaceObjectChoiceValue("thermalzone",user_arguments,model)		
    space_infiltration_increase_percent = runner.getDoubleArgumentValue("space_infiltration_increase_percent",user_arguments)
	#################################################################################
    time_constant = runner.getDoubleArgumentValue('time_constant',user_arguments)
	start_month = runner.getDoubleArgumentValue('start_month',user_arguments)
	start_date = runner.getDoubleArgumentValue('start_date',user_arguments)
	start_time = runner.getDoubleArgumentValue('start_time',user_arguments)
	end_month = runner.getDoubleArgumentValue('end_month',user_arguments)
	end_date = runner.getDoubleArgumentValue('end_date',user_arguments)
	end_time = runner.getDoubleArgumentValue('end_time',user_arguments)	
	time_interval = model.getTimestep.numberOfTimestepsPerHour
	time_step = (1./(time_interval.to_f))	
	#################################################################################

    #check the thermalzone for reasonableness and see if measure should run on space type or on the entire building
    apply_to_building = false
    thermalzone = nil
    if object.empty?
      handle = runner.getStringArgumentValue("thermalzone",user_arguments)
      if handle.empty?
        runner.registerError("No space type was chosen.")
      else
        runner.registerError("The selected space type with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not object.get.to_Space.empty?
        thermalzone = object.get.to_Space.get
		##################################################
	    space_name = object.get.to_Space.get.name
	    runner.registerInfo("Selected space name = #{space_name}")
	    ##################################################
      elsif not object.get.to_Building.empty?
        apply_to_building = true
		##################################################
	    runner.registerInfo("Infiltration applied to entire bldg.")
	    ##################################################
      else
        runner.registerError("Script Error - argument not showing up as space type or building.")
        return false
      end
    end

    #check the space_infiltration_increase_percent and for reasonableness
    if space_infiltration_increase_percent > 100
      runner.registerError("Please enter a value less than or equal to 100 for the space infiltration increase percentage.")
      return false
    elsif space_infiltration_increase_percent == 0
      runner.registerInfo("No space infiltration adjustment requested, but some life cycle costs may still be affected.")
    elsif space_infiltration_increase_percent < 1 and space_infiltration_increase_percent > -1
      runner.registerWarning("A space infiltration increase percentage of #{space_infiltration_increase_percent} percent is abnormally low.")
    elsif space_infiltration_increase_percent > 90
      runner.registerWarning("A space infiltration increase percentage of #{space_infiltration_increase_percent} percent is abnormally high.")
    elsif space_infiltration_increase_percent < 0
      runner.registerInfo("The requested value for space infiltration increase percentage was negative. This will result in a reduction in space infiltration.")
    end

    #get space infiltration objects used in the model
    space_infiltration_objects = model.getSpaceInfiltrationDesignFlowRates
    space_infiltration_ela_objects = model.getSpaceInfiltrationEffectiveLeakageAreas

    #counters needed for measure
    altered_instances = 0

    #reporting initial condition of model
    if space_infiltration_objects.size > 0 || space_infiltration_ela_objects.size > 0 
      runner.registerInitialCondition("The initial model contained #{space_infiltration_objects.size + space_infiltration_ela_objects.size} space infiltration objects.")	  
    else
      runner.registerInitialCondition("The initial model did not contain any space infiltration objects.")
    end
	
	#################################################################################
	#create a schedule object to be used in infiltration objects
	schedule_const = OpenStudio::Model::ScheduleConstant.new(model)	
	schedule_const.setName("faultlvlsch_#{$faultnow}")
	schedule_const.setValue(0)
	#################################################################################

    #getting spaces in the model
    spaces = model.getSpaces
 
	#################################################################################
    #loop through spaces for ZoneInfiltration:DesignFlowRate
    spaces.each do |space|
      space_infiltration_objects = space.spaceInfiltrationDesignFlowRates
      space_infiltration_objects.each do |space_infiltration_object|
	  
	    short_name = name_cut(space_infiltration_object.name.to_s)
	    
	    if apply_to_building == true

          #call def to alter performance and life cycle costs
          alter_performance(model, space_infiltration_object, space_infiltration_increase_percent, runner, schedule_const, start_month, start_date, start_time, end_month, end_date, end_time, time_constant, time_step, short_name)

          #rename
          updated_instance_name = space_infiltration_object.setName("#{space_infiltration_object.name} #{space_infiltration_increase_percent} percent increase")
		  runner.registerInfo("#{updated_instance_name}")
          altered_instances += 1
		else
		  if space.name.to_s == space_name.to_s

            #call def to alter performance and life cycle costs
            alter_performance(model, space_infiltration_object, space_infiltration_increase_percent, runner, schedule_const, start_month, start_date, start_time, end_month, end_date, end_time, time_constant, time_step, short_name)

            #rename
            updated_instance_name = space_infiltration_object.setName("#{space_infiltration_object.name} #{space_infiltration_increase_percent} percent increase")
		    runner.registerInfo("#{updated_instance_name}")
            altered_instances += 1
		  end
		end  
      end 
	  
    end 
    #################################################################################
    #loop through spaces for ZoneInfiltration:EffectiveLeakageArea
    spaces.each do |space|
      space_infiltration_ela_objects = space.spaceInfiltrationEffectiveLeakageAreas
      space_infiltration_ela_objects.each do |space_infiltration_ela_object|
	  
	    short_name = name_cut(space_infiltration_ela_objects.name.to_s)
	    
		if apply_to_building == true

          #call def to alter performance and life cycle costs
          alter_performance_ela(object, space_infiltration_increase_percent, runner, schedule_const, start_month, start_date, start_time, end_month, end_date, end_time, time_constant, time_step, short_name)

          #rename
          updated_instance_name = space_infiltration_ela_object.setName("#{space_infiltration_ela_object.name} #{space_infiltration_increase_percent} percent increase")
	  	  runner.registerInfo("#{updated_instance_name}")
          altered_instances += 1
		  
		else
		  if space.name.to_s == space_name.to_s
		  
			#call def to alter performance and life cycle costs
            alter_performance_ela(object, space_infiltration_increase_percent, runner, schedule_const, start_month, start_date, start_time, end_month, end_date, end_time, time_constant, time_step, short_name)
 
            #rename
            updated_instance_name = space_infiltration_ela_object.setName("#{space_infiltration_ela_object.name} #{space_infiltration_increase_percent} percent increase")
	        runner.registerInfo("#{updated_instance_name}")
            altered_instances += 1
		  end
		end
		  
      end 
    end
    #################################################################################
	
    #report final condition
    runner.registerFinalCondition("#{altered_instances} space infiltration objects in the model were altered.")

  end #end the run method

end #end the measure

#this allows the measure to be use by the application
ExcessiveInfiltration.new.registerWithApplication
