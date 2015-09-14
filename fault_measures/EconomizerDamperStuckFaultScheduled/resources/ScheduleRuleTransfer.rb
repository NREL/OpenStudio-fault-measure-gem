#This ruby script transfer the rules in the OpenStudio::Model::ScheduleRule objects
#from the first one to the second one

def schedule_rule_transfer(firstschedule, secondschedule)
  if firstschedule.applySunday
    secondschedule.setApplySunday(true)
  end
  if firstschedule.applyMonday
    secondschedule.setApplyMonday(true)
  end
  if firstschedule.applyTuesday
    secondschedule.setApplyTuesday(true)
  end
  if firstschedule.applyWednesday
    secondschedule.setApplyWednesday(true)
  end
  if firstschedule.applyThursday
    secondschedule.setApplyThursday(true)
  end
  if firstschedule.applyFriday
    secondschedule.setApplyFriday(true)
  end
  if firstschedule.applySaturday
    secondschedule.setApplySaturday(true)
  end
  if firstschedule.dateSpecificationType.eql?"DateRange"
    secondschedule.setStartDate(firstschedule.startDate.get)
    secondschedule.setEndDate(firstschedule.endDate.get)
  end
  return secondschedule #return the second schedule
end