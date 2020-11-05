# ''' This is a translated version of the visual basic psych function in 
 # our xls template to a python code function psychropy()
 # The function and subfunctions defined herein come with no warranty or 
 # certification of fitness for any purpose
 # Do not use these functions for conditions outside boundaries defined 
 # by their original sources.
 # Subfunctions use equations from the following sources:
    # ASHRAE Fundamentals, 2005, SI Edition
    # Singh et al. "Numerical Calculations of Psychrometric Properties 
        # on a Calculator". Building and Environment, 37, 2002.
 # The function will calculate various properties of moist air. Properties 
 # calculated include Wet Bulb, Dew Point, Relative Humidity, Humidity 
 # Ratio, Vapor Pressure, Degree of Saturation, enthalpy, specific volume 
 # of dry air, and moist air density.
 
 # The function requires input of: barometric pressure, and two other 
 # parameters, We recomend that one of these be Tdb and if not using that 
 # the other two must be h and HR.  These parameters along with Tdb can 
 # be Twb, DP, RH, or two mentioned previously.
 # Sytax for function as follows:
 # psych(P,intype0,invalue0,intype1,invalue1,outtype,unittype)
 # Where: 
 # P is the barometric pressure in PSI or Pa .
 # intypes     indicator string for the corresponding 
                     # invalue parameter (ie Tdb, RH etc.)
 # invalues    is the actual value associated with the type of parameter 
                     # (ie value of Wet bulb, Dew point, RH, or Humidity 
                     # Ratio etc.)
 # outType     indicator string for the corresponding invalue parameter
 # unittype    is the optional unit selector.  Imp for Imperial, SI for 
                     # SI.  Imp is default if omitted. 
 # valid intypes:
 # Tdb    Dry Bulb Temp            F or C                       Valid for Input 
  # *** it is highly Recommended Tdb be used as an input (can only 
              # output/not use, if both other inputs are h and HR)
 # Twb    Web Bulb Temp            F or C                       Valid for Input
 # DP     Dew point                F or C                       Valid for input
 # RH     RH                       between 0 and 1              Valid for input
 # W      Humidity Ratio           Mass Water/ Mass Dry Air     Valid for input
 # h      Enthalpy                 BTU/lb dry air or kJ/kg DA   Valid for input
  # ***Warning 0 state for Imp is ~0F, 0% RH ,and  1 ATM, 0 state 
              # for SI is 0C, 0%RH and 1 ATM
  
  
 # valid outtypes:
 # Tdb    Dry Bulb Temp            F or C                       Valid for Input 
   # ***it is highly Recommended Tdb be used as an input (can only 
              # output/not use, if both other inputs are h and HR)
 # Twb    Web Bulb Temp            F or C                       Valid for Input
 # DP     Dew point                F or C                       Valid for input
 # RH     Relative Humidity        between 0 and 1              Valid for input
 # W      Humidity Ratio           Mass Water/ Mass Dry Air     Valid for input
 # h      Enthalpy                 BTU/lb dry air or kJ/kg DA   Valid for input
   # ***Warning 0 state for Imp is ~0F, 0% RH ,and  1 ATM, 0 state
               # for SI is 0C, 0%RH and 1 ATM
 # WVP    Water Vapor Pressure     PSI or Pa
 # Dsat   Degree of Saturation     between 0 and 1
 # s      NOT VALID, Should be entropy
 # SV     Specific Volume          ft^3/lbm or m^3/kg dry air
 # MAD    Moist Air Density        lb/ft^3 or m^3/kg
 # The corresponding numbers associated with the types in the excel VB program:
 # The Numbers for inType and outType are
 # 1 Web Bulb Temp            F or C                        Valid for Input
 # 2 Dew point                F or C                        Valid for input
 # 3 RH                       between 0 and 1               Valid for input
 # 4 Humidity Ratio           Mass Water/ Mass Dry Air      Valid for input
 # 5 Water Vapor Pressure     PSI or Pa
 # 6 Degree of Saturation     between 0 and 1
 # 7 Enthalpy                 BTU/lb dry air or kJ/kg dry air
     # Warning 0 state for IP is ~0F, 0% RH ,and  1 ATM, 0 state 
              # for SI is 0C, 0%RH and 1 ATM
 # 8 NOT VALID, Should be entropy
 # 9 Specific Volume          ft**3/lbm or m**3/kg dry air
 # 10 Moist Air Density       lb/ft**3 or m**3/kg"""
 # this python version adds the capability to use Enthalpy in the place of Tdb  
 # modified Syntax to be psychro(p,in0type,in0,in1type,in1,outtype,units)
 # where p is pressure
 # in0type is the type of the first input variable
 # in0 is the value
 # in1type is the type of the first input variable
 # in1 is the value
 # outtype is the type for the output variable
 # units is the specified units (ie Imp or SI)
 # '''


include Math

def part_press(p,w)
    
    # ''' Function to compute partial vapor pressure in [kPa]
        # From page 6.9 equation 38 in ASHRAE Fundamentals handbook (2005)
            # p = ambient pressure [kPa]
            # w = humidity ratio [kg/kg dry air]
    # '''
    result = p * w / (0.62198 + w)
    return result
end


def sat_press(tdb)

    # ''' Function to compute saturation vapor pressure in [kPa]
        # ASHRAE Fundamentals handbood (2005) p 6.2, equation 5 and 6
            # Tdb = Dry bulb temperature [degC]
            # Valid from -100C to 200 C
    # '''

    c1 = -5674.5359
    c2 = 6.3925247
    c3 = -0.009677843
    c4 = 0.00000062215701
    c5 = 2.0747825E-09
    c6 = -9.484024E-13
    c7 = 4.1635019
    c8 = -5800.2206
    c9 = 1.3914993
    c10 = -0.048640239
    c11 = 0.000041764768
    c12 = -0.000000014452093
    c13 = 6.5459673
 
    tk = tdb + 273.15                     # converts from degc to degK
    
    if tk <= 273.15
      result = Math.exp(c1/tk + c2 + c3*tk + c4*tk**2 + c5*tk**3 + c6*tk**4 + c7*Math.log(tk)) / 1000
    else
      result = Math.exp(c8/tk + c9 + c10*tk + c11*tk**2 + c12*tk**3 + c13*Math.log(tk)) / 1000
	end
    return result
end


def hum_rat(tdb, twb, p)
    
    # ''' Function to calculate humidity ratio [kg H2O/kg air]
        # Given dry bulb and wet bulb temp inputs [degc]
        # ASHRAE Fundamentals handbood (2005)
            # tdb = Dry bulb temperature [degc]
            # twb = Wet bulb temperature [degc]
            # p = Ambient pressure [kpa]
    # '''

    pws = sat_press(twb)
    ws = 0.62198 * pws / (p - pws)          # Equation 23, p6.8
    if tdb >= 0                            # Equation 35, p6.9
      result = (((2501 - 2.326*twb)*ws - 1.006*(tdb - twb))/(2501 + 1.86*tdb - 4.186*twb))
    else                                   # Equation 37, p6.9
      result = (((2830 - 0.24*twb)*ws - 1.006*(tdb - twb))/(2830 + 1.86*tdb - 2.1*twb))
	end
    return result
end

def hum_rat2(tdb, rh, p)

    # ''' Function to calculate humidity ratio [kg H2O/kg air]
        # Given dry bulb and wet bulb temperature inputs [degc]
        # ASHRAE Fundamentals handbood (2005)
            # tdb = Dry bulb temperature [degc]
            # rh = Relative Humidity [Fraction or %]
            # p = Ambient pressure [kpa]
    # '''
    pws = sat_press(tdb)
    result = 0.62198*rh*pws/(p - rh*pws)    # Equation 22, 24, p6.8
    return result
end

def rel_hum(tdb, twb, p)

    # ''' calculates relative humidity ratio
        # ASHRAE Fundamentals handbood (2005)
            # tdb = Dry bulb temperature [degc]
            # twb = Wet bulb temperature [degc]
            # p = Ambient pressure [kpa]
    # '''
    
    w = hum_rat(tdb, twb, p)
    result = part_press(p, w) / sat_press(tdb)   # Equation 24, p6.8
    return result
end

def rel_hum2(tdb, w, p)
    
    # ''' calculates the relative humidity given:
            # tdb = Dry bulb temperature [degc]
            # p = ambient pressure [kpa]
            # w = humidity ratio [kg/kg dry air]
    # '''

    pw = part_press(p, w)
    pws = sat_press(tdb)
    result = pw / pws
    return result
end

def wet_bulb(tdb, rh, p)
    
    # ''' calculates the wet Bulb temp given:        
            # tdb = Dry bulb temperature [degc]
            # rh = Relative humidity ratio [Fraction or %]
            # p = Ambient pressure [kpa]
        # Uses Newton-Rhapson iteration to converge quickly
    # '''

    w_normal = hum_rat2(tdb, rh, p)
    result = tdb
    
    #' Solves to within 0.001% accuracy using Newton-Rhapson'    
    w_new = hum_rat(tdb, result, p)
    while abs((w_new - w_normal) / w_normal) > 0.00001 do
      w_new2 = hum_rat(tdb, result - 0.001, p)
      dw_dtwb = (w_new - w_new2) / 0.001
      result = result - (w_new - w_normal) / dw_dtwb
      w_new = hum_rat(tdb, result, p)
	end
    return result
end

def enthalpy_air_h2o(tdb, w)
    
    # ''' calculates enthalpy in kJ/kg (dry air) given:
            # tdb = Dry bulb temperature [degc]
            # w = Humidity Ratio [kg/kg dry air]
        # calculations from 2005 ASHRAE Handbook - Fundamentals - SI p6.9 eqn 32
    # '''
       
    result = 1.006*tdb + w*(2501 + 1.86*tdb)
    return result
end

def t_drybulb_calc(h,w)
    
    # ''' calculates dry bulb temp in deg c given:
            # h = enthalpy [kJ/kg k]
            # w = Humidity Ratio [kg/kg dry air]
        # back calculated from enthalpy equation above
        # ***warning 0 state for Imp is ~0F, 0% rh ,and  1 AtM, 0 state 
              # for SI is 0c, 0%rh and 1 AtM
    # '''
    result = (h-(2501*w))/(1.006+(1.86*w))
    return result
end

def dew_point(p, w)

    # ''' Function to compute the dew point temperature (deg c)
        # From page 6.9 equation 39 and 40 in ASHRAE Fundamentals handbook (2005)
            # p = ambient pressure [kpa]
            # w = humidity ratio [kg/kg dry air]
        # Valid for Dew points less than 93 c
    # '''

    c14 = 6.54
    c15 = 14.526
    c16 = 0.7389
    c17 = 0.09486
    c18 = 0.4569
    
    pw = part_press(p, w)
    alpha = Math.log(pw)
    tdp1 = c14 + c15*alpha + c16*alpha**2 + c17*alpha**3 + c18*pw**0.1984
    tdp2 = 6.09 + 12.608*alpha + 0.4959*alpha**2
    if tdp1 >= 0
      result = tdp1
    else
      result = tdp2
	end
    return result
end

def dry_air_density(p, tdb, w)
    
    # ''' Function to compute the dry air density (kg_dry_air/m**3), using pressure
        # [kpa], temperature [c] and humidity ratio
        # From page 6.8 equation 28 ASHRAE Fundamentals handbook (2005)
        # [rho_dry_air] = dry_air_density(p, tdb, w)
        # Note that total density of air-h2o mixture is:
        # rho_air_h2o = rho_dry_air * (1 + w)
        # gas constant for dry air
    # '''

    r_da = 287.055
    result = 1000*p/(r_da*(273.15 + tdb)*(1 + 1.6078*w))
    return result
end

def psych(p, in0type, in0Val, in1type, in1Val, outtype, unittype='Imp')

 
    if in0type != 'h' and in0type != 'w' and in0type != 'tdb'
      outVal = 'NAN'
    elsif in0type == in1type
      outVal = 'NAN'
	end
    
    if unittype == 'SI'
      p=p/1000                            # converts p to kpa
      if in0type == 'tdb'               # assign the first input
        tdb=in0Val
      elsif in0type =='w'
        w=in0Val
      elsif in0type =='h'
        h=in0Val
      end		

      if in1type == 'tdb'                # assign the second input
        tdb=in1Val
      elsif in1type == 'twb'
        twb=in1Val
      elsif in1type =='Dp'
        dew=in1Val
      elsif in1type =='rh'
        rh=in1Val
      elsif in1type =='w'
        w=in1Val
      elsif in1type =='h'
        h=in1Val
	  end
		
    else                                   # converts to SI if not already
      p = (p*4.4482216152605)/(0.0254**2*1000)
      if in0type =='tdb'                           
        tdb = (in0Val-32)/1.8
      elsif in0type == 'w'
        w = in0Val
      elsif in0type == 'h'
        h = ((in0Val * 1.055056)/0.45359237) - 17.884444444
      end
            
      if in1type == 'tdb'                                   
        tdb = (in1Val - 32)/1.8
      elsif in1type == 'twb'
        twb = (in1Val - 32)/1.8
      elsif in1type == 'Dp'
        dew = (in1Val - 32)/1.8
      elsif in1type == 'rh'
        rh = in1Val
      elsif in1type == 'w'
        w = in1Val
      elsif in1type == 'h'
        h = ((in1Val*1.055056)/0.45359237) - 17.884444444
      end
	  
	end
        
    
    if (in0type == 'h' and in1type == 'w') # calculate tdb if not given
      tdb = t_drybulb_calc(h,w)
    elsif (in0type == 'w' and in1type == 'h')
      tdb = t_drybulb_calc(h,w)
	end
            
    
    if outtype == 'rh' or outtype == 'twb'      # Find rh
      if in1type == 'twb'                     # given twb
        rh = rel_hum(tdb, twb, p)
      elsif in1type == 'Dp'                   # given dew
        rh = sat_press(dew)/sat_press(tdb)
      # elsif in1type == 'rh'                   # given rh
        # rh already Set
      elsif in1type == 'w'                     # given w
        rh = part_press(p, w) / sat_press(tdb)
      elsif in1type == 'h'
        w = (1.006 * tdb - h) / (-(2501 + 1.86 * tdb))
        rh = part_press(p, w) / sat_press(tdb)
	  end

    else
      if in0type != 'w'                       # Find w
        if in1type == 'twb'                 # Given twb
          w = hum_rat(tdb, twb, p)
        elsif in1type == 'Dp'                # Given dew
          w = 0.621945*sat_press(dew)/(p - sat_press(dew))
          #' Equation taken from eq 20 of 2009 Fundemental chapter 1'
        elsif in1type == 'rh'                # Given rh
          w = hum_rat2(tdb, rh, p)
        # elsif in1type == 'w'               # Given w
          # w already known
        elsif in1type == 'h'                 # Given h
          w = (1.006*tdb - h)/(-(2501 + 1.86*tdb))  
          #' Algebra from 2005 ASHRAE Handbook - Fundamentals - SI p6.9 eqn 32'
		end
      else
        #print ('invalid input varilables')
      end
    end	  
            
    # p, tdb, and w are now availible

    if outtype == 'tdb'
      outVal = tdb
    elsif outtype == 'twb'                  # Request twb
      outVal = wet_bulb(tdb, rh, p)
    elsif outtype == 'dp'                   # Request dew
      outVal = dew_point(p, w)
    elsif outtype == 'rh'                   # Request rh
      outVal = rh
    elsif outtype == 'w'                    # Request w
      outVal = w
    elsif outtype == 'wVp'                 # Request pw
      outVal = part_press(p, w) * 1000
    elsif outtype == "DSat"                 # Request deg of sat
      outVal = w / hum_rat2(tdb, 1, p)    
      #'the middle arg of hum_rat2 is suppose to be rh.  rh is suppose to be 100%'
    elsif outtype == 'h'                    # Request enthalpy
      outVal = enthalpy_air_h2o(tdb, w)
    elsif outtype == 's'                    # Request entropy
      outVal = 5 / 0                      
      #'don\'t have equation for Entropy, so I divided by zero to induce an error.'
    elsif outtype == 'SV'                   # Request specific volume
      outVal = 1 / (dry_air_density(p, tdb, w))
    elsif outtype == 'MAD'                  # Request density
      outVal = dry_air_density(p, tdb, w) * (1 + w)
	end


    if unittype == 'Imp'                   # convert to Imperial units
      if outtype == 'tdb' or outtype == 'twb' or outtype == 'dp'
        outVal = 1.8*outVal + 32
      elif outtype == 'wVp'
        outVal = outVal*0.0254**2/4.448230531
      elif outtype == 'h'
        outVal = (outVal + 17.88444444444)*0.45359237/1.055056
      elif outtype == 'SV'
        outVal = outVal*0.45359265/((12*0.0254)**3)
      elif outtype == 'MAD'
        outVal = outVal*(12*0.0254)**3/0.45359265
	  end
	end

    return outVal
end
    
# def main():
    # p = input ("enter the value for p:")
    # in0type = input ( "enter the first input type:")
    # in0Val = input("enter first input value:")
    # in1type = input ( "enter the second input type:")
    # in1Val = input ( "enter second input value:")
    # outtype = input ( "enter the output type:")
    # unittype = input ( "enter the unit type (Imp or SI):") 
    # result=psych(float(p),in0type,float(in0Val),in1type,float(in1Val),outtype,unittype)
    # print (result)
    
# if __name__=='__main__': main()