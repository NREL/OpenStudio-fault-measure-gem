# Air Handling Unit Fan Motor Degradation

##Description

def description
    return "Fan motor degradation occurs due to bearing and stator winding faults, leading to a decrease in motor efficiency and an increase in overall fan power consumption. This fault is categorized as a fault that occur in the ventilation system (fan) during the operation stage. This fault measure is based on a semi-empirical model and simulates the air handling unit fan motor degradation by modifying either the Fan:ConstantVolume, Fan:VariableVolume, or the Fan:OnOff objects in EnergyPlus assigned to the ventilation system. The fault intensity (F) for this fault is defined as the ratio of fan motor efficiency degradation with the application range of 0 to 0.3 (30% degradation)."
end

##Modeler Description

def modeler_description
    return "Nine user inputs are required and, based on these user inputs, the fan efficiency is recalculated to reflect the faulted operation. η_(fan,tot,F) = η_(fan,tot)∙(1-F), where η_(fan,tot,F) is the degraded total efficiency under faulted condition, η_(fan,tot) is the total efficiency under normal condition, and F is the fault intensity. The time required for the fault to reach the full level is only required when the user wants to model fault evolution. If the fault evolution is not necessary for the user, it can be defined as zero and the F will be imposed as a step function with the user defined value. However, by defining the time required for the fault to reach the full level, fault starting month/date/time and fault ending month/date/time, the adjustment factor AF is calculated at each time step starting from the starting month/date/time to gradually impose F based on the user specified time frame. AF is calculated as follows, AF_current = AF_previous + dt/tau where AF_current is the adjustment factor calculated based on the previously calculated adjustment factor (AF_previous), simulation timestep (dt) and the time required for the fault to reach the full level (tau)."
  end
  
##Measure Type

EnergyPlus Measure

##Taxonomy

HVAC.Ventilation

##Arguments 

def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    list = OpenStudio::StringVector.new
    list << $allchoices
	  
    cvs = workspace.getObjectsByType("Fan:ConstantVolume".to_IddObjectType)
    cvs.each do |cv|
      list << cv.name.to_s
    end
	
    ofs = workspace.getObjectsByType("Fan:OnOff".to_IddObjectType)
      ofs.each do |of|
      list << of.name.to_s
    end
	
	  vvs = workspace.getObjectsByType("Fan:VariableVolume".to_IddObjectType)
      vvs.each do |vv|
      list << vv.name.to_s
    end
	
    fan_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("fan_choice", list, true)
    fan_choice.setDisplayName("Enter the name of the faulted Fan:ConstantVolume, Fan:OnOff object or Fan:VariableVolume. If you want to impose the fault on all fan objects in the building, enter #{$allchoices}")
    fan_choice.setDefaultValue($allchoices)
    args << fan_choice

    eff_degrad_fac = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('eff_degrad_fac', false)
    eff_degrad_fac.setDisplayName('Degradation factor of the total efficiency of the fan during the simulation period. If the fan is not faulted, set it to zero.')
    eff_degrad_fac.setDefaultValue(0.15)  # default fouling level to be 15%
    args << eff_degrad_fac
	
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
  
##Initial Condition

runner.registerInitialCondition("Imposing airflow restriction on #{fan_choice}.")
Final Condition

runner.registerFinalCondition("Imposed efficiency degradation level at #{eff_degrad_fac} on #{fan_choice}.")

##Not Applicable

n/a

##Warning

n/a

##Error

  runner.registerError("User-defined schedule #{sch_choice} does not exist. Exiting......")

  runner.registerError("User-defined schedule #{sch_choice} has a ScheduleTypeLimits outside     the range 0 to 1.0. Exiting......")

  runner.registerError("Fan Efficiency Degradation Level #{eff_degrad_fac} for #{fan_choice} is outside the range 0 to 1.0. Exiting......")
  
  runner.registerError("Measure FanMotorDegradation cannot find #{fan_choice}. Skipping......")

##Information

•	Works with,
•	Fan:ConstantVolume
•	Fan:OnOff
•	Fan:VariableVolume.
Code Outline
•	Define arguments (air handling unit where fault occurs, fault level in constant value or scheduled values).
•	Check scheduled fault level values (within 0-1) if exists.
•	Check constant fault level value (within 0-1).
•	Create fractional schedule object for fault level implementation (use fault level values either from the constant or scheduled input arguments).
•	Find the fan object(s) assigned to the air handling unit that was selected as argument.
•	Store original efficiency values from the fan object(s).
•	Write EMS program to impose degraded efficiency for each fan object.
•	Define sensor object (storing efficiency degradation values in fractional schedule).
•	Define program object (calculate fan efficiency after degradation).
•	Define ProgramCallingManager object (define EMS calling point).
•	Define Actuator object (apply degraded efficiency to fan object(s)).
•	Append EMS code that calculates the adjustment factor (AF)
•	Define EMS output object

##Tests
●	Test model with Fan:ConstantVolume
●	Test model with Fan:OnOff
●	Test model with Fan:VariableVolume
●	Test invalid user argument values to make sure measure fails gracefully
●	Test fault intensity with constant value
●	Test fault intensity with scheduled values



