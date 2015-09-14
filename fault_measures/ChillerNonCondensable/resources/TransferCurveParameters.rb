#This ruby script contains functions that transfers parameters
#from the curves defined in EnergyPlus to EnergyPlus Measure script
#for the creation of EnergyManagementSystem script

#define function to get parameters from biquadratic curves
def para_biquadratic(curvebiquadratics, curve_name)
  para = []
  no_curve = true
  curvebiquadratics.each do |curvebiquadratic|
    if curvebiquadratic.getString(0).to_s.eql?(curve_name)
      para << curvebiquadratic.getString(1).to_s
      para << curvebiquadratic.getString(2).to_s
      para << curvebiquadratic.getString(3).to_s
      para << curvebiquadratic.getString(4).to_s
      para << curvebiquadratic.getString(5).to_s
      para << curvebiquadratic.getString(6).to_s
      no_curve = false
      break
    end
  end
  return curve_name, para, no_curve
end

#define function to get parameters from biquadratic curves, including limits to x and y
def para_biquadratic_limit(curvebiquadratics, curve_name)
  para = []
  no_curve = true
  curvebiquadratics.each do |curvebiquadratic|
    if curvebiquadratic.getString(0).to_s.eql?(curve_name)
      for i in 1..10
        para << curvebiquadratic.getString(i).to_s
      end
      no_curve = false
      break
    end
  end
  return curve_name, para, no_curve
end