# This ruby script contains functions that transfers parameters
# from the curves defined in EnergyPlus to EnergyPlus Measure script
# for the creation of EnergyManagementSystem script

# define function to get parameters from biquadratic curves
def para_biquadratic(curvebiquadratics, curve_name)
  para = []
  no_curve = true
  curvebiquadratics.each do |curvebiquadratic|
    if curvebiquadratic.getString(0).to_s.eql?(curve_name)
      (1..6).each do |ii|
        para << curvebiquadratic.getString(ii).to_s
      end
      no_curve = false
      break
    end
  end
  return curve_name, para, no_curve
end

# define function to get parameters from biquadratic curves, including limits to x and y
def para_biquadratic_limit(curvebiquadratics, curve_name)
  para = []
  no_curve = true
  curvebiquadratics.each do |curvebiquadratic|
    if curvebiquadratic.getString(0).to_s.eql?(curve_name)
      (1..10).each do |i|
        para << curvebiquadratic.getString(i).to_s
      end
      no_curve = false
      break
    end
  end
  return curve_name, para, no_curve
end
