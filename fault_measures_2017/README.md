# Representing Small Commercial Building Faults in EnergyPlus: Model Development

Small commercial buildings (those with less than approximately 1,000 m2 of total floor area) often do not have access to cost-effective automated fault detection and diagnosis (AFDD) tools for maintaining efficient building operations. AFDD tools based on machine-learning algorithms hold promise for lowering cost barriers for AFDD in small commercial buildings; however, such algorithms require access to high-quality training data that is often difficult to obtain. 

![alt text](workflow.png)

Above figure shows the workflow of the entire study including the companion (Part II) study. The fault models considered in this study were those identified as highest priority by [Kim, Cai, and Braun (2018)](https://www.nrel.gov/docs/fy18osti/70136.pdf). Based on an extensive literature review and communications with experts in the field, we estimated annual energy impact reflecting the occurrence percentage and performance degradation of each fault and the financial impact reflecting the utility cost increase and life cycle cost increase of each fault. The estimates were used to prioritize faults that have significant impact on nationwide energy consumption.

Models for all faults were implemented for the whole-building energy modeling software engine EnergyPlus®, developed and maintained by the U.S. Department of Energy. Some of the fault models used were developed in a [previous study](https://www.nrel.gov/docs/fy16osti/65030.pdf); those faults applicable to small commercial buildings were adopted and updated for [this work](). The remaining faults in the list represent newly developed models. All fault models were refined to have extended capability, such as operation with a wider variety of modeling objects in EnergyPlus, compatibility with other fault models within the simulation, and additional features such as the fault evolution.

Some, but not all, of the fault models were validated against experimental measurements. Simulation results with and without modeled faults were compared to actual experimental measurements obtained from a test facility designed to resemble a small office building. Validation results are described in the [companion study]().

Below is a list of all fault models included in this repository.

![alt text](FaultModel.png)