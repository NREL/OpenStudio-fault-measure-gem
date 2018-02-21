# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# require all .rb files in resources folder
Dir[File.dirname(__FILE__) + '/resources/*.rb'].each {|file| require file }

# start the measure
class OrnlTwoStoryFrpModel < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Ornl Two Story Frp Model"
  end

  # human readable description
  def description
    return "This measure will make the ORNL Two Story Flexible Research Platrom OpenStudio Model."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This will start with an OSM file in the resoruce directory. Simulation settings, geometry, constructions, and schedules will come in with the IDF. Schedules will need to be converted to Rulset Schedules so they will work with downstream measures. Schedules may need to be overridden from external resource data unique to a specific test configuraiton. EMS will need to be updated, and HVAC systems will need to be rebuilt.

At some point the OSM could become the working model that gets updated and converted to IDF as needed. In that case this meaure be needed. There will be a mostly complete OSM model that just uses measure to adapt operational characteristics as needed."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # argument for RTU system (used choice vs. bool in case we want more options)
    choices = OpenStudio::StringVector.new
    choices << "Enabled"
    choices << "Disabled"
    choices << "Calibration on/off"
    choices << "Calibration on/off alt"
    hvac_mode = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("hvac_mode", choices,true)
    hvac_mode.setDisplayName("Select HVAC Mode")
    hvac_mode.setDefaultValue("Enabled")
    args << hvac_mode

    # argument for RTU system (used choice vs. bool in case we want more options)
    choices = OpenStudio::StringVector.new
    choices << "Lennox KCA120S4"
    choices << "Field Data"
    choices << "Lab Data"
    dx_curves = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("dx_curves", choices,true)
    dx_curves.setDisplayName("Select DX Curves")
    dx_curves.setDefaultValue("Lennox KCA120S4")
    args << dx_curves

    # argument for fan performance
    choices = OpenStudio::StringVector.new
    choices << "Original"
    choices << "Field Data"
    fan_curves = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("fan_curves", choices,true)
    fan_curves.setDisplayName("Select Fan Curves")
    fan_curves.setDefaultValue("Original")
    args << fan_curves

    # argument for fan_eff
    fan_eff = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("fan_eff",true)
    fan_eff.setDisplayName("Fan Efficiency")
    fan_eff.setUnits("si values")
    fan_eff.setDefaultValue(0.9)
    args << fan_eff

    # argument for fan_eff
    fan_pr = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("fan_pr",true)
    fan_pr.setDisplayName("Fan Pressure Rise")
    fan_pr.setUnits("si values")
    fan_pr.setDefaultValue(1000.0)
    args << fan_pr

    # argument for fan_eff
    fan_max_flow = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("fan_max_flow",true)
    fan_max_flow.setDisplayName("Fan Maximum Flow Rate")
    fan_max_flow.setUnits("si values")
    fan_max_flow.setDefaultValue(2.35973721600001)
    args << fan_max_flow

    # argument for fan_eff
    fan_power_at_min = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("fan_power_at_min",true)
    fan_power_at_min.setDisplayName("Fan Power at Minimum Flow Rate")
    fan_power_at_min.setUnits("si values")
    fan_power_at_min.setDefaultValue(1.330891789824)
    args << fan_power_at_min

    # argument for daylight savings
    dst = OpenStudio::Ruleset::OSArgument::makeBoolArgument("dst",true)
    dst.setDisplayName("Enable Daylight Savings Time")
    dst.setDefaultValue(false)
    args << dst

    # argument for setpoint_temp_floor
    setpoint_temp_floor = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("setpoint_temp_floor",true)
    setpoint_temp_floor.setDisplayName("Floor for Air Loop Supply Setpoint Temperature")
    setpoint_temp_floor.setUnits("C")
    setpoint_temp_floor.setDefaultValue(12.78) # was 15 prior to this coce
    args << setpoint_temp_floor

    # argument for oa_threshold_for_setpoint_floor
    oa_threshold_for_setpoint_floor = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("oa_threshold_for_setpoint_floor",true)
    oa_threshold_for_setpoint_floor.setDisplayName("Outdoor Dry Bulb Temperature at or above which the airloop setpoint should reach the floor.")
    oa_threshold_for_setpoint_floor.setUnits("C")
    oa_threshold_for_setpoint_floor.setDefaultValue(13.89)
    args << oa_threshold_for_setpoint_floor

    # argument for setpoint_temp_ceiling
    setpoint_temp_ceiling = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("setpoint_temp_ceiling",true)
    setpoint_temp_ceiling.setDisplayName("Ceiling for Air Loop Supply Setpoint Temperature")
    setpoint_temp_ceiling.setUnits("C")
    setpoint_temp_ceiling.setDefaultValue(20.0)
    args << setpoint_temp_ceiling

    # argument for oa_threshold_for_setpoint_ceiling
    oa_threshold_for_setpoint_ceiling = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("oa_threshold_for_setpoint_ceiling",true)
    oa_threshold_for_setpoint_ceiling.setDisplayName("Outdoor Dry Bulb Temperature at or below which the airloop setpoint should reach the ceiling.")
    oa_threshold_for_setpoint_ceiling.setUnits("C")
    oa_threshold_for_setpoint_ceiling.setDefaultValue(7.7)
    args << oa_threshold_for_setpoint_ceiling

    # argument for fan performance
    choices = OpenStudio::StringVector.new
    choices << "EMS"
    choices << "Scheduled"
    stp_mgr = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("stp_mgr", choices,true)
    stp_mgr.setDisplayName("Air Loop Setpoint Strategy.")
    stp_mgr.setDefaultValue("EMS")
    args << stp_mgr

    # argument infiltration
    choices = OpenStudio::StringVector.new
    choices << "1/4th from 6am to 6pm"
    choices << "Always On"
    choices << "1/4th during no HVAC test"
    choices << "dynamic_infil"
    infil_sch_arg = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("infil_sch_arg", choices,true)
    infil_sch_arg.setDisplayName("Select Infiltration Schedule Behavior")
    infil_sch_arg.setDefaultValue("1/4th during no HVAC test")
    args << infil_sch_arg

    # arguments below only work because this measure is used with a seed model that has very specific known values for the infiltration schedule
    # need to make sure the sum of the reduction isn't greater than 1, and probalby not greater than 0.75 Keep variable range tight
    # no OA so doesn't matter when HVAC system is on or off, it matters when staff or visitors are going into and out of the building

    # argument for reduction in infiltration for daytime during typical weekend vs. typical weekday
    infil_redu_day_weekend = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("infil_redu_day_weekend",true)
    infil_redu_day_weekend.setDisplayName("Fractional reduction in schedule for weekend vs. weekday.")
    infil_redu_day_weekend.setDescription("This is only used if Infiltration Schedule Behavior is det to dynamic_infil")
    infil_redu_day_weekend.setDefaultValue(0.25) # values in schedule in model will be reduced by this if starting value is exactly 0.9999
    args << infil_redu_day_weekend

    # argument for reduction in infiltration for daytime during free float test day vs. typical weekend
    infil_redu_day_ff = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("infil_redu_day_ff",true)
    infil_redu_day_ff.setDisplayName("Fractional reduction in schedule for free float vs. weekend.")
    infil_redu_day_ff.setDescription("This is only used if Infiltration Schedule Behavior is det to dynamic_infil")
    infil_redu_day_ff.setDefaultValue(0.125) # values in schedule in model will be reduced by this if starting value is exactly 0.9998
    args << infil_redu_day_ff

    # argument for reduction in infiltration for daytime during night time vs. free float test day
    infil_redu_night = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("infil_redu_night",true)
    infil_redu_night.setDisplayName("Fractional reduction in schedule for night vs. free float.")
    infil_redu_night.setDescription("This is only used if Infiltration Schedule Behavior is det to dynamic_infil")
    infil_redu_night.setDefaultValue(0.125)# values in schedule in model will be reduced by this if starting value is exactly 0.9997
    args << infil_redu_night

    # todo - add argument to set doors between stairs and adjacent walls as air wall, if we want to be able to enable zone mixing for them.

    # set multipliers for first floor internal mass
    int_mass_first_thin_area = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("int_mass_first_thin_area",true)
    int_mass_first_thin_area.setDisplayName("Area of thin internal mass per first story space, except where overriden by arguments below.")
    int_mass_first_thin_area.setDescription("Thin internal mass is modeled as 1/16th inch metal")
    int_mass_first_thin_area.setUnits("ft^2")
    int_mass_first_thin_area.setDefaultValue(20.0)
    args << int_mass_first_thin_area
    int_mass_first_thick_area = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("int_mass_first_thick_area",true)
    int_mass_first_thick_area.setDisplayName("Area of thick internal mass per first story space, except where overriden by arguments below.")
    int_mass_first_thick_area.setDescription("Thick internal mass is modeled as 1/4th inch metal")
    int_mass_first_thick_area.setUnits("ft^2")
    int_mass_first_thick_area.setDefaultValue(5.0)
    args << int_mass_first_thick_area

    # set multipliers for second floor internal mass
    int_mass_second_thin_area = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("int_mass_second_thin_area",true)
    int_mass_second_thin_area.setDisplayName("Area of thin internal mass per second story space, except where overriden by arguments below.")
    int_mass_second_thin_area.setDescription("Thin internal mass is modeled as 1/16th inch metal")
    int_mass_second_thin_area.setUnits("ft^2")
    int_mass_second_thin_area.setDefaultValue(5.0)
    args << int_mass_second_thin_area
    int_mass_second_thick_area = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("int_mass_second_thick_area",true)
    int_mass_second_thick_area.setDisplayName("Area of thick internal mass per second story space, except where overriden by arguments below.")
    int_mass_second_thick_area.setDescription("Thick internal mass is modeled as 1/4th inch metal")
    int_mass_second_thick_area.setUnits("ft^2")
    int_mass_second_thick_area.setDefaultValue(5.0)
    args << int_mass_second_thick_area

    # set multipliers for plenum internal mass
    int_mass_plenum_thin_area = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("int_mass_plenum_thin_area",true)
    int_mass_plenum_thin_area.setDisplayName("Area of thin internal mass per plenum space.")
    int_mass_plenum_thin_area.setDescription("Thin internal mass is modeled as 1/16th inch metal")
    int_mass_plenum_thin_area.setUnits("ft^2")
    int_mass_plenum_thin_area.setDefaultValue(500.0)
    args << int_mass_plenum_thin_area
    int_mass_plenum_thick_area = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("int_mass_plenum_thick_area",true)
    int_mass_plenum_thick_area.setDisplayName("Area of thick internal mass per plenum space.")
    int_mass_plenum_thick_area.setDescription("Thick internal mass is modeled as 1/4th inch metal")
    int_mass_plenum_thick_area.setUnits("ft^2")
    int_mass_plenum_thick_area.setDefaultValue(50.0)
    args << int_mass_plenum_thick_area

    # set multipliers for stairs internal mass (for now split thermal mass across both spaces)
    int_mass_stair_thin_area = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("int_mass_stair_thin_area",true)
    int_mass_stair_thin_area.setDisplayName("Area of thin internal mass per stair space.")
    int_mass_stair_thin_area.setDescription("Thin internal mass is modeled as 1/16th inch metal")
    int_mass_stair_thin_area.setUnits("ft^2")
    int_mass_stair_thin_area.setDefaultValue(0.0)
    args << int_mass_stair_thin_area
    int_mass_stair_thick_area = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("int_mass_stair_thick_area",true)
    int_mass_stair_thick_area.setDisplayName("Area of thick internal mass per stair space.")
    int_mass_stair_thick_area.setDescription("Thick internal mass is modeled as 1/4th inch metal")
    int_mass_stair_thick_area.setUnits("ft^2")
    int_mass_stair_thick_area.setDefaultValue(400.0)
    args << int_mass_stair_thick_area

    # set multipliers for room 105 internal mass
    int_mass_room_105_thin_area = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("int_mass_room_105_thin_area",true)
    int_mass_room_105_thin_area.setDisplayName("Area of thin internal mass for room 105.")
    int_mass_room_105_thin_area.setDescription("Thin internal mass is modeled as 1/16th inch metal")
    int_mass_room_105_thin_area.setUnits("ft^2")
    int_mass_room_105_thin_area.setDefaultValue(350.0)
    args << int_mass_room_105_thin_area
    int_mass_room_105_thick_area = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("int_mass_room_105_thick_area",true)
    int_mass_room_105_thick_area.setDisplayName("Area of thick internal mass for room 105.")
    int_mass_room_105_thick_area.setDescription("Thick internal mass is modeled as 1/4th inch metal")
    int_mass_room_105_thick_area.setUnits("ft^2")
    int_mass_room_105_thick_area.setDefaultValue(15.0)
    args << int_mass_room_105_thick_area

    # set multipliers for 106 internal mass
    int_mass_room_106_thin_area = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("int_mass_room_106_thin_area",true)
    int_mass_room_106_thin_area.setDisplayName("Area of thin internal mass for room 106.")
    int_mass_room_106_thin_area.setDescription("Thin internal mass is modeled as 1/16th inch metal")
    int_mass_room_106_thin_area.setUnits("ft^2")
    int_mass_room_106_thin_area.setDefaultValue(100.0)
    args << int_mass_room_106_thin_area
    int_mass_room_106_thick_area = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("int_mass_room_106_thick_area",true)
    int_mass_room_106_thick_area.setDisplayName("Area of thick internal mass for room 106.")
    int_mass_room_106_thick_area.setDescription("Thick internal mass is modeled as 1/4th inch metal")
    int_mass_room_106_thick_area.setUnits("ft^2")
    int_mass_room_106_thick_area.setDefaultValue(40.0)
    args << int_mass_room_106_thick_area

    # global int_mass_multiplier
    int_mass_multiplier = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("int_mass_multiplier",true)
    int_mass_multiplier.setDisplayName("Global Internal Mass Multiplier")
    int_mass_multiplier.setDescription("For use with calibration a single multiplier applied to values above in area of internal mass")
    int_mass_multiplier.setUnits("ft^2")
    int_mass_multiplier.setDefaultValue(1.0)
    args << int_mass_multiplier

    # argument for add_water_tanks
    add_water_tanks = OpenStudio::Ruleset::OSArgument::makeBoolArgument("add_water_tanks",true)
    add_water_tanks.setDisplayName("Add mass for 4 x 200 gallon non insulated water tanks to Room 105.")
    add_water_tanks.setDefaultValue(true)
    args << add_water_tanks

    # shgc_multiplierr
    shgc_multiplier = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("shgc_multiplier",true)
    shgc_multiplier.setDisplayName("SHGC Multiplier")
    shgc_multiplier.setDescription("Changes default SHGC value entered for Double Pane material used for external windows in the model.")
    shgc_multiplier.setUnits("ft^2")
    shgc_multiplier.setDefaultValue(1.0)
    args << shgc_multiplier

    # ufactor_multiplier
    ufactor_multiplier = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("ufactor_multiplier",true)
    ufactor_multiplier.setDisplayName("U Factor Multiplier")
    ufactor_multiplier.setDescription("Changes default U Factor value entered for Double Pane material used for external windows in the model.")
    ufactor_multiplier.setUnits("ft^2")
    ufactor_multiplier.setDefaultValue(1.0)
    args << ufactor_multiplier

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    #use the built-in error checking
    if not runner.validateUserArguments(arguments(model),user_arguments)
      return false
    end

    # get arguments
    hvac_mode = runner.getStringArgumentValue("hvac_mode",user_arguments)
    dx_curves = runner.getStringArgumentValue("dx_curves",user_arguments)
    fan_curves = runner.getStringArgumentValue("fan_curves",user_arguments)
    fan_eff = runner.getDoubleArgumentValue("fan_eff",user_arguments)
    fan_pr = runner.getDoubleArgumentValue("fan_pr",user_arguments)
    fan_max_flow = runner.getDoubleArgumentValue("fan_max_flow",user_arguments)
    fan_power_at_min = runner.getDoubleArgumentValue("fan_power_at_min",user_arguments)
    dst = runner.getBoolArgumentValue("dst",user_arguments)
    setpoint_temp_floor = runner.getDoubleArgumentValue("setpoint_temp_floor",user_arguments)
    setpoint_temp_ceiling = runner.getDoubleArgumentValue("setpoint_temp_ceiling",user_arguments)
    oa_threshold_for_setpoint_floor = runner.getDoubleArgumentValue("oa_threshold_for_setpoint_floor",user_arguments)
    oa_threshold_for_setpoint_ceiling = runner.getDoubleArgumentValue("oa_threshold_for_setpoint_ceiling",user_arguments)
    stp_mgr = runner.getStringArgumentValue("stp_mgr",user_arguments)
    infil_sch_arg = runner.getStringArgumentValue("infil_sch_arg",user_arguments)
    infil_redu_day_weekend = runner.getDoubleArgumentValue("infil_redu_day_weekend",user_arguments)
    infil_redu_day_ff = runner.getDoubleArgumentValue("infil_redu_day_ff",user_arguments)
    infil_redu_night = runner.getDoubleArgumentValue("infil_redu_night",user_arguments)
    int_mass_first_thin_area = runner.getDoubleArgumentValue("int_mass_first_thin_area",user_arguments)
    int_mass_first_thick_area = runner.getDoubleArgumentValue("int_mass_first_thick_area",user_arguments)
    int_mass_second_thin_area = runner.getDoubleArgumentValue("int_mass_second_thin_area",user_arguments)
    int_mass_second_thick_area = runner.getDoubleArgumentValue("int_mass_second_thick_area",user_arguments)
    int_mass_plenum_thin_area = runner.getDoubleArgumentValue("int_mass_plenum_thin_area",user_arguments)
    int_mass_plenum_thick_area = runner.getDoubleArgumentValue("int_mass_plenum_thick_area",user_arguments)
    int_mass_stair_thin_area = runner.getDoubleArgumentValue("int_mass_stair_thin_area",user_arguments)
    int_mass_stair_thick_area = runner.getDoubleArgumentValue("int_mass_stair_thick_area",user_arguments)
    int_mass_room_105_thin_area = runner.getDoubleArgumentValue("int_mass_room_105_thin_area",user_arguments)
    int_mass_room_105_thick_area = runner.getDoubleArgumentValue("int_mass_room_105_thick_area",user_arguments)
    int_mass_room_106_thin_area = runner.getDoubleArgumentValue("int_mass_room_106_thin_area",user_arguments)
    int_mass_room_106_thick_area = runner.getDoubleArgumentValue("int_mass_room_106_thick_area",user_arguments)
    int_mass_multiplier = runner.getDoubleArgumentValue("int_mass_multiplier",user_arguments)
    add_water_tanks = runner.getBoolArgumentValue("add_water_tanks",user_arguments)
    shgc_multiplier = runner.getDoubleArgumentValue("shgc_multiplier",user_arguments)
    ufactor_multiplier = runner.getDoubleArgumentValue("ufactor_multiplier",user_arguments)

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.objects.size} objects.")

    # >> replace model in with model from resources folder
    #base_model_path = "#{File.dirname(__FILE__)}/resources/FRP2_raw_import.osm"
    #base_model_path = "#{File.dirname(__FILE__)}/resources/FRP2_raw_import_updated_ORNL.osm"
    #base_model_path = "#{File.dirname(__FILE__)}/resources/FRP2_raw_import_updated_ORNL2.osm"
    #base_model_path = "#{File.dirname(__FILE__)}/resources/FRP2_raw_import_updated_ORNL3.osm"
    base_model_path = "#{File.dirname(__FILE__)}/resources/FRP2_raw_import_updated_ORNL4.osm"
    translator = OpenStudio::OSVersion::VersionTranslator.new
    oModel = translator.loadModel(base_model_path)
    if oModel.empty?
      runner.registerError("Could not load base model model from '" + base_model_path.to_s + "'.")
      return false
    end

    #model.swap(oModel.get)
    # this gives [BUG] Segmentation fault at 0x00000100000061 if I then do model.getSpaces.first.surfaces.size  

    # alternative swap
    # remove existing objects from model
    handles = OpenStudio::UUIDVector.new
    model.objects.each do |obj|
      handles << obj.handle
    end
    model.removeObjects(handles)
    # add new file to empty model
    model.addObjects( oModel.get.toIdfFile.objects )
    runner.registerInfo("#{base_model_path} was imported with #{model.objects.size} objects.")

    # update attributes that didn't import in
    year_desc = model.getYearDescription
    year_desc.setCalendarYear(2015)
    runner.registerInfo("Setting Calendar Year to #{year_desc.calendarYear}.")

    # cleanup zone names
    model.getThermalZones.each do |zone|

      # clean up zone name so it matches what it was in IDF
      zone.setName("#{zone.name.get.gsub(' Thermal Zone','')}")

    end
    runner.registerInfo("Reverting Thermal Zone back to original names from IDF file.")

    # >> assign building stories

    # find the first story with z coordinate, create one if needed
    def getStoryForNominalZCoordinate(model, minz)
      model.getBuildingStorys.each do |story|
        z = story.nominalZCoordinate
        if not z.empty?
          if minz.round(2) == z.get.round(2)
            return story
          end
        end
      end
      story = OpenStudio::Model::BuildingStory.new(model)
      story.setNominalZCoordinate(minz)
      return story
    end

    # make has of spaces and minz values
    sorted_spaces = Hash.new
    model.getSpaces.each do |space|
      # loop through space surfaces to find min z value
      z_points = []
      space.surfaces.each do |surface|
        surface.vertices.each do |vertex|
          z_points << vertex.z
        end
      end
      minz = z_points.min + space.zOrigin
      sorted_spaces[space] = minz
    end

    # pre-sort spaces
    sorted_spaces = sorted_spaces.sort{|a,b| a[1]<=>b[1]}

    # this should take the sorted list and make and assign stories
    sorted_spaces.each do |space|
      space_obj = space[0]
      space_minz = space[1]
      if space_obj.buildingStory.empty?

        story = getStoryForNominalZCoordinate(model, space_minz)
        space_obj.setBuildingStory(story)

      end
    end
    # reporting final number of stories
    runner.registerInfo("Added #{model.getBuildingStorys.size} stories ot the building.")

    # >> convert all schedules to ScheduleRulesets (This will support fault measures that alter schedules)
    new_schedules = []
    model.getScheduleCompacts.each do |compact|

      # skip specific schedules that are expected to be compact in EMS and will not be altered by fault measures
      next if compact.name.get.to_s == "DOAS-Always 1"

      orig_name = compact.name.get
      sch_translator = ScheduleTranslator.new(model, compact)
      os_sch = sch_translator.translate

      # replace uses of schedule, model.swap(compact,os_sch) doesn't work
      compact.sources.each do |source|
        source_index = source.getSourceIndices(compact.handle)
        source_index.each do |field|
          source.setPointer(field,os_sch.handle)
        end
      end
      compact.remove
      os_sch.setName(orig_name)
      new_schedules << os_sch
    end
    runner.registerInfo("Added #{new_schedules.size} ScheduleRuleset objects to the model.")

    # todo - can remove this if using v4 which has these manually chagned in IDF file
    model.getElectricEquipments.each do |equip|
      space_name = equip.space.get.name.get
      if space_name.include?('01') # should catch stairs
        # don't alter schedule assigned to unit heater in stair
      elsif space_name.include?('Room 1')
        target_schedule = model.getScheduleByName('New_BLDG_EQUIP_SCH_Down').get
        equip.setSchedule(target_schedule)
      elsif space_name.include?('Room 2')
        target_schedule = model.getScheduleByName('New_BLDG_EQUIP_SCH_Up').get
        equip.setSchedule(target_schedule)
      else # shouldn't hit this

      end
    end

    # >> add infiltration manually, ZoneInfiltration:DesignFlowRate on All Zones doesn't come in on reverse translation
    # todo - consider coming up with equiv ACH for structure using exterior walls and roof vs. ACH
    model.getSpaces.each do |space|
      infil = OpenStudio::Model::SpaceInfiltrationDesignFlowRate.new(model)
      infil.setName("#{space.name} Infiltration") # single object for all zones named Infiltration in source IDF
      infil.setAirChangesperHour(0.5)
      infil.setConstantTermCoefficient(0.606)
      infil.setTemperatureTermCoefficient(0.03636)
      infil.setVelocityTermCoefficient(0.1177)
      infil.setVelocitySquaredTermCoefficient(0.0)
      if infil_sch_arg == "Always On"
        infil.setSchedule(model.alwaysOnDiscreteSchedule)
      elsif infil_sch_arg == "1/4th during no HVAC test"
        infil.setSchedule(model.getScheduleRulesetByName("infil_custom_no_hvac").get)
      elsif infil_sch_arg == "dynamic_infil"
        # schedule changes made after loop through spaces.
        infil.setSchedule(model.getScheduleRulesetByName("dynamic_infil").get)
      else
        infil.setSchedule(model.getScheduleRulesetByName("INFIL_SCH").get)
      end
      infil.setSpace(space)
    end
    runner.registerInfo("Setting infiltration to 0.5 ACH for all spaces in model.")

    # alter the infiltration schedule once
    if infil_sch_arg == "dynamic_infil"

      # gather profiles
      profiles = []
      dyamic_infil_sch = model.getScheduleRulesetByName("dynamic_infil").get
      schedule = dyamic_infil_sch.to_ScheduleRuleset.get
      defaultProfile = schedule.defaultDaySchedule
      profiles << defaultProfile
      rules = schedule.scheduleRules
      rules.each do |rule|
        profiles << rule.daySchedule
      end

      # alter profiles
      profiles.each do |day_sch|
        times = day_sch.times
        i = 0

        # make arrays for original times and values
        times = day_sch.times
        values = day_sch.values
        day_sch.clearValues

        # make arrays for new values
        new_times = []
        new_values = []

        # loop through original time/value pairs to populate new array
        for i in 0..(values.length - 1)
          new_times << times[i]
          if values[i].round(2) == 0.99
            new_values << 1.0 - infil_redu_day_weekend
          elsif values[i].round(2) == 0.98
            new_values << 1.0 - infil_redu_day_weekend - infil_redu_day_ff
          elsif values[i].round(2) == 0.97
            new_values << 1.0 - infil_redu_day_weekend - infil_redu_day_ff - infil_redu_night
          else
            new_values << values[i]
          end
        end

        # generate new day_sch values
        for i in 0..(new_values.length - 1)
          day_sch.addValue(new_times[i], new_values[i])
        end
      end

    end

    # >> add HVAC

    # add in air loops
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    air_loop.setName('RoofTop')
    runner.registerInfo("Adding airloop named #{air_loop.name.to_s}.")

    # configure air loop nightcycle manager
    air_loop.setNightCycleControlType('StayOff') # changed to StayOff from CycleOnAny to match behavior of ORNL model
    avail_mgr = air_loop.availabilityManager.get.to_AvailabilityManagerNightCycle.get
    avail_mgr.setThermostatTolerance(1.38888888888889)
    runner.registerInfo("Adjusting nightcycle availability manager.")

    # configure air loop sizing
    sizing_system = air_loop.sizingSystem
    sizing_system.setDesignOutdoorAirFlowRate(0)
    # todo - investigate possible OS issue where MinimumSystemAirFlowRatio is in OS object vs. CentralHeatingMaximumSystemAirFlowRatio
      #sizing_system.setCentralHeatingMaximumSystemAirFlowRatio(0.9)
    sizing_system.setMinimumSystemAirFlowRatio(0.9)
    sizing_system.setPreheatDesignTemperature(2)
    sizing_system.setPrecoolDesignTemperature(11)
    sizing_system.setCentralCoolingDesignSupplyAirTemperature(14.4444444444444)
    sizing_system.setCentralHeatingDesignSupplyAirTemperature(43.3)
    sizing_system.setAllOutdoorAirinCooling(false)
    sizing_system.setAllOutdoorAirinHeating(false)
    sizing_system.setCentralCoolingDesignSupplyAirHumidityRatio(0.008)
    sizing_system.setCoolingDesignAirFlowMethod('Flow/System')
    sizing_system.setCoolingDesignAirFlowRate(1.6518160512)
    sizing_system.setHeatingDesignAirFlowMethod('Flow/System')
    sizing_system.setHeatingDesignAirFlowRate(1.51023181824)
    runner.registerInfo("Configuring System Sizing.")

    # populate air loop supply side

    # turn of availability of RTU if requested
    if hvac_mode == "Disabled"
      fan_sch = model.alwaysOffDiscreteSchedule
    elsif hvac_mode == "Enabled"
      # to fan schedule is translating incorrectly and won't hookup to fan, so making adjustments first
      # todo- even after fix looks like my schedule just applies M-F while IDF schedule is 7 days a week (has empty default profile and rule is M-F) add temp fix here, but then fix in translation later
      fan_sch = model.getScheduleRulesetByName("FanAvailSched").get
      first_rule = fan_sch.scheduleRules.first
      first_rule.setApplySaturday(true)
      first_rule.setApplySunday(true)
    else
      fan_sch = model.getScheduleRulesetByName(hvac_mode).get
    end

    # add fan
    fan = OpenStudio::Model::FanVariableVolume.new(model,model.alwaysOnDiscreteSchedule) # if RTU is off, we still should not have to change this
    fan.setName("RoofTop Supply Fan")
    # schedule set on air loop in OSM and will be assigned to fan in IDF
    air_loop.setAvailabilitySchedule(fan_sch)
    if fan_curves == "Field Data"
      fan.setFanEfficiency(fan_eff)
      fan.setPressureRise(fan_pr)
      fan.setMaximumFlowRate(fan_max_flow)
      fan.setFanPowerMinimumAirFlowRate(fan_power_at_min)
      fan.setMotorEfficiency(0.9)
      fan.setFanPowerCoefficient1(-3.0)
      fan.setFanPowerCoefficient2(12.4)
      fan.setFanPowerCoefficient3(-13.94)
      fan.setFanPowerCoefficient4(5.44)
      fan.setFanPowerCoefficient5(0.0)
    else # use original values
      fan.setFanEfficiency(fan_eff)
      fan.setPressureRise(fan_pr)
      fan.setMaximumFlowRate(fan_max_flow)
      fan.setFanPowerMinimumAirFlowRate(fan_power_at_min)
      fan.setMotorEfficiency(0.9)
      fan.setFanPowerCoefficient1(0.2823)
      fan.setFanPowerCoefficient2(-0.6037)
      fan.setFanPowerCoefficient3(4.0033)
      fan.setFanPowerCoefficient4(-3.8509)
      fan.setFanPowerCoefficient5(1.1559)
    end
    runner.registerInfo("Adding fan named #{fan.name.to_s}")

    # add heating coil
    htg_coil = OpenStudio::Model::CoilHeatingGas.new(model,model.alwaysOffDiscreteSchedule)
    htg_coil.setName("RoofTop HeatingCoil")
    htg_coil.setGasBurnerEfficiency(0.81)
    # RTU is 122,000 Btuh with 81 Btuh of that in first of two stages
    htg_coil.setNominalCapacity(35755.0) # W
    htg_coil.setPartLoadFractionCorrelationCurve(model.getCurveCubicByName("RoofTop Heating Coil PLF-FPLR").get)
    runner.registerInfo("Adding heating coil named #{htg_coil.name.to_s}.")

=begin
    # add mixed air used as variable for EMS
    htg_coil_outlet_node = OpenStudio::Model::SetpointManagerMixedAir.new(model)
    htg_coil_outlet_node.setName("RoofTop Heating Coil Air Temp Manager")
=end

    # add 1 of 2 CoilPerformanceDxCooling
    capft = model.getCurveBiquadraticByName("#{dx_curves} Stage 1 CapFT").get
    capfff = model.getCurveQuadraticByName("#{dx_curves} Stage 1 CapFFF").get
    eirft = model.getCurveBiquadraticByName("#{dx_curves} Stage 1 EIRFT").get
    eirfff = model.getCurveQuadraticByName("#{dx_curves} Stage 1 EIRFFF").get
    plffplr = model.getCurveQuadraticByName("#{dx_curves} PLFFPLR").get
    coil_perf_dx_clg_1 = OpenStudio::Model::CoilPerformanceDXCooling.new(model,capft,capfff,eirft,eirfff,plffplr)
    coil_perf_dx_clg_1.setName("#{dx_curves} Stage 1")
    coil_perf_dx_clg_1.setGrossRatedSensibleHeatRatio(0.687)
    coil_perf_dx_clg_1.setFractionofAirFlowBypassedAroundCoil(0.5)
    if dx_curves == "Lennox KCA120S4"
      coil_perf_dx_clg_1.setGrossRatedTotalCoolingCapacity(21023.7484296)
      coil_perf_dx_clg_1.setGrossRatedCoolingCOP(3.3)
      coil_perf_dx_clg_1.setRatedAirFlowRate(2.12376349440001)
    else
      coil_perf_dx_clg_1.setGrossRatedTotalCoolingCapacity(43960.66)
      coil_perf_dx_clg_1.setGrossRatedCoolingCOP(2.97)
      coil_perf_dx_clg_1.setRatedAirFlowRate(2.36) # 5000 CFM
      #coil_perf_dx_clg_1.setFractionofAirFlowBypassedAroundCoil(0.1)
    end

    # add 2 of 2 CoilPerformanceDxCooling
    capft = model.getCurveBiquadraticByName("#{dx_curves} Stage 1&2 CapFT").get
    capfff = model.getCurveQuadraticByName("#{dx_curves} Stage 1&2 CapFFF").get
    eirft = model.getCurveBiquadraticByName("#{dx_curves} Stage 1&2 EIRFT").get
    eirfff = model.getCurveQuadraticByName("#{dx_curves} Stage 1&2 EIRFFF").get
    plffplr = model.getCurveQuadraticByName("#{dx_curves} PLFFPLR").get
    coil_perf_dx_clg_1_2 = OpenStudio::Model::CoilPerformanceDXCooling.new(model,capft,capfff,eirft,eirfff,plffplr)
    coil_perf_dx_clg_1_2.setName("#{dx_curves} Stage 1&2")
    coil_perf_dx_clg_1_2.setGrossRatedSensibleHeatRatio(0.687)
    # todo - confirm what if any changes to stage one and what rated EIR impacts
    if dx_curves == "Lennox KCA120S4"
      coil_perf_dx_clg_1_2.setGrossRatedTotalCoolingCapacity(43081.4516999999)
      coil_perf_dx_clg_1_2.setGrossRatedCoolingCOP(3.3)
      coil_perf_dx_clg_1_2.setRatedAirFlowRate(2.12376349440001) # 4500 CFM
    else
      coil_perf_dx_clg_1_2.setGrossRatedTotalCoolingCapacity(43960.66)
      coil_perf_dx_clg_1_2.setGrossRatedCoolingCOP(2.97)
      coil_perf_dx_clg_1_2.setRatedAirFlowRate(2.36) # 5000 CFM
      #coil_perf_dx_clg_1_2.setFractionofAirFlowBypassedAroundCoil(0.1)
    end

    # altering coil performance vaules per original IDf to match
    # for all fields changed zero value means the latent degradation model is disabled
    # todo - when we calibrate against measured data may want to re-vsit what is used here.
    coil_perf_dx_clg_1.setNominalTimeforCondensateRemovaltoBegin(0) # EnergyPlus suggested value is 1000
    coil_perf_dx_clg_1.setRatioofInitialMoistureEvaporationRateandSteadyStateLatentCapacity (0) # EnergyPlus suggested value is 1.5
    coil_perf_dx_clg_1.setMaximumCyclingRate(0) # EnergyPlus suggested value is 3
    coil_perf_dx_clg_1.setLatentCapacityTimeConstant(0) # EnergyPlus suggested value is 45
    coil_perf_dx_clg_1_2.setNominalTimeforCondensateRemovaltoBegin(0) # EnergyPlus suggested value is 1000
    coil_perf_dx_clg_1_2.setRatioofInitialMoistureEvaporationRateandSteadyStateLatentCapacity (0) # EnergyPlus suggested value is 1.5
    coil_perf_dx_clg_1_2.setMaximumCyclingRate(0) # EnergyPlus suggested value is 3
    coil_perf_dx_clg_1_2.setLatentCapacityTimeConstant(0) # EnergyPlus suggested value is 45

    # add cooling coil
    clg_coil = OpenStudio::Model::CoilCoolingDXTwoStageWithHumidityControlMode.new(model)
    clg_coil.setName("RoofTop Cooling Coil")
    clg_coil.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
    clg_coil.setNumberofEnhancedDehumidificationModes(0)
    clg_coil.setNormalModeStage1CoilPerformance(coil_perf_dx_clg_1)
    clg_coil.setNormalModeStage1Plus2CoilPerformance(coil_perf_dx_clg_1_2)
    clg_coil.resetDehumidificationMode1Stage1CoilPerformance
    clg_coil.resetDehumidificationMode1Stage1Plus2CoilPerformance
    runner.registerInfo("Adding cooling coil named #{clg_coil.name.to_s}.")

=begin
    # add mixed air used as variable for EMS
    clg_coil_outlet_node = OpenStudio::Model::SetpointManagerMixedAir.new(model)
    clg_coil_outlet_node.setName("RoofTop Cooling Coil Air Temp Manager")
=end

    # add oa controller
    oa_controller = OpenStudio::Model::ControllerOutdoorAir.  new(model)
    oa_controller.setName("RoofTop OA Controller")
    oa_controller.setMinimumOutdoorAirFlowRate(0)
    oa_controller.setMaximumOutdoorAirFlowRate(0)
    oa_controller.setMinimumLimitType("ProportionalMinimum")

    # add oa system
    oa_system = OpenStudio::Model::AirLoopHVACOutdoorAirSystem.new(model,oa_controller)
    oa_system.setName("RooTop OA System")
    runner.registerInfo("Adding OA system named #{oa_system.name.to_s}.")

    # add the components to the air loop
    # in order from closest to zone to furthest from zone
    supply_inlet_node = air_loop.supplyInletNode
    supply_outlet_node = air_loop.supplyOutletNode
    fan.addToNode(supply_inlet_node)
    htg_coil.addToNode(supply_inlet_node)
    clg_coil.addToNode(supply_inlet_node)
    oa_system.addToNode(supply_inlet_node)
    runner.registerInfo("Adding components to air loop.")

    # rename nodes used for output variables
    fan_outlet_node = fan.outletModelObject.get
    fan_outlet_node.setName("RoofTop Supply Fan Outlet")
    htg_coil_outlet_object = htg_coil.outletModelObject.get
    htg_coil_outlet_object.setName("RoofTop Heating Coil Outlet")
    clg_coil_outlet_object = clg_coil.outletModelObject.get
    clg_coil_outlet_object.setName("RoofTop Cooling Coil Outlet")

=begin
    # add setpoint manager mixed air objects to loop, and set characteristics.
    htg_coil_outlet_node.addToNode(htg_coil.inletModelObject.get.to_Node.get)
    htg_coil_outlet_node.setReferenceSetpointNode(htg_coil_outlet_object.to_Node.get)
    #htg_coil_outlet_node.setString(6,fan_outlet_node.to_Node.get.name.to_s)
    # todo - setString(6,) on the mixed air setpoint managers results in extra unexpected mixed air objects in the resulting IDF file, but still only two in the OSM

    clg_coil_outlet_node.addToNode(clg_coil.inletModelObject.get.to_Node.get)
    clg_coil_outlet_node.setReferenceSetpointNode(clg_coil_outlet_object.to_Node.get)
    #clg_coil_outlet_node.setString(6,fan_outlet_node.to_Node.get.name.to_s)
    # todo - setString(6,) on the mixed air setpoint managers results in extra unexpected mixed air objects in the resulting IDF file, but still only two in the OSM
=end

    # rename oa outlet so matches variable
    oa_outlet_node = oa_system.mixedAirModelObject.get
    oa_outlet_node.setName("RoofTop Mixed Air Outlet")

    # gather unqiue zone HVAC equipment characteristics
    # todo - if plug loads are going to change from test to test, they could be added here as well
    zone_attributes = {}
    zone_attributes["Room 102"] = {
        :reheat_cap => 1000.00000121572,
        :max_air_flow => 0.132145284096,
        :min_air_flow => 9.43894886400002E-02,
        :sizing_clg_dsn_flow_rate => 0.132145284096,
        :sizing_htg_dsn_flow_rate => 5.66336931840001E-02,
        :oa_flow_rate => 2.69010042624001E-02,
        :exhaust_flow_rate => 0
    }
    zone_attributes["Room 103"] = {
        :reheat_cap => 1000.00000121572,
        :max_air_flow => 0.18877897728,
        :min_air_flow => 5.66336931840001E-02,
        :sizing_clg_dsn_flow_rate => 0.18877897728,
        :sizing_htg_dsn_flow_rate => 5.66336931840001E-02,
        :oa_flow_rate => 2.35973721600001E-02,
        :exhaust_flow_rate => 4.86105866496001E-02
    }
    zone_attributes["Room 104"] = {
        :reheat_cap => 4999.99999142503,
        :max_air_flow => 0.264290568192001,
        :min_air_flow => 0.174620553984,
        :sizing_clg_dsn_flow_rate => 0.264290568192001,
        :sizing_htg_dsn_flow_rate => 5.66336931840001E-02,
        :oa_flow_rate => 2.54851619328001E-02,
        :exhaust_flow_rate => 0
    }
    zone_attributes["Room 105"] = {
        :reheat_cap => 4999.99999142503,
        :max_air_flow => 0.283168465920001,
        :min_air_flow => 0.174620553984,
        :sizing_clg_dsn_flow_rate => 0.283168465920001,
        :sizing_htg_dsn_flow_rate => 0.174620553984,
        :oa_flow_rate => 3.25643735808001E-02,
        :exhaust_flow_rate => 0
    }
    zone_attributes["Room 106"] = {
        :reheat_cap => 4999.99999142503,
        :max_air_flow => 0.283168465920001,
        :min_air_flow => 0.174620553984,
        :sizing_clg_dsn_flow_rate => 0.283168465920001,
        :sizing_htg_dsn_flow_rate => 0.174620553984,
        :oa_flow_rate => 2.59571093760001E-02,
        :exhaust_flow_rate => 0
    }
    zone_attributes["Room 202"] = {
        :reheat_cap => 1999.99999950072,
        :max_air_flow => 0.212376349440001,
        :min_air_flow => 9.91089630720002E-02,
        :sizing_clg_dsn_flow_rate => 0.212376349440001,
        :sizing_htg_dsn_flow_rate => 9.91089630720002E-02,
        :oa_flow_rate => 0.0108547911936,
        :exhaust_flow_rate => 6.27690099456002E-02
    }
    zone_attributes["Room 203"] = {
        :reheat_cap => 1500.00000035822,
        :max_air_flow => 0.1179868608,
        :min_air_flow => 7.07921164800002E-02,
        :sizing_clg_dsn_flow_rate => 0.1179868608,
        :sizing_htg_dsn_flow_rate => 7.07921164800002E-02,
        :oa_flow_rate => 0.0108547911936,
        :exhaust_flow_rate => 0
    }
    zone_attributes["Room 204"] = {
        :reheat_cap => 4999.99999142503,
        :max_air_flow => 0.283168465920001,
        :min_air_flow => 0.174620553984,
        :sizing_clg_dsn_flow_rate => 0.283168465920001,
        :sizing_htg_dsn_flow_rate => 0.174620553984,
        :oa_flow_rate => 0.0136864758528,
        :exhaust_flow_rate => 0
    }
    zone_attributes["Room 205"] = {
        :reheat_cap => 4999.99999142503,
        :max_air_flow => 0.283168465920001,
        :min_air_flow => 0.174620553984,
        :sizing_clg_dsn_flow_rate => 0.297326889216001,
        :sizing_htg_dsn_flow_rate => 0.174620553984,
        :oa_flow_rate => 0.0127425809664,
        :exhaust_flow_rate => 0
    }
    zone_attributes["Room 206"] = {
        :reheat_cap => 4999.99999142503,
        :max_air_flow => 0.297326889216001,
        :min_air_flow => 0.174620553984,
        :sizing_clg_dsn_flow_rate => 0.297326889216001,
        :sizing_htg_dsn_flow_rate => 0.174620553984,
        :oa_flow_rate => 0.0127425809664,
        :exhaust_flow_rate => 0
    }

    # Make a VAV terminal with HW reheat for each zone on this story
    # and hook the reheat coil to the HW loop
    model.getThermalZones.sort.each do |zone|
      if zone.thermostatSetpointDualSetpoint.is_initialized

        # add reheat coil for terminal
        reheat_coil = OpenStudio::Model::CoilHeatingElectric.new(model,model.alwaysOnDiscreteSchedule)
        reheat_coil.setName("#{zone.name.get.to_s} Reheat Coil")
        reheat_coil.setEfficiency(1.0)
        reheat_coil.setNominalCapacity(zone_attributes[zone.name.get.to_s][:reheat_cap])

        # add terminal to zone
        vav_terminal = OpenStudio::Model::AirTerminalSingleDuctVAVReheat.new(model,model.alwaysOnDiscreteSchedule,reheat_coil)
        vav_terminal.setName("#{zone.name.get.to_s} VAV Reheat")
        vav_terminal.setMaximumAirFlowRate(zone_attributes[zone.name.get.to_s][:max_air_flow])
        vav_terminal.setZoneMinimumAirFlowMethod("FixedFlowRate")
        vav_terminal.	setFixedMinimumAirFlowRate(zone_attributes[zone.name.get.to_s][:min_air_flow])
        vav_terminal.setDamperHeatingAction("Reverse")

        # add zone to air_loop
        air_loop.addBranchForZone(zone,vav_terminal.to_StraightComponent)

        # rename terminal outlet node so it matches output variable names in model
        vav_terminal_outlet_node = vav_terminal.outletModelObject.get
        vav_terminal_outlet_node.setName("#{zone.name.to_s} Supply Inlet")

        # setup sizing_zone
        sizing_zone = zone.sizingZone
        sizing_zone.setZoneCoolingDesignSupplyAirTemperatureDifference(8.33333333333333)
        sizing_zone.setZoneHeatingDesignSupplyAirTemperatureDifference(30.0)
        sizing_zone.setCoolingDesignAirFlowRate(zone_attributes[zone.name.get.to_s][:sizing_clg_dsn_flow_rate])
        sizing_zone.setHeatingDesignAirFlowRate(zone_attributes[zone.name.get.to_s][:sizing_htg_dsn_flow_rate])
        sizing_zone.setZoneCoolingDesignSupplyAirHumidityRatio(0.008)

        # not currently using outdoor air.
=begin
        # add zone ventilation
        # todo - add in fresh air and exhaust (Can I use ZoneVentilationDesignFlowRate instead of ZoneHVACOutdoorAirUnit)
        zone_vent_fresh_air = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
        zone_vent_fresh_air.setName("#{zone.name.to_s} Fresh Air")
        zone_vent_fresh_air.addToThermalZone(zone)
        zone_vent_fresh_air.setVentilationType("Intake")
        zone_vent_fresh_air.setDesignFlowRateCalculationMethod("Flow/Zone")
        zone_vent_fresh_air.setDesignFlowRate(zone_attributes[zone.name.get.to_s][:oa_flow_rate])
        # todo - can't also set availability schedule like ZoneHVACOutdoorAirUnit, see if that is an issue, why is it always off
        zone_vent_fresh_air.setSchedule(model.getScheduleCompactByName("DOAS-Always 1").get)
        zone_vent_fresh_air.setFanTotalEfficiency(0.7)
        zone_vent_fresh_air.setFanPressureRise(298.906748567116)
        # if zone has exhaust then add a second zone ventilation design flow rate object
        if zone_attributes[zone.name.get.to_s][:exhaust_flow_rate] > 0
          zone_vent_exhaust = OpenStudio::Model::ZoneVentilationDesignFlowRate.new(model)
          zone_vent_exhaust.setName("#{zone.name.to_s} Exhaust")
          zone_vent_exhaust.addToThermalZone(zone)
          zone_vent_exhaust.setVentilationType("Exhaust")
          zone_vent_exhaust.setDesignFlowRateCalculationMethod("Flow/Zone")
          zone_vent_exhaust.setDesignFlowRate(zone_attributes[zone.name.get.to_s][:exhaust_flow_rate])
          # todo - can't also set availability schedule like ZoneHVACOutdoorAirUnit, see if that is an issue, why is it always off
          zone_vent_exhaust.setSchedule(model.getScheduleCompactByName("DOAS-Always 1").get)
          zone_vent_exhaust.setFanTotalEfficiency(0.7)
          zone_vent_exhaust.setFanPressureRise(298.906748567116)
          runner.registerInfo("Adding a VAV terminal, zone ventilation design flow rate for fresh air, zone ventilation design flow rate for exhaust, and setting zone sizing for #{zone.name.to_s}.")
        else
          runner.registerInfo("Adding a VAV terminal, zone ventilation design flow rate for fresh air, and setting zone sizing for #{zone.name.to_s}.")
        end
=end

      end
    end
    runner.registerInfo("Added #{air_loop.thermalZones.size} thermal zones to #{air_loop.name.to_s}.")

    # sort stories by nominalZCoordinate
    nom_z_vals = []
    model.getBuildingStorys.sort.each do |story|
      nom_z_vals << story.nominalZCoordinate.get
    end
    nom_z_vals = nom_z_vals.sort!

    # identify plenum zones
    first_story_plenum_zone = nil
    second_floor_plenum_zone = nil
    model.getBuildingStorys.sort.each do |story|
      if story.nominalZCoordinate.get == nom_z_vals[1]
        first_story_plenum_zone = story.spaces.first.thermalZone.get
      elsif story.nominalZCoordinate.get == nom_z_vals[3]
        second_floor_plenum_zone = story.spaces.first.thermalZone.get
      end
    end

    # assign plenums to zones
    model.getBuildingStorys.sort.each do |story|
      if story.nominalZCoordinate.get == nom_z_vals[0]
        story.spaces.each do |space|
          zone = space.thermalZone.get
          zone.setReturnPlenum(first_story_plenum_zone)
        end
      elsif story.nominalZCoordinate.get == nom_z_vals[2]
        story.spaces.each do |space|
          zone = space.thermalZone.get
          zone.setReturnPlenum(second_floor_plenum_zone)
        end
      end
    end

    # report plenums
    is_plenum = []
    unconditioned = []
    conditioned = []
    model.getThermalZones.each do |zone|
      if zone.isPlenum
        is_plenum << zone
      elsif ! zone.thermostatSetpointDualSetpoint.is_initialized
        unconditioned << zone
      else
        conditioned << zone
      end
    end
    runner.registerInfo("Added #{is_plenum.size} return air plenums to the model serving #{conditioned.size} zones. #{unconditioned.size} occupied zones don't have thermostats.")

    # output variables (many point to hvac objects from IDF file that may not have same name now)
    # renamed terminal output node to "#{zone.name.to_s} Supply Inlet"
    # renamed rooftop fan outlet node to "RoofTop Supply Fan Outlet"
    # renamed rooftop heating outlet node to "RoofTop Heating Coil Outlet"
    # added setpointManagerMixedAir between clg_coil and OA system named "RoofTop Mixed Air Outlet"
    # ignoring COOLING SUPPLY TEMPERATURE, EMS Output Variable
    # ignoring HEATING SUPPLY TEMPERATURE, EMS Output Variable

    #model.getOutputVariables.each do |output_var|
    #  puts output_var.keyValue
    #end

    # don't use setpointManagerScheduled when using EMS to MakeSetpoint
    if stp_mgr == "Scheduled"
      # using mixed air setpoint manager to control
      # Add a setpoint manager to control the
      # supply air to a constant temperature
      sat_c_clg = OpenStudio::convert(55,"F","C").get
      sat_c_htg = OpenStudio::convert(65,"F","C").get
      # todo - update schedule to use 65C for 6 months of the year
      sat_sch = OpenStudio::Model::ScheduleRuleset.new(model)
      sat_sch.setName("Supply Air Temp")
      sat_sch.defaultDaySchedule().setName("Supply Air Temp Default")
      sat_sch.defaultDaySchedule().addValue(OpenStudio::Time.new(0,24,0,0),sat_c_clg)
      sat_stpt_manager = OpenStudio::Model::SetpointManagerScheduled.new(model,sat_sch)
      sat_stpt_manager.addToNode(supply_outlet_node)
      runner.registerInfo("Adding scheduled setpoint manager (remove this when EMS is enabled).")

      # removing all EMS
      model.getEnergyManagementSystemPrograms.each { |i| i.remove }
      model.getEnergyManagementSystemProgramCallingManagers.each { |i| i.remove }
      model.getEnergyManagementSystemOutputVariables.each { |i| i.remove }
      model.getEnergyManagementSystemGlobalVariables.each { |i| i.remove } # all DOAS so remove all
      model.getEnergyManagementSystemSensors.each { |i| i.remove }
      model.getEnergyManagementSystemActuators.each { |i| i.remove }

    else

      # >> add in missing EMS information
      # add EMS variable name to OS:EnergyManagementSystem:OutputVariable)
      model.getEnergyManagementSystemOutputVariables.each do |ems_var|

        if ems_var.name.to_s == 'Heating Supply Temperature'

          # create OS:EnergyManagementSystem:Actuator.
          ems_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(htg_coil_outlet_object,"System Node Setpoint","Temperature Setpoint")
          ems_actuator.setName("HeatingSupplyT")

          # assign ems_var
          ems_var.setEMSVariableName(ems_actuator.name.to_s)

        elsif ems_var.name.to_s == 'Cooling Supply Temperature'
          # add and assign OS:EnergyManagementSystem:Actuator

          # create OS:EnergyManagementSystem:Actuator
          ems_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(clg_coil_outlet_object,"System Node Setpoint","Temperature Setpoint")
          ems_actuator.setName("CoolingSupplyT")

          # assign ems_var
          ems_var.setEMSVariableName(ems_actuator.name.to_s)

        else
          # do nothing (DOAS Schedule Value object didn't loose its EMS Variable name value on import)
        end

      end

      # customize setpoint manager range for MakeSetpoint EMS
      oa = "{fbe21d25-aadc-4a30-b679-0a6007048d7b}"
      formula_between_floor_ceiling = "#{setpoint_temp_floor} + ((#{setpoint_temp_ceiling - setpoint_temp_floor}) * (#{oa_threshold_for_setpoint_floor} - #{oa})/(#{oa_threshold_for_setpoint_floor - oa_threshold_for_setpoint_ceiling}))"
      model.getEnergyManagementSystemPrograms.each do |program|
        next if not program.name.to_s.include? "MakeSetpoint"

        # clear out existing code
        program.resetBody

        # add new lines
        program.addLine("IF #{oa} >= #{oa_threshold_for_setpoint_floor}")
        program.addLine("SET CoolingSupplyT = #{setpoint_temp_floor}")
        program.addLine("SET HeatingSupplyT = #{setpoint_temp_floor}")
        program.addLine("ELSEIF #{oa} <= #{oa_threshold_for_setpoint_ceiling}")
        program.addLine("SET CoolingSupplyT = #{setpoint_temp_ceiling}")
        program.addLine("SET HeatingSupplyT = #{setpoint_temp_ceiling}")
        program.addLine("ELSE")
        program.addLine("SET CoolingSupplyT = #{formula_between_floor_ceiling}")
        program.addLine("SET HeatingSupplyT = #{formula_between_floor_ceiling}")
        program.addLine("ENDIF")

        # log for user
        runner.registerInfo("Updating logic for #{program.name} EMS program based on user inputs.")

      end

      # removing EMS related to DOAS but leaving EMS related to setpoint manager
      model.getEnergyManagementSystemPrograms.each { |i| if i.name.to_s.include?("DOAS") then i.remove end }
      model.getEnergyManagementSystemProgramCallingManagers.each { |i| if i.name.to_s.include?("DOAS") then i.remove end }
      model.getEnergyManagementSystemOutputVariables.each { |i| if i.name.to_s.include?("DOAS") then i.remove end }
      model.getEnergyManagementSystemGlobalVariables.each { |i| i.remove } # all DOAS so remove all
      model.getEnergyManagementSystemSensors.each { |i| if i.name.to_s.include?("DOAS") then i.remove end }
      model.getEnergyManagementSystemActuators.each { |i| if i.name.to_s.include?("DOAS") then i.remove end }

    end

    # set Site:GroundReflectance
    ground_reflectance = model.getSiteGroundReflectance
    ground_reflectance.setJanuaryGroundReflectance(0.29)
    ground_reflectance.setFebruaryGroundReflectance(0.29)
    ground_reflectance.setMarchGroundReflectance(0.29)
    ground_reflectance.setAprilGroundReflectance(0.29)
    ground_reflectance.setMayGroundReflectance(0.29)
    ground_reflectance.setJuneGroundReflectance(0.29)
    ground_reflectance.setJulyGroundReflectance(0.29)
    ground_reflectance.setAugustGroundReflectance(0.29)
    ground_reflectance.setSeptemberGroundReflectance(0.29)
    ground_reflectance.setOctoberGroundReflectance(0.29)
    ground_reflectance.setNovemberGroundReflectance(0.29)
    ground_reflectance.setDecemberGroundReflectance(0.29)
    runner.registerInfo("Setting Ground Reflectance.")

    # set Site:GroundTemperature:BuildingSurface
    ground_temps = model.getSiteGroundTemperatureBuildingSurface
    ground_temps.setJanuaryGroundTemperature(19.939)
    ground_temps.setFebruaryGroundTemperature(19.907)
    ground_temps.setMarchGroundTemperature(19.925)
    ground_temps.setAprilGroundTemperature(20.167)
    ground_temps.setMayGroundTemperature(21.424)
    ground_temps.setJuneGroundTemperature(22.505)
    ground_temps.setJulyGroundTemperature(22.726)
    ground_temps.setAugustGroundTemperature(22.815)
    ground_temps.setSeptemberGroundTemperature(22.805)
    ground_temps.setOctoberGroundTemperature(20.837)
    ground_temps.setNovemberGroundTemperature(20.22)
    ground_temps.setDecemberGroundTemperature(20.048)
    runner.registerInfo("Setting Ground Temperatures.")

    # set Site:WaterMainsTemperature
    water_main_temps = model.getSiteWaterMainsTemperature
    water_main_temps.setAnnualAverageOutdoorAirTemperature(14.55)
    water_main_temps.setMaximumDifferenceInMonthlyAverageOutdoorAirTemperatures(22)
    runner.registerInfo("Setting Water Main Temperatures.")

    # set sizing parameters
    sizing_params = model.getSizingParameters
    sizing_params.setHeatingSizingFactor(1.0)
    sizing_params.setCoolingSizingFactor(1.0)
    runner.registerInfo("Setting Sizing Parameters to 1.0 for heating and cooling")

    # set runperiod
    run_period = model.getRunPeriod
    run_period.setBeginMonth(1)
    run_period.setBeginDayOfMonth (1)
    run_period.setEndMonth(12)
    run_period.setEndDayOfMonth (31)
    runner.registerInfo("Setting Simulation Run Period from 1/1 through 12/31.")

    # enable daylight savings
    if dst
      model.getRunPeriodControlDaylightSavingTime
    end

    # alter internal mass using user arguments
    model.getBuildingStorys.sort.each do |story|

      # identify internal mass objects
      int_mass_thin = []
      int_mass_thick = []
      story.spaces.each do |space|
        space.internalMass.each do |mass|
          if mass.internalMassDefinition.name.get.to_s.include?("Thin")
            int_mass_thin << mass
          elsif mass.internalMassDefinition.name.get.to_s.include?("Thick")
            int_mass_thick << mass
          else
            # don't change anything on 200 gallon water storage tank mass
          end
        end
      end

      thin_mult = nil
      thick_mult = nil
      runner.registerInfo("Setting typcial internal mass for #{story.name}")
      if story.name.get.to_s.include?("Building Story 1")
        thin_mult = int_mass_first_thin_area
        thick_mult = int_mass_first_thick_area
      elsif story.name.get.to_s.include?("Building Story 3")
        thin_mult = int_mass_second_thin_area
        thick_mult = int_mass_second_thick_area
      else
        # apply plenum logic
        thin_mult = int_mass_plenum_thin_area
        thick_mult = int_mass_plenum_thick_area
      end

      # alter internal mass
      int_mass_thin.each do |mass|
        mass.setMultiplier(thin_mult)
      end
      int_mass_thick.each do |mass|
        mass.setMultiplier(thick_mult)
      end

    end

    # alter mass for specific spaces
    model.getSpaces.sort.each do |space|

      # identify internal mass objects
      int_mass_thin = nil
      int_mass_thick = nil
      water_tank = nil
      space.internalMass.each do |mass|
        if mass.internalMassDefinition.name.get.to_s.include?("Thin")
          int_mass_thin = mass
        elsif mass.internalMassDefinition.name.get.to_s.include?("Thick")
          int_mass_thick = mass
        else
          water_tank = mass
        end
      end

      if space.name.get.to_s.include?("Room 101") || space.name.get.to_s.include?("Room 201")
        runner.registerInfo("Setting custom internal mass for #{space.name}")
        int_mass_thin.setMultiplier(int_mass_stair_thin_area)
        int_mass_thick.setMultiplier(int_mass_stair_thick_area)
      elsif space.name.get.to_s.include?("Room 105")
        runner.registerInfo("Setting custom internal mass for #{space.name}")
        int_mass_thin.setMultiplier(int_mass_room_105_thin_area)
        int_mass_thick.setMultiplier(int_mass_room_105_thick_area)

        # remove water tanks if requested
        if not add_water_tanks
          water_tank.remove
          runner.registerInfo("Removed internal mass from Room 105for 4 x 200 gallon water starage tanks")
        else
          runner.registerInfo("Room 105 includes internal mass for 4 x 200 gallon water starage tanks")
        end

      elsif space.name.get.to_s.include?("Room 106")
        runner.registerInfo("Setting custom internal mass for #{space.name}")
        int_mass_thin.setMultiplier(int_mass_room_106_thin_area)
        int_mass_thick.setMultiplier(int_mass_room_106_thick_area)
      end
    end

    # clean up any internal mass with multiplier of 0
    model.getInternalMasss.each do |mass|
      if mass.multiplier == 0.0
        mass.remove
      else
        # use global internal mass variable to change multiplier
        mass.setMultiplier(mass.multiplier * int_mass_multiplier)
      end
    end

    # alter envlope construction characteristics
    double_pane_mat = model.getSimpleGlazingByName('Double Pane').get
    double_pane_mat.setSolarHeatGainCoefficient(double_pane_mat.solarHeatGainCoefficient * shgc_multiplier)
    double_pane_mat.setUFactor(double_pane_mat.uFactor * ufactor_multiplier)

    # note: heating equipment and controls for stair zones is modeled as plug loads for spaces 101 and 201
    # note: don't need to set ZoneAirHeatBalanceAlgorithm to ThirdOrderBackwardDifference, that is E+ default
    # note: SurfaceConvectionAlgorithm:Inside is CeilingDiffuser in orig IDF, while default used in OSM generated IDF is TARP, changed IDF for now for better comparison.

    # todo - model people
    # people are currently modeled as other equipment, but may also be included in electric equipment, although isn't clear how this is done without over-calculationg electric equipment electrical consumption.
    # one option is to model people without any internal gains and leave existing objects alone
    # another option is to remove other equipment and make any necessary adjustments to electrical equipment, and then add in people with internal gains.

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.objects.size} objects.")

    return true

  end
  
end

# register the measure to be used by the application
OrnlTwoStoryFrpModel.new.registerWithApplication
