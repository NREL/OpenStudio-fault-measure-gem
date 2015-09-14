
# open the class to add methods to return sizing values
class OpenStudio::Model::AirConditionerVariableRefrigerantFlow

  # Sets all auto-sizeable fields to autosize
  def autosize
    # OpenStudio::logFree(OpenStudio::Warn, "openstudio.sizing.AirConditionerVariableRefrigerantFlow", ".autosize not yet implemented for #{self.iddObject.type.valueDescription}.")
    self.autosizeEvaporativeCondenserAirFlowRate
    self.autosizeEvaporativeCondenserPumpRatedPowerConsumption
    self.autosizeRatedTotalCoolingCapacity
    self.autosizeRatedTotalHeatingCapacity
    self.autosizeResistiveDefrostHeaterCapacity
    self.autosizeWaterCondenserVolumeFlowRate
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    OpenStudio::logFree(OpenStudio::Warn, "openstudio.sizing.AirConditionerVariableRefrigerantFlow", ".applySizingValues not yet implemented for #{self.iddObject.type.valueDescription}.")
        
  end

  # returns the autosized design supply air flow rate as an optional double
  def autosizeEvaporativeCondenserAirFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Evaporative Condenser Air Flow Rate', 'm3/s')
    
  end
  
  def autosizeEvaporativeCondenserPumpRatedPowerConsumption

    return self.model.getAutosizedValue(self, 'Design Size Evaporative Condenser Pump Rated Power Consumption', 'W')
    
  end
  
  def autosizedRatedTotalCoolingCapacity

    return self.model.getAutosizedValue(self, 'Design Size Gross Rated Total Cooling Capacity', 'W')
    
  end
  
  def autosizedRatedTotalHeatingCapacity

    return self.model.getAutosizedValue(self, 'Design Size Gross Rated Heating Capacity', 'W')
    
  end
  
  def autosizedResistiveDefrostHeaterCapacity

    return self.model.getAutosizedValue(self, 'Design Size Resistive Defrost Heater Capacity', 'W')
    
  end
  
  def autosizedWaterCondenserVolumeFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Water Condenser Volume Flow Rate', 'm3/s')
    
  end
  
  
  
end
