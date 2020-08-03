# This scipt contains functions that help converting energy cost
# into US$/US

def elec_cost_conversion(cost_per_kwh)
  # This function converts the input cost per kWh
  # into cost per J

  return cost_per_kwh/3600000
end

def gas_cost_conversion(cost_per_ccf)
  # This function converts the input cost of natural
  # gas per ccf into cost per J using the conversion
  # factor that 1 ccf contains 10.25 therm of energy

  return cost_per_ccf/10.25/105506000.0
end
