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

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # report initial condition of model
    runner.registerInitialCondition("The building started with #{model.objects.size} objects.")

    # >> replace model in with model from resources folder
    base_model_path = "#{File.dirname(__FILE__)}/resources/FRP2_raw_import.osm"
    translator = OpenStudio::OSVersion::VersionTranslator.new
    oModel = translator.loadModel(base_model_path)
    if oModel.empty?
      runner.registerError("Could not load base model model from '" + alternativeModelPath.to_s + "'.")
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
    runner.registerInfo("#{base_model_path} was imported with #{model.objects.size} objects")

    # update attributes that didn't import in
    year_desc = model.getYearDescription
    year_desc.setCalendarYear(2017)

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


    # todo - fix surface matching until source IDF and OSM are updated


    # todo - fix exterior constructions until source IDF and OSM are updated


    # >> convert all schedules to ScheduleRulesets (This will support fault measures that alter schedules)
    new_schedules = []
    model.getScheduleCompacts.each do |compact|
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

    # >> add HVAC

    # add in air loops
    air_loop = OpenStudio::Model::AirLoopHVAC.new(model)
    air_loop.setName('RoofTop')

    # populate air loop with zones
    model.getThermalZones.each do |zone|

      # clean up zone name so it matches what it was in IDF
      zone.setName("#{zone.name.get.gsub(' Thermal Zone','')}")

      # add zone to air loop
      if zone.thermostatSetpointDualSetpoint.is_initialized
        air_loop.addBranchForZone(zone)
      end
    end
    runner.registerInfo("Added airloop named #{air_loop.name} with #{air_loop.thermalZones.size} thermal zones.")

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
    has_return_plenum = []
    unconditioned = []
    model.getThermalZones.each do |zone|
      if zone.isPlenum
        is_plenum << zone
      elsif ! zone.thermostatSetpointDualSetpoint.is_initialized
        unconditioned << zone
      end
    end
    runner.registerInfo("Added #{is_plenum.size} return air plenums to the model serving ??? zones. #{unconditioned.size} occupied zones don't have thermostats.")


    # todo - populate air loop supply side


    # todo - add in zone equipment


    # todo - need to make sure all curves and performance data match source IDF


    # todo >> fix variables (many point to hvac objects from IDF file that may not have same name now)
    model.getOutputVariables.each do |output_var|
      #puts output_var.keyValue
    end


    # todo >> add in missing EMS information

    # add EMS variable name to OS:EnergyManagementSystem:OutputVariable)
    model.getEnergyManagementSystemOutputVariables.each do |ems_var|

=begin
      if ems_var.name.to_s == 'Heating Supply Temperature'

        # create OS:EnergyManagementSystem:Actuator.
        ems_var_obj = nil
        ems_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(ems_var_obj,"System Node Setpoint","Temperature Setpoint")
        ems_actuator.setName("HeatingSupplyT")

        # assign ems_var
        ems_var.setEMSVariableName(ems_actuator.handle)

      elsif ems_var.name.to_s == 'Cooling Supply Temperature'
        # add and assign OS:EnergyManagementSystem:Actuator

        # create OS:EnergyManagementSystem:Actuator
        ems_var_obj = nil
        ems_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(ems_var_obj,"System Node Setpoint","Temperature Setpoint")
        ems_actuator.setName("CoolingSupplyT")

        # assign ems_var
        ems_var.setEMSVariableName(ems_actuator.handle)

      else
        # do nothing (DOAS Schedule Value object didn't loose its EMS Variable name value on import)
      end
=end

      puts ems_var

    end

    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.objects.size} objects.")

    return true

  end
  
end

# register the measure to be used by the application
OrnlTwoStoryFrpModel.new.registerWithApplication
