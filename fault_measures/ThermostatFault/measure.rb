#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# http://openstudio.nrel.gov/sites/openstudio.nrel.gov/files/nv_data/cpp_documentation_it/model/html/namespaces.html

require 'date'
require "#{File.dirname(__FILE__)}/resources/util"

#start the measure
class ThermostatFault < OpenStudio::Ruleset::ModelUserScript
  
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return "ThermostatFault"
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make a bool argument for not running the measure
    run_me = OpenStudio::Ruleset::OSArgument::makeBoolArgument("run_me", true)
    run_me.setDisplayName("Run Measure ThermostatFault")
    run_me.setDefaultValue(false)
    args << run_me

    #make bool arguments for thermal zones
    thermalzones = model.getThermalZones
    thermalzones.each do |thermalzone|
      selected_thermalzone = OpenStudio::Ruleset::OSArgument::makeBoolArgument(thermalzone.name.to_s, false)
	   selected_thermalzone.setDisplayName(thermalzone.name.to_s.gsub("Thermal Zone: ",""))
	   selected_thermalzone.setDefaultValue(false)
	   args << selected_thermalzone
    end

    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    if runner.getBoolArgumentValue("run_me",user_arguments)

      # faulted/non-faulted state at each timestep
      timestepfaultstate = TimestepFaultState.new(model)
      timestepfaultstate.make("./faulted_timesteps.csv",
                              [[11],[1,2,3,4,5,6,7,8,9,10,11,12],[1,2,3,4,5,6,7,8,9,10,11,12]],
                              [[6,7,8,9,10,11,12,13,14,15,16,17,18,19,20],[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,7,18,19,20,21,22,23,24,25,26,27,28,29,30,31],[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,7,18,19,20,21,22,23,24,25,26,27,28,29,30,31]],
                              [["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"],["Saturday"],["Sunday"]],
                              [[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24],[18,19,20,21,22],[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24]])

	    #get list of all thermal zone names in the model
	    thermalzones = model.getThermalZones
	    thermalzones_display_names = []
	    thermalzones.each do |thermalzone|
		    thermalzones_display_names << thermalzone.name.to_s
	    end
	
	    #hash storing whether the user selected the thermal zone or not
	    selected_thermalzones = {}
	    thermalzones_display_names.each do |thermalzones_display_name|
		    selected_thermalzones[thermalzones_display_name] = runner.getBoolArgumentValue(thermalzones_display_name,user_arguments)
	    end
	
	    #get default, summer, and winter profiles from heating and cooling rulesets
	    heating = []
	    cooling = []
	    thermalzones.each do |thermalzone|
		    if selected_thermalzones[thermalzone.name.to_s]
			    thermostatsetpointdualsetpoint = thermalzone.thermostatSetpointDualSetpoint
			    if thermostatsetpointdualsetpoint.empty?
				    runner.registerWarning("Cannot find existing thermostat for thermal zone '#{thermalzone.name}', skipping.")
				    next
			    end
			    if heating.empty?
				    heatingtemperatureschedule = thermostatsetpointdualsetpoint.get.heatingSetpointTemperatureSchedule.get.to_Schedule.get
				    heatingrulesetschedule = heatingtemperatureschedule.to_ScheduleRuleset.get
				    heating << heatingrulesetschedule.defaultDaySchedule
				    heating << heatingrulesetschedule.summerDesignDaySchedule
				    heating << heatingrulesetschedule.winterDesignDaySchedule
			    end
			    if cooling.empty?
				    coolingtemperatureschedule = thermostatsetpointdualsetpoint.get.coolingSetpointTemperatureSchedule.get.to_Schedule.get
				    coolingrulesetschedule = coolingtemperatureschedule.to_ScheduleRuleset.get
				    cooling << coolingrulesetschedule.defaultDaySchedule
				    cooling << coolingrulesetschedule.summerDesignDaySchedule
				    cooling << coolingrulesetschedule.winterDesignDaySchedule
			    end
		    end
	    end
	
	    #new heating ruleset
	    heatingrulesetfault = OpenStudio::Model::ScheduleRuleset.new(model)
	    heatingrulesetfault.setName("Large Office HtgSetpFault")
	
	    #set default day schedule
	    heatingdefaultdayschedule = heatingrulesetfault.defaultDaySchedule
	    heatingdefaultdayschedule.setName("Heating Temperature Default Day Schedule")
	    heatingdefaultdayschedule.clearValues
	    times = heating[0].times
	    values = heating[0].values
	    for i in 0..(times.size - 1)
		    heatingdefaultdayschedule.addValue(times[i],values[i])
	    end
	
	    #set summer design day schedule
	    dayschedule = OpenStudio::Model::ScheduleDay.new(model)
	    dayschedule.setName("Heating Temperature Summer Design Day Schedule")
	    times = heating[1].times
	    values = heating[1].values
	    for i in 0..(times.size - 1)
		    dayschedule.addValue(times[i],values[i])
	    end
	    heatingrulesetfault.setSummerDesignDaySchedule(dayschedule)
	
	    #set winter design day schedule
	    dayschedule = OpenStudio::Model::ScheduleDay.new(model)
	    dayschedule.setName("Heating Temperature Winter Design Day Schedule")
	    times = heating[2].times
	    values = heating[2].values
	    for i in 0..(times.size - 1)
		    dayschedule.addValue(times[i],values[i])
	    end
	    heatingrulesetfault.setWinterDesignDaySchedule(dayschedule)
	
	    #new heating rule, priority 2
	    heatingruleprioritytwo = OpenStudio::Model::ScheduleRule.new(heatingrulesetfault)
	    heatingruleprioritytwo.setName("Priority 2 Heating Rule")
	    heatingruleprioritytwo.setApplySunday(true)
	    heatingruleprioritytwodayschedule = heatingruleprioritytwo.daySchedule
	    heatingruleprioritytwodayschedule.setName("Priority 2 Heating Rule Day Schedule")
	    heatingruleprioritytwodayschedule.clearValues
	    heatingruleprioritytwodayschedule.addValue(OpenStudio::Time.new(0,24,0,0), 14.9194641113281)
	
	    #new heating rule, priority 1
	    heatingrulepriorityone = OpenStudio::Model::ScheduleRule.new(heatingrulesetfault)
	    heatingrulepriorityone.setName("Priority 1 Heating Rule")
	    heatingrulepriorityone.setApplySunday(true)
	    heatingrulepriorityone.setApplyMonday(true)
	    heatingrulepriorityone.setApplyTuesday(true)
	    heatingrulepriorityone.setApplyWednesday(true)
	    heatingrulepriorityone.setApplyThursday(true)
	    heatingrulepriorityone.setApplyFriday(true)
	    heatingrulepriorityone.setApplySaturday(true)
	    heatingrulepriorityone.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new("November"),6))
	    heatingrulepriorityone.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new("November"),20))
	    heatingrulepriorityonedayschedule = heatingrulepriorityone.daySchedule
	    heatingrulepriorityonedayschedule.setName("Priority 1 Heating Rule Day Schedule")
	    heatingrulepriorityonedayschedule.clearValues
	    heatingrulepriorityonedayschedule.addValue(OpenStudio::Time.new(0,24,0,0), 8.19301509857178)
	
	    #new cooling ruleset
	    coolingrulesetfault = OpenStudio::Model::ScheduleRuleset.new(model)
	    coolingrulesetfault.setName("Large Office ClgSetpFault")

	    #set default day schedule
	    coolingdefaultdayschedule = coolingrulesetfault.defaultDaySchedule
	    coolingdefaultdayschedule.setName("Cooling Temperature Default Day Schedule")
	    coolingdefaultdayschedule.clearValues
	    times = cooling[0].times
	    values = cooling[0].values
	    for i in 0..(times.size - 1)
		    coolingdefaultdayschedule.addValue(times[i],values[i])
	    end
	
	    #set summer design day schedule
	    dayschedule = OpenStudio::Model::ScheduleDay.new(model)
	    dayschedule.setName("Cooling Temperature Summer Design Day Schedule")
	    times = cooling[1].times
	    values = cooling[1].values
	    for i in 0..(times.size - 1)
		    dayschedule.addValue(times[i],values[i])
	    end
	    coolingrulesetfault.setSummerDesignDaySchedule(dayschedule)
	
	    #set winter design day schedule
	    dayschedule = OpenStudio::Model::ScheduleDay.new(model)
	    dayschedule.setName("Cooling Temperature Winter Design Day Schedule")
	    times = heating[2].times
	    values = heating[2].values
	    for i in 0..(times.size - 1)
		    dayschedule.addValue(times[i],values[i])
	    end
	    coolingrulesetfault.setWinterDesignDaySchedule(dayschedule)
	
	    #new cooling rule, priority 1
	    coolinggruleprioritytwo = OpenStudio::Model::ScheduleRule.new(coolingrulesetfault)
	    coolinggruleprioritytwo.setName("Priority 2 Cooling Rule")
	    coolinggruleprioritytwo.setApplySunday(true)
	    coolinggruleprioritytwo.setApplyMonday(false)
	    coolinggruleprioritytwo.setApplyTuesday(false)
	    coolinggruleprioritytwo.setApplyWednesday(false)
	    coolinggruleprioritytwo.setApplyThursday(false)
	    coolinggruleprioritytwo.setApplyFriday(false)
	    coolinggruleprioritytwo.setApplySaturday(false)
	    coolinggruleprioritytwo.setStartDate(OpenStudio::Date.new("2014"))
	    coolinggruleprioritytwodayschedule = coolinggruleprioritytwo.daySchedule
	    coolinggruleprioritytwodayschedule.setName("Priority 2 Cooling Rule Day Schedule")
	    coolinggruleprioritytwodayschedule.clearValues
	    coolinggruleprioritytwodayschedule.addValue(OpenStudio::Time.new(0,24,0,0), 26.7)

	    #new cooling rule, priority 2
	    coolingrulepriorityone = OpenStudio::Model::ScheduleRule.new(coolingrulesetfault)
	    coolingrulepriorityone.setName("Priority 1 Cooling Rule")
	    coolingrulepriorityone.setApplySunday(true)
	    coolingrulepriorityone.setApplyMonday(true)
	    coolingrulepriorityone.setApplyTuesday(true)
	    coolingrulepriorityone.setApplyWednesday(true)
	    coolingrulepriorityone.setApplyThursday(true)
	    coolingrulepriorityone.setApplyFriday(true)
	    coolingrulepriorityone.setApplySaturday(true)
	    coolingrulepriorityone.setStartDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new("November"),6))
	    coolingrulepriorityone.setEndDate(OpenStudio::Date.new(OpenStudio::MonthOfYear.new("November"),20))
	    coolingrulepriorityonedayschedule = coolingrulepriorityone.daySchedule
	    coolingrulepriorityonedayschedule.setName("Priority 1 Cooling Rule Day Schedule")
	    coolingrulepriorityonedayschedule.clearValues
	    coolingrulepriorityonedayschedule.addValue(OpenStudio::Time.new(0,24,0,0), 40.2799987792969)
	
	    #create a new thermostat for each applicable thermal zone and connect it the new rulesets
	    thermalzones.each do |thermalzone|
		    if selected_thermalzones[thermalzone.name.to_s]
		
			    #get dual setpoint thermostat
			    thermostatsetpointdualsetpoint = thermalzone.thermostatSetpointDualSetpoint
			    if thermostatsetpointdualsetpoint.empty?
				    runner.registerWarning("Cannot find existing thermostat for thermal zone '#{thermalzone.name}', skipping.")
				    next
			    end
			
			    #get heating temperature schedule
			    heatingtemperatureschedule = thermostatsetpointdualsetpoint.get.heatingSetpointTemperatureSchedule.get.to_Schedule.get
			    heatingrulesetschedule = heatingtemperatureschedule.to_ScheduleRuleset.get
			
			    #get cooling temperature schedule
			    coolingtemperatureschedule = thermostatsetpointdualsetpoint.get.coolingSetpointTemperatureSchedule.get.to_Schedule.get
			    coolingrulesetschedule = coolingtemperatureschedule.to_ScheduleRuleset.get

			    #heating rules
			    rules = heatingrulesetschedule.scheduleRules
			    listofrules = []
			    i = 0
			    rules.each do |rule|
				    listofrules << rule.name.to_s
				    i += 1
			    end
			    runner.registerInfo("The dual thermostat for '#{thermalzone.name}' had #{i} heating rule(s) applied to it:")
			    listofrules.each do |rule|
				    runner.registerInfo(rule)
			    end
			
			    #cooling rules
			    rules = coolingrulesetschedule.scheduleRules
			    listofrules = []
			    i = 0
			    rules.each do |rule|
				    listofrules << rule.name.to_s
				    i += 1
			    end
			    runner.registerInfo("The dual thermostat for '#{thermalzone.name}' had #{i} cooling rule(s) applied to it:")
			    listofrules.each do |rule|
				    runner.registerInfo(rule)
			    end
			
			    #create the new thermostat
			    thermostatsetpointdualsetpoint = OpenStudio::Model::ThermostatSetpointDualSetpoint.new(model)
			
			    #assign the heating temperature schedule with faults to the new thermostat
			    thermostatsetpointdualsetpoint.setHeatingSetpointTemperatureSchedule(heatingrulesetfault)
			
			    #assign the cooling temperature schedule with faults to the new thermostat
			    thermostatsetpointdualsetpoint.setCoolingSetpointTemperatureSchedule(coolingrulesetfault)
			
			    #assign the new dual setpoint thermostat to the thermal zone
			    thermalzone.setThermostatSetpointDualSetpoint(thermostatsetpointdualsetpoint)
			
		    end
	    end
	
	    #summarize the new sets of schedules
	    thermalzones.each do |thermalzone|
		    if selected_thermalzones[thermalzone.name.to_s]
			    thermostatsetpointdualsetpoint = thermalzone.thermostatSetpointDualSetpoint
			    if thermostatsetpointdualsetpoint.empty?
				    runner.registerWarning("Cannot find existing thermostat for thermal zone '#{thermalzone.name}', skipping.")
				    next
			    end
			
			    #get heating temperature schedule
			    heatingtemperatureschedule = thermostatsetpointdualsetpoint.get.heatingSetpointTemperatureSchedule.get.to_Schedule.get
			    heatingrulesetschedule = heatingtemperatureschedule.to_ScheduleRuleset.get
			
			    #get cooling temperature schedule
			    coolingtemperatureschedule = thermostatsetpointdualsetpoint.get.coolingSetpointTemperatureSchedule.get.to_Schedule.get
			    coolingrulesetschedule = coolingtemperatureschedule.to_ScheduleRuleset.get

			    #heating rules
			    rules = heatingrulesetschedule.scheduleRules
			    listofrules = []
			    i = 0
			    rules.each do |rule|
				    listofrules << rule.name.to_s
				    i += 1
			    end
			    runner.registerInfo("The dual thermostat for '#{thermalzone.name}' now has #{i} heating rule(s) applied to it:")
			    listofrules.each do |rule|
				    runner.registerInfo(rule)
			    end
			
			    #cooling rules
			    rules = coolingrulesetschedule.scheduleRules
			    listofrules = []
			    i = 0
			    rules.each do |rule|
				    listofrules << rule.name.to_s
				    i += 1
			    end
			    runner.registerInfo("The dual thermostat for '#{thermalzone.name}' now has #{i} cooling rule(s) applied to it:")
			    listofrules.each do |rule|
				    runner.registerInfo(rule)
			    end

		    end
		
	    end

    end

    return true
 
  end #end the run method

end #end the measure

#this allows the measure to be use by the application
ThermostatFault.new.registerWithApplication