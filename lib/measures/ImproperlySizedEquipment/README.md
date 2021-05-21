

###### (Automatically generated documentation)

# Improperly Sized Equipment

## Description
A possible fault for HVAC equipment is improper sizing at the design stage. This fault is based on a physical model where certain perameter(s) are changed in EnergyPlus to mimic the faulted operation; this sumulated over and undersized equipment by modifying Sizing:Parameters object in EnergyPlus. The fault intensity (F) is defined as the ratio of the improper sizing relative to the corrent sizing.

## Modeler Description
This measure simuated the effect of improperly sized equipment at design by modifying the Sizing:Parameters object and capacity fields in objects in Energy Plus. One user input is required; ratio of the desired improper size to the original sizing. 

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### Enter the name of the oversized coil object. If you want to impose the fault on all equipment, select 'Apply to all equipment'

**Name:** equip_choice,
**Type:** Choice,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Sizing Multiplier (greater than 0)

**Name:** sizing_ratio,
**Type:** Double,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Hard size model

**Name:** hard_size,
**Type:** Boolean,
**Units:** ,
**Required:** true,
**Model Dependent:** false




