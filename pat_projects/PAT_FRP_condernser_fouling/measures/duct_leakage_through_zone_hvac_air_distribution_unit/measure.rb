# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class DuctLeakageThroughZoneHVACAirDistributionUnit < OpenStudio::Measure::EnergyPlusMeasure

  # human readable name
  def name
    return "Duct Leakage through ZoneHVACAirDistributionUnit"
  end

  # human readable description
  def description
    return "Simulate supply air duct leakage from VAV into Return Plenum."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This simple measure finds all ZoneHVAC:AirDistributionUnit objects and sets the upstream and downstream nominal leakage fraction to a user specified value"
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Measure::OSArgumentVector.new

    # the name of the zone to add to the model
    upstream_fraction = OpenStudio::Measure::OSArgument.makeDoubleArgument("upstream_fraction", true)
    upstream_fraction.setDisplayName("Upstream nominal leakage fraction")
    upstream_fraction.setDefaultValue(0.0)
    args << upstream_fraction

    # the name of the zone to add to the model
    downstream_fraction = OpenStudio::Measure::OSArgument.makeDoubleArgument("downstream_fraction", true)
    downstream_fraction.setDisplayName("Downstream nominal leakage fraction")
    downstream_fraction.setDefaultValue(0.0)
    args << downstream_fraction

    return args
  end

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

    # assign the user inputs to variables
    upstream_fraction = runner.getStringArgumentValue("upstream_fraction", user_arguments)
    downstream_fraction = runner.getStringArgumentValue("downstream_fraction", user_arguments)

    # get all thermal zones in the starting model
    adus = workspace.getObjectsByType("ZoneHVAC:AirDistributionUnit".to_IddObjectType)

    # reporting initial condition of model
    runner.registerInitialCondition("The building started with #{adus.size} Air Distribution Unit objects..")

    # set upstream and downstream
    adus.each do |adu|
      runner.registerInfo("Setting duct leakge for #{adu.getString(0)}")
      adu.setString(4,upstream_fraction)
      adu.setString(5,downstream_fraction)
    end


    return true

  end

end

# register the measure to be used by the application
DuctLeakageThroughZoneHVACAirDistributionUnit.new.registerWithApplication
