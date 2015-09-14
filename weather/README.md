# Weather files

This README describes the weather files in this folder. The `.epw` (EnergyPlus weather) files are
imported by [OpenStudio Analysis Spreadsheet] to provide weather inputs to building models simulated
in EnergyPlus. The `.stat` files provide human-friendly summary statistics for their corresponding
`.epw` files. In the published report related to fault modeling, the weather data of Golden,
Colorado, USA in 2012 are used. The files are:

* `SRRL_2012AMY_60min.epw`: The weather data file of Golden, Colorado, USA in 2012
* `SRRL_2012AMY_60min.stat`: The statistics of data in `SRRL_2012AMY_60min.epw`\

[OpenStudio Analysis Spreadsheet]: https://github.com/NREL/OpenStudio-analysis-spreadsheet/ "OpenStudio Analysis Spreadsheet"
