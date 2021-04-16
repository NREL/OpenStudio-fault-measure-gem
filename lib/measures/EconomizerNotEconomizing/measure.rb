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
$faultnow = 'ENE'

# start the measure
class EconomizerNotEconomizing < OpenStudio::Measure::ModelMeasure

  # human readable name
  def name
    return "Economizer Not Economizing"
  end

  # human readable description
  def description
    return "This fault model simulates a situation where economizer is not economizing when it is supposed to. Not leveraging favorable outdoor air when it is available will result in increased cooling end-use energy consumption."
  end

  # human readable description of modeling approach
  def modeler_description
    return "This fault model uses the EMS by overriding 'Air Mass Flow Rate' control type in 'Outdoor Air Controller' actuator with minimum outdoor air requirement. User can also specify when to initiate fault by defining starting month, date, and time. This version is currently not supporting fault ending timing even though input arguments are implemented in the measure."
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

    #make a double argument for the start month
    start_month = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_month', false)
    start_month.setDisplayName('Enter the month (1-12) when the fault starts to occur')
    start_month.setDefaultValue(1)  #default is June
    args << start_month
	
	  #make a double argument for the start date
    start_date = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_date', false)
    start_date.setDisplayName('Enter the date (1-28/30/31) when the fault starts to occur')
    start_date.setDefaultValue(1)  #default is 1st day of the month
    args << start_date
	
	  #make a double argument for the start time
    start_time = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('start_time', false)
    start_time.setDisplayName('Enter the time of day (0-24) when the fault starts to occur')
    start_time.setDefaultValue(0)  #default is 9am
    args << start_time
	
	  #make a double argument for the end month
    end_month = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('end_month', false)
    end_month.setDisplayName('Enter the month (1-12) when the fault ends')
    end_month.setDefaultValue(12)  #default is Decebmer
    args << end_month
	
	  #make a double argument for the end date
    end_date = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('end_date', false)
    end_date.setDisplayName('Enter the date (1-28/30/31) when the fault ends')
    end_date.setDefaultValue(31)  #default is last day of the month
    args << end_date
	
	  #make a double argument for the end time
    end_time = OpenStudio::Ruleset::OSArgument::makeDoubleArgument('end_time', false)
    end_time.setDisplayName('Enter the time of day (0-24) when the fault ends')
    end_time.setDefaultValue(24)  #default is 11pm
    args << end_time
    
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
    start_month = runner.getDoubleArgumentValue('start_month',user_arguments)
    start_date = runner.getDoubleArgumentValue('start_date',user_arguments)
    start_time = runner.getDoubleArgumentValue('start_time',user_arguments)
    end_month = runner.getDoubleArgumentValue('end_month',user_arguments)
    end_date = runner.getDoubleArgumentValue('end_date',user_arguments)
    end_time = runner.getDoubleArgumentValue('end_time',user_arguments)	
    time_interval = model.getTimestep.numberOfTimestepsPerHour
    time_step = (1./(time_interval.to_f))
  
    runner.registerInitialCondition("Measure began with #{model.getEnergyManagementSystemSensors.count} EMS sensors, #{model.getEnergyManagementSystemActuators.count} EMS Actuators, #{model.getEnergyManagementSystemPrograms.count} EMS Programs, #{model.getEnergyManagementSystemSubroutines.count} EMS Subroutines, #{model.getEnergyManagementSystemProgramCallingManagers.count} EMS Program Calling Manager objects")
        
    controlleroutdoorairs = model.getControllerOutdoorAirs
    controlleroutdoorairs.each do |controlleroutdoorair|
      if controlleroutdoorair.name.to_s.eql?(econ_choice) || econ_choice.eql?($allchoices)
        if verbose_info_statements == true
          runner.registerInfo("Imposing fault in Controller:OutdoorAir object #{controlleroutdoorair.name}.")
          runner.registerInfo("Imposing fault which occurs on #{start_month.to_i}/#{start_date.to_i} at #{start_time.to_i}:00 and which disappears on #{end_month.to_i}/#{end_date.to_i} at #{end_time.to_i}:00")

          # check if Controller:OutdoorAir object configurations
          controltype = controlleroutdoorair.getEconomizerControlType
          controlactiontype = controlleroutdoorair.getEconomizerControlActionType
          lockouttype = controlleroutdoorair.getLockoutType
          minlimittype = controlleroutdoorair.getMinimumLimitType
          highhumcontrol = controlleroutdoorair.getHighHumidityControl
          minoaschedule = controlleroutdoorair.minimumOutdoorAirSchedule
          str_indicator = controlleroutdoorair.name.to_s.gsub(/\s+/, "").downcase

          runner.registerInfo("Economizer configuration: ControlType = #{controltype}")
          runner.registerInfo("Economizer configuration: ControlActionType = #{controlactiontype}")
          runner.registerInfo("Economizer configuration: LockoutType = #{lockouttype}")
          runner.registerInfo("Economizer configuration: MinimumLimitType = #{minlimittype}")
          # runner.registerInfo("Economizer configuration: HighHumidityControl = #{highhumcontrol}")
          name_airloophvac = controlleroutdoorair.airLoopHVACOutdoorAirSystem.get.airLoopHVAC.get.name.to_s
          runner.registerInfo("Economizer configuration: AirLoopHVAC = #{name_airloophvac}")

          # TODO: add additional logics for different configuration settings
          if controltype.eql?('NoEconomizer')
            runner.registerInfo("Control type of NoEconomizer is not supported. Exiting...")
            return false
          else

            if minlimittype.eql?('FixedMinimum')

              # Create new EnergyManagementSystem:InternalVariable object 
              ems_oa_min_mfr = OpenStudio::Model::EnergyManagementSystemInternalVariable.new(model, "Outdoor Air Controller Minimum Mass Flow Rate")
              ems_oa_min_mfr.setName("min_#{str_indicator}")
              ems_oa_min_mfr.setInternalDataIndexKeyName("#{controlleroutdoorair.name.to_s}")
              ems_oa_min_mfr.setInternalDataType("Outdoor Air Controller Minimum Mass Flow Rate")
              if verbose_info_statements == true
                runner.registerInfo("EMS Internal Variable named #{ems_oa_min_mfr.name} was added")
              end

            elsif minlimittype.eql?('ProportionalMinimum') 

              # Create new EnergyManagementSystem:Sensor object  
              ems_oa_min_mfr = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Air System Outdoor Air Mechanical Ventilation Requested Mass Flow Rate")
              ems_oa_min_mfr.setName("min_#{str_indicator}")
              ems_oa_min_mfr.setKeyName(name_airloophvac)
              if verbose_info_statements == true
                runner.registerInfo("EMS Sensor named #{ems_oa_min_mfr.name} added")
              end

            end

            # Create new EnergyManagementSystem:Sensor object
            ems_min_oa_sch = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Schedule Value")
            ems_min_oa_sch.setName("min_oa_sch_#{str_indicator}")
            ems_min_oa_sch.setKeyName("#{minoaschedule.get.name}")
            if verbose_info_statements == true
              runner.registerInfo("EMS Sensor named #{ems_min_oa_sch.name} was added") 
            end

            # # Create new EnergyManagementSystem:Sensor object
            # ems_ori_oa = OpenStudio::Model::EnergyManagementSystemSensor.new(model, "Air System Outdoor Air Mass Flow Rate")
            # ems_ori_oa.setName("ori_oa_#{str_indicator}")
            # ems_ori_oa.setKeyName(name_airloophvac)
            # if verbose_info_statements == true
            #   runner.registerInfo("EMS Sensor named #{ems_ori_oa.name} was added") 
            # end

            # create new EnergyManagementSystem:Program object describing the zone temp averaging algorithm
            ems_oa_override = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
            ems_oa_override.setName("PRGM_#{str_indicator}")
            # ems_oa_override.addLine("SET ori_oa_#{str_indicator} = ori_oa_#{str_indicator}")
            ems_oa_override.addLine("SET min_oa_ref_#{str_indicator} = min_#{str_indicator}")
            ems_oa_override.addLine("SET min_oa_sch_#{str_indicator} = min_oa_sch_#{str_indicator}")
            ems_oa_override.addLine("SET SM = #{start_month}")
            ems_oa_override.addLine("SET SD = #{start_date}")
            ems_oa_override.addLine("SET ST = #{start_time}")
            ems_oa_override.addLine("SET EM = #{end_month}")
            ems_oa_override.addLine("SET ED = #{end_date}")
            ems_oa_override.addLine("SET ET = #{end_time}")
            ems_oa_override.addLine("SET ut_start = SM*10000 + SD*100 + ST")
            ems_oa_override.addLine("SET ut_end = EM*10000 + ED*100 + SD")
            ems_oa_override.addLine("SET ut_actual = Month*10000 + DayOfMonth*100 + CurrentTime")
            # ems_oa_override.addLine("IF (ut_start<=ut_actual) && (ut_end>=ut_actual)") #TODO: terminating (and make it back to normal) is not working currently
            ems_oa_override.addLine("IF (ut_start<=ut_actual)")
            ems_oa_override.addLine("SET oa_override_#{str_indicator} = min_oa_ref_#{str_indicator}*min_oa_sch_#{str_indicator}")
            # ems_oa_override.addLine("ELSE")
            # ems_oa_override.addLine("SET oa_override_#{str_indicator} = ori_oa_#{str_indicator}")
            ems_oa_override.addLine("ENDIF")
            if verbose_info_statements == true
              runner.registerInfo("EMS Program named #{ems_oa_override.name} was added")
            end

            # create EnergyManagementSystem:ProgramCallingManager object
            ems_program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
            ems_program_calling_manager.setName("PCM_#{str_indicator}")
            ems_program_calling_manager.setCallingPoint("InsideHVACSystemIterationLoop")
            ems_program_calling_manager.addProgram(ems_oa_override)
            if verbose_info_statements == true
              runner.registerInfo("EMS Program Calling Manager named #{ems_program_calling_manager.name} was added")
            end

            # create EMS actuator object 
            ems_oa_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(controlleroutdoorair,"Outdoor Air Controller","Air Mass Flow Rate")
            ems_oa_actuator.setName("oa_override_#{str_indicator}")
            if verbose_info_statements == true
              runner.registerInfo("EMS Actuator object named #{ems_oa_actuator.name} was added") 
            end

            # create global EnergyManagementSystem:OutputVariable object
            ems_ov1 = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, "min_oa_ref_#{str_indicator}")
            ems_ov1.setName("min_oa_ref_#{str_indicator}") 
            ems_ov1.setEMSVariableName("min_oa_ref_#{str_indicator}")
            ems_ov1.setTypeOfDataInVariable("Averaged")
            ems_ov1.setUpdateFrequency("SystemTimestep")
            ems_ov1.setEMSProgramOrSubroutineName(ems_oa_override) 
            if verbose_info_statements == true
              runner.registerInfo("EMS Output Variable object named #{ems_ov1.name} was added")
            end

            # create global EnergyManagementSystem:OutputVariable object
            ems_ov2 = OpenStudio::Model::EnergyManagementSystemOutputVariable.new(model, "oa_override_#{str_indicator}")
            ems_ov2.setName("oa_override_#{str_indicator}") 
            ems_ov2.setEMSVariableName("oa_override_#{str_indicator}")
            ems_ov2.setTypeOfDataInVariable("Averaged")
            ems_ov2.setUpdateFrequency("SystemTimestep")    
            ems_ov2.setEMSProgramOrSubroutineName(ems_oa_override)
            if verbose_info_statements == true
              runner.registerInfo("EMS Output Variable object named #{ems_ov2.name} was added")
            end

            # create new OutputVariable object
            output_variable1 = OpenStudio::Model::OutputVariable.new("min_oa_ref_#{str_indicator}",model)
            output_variable1.setKeyValue("*")
            output_variable1.setReportingFrequency("Timestep") 
            output_variable1.setVariableName("min_oa_ref_#{str_indicator}")
            if verbose_info_statements == true
              runner.registerInfo("OutputVariable named #{output_variable1.name} was added")
            end

            # create new OutputVariable object
            output_variable2 = OpenStudio::Model::OutputVariable.new("oa_override_#{str_indicator}",model)
            output_variable2.setKeyValue("*")
            output_variable2.setReportingFrequency("Timestep") 
            output_variable2.setVariableName("oa_override_#{str_indicator}")
            if verbose_info_statements == true
              runner.registerInfo("OutputVariable named #{output_variable2.name} was added")
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


