# Representing Small Commercial Building Faults in EnergyPlus: Model Development

Small commercial buildings (those with less than approximately 1,000 m2 of total floor area) often do not have access to cost-effective automated fault detection and diagnosis (AFDD) tools for maintaining efficient building operations. AFDD tools based on machine-learning algorithms hold promise for lowering cost barriers for AFDD in small commercial buildings; however, such algorithms require access to high-quality training data that is often difficult to obtain. 

![alt text](workflow.png)

Above figure shows the workflow of the entire study including the companion (Part II) study. The fault models considered in this study were those identified as highest priority by [Kim, Cai, and Braun (2018)](https://www.nrel.gov/docs/fy18osti/70136.pdf). Based on an extensive literature review and communications with experts in the field, we estimated annual energy impact reflecting the occurrence percentage and performance degradation of each fault and the financial impact reflecting the utility cost increase and life cycle cost increase of each fault. The estimates were used to prioritize faults that have significant impact on nationwide energy consumption.

Models for all faults were implemented for the whole-building energy modeling software engine EnergyPlus®, developed and maintained by the U.S. Department of Energy. Some of the fault models used were developed in a [previous study](https://www.nrel.gov/docs/fy16osti/65030.pdf); those faults applicable to small commercial buildings were adopted and updated for this work. The remaining faults in the list represent newly developed models. All fault models were refined to have extended capability, such as operation with a wider variety of modeling objects in EnergyPlus, compatibility with other fault models within the simulation, and additional features such as the fault evolution.

Some, but not all, of the fault models were validated against experimental measurements. Simulation results with and without modeled faults were compared to actual experimental measurements obtained from a test facility designed to resemble a small office building. Validation results are described in the companion study.

Fault Measures	Fault Intensity Definition	Fault Intensity Range	Modeling Approach	Fault Evolution
Presence of noncondensable gas in refrigerant	Ratio of the mass of noncondensable gas in the refrigerant circuit to the mass of noncondensable gas that the refrigerant circuit can hold at standard atmospheric pressure	0 to 0.6	Empirical	Y
Refrigerant liquid-line restriction	Ratio of increase in the pressure difference between the condenser outlet and evaporator inlet because of the restriction	0 to 0.3	Empirical	Y
Condenser fouling	Ratio of reduction in condenser coil airflow at full load	0 to 0.5	Empirical	Y
Nonstandard refrigerant charging	Ratio of charge deviation from the normal charge level	-0.3 to 0.15	Empirical	Y
Economizer opening stuck at certain position	Ratio of economizer damper at the stuck position (0 = completely closed, 1 = completely open)	0 to 1	Physical	N
Supply air duct leakages	Ratio of the leakage flow relative to supply flow	0 to 0.3	Physical	N
Return air duct leakages	Unconditioned air introduced to return air stream at full load condition as a ratio of the total return airflow rate	0 to 0.3	Physical	Y
Biased economizer sensor: mixed temperature	Biased temperature level in K	-3 to +3K	Physical	N
Biased economizer sensor: outdoor relative humidity 	Biased relative humidity level in %	-10 to +10%	Physical	Y
Biased economizer sensor: outdoor temperature	Biased temperature level in K	-3 to +3K	Physical	Y
Biased economizer sensor: return relative humidity 	Biased relative humidity level in %	-10 to +10%	Physical	Y
Biased economizer sensor: return temperature	Biased temperature level in K	-3 to +3K	Physical	Y
Excessive infiltration around the building envelope	Ratio of excessive infiltration around the building envelope compared to the unfaulted condition	0 to 0.4	Physical	Y
Oversized equipment at design	Ratio of increased sizing compared to the correct sizing	0 to 0.5	Physical	N
HVAC setback error: delayed onset	Delay in the onset of setback in hours	0 to 3 hrs	Physical	N
HVAC setback error: early termination	Early termination of setback in hours	0 to 3 hrs	Physical	N
HVAC setback error: no overnight setback	Absence of overnight setback (binary)	0 or 1	Physical	N
Improper time delay setting in occupancy sensors	Delayed time setting in hours	0 to 0.75 hrs	Physical	N
Lighting setback error: delayed onset	Delay in the onset of setback in hours	0 to 3 hrs	Physical	N
Lighting setback error: early termination	Early termination of setback in hours	0 to 3 hrs	Physical	N
Lighting setback error: no overnight setback	Absence of overnight setback (binary)	0 or 1	Physical	N
Thermostat measurement bias	Thermostat measurement bias in K	-3 to 3K	Physical	Y
Condenser fan degradation	Reduction in motor efficiency as a fraction of the unfaulted motor efficiency	0 to 0.3	Semi-empirical	Y
Duct fouling	Reduction in airflow in the duct system at full load condition as a ratio of the design airflow rate	0 to 0.4	Semi-empirical	N
Air handling unit fan motor degradation	Ratio of fan motor efficiency degradation	0 to 0.3	Semi-empirical	Y

