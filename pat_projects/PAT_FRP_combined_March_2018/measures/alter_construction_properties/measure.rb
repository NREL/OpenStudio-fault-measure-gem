# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class AlterConstructionProperties < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "Alter Construction Properties"
  end

  # human readable description
  def description
    return "This measure will allow you to alter the r value and mass of existing opaque layered constructions in your model"
  end

  # human readable description of modeling approach
  def modeler_description
    return "The thicknes of the least conductive material will be increased to increase r value. The thickness of the most dense material will be increased to increase the mass of the wall. Warning should be issued if materials with reasonable properties to cahnge can't be found. "
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    #populate choice argument for constructions that are applied to surfaces in the model
    construction_handles = OpenStudio::StringVector.new
    construction_display_names = OpenStudio::StringVector.new

    #putting space types and names into hash
    construction_args = model.getConstructions
    construction_args_hash = {}
    construction_args.each do |construction_arg|
      construction_args_hash[construction_arg.name.to_s] = construction_arg
    end

    #looping through sorted hash of constructions
    construction_args_hash.sort.map do |key,value|
      #only include if construction is used on surface
      if value.getNetArea > 0
        construction_handles << value.handle.to_s
        construction_display_names << key
      end
    end

    #make an argument for construction
    construction = OpenStudio::Measure::OSArgument::makeChoiceArgument("construction", construction_handles, construction_display_names,true,true)
    construction.setDisplayName("Choose a Construction to Alter")
    args << construction

    #make an argument insulation R-value
    r_value = OpenStudio::Ruleset::OSArgument::makeDoubleArgument("r_value",true)
    r_value.setDisplayName("Percentage Increase of R-value for Insulation material in selected construction")
    r_value.setDefaultValue(30.0)
    args << r_value

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    #assign the user inputs to variables
    selected_construction = runner.getOptionalWorkspaceObjectChoiceValue("construction",user_arguments,model) #model is passed in because of argument type
    r_value = runner.getDoubleArgumentValue("r_value",user_arguments)

    #set limit for minimum insulation. This is used to limit input and for inferring insulation layer in construction.
    min_expected_r_value_ip = 1 #ip units

    #check the construction for reasonableness
    if selected_construction.empty?
      handle = runner.getStringArgumentValue("construction",user_arguments)
      if handle.empty?
        runner.registerError("No construction was chosen.")
      else
        runner.registerError("The selected construction with handle '#{handle}' was not found in the model. It may have been removed by another measure.")
      end
      return false
    else
      if not selected_construction.get.to_Construction.empty?
        selected_construction = selected_construction.get.to_Construction.get
      else
        runner.registerError("Script Error - argument not showing up as construction.")
        return false
      end
    end

    # report initial condition of model
    initial_conductance_ip = OpenStudio.convert(1/selected_construction.thermalConductance.to_f,"m^2*K/W", "ft^2*h*R/Btu")
    runner.registerInitialCondition("#{selected_construction.name.to_s} started with an R-value of #{initial_conductance_ip} ft^2*h*R/Btu.")

    # alter construction
    construction_layers = selected_construction.layers
    max_thermal_resistance_material = ""
    max_thermal_resistance_material_index = ""
    counter = 0
    thermal_resistance_values = []

    #loop through construction layers and infer insulation layer/material
    construction_layers.each do |construction_layer|
      construction_layer_r_value = construction_layer.to_OpaqueMaterial.get.thermalResistance
      if not thermal_resistance_values.empty?
        if construction_layer_r_value > thermal_resistance_values.max
          max_thermal_resistance_material = construction_layer
          max_thermal_resistance_material_index = counter
        end
      end
      thermal_resistance_values << construction_layer_r_value
      counter = counter + 1
    end

    if not thermal_resistance_values.max > OpenStudio.convert(min_expected_r_value_ip, "ft^2*h*R/Btu","m^2*K/W").get
      runner.registerWarning("Construction '#{selected_construction.name.to_s}' does not appear to have an insulation layer and was not altered.")
    else
      # do not clone construction since all instacnes of it will be changed
      final_construction = selected_construction
      final_construction.setName("#{selected_construction.name.to_s} adj exterior wall insulation")

      # create new material
      new_material = max_thermal_resistance_material.clone(model)
      new_material = new_material.to_OpaqueMaterial.get
      new_material.setName("#{max_thermal_resistance_material.name.to_s}_R-value #{r_value}% increase")
      final_construction.eraseLayer(max_thermal_resistance_material_index)
      final_construction.insertLayer(max_thermal_resistance_material_index,new_material)
      runner.registerInfo("For construction'#{final_construction.name.to_s}', material'#{new_material.name.to_s}' was altered.")

      #edit insulation material
      new_material_matt = new_material.to_Material
      if not new_material_matt.empty?
        starting_thickness = new_material_matt.get.thickness
        target_thickness = starting_thickness * (1 + r_value/100)
        final_thickness = new_material_matt.get.setThickness(target_thickness)
      end
      new_material_massless = new_material.to_MasslessOpaqueMaterial
      if not new_material_massless.empty?
        starting_thermal_resistance = new_material_massless.get.thermalResistance
        final_thermal_resistance = new_material_massless.get.setThermalResistance(starting_thermal_resistance * (1 + r_value/100))
      end
      new_material_airgap = new_material.to_AirGap
      if not new_material_airgap.empty?
        starting_thermal_resistance = new_material_airgap.get.thermalResistance
        final_thermal_resistance = new_material_airgap.get.setThermalResistance(starting_thermal_resistance * (1 + r_value/100))
      end

    end

    # report final condition of model
    final_conductance_ip = OpenStudio.convert(1/selected_construction.thermalConductance.to_f,"m^2*K/W", "ft^2*h*R/Btu")
    runner.registerFinalCondition("#{selected_construction.name.to_s} started with an R-value of #{final_conductance_ip} ft^2*h*R/Btu.")

    return true

  end
  
end

# register the measure to be used by the application
AlterConstructionProperties.new.registerWithApplication
