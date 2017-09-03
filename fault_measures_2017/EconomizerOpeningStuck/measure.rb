#see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

#see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

#see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

require 'date'
require "#{File.dirname(__FILE__)}/resources/ScheduleRuleTransfer"
require "#{File.dirname(__FILE__)}/resources/FractionalScheduleChoice"

$allchoices = '* ALL Controller:OutdoorAir *'

#start the measure
class EconomizerDamperStuckFaultScheduled < OpenStudio::Ruleset::ModelUserScript
  #define the name that a user will see, this method may be deprecated as
  #the display name in PAT comes from the name field in measure.xml
  def name
    return 'All faulted damper in an economizer'
  end
  
  def description
    return 'Stuck dampers associated with economizers can be caused by seized ' \
	'actuators, broken linkages, economizer control system failures, or the ' \
        'failure of sensors that are used to determine damper position ' \
	'(Roth et al. 2004, 2005). In extreme cases, dampers stuck at either 100% ' \
	'open or closed can have a serious impact on system energy consumption ' \
	'or occupant comfort in the space. This measure simulates a stuck damper ' \
	'by modifying the Controller:OutdoorAir object in EnergyPlus. ' \
	'The fault intensity (F) for this fault is defined as the ratio of ' \
	'economizer damper at the stuck position (0-1 / 0 = fully closed, ' \
	'1 = fully open)'
  end
  
  def modeler_description
    return 'To use this fault measure, user should choose the economizer getting ' \
	'faulted, the elapsed time that the damper is being stuck and the ' \
	'damper stuck position. If a schedule of fault prevalence is not given, ' \
	'the model will apply the fault to the entire simulation. The fixed ' \
	'damper position is described by a ratio of the outdoor airflow rate to ' \
	'the supply air duct.'
  end
  
  #define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    #make choice arguments for economizers
    controlleroutdoorairs = model.getControllerOutdoorAirs
    chs = OpenStudio::StringVector.new
    controlleroutdoorairs.each do |controlleroutdoorair|
      chs << controlleroutdoorair.name.to_s
    end
    chs << $allchoices
    econ_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('econ_choice', chs, true)
    econ_choice.setDisplayName("Choice of economizers. If you want to impose the fault on all economizers, choose #{$allchoices}")
    econ_choice.setDefaultValue($allchoices)
    args << econ_choice
	
    #give a choice to choose schedules. If checked, the model will look up the chosen schedule for 
    #a schedule of fault presence and set the damper position during non-zero period as damper_pos. 
    #Otherwise, the damper position entered at damper_pos will be applied to the economizer for 
    #the entire simulation period
    schedule_exist = OpenStudio::Ruleset::OSArgument::makeBoolArgument('schedule_exist', false)
    schedule_exist.setDisplayName('Check if a schedule of fault presence is needed, or uncheck to apply the fault for the entire simulation.')
    schedule_exist.setDefaultValue(false)
    args << schedule_exist
    
    #choice of schedules for the presence of fault. 0 for no fault and other numbers means fault    
    args << fractional_schedule_choice(model)
	
    #make a double argument for the damper position
    #it should range between 0 and 1. 0 means completely closed damper
    #and 1 means fully opened damper
    damper_pos = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('damper_pos', false)
    damper_pos.setDisplayName('The position of damper indicated between 0 and 1. If it is -1 and a schedule of fault prevalence is not given, the fault model will not be imposed to the building simulation without warning.')
    damper_pos.setDefaultValue(0.5)  #default position to be fully closed
    args << damper_pos
	
    return args
  end #end the arguments method

  #define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)
    
    #use the built-in error checking 
    if not runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
	
    #obtain values
    econ_choice = runner.getStringArgumentValue('econ_choice',user_arguments)
    schedule_exist = runner.getBoolArgumentValue('schedule_exist',user_arguments)
    sch_choice = runner.getStringArgumentValue('sch_choice',user_arguments)
    damper_pos = runner.getDoubleArgumentValue('damper_pos',user_arguments)
    
    #check if the damper position is between 0 and 1
    if damper_pos == -1.0
      runner.registerInfo("Damper position at #{damper_pos}. Skipping the model......")
    elsif damper_pos < 0.0 || damper_pos > 1.0
      runner.registerError("Damper position must be between 0 and 1 and it is now #{damper_pos}!")
      return false
    end
    
    if schedule_exist || (damper_pos >= 0 && damper_pos <= 1) # only continue if the user is running the module
    
      runner.registerInitialCondition("Fixing #{econ_choice} damper position to #{damper_pos}")
      
      # need a set of code to check schedule names in the future
      
      #find the economizer to change
      controlleroutdoorairs = model.getControllerOutdoorAirs
      controlleroutdoorairs.each do |controlleroutdoorair|
        if controlleroutdoorair.name.to_s.eql?(econ_choice) || econ_choice.eql?($allchoices)
        
          #check control algorithm. If the algorithm is NoEconomizer, exit without change
          controltype = controlleroutdoorair.getEconomizerControlType
          if controltype.eql?('NoEconomizer')
            runner.registerAsNotApplicable("#{econ_choice} does not have an economizer. Skipping......")
            break
          end
        
          #create a faulted schedule. If schedule_exist is 0, create a schedule that the fault exists
          #all the time. Otherwise, create a schedule that the fault happens following the non-zero values
          #in the user-defined schedule
          if schedule_exist
              
            #create new fault schedule
            faultschedule = OpenStudio::Model::ScheduleRuleset.new(model)
            faultschedule.setName("Damper Stuck Fault Schedule for #{econ_choice}")
            
            #all schedule objects under the fault schedule should have a continuous schedule type limit
            faultscheduletypelimits = OpenStudio::Model::ScheduleTypeLimits.new(model)
            faultscheduletypelimits.setLowerLimitValue(0)
            faultscheduletypelimits.setUpperLimitValue(1)
            faultscheduletypelimits.setNumericType('CONTINUOUS')
            faultscheduletypelimits.setName("Damper Stuck Fault Schedule Type Limit for #{econ_choice}")
            faultschedule.setScheduleTypeLimits(faultscheduletypelimits)
            
            #another schedule for upper limit of the damper position
            upperfaultschedule = OpenStudio::Model::ScheduleRuleset.new(model)
            upperfaultschedule.setName("Damper Stuck Fault Schedule for Maximum Flow Fraction of #{econ_choice}")
            upperfaultschedule.setScheduleTypeLimits(faultscheduletypelimits)
                
            #create a schedule that the economizer is fixed at the damper_pos when the schedule has any values
            #other than 0.
            schedulerulesets = model.getScheduleRulesets
            schedulerulesets.each do |scheduleruleset|
              if scheduleruleset.name.to_s.eql?(sch_choice)
                
                #create regular day schedule
                faultscheduledayschedule = faultschedule.defaultDaySchedule
                faultscheduledayschedule.clearValues
                faultscheduledayschedule.setName("Default Damper Stuck Fault Default Day Schedule for #{econ_choice}")
                upperfaultscheduledayschedule = upperfaultschedule.defaultDaySchedule
                upperfaultscheduledayschedule.clearValues
                upperfaultscheduledayschedule.setName("Default Damper Stuck Fault Default Day Schedule for Maximum Flow Fraction of #{econ_choice}")
                dayschedule = scheduleruleset.defaultDaySchedule
                times = dayschedule.times
                values = dayschedule.values
                for i in 0..(times.size - 1)
                  if values[i]==(0)
                    faultscheduledayschedule.addValue(times[i], 0)
                    upperfaultscheduledayschedule.addValue(times[i], 1)
                  else
                    faultscheduledayschedule.addValue(times[i],damper_pos)
                    upperfaultscheduledayschedule.addValue(times[i],damper_pos)
                  end
                end
                
                #create overriding ScheduleRules based on the schedule in the system
                schedulerulesetschedulerules = scheduleruleset.scheduleRules
                if schedulerulesetschedulerules.size > 0
                  ii = 1
                  schedulerulesetschedulerules.each do |schedulerulesetschedulerule|
                    #initialization
                    faultscheduleschedulerule = OpenStudio::Model::ScheduleRule.new(faultschedule)
                    faultscheduleschedulerule.setName("Damper Stuck Fault Schedule for "+econ_choice+" priority #{ii} Rule")
                    faultdayschedule = faultscheduleschedulerule.daySchedule
                    upperfaultscheduleschedulerule = OpenStudio::Model::ScheduleRule.new(upperfaultschedule)
                    upperfaultscheduleschedulerule.setName("Damper Stuck Fault Schedule for Maximum Flow Fraction of "+econ_choice+" priority #{ii} Rule")
                    upperfaultdayschedule = upperfaultscheduleschedulerule.daySchedule
                    dayschedule = schedulerulesetschedulerule.daySchedule
                    
                    #set schedule values
                    times = dayschedule.times
                    values = dayschedule.values
                    for i in 0..(times.size - 1)
                      if values[i]==(0)
                        faultdayschedule.addValue(times[i],0)
                        upperfaultdayschedule.addValue(times[i],1)
                      else
                        faultdayschedule.addValue(times[i],damper_pos)
                        upperfaultdayschedule.addValue(times[i],damper_pos)
                      end
                    end
                    
                    #set schedule rules
                    faultscheduleschedulerule = schedule_rule_transfer(schedulerulesetschedulerule, faultscheduleschedulerule)
                    upperfaultscheduleschedulerule = schedule_rule_transfer(schedulerulesetschedulerule, upperfaultscheduleschedulerule)
                    
                    #copy ruleindex
                    ruleindex = schedulerulesetschedulerule.ruleIndex
                    faultschedule.setScheduleRuleIndex(faultscheduleschedulerule, ruleindex)
                    upperfaultschedule.setScheduleRuleIndex(upperfaultscheduleschedulerule, ruleindex)
                  end
                end
                
                #create summer design day schedule, if needed
                if not scheduleruleset.isSummerDesignDayScheduleDefaulted
                  faultschedulesummerschedule = OpenStudio::Model::ScheduleDay.new(model)
                  faultschedulesummerschedule.clearValues
                  faultschedulesummerschedule.setName("Damper Stuck Fault Summer Design Day Schedule for #{econ_choice}")
                  upperfaultschedulesummerschedule = OpenStudio::Model::ScheduleDay.new(model)
                  upperfaultschedulesummerschedule.clearValues
                  upperfaultschedulesummerschedule.setName("Damper Stuck Fault Summer Design Day Schedule for Maximum Flow Fraction of #{econ_choice}")
                  summerschedule = scheduleruleset.summerDesignDaySchedule
                  times = summerschedule.times
                  values = summerschedule.values
                  for i in 0..(times.size-1)
                    if values[i]==(0)
                      faultschedulesummerschedule.addValue(times[i],0)
                      upperfaultschedulesummerschedule.addValue(times[i],1)
                    else
                      faultschedulesummerschedule.addValue(times[i],damper_pos)
                      upperfaultschedulesummerschedule.addValue(times[i],damper_pos)
                    end
                  end
                  faultschedule.setSummerDesignDaySchedule(faultschedulesummerschedule)
                  upperfaultschedule.setSummerDesignDaySchedule(upperfaultschedulesummerschedule)
                end
                
                #create winter design day schedule, if needed
                if not scheduleruleset.isWinterDesignDayScheduleDefaulted
                  faultschedulewinterschedule = OpenStudio::Model::ScheduleDay.new(model)
                  faultschedulewinterschedule.clearValues
                  faultschedulewinterschedule.setName("Damper Stuck Fault Winter Design Day Schedule for #{econ_choice}")
                  upperfaultschedulewinterschedule = OpenStudio::Model::ScheduleDay.new(model)
                  upperfaultschedulewinterschedule.clearValues
                  upperfaultschedulewinterschedule.setName("Damper Stuck Fault Winter Design Day Schedule for Maximum Flow Fraction of #{econ_choice}")
                  winterschedule = scheduleruleset.winterDesignDaySchedule
                  times = winterschedule.times
                  values = winterschedule.values
                  for i in 0..(times.size-1)
                    if values[i]==(0)
                      faultschedulewinterschedule.addValue(times[i],0)
                      upperfaultschedulewinterschedule.addValue(times[i],1)
                    else
                      faultschedulewinterschedule.addValue(times[i],damper_pos)
                      upperfaultschedulewinterschedule.addValue(times[i],damper_pos)
                    end
                  end
                  faultschedule.setWinterDesignDaySchedule(faultschedulewinterschedule)
                  upperfaultschedule.setWinterDesignDaySchedule(upperfaultschedulewinterschedule)
                end
                
                #set the faulted damper schedule
                controlleroutdoorair.setMinimumFractionofOutdoorAirSchedule(faultschedule)
                controlleroutdoorair.setMaximumFractionofOutdoorAirSchedule(upperfaultschedule)
                
                break
              end
            end
          else
            #create a schedule that the economizer is fixed at the damper_pos for the entire simulation
            #period
            faultschedule = OpenStudio::Model::ScheduleRuleset.new(model)
            faultschedule.setName("Damper Stuck Fault Schedule for #{econ_choice}")
            faultscheduledefault = faultschedule.defaultDaySchedule
            faultscheduledefault.clearValues
            faultscheduledefault.addValue(OpenStudio::Time.new(0,24,0,0), damper_pos)
            faultscheduledefault.setName("Default Damper Stuck Fault Default Schedule for #{econ_choice}")
            
            #set the faulted damper schedule
            controlleroutdoorair.setMinimumFractionofOutdoorAirSchedule(faultschedule)
            controlleroutdoorair.setMaximumFractionofOutdoorAirSchedule(faultschedule)
          end
        
        end

        #ending
        runner.registerFinalCondition("Damper position at #{econ_choice} is fixed at #{damper_pos}")
      end
    else
      runner.registerAsNotApplicable("#{name} is not running for #{econ_choice}. Skipping......")
    end
    
    return true
  end #end the run method
end #end the measure

#this allows the measure to be use by the application
EconomizerDamperStuckFaultScheduled.new.registerWithApplication
