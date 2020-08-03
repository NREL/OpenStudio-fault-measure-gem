# Thermostat Measurement Bias

## Description

  def description
    return "Drift of the thermostat temperature sensor over time can lead to increased energy use and/or reduced occupant comfort. This fault is categorized as a fault that occur in the indoor thermostats (sensor) during the operation stage. This fault measure is based on a physical model where certain parameter(s) is changed in EnergyPlus to mimic the faulted operation; thus simulates a biased thermostat by modifying the Schedule:Compact object in EnergyPlus assigned to heating and cooling set points. The fault intensity (F) is defined as the thermostat measurement bias (K). A positive number means that the sensor is reading a temperature higher than the true temperature."
  end
  
## Modeler Description

  def modeler_description
    return "Seven user inputs are required and, based on these user inputs, the original (non-faulted) heating and cooling set point schedules in the building model will be replaced with a biased temperature set point by the equation below. If the reading of the thermostat is biased with +1C, the actual space temperature should be maintained 1C lower than the reading. Thus, the set point for the space is corrected by subtracting the original set point from the biased level. T_(stpt,heat,F)=T_(stpt,heat)-F / T_(stpt,cool,F)=T_(stpt,cool)-F. The time required for the fault to reach the full level is only required when the user wants to model fault evolution. If the fault evolution is not necessary for the user, it can be defined as zero and F will be imposed as a step function with the user defined value. However, by defining the time required for the fault to reach the full level, fault starting month/date/time and fault ending month/date/time, the adjustment factor AF is calculated at each time step starting from the starting month/date/time to gradually impose F based on the user specified time frame. AF is calculated as follows, AF_current = AF_previous + dt/tau where AF_current is the adjustment factor calculated based on the previously calculated adjustment factor (AF_previous), simulation timestep (dt) and the time required for the fault to reach the full level (tau)."
  end
  
## Measure Type

OpenStudio Measure 

## Taxonomy

HVAC.HVAC Controls

## Arguments 

def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    zone_handles, zone_display_names = pass_zone(model, $allzonechoices)
    zone = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
        'zone', zone_display_names, zone_display_names, true
    )
    zone.setDefaultValue("* All Zones *")
    zone.setDisplayName("Zone. Choose #{$allzonechoices} if you want to impose the fault in all zones")
    args << zone

    months = OpenStudio::StringVector.new
    months << "January"
    months << "February"
    months << "March"
    months << "April"
    months << "May"
    months << "June"
    months << "July"
    months << "August"
    months << "September"
    months << "October"
    months << "November"
    months << "December"

    bias_level = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("bias_level", false)
    bias_level.setDisplayName("Enter the constant setpoint bias level [K] [0=Non faulted case]")
    bias_level.setDefaultValue(0)
    args << bias_level

    time_constant = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('time_constant', false)
    time_constant.setDisplayName('Enter the time required for fault to reach full level [hr]')
    time_constant.setDefaultValue(0)  #default is zero
    args << time_constant
	
	start_month = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("start_month", months, true)
    start_month.setDisplayName("Fault active start month")
    start_month.setDefaultValue("January")
    args << start_month
	
    start_date = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_date', false)
    start_date.setDisplayName('Enter the date (1-28/30/31) when the fault starts to occur')
    start_date.setDefaultValue(1)  #default is 1st day of the month
    args << start_date
	
    end_month = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("end_month", months, true)
    end_month.setDisplayName("Fault active end month")
    end_month.setDefaultValue("December")
    args << end_month
	
    end_date = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('end_date', false)
    end_date.setDisplayName('Enter the date (1-28/30/31) when the fault ends')
    end_date.setDefaultValue(31)  #default is last day of the month
    args << end_date

    return args
  end
  
## Initial Condition

    runner.registerInitialCondition("Initial heating setpoints in affected zones range from #{setpoint_values[:init_htg_min].min.round(1)} C to #{setpoint_values[:init_htg_max].max.round(1)} C. Initial cooling setpoints in affected zones range from #{setpoint_values[:init_clg_min].min.round(1)} C to #{setpoint_values[:init_clg_max].max.round(1)} C.")

## Final Condition

    runner.registerFinalCondition("Final heating setpoints in affected zones range from #{setpoint_values[:final_htg_min].min.round(1)} C to #{setpoint_values[:final_htg_max].max.round(1)} C. Final cooling setpoints in affected zones range from #{setpoint_values[:final_clg_min].min.round(1)} C to #{setpoint_values[:final_clg_max].max.round(1)} C.") 

## Not Applicable

      runner.registerAsNotApplicable("No changes made, selected zones may not have had setpoint schedules, or schedules may not have been ScheduleRulesets.")
      runner.registerAsNotApplicable("No changes made thermostat bias of 0.0 requested.") 

## Warning

      runner.registerWarning("Cannot find existing thermostat for thermal zone '#{thermalzone.name}'. No changes made in this zone.")
      runner.registerWarning("Skipping #{thermalzone.name} because it is either missing heating setpoint schedule or the schedule is not ScheduleRulesets.")
      runner.registerWarning("Skipping #{thermalzone.name} because it is either missing cooling setpoint schedule or the schedule is not ScheduleRulesets.")

## Error

      runner.registerError("Invalid fault start/end month combination.")

## Information

•	Works with Schedule Ruleset.
Code Outline
•	Define arguments (zone where fault occurs, fault starting month, fault ending month, fault level in constant value).
•	Check fault active months when fault is being imposed based on fault starting month and ending month.
•	If time constant for fault evolution is defined as zero,
•	Apply fault for selected thermal zone(s).
•	Read heating and cooling thermostat schedule defined in the zone.
•	Gather thermostat setpoint information (average, min, max).
•	Alter heating thermostat setpoint based on biased level.
•	Copy original schedules.
•	Store setpoint values.
•	Empty schedules.
•	Insert biased setpoint values based on stored setpoint values.
•	Alter cooling thermostat setpoint based on biased level.
•	Copy original schedules.
•	Store setpoint values.
•	Empty schedules.
•	Insert biased setpoint values based on stored setpoint values.
•	Assign modified heating setpoints to thermostat.
•	Assign modified cooling setpoints to thermostat.
•	Assign thermostat to selected zone.
•	Gather modified thermostat setpoint information (average, min, max).
•	If time constant for fault evolution is defined other than zero,
•	Append EMS code that calculates the adjustment factor (AF) and overwrites original heating and cooling schedules to selected zone.

## Tests

●	Test different sets of input arguments (starting/ending month, biased level)
●	Test invalid user argument values to make sure measure fails gracefully.



