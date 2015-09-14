
# open the class to add methods to return sizing values
class OpenStudio::Model::AirTerminalSingleDuctVAVNoReheat

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeMaximumAirFlowRate 
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues
       
    rated_flow_rate = self.autosizedMaximumAirFlowRate
    if rated_flow_rate.is_initialized and self.isMaximumAirFlowRateAutosized
      self.setMaximumAirFlowRate(rated_flow_rate.get) 
    end

  end

  # returns the autosized maximum air flow rate as an optional double
  def autosizedMaximumAirFlowRate

    return self.model.getAutosizedValue(self, 'Design Size Maximum Air Flow Rate', 'm3/s')
    
  end  

  
end
