Attribute VB_Name = "Module1"
Function Part_press(P, W) As Double
' Function to compute partial vapor pressure in [kPa]
' From page 1.9 equation 38 in ASHRAE Fundamentals handbook SI-Edition (2009)
'   P = ambient pressure [kPa]
'   W = humidity ratio [kg/kg dry air]

    Part_press = P * W / (0.621945 + W)
End Function
Function Sat_press(Tdb) As Double
' Function to compute saturation vapor pressure in [kPa]
' ASHRAE Fundamentals handbook SI-Edition (2009) p 1.2, equation 5 and 6
'   Tdb = Dry bulb temperature [degC]

    C1 = -5674.5359
    C2 = 6.3925247
    C3 = -0.009677843
    C4 = 6.2215701E-07
    C5 = 2.0747825E-09
    C6 = -9.484024E-13
    C7 = 4.1635019
    C8 = -5800.2206
    C9 = 1.3914993
    C10 = -0.048640239
    C11 = 4.1764768E-05
    C12 = -1.4452093E-08
    C13 = 6.5459673
 
    TK = Tdb + 273.15         'Converts from degC to degK
    
    If TK <= 273.15 Then
        Sat_press = 0.001 * Exp(C1 / TK + C2 + C3 * TK + C4 * TK ^ 2 + C5 * TK ^ 3 + C6 * TK ^ 4 + C7 * Log(TK))
    Else
        Sat_press = 0.001 * Exp(C8 / TK + C9 + C10 * TK + C11 * TK ^ 2 + C12 * TK ^ 3 + C13 * Log(TK))
    End If

End Function
Function Hum_rat_Tdb_Twb_P(Tdb, Twb, P) As Double
' Function to calculate humidity ratio [kg H2O/kg air]
' Given dry bulb and wet bulb temp inputs [degC]
' ASHRAE Fundamentals handbook SI-Edition (2009)
'   Tdb = Dry bulb temperature [degC]
'   Twb = Wet bulb temperature [degC]
'   P = Ambient Pressure [kPa]
    
    Pws = Sat_press(Twb)
    Ws = 0.621945 * Pws / (P - Pws)       ' Equation 23, p1.8
    If Tdb >= 0 Then
        ' Equation 35, p1.9
        Hum_rat_Tdb_Twb_P = ((2501 - 2.326 * Twb) * Ws - 1.006 * (Tdb - Twb)) / (2501 + 1.86 * Tdb - 4.186 * Twb)
    Else
        ' Equation 37, p1.9
        Hum_rat_Tdb_Twb_P = ((2830 - 0.24 * Twb) * Ws - 1.006 * (Tdb - Twb)) / (2830 + 1.86 * Tdb - 2.1 * Twb)
    End If
End Function
Function Hum_rat_Tdb_Twb_P_IP(Tdb, Twb, P) As Double
' Function to calculate humidity ratio [lb H2O/lb air]
' Given dry bulb and wet bulb temp inputs [degF]
' ASHRAE Fundamentals handbook SI-Edition (2009)
'   Tdb = Dry bulb temperature [degF]
'   Twb = Wet bulb temperature [degF]
'   P = Ambient Pressure [PSI]

    Hum_rat_Tdb_Twb_P_IP = Hum_rat_Tdb_Twb_P((Tdb - 32) / 1.8, (Twb - 32) / 1.8, 101.325 * P / 14.696)
End Function

Function Hum_rat_Tdb_RH_P(Tdb, RH, P) As Double
' Function to calculate humidity ratio [kg H2O/kg air]
' Given dry bulb and wet bulb temperature inputs [degC]
' ASHRAE Fundamentals handbook SI-Edition (2009)
'   Tdb = Dry bulb temperature [degC]
'   RH = Relative Humidity [Fraction or %]
'   P = Ambient Pressure [kPa]
    
    Pws = Sat_press(Tdb)
    Hum_rat_Tdb_RH_P = 0.621945 * RH * Pws / (P - RH * Pws)   ' Equation 22, 24, p1.8
    
End Function
Function Hum_rat_Tdb_RH_P_IP(Tdb, RH, P) As Double
'' USE THIS ONE!!!
' Function to calculate humidity ratio [lb H2O/lb air]
' Given dry bulb temp and relative humidity inputs [degF]
' ASHRAE Fundamentals handbook SI-Edition (2009)
'   Tdb = Dry bulb temperature [degF](T_Room_xxx)
'   RH = Relative Humidity [Fraction or %](RH_Room_xxx)
'   P = Ambient Pressure [PSI] (P_Amb)
    
    Hum_rat_Tdb_RH_P_IP = Hum_rat_Tdb_RH_P((Tdb - 32) / 1.8, RH, 101.325 * P / 14.696)
    
End Function

Function Hum_rat_Tdb_H(Tdb, H) As Double
' Function to calculate humidity ratio [kg H2O/kg air]
' Given dry bulb and enthalpy inputs [degC]
' ASHRAE Fundamentals handbook SI-Edition (2009)
'   Tdb = Dry bulb temperature [degC]
'   H = Enthalpy [kJ/kg]

' Calculations from SI Edition (2009) ASHRAE Handbook - Fundamentals - SI P1.9 eqn 32
    Hum_rat_Tdb_H = (H - 1.006 * Tdb) / (2501 + 1.86 * Tdb)
    
End Function

Function Hum_rat_Tdb_H_IP(Tdb, H) As Double
' Function to calculate humidity ratio [lb H2O/lb air]
' Given dry bulb and wet bulb temperature inputs [degC]
' ASHRAE Fundamentals handbook SI-Edition (2009)
'   Tdb = Dry bulb temperature [degF]
'   H = Enthalpy [Btu/lb]

' Calculations from SI Edition (2009) ASHRAE Handbook - Fundamentals - IP P1.9 eqn 32???
    Hum_rat_Tdb_H_IP = (H - 0.24 * Tdb) / (1061 + 0.444 * Tdb)
End Function

Function RH_Tdb_Twb_P(Tdb, Twb, P)
' Calculates relative humidity ratio
' ASHRAE Fundamentals handbook SI-Edition (2009)
'   Tdb = Dry bulb temperature [degC]
'   Twb = Wet bulb temperature [degC]
'   P = Ambient Pressure [kPa]

    W = Hum_rat_Tdb_Twb_P(Tdb, Twb, P)
    RH_Tdb_Twb_P = Part_press(P, W) / Sat_press(Tdb)          ' Equation 24, p6.8
End Function

Function RH_Tdb_Twb_P_IP(Tdb, Twb, P)
' Calculates relative humidity ratio
' ASHRAE Fundamentals handbook SI-Edition (2009)
'   Tdb = Dry bulb temperature [degF]
'   Twb = Wet bulb temperature [degF]
'   P = Ambient Pressure [PSI]

    RH_Tdb_Twb_P_IP = RH_Tdb_Twb_P((Tdb - 32) / 1.8, (Twb - 32) / 1.8, 101.325 * P / 14.696)
End Function

Function RH_Tdb_W_P(Tdb, W, P)
' Calculates the relative humidity given:
'   Tdb = Dry bulb temperature [degC]
'   P = ambient pressure [kPa]
'   W = humidity ratio [kg/kg dry air]
' ASHRAE Fundamentals handbook SI-Edition (2009)

    Pw = Part_press(P, W)
    Pws = Sat_press(Tdb)
    RH_Tdb_W_P = Pw / Pws
End Function

Function RH_Tdb_W_P_IP(Tdb, W, P)
' Calculates the relative humidity given:
'   Tdb = Dry bulb temperature [degF]
'   W = humidity ratio [lb/lb dry air]
'   P = ambient pressure [PSI]
    
    RH_Tdb_W_P_IP = RH_Tdb_W_P((Tdb - 32) / 1.8, W, 101.325 * P / 14.696)
End Function

Function Wet_bulb_Tdb_RH_P(Tdb, RH, P)
' Calculates the Wet Bulb temp given dry blub temp [degC] and Relative Humidity
' Uses Newton-Rhapson iteration to converge quickly
'   Tdb = Dry bulb temperature [degC]
'   RH = Relative humidity ratio [Fraction or %]
'   P = Ambient Pressure [kPa]
' ASHRAE Fundamentals handbook SI-Edition (2009)

    W_normal = Hum_rat_Tdb_RH_P(Tdb, RH, P)
    Wet_bulb = Tdb
    ' Solve to within 0.001% accuracy using Newton-Rhapson
    W_new = Hum_rat_Tdb_Twb_P(Tdb, Wet_bulb, P)
    Do While Abs((W_new - W_normal) / W_normal) > 1E-05
        W_new2 = Hum_rat_Tdb_Twb_P(Tdb, Wet_bulb - 0.001, P)
        dw_dtwb = (W_new - W_new2) / 0.001
        Wet_bulb = Wet_bulb - (W_new - W_normal) / dw_dtwb
        W_new = Hum_rat_Tdb_Twb_P(Tdb, Wet_bulb, P)
    Loop
    Wet_bulb_Tdb_RH_P = Wet_bulb
End Function

Function Wet_bulb_Tdb_RH_P_IP(Tdb, RH, P)
' Calculates the Wet Bulb temp given dry blub temp [degF] and Relative Humidity
' Uses Newton-Rhapson iteration to converge quickly
'   Tdb = Dry bulb temperature [degF]
'   RH = Relative humidity ratio [Fraction or %]
'   P = Ambient Pressure [PSI]

    Wet_bulb_Tdb_RH_P_IP = 1.8 * Wet_bulb_Tdb_RH_P((Tdb - 32) / 1.8, RH, 101.325 * P / 14.696) + 32
End Function

Function h_air_Tdb_W(Tdb, W)
' Calculates enthalpy in kJ/kg (dry air)
'   Tdb = Dry bulb temperature [degC]
'   W = Humidity Ratio [kg/kg dry air]

    ' Calculations from SI Edition (2009) ASHRAE Handbook - Fundamentals - SI P1.9 eqn 32
    h_air_Tdb_W = 1.006 * Tdb + W * (2501 + 1.86 * Tdb)

End Function

Function h_air_Tdb_W_IP(Tdb, W)
' Calculates enthalpy in BTU/lb (dry air)
'   Tdb = Dry bulb temperature [degF]
'   W = Humidity Ratio [lb/lb dry air]

    h_air_Tdb_W_IP = 0.429922 * (h_air_Tdb_W((Tdb - 32) / 1.8, W) + 17.884)
End Function

Function h_fg_H2O(Tdb)
' Latent heat of saturated water function
' Correlation taken from Steam Tables - Introduction To Thermodynamics, Classical and Statistical
'   Sonntag / Van Wylen
' Good from 0 - 200 degC
' Output in kJ/kg
'   Tdb = Dry bulb temperature [degC]

    h_fg_H2O = 2518.6 - 2.7571 * Tdb
    
End Function

Function Dew_point_P_W(P, W) As Double
' Function to compute the dew point temperature (deg C)
' From page 1.9 equation 39 and 40 in ASHRAE Fundamentals handbook SI-Edition (2009)
'   P = ambient pressure [kPa]
'   W = humidity ratio [kg/kg dry air]

    C14 = 6.54
    C15 = 14.526
    C16 = 0.7389
    C17 = 0.09486
    C18 = 0.4569
    
    Pw = Part_press(P, W)
    alpha = Log(Pw)
    If Tdp1 >= 0 Then
        Dew_point_P_W = C14 + C15 * alpha + C16 * alpha ^ 2 + C17 * alpha ^ 3 + C18 * Pw ^ 0.1984
    Else
        Dew_point_P_W = 6.09 + 12.608 * alpha + 0.4959 * alpha ^ 2
    End If
End Function

Function Dew_point_P_W_IP(P, W) As Double
' Function to compute the dew point temperature (deg F)
' From page 6.9 equation 39 and 40 in ASHRAE Fundamentals handbook SI-Edition (2009)
'   P = ambient pressure [PSI]
'   W = humidity ratio [lb/lb dry air]

    Dew_point_P_W_IP = 1.8 * Dew_point_P_W(101.325 * P / 14.696, W) + 32
End Function

Function Dry_Air_Density(P, Tdb, W)
' Function to compute the dry air density (kg_dry_air/m^3), using pressure
' [kPa], temperature [C] and humidity ratio
' From page 1.8 equation 28 ASHRAE Fundamentals handbook SI-Edition (2009)
'   [rho_dry_air] = Dry_Air_Density(P, Tdb, w)
' Note that total density of air-h2o mixture is:
'   rho_air_h2o = rho_dry_air * (1 + W)
' gas constant for dry air (with carbon dioxide levels for the 1st half of 20th century)

    R_da = 287.042
    Dry_Air_Density = 1000 * P / (R_da * (273.15 + Tdb) * (1 + 1.607858 * W))
End Function

Function Dry_Air_Density_IP(P, Tdb, W)
' Function to compute the dry air density (lb_dry_air/ft^3), using pressure
' [PSI], temperature [F] and humidity ratio
' From page 1.8 equation 28 ASHRAE Fundamentals handbook SI-Edition (2009)
'   [rho_dry_air] = Dry_Air_Density(P, Tdb, w)
' Note that total density of air-h2o mixture is:
'   rho_air_h2o = rho_dry_air * (1 + W)

    Dry_Air_Density_IP = 0.062428 * Dry_Air_Density(101.325 * P / 14.696, (Tdb - 32) / 1.8, W)
End Function

Function SG_Water(Temp)
' Module to calculate the specific gravity of water.  Data taken from EES and fitted with 3rd order polynomial
    SG_Water = 2E-05 * Temp ^ 3 - 0.006 * Temp ^ 2 + 0.0183 * Temp + 1000
    SG_Water = 0.001 * SG_Water
End Function

Function STD_Press(Elevation)
' Module to calculate the standard pressure [kPa] at given elevation (meters)
'   ASHRAE Fundamentals SI-Edition (2009) - chap 1, eqn 3

    STD_Press = 101.325 * (1 - 2.25577E-05 * Elevation) ^ 5.2559
End Function

Function STD_Press_IP(Elevation)
' Module to calculate the standard pressure [PSI] at given elevation (ft)

    STD_Press_IP = 14.696 * STD_Press(0.3048 * Elevation) / 101.325
End Function

Function STD_Temp(Elevation)
' Module to calculate the standard temperature [degC] at given elevation (meters)
'   ASHRAE Fundamentals SI-Edition (2009) - chap 6, eqn 4

    STD_Temp = 15 - 0.0065 * Elevation
End Function

Function STD_Temp_IP(Elevation)
' Module to calculate the standard temperature [degF] at given elevation (ft)

    STD_Temp_IP = 1.8 * STD_Temp(0.3048 * Elevation) + 32
End Function

Function Density_Water(Temp_SI)
' Function to calculate the density of water.
'   Temp_SI in degC
'   Density_Water in kg/m3
'   Correllation taken from M. Conde
    T_water_crit = 273.15 + 373.984 ' degC
    B0 = 1.993771843
    B1 = 1.0985211604
    B2 = -0.5094492996
    B3 = -1.7611912427
    B4 = -44.9005480267
    B5 = -723692.2618632
    
    x = 1 / 3
    tau = 1 - (Temp_SI + 273.15) / T_water_crit
    Density_Water = 322 * (1 + B0 * tau ^ x + B1 * tau ^ (2 * x) + B2 * tau ^ (5 * x) + B3 * tau ^ (16 * x) + B4 * tau ^ (43 * x) + B5 * tau ^ (110 * x))

End Function

Function ST_Water(Temp_SI)
' Function to calculate the Surface Tension of Water.
'   Temp_SI in degC
'   ST_Water in mN/m
'   Correllation taken from M. Conde

    T_water_crit = 273.15 + 373.984
    sigma = (Temp_SI + 273.15) / T_water_crit
    ST_Water = 235.8 * (1 + 0.625 * (1 - sigma)) * (1 - sigma) ^ 1.256
End Function

Function Cp_Water(Temp_SI)
' Function to calculate the specific heat of Water.
'   Temp_SI in degC
'   Cp_Water in kJ/kg-K
'   Correllation taken from M. Conde
    If Temp_SI <= 0 Then
        A = 830.54602
        B = -1247.52013
        c = -68.6035
        D = 491.2765
        E = -1.80692
        F = -137.51511
    Else
        A = 88.7891
        B = -120.1958
        c = -16.9264
        D = 52.4654
        E = 0.10826
        F = 0.46988
    End If
    sigma = (273.15 + Temp_SI) / 228 - 1
    Cp_Water = A + B * sigma ^ 0.02 + c * sigma ^ 0.04 + D * sigma ^ 0.06 + E * sigma ^ 1.8 + F * sigma ^ 8
    
End Function

Function Tdb_SI(W, H)
' Function to calculate the dry bulb temperature given:
'   w = humidity ratio (kg/kg)
'   h = enthalpy (kJ/kg)
' Calculations from SI Edition (2009) ASHRAE Handbook - Fundamentals - SI P1.9 eqn 32
'  Derived from h = 1.006 * Tdb + w * (2501 + 1.86 * Tdb)

    Tdb_SI = (H - W * 2501) / (1.006 + W * 1.86)

End Function

Function Tdb_IP(W, H)
' Function to calculate the dry bulb temperature given:
'   w = humidity ratio (lb/lb)
'   h = enthalpy (btu/lb)
' Calculations from SI Edition (2009) ASHRAE Handbook - Fundamentals - SI P1.9 eqn 32
    h_SI = H / 0.429922 - 17.884
    Tdb_IP = (h_SI - W * 2501) / (1.006 + W * 1.86)
    Tdb_IP = 1.8 * Tdb_IP + 32

End Function

Function Cp_HumidAir(W)
' Calculates the specific heat of humid air in kJ/kg-C (dry air)
'   W = Humidity Ratio [kg/kg dry air]

'  Calculations from SI Edition (2009) ASHRAE Handbook - Fundamentals - SI P1.9 eqn 32 (Cp = dh/dT)
    Cp_HumidAir = 1.006 + 1.86 * W
    
End Function


Function Cp_HumidAir_IP(W)
' Calculates the specific heat of humid air in BTU/lbm-F (dry air)
'   W = Humidity Ratio [lbm/lbm dry air]

'  Calculations from SI Edition (2009) ASHRAE Handbook - Fundamentals - SI P1.9 eqn 32 (Cp = dh/dT)
    Cp_HumidAir_IP = 0.238845897 * Cp_HumidAir(W)
    
End Function


Function mu_air(Tdb)
' --------------------------- Function mu_air -------------------------------
' Function to calculate dynamic viscosity of air [kg/m-sec ]
'   %ANSI/ASHRAE Standard 37-2005, page 7, section 6.3.3
' Usage:
'   [mu] = mu_air(Tdb)
' Inputs:
'    Tdb = Dry bulb temperature [degC]
   
    mu_air = (17.23 + 0.048 * Tdb) * 1E-06
End Function


