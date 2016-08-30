# Measure script folder

This README describes the OpenStudio and EnergyPlus Measures in this folder
and other supporting files that help to model faults in OpenStudio building
models. They can be grouped as follows:

* Fault Model Measure Scripts
* Supporting Measure Scripts
* Extra Documentation Files

Scripts related to one Measure are stored in a single folder. For instance,
Measure scripts related to the Measure *AddMeter* are stored in the folder
*AddMeter* listed above. To use them with OpenStudio, please check
[About Measures - OpenStudio User Docs](http://nrel.github.io/OpenStudio-user-documentation/getting_started/about_measures/ "About Measures - OpenStudio User Docs").
For their uses with OpenStudio Analysis Spreadsheet, example project files are
given in *../project/*.

## Fault Model Measure Scripts

The following list describes the general functions of the Measures. For details
of the Measures, please check the documentation inside *measure.rb* and
*measure.xml* in the folders.

### OpenStudio Measures

* **DuctFouling**: Model fouling in air duct filters and heat exchangers
* **EconomizerDamperStuckFaultScheduled**: Model stuck damper in economizers according to Barsarkar et al. 2011
* **ExtendEveningThermostatSetpointWeek**: Model how extended thermostat set point schedule for occupied hours beyond evening closing hours affect building performance.
* **ExtendMorningThermostatSetpointWeek**: Model how extended thermostat set point schedule for occupied hours beyond morning opening hours affect building performance.
* **NoOvernightSetbackWeek**: Model the use of thermostat set point schedule in occupied hours in all unoccupied hours
* **NoReset**: Model the incorrect use of thermostat set point schedule on the previous day. This may become severe when a weekend schedule is used on a weekday.
* **PlantLoopTempSensorBiasOS**: Model the bias of temperature sensor on water circuit loop
* **ReduceSpaceInfiltrationByPercentage**: Provided by [BCL (Building Component Library)](https://bcl.nrel.gov/ "Building Component Library"). Use negative inputs to model excessive air leakage around building envelope.
* **ThermostatBias**: Model thermostat bias fault

### EnergyPlus Measures

* **AirLoopSupplyTempSensorBias**: Model supply air temperature sensor bias, if it exists.
* **AirTerminalSupplyDownstreamLeakToReturn**: Add the EnergyPlus Duct Leakage model to the building model. Only applicable to models having a plenum model.
* **AteCheungChillerCondenserFouling**: Model the impact of condenser fouling in a water-cooled chiller according to Cheung and Braun (2016)
* **AteCheungChillerExcessOil**: Model the impact of excess oil in a water-cooled chiller according to Cheung and Braun (2016)
* **AteCheungChillerNonCondensable**: Model the impact of noncondensable gas in a water-cooled chiller according to Cheung and Braun (2016)
* **AteCheungChillerOvercharge**: Model the impact of too much refrigerant in a water-cooled chiller according to Cheung and Braun (2016)
* **ChillerCondenserFouling**: Model condenser fouling in water-cooled chiller
* **ChillerExcessOil**: Model excessive oil impact to water-cooled chiller
* **ChillerNonCondensable**: Model the impact of non-condensable to water-cooled chiller
* **ChillerOvercharge**: Model the impact of too much refrigerant in a water-cooled chiller
* **CoolingThermostatSetpointOccRedByOutdoorTemp**: Model the manual reduction of cooling thermostat set point due to high ambient temperature
* **EconomizerOutdoorRHSensorBiasFault**: Model bias of economizer outdoor relative humidity sensor. Only work when the economizer control depends on air enthalpy values.
* **EconomizerOutdoorTempSensorBiasFault**: Add EnergyPlus model FaultModel:TemperatureSensorOffset:OutdoorAir to the OpenStudio model.
* **EconomizerPotentialMixedTempSensorBiasFault**: Model bias of economizer mixed air temperature sensor, if it exists.
* **EconomizerReturnRHSensorBiasFault**: Model bias of economizer return relative humidity sensor. Only work when the economizer control depends on air enthalpy values.
* **EconomizerReturnTempSensorBiasFault**: Add EnergyPlus model FaultModel:TemperatureSensorOffset:ReturnAir to the OpenStudio model.
* **FanMotorEfficiencyFault**: Model fan motor efficiency degradation in air ducts
* **HeatingThermostatSetpointOccRedByOutdoorTemp**: Model the manual increase of heating thermostat set point due to low ambient temperature
* **RTUCAWithSHRChange**: Model condenser fouling of packaged air conditioners
* **RTUCondenserFanMotorEfficiencyFault**: Model condenser fan motor efficiency degradation of packaged air conditioners
* **RTULLWithSHRChange**: Model liquid line restriction of packaged air conditioners
* **RTUNCWithSHRChange**: Model non-condensable flow with refrigerant in packaged air conditioners
* **SplitUCWithSHRChange**: Model undercharging in split air conditioners
* **SplitCAWithSHRChange**: Model condenser fouling of split air conditioners
* **SplitUCWithSHRChange**: Model undercharging in split air conditioners

## Supporting Measure Scripts

The following list contains the Measures that are required to output the
variables needed to understand the impact of faults.

* **AddMeter**: Provided by [BCL](https://bcl.nrel.gov/ "Building Component Library"). Add object Output:Meter to the OpenStudio model.
* **AddOutputVariable**: Provided by [BCL](https://bcl.nrel.gov/ "Building Component Library"). Add object Output:Variable to the OpenStudio model.
* **AutoSizeToHardSizeEPlusVersion**: Change all autosize values in the OpenStudio model to the corresponding values from the autosizing algorithm. Should be executed before using any models in Fault Model Measure Scripts if your model contains any entries that need autosizing. Only works with EnergyPlus version 8.1 and 8.2.
* **ExportTimeSeriesDatatoCSV**: Uploaded to [BCL](https://bcl.nrel.gov/ "Building Component Library"). Create a csv file containing all timestep data listed under Output:Meter and Output:Variable objects.
* **ThermostatBiasReporting**: Offset the zone air temperature output according to the thermostat bias so that the building simulation outputs show a biased reading rather than the true building simulation output. Does not work with OpenStudio Analysis Spreadsheet.
* **ThermostatBiasReportingAnalysisSpreadSheet**: Version of *ThermostatBiasReporting* that works with OpenStudio Analysis Spreadsheet only.
* **XcelEDAReportingandQAQC** and **XcelEDATariffSelectionandModelSetup**: Provided by [BCL (Building Component Library)](https://bcl.nrel.gov/ "Building Component Library"). Add a tariff scheme and calculate the energy cost of the building. Require both at the same time for correct calculation.

## Extra Documentation Files

The following list files that document extra information about the measures.

* **Measure\_script\_info.csv**: Information about the fault model incompatibility issues with each other.
* **local_fdd_measures.csv**: Templates for fault model inputs in the OpenStudio Analysis Spreadsheet project files.

## References

Barsarkar et al. 2009: at [12th Conference of International Building Performance Simulation Association](http://www.ibpsa.org/proceedings/BS2011/P_1925.pdf "Modeling and Simulation og HVAC Faults in EnergyPlus")

Cheung, H. and Braun, J. E. 2016: in [Applied Thermal Engineering, 99, 756–764](http://doi.org/10.1016/j.applthermaleng.2016.01.119 "Empirical modeling of the impacts of faults on water-cooled chiller power consumption for use in building simulation programs")
