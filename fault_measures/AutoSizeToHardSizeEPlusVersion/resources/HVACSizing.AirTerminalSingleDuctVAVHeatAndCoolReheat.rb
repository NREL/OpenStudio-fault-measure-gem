
# open the class to add methods to return sizing values
class OpenStudio::Model::AirTerminalSingleDuctVAVHeatAndCoolReheat

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeMaximumAirFlowRate
    self.autosizeMaximumHotWaterorSteamFlowRate
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues
  
    rated_flow_rate = self.autosizedMaximumAirFlowRate
    if rated_flow_rate.is_initialized and self.isMaximumAirFlowRateAutosized
      self.setMaximumAirFlowRate(rated_flow_rate.get) 
    end
       
    maximum_hot_water_steam_flow = self.autosizedMaximumHotWaterorSteamFlowRate
    if maximum_hot_water_steam_flow.is_initialized and self.isMaximumHotWaterorSteamFlowRateAutosized
      self.setMaximumHotWaterorSteamFlowRate(maximum_hot_water_steam_flow.get) 
    end
        
  end

  # returns the autosized design supply air flow rate as an optional double
  def autosizedMaximumAirFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Maximum Air Flow Rate', 'm3/s')
    
  end

  def autosizedMaximumHotWaterorSteamFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Hot Water or Steam Flow Rate', 'm3/s')
    
  end
  
  
end
