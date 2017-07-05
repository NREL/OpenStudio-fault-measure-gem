
# open the class to add methods to return sizing values
class OpenStudio::Model::BoilerHotWater

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeNominalCapacity
    self.DesignWaterFlowRate
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    nominal_capacity = self.autosizedNominalCapacity
    if nominal_capacity.is_initialized and self.isNominalCapacityAutosized
      self.setNominalCapacity(nominal_capacity.get) 
    end

    design_water_flow_rate = self.autosizedDesignWaterFlowRate
    if design_water_flow_rate.is_initialized and self.isDesignWaterFlowRateAutosized
      self.setDesignWaterFlowRate(design_water_flow_rate.get) 
    end
    
  end

  # returns the autosized nominal capacity as an optional double
  def autosizedNominalCapacity

    # v.8.1.0 case
    result = self.model.getAutosizedValue(self, 'Nominal Capacity', 'W')
    if result.empty? # v8.2.0 case
      return self.model.getAutosizedValue(self, 'Design Size Nominal Capacity', 'W')
    else
      return result
    end
    
  end
  
  # returns the autosized design water flow rate as an optional double
  def autosizedDesignWaterFlowRate

    # v.8.1.0 case
    result = self.model.getAutosizedValue(self, 'Design Water Flow Rate', 'm3/s')
    if result.empty? # v8.2.0 case
      return self.model.getAutosizedValue(self, 'Design Size Design Water Flow Rate', 'm3/s')
    else
      return result
    end
    
  end
  
  
end
