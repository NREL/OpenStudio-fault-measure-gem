# Excessive Infiltration

## Description

    def description
    return "Excessive infiltration around the building envelope occurs by the unintentional introduction of outside air into a building, typically through cracks in the building envelope and through use of windows and doors. Infiltration is driven by pressure differences between indoors and outdoors of the building caused by wind and by air buoyancy forces known commonly as the stack effect. Excessive infiltration can affect thermal comfort, indoor air quality, heating and cooling demand, and moisture damage of building envelope components. This fault is categorized as a fault that occur in the building envelope during the operation stage. This fault measure is based on a physical model where certain parameter(s) is changed in EnergyPlus to mimic the faulted operation; thus simulates an excessive infiltration by modifying ZoneInfiltration:DesignFlowRate or ZoneInfiltration:EffectiveLeakageArea objects in EnergyPlus. The fault intensity (F) is defined as the ratio of excessive infiltration around the building envelope compared to the non-faulted condition."
  end
  
## Modeler Description

  def modeler_description
    return "The user input of the ratio of excessive infiltration is applied to one of either four variables (Design Flow Rate, Flow per Zone Floor Area, Flow per Exterior Surface Area, Air Changes per Hour) in ZoneInfiltration:DesignFlowRate object and one variable (Effective Air Leakage Area) in ZoneInfiltration:EffectiveLeakageArea depending on the user’s choice of infiltration implementation method to impose fault over the original (non-faulted) configuration. The modified value (Infil_m) is calculated as Infil_m = Infil_o * (1+F), where Infil_o is the original value defined in the infiltration object and F is the ratio of excessive infiltration. The time required for the fault to reach the full level is only required when the user wants to model fault evolution. If the fault evolution is not necessary for the user, it can be defined as zero and F will be imposed as a step function with the user defined value. However, by defining the time required for the fault to reach the full level, fault starting month/date/time and fault ending month/date/time, the adjustment factor AF is calculated at each time step starting from the starting month/date/time to gradually impose F based on the user specified time frame. AF is calculated as follows, AF_current = AF_previous + dt/tau where AF_current is the adjustment factor calculated based on the previously calculated adjustment factor (AF_previous), simulation timestep (dt) and the time required for the fault to reach the full level (tau)."
  end
  
## Measure Type

OpenStudio Measure 
	
## Taxonomy

Envelope.Infiltration

## Arguments 

def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    thermalzone_handles = OpenStudio::StringVector.new
    thermalzone_display_names = OpenStudio::StringVector.new

    thermalzone_args = model.getSpaces
    thermalzone_args_hash = {}
    thermalzone_args.each do |thermalzone_arg|
      thermalzone_args_hash[thermalzone_arg.name.to_s] = thermalzone_arg
    end
	
    thermalzone_args_hash.sort.map do |key,value|
      thermalzone_handles << value.handle.to_s
      thermalzone_display_names << key
    end
	thermalzone_display_names << "*Entire Building*"

    building = model.getBuilding
    thermalzone_handles << building.handle.to_s 

    thermalzone = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("thermalzone", thermalzone_handles, thermalzone_display_names)
    thermalzone.setDisplayName("Apply the Measure to a Specific Space Type or to the Entire Model.")
    thermalzone.setDefaultValue("*Entire Building*") #if no space type is chosen this will run on the entire building
    args << thermalzone

    space_infiltration_increase_percent = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("space_infiltration_increase_percent",true)
    space_infiltration_increase_percent.setDisplayName("Space Infiltration Increase (%).")
    space_infiltration_increase_percent.setDefaultValue(20.0)
    args << space_infiltration_increase_percent

    time_constant = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('time_constant', false)
    time_constant.setDisplayName('Enter the time required for fault to reach full level [hr]')
    time_constant.setDefaultValue(0)  #default is zero
    args << time_constant
	
    start_month = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_month', false)
    start_month.setDisplayName('Enter the month (1-12) when the fault starts to occur')
    start_month.setDefaultValue(6)  #default is June
    args << start_month
	
    start_date = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_date', false)
    start_date.setDisplayName('Enter the date (1-28/30/31) when the fault starts to occur')
    start_date.setDefaultValue(1)  #default is 1st day of the month
    args << start_date
	
    start_time = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_time', false)
    start_time.setDisplayName('Enter the time of day (0-24) when the fault starts to occur')
    start_time.setDefaultValue(9)  #default is 9am
    args << start_time
	
    end_month = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('end_month', false)
    end_month.setDisplayName('Enter the month (1-12) when the fault ends')
    end_month.setDefaultValue(12)  #default is Decebmer
    args << end_month
	
    end_date = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('end_date', false)
    end_date.setDisplayName('Enter the date (1-28/30/31) when the fault ends')
    end_date.setDefaultValue(31)  #default is last day of the month
    args << end_date
	
    end_time = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('end_time', false)
    end_time.setDisplayName('Enter the time of day (0-24) when the fault ends')
    end_time.setDefaultValue(23)  #default is 11pm
    args << end_time

    return args
  end
  
## Initial Condition

    runner.registerInitialCondition("The initial model contained #{space_infiltration_objects.size + space_infiltration_ela_objects.size} space infiltration objects.")
    runner.registerInitialCondition("The initial model did not contain any space infiltration objects.")

## Final Condition

    runner.registerFinalCondition("#{altered_instances} space infiltration objects in the model were altered.")

## Not Applicable

    runner.registerAsNotApplicable("No space infiltration objects were found in the specified space type(s) and no life cycle costs were requested.")

## Warning

    runner.registerWarning("A space infiltration increase percentage of #{space_infiltration_increase_percent} percent is abnormally low.")
    runner.registerWarning("A space infiltration increase percentage of #{space_infiltration_increase_percent} percent is abnormally high.")
    runner.registerWarning("'#{instance.name}' is used by one or more instances and has no load values.")

## Error

    runner.registerError("No space type was chosen.")
    runner.registerError("The selected space type with handle '#{handle}' was not found in the model. It may have been removed by another measure.")

## Information

•	Works with, 
•	ZoneInfiltration:DesignFlowRate
•	ZoneInfiltration:EffectiveLeakageArea.
•	Future refinement item is,
•	"Space" input option (with drop down menu) instead of "SpaceType" option. LCC cost codes are not used.
Code Outline
•	Define arguments (zone where fault occurs, percentage of increased infiltration).
•	Check whether fault intensity (increase of infiltration) is reasonably defined within 0-100.
•	Modify infiltration objects based on “space” object.
•	Read and replace infiltration method defined in ZoneInfiltration:DesignFlowRate.
•	Append EMS code that calculates the adjustment factor (AF)
•	Replace infiltration values based on user defined fault intensity (F)
•	designFlowRate schedule = (schedule value) * (1 + F/100*AF)
•	flowperSpaceFloorArea schedule = (schedule value) * (1 + F/100*AF)
•	flowperExteriorSurfaceArea schedule = (schedule value) * (1 + F/100*AF)
•	flowperExteriorWallArea schedule = (schedule value) * (1 + F/100*AF)
•	airChangesperHour schedule = (schedule value) * (1 + F/100*AF)
•	Read and replace infiltration method defined in ZoneInfiltration:EffectiveLeakageArea.
•	Append EMS code that calculates the adjustment factor (AF)
•	Replace infiltration values based on user defined fault intensity
•	effectiveAirLeakageArea schedule= (schedule value) * (1 + F/100*AF)

## Tests

●	Test invalid user argument values to make sure measure fails gracefully
●	Test different infiltration methods.
