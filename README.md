# Overview of the Openstudio Fault Models Gem

- Creating a comprehensive library of **OpenStudio fault models**
- Created/tested/validated with OpenStudio 2.8. Might not be compatible with later versions.

## Features

- Physics-based fault impact simulation within the capability of EnergyPlus/OpenStudio

- Fault intensity implementation simulating how severe faults are (e.g., how much portion is fouled in the condenser heat exchanger) and estimating the impact of a fault in different fault intensities.

- Fault evolution implementation simulating evolving/increasing fault intensity through certain period of time.

## Future goals

- what are common/typical faults in different sample spaces (e.g., HVAC system type, building operation type, building location etc.) ?

- how often (e.g., incidence and prevalence) faults occur in different sample spaces (e.g., HVAC system type, building operation type, building location etc.) ?

# Past Publications Related to this Work

- [Development of Fault Models for Hybrid Fault Detection and Diagnostics Algorithm](https://www.nrel.gov/docs/fy16osti/65030.pdf)

- [Empirical modeling of the impacts of faults on water-cooled chiller power consumption for use in building simulation programs](https://www.sciencedirect.com/science/article/pii/S1359431116300692)

- [Common Faults and Their Prioritization in Small Commercial Buildings](https://www.nrel.gov/docs/fy18osti/70136.pdf)

- [Commercial Fault Detection and Diagnostics Tools: What They Offer, How They Differ, and What’s Still Needed](https://escholarship.org/uc/item/4j72k57p)

- [Assessing barriers and research challenges for automated fault detection and diagnosis technology for small commercial buildings in the United States](https://www.sciencedirect.com/science/article/pii/S1364032118306300)

- [Metrics and Methods to Assess Building Fault Detection and Diagnosis Tools](https://www.osti.gov/biblio/1503166)

- [A performance evaluation framework for building fault detection and diagnosis algorithms](https://www.sciencedirect.com/science/article/pii/S0378778818335680)

- [Representing Small Commercial Building Faults in EnergyPlus, Part I: Model Development](https://www.mdpi.com/2075-5309/9/11/233)

- [Representing Small Commercial Building Faults in EnergyPlus, Part II: Model Validation](https://www.mdpi.com/2075-5309/9/12/239)

- [Research Challenges and Directions in HVAC Fault Prevalence](https://www.tandfonline.com/doi/full/10.1080/23744731.2021.1898243)

# Installation

Add this line to your application's Gemfile:

```ruby
gem 'openstudio-fault-models'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install 'openstudio-fault-models'

# Usage

To be filled out later. 

## TODO

- [ ] Remove measures from OpenStudio-Measures to standardize on this location
- [ ] Update measures to code standards
- [ ] Review and fill out the gemspec file with author and gem description

# Releasing

* Update change log
* Update version in `/lib/openstudio/openstudio-fault-models/version.rb`
* Merge down to master
* Release via github
* run `rake release` from master

