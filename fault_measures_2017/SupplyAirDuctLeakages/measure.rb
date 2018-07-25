# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

# see the URL below for information on using life cycle cost objects in OpenStudio
# http://openstudio.nrel.gov/openstudio-life-cycle-examples

# see the URL below for access to C++ documentation on model objects (click on "model" in the main window to view model objects)
# https://s3.amazonaws.com/openstudio-sdk-documentation/index.html

# start the measure
class SupplyAirDuctLeakages < OpenStudio::Ruleset::WorkspaceUserScript
  # human readable name
  def name
    return 'Supply Air Duct Leakages'
  end

  # human readable description
  def description
    return "Duct leakage can be caused by torn or missing external duct wrap, poor workmanship around duct takeoffs and fittings, disconnected ducts, improperly installed duct mastic, and temperature and pressure cycling. Conditioned air leaking to an unconditioned space in buildings increases the equipment heating or cooling demand and can increase fan power for variable air volume systems. This fault is categorized as a fault that occur in the ventilation system (duct) during the operation stage. This fault measure is based on a physical model where certain parameter(s) is changed in EnergyPlus to mimic the faulted operation; thus simulates supply air leakage by modifying the ZoneHVAC:AirDistributionUnit object in EnergyPlus. The fault intensity (F) is defined as the ratio of the leakage flow relative to supply flow."   
  end

  # human readable description of workspace approach
  def modeler_description
    return "Two user inputs are required to simulate the fault. The ZoneHVAC:AirDistributionUnit object has two leakage options (upstream and downstream leakages) available. For supply duct leakage, the leakage ratio (leakage flow relative to supply flow) is applied to the downstream leakage parameter and the upstream leakage parameter is replaced with zero in the object. To use this Measure, choose the AirTerminal object to be faulted and a ratio of leakage flow rate to the airflow directed to the zone upstream to the leak. Equation, r_(leak,dnst,F) = 1 - ( 1 - r_(leak,dnst) ) * ( 1 - F ) provides an expression for the downstream leakage ratio (r_(leak,dnst,F)) under faulty conditions in terms of a normal leakage ratio (r_(leak,dnst)) and a fault intensity (F) defined as the ratio of the leakage flow relative to supply flow."
  end

  # define the arguments that the user will input
  def arguments(workspace)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    ##################################################
    list = OpenStudio::StringVector.new
    atsdus = workspace.getObjectsByType("AirTerminal:SingleDuct:Uncontrolled".to_IddObjectType)
    atsdus.each do |atsdu|
      list << atsdu.name.to_s
    end
    atddcvs = workspace.getObjectsByType("AirTerminal:DualDuct:ConstantVolume".to_IddObjectType)
    atddcvs.each do |atddcv|
      list << atddcv.name.to_s
    end
    atddvavs = workspace.getObjectsByType("AirTerminal:DualDuct:VAV".to_IddObjectType)
    atddvavs.each do |atddvav|
      list << atddvav.name.to_s
    end
	atddvavoas = workspace.getObjectsByType("AirTerminal:DualDuct:VAV:OutdoorAir".to_IddObjectType)
    atddvavoas.each do |atddvavoa|
      list << atddvavoa.name.to_s
    end
	atsdcvrs = workspace.getObjectsByType("AirTerminal:SingleDuct:ConstantVolume:Reheat".to_IddObjectType)
    atsdcvrs.each do |atsdcvr|
      list << atsdcvr.name.to_s
    end
	atsdvavrs = workspace.getObjectsByType("AirTerminal:SingleDuct:VAV:Reheat".to_IddObjectType)
    atsdvavrs.each do |atsdvavr|
      list << atsdvavr.name.to_s
    end
	atsdvavnrs = workspace.getObjectsByType("AirTerminal:SingleDuct:VAV:NoReheat".to_IddObjectType)
    atsdvavnrs.each do |atsdvavnr|
      list << atsdvavnr.name.to_s
    end
	atsdspiurs = workspace.getObjectsByType("AirTerminal:SingleDuct:SeriesPIU:Reheat".to_IddObjectType)
    atsdspiurs.each do |atsdspiur|
      list << atsdspiur.name.to_s
    end
	atsdppiurs = workspace.getObjectsByType("AirTerminal:SingleDuct:ParallelPIU:Reheat".to_IddObjectType)
    atsdppiurs.each do |atsdppiur|
      list << atsdppiur.name.to_s
    end
	atsdcvfpis = workspace.getObjectsByType("AirTerminal:SingleDuct:ConstantVolume:FourPipeInduction".to_IddObjectType)
    atsdcvfpis.each do |atsdcvfpi|
      list << atsdcvfpi.name.to_s
    end
	atsdvavrvsfs = workspace.getObjectsByType("AirTerminal:SingleDuct:VAV:Reheat:VariableSpeedFan".to_IddObjectType)
    atsdvavrvsfs.each do |atsdvavrvsf|
      list << atsdvavrvsf.name.to_s
    end
	atsdvavhacrs = workspace.getObjectsByType("AirTerminal:SingleDuct:VAV:HeatAndCool:Reheat".to_IddObjectType)
    atsdvavhacrs.each do |atsdvavhacr|
      list << atsdvavhacr.name.to_s
    end
	atsdvavhacnrs = workspace.getObjectsByType("AirTerminal:SingleDuct:VAV:HeatAndCool:NoReheat".to_IddObjectType)
    atsdvavhacnrs.each do |atsdvavhacnr|
      list << atsdvavhacnr.name.to_s
    end
		
    # make choice arguments for fan
    airterminal_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument("airterminal_choice", list, true)
    airterminal_choice.setDisplayName("Select the name of the faulted AirTerminal object")
    airterminal_choice.setDefaultValue(list[0].to_s)
    args << airterminal_choice
    ##################################################

    # make a double argument for the leakage ratio
    leak_ratio = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('leak_ratio', false)
    leak_ratio.setDisplayName('Ratio of leak airflow between 0 and 0.3.')
    leak_ratio.setDefaultValue(0.1)  # default leakage level to be 10%
    args << leak_ratio

    return args
  end

  # define what happens when the measure is run
  def run(workspace, runner, user_arguments)
    super(workspace, runner, user_arguments)

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(workspace), user_arguments)
      return false
    end

    # obtain values
    airterminal_choice = runner.getStringArgumentValue('airterminal_choice', user_arguments)
    leak_ratio = runner.getDoubleArgumentValue('leak_ratio', user_arguments)

    sh_airterminal_choice = airterminal_choice.clone.gsub!(/[^0-9A-Za-z]/, '')

    if leak_ratio != 0 # only continue if the system is faulted

      runner.registerInitialCondition("Imposing duct leakages on #{airterminal_choice}.")

      # if there is no user-defined schedule, check if the fouling level is positive and if it is below the permitted level in E+
      if leak_ratio < 0.0 || leak_ratio > 0.3
        runner.registerError("Fault level #{leak_ratio} for #{airterminal_choice} is outside the range from 0 to 0.3. Exiting......")
        return false
      end

      # prepare objects to add
      string_objects = []

      # if the AirTerminal object type is AirTerminal:SingleDuct:Uncontrolled, replace it with AirTerminal:SingleDuct:ConstantVolume:Reheat to add the ZoneHVAC:AirDistributionUnit object that is required to impose the leak model. Append the new objects to the model before process it with the fault
      airterminals = workspace.getObjectsByType('AirTerminal:SingleDuct:Uncontrolled'.to_IddObjectType)
      airterminals.each do |airterminal|
        if airterminal.getString(0).to_s.eql?(airterminal_choice)
          # start replacement
          # get the parameters from the original AirTerminal object
          schedule_name = airterminal.getString(1).to_s
          supply_node = airterminal.getString(2).to_s
          defaultflow = airterminal.getString(3).to_s  # can be "Autosize" so leave it as string
          # change the equipment list object type and names under AirTerminal:SingleDuct:Uncontrolled
          newaduname = "ADU #{sh_airterminal_choice}"
          
          #############################################################################################          
          #equiplistchange = false
          #equiplists = workspace.getObjectsByType('ZoneHVAC:EquipmentList'.to_IddObjectType)
          #equiplists.each do |equiplist|
          #  equiplistfields = equiplist.numFields
          #  (1..(equiplistfields - 1)).each do |ind|
          #    if equiplist.getString(ind).to_s.eql?(airterminal_choice)
          #      equiplist.setString(ind, newaduname)
          #      equiplist.setString(ind - 1, 'ZoneHVAC:AirDistributionUnit')
          #      equiplistchange = true
          #      break
          #    end
          #  end
          #  if equiplistchange
          #    break
          #  end
          #end
          #unless equiplistchange
          #  runner.registerError("Measure SupplyAirDuctLeakages cannot find the ZoneHVAC:EquipmentList that contains #{airterminal_choice}. Exiting......")
          #  return false
          #end
          #############################################################################################
          
          # change the AirLoopHVAC:ZoneSplitter object with new node name
          newnodename = "NodeIn#{sh_airterminal_choice}"  # name of node between the new terminal and the ZoneSplitter object
          zonesplitterchange = false
          zonesplitters = workspace.getObjectsByType('AirLoopHVAC:ZoneSplitter'.to_IddObjectType)
          zonesplitters.each do |zonesplitter|
            zonesplitterfields = zonesplitter.numFields
            (1..(zonesplitterfields - 1)).each do |ind|
              if zonesplitter.getString(ind).to_s.eql?(supply_node)
                zonesplitter.setString(ind, newnodename)
                zonesplitterchange = true
                break
              end
            end
            if zonesplitterchange
              break
            end
          end
          unless zonesplitterchange
            runner.registerError("Measure SupplyAirDuctLeakages cannot find the AirLoopHVAC:ZoneSplitter that contains #{airterminal_choice}. Exiting......")
            return false
          end
          # create new AirTerminal:SingleDuct:ConstantVolume:Reheat, Coil:Heating:Electric and ZoneHVAC:AirDistributionUnit objects
          newcoilname = "ElecHeatCoil#{sh_airterminal_choice}"
          string_objects << "
            Coil:Heating:Electric,
              #{newcoilname},                         !- Name
              #{schedule_name},                       !- Availability Schedule Name
              1,                                      !- Efficiency
              0,                                      !- Nominal Capacity {W}
              #{newnodename},                          !- Air Inlet Node Name
              #{supply_node};                        !- Air Outlet Node Name
          "  # zero capacity to avoid adding reheat
          string_objects << "
            AirTerminal:SingleDuct:ConstantVolume:Reheat,
              #{airterminal_choice},                  !- Name
              #{schedule_name},                       !- Availability Schedule Name
              #{supply_node},                         !- Air Outlet Node Name
              #{newnodename},                         !- Air Inlet Node Name
              #{defaultflow},                         !- Maximum Air Flow Rate {m3/s}
              Coil:Heating:Electric,                  !- Reheat Coil Object Type
              #{newcoilname},                         !- Reheat Coil Name
              Autosize,                               !- Maximum Hot Water or Steam Flow Rate {m3/s}
              0,                                      !- Minimum Hot Water or Steam Flow Rate {m3/s}
              0.001,                                  !- Convergence Tolerance
              35;                                     !- Maximum Reheat Air Temperature {C}
          "  # same configuration as AirTerminal:SingleDuct:Uncontrolled object to replace the object without changing performance
          string_objects << "
            ZoneHVAC:AirDistributionUnit,
              #{newaduname},                          !- Name
              #{supply_node},                         !- Air Distribution Unit Outlet Node Name
              AirTerminal:SingleDuct:ConstantVolume:Reheat, !- Air Terminal Object Type
              #{airterminal_choice};                  !- Air Terminal Name
          "
          # add new objects
          string_objects.each do |string_object|
            idfobject = OpenStudio::IdfObject::load(string_object)
            object = idfobject.get
            wsobject = workspace.addObject(object)
            unless wsobject
              runner.registerError("#{string_object} inserted unsuccessfully. Exiting......")
              return false
            end
          end
          
          #############################################################################################
          #string_objects = []
          ## remove the AirTerminal:SingleDuct:Uncontrolled object
          #airterminal.remove
          #break
          #############################################################################################
          
        end
      end
      
      #############################################################################################
      airterminals.each do |airterminal|
        if airterminal.getString(0).to_s.eql?(airterminal_choice)
      
          # change the equipment list object type and names under AirTerminal:SingleDuct:Uncontrolled
          newaduname = "ADU #{sh_airterminal_choice}"
                   
          equiplistchange = false
          equiplists = workspace.getObjectsByType('ZoneHVAC:EquipmentList'.to_IddObjectType)
          equiplists.each do |equiplist|
            equiplistfields = equiplist.numFields
            (1..(equiplistfields - 1)).each do |ind|
              if equiplist.getString(ind).to_s.eql?(airterminal_choice)
                equiplist.setString(ind, newaduname)
                equiplist.setString(ind - 1, 'ZoneHVAC:AirDistributionUnit')
                equiplistchange = true
                break
              end
            end
            if equiplistchange
              break
            end
          end
          unless equiplistchange
            runner.registerError("Measure SupplyAirDuctLeakages cannot find the ZoneHVAC:EquipmentList that contains #{airterminal_choice}. Exiting......")
            return false
          end
          string_objects = []
          # remove the AirTerminal:SingleDuct:Uncontrolled object
          airterminal.remove
          break
        end
      end
      #############################################################################################

      # find the AirTerminal object to change
      airterminal_changed = false
      adu_changed = false
      ratio_set = false
      zonemixer_changed = false
      retpath_changed = false
      retplen_found = false
      field_num = 0
      zonename = ''
      existing_airterminals = []
      airterminaltypes = [
        'AirTerminal:DualDuct:ConstantVolume', 'AirTerminal:DualDuct:VAV', 'AirTerminal:DualDuct:VAV:OutdoorAir', 'AirTerminal:SingleDuct:ConstantVolume:Reheat', 'AirTerminal:SingleDuct:VAV:Reheat', 'AirTerminal:SingleDuct:VAV:NoReheat', 'AirTerminal:SingleDuct:SeriesPIU:Reheat', 'AirTerminal:SingleDuct:ParallelPIU:Reheat', 'AirTerminal:SingleDuct:ConstantVolume:FourPipeInduction',  'AirTerminal:SingleDuct:VAV:Reheat:VariableSpeedFan', 'AirTerminal:SingleDuct:VAV:HeatAndCool:Reheat', 'AirTerminal:SingleDuct:VAV:HeatAndCool:NoReheat'
      ] # AirTerminal:SingleDuct:Uncontrolled requires insertion of of ZoneHVAC:AirDistributionUnit. Do it later.
      airterminaltypes.each do |airterminaltype|
        airterminals = workspace.getObjectsByType(airterminaltype.to_IddObjectType)
        airterminals.each do |airterminal|
          # check if the names are equal
          if airterminal.getString(0).to_s.eql?(airterminal_choice)
            # find the airterminal
            airterminal_changed = true

            # locate the ZoneHVAC:AirDistributionUnit to add the leakage ratio
            adus = workspace.getObjectsByType('ZoneHVAC:AirDistributionUnit'.to_IddObjectType)
            adus.each do |adu|
              if adu.getString(2).to_s.eql?(airterminaltype) && adu.getString(3).to_s.eql?(airterminal_choice)
                adu_changed = true
                # continue to check if a Return Plenum is available for the duct to leak before imposing fault
                equiplists = workspace.getObjectsByType('ZoneHVAC:EquipmentList'.to_IddObjectType)
                aduname = adu.getString(0).to_s
                equiplists.each do |equiplist|
                  equiplistfields = equiplist.numFields
                  (1..(equiplistfields - 1)).each do |ind|
                    if equiplist.getString(ind).to_s.eql?(aduname)
                      equiplistname = equiplist.getString(0).to_s
                      equipconns = workspace.getObjectsByType('ZoneHVAC:EquipmentConnections'.to_IddObjectType)
                      equipconns.each do |equipconn|
                        if equipconn.getString(1).to_s.eql?(equiplistname)
                          # zone located
                          zoneoutnode = equipconn.getString(5).to_s
                          # find the related AirLoopHVAC:ReturnPlenum object
                          returnplenums = workspace.getObjectsByType('AirLoopHVAC:ReturnPlenum'.to_IddObjectType)
                          returnplenums.each do |returnplenum|

                            # this adds support for plenums serving more than 1 zone
                            (returnplenum.numFields - 5).times do |i|
                              if returnplenum.getString(5 + i).to_s.eql?(zoneoutnode)  # check if they are connected
                                retplen_found = true
                                break
                              end
                            end

                          end
                          if retplen_found
                            break
                          end
                          break
                        end
                      end
                    end
                    if retplen_found
                      break
                    end
                  end
                  if retplen_found
                    break
                  end
                end
                if retplen_found
                  # set or modify the original leakage ratio
                  ori_leak_ratio = adu.getDouble(5)
                  field_num = adu.numFields
                  if ori_leak_ratio
                    leak_ratio = 1.0 - (1.0 - ori_leak_ratio.to_f) * (1.0 - leak_ratio)  # if the AirTerminal is leakage in the original model, recalculate the appropriate leak ratio
                  end
                  ratio_set = adu.setDouble(5, leak_ratio)
                  upstreamleakratio = adu.getDouble(4)
                  if !upstreamleakratio  # give a small value to make sure that the algorithm runs
                    adu.setDouble(4, 0.00001)
                  elsif upstreamleakratio.to_f < 0.00001
                    adu.setDouble(4, 0.00001)
                  end
                  break
                else
                  runner.registerAsNotApplicable("#{airterminal_choice} cannot leak because there are no return plenums for it to leak its airflow. Skipping......")
                  return true
                end
              end
            end
          else
            existing_airterminals << airterminal.getString(0).to_s
          end
          if airterminal_changed
            break
          end
        end
        if airterminal_changed
          break
        end
      end

      # give an error for the name if no RTU is changed
      if !airterminal_changed
        runner.registerError("Measure SupplyAirDuctLeakages cannot find #{airterminal_choice}. Exiting......")
        airterminals_msg = 'Only AirTerminals '
        existing_airterminals.each do |existing_airterminal|
          airterminals_msg = "#{airterminals_msg}#{existing_airterminal}, "
        end
        airterminals_msg = "#{airterminals_msg} were found."
        runner.registerError(airterminals_msg)
        return false
      elsif !adu_changed
        runner.registerError("Measure SupplyAirDuctLeakages cannot find the ZoneHVAC:AirDistributionUnit that contains #{airterminal_choice}. Exiting......")
        return false
      elsif !ratio_set
        runner.registerError("Leakage ratio cannot be assigned to #{airterminal_choice} with the ZoneHVAC:AirDistributionUnit object having #{field_num} fields. Exiting......")
        return false
      end

      # report final condition of workspace
      runner.registerFinalCondition("Imposed performance degradation on #{airterminal_choice}.")
    else
      runner.registerAsNotApplicable("SupplyAirDuctLeakages is not running for #{airterminal_choice}. Skipping......")
    end

    return true
  end
end

# register the measure to be used by the application
SupplyAirDuctLeakages.new.registerWithApplication
