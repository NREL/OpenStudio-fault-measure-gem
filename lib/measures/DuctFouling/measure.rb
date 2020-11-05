# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide

require "#{File.dirname(__FILE__)}/resources/entercoefficients_DF"

$allahuchoice = '* ALL AHUs *'

# start the measure
class DuctFouling < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return 'Duct Fouling'
  end

  # human readable description
  def description
    return "Ducts are fouled by dust that accumulates in the filter and/or fins of heat exchangers in the indoor air ducts. The accumulation increases the flow resistance of the air duct and changes the airflow and pressure drop across the duct in accordance with the controls of the fan rotational speed. This fault is categorized as a fault that occur in the ventilation system during the operation stage. This fault measure is based on an empirical model and simulates duct fouling by modifying either Fan:ConstantVolume, Fan:VariableVolume, Fan:OnOff, or Fan:VariableVolume objects in EnergyPlus assigned to the air system. F is the fault intensity defined as the reduction in evaporator coil airflow at full load condition as a ratio of the design airflow rate with the application range of 0 to 0.5 (50% reduction)."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Two additional user inputs are required. Based on these user inputs, the maximum supply airflow rate parameter defined in fan objects is replaced based on equation, mdot_(a,max,F) = mdot_(a,max)∙(1-F), where mdot_(a,max,F) is the maximum airflow rate of the faulted condition, mdot_(a,max) is the maximum airflow rate under normal conditions, and F is the fault intensity defined as the reduction in evaporator coil airflow at full load condition as a ratio of the design airflow rate.  There is a pressure rise (r_pd) parameter that is also required in fan objects in order to properly reflect evaporator fouling. Equation, F = 1-√((1+r_pd-c_F)/(1-c_F ))  shows the relation between F and r_pd that is used to calculate the pressure rise based on the fault intensity level. cF is the coefficient that is determined based on the training data set."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # find all the airloop objects
    airloophvacs = model.getAirLoopHVACs
    chs = OpenStudio::StringVector.new
    chs << $allahuchoice
    airloophvacs.each do |airloophvac|
      chs << airloophvac.name.to_s
    end
    equip_name = OpenStudio::Ruleset::OSArgument.makeChoiceArgument('equip_name', chs, true)  #  use the names for choices of equipment
    equip_name.setDisplayName('Choice of AirLoopHVAC objects. If you want to impose it on all AHUs, choose * ALL AHUs *')
    equip_name.setDefaultValue($allahuchoice)
    args << equip_name
    
    # ask user for a fault level in terms of the percentage of mass flow rate reduction
    flow_decrease_ratio = OpenStudio::Ruleset::OSArgument.makeDoubleArgument('flow_decrease_ratio', true)
    flow_decrease_ratio.setDefaultValue(0.1)
    flow_decrease_ratio.setDisplayName('Decrease of air mass flow rate ratio when the fans are running at their maximum speed (0-1). (-)')
    args << flow_decrease_ratio
    
    #make double arguments to obtain coefficients
    args = enter_coefficients(args, 1, 'fanCurve', [1.4048])

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    unless runner.validateUserArguments(arguments(model), user_arguments)
      return false 
    end

    # assign the user inputs to variables
    equip_name = runner.getStringArgumentValue('equip_name', user_arguments)
    flow_decrease_ratio = (runner.getDoubleArgumentValue('flow_decrease_ratio', user_arguments))
    coeff = runner_pass_coefficients(runner, user_arguments, 1, 'fanCurve')

    # check the flow_decrease_ratio for reasonableness
    if flow_decrease_ratio < 0.0
      runner.registerError("User defined fouling level in Measure #{name} is negative. Exiting......")
      return false
    elsif flow_decrease_ratio >= 1.0
      runner.registerError("The resultant mass flow rate in Measure #{name} is negative. Exiting......")
      return false
    elsif flow_decrease_ratio == 0.0
      runner.registerAsNotApplicable("Fouling level is zero. Skipping the Measure #{name}")
      return true
    end

    # report initial condition of model
    allahus = false
    if equip_name.eql?($allahuchoice)
      runner.registerInitialCondition('Fouling are being applied on all AHUs......')
      allahus = true
    else
      runner.registerInitialCondition("Fouling is being applied to the #{equip_name}......")
    end
    
    # locate the airloop
    airloophvacs = model.getAirLoopHVACs
    chs = OpenStudio::StringVector.new
    found = false
    fan_found = false
    airloophvacs.each do |airloophvac|
      if airloophvac.name.to_s.eql?(equip_name) || allahus
        found = true
        # find all fan objects in the equipment
        # loop over all OS:Fan:ConstantVolume objects, OS:Fan:VariableVolume objects and OS:Fan:OnOff objects
        fanconstantvolumes = airloophvac.supplyComponents("OS:Fan:ConstantVolume".to_IddObjectType)
        if !fanconstantvolumes.empty?
          fanconstantvolumes.each do |fan|
            fan = fan.to_FanConstantVolume.get # transferring from ModelObject Class to FanConstantVolume Class
            runner.registerInfo("Processsing #{fan.name.to_s}")
            if fan.isMaximumFlowRateAutosized
              runner.registerInfo("#{fan.name.to_s} is not hard sized by other measures. Skipping......")
            else
              # change the maximum flow rate condition with the given fan curve
              delta_P = fan.pressureRise
              #delta_P = delta_P*(1+((1.-coeff[0])*flow_decrease_ratio*(flow_decrease_ratio-2)))
              delta_P = delta_P*(coeff[0]+(1-coeff[0])*(1-flow_decrease_ratio)*(1-flow_decrease_ratio))
              max_flow = fan.getMaximumFlowRate
              max_flow = max_flow.get
              max_flow = max_flow*(1.-flow_decrease_ratio)
              fan.setMaximumFlowRate(max_flow)
              fan.setPressureRise(delta_P)
              runner.registerInfo("#{fan.name.to_s} has its rated condition altered for fouling.")
            end
            fan_found = true
          end
        end
        fanvariablevolumes = airloophvac.supplyComponents("OS:Fan:VariableVolume".to_IddObjectType)
        if !fanvariablevolumes.empty?
          fanvariablevolumes.each do |fan|
            fan = fan.to_FanVariableVolume.get # transferring from ModelObject Class to FanConstantVolume Class
            runner.registerInfo("Processsing #{fan.name.to_s}")
            if fan.isMaximumFlowRateAutosized
              runner.registerInfo("#{fan.name.to_s} is not hard sized by other measures. Skipping......")
            else
              # change the maximum flow rate condition with the given fan curve
              # variables defined in a little bit different way to facilitate future modification
              old_delta_P = fan.pressureRise
              old_max_flow = fan.getMaximumFlowRate
			  ###############################################
			  old_min_v = fan.fanPowerMinimumAirFlowRate.get
              old_max_flow = old_max_flow.get.value
              max_flow = old_max_flow*(1.-flow_decrease_ratio)
			  if max_flow >= old_min_v
			    fan.setMaximumFlowRate(max_flow)
				delta_P = old_delta_P*(coeff[0]+(1-coeff[0])*(1-flow_decrease_ratio)*(1-flow_decrease_ratio))
                fan.setPressureRise(delta_P)
                runner.registerInfo("#{fan.name.to_s} maximum flow becomes #{max_flow.round(3)} m3/s from #{old_max_flow.round(3)} m3/s.")
			  else
                fan.setMaximumFlowRate(old_min_v)
				maxminratio = (max_flow-old_min_v)/max_flow
				delta_P = old_delta_P*(coeff[0]+(1-coeff[0])*(1-maxminratio)*(1-maxminratio))
                fan.setPressureRise(delta_P)
                runner.registerInfo("Reduced maximum flow (#{max_flow.round(3)} m3/s) is lower than the specified minimum flow (#{old_min_v.round(3)} m3/s). Modified maximum flow in #{fan.name.to_s} is overriden to specified minimum flow of #{old_min_v.round(3)} m3/s.")
			  end	
			  ###############################################
              
              # fix the flow rate corresponding to the minimum power consumption
              # get f_pl coefficients
              c = []
              (1..5).each do |count|
                  temp = fan.send("fanPowerCoefficient#{count}")
                  if temp
                    c << temp.get
                  else
                    c << 0.0
                  end
              end
              eff = fan.fanEfficiency
              rho_a = 1.2 # arbitrary
              min_flow_method = fan.fanPowerMinimumFlowRateInputMethod
              if min_flow_method.eql?("FixedFlowRate")
                
                min_power = fan_power(c, old_min_v, old_max_flow, old_delta_P, eff, rho_a)
                min_v_ratio = old_min_v/old_max_flow
              else  # default is fraction
                min_v_ratio = fan.fanPowerMinimumFlowFraction
                old_min_v = min_v_ratio*old_max_flow
                min_power = fan_power(c, old_min_v, old_max_flow, old_delta_P, eff, rho_a)
              end
              # the minimum airflow corresponding to the minimum power must be lower than the
              # current minimum flow. Use bisection method
              if min_v_ratio > 0.001  #only set another min. airflow if it is significant
                # Dekker's method
                y_high = fan_power(c, old_min_v, max_flow, delta_P, eff, rho_a)-min_power #should be higher
                # find y_low
                mulp = 0.95
                y_low = fan_power(c, old_min_v*mulp, max_flow, delta_P, eff, rho_a)-min_power
                count = 1
                while y_low*y_high > 0.0
                  mulp = mulp*0.95
                  y_low = fan_power(c, old_min_v*mulp, max_flow, delta_P, eff, rho_a)-min_power
                  if count > 100
                    runner.registerError("Cannot find the airflow corresponding to the minimum power consumption. Exiting......")
                    return false
                  end
                  count = count+1
                end
                x_high = old_min_v
                x_low = old_min_v*mulp
                count = 1
                runner.registerInfo("y_high at #{y_high} W, y_low at #{y_low} W")
                while y_high.abs > 0.001
                  if y_low.abs < y_high.abs
                    x_temp = x_high
                    y_temp = y_high
                    x_high = x_low
                    y_high = y_low
                    x_low = x_temp
                    y_low = y_temp
                  end
                  mm = (x_high+x_low)*0.5
                  if y_high != y_low
                    ss = x_high-(x_high-x_low)/(y_high-y_low)*y_high
                  else
                    ss = mm
                  end
                  if (x_high > ss && ss > mm) || (x_high < ss && ss < mm)
                    x_new = ss
                  else
                    x_new = mm
                  end
                  y_new = fan_power(c, x_new, max_flow, delta_P, eff, rho_a)-min_power
                  if y_new*y_high < 0.0
                    y_low = y_new
                    x_low = x_new
                  else
                    y_high = y_new
                    x_high = x_new
                  end
                  count = count+1
                  if count > 100
                    runner.registerError("Dekker method fails with x_high at #{x_high}, x_low at #{x_low}, y_new at #{y_new} and mulp at #{mulp}. Exiting......")
                    return false
                  end
                end
                new_min_v = x_high
                runner.registerInfo("#{fan.name.to_s} fixes its min. power at #{min_power.round(2)} W with new min. flow at #{new_min_v.round(3)} m3/s from #{old_min_v.round(3)} m3/s.")
                if min_flow_method.eql?("FixedFlowRate")
                  fan.setFanPowerMinimumAirFlowRate(new_min_v)
                else  # default is fraction
                  fan.setFanPowerMinimumFlowFraction(new_min_v/max_flow)
                end
              end
              runner.registerInfo("#{fan.name.to_s} has its rated condition altered for fouling.")
            end
            fan_found = true
          end
        end
        fanonoffs = airloophvac.supplyComponents("OS:Fan:OnOff".to_IddObjectType)
        if !fanonoffs.empty?
          fanonoffs.each do |fan|
            fan = fan.to_FanOnOff.get # transferring from ModelObject Class to FanConstantVolume Class
            runner.registerInfo("Processsing #{fan.name.to_s}")
            if fan.isMaximumFlowRateAutosized()
              runner.registerInfo("#{fan.name.to_s} is not hard sized by other measures. Skipping......")
            else
              # change the maximum flow rate condition with the given fan curve
              # variables defined in a little bit different way to facilitate future modification
              old_delta_P = fan.pressureRise
              delta_P = old_delta_P*(1+((1.-coeff[0])*flow_decrease_ratio*(flow_decrease_ratio-2)))
              old_max_flow = fan.getMaximumFlowRate
              old_max_flow = old_max_flow.get
              max_flow = old_max_flow*(1.-flow_decrease_ratio)
              fan.setMaximumFlowRate(max_flow)
              fan.setPressureRise(delta_P)
              runner.registerInfo("#{fan.name.to_s} has its rated condition altered for fouling.")
            end
            fan_found = true
          end
        end
      end
      if found
        break
      end
    end

    # report final condition of model
    if allahus
        runner.registerFinalCondition('Fouling are applied on all AHUs......')
    else
      if fan_found
        runner.registerFinalCondition("Fouling is applied to the #{equip_name}......")
      else
        runner.registerError("No Fan objects reside in #{equip_name} to restrict the airflow. Exiting......")
        return false
      end
    end

    return true
  end
  
  # function to calculate fan power consumption for Fan:VariableVolume
  def fan_power(c, flow, max_flow, delta_P, eff, rho_a)
    ratio = flow/max_flow
    f_pl = c[0]+c[1]*ratio+c[2]*ratio**2+c[3]*ratio**3+c[4]*ratio**4
    return f_pl*max_flow*delta_P/eff/rho_a
  end
  
end

# register the measure to be used by the application
DuctFouling.new.registerWithApplication
