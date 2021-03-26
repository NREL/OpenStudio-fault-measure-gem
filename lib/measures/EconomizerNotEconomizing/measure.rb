# *******************************************************************************
# OpenStudio(R), Copyright (c) 2008-2018, Alliance for Sustainable Energy, LLC.
# All rights reserved.
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# (1) Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# (2) Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# (3) Neither the name of the copyright holder nor the names of any contributors
# may be used to endorse or promote products derived from this software without
# specific prior written permission from the respective party.
#
# (4) Other than as required in clauses (1) and (2), distributions in any form
# of modifications or other derivative works may not use the "OpenStudio"
# trademark, "OS", "os", or any other confusingly similar designation without
# specific prior written permission from Alliance for Sustainable Energy, LLC.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER(S) AND ANY CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER(S), ANY CONTRIBUTORS, THE
# UNITED STATES GOVERNMENT, OR THE UNITED STATES DEPARTMENT OF ENERGY, NOR ANY OF
# THEIR EMPLOYEES, BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
# OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# *******************************************************************************

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

$allchoices = 'All Economizers'

# start the measure
class EconomizerNotEconomizing < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "Economizer Not Economizing"
  end

  # human readable description
  def description
    return "tbd"
  end

  # human readable description of modeling approach
  def modeler_description
    return "tbd"
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    #make choice arguments for economizers
    controlleroutdoorairs = model.getControllerOutdoorAirs
    chs = OpenStudio::StringVector.new
    chs << $allchoices
    controlleroutdoorairs.each do |controlleroutdoorair|
      chs << controlleroutdoorair.name.to_s
    end
    econ_choice = OpenStudio::Ruleset::OSArgument::makeChoiceArgument('econ_choice', chs, true)
    econ_choice.setDisplayName("Choice of economizers. If you want to impose the fault on all economizers, choose #{$allchoices}")
    econ_choice.setDefaultValue($allchoices)
    args << econ_choice
    
    # Add a check box for specifying verbose info statements
    verbose_info_statements = OpenStudio::Ruleset::OSArgument::makeBoolArgument("verbose_info_statements", false)
    verbose_info_statements.setDisplayName("Check to allow measure to generate verbose runner.registerInfo statements.")
    verbose_info_statements.setDefaultValue(false)
    args << verbose_info_statements
    
    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    econ_choice = runner.getStringArgumentValue('econ_choice',user_arguments)
    verbose_info_statements = runner.getBoolArgumentValue("verbose_info_statements",user_arguments)
  
    runner.registerInitialCondition("Measure began with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")
        
    controlleroutdoorairs = model.getControllerOutdoorAirs
    controlleroutdoorairs.each do |controlleroutdoorair|
      if controlleroutdoorair.name.to_s.eql?(econ_choice) || econ_choice.eql?($allchoices)
        if verbose_info_statements == true
          runner.registerInfo("Imposing fault in Controller:OutdoorAir object #{controlleroutdoorair.name}.")

          # check if Controller:OutdoorAir object configurations
          controltype = controlleroutdoorair.getEconomizerControlType
          controlactiontype = controlleroutdoorair.getEconomizerControlActionType
          lockouttype = controlleroutdoorair.getLockoutType
          minlimittype = controlleroutdoorair.getMinimumLimitType
          highhumcontrol = controlleroutdoorair.getHighHumidityControl

          runner.registerInfo("Economizer configuration: ControlType = #{controltype}")
          runner.registerInfo("Economizer configuration: ControlActionType = #{controlactiontype}")
          runner.registerInfo("Economizer configuration: LockoutType = #{lockouttype}")
          runner.registerInfo("Economizer configuration: MinimumLimitType = #{minlimittype}")
          runner.registerInfo("Economizer configuration: HighHumidityControl = #{highhumcontrol}")

          # TODO: add additional logics for different configuration settings
          if controltype.eql?('NoEconomizer')
            runner.registerInfo("Control type of NoEconomizer is not supported. Exiting...")
            return false
          else
            if minlimittype.eql?('FixedMinimum')
              runner.registerInfo("Minimum limit type of FixedMinimum is not supported in the current version. Exiting...")
              return false
            elsif minlimittype.eql?('ProportionalMinimum')
              runner.registerInfo("Minimum limit type of ProportionalMinimum is supported. Adding EMS...")

              # Create new EnergyManagementSystem:Sensor object  
              ems_oa_mech_mfr = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Air System Outdoor Air Mechanical Ventilation Requested Mass Flow Rate")
              ems_oa_mech_mfr.setName("min1_#{controlleroutdoorair.name.to_s.gsub(/\s+/, "").downcase}")
              ems_oa_mech_mfr.setKeyName("9 ZONE PVAV") #TODO: find systematic way to find key
              if verbose_info_statements == true
                runner.registerInfo("EMS Sensor named #{ems_oa_mech_mfr.name} added")
              end

              # Create new EnergyManagementSystem:InternalVariable object 
              ems_oa_min_mfr = OpenStudio::Model::EnergyManagementSystemInternalVariable.new(model, "Outdoor Air Controller Minimum Mass Flow Rate")
              ems_oa_min_mfr.setName("min2_#{controlleroutdoorair.name.to_s.gsub(/\s+/, "").downcase}")
              ems_oa_min_mfr.setInternalDataIndexKeyName("#{controlleroutdoorair.name.to_s}")
              ems_oa_min_mfr.setInternalDataType("Outdoor Air Controller Minimum Mass Flow Rate")
              if verbose_info_statements == true
                runner.registerInfo("EMS Internal Variable named #{ems_oa_min_mfr.name} added")
              end

              # create new EnergyManagementSystem:Program object describing the zone temp averaging algorithm
              ems_oa_override = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
              ems_oa_override.setName("PRGM_#{controlleroutdoorair.name.to_s.gsub(/\s+/, "").downcase}")
              ems_oa_override.addLine("Set min_oa_ref1 = min1_#{controlleroutdoorair.name.to_s.gsub(/\s+/, "").downcase}")
              ems_oa_override.addLine("Set min_oa_ref2 = min2_#{controlleroutdoorair.name.to_s.gsub(/\s+/, "").downcase}")
              ems_oa_override.addLine("Set oa_override_#{controlleroutdoorair.name.to_s.gsub(/\s+/, "").downcase} = min_oa_ref1")
              if verbose_info_statements == true
                runner.registerInfo("EMS Program named #{ems_oa_override.name} was added")
              end

              # create EnergyManagementSystem:ProgramCallingManager object
              ems_program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
              ems_program_calling_manager.setName("PCM_#{controlleroutdoorair.name.to_s.gsub(/\s+/, "").downcase}")
              ems_program_calling_manager.setCallingPoint("InsideHVACSystemIterationLoop")
              ems_program_calling_manager.addProgram(ems_oa_override)
              if verbose_info_statements == true
                runner.registerInfo("EMS Program Calling Manager named #{ems_program_calling_manager.name} was added")
              end

              # create EMS actuator object 
              ems_oa_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(controlleroutdoorair,"Outdoor Air Controller","Air Mass Flow Rate")
              ems_oa_actuator.setName("oa_override_#{controlleroutdoorair.name.to_s.gsub(/\s+/, "").downcase}")
              if verbose_info_statements == true
                runner.registerInfo("EMS Actuator object named #{ems_oa_actuator.name} was added") 
              end

              # create global EnergyManagementSystem:OutputVariable object
              ems_ov1 = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, 'min_oa_ref1')
              ems_ov1.setName("min_oa_ref1") 
              ems_ov1.setEMSVariableName("min_oa_ref1")
              ems_ov1.setTypeOfDataInVariable("Averaged")
              ems_ov1.setUpdateFrequency("SystemTimestep")
              ems_ov1.setEMSProgramOrSubroutineName(ems_oa_override) 
              if verbose_info_statements == true
                runner.registerInfo("EMS Output Variable object named #{ems_ov1.name} was added")
              end

              # create global EnergyManagementSystem:OutputVariable object
              ems_ov2 = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, 'min_oa_ref2')
              ems_ov2.setName("min_oa_ref2") 
              ems_ov2.setEMSVariableName("min_oa_ref2")
              ems_ov2.setTypeOfDataInVariable("Averaged")
              ems_ov2.setUpdateFrequency("SystemTimestep")    
              ems_ov2.setEMSProgramOrSubroutineName(ems_oa_override)
              if verbose_info_statements == true
                runner.registerInfo("EMS Output Variable object named #{ems_ov2.name} was added")
              end

              # create global EnergyManagementSystem:OutputVariable object
              ems_ov3 = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, "oa_override_#{controlleroutdoorair.name.to_s.gsub(/\s+/, "").downcase}")
              ems_ov3.setName("oa_override_#{controlleroutdoorair.name.to_s.gsub(/\s+/, "").downcase}") 
              ems_ov3.setEMSVariableName("oa_override_#{controlleroutdoorair.name.to_s.gsub(/\s+/, "").downcase}")
              ems_ov3.setTypeOfDataInVariable("Averaged")
              ems_ov3.setUpdateFrequency("SystemTimestep")    
              ems_ov3.setEMSProgramOrSubroutineName(ems_oa_override)
              if verbose_info_statements == true
                runner.registerInfo("EMS Output Variable object named #{ems_ov3.name} was added")
              end

              # create new OutputVariable object
              output_variable1 = OpenStudio::Model::OutputVariable.new("min_oa_ref1",model)
              output_variable1.setKeyValue("*")
              output_variable1.setReportingFrequency("Timestep") 
              output_variable1.setVariableName("min_oa_ref1")
              if verbose_info_statements == true
                runner.registerInfo("OutputVariable named #{output_variable1.name} was added")
              end

              # create new OutputVariable object
              output_variable2 = OpenStudio::Model::OutputVariable.new("min_oa_ref2",model)
              output_variable2.setKeyValue("*")
              output_variable2.setReportingFrequency("Timestep") 
              output_variable2.setVariableName("min_oa_ref2")
              if verbose_info_statements == true
                runner.registerInfo("OutputVariable named #{output_variable2.name} was added")
              end

              # create new OutputVariable object
              output_variable3 = OpenStudio::Model::OutputVariable.new("oa_override_#{controlleroutdoorair.name.to_s.gsub(/\s+/, "").downcase}",model)
              output_variable3.setKeyValue("*")
              output_variable3.setReportingFrequency("Timestep") 
              output_variable3.setVariableName("oa_override_#{controlleroutdoorair.name.to_s.gsub(/\s+/, "").downcase}")
              if verbose_info_statements == true
                runner.registerInfo("OutputVariable named #{output_variable3.name} was added")
              end


              # how to get AirLoopHVAC name to use as a key?
              testings = model.getAirLoopHVACs
              testings.each do |testing|
                keyname = testing.name
                runner.registerInfo("TESTING = #{keyname}")
              end

            end
          end
        end
      end
    end
  
    runner.registerFinalCondition("Measure finished with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")
    return true
    
  end # end run method
  
end # end class

# register the measure to be used by the application
EconomizerNotEconomizing.new.registerWithApplication


