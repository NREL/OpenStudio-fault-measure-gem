
# open the class to add methods to return sizing values
class OpenStudio::Model::AirLoopHVACUnitaryHeatPumpAirToAir

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeSupplyAirFlowRateDuringCoolingOperation
    self.autosizeSupplyAirFlowRateDuringHeatingOperation
    self.autosizeSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded
    self.autosizeMaximumSupplyAirTemperaturefromSupplementalHeater
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    sup_air_flow_cooling = self.autosizedSupplyAirFlowRateDuringCoolingOperation
    # to ensure that the original value is an autosized value
    if sup_air_flow_cooling.is_initialized and self.isSupplyAirFlowRateDuringCoolingOperationAutosized
      self.setSupplyAirFlowRateDuringCoolingOperation(sup_air_flow_cooling.get) 
    end    

    sup_air_flow_heating = self.autosizedsSupplyAirFlowRateDuringHeatingOperation
    # to ensure that the original value is an autosized value
    if sup_air_flow_heating.is_initialized and self.isSupplyAirFlowRateDuringHeatingOperationAutosized
      self.setSupplyAirFlowRateDuringHeatingOperation(sup_air_flow_heating.get) 
    end     

    sup_air_flow_no_htg_clg = self.autosizedSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded
    # to ensure that the original value is an autosized value
    if sup_air_flow_no_htg_clg.is_initialized and self.isSupplyAirFlowRateWhenNoCoolingorHeatingisNeededAutosized
      self.setSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded(sup_air_flow_no_htg_clg.get) 
    end
    
    max_sup_htg_temp = self.autosizedMaximumSupplyAirTemperaturefromSupplementalHeater
    # to ensure that the original value is an autosized value
    if max_sup_htg_temp.is_initialized and self.isautosizedMaximumSupplyAirTemperaturefromSupplementalHeaterAutosized
      self.setMaximumSupplyAirTemperaturefromSupplementalHeater(max_sup_htg_temp.get) 
    end 
  
  end

  # returns the autosized supply air flow rate during cooling operation as an optional double
  def autosizedSupplyAirFlowRateDuringCoolingOperation

    return self.model.getAutosizedValue(self, 'Supply Air Flow Rate During Heating Operation', 'm3/s')

  end

    # returns the autosized supply air flow rate during heating operation as an optional double
  def autosizedsSupplyAirFlowRateDuringHeatingOperation

    return self.model.getAutosizedValue(self, 'Supply Air Flow Rate During Cooling Operation', 'm3/s')
    
  end
  
  # returns the autosized supply air flow rate when no heating or cooling is needed as an optional double
  def autosizedSupplyAirFlowRateWhenNoCoolingorHeatingisNeeded

    return self.model.getAutosizedValue(self, 'Supply Air Flow Rate', 'm3/s')   
    
  end

  # returns the autosized maximum supply air temperature from supplemental heater as an optional double
  def autosizedMaximumSupplyAirTemperaturefromSupplementalHeater

    return self.model.getAutosizedValue(self, 'Maximum Supply Air Temperature from Supplemental Heater', 'C')   
    
  end 

 
end
