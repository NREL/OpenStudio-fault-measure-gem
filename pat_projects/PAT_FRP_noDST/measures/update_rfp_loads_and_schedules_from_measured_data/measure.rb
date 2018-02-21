# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'csv'

# start the measure
class UpdateRFPLoadsAndSchedulesFromMeasuredData < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Update RFP Loads and Schedules from Measured Data"
  end

  # human readable description
  def description
    return "For calibration to measured data update selected loads and load schedules to match measured data for specific dates"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Time series data has 15 minute data for selected dates. Map specific columns in data to specific objects in model. When find entry for specific date, add a new rule to existing schedule with 24x4 time/value pairs."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # the name of the sql file
    csv_name = OpenStudio::Ruleset::OSArgument.makeStringArgument("csv_name", true)
    csv_name.setDisplayName("Path to CSV file for the metered data")
    csv_name.setDescription("Path to CSV file including file name.")
    csv_name.setDefaultValue("../../../lib/resources/mtr.csv")
    args << csv_name

    return args
  end

  # lookup measured data header is snake_case version of header
  def lookup_measured_data(csv_hash,target_dates,header_sym,runner)
    rule_values_15_min = {}
    max_values_each_day = []
    target_dates.each do |date|
      rule_values_15_min[date] = []
      24.times do |hour|
        4.times do |quater_hour|

          # skip 0 0
          next if hour == 0 and quater_hour == 0

          min = sprintf '%02d', (quater_hour) * 15 # need padded string
          if csv_hash.has_key?("#{date} #{hour}:#{min}")
            raw_value = csv_hash["#{date} #{hour}:#{min}"][header_sym]
            if raw_value.nil?
              rule_values_15_min[date] << 0.0
            elsif raw_value == "NAN"
              rule_values_15_min[date] << 0.0
            else
              rule_values_15_min[date] << csv_hash["#{date} #{hour}:#{min}"][header_sym]
            end
          else
            runner.registerWarning("can't find timestep of #{date} #{hour}:#{min} for #{header_sym}, using previous value for hash")
            rule_values_15_min[date] << rule_values_15_min[date].last # will have to catch this and do something about it downstream
          end

        end
      end

      # this dataset missing last timestep
      if rule_values_15_min[date].size < 96
        rule_values_15_min[date] << rule_values_15_min[date].last
      end

      max_values_each_day << rule_values_15_min[date].max
    end

    return {:values => rule_values_15_min, :max => max_values_each_day.max}
  end

  # add rule to schedule
  def add_rule_to_schedule(model,schedule,day,values)

    # add values
    schedule_day  = OpenStudio::Model::ScheduleDay.new(model)
    counter = 0
    24.times do |hour|
      4.times do |quarter_hour|
        next if hour == 0 and quarter_hour == 0 # don't want an until 0:0) value
        min = quarter_hour * 15 # need number
        schedule_day.addValue(OpenStudio::Time.new(0, hour, min, 0), values[counter])
        counter += 1
      end
    end
    # add last value
    #schedule_day.addValue(OpenStudio::Time.new(0, 24, 0, 0), values.last)
    # set days of year and days of week
    schedule_rule = OpenStudio::Model::ScheduleRule.new(schedule,schedule_day)
    schedule_rule.setName(day)
    start_date = day.split('/')
    # not using addSpecificDate because it isn't fully inspectable in GUI
    #schedule_rule.addSpecificDate(model.getYearDescription.makeDate(start_date[0].to_i, start_date[1].to_i))
    date = model.getYearDescription.makeDate(start_date[0].to_i, start_date[1].to_i)
    schedule_rule.setStartDate(date)
    schedule_rule.setEndDate(date)
    schedule_rule.setApplySunday(true)
    schedule_rule.setApplyMonday(true)
    schedule_rule.setApplyTuesday(true)
    schedule_rule.setApplyWednesday(true)
    schedule_rule.setApplyThursday(true)
    schedule_rule.setApplyFriday(true)
    schedule_rule.setApplySaturday(true)

    return schedule_rule

  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    csv_name = runner.getStringArgumentValue("csv_name", user_arguments)

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.getSchedules.size} schedules.")

    # array of altered schedules for reporting
    altered_schedules = []

    # tolerance values
    tolerance = 1.02

    # load CSV file (deleted first row to get desired row as header)
    #csv_file = "#{File.dirname(__FILE__)}/resources/combined_15m.csv"
    csv_hash = {}
    CSV.foreach(csv_name, :headers => :second_row, :header_converters => :symbol, :converters => :all) do |row|
      next if $. < 2 # skip first 1 rows
      short_name = row.fields[0]
      csv_hash[short_name] = Hash[row.headers[1..-1].zip(row.fields[1..-1])]
    end
 
    # look for dates in CSV file
    target_dates = []
    csv_hash.keys.each do |date|
      trim_value = date.index(" ") - date.length
      date = date[0...trim_value]
      target_dates << date
    end
    target_dates = target_dates.uniq!
    # each day goes from 0:00 to 23:45

    # gather data for wall heaters and update schedules
    runner.registerInfo("Adding rules to WALL_HEATER schedule used by plug loads in two spaces")
    heater_sch = model.getScheduleRulesetByName("WALL_HEATER").get # used for two 1000w electric equipment objects
    lookup_heater = lookup_measured_data(csv_hash,target_dates,:wh_wallheater_tot,runner)
    expected_max = 2000.0
    timesteps_per_hour = 4
    if lookup_heater[:max] * timesteps_per_hour  > expected_max * tolerance
      runner.registerWarning("Max measured wall heater value of #{lookup_heater[:max] * timesteps_per_hour} is more than #{tolerance} times the expected value of #{expected_max}W")
    end
    lookup_heater[:values].each do |day,values|
      new_values = []
      values.each do |value|
        if not value.nil?
          new_values << [value/(expected_max/timesteps_per_hour),1.0].min # if number is slightly larger than 1.0 round down
        else
          # todo - address nil value
        end

      end
      schedule_rule = add_rule_to_schedule(model,heater_sch,day,new_values)
    end
    altered_schedules << heater_sch

    # set fuel for other equipment so it counts in end use (make sure this is subtracted this from what goes into plug load objects)
    model.getOtherEquipments.each do |other_equip|
      other_equip.setFuelType("Electricity")
    end

    # update plug loads other than stair heaters. Deduct portion used for other equipment (humidifier)
    model.getElectricEquipments.each do |elec_equip|

      # skip stair heater changed elsewhere
      space_name = elec_equip.space.get.name.to_s
      next if space_name == "Room 101" || space_name == "Room 201"

      # get design level
      elec_equip_w = elec_equip.electricEquipmentDefinition.designLevel.get
      elec_equip.electricEquipmentDefinition.setName("#{space_name} elec equip def")

      # clone schedule
      runner.registerInfo("Adding rules to clone of #{elec_equip.schedule.get.name} named #{space_name}_elec_equip_sch")
      new_sch = elec_equip.schedule.get.clone(model).to_ScheduleRuleset.get
      new_sch.setName("#{space_name}_elec_equip_sch")
      elec_equip.setSchedule(new_sch)

      # gather data
      column_name = "#{space_name.gsub("Room ","wh_plugs")}_tot".to_sym
      lookup_elec_equip = lookup_measured_data(csv_hash,target_dates,column_name,runner)

      # determine other equipment contribution and create updated data with deducted values.
      if elec_equip.space.get.otherEquipment.size == 0
        # no occupant load in this space
        lookup_elec_equip_adjusted = lookup_elec_equip
      else
        occupant_load = elec_equip.space.get.otherEquipment.first
        occupant_load_design_level = occupant_load.getDesignLevel(elec_equip.space.get.floorArea,0.0) # no people
        occupant_load_sch = occupant_load.schedule.get.to_ScheduleRuleset.get
        occupant_load_sch_rule = occupant_load_sch.defaultDaySchedule

        # update lookup equipment
        lookup_elec_equip_adjusted = {}
        lookup_elec_equip_adjusted[:values] = {}
        max_adjusted = 0.0
        lookup_elec_equip[:values].each do |day,values|
          lookup_elec_equip_adjusted[:values][day] = []
          values.each_with_index do |value,i|
            # get time from index
            hour = i/4
            minutes = (i % 4) * 15
            time = OpenStudio::Time.new(0, hour, minutes, 0)

            if not value.nil?
              fractional_value_at_time = occupant_load_sch_rule.getValue(time)
              target_value = [value - fractional_value_at_time * occupant_load_design_level * 0.25,0.0].max # added 0.25 since converting W value to wh in 15 minute time step
              lookup_elec_equip_adjusted[:values][day] << target_value
              #runner.registerInfo("At #{day} #{hour} #{minutes} fractional value is #{fractional_value_at_time} design level is #{occupant_load_design_level}. Changing from #{value} to #{target_value}")
              if target_value > max_adjusted
                max_adjusted = target_value
              end
            else
              # todo - address nil value
            end
          end
          lookup_elec_equip_adjusted[:max]=  max_adjusted
        end

      end

      # add new rules to schedule
      if lookup_elec_equip_adjusted[:max] * timesteps_per_hour  > elec_equip_w * tolerance
        runner.registerInfo("Max measured plug load value of #{lookup_elec_equip_adjusted[:max] * timesteps_per_hour} is more than #{tolerance} times the expected value of #{elec_equip_w}W for #{space_name}. Increasing electric equipment design level to max measured value.")
        elec_equip_w = lookup_elec_equip_adjusted[:max] * timesteps_per_hour
        elec_equip.electricEquipmentDefinition.setDesignLevel(elec_equip_w)
      end
        lookup_elec_equip_adjusted[:values].each do |day,values|
        new_values = []
        values.each do |value|

          if not value.nil?
            new_values << [[value/(elec_equip_w/timesteps_per_hour),1.0].min,0.0].max # if number is slightly larger than 1.0 round down, if it is less than 0 increase to 0
            # negative number was possible if more consumption is going to Other Equipment (humidifier) thatn was measured
          else
            # todo - address nil value
          end

        end
        schedule_rule = add_rule_to_schedule(model,new_sch,day,new_values)
      end
      altered_schedules << new_sch

    end

    # get installed lighting W for first and second story
    lighting_power_by_story = {}
    model.getBuildingStorys.each do |story|
      lighting_power_by_story[story.name.to_s] = 0.0
      story.spaces.each do |space|
        lighting_power_by_story[story.name.to_s] += space.lightingPower
      end
    end
    story_first_target = lighting_power_by_story['Building Story 1']
    story_second_target = lighting_power_by_story['Building Story 3'] # 2 is first story plenum

    # gather data for first story lights to update schedule. Add exit signs to general lighting
    runner.registerInfo("Adding rules to BLDG_LIGHT_DownSt_SCH schedule used by lights on the first floor.")
    lookup_lights_dwn_gen = lookup_measured_data(csv_hash,target_dates,:wh_lights_dwn_tot,runner)
    lookup_lights_dwn_em = lookup_measured_data(csv_hash,target_dates,:wh_emlights_dwn_tot,runner)
    # combine data from to lighting sources
    lookup_lights_combined = {}
    lookup_lights_combined_max = []
    lookup_lights_dwn_gen[:values].each do |day,values|
      lookup_lights_combined[day] = []
      values_b = []
      values.each do |v|
        if not v.nil? then values_b << v end
      end
      lookup_lights_combined_max << values_b.max
      values.each_with_index do |value,i|
        next if value.nil?
        em_lighs_value = lookup_lights_dwn_em[:values][day][i]
        lookup_lights_combined[day] << value + em_lighs_value
      end
    end
    if lookup_lights_combined_max.max * timesteps_per_hour  > story_first_target * tolerance
      runner.registerWarning("Max measured first floor lighting value of  #{lookup_lights_combined_max.max * timesteps_per_hour} is more than #{tolerance} times the expected value of #{story_first_target}W")
    end
    light_sch_dwn = model.getScheduleRulesetByName("BLDG_LIGHT_DownSt_SCH").get
    lookup_lights_combined.each do |day,values|
      new_values = []
      values.each do |value|
        new_values << [value/(story_first_target/timesteps_per_hour),1.0].min # if number is slightly larger than 1.0 round down
      end
      schedule_rule = add_rule_to_schedule(model,light_sch_dwn,day,new_values)
    end
    altered_schedules << light_sch_dwn

    # gather data for second story lights to update schedule. Add exit signs to general lighting
    runner.registerInfo("Adding rules to BLDG_LIGHT_Upst_SCH schedule used by lights on the second floor.")
    lookup_lights_up_gen = lookup_measured_data(csv_hash,target_dates,:wh_lights_up_tot,runner)
    lookup_lights_up_em = lookup_measured_data(csv_hash,target_dates,:wh_emlights_up_tot,runner)
    # combine data from to lighting sources
    lookup_lights_combined = {}
    lookup_lights_combined_max = []
    lookup_lights_up_gen[:values].each do |day,values|
      lookup_lights_combined[day] = []
      values_b = []
      values.each do |v|
        if not v.nil? then values_b << v end
      end
      lookup_lights_combined_max << values_b.max
      values.each_with_index do |value,i|
        next if value.nil?
        em_lighs_value = lookup_lights_up_em[:values][day][i]
        lookup_lights_combined[day] << value + em_lighs_value
      end
    end
    if lookup_lights_combined_max.max * timesteps_per_hour  > story_second_target * tolerance
      runner.registerWarning("Max measured second floor lighting value of  #{lookup_lights_combined_max.max * timesteps_per_hour} is more than #{tolerance} times the expected value of #{story_second_target}W")
    end
    light_sch_up = model.getScheduleRulesetByName("BLDG_LIGHT_Upst_SCH").get
    lookup_lights_combined.each do |day,values|
      new_values = []
      values.each do |value|
        new_values << [value/(story_second_target/timesteps_per_hour),1.0].min # if number is slightly larger than 1.0 round down
      end
      schedule_rule = add_rule_to_schedule(model,light_sch_up,day,new_values)
    end
    altered_schedules << light_sch_up
    
    # report final condition of model
    runner.registerFinalCondition("#{altered_schedules.size} schedules were altered.")

    return true

  end
  
end

# register the measure to be used by the application
UpdateRFPLoadsAndSchedulesFromMeasuredData.new.registerWithApplication
