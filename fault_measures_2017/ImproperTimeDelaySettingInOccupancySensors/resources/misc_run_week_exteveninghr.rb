# The file contains functions to pass arguments from OpenStudio inputs to the
# measure script. They are used to avoid the function run to be too long.

# 11/20/2017 Improper Time Delay Setting in Occupancy Sensors measure developed based on Lighting Setback Error (Delayed Onset) measure
# codes within ######## are modified parts

##########################################################
##########################################################
def applyfaulttopeople(people, light, ext_hr, start_month, end_month, dayofweek, runner, setpoint_values, model)
  
  scheds_occ = []
  people.each do |peopl|
	scheds_occ << peopl.numberofPeopleSchedule
  end
  peoplerulesetschedule = scheds_occ[0].get.to_Schedule.get.clone.to_ScheduleRuleset.get
  
  scheds_ltg = []
  light.each do |ligh|
	scheds_ltg << ligh.schedule
  end
  lightingrulesetschedule = scheds_ltg[0].get.to_Schedule.get.clone.to_ScheduleRuleset.get
  
  setpoint_values = gather_light_avg_high_low_values(people, peoplerulesetschedule, setpoint_values, runner, model, 'initial')

  # alter schedules
  addnewscheduleruleset_occupancy(lightingrulesetschedule, peoplerulesetschedule, ext_hr, start_month, end_month, dayofweek, 'evening', runner)

  setpoint_values = gather_light_avg_high_low_values(light, lightingrulesetschedule, setpoint_values, runner, model, 'final')

  # assign the modified schedule to the people
  light[0].setSchedule(lightingrulesetschedule)

  return setpoint_values

end
##########################################################
##########################################################