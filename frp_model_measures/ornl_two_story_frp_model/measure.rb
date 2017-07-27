# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

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
    runner.registerInfo("The building has #{model.getBuildingStorys.size} stories.")


    # todo - fix surface matching until soruce IDF and OSM are updated


    # todo - fix exterior constructions until soruce IDF and OSM are updated


    # todo - add in missing EMS information


    # todo - convert all schedules to ScheduleRulesets (This will support fault measures that alter schedules)


    # todo - Add in air loops


    # todo - setup return air plenums


    # todo - add in zone equipment


    # report final condition of model
    runner.registerFinalCondition("The building finished with #{model.objects.size} objects.")

    return true

  end
  
end

# register the measure to be used by the application
OrnlTwoStoryFrpModel.new.registerWithApplication
