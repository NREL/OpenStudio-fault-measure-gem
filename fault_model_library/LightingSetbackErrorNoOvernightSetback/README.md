# Lighting Setback Error: No Overnight Setback

## Description

  def description
    return “Lighting should be turned off or at least reduced during unoccupied hours. However, some commissioning studies have found noticeable lighting energy use at night either because lighting schedules are improperly configured or occupants forget to turn off lights when vacating a building. This fault is categorized as a fault that occur in the lighting system (controller) during the operation stage. This fault measure is based on a physical model where certain parameter(s) is changed in EnergyPlus to mimic the faulted operation; thus simulates the effect of having no setback during unoccupied hours by modifying the Schedule:Compact object in EnergyPlus assigned to lighting schedules. The fault intensity (F) is defined as the absence of overnight lighting setback (binary).”
  end
  
## Modeler Description

  def modeler_description
    return “Four different user inputs are required; zone where the fault occurs, starting month of the faulted operation, ending month of the faulted operation, day of the week when the fault occurs. The measure detects the original (non-faulted) lighting schedule applied in EnergyPlus automatically, and adjusts the schedule based on user inputs.”
  end
  
## Measure Type

OpenStudio Measure 

## Taxonomy

Electric Lighting.Electric Lighting Controls

## Arguments 

  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    zone_handles, zone_display_names = pass_zone(model, $allzonechoices)
    zone = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
      'zone', zone_display_names, zone_display_names, true
    )
    zone.setDefaultValue(zone_display_names[0])
    zone.setDisplayName("Zone. Choose #{$allzonechoices} if you want to impose the fault in all zones")
    args << zone

    osmonths = OpenStudio::StringVector.new
    $months.each do |month|
      osmonths << month
    end

    start_month = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
      'start_month', osmonths, true
    )
    start_month.setDisplayName('Fault active start month')
    start_month.setDefaultValue($months[0])
    args << start_month

    end_month = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
      'end_month', osmonths, true
    )
    end_month.setDisplayName('Fault active end month')
    end_month.setDefaultValue($months[11])
    args << end_month

    osdaysofweeks = OpenStudio::StringVector.new
    $dayofweeks.each do |day|
      osdaysofweeks << day
    end
    osdaysofweeks << $not_faulted
    osdaysofweeks << $all_days
    osdaysofweeks << $weekdaysonly
    osdaysofweeks << $weekendonly
    dayofweek = OpenStudio::Ruleset::OSArgument.makeChoiceArgument(
      'dayofweek', osdaysofweeks, true
    )
    dayofweek.setDisplayName('Day of the week')
    dayofweek.setDefaultValue($all_days)
    args << dayofweek

    return args
  end
  
## Initial Condition

    runner.registerInitialCondition("Initial lighting profile in affected zones range from #{setpoint_values[:initial_ltg_min].min.round(1)} to #{setpoint_values[:initial_ltg_max].max.round(1)}")
	
## Final Condition

    runner.registerFinalCondition("Final lighting profile in affected zones range from #{setpoint_values[:final_ltg_min].min.round(1)} to #{setpoint_values[:final_ltg_max].max.round(1)}.")
	
## Not Applicable

runner.registerAsNotApplicable('Measure NoOvernightSetbackWeek not run')
runner.registerAsNotApplicable("No changes made, selected zones may not have had setpoint schedules, or they schedules may not have been ScheduleRulesets.")

## Warning

n/a

## Error

n/a

## Information

•	Following measures share the same (or similar) functions.
•	LightingSetbackErrorDelayedOnset
•	LightingSetbackErrorEarlyTermination
•	LightingSetbackErrorNoOvernightSetback
•	Works with Schedule Ruleset. 
•	Only works for unimodal profile.
•	Future refinement item is,
•	Capability to work with multimodal lighting profiles.
Code Outline
•	Define arguments (zone where fault occurs, fault starting month, fault ending month, day of week when fault occurs, fault level in constant value).
•	Check currently applied lighting schedules.
•	Gather lighting schedule fraction values from those schedules (minimum and maximum).
•	Create faulted schedule based on input arguments reflecting no overnight setback.
•	Create faulted schedule according to input arguments... addnewscheduleruleset
•	Create default schedule... createnewdefaultdayofweekrule
•	Create new schedule based on old schedule but with user defined fault starting month and ending month... createnewruleandcopy
•	Copy times and values from current schedule... copydayscheduletimesandvalues
•	Set fault starting date and ending date... Setcommoninformation
•	Change schedule type only applied to certain day of week... Changedayofweek
•	Apply schedule to all days in a week... applyallday
•	or Apply schedule to specific day in a week... applydayofweek
•	Propagate faulted schedule throughout the simulation period... propagateeveningchangeovervaluewithextrainfo
•	Find building opening time or closing time... findchangetime
•	Create schedule according to faulted time period... newtimesandvaluestosceduleday
•	Returns faulted time object according to faulted time period... shifttimevector 
•	Updates faulted hours and minutes according to extended time... newhrandmin
•	Corrects time format within 24 hours... midnightadjust
•	Corrects hours and minutes to correct format... roundclock
•	Create new priority schedule... createnewpriroityrules
•	Create new schedule based on old schedule but with user defined fault starting month and ending month... Createnewruleandcopy
•	Copy times and values from current schedule... copydayscheduletimesandvalues
•	Set fault starting date and ending date... Setcommoninformation
•	Compare and change the schedule according to faulted period... compareandchangedayofweek
•	Apply schedule to all days in a week... applyallday
•	Change schedule type only applied to certain day of week... changedayofweek
•	Apply schedule to all days in a week... applyallday
•	or Apply schedule to specific day in a week... Applydayofweek
•	Propagate faulted schedule throughout the simulation period... propagateeveningchangeovervalue
•	Find building opening time or closing time... findchangetime
•	Replace time and values in a schedule according to faulted period... newtimesandvaluestosceduleday
•	Assign modified (or faulted) lighting schedule(s) to assigned zone(s).

## Tests

●	Test different sets of input arguments (starting/ending month, extended hours, day of week)
●	Test invalid user argument values to make sure measure fails gracefully.



