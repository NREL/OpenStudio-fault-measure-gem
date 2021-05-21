def applyToLoop(runner, workspace, loop, offset, fault_intensity_key)
  runner.registerInfo("Applying #{offset}C offset to #{loop.name.get}")
  branches = getBranchesFromLoop(workspace, loop)
  ducts = []
  branches.each do |branch|
    ducts.push(appendDuctToBranch(workspace, branch))
  end
  pointMixedSetpointManagersToDuctOutlets(workspace, ducts)
  updateLoopOutletNodes(workspace, loop, branches)
  program = OpenStudio::IdfObject.new('EnergyManagementSystem:Program'.to_IddObjectType)
  program.setName(toEMSName("#{loop.name.get}_offset_applier"))
  line = 0
  ducts.each do |duct|
    actuator, sensor = makeActuatorAndSensorForDuct(workspace, duct)
    program.setString(line += 1, "SET #{actuator.name.get} = #{sensor.name.get} + #{offset}*#{fault_intensity_key}")
  end
  program = workspace.insertObject(program).get
  calling_manager = OpenStudio::IdfObject.new('EnergyManagementSystem:ProgramCallingManager'.to_IddObjectType)
  calling_manager.setName("#{loop.name.get}_calling_manager")
  calling_manager.setString(1, 'AfterPredictorBeforeHVACManagers')
  calling_manager.setString(2, program.name.get)
  calling_manager = workspace.insertObject(calling_manager).get
end

def toEMSName(string)
  return 'm_' + string.gsub('-','_').gsub(' ','_')
end

def updateLoopOutletNodes(workspace, loop, branches)
  outlet_nodes = []
  branches.each do |branch|
    outlet_nodes.push(branch.getString(branch.numFields - 1).get)
  end
  outlet_nodelist = workspace.getObjectByTypeAndName('NodeList'.to_IddObjectType, loop.getString(9).get)
  if outlet_nodelist.is_initialized
    outlet_nodelist = outlet_nodelist.get
    for i in 0..outlet_nodes.length - 1
      outlet_nodelist.setString(i + 1, outlet_nodes[i])
    end
  else
    loop.setString(9, outlet_nodes[0])
  end
end

def makeActuatorAndSensorForDuct(workspace, duct)
  actuator = OpenStudio::IdfObject.new('EnergyManagementSystem:Actuator'.to_IddObjectType)
  sensor = OpenStudio::IdfObject.new('EnergyManagementSystem:Sensor'.to_IddObjectType)
  actuator.setName(toEMSName("#{duct.getString(2).get}_setpoint_actuator")) # Set Name
  actuator.setString(1, duct.getString(2).get)
  actuator.setString(2, 'System Node Setpoint')
  actuator.setString(3, 'Temperature Setpoint')
  sensor.setName(toEMSName("#{duct.getString(1).get}_setpoint"))
  sensor.setString(1, duct.getString(1).get)
  sensor.setString(2, 'System Node Setpoint Temperature')
  actuator = workspace.insertObject(actuator).get
  sensor = workspace.insertObject(sensor).get
  return actuator, sensor
end

def pointMixedSetpointManagersToDuctOutlets(workspace, ducts)
  replace_nodes = {}
  ducts.each do |duct|
    replace_nodes[duct.getString(1).get] = duct.getString(2).get
  end
  mixed_air_setpoint_managers = workspace.getObjectsByType('SetpointManager:MixedAir'.to_IddObjectType)
  mixed_air_setpoint_managers.each do |setpoint_manager|
    if replace_nodes.key? setpoint_manager.getString(2).get
      setpoint_manager.setString(2, replace_nodes[setpoint_manager.getString(2).get])
    end
  end
end

def getOutletNodesFromLoop(workspace, loop)
  outlet_nodelist = workspace.getObjectByTypeAndName('NodeList'.to_IddObjectType, loop.getString(9).get)
  outlet_nodes = []
  if outlet_nodelist.is_initialized
    outlet_nodelist = outlet_nodelist.get
    for i in 1..outlet_nodelist.numFields
      outlet_nodes.push(outlet_nodelist.getString(i).get)
    end
  else
    outlet_nodes.push(loop.getString(9).get)
  end
end

def getBranchesFromLoop(workspace, loop)
  branchlist = workspace.getObjectByTypeAndName('BranchList'.to_IddObjectType, loop.getString(4).get)
  branches = []
  if branchlist.is_initialized
    branchlist = branchlist.get
    for i in 1..(branchlist.numFields - 1)
      branches.push(workspace.getObjectByTypeAndName('Branch'.to_IddObjectType, branchlist.getString(i).get).get)
    end
  end
  return branches
end

def appendDuctToBranch(workspace, branch)
  duct = OpenStudio::IdfObject.new('Duct'.to_IddObjectType)
  branch_fields_num = branch.numFields
  outlet_node_name = branch.getString(branch_fields_num - 1).get
  intermediate_node_name = branch.name.get + ' New Outlet Node'
  duct.setString(1, outlet_node_name)
  duct.setString(2, intermediate_node_name)
  duct = workspace.addObject(duct).get
  branch.setString(branch_fields_num, 'Duct')
  branch.setString(branch_fields_num + 1, duct.name.get)
  branch.setString(branch_fields_num + 2, outlet_node_name)
  branch.setString(branch_fields_num + 3, intermediate_node_name)
  return duct
end
