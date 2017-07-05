# This Ruby script checks if a schedule exists in the EnergyPlus workspace
# and returns true if the schedule exists. It also returns the name of the
# ScheduleTypeLimits object associated with the schedule and the type of
# schedule ("Schedule:Year", "Schedule:Compact", "Schedule:Constant" and
# "Schedule:File") to the user. Otherwise, it returns false and two empty
# strings as its outputs

# This script is used by EnergyPlus Measure script and requries the name of
# the user-defined schedule and workspace as inputs

def schedule_search(workspace, sch_name)
  # define the type of shedules that may exist in EnergyPlus idf files
  scheduletypes = %w(Schedule:Year Schedule:Compact Schedule:Constant Schedule:File)

  bool_schedule_false = true
  schedule_type_limit = ''
  schedule_code = ''
  scheduletypes.each do |scheduletype|
    schedules = workspace.getObjectsByType(scheduletype.to_IddObjectType)
    if bool_schedule_false
      schedules.each do |schedule|
        if schedule.getString(0).to_s.eql?(sch_name)
          bool_schedule_false = false
          schedule_type_limit = schedule.getString(1).to_s
          schedule_code = scheduletype
          break
        end
      end
    end
  end

  return !(bool_schedule_false), schedule_type_limit, schedule_code
end
