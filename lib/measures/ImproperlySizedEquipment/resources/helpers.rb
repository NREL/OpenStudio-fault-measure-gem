require 'openstudio'

class Helper
  def self.change_rated_capacity(object, sizing_ratio, runner)
    object = to_real_openstudio_class(object)
    mth = CLASS_METHODS[object.class]
    mth.call(object, sizing_ratio, runner) unless mth.is_a? String
  end

  def self.to_real_openstudio_class(object)
    class_name = object.iddObjectType.valueDescription
    conv_meth = 'to_' << class_name.gsub(/^OS/, '').gsub(':', '').gsub('_', '')
    object = object.send(conv_meth)
    return if object.empty?
    return object.get
  end

  def self.changeratedcapacity1(object, sizing_ratio, runner)
    # works for
    # CoilCoolingDXSingleSpeed
    # CoilCoolingDXVariableRefrigerantFlow
    autosized = object.isRatedTotalCoolingCapacityAutosized
    if autosized
      runner.registerInfo("Capacity of coil (#{object.name}) is autosized, skipping..")
    else
      value_before_cap = object.ratedTotalCoolingCapacity.to_f
      value_after_cap = value_before_cap * sizing_ratio

      object.setRatedTotalCoolingCapacity(value_after_cap)
      #object.setRatedAirFlowRate(value_after_flow)

      runner.registerInfo("Capacity of coil (#{object.name}) changed from #{value_before_cap.round(2)} W to #{value_after_cap.round(2)} W (#{(sizing_ratio*100).round(0)}% of previous).")
    end
  end

  def self.changeratedcapacity2(object, sizing_ratio, runner)
    # works for
    # CoilCoolingDXTwoStageWithHumidityControlMode (CoilPerformanceDXCooling)
    
    if !(object.normalModeStage1CoilPerformance.empty? && object.normalModeStage1Plus2CoilPerformance.empty?)
      perf1 = object.normalModeStage1CoilPerformance.get
      perf2 = object.normalModeStage1Plus2CoilPerformance.get
      autosized1 = perf1.isGrossRatedTotalCoolingCapacityAutosized
      autosized2 = perf2.isGrossRatedTotalCoolingCapacityAutosized
      if autosized1
        runner.registerInfo("Capacity of coil (#{object.name}: #{perf1.name}) is autosized, skipping..")
      elsif autosized2
        runner.registerInfo("Capacity of coil (#{object.name}: #{perf2.name}) is autosized, skipping..")
      else
        value_before_cap1 = perf1.grossRatedTotalCoolingCapacity.to_f
        value_before_cap2 = perf2.grossRatedTotalCoolingCapacity.to_f
        value_after_cap1 = value_before_cap1 * sizing_ratio
        value_after_cap2 = value_before_cap2 * sizing_ratio
        perf1.setGrossRatedTotalCoolingCapacity(value_after_cap1)
        perf2.setGrossRatedTotalCoolingCapacity(value_after_cap2)
        runner.registerInfo("Capacity of coil (#{perf1.name}: #{value_before_cap1.round(2)} W --> #{value_after_cap1.round(2)} W / #{perf2.name}: #{value_before_cap2.round(2)} W --> #{value_after_cap2.round(2)} W) (#{(sizing_ratio*100).round(0)}% of previous).")
      end
    end		
  end

  def self.changeratedcapacity3(object, sizing_ratio, runner)
    # works for
    # CoilCoolingDXTwoSpeed

    autosized1 = object.autosizedRatedHighSpeedTotalCoolingCapacity
    autosized2 = object.autosizedRatedLowSpeedTotalCoolingCapacity
    if autosized1
      runner.registerInfo("Capacity of coil (#{object.name}_high) is autosized, skipping..")

      value_before_cap2 = object.ratedLowSpeedTotalCoolingCapacity.to_f
      value_after_cap2 = value_before_cap2 * sizing_ratio

      runner.registerInfo("Capacity of coil (#{object.name}) changed from #{value_before_cap2.round(2)} W to #{value_after_cap2.round(2)} W (low) (#{(sizing_ratio*100).round(0)}% of previous).")
    elsif autosized2
      runner.registerInfo("Capacity of coil (#{object.name}_low) is autosized, skipping..")
      
      value_before_cap1 = object.ratedHighSpeedTotalCoolingCapacity.to_f
      value_after_cap1 = value_before_cap1 * sizing_ratio
      
      runner.registerInfo("Capacity of coil (#{object.name}) changed from #{value_before_cap1.round(2)} W to #{value_after_cap1.round(2)} W (high) (#{(sizing_ratio*100).round(0)}% of previous).")
    else
      value_before_cap1 = object.ratedHighSpeedTotalCoolingCapacity.to_f
      value_after_cap1 = value_before_cap1 * sizing_ratio

      value_before_cap2 = object.ratedLowSpeedTotalCoolingCapacity.to_f
      value_after_cap2 = value_before_cap2 * sizing_ratio

      object.setRatedHighSpeedTotalCoolingCapacity(value_after_cap1)
      object.setRatedLowSpeedTotalCoolingCapacity(value_after_cap2)

      runner.registerInfo("Capacity of coil (#{object.name}) changed from #{value_before_cap1.round(2)} W to #{value_after_cap1.round(2)} W (high) and from #{value_before_cap2.round(2)} W to #{value_after_cap2.round(2)} W (low) (#{(sizing_ratio*100).round(0)}% of previous).")
    end 
  end

  def self.changeratedcapacity4(object, sizing_ratio, runner)
    # works for
    # CoilHeatingDXVariableRefrigerantFlow

    autosized = object.isRatedTotalHeatingCapacityAutosized
    if autosized
      runner.registerInfo("Capacity of coil (#{object.name}) is autosized, skipping..")
    else
      value_before_cap = object.ratedTotalHeatingCapacity.to_f
      value_after_cap = value_before_cap * sizing_ratio

      object.setRatedTotalHeatingCapacity(value_after_cap)

      runner.registerInfo("Capacity of coil (#{object.name}) changed from #{value_before_cap.round(2)} W to #{value_after_cap.round(2)} W (#{(sizing_ratio*100).round(0)}% of previous).")
    end
  end

  def self.changeratedcapacity5(object, sizing_ratio, runner)
    #works for
    #CoilHeatingGas
    #CoilHeatingElectric
    
    autosized = object.isNominalCapacityAutosized
    if autosized
      runner.registerInfo("Capacity of coil (#{object.name}) is autosized, skipping..")
    else
      value_before_cap = object.nominalCapacity.to_f
      value_after_cap = value_before_cap * sizing_ratio
      
      object.setNominalCapacity(value_after_cap)
      
      runner.registerInfo("Capacity of coil (#{object.name}) changed from #{value_before_cap.round(2)} W to #{value_after_cap.round(2)} W (#{(sizing_ratio*100).round(0)}% of previous).")
    end
  end

  def self.change_rated_capacity_fans(object, sizing_ratio, runner)
    if object.isMaximumFlowRateAutosized
      runner.registerInfo("Capacity of fan (#{object.name}) is autosized, skipping..")
    else
      value_before_cap = object.maximumFlowRate.get.to_f
      value_after_cap = value_before_cap * sizing_ratio

      object.setMaximumFlowRate(value_after_cap)

      runner.registerInfo("Capacity of fan (#{object.name}) changed from #{value_before_cap.round(2)} cfm to #{value_after_cap.round(2)} cfm (#{sizing_ratio*100.round(0)}% of previous).")
    end
  end

  def self.get_all_equipment_objects(model)
    equip_objs = []
    CLASS_METHODS.keys.each do |cls|
      class_name = cls.iddObjectType.valueDescription
      get_meth = 'get' << class_name.gsub(/^OS/, '').gsub(':', '').gsub('_', '') << 's'
      objects = model.send(get_meth)
      equip_objs += objects
    end
    return equip_objs
  end
  CLASS_METHODS = { #OpenStudio::Model::CoilHeatingWater => '',
                    OpenStudio::Model::CoilHeatingGas => method(:changeratedcapacity5),
                    OpenStudio::Model::CoilHeatingElectric => method(:changeratedcapacity5),
                    #OpenStudio::Model::CoilHeatingDXSingleSpeed => '',
                    OpenStudio::Model::CoilHeatingDXVariableRefrigerantFlow => method(:changeratedcapacity4),
                    #OpenStudio::Model::CoilCoolingWater => '',
                    OpenStudio::Model::CoilCoolingDXSingleSpeed => method(:changeratedcapacity1),
                    OpenStudio::Model::CoilCoolingDXTwoSpeed => method(:changeratedcapacity3),
                    OpenStudio::Model::CoilCoolingDXTwoStageWithHumidityControlMode => method(:changeratedcapacity2),
                    OpenStudio::Model::CoilCoolingDXVariableRefrigerantFlow => method(:changeratedcapacity1),
                    OpenStudio::Model::FanOnOff => method(:change_rated_capacity_fans),
                    OpenStudio::Model::FanConstantVolume => method(:change_rated_capacity_fans),
                    OpenStudio::Model::FanVariableVolume => method(:change_rated_capacity_fans) }.freeze
end
