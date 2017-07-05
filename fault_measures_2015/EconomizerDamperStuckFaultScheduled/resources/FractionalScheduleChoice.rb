#This ruby script accepts the OpenStudio::Model::Model object as an input 
#and output the choice of fractional schedules for OpenStudio users
#to choose

def fractional_schedule_choice(model, display_text="Choice of fault presence schedule:")
  schedulerulesets = model.getScheduleRulesets
  chs = OpenStudio::StringVector.new
  first_loop = false
  default_string = ""
  schedulerulesets.each do |scheduleruleset|
    limit = scheduleruleset.scheduleTypeLimits.get  #get the scheduleTypeLimits of the schedules
    if limit.lowerLimitValue.to_f >= 0 && limit.upperLimitValue.to_f <= 1
      chs << scheduleruleset.name.to_s
      if not first_loop
        default_string = scheduleruleset.name.to_s
        first_loop = true
      end
    end
  end
  sch_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("sch_choice", chs, true)
  sch_choice.setDisplayName(display_text)
  if first_loop
    sch_choice.setDefaultValue(default_string)
  end
  return sch_choice
end