

###### (Automatically generated documentation)

# Discharge Temperature Offset

## Description
This measure models the faulted condition of a discharge air temperature sensor/setpoint where is has a bias from what it should be.

## Modeler Description
This measure models this fault by first appending a duct to the faulted supply loop after the supply outlet node. The setpoint value from that node is then applied to the new node with an offset as determined by the loop. The mixed air setpoint managers are then pointed to the new outlet node.

## Measure Type
EnergyPlusMeasure

## Taxonomy


## Arguments


### Enter the name of the loop to apply the discharge setpoint offset on

**Name:** loop_choice,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Offset Temp

**Name:** offset,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Enter the time required for fault to reach full level [hr]

**Name:** time_constant,
**Type:** Double,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Enter the month (1-12) when the fault starts to occur

**Name:** start_month,
**Type:** Double,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Enter the date (1-28/30/31) when the fault starts to occur

**Name:** start_date,
**Type:** Double,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Enter the time of day (0-24) when the fault starts to occur

**Name:** start_time,
**Type:** Double,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Enter the month (1-12) when the fault ends

**Name:** end_month,
**Type:** Double,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Enter the date (1-28/30/31) when the fault ends

**Name:** end_date,
**Type:** Double,
**Units:** ,
**Required:** false,
**Model Dependent:** false

### Enter the time of day (0-24) when the fault ends

**Name:** end_time,
**Type:** Double,
**Units:** ,
**Required:** false,
**Model Dependent:** false




