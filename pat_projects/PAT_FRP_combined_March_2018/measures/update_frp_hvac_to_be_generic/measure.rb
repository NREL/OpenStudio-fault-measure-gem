# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class FrpUpdateHvacToBeGeneric < OpenStudio::Measure::ModelMeasure

  # require all .rb files in resources folder
  Dir[File.dirname(__FILE__) + '/resources/*.rb'].each {|file| require file }

  # resource file modules
  include OsLib_Schedules

  # human readable name
  def name
    return "FRP Update HVAC to be Generic"
  end

  # human readable description
  def description
    return "This will add OA, update infiltration schedule, enable furnace, update thermostat, and make changes to terminals. It may also autosize some or all elements"
  end

  # human readable description of modeling approach
  def modeler_description
    return "User arguments will control how much is changed. For example if weather file isn't changed, then maybe everything doesn't need to be autosized. May also have to adjust deck temperature control strategy. Add space types, construction sets to the model prior to running this measure, and also delete space loads."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # create bools arguments
    bool_args.each do |k,v|
      # bool
      bool_arg = OpenStudio::Measure::OSArgument.makeBoolArgument(k, true)
      bool_arg.setDisplayName(v)
      bool_arg.setDefaultValue(true)
      args << bool_arg
    end

    return args
  end

  # bool args
  def bool_args()

    bool_arg_hash = {}
    bool_arg_hash["enable_rtu_oa"] = "Enabling outdoor air for the RTU"
    bool_arg_hash["enable_rtu_econo"] = "Enabling economizer for the RTU"
    bool_arg_hash["enable_furnace"] = "Enable RTU furnace"

    # availability, thermostats setbacks, and infiltration schedules should all be in sync
    bool_arg_hash["update_availability"] = "Update Availability schedules to reflect typical office"
    bool_arg_hash["update_infil_sch"] = "Update Infiltration schedule to relflect daytime positive pressure"
    bool_arg_hash["update_thermostats"] = "Update Thermostat schedules to reflect typical office"

    # used for sweeping across climate zones
    bool_arg_hash["autosize_rtu"] = "Autosize RTU components"
    bool_arg_hash["autosize_terminals"] = "Autosize Terminal components"
    bool_arg_hash["autosize_airloop"] = "Autosize other Air Loop components"

    #stair and plenum should follow infiltration schedule for primary building type
    bool_arg_hash["setup_non_default_space_types"] = "Remove hard assigned space loads"

    return bool_arg_hash
  end

  # bool args (not using as argument but will pull in for generating schedules based on hours of operation)
  def double_args()

    double_arg_hash = {}

    # hour of operation inputs
    double_arg_hash["weekday_hoo_start"] = {:display =>"Weekday Hours of Operation Start", :units => nil, :default => 6}
    double_arg_hash["weekday_hoo_end"] = {:display =>"Weekday Hours of Operation End", :units => nil, :default => 22}
    double_arg_hash["sat_hoo_start"] = {:display =>"Saturday Hours of Operation Start", :units => nil, :default => 6}
    double_arg_hash["sat_hoo_end"] = {:display =>"Saturday Hours of Operation End", :units => nil, :default => 17}
    double_arg_hash["sun_hoo_start"] = {:display =>"Sunday Hours of Operation Start", :units => nil, :default => 0}
    double_arg_hash["sun_hoo_end"] = {:display =>"Sunday Hours of Operation End", :units => nil, :default => 0}

    # thermostat inputs
    double_arg_hash["htg_occ"] = {:display =>"Heating Occupied Setpoint", :units => "C", :default => 21}
    double_arg_hash["htg_unocc"] = {:display =>"Heating Unoccupied Setpoint", :units => "C", :default => 15.6}
    double_arg_hash["clg_occ"] = {:display =>"Cooling Occupied Setpoint", :units => "C", :default => 24}
    double_arg_hash["clg_unocc"] = {:display =>"Cooling Unoccupied Setpoint", :units => "C", :default => 26.7}

    # infiltration fraction durring HVAC operation
    double_arg_hash["infil"] = {:display =>"Infiltration Fraction Durring HVAC Operation", :units => nil, :default => 0.25}

    return double_arg_hash
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    args = {}
    bool_args.each do |k,v|
      args[k] = {:value => runner.getBoolArgumentValue(k, user_arguments),:display => v}
    end

    # add double args to args hash, even though they are not currently exposed as user arguments
    double_args.each do |k,v|
      args[k] = v # hash with :display, :units, and :default as keys
    end
    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.objects.size} objects.")

    if args["enable_rtu_oa"][:value] == true
      runner.registerInfo(args["enable_rtu_oa"][:display])
      oa = model.getControllerOutdoorAirs
      if oa.size > 1
        runner.registerWarning("Found more than one ControllerOutdoorAir object, altering #{oa.first.name}")
      end
      oa = oa.first
      oa.autosizeMinimumOutdoorAirFlowRate
      oa.autosizeMaximumOutdoorAirFlowRate
      runner.registerInfo(" - autosizing min and max air flow rate for controller outdoor air.")
    end


    if args["enable_rtu_econo"][:value] == true
      runner.registerInfo(args["enable_rtu_econo"][:display])
      oa = model.getControllerOutdoorAirs
      if oa.size > 1
        runner.registerWarning("Found more than one ControllerOutdoorAir object, altering #{oa.first.name}")
      end
      oa = oa.first
      oa.setEconomizerControlType("FixedDryBulb")
      runner.registerInfo(" - Setting economizer control type to FixedDryBulb.")
    end

    if args["enable_furnace"][:value]
      runner.registerInfo(args["enable_furnace"][:display])
      htg_coil = model.getCoilHeatingGass
      if htg_coil.size > 1
        runner.registerWarning("Found more than one CoilHeatingGas object, altering #{htg_coil.first.name}")
      end
      htg_coil = htg_coil.first
      orig_sch = htg_coil.availabilitySchedule.name
      htg_coil.setAvailabilitySchedule(model.alwaysOnDiscreteSchedule)
      runner.registerInfo(" - Changing gas heating coil availability schedule from #{orig_sch} to #{htg_coil.availabilitySchedule.name}.")
    end

    # todo - enable night cycle operation?
    if args["update_availability"][:value]
      runner.registerInfo(args["update_availability"][:display])
      ruleset_name = "HVAC Availability Schedule"
      winter_design_day = nil
      summer_design_day = nil
      default_day = ["Weekday",[args["weekday_hoo_start"][:default],0],[args["weekday_hoo_end"][:default],1],[24,0]]
      rules = []
      rules << ["Saturday","1/1-12/31","Sat",[args["sat_hoo_start"][:default],0],[args["sat_hoo_end"][:default],1],[24,0]]
      rules << ["Sunday","1/1-12/31","Sun",[args["sun_hoo_start"][:default],0],[args["sun_hoo_end"][:default],1],[24,0]]
      options = {"name" => ruleset_name,
                 "winter_design_day" => winter_design_day,
                 "summer_design_day" => summer_design_day,
                 "default_day" => default_day,
                 "rules" => rules}
      avail_sch = OsLib_Schedules.createComplexSchedule(model, options)
      air_loop = model.getAirLoopHVACs
      if air_loop.size > 1
        runner.registerWarning("Found more than one AirLoopHVAC object, altering #{air_loop.first.name}")
      end
      air_loop = air_loop.first
      air_loop.setAvailabilitySchedule(avail_sch)
      runner.registerInfo(" - Setting availability schedule for #{air_loop.name} to #{avail_sch.name}")
      times = []
      avail_sch.defaultDaySchedule.times.each_with_index do |time,i|
        times << "[#{time.hours},#{avail_sch.defaultDaySchedule.values[i]}]"
      end
      runner.registerInfo(" - Times and values for #{avail_sch.name} default profile are #{times.join(",")}")
    end

    if args["update_infil_sch"][:value]
      runner.registerInfo(args["update_infil_sch"][:display])
      ruleset_name = "Infiltration Schedule"
      winter_design_day = nil
      summer_design_day = nil
      default_day = ["Weekday",[args["weekday_hoo_start"][:default],1],[args["weekday_hoo_end"][:default],args["infil"][:default]],[24,1]]
      rules = []
      rules << ["Saturday","1/1-12/31","Sat",[args["sat_hoo_start"][:default],1],[args["sat_hoo_end"][:default],args["infil"][:default]],[24,1]]
      rules << ["Sunday","1/1-12/31","Sun",[args["sun_hoo_start"][:default],1],[args["sun_hoo_end"][:default],args["infil"][:default]],[24,1]]
      options = {"name" => ruleset_name,
                 "winter_design_day" => winter_design_day,
                 "summer_design_day" => summer_design_day,
                 "default_day" => default_day,
                 "rules" => rules}
      infil_sch = OsLib_Schedules.createComplexSchedule(model, options)
      infils = model.getSpaceInfiltrationDesignFlowRates
      infils.each do |infil|
        infil.setSchedule(infil_sch)
      end
      runner.registerInfo(" - Setting infiltration schedule for #{infils.size} SpaceInfiltrationDesignFlowRate objects.")
      times = []
      infil_sch.defaultDaySchedule.times.each_with_index do |time,i|
        times << "[#{time.hours},#{infil_sch.defaultDaySchedule.values[i]}]"
      end
      runner.registerInfo(" - Times and values for #{infil_sch.name} default profile are #{times.join(",")}")
    end

    if args["update_thermostats"][:value]
      runner.registerInfo(args["update_thermostats"][:display])

      ruleset_name = "Htg Setpoint Schedule"
      winter_design_day = nil
      summer_design_day = nil
      default_day = ["Weekday",[args["weekday_hoo_start"][:default],args["htg_unocc"][:default]],[args["weekday_hoo_end"][:default],args["htg_occ"][:default]],[24,args["htg_unocc"][:default]]]
      rules = []
      rules << ["Saturday","1/1-12/31","Sat",[args["sat_hoo_start"][:default],args["htg_unocc"][:default]],[args["sat_hoo_end"][:default],args["htg_occ"][:default]],[24,args["htg_unocc"][:default]]]
      rules << ["Sunday","1/1-12/31","Sun",[args["sun_hoo_start"][:default],args["htg_unocc"][:default]],[args["sun_hoo_end"][:default],args["htg_occ"][:default]],[24,args["htg_unocc"][:default]]]
      options = {"name" => ruleset_name,
                 "winter_design_day" => winter_design_day,
                 "summer_design_day" => summer_design_day,
                 "default_day" => default_day,
                 "rules" => rules}
      htg_sch = OsLib_Schedules.createComplexSchedule(model, options)
      thermostats = model.getThermostatSetpointDualSetpoints
      thermostats.each do |thermostat|
        thermostat.setHeatingSetpointTemperatureSchedule(htg_sch)
      end
      runner.registerInfo(" - Setting heating setopint schedule for #{thermostats.size} ThermostatSetpointDualSetpoint objects.")
      times = []
      htg_sch.defaultDaySchedule.times.each_with_index do |time,i|
        times << "[#{time.hours},#{htg_sch.defaultDaySchedule.values[i]}]"
      end
      runner.registerInfo(" - Times and values for #{htg_sch.name} default profile are #{times.join(",")}")

      ruleset_name = "Clg Setpoint Schedule"
      winter_design_day = nil
      summer_design_day = nil
      default_day = ["Weekday",[args["weekday_hoo_start"][:default],args["clg_unocc"][:default]],[args["weekday_hoo_end"][:default],args["clg_occ"][:default]],[24,args["clg_unocc"][:default]]]
      rules = []
      rules << ["Saturday","1/1-12/31","Sat",[args["sat_hoo_start"][:default],args["clg_unocc"][:default]],[args["sat_hoo_end"][:default],args["clg_occ"][:default]],[24,args["clg_unocc"][:default]]]
      rules << ["Sunday","1/1-12/31","Sun",[args["sun_hoo_start"][:default],args["clg_unocc"][:default]],[args["sun_hoo_end"][:default],args["clg_occ"][:default]],[24,args["clg_unocc"][:default]]]
      options = {"name" => ruleset_name,
                 "winter_design_day" => winter_design_day,
                 "summer_design_day" => summer_design_day,
                 "default_day" => default_day,
                 "rules" => rules}
      clg_sch = OsLib_Schedules.createComplexSchedule(model, options)
      thermostats = model.getThermostatSetpointDualSetpoints
      thermostats.sort.each do |thermostat|
        thermostat.setCoolingSetpointTemperatureSchedule(clg_sch)
      end
      runner.registerInfo(" - Setting cooling setopint schedule for #{thermostats.size} ThermostatSetpointDualSetpoint objects.")
      times = []
      clg_sch.defaultDaySchedule.times.each_with_index do |time,i|
        times << "[#{time.hours},#{clg_sch.defaultDaySchedule.values[i]}]"
      end
      runner.registerInfo(" - Times and values for #{clg_sch.name} default profile are #{times.join(",")}")

    end

    if args["autosize_rtu"][:value]
      runner.registerInfo(args["autosize_rtu"][:display])

      # cooling coil
      objs = model.getCoilPerformanceDXCoolings
      objs.sort.each do |obj|
        # todo - stop unless object is associated with a coil used on an air loop
        obj.autosizeGrossRatedTotalCoolingCapacity
        obj.autosizeGrossRatedSensibleHeatRatio
        obj.autosizeRatedAirFlowRate
        # two below are not necessary since this is air cooled
        #obj.autosizeEvaporativeCondenserAirFlowRate
        #obj.autosizeEvaporativeCondenserPumpRatedPowerConsumption
        runner.registerInfo(" - Autosized values for #{obj.name}")
      end

      # heating coil
      obj = model.getCoilHeatingGass
      if obj.size > 1
        runner.registerWarning("Found more than one CoilHeatingGas object, altering #{obj.first.name}")
      end
      obj = obj.first
      obj.autosizeNominalCapacity
      runner.registerInfo(" - Autosized values for #{obj.name}")

      # fan
      obj = model.getFanVariableVolumes
      if obj.size > 1
        runner.registerWarning("Found more than one FanVariableVolume object, altering #{obj.first.name}")
      end
      obj = obj.first
      obj.autosizeMaximumFlowRate
      runner.registerInfo(" - Autosized values for #{obj.name}")

      # oa is autosized by this measure when enable_rtu_oa is true
    end

    if args["autosize_terminals"][:value]
      runner.registerInfo(args["autosize_terminals"][:display])

      # terminal
      objs = model.getAirTerminalSingleDuctVAVReheats
      objs.sort.each do |obj|
        obj.autosizeMaximumAirFlowRate
        obj.autosizeMaximumFlowFractionDuringReheat
        obj.autosizeMaximumFlowPerZoneFloorAreaDuringReheat
        runner.registerInfo(" - Autosized values for #{obj.name}")
      end

      # electric heating coil
      objs = model.getCoilHeatingElectrics
      objs.sort.each do |obj|
        obj.autosizeNominalCapacity
        runner.registerInfo(" - Autosized values for #{obj.name}")
      end
    end

    if args["autosize_airloop"][:value]
      runner.registerInfo(args["autosize_airloop"][:display])

      # air_loop_hvac
      obj = model.getAirLoopHVACs
      if obj.size > 1
        runner.registerWarning("Found more than one AirLoopHVAC object, altering #{obj.first.name}")
      end
      obj = obj.first
      obj.autosizeDesignSupplyAirFlowRate
      runner.registerInfo(" - Autosized values for #{obj.name}")

      # sizing system
      obj = model.getSizingSystems
      if obj.size > 1
        runner.registerWarning("Found more than one SizingSystem object, altering #{obj.first.name}")
      end
      obj = obj.first
      obj.autosizeDesignOutdoorAirFlowRate

      # these are already autosized
      #obj.autosizeCoolingDesignCapacity
      #obj.autosizeHeatingDesignCapacity
      runner.registerInfo(" - Autosized values for SizingSystem object for #{obj.airLoopHVAC.name}")

    end

    if args["setup_non_default_space_types"][:value]
      runner.registerInfo(args["setup_non_default_space_types"][:display]) #, and assign stair and plenum space types. Primary space type should already be assigned.

      # remove all space type assignments
      model.getSpaces.each do |space|
        space.resetSpaceType
      end
      runner.registerInfo(" - removing initial space type assignments")

      # setup stair
      stair_space_type = nil
      model.getSpaceTypes.sort.each do |space_type|
        if space_type.standardsSpaceType.is_initialized and space_type.standardsSpaceType.get == "Stair"
          stair_space_type = space_type
        end
      end
      if stair_space_type.nil?
        runner.registerWarning("Didn't find a Stair space type in the model")
      else
        stairs = ["Room 101","Room 201"]
        model.getSpaces.sort.each do |space|
          next if not stairs.include?(space.name.get.to_s)
          space.setSpaceType(stair_space_type)
          runner.registerInfo(" - Assigning #{stair_space_type.name} space type to #{space.name}")
        end
      end

      # setup plenum
      plenum_space_type = OpenStudio::Model::SpaceType.new(model)
      plenum_space_type.setName("FRP Plenum")
      if model.getBuilding.spaceType.is_initialized
        default_space_type = model.getBuilding.spaceType.get
        if default_space_type.spaceInfiltrationDesignFlowRates.size > 0
          new_infil = default_space_type.spaceInfiltrationDesignFlowRates.first.clone(model)
          new_infil.setName("Plenum Infiltration")
          new_infil = new_infil.to_SpaceInfiltrationDesignFlowRate.get
          new_infil.setSpaceType(plenum_space_type)
        else
          runner.regisgerWarning("#{plenum_space_type.name} doesn't have spaceInfiltrationDesignFlowRate objecs assigned")
        end

        # update design spec OA to use always on schedule
        if default_space_type.designSpecificationOutdoorAir.is_initialized
          oa = default_space_type.designSpecificationOutdoorAir.get
          oa.setOutdoorAirFlowRateFractionSchedule(model.alwaysOnDiscreteSchedule)
          runner.registerInfo(" - adding always on schedule to #{oa.name} to support downstream measures that expect this")
        end

        else
        runner.registerWarning("Not adding infiltration to #{plenum_space_type.name} because building doesn't have default space type assigned.")
        runner.registerWarning("Not adding schedule to design specification OA for default space type, since the building does not have a default space type assigned.")
      end
      model.getSpaces.each do |space|
        if space.isPlenum
          space.setSpaceType(plenum_space_type)
          runner.registerInfo(" - Assigning #{plenum_space_type.name} space type to #{space.name}")
        end

      end

    end

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.objects.size} objects.")

    # note: constructions should be assigned by space type and construction set wizard

    return true

  end
  
end

# register the measure to be used by the application
FrpUpdateHvacToBeGeneric.new.registerWithApplication
