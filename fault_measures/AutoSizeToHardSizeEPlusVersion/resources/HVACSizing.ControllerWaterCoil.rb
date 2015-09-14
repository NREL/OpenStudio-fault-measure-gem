
# open the class to add methods to return sizing values
class OpenStudio::Model::ControllerWaterCoil

  # Sets all auto-sizeable fields to autosize
  def autosize
    self.autosizeMaximumActuatedFlow
    self.autosizeControllerConvergenceTolerance
  end

  # Takes the values calculated by the EnergyPlus sizing routines
  # and puts them into this object model in place of the autosized fields.
  # Must have previously completed a run with sql output for this to work.
  def applySizingValues

    # Only attempt to retrieve sizes for water coil controllers
    # that have their sensor nodes set.  Water coils without sensor
    # nodes aren't controlling anything.
    if self.sensorNode.is_initialized
  
      maximum_actuated_flow = self.autosizedMaximumActuatedFlow
      if maximum_actuated_flow.is_initialized and self.isMaximumActuatedFlowAutosized
        self.setMaximumActuatedFlow(maximum_actuated_flow.get) 
      end

      controller_convergence_tolerance = self.autosizedControllerConvergenceTolerance
      if controller_convergence_tolerance.is_initialized and self.isControllerConvergenceToleranceAutosized
        self.setControllerConvergenceTolerance(controller_convergence_tolerance.get) 
      end
    
    end
    
  end

  # returns the autosized maximum actuated flow rate as an optional double
  def autosizedMaximumActuatedFlow

    return self.model.getAutosizedValue(self, 'Maximum Actuated Flow', 'm3/s')
    
  end
  
  # returns the autosized controller convergence tolerance as an optional double
  def autosizedControllerConvergenceTolerance

    return self.model.getAutosizedValue(self, 'Controller Convergence Tolerance', '')

  end
  
  
end
