# The Real Cost of Doing Nothing in the Face of Extreme Weather: Applied Data Science Capstone
## Cochrane, O.J. (2024)
This study focuses on benefit-cost analyses of climate hazard adaptation measures. CLIMADA, an open-source model built for Python, allows users to generate and customize adaptations and visualize/quantify the economic benefits when faced with a selection of natural hazards. This study focuses on the impact of wetlands to reduce damage caused by tropical cyclones (i.e. Hurricanes and Tropical Storms).

To reach the end product of a benefit-cost analysis, the process needs to be broken down to create the necessary components first. This document will break each component down to be easily replicable for various cyclones, locations, populations, and functions.

The main components are Hazard and Entity. An Entity is broken down into the following subcomponents: Exposure, Impact, Measure, and Discount Rates.

A Hazard contains all the relevant data about the given incidence. In this case, we will be using `TCTracks` for our tropical cyclone data. CLIMADA is able to access historical data about tropical cyclones and import it into the program. We will be using Hurricane Sandy as out storm of choice.

The following code initializes some packages for the work, and imports Hurricane Sandy data as `tr_storm`. It also generates a general plot of Sandy's strength over it's historical path.

## Imports, Packages, and Data
All code in this document was run with Python 3.9.15. All necessary packages are included in the following code block. Please refer to the respective documentation of [CLIMADA](https://climada-python.readthedocs.io/en/stable/index.html) and the specific package(s) for all troubleshooting.

    %matplotlib inline
    import numpy as np
    import matplotlib.pyplot as plt
    import warnings
    np.warnings = warnings
    warnings.filterwarnings('ignore')
    from climada.entity import LitPop
    from climada.entity import ImpactFuncSet, ImpfTropCyclone, Exposures
    from climada.entity.measures import Measure, MeasureSet
    from climada.hazard import Hazard, Centroids, TropCyclone, TCTracks
    from climada.engine import ImpactCalc
    from climada.entity import Entity
    from climada.entity import DiscRates
    from climada.util.api_client import Client
    from climada.engine import CostBenefit
    from climada.engine.cost_benefit import risk_aai_agg

    # Tracks: https://ncics.org/ibtracs/
    
    # Generate plot of SANDY (2012)
    tr_storm = TCTracks.from_ibtracs_netcdf(provider='usa', storm_id='2012296N14283') # Sandy 2012
    storm_name = 'Sandy'
    plt.figure(figsize=(10,16))
    ax = tr_storm.plot();
    ax.set_title(storm_name)

We can see the map of Sandy's historical track is overlayed on an outline of the United States. It also contains intensity data along the entire track to show the category at different segments of the track. Storms are identified by their storm ID issued by the National Oceanic and Atmospheric Administration (NOAA).

After defining the type of data for asset valuation, you need to define the space/region where you will measure the impact of the storm (as well as the level of detail). This is done using `Centroids` overlaid on the map. Since this analysis is of New York State (and immediate surrounding areas), we'll define a grid of centroids over the area using lat/lon coordinates.

    min_lat, max_lat, min_lon, max_lon = 40.43, 45.10, -79.83, -71.75
    cent = Centroids.from_pnt_bounds((min_lon, min_lat, max_lon, max_lat), res=0.15)
    cent.check()
    cent.plot()
    
Consider that a finer resolution value means more centroids, quickly leading to longer computing times.

## RCPs and Scaling for Future Climate Conditions

Now, to investigate the future of extreme weather intensity across different climate change scenarios, we'll scale a copy of SANDY up to different Representative Concentration Pathways (RCPs). RCPs are categorical outcomes of climate change based on several activities and how they are addressed/adapted in the future, including energy production, transporation, and innovation. The RCPs have been formally adopted by the Intergovernmental Panel on Climate Change (IPCC) and come at levels based on the level of radiative forcing in the year 2100.

CLIMADA allows us to easily scale `tr_storm` to each pre-defined level using the `apply_climate_scenario_knu()` method as follows, but first, we need to encapsulate `tr_storm` in a `TropicalCyclone` object (along with our centroids `cent`) to make sure it has the proper attributes for our analysis.

    tc_storm = TropCyclone.from_tracks(tr_storm, centroids=cent)
    
    # Create RCP-scaled copies of the storm
    tc_storm26 = tc_storm.apply_climate_scenario_knu(ref_year = 2100, rcp_scenario = 26) # least adverse
    tc_storm45 = tc_storm.apply_climate_scenario_knu(ref_year = 2100, rcp_scenario = 45)
    tc_storm60 = tc_storm.apply_climate_scenario_knu(ref_year = 2100, rcp_scenario = 60)
    tc_storm85 = tc_storm.apply_climate_scenario_knu(ref_year = 2100, rcp_scenario = 85) # most adverse
    
You can see the effects of this linear scaling to each RCP by printing the maximum intensity (wind speed in meters/second) of each `tc_storm` object. Here, we'll print the max intensity for SANDY historically and SANDY under the RCP 8.5 protocol.

    # SANDY 2012
    max_intensity = tc_storm.intensity.max()
    print(f"The maximum intensity (wind speed) is: {max_intensity} m/s")
    
    # SANDY at RCP 8.5 in 2100
    max_intensity = tc_storm85.intensity.max()
    print(f"The maximum intensity (wind speed) is: {max_intensity} m/s")
    
You can see that the more adverse RCPs result in verions with a greater max intensity. You can also visualize the intensity of each version.

    tc_storm85.plot_intensity('2012296N14283')

## Exposures and Asset Valuation
The next step is to import the economic data to determine the value of targets in the storms track. This is called our `Exposure`.

The data comes from a source called LitPop that is directly integrated into the CLIMADA environment. However, the data needs to be manually downloaded from a public NASA database and stored in a specific location in the CLIMADA files. LitPop uses nightime light data and population demographic information to gauge a multitude of economic indicators. Among these are GDP, exports, and income group.

For this study, we will be using GDP for asset valuation. The following code imports the GDP data for the United States from LitPop:

    # Exposure (LitPop): exp
    exp = LitPop.from_countries(['USA'], fin_mode = 'gdp', res_arcsec = 30)
    exp.plot_scatter();
    
This code also plots the exposure data on a map of the US. Note the `res_arcsec = 30` argument. This specifies the resolution, or how granular the map is in terms of zone. Higher resolutions will create much smoother images, but take much longer to generate.

## Climate Adaptations as Measures
Now that we have our tropical cyclone and exposure data, the next step is to create our measure. This study aimed to investigate the potential benefits of wetlands to mitigate storm damage, specifically through their ability to absord and store precipitation and combat flooding. The following code outlines this measure that will serve as wetlands to reduce the impact of our tropical cyclone.

    meas = Measure(
    name='Wetlands', # name of measure
    haz_type='TC', # hazard the measure is combating 
    color_rgb=np.array([1, 1, 1]),
    cost=100000000, # cost of measure implementation, 1e8
    mdd_impact=(1,-0.25), # on average, assets will experience 25% less impact
    paa_impact=(1,-0.05), # 5% of assets will no longer be impacted
    hazard_inten_imp=(1,0),
    )

    meas.check()

    # Make MeasureSet for Entity integration even though it's a singular measure
    meas_set = MeasureSet()
    meas_set.append(meas)
    meas_set.check()
    
We're creating a measure saved under the variable `meas` with several attributes. It will be named `Wetlands` and has a `haz_type` of `TC`. This denotes that we are applying the measure to a tropical cyclone (TC). The `cost` takes the projected cost of implementing/constructing this measure if it were to be built. We've decided to implement $100 million USD worth of wetlands for damage mitigation across the region of analysis. 

`mdd_impact` stands for Mean Damage Degree Impact. The second parameter denotes the percent reduction of the mean damage degree of the tropical cyclone. In this example, the wetlands measure will *decrease* the average damage to an asset by the tropical cyclone by *25%*. 

`paa_impact` stands for Percentage of Assets Affected Impact, which our measure decreases by 5%. This does not change the level of damage done to assets, but rather what percentage of assets in the path of the tropical cyclone will be damaged at all. We are reasonably assuming that the reduction of flooding from wetlands construction will cause some assets to no longer suffer flood damage.

Lastly, `meas` is encapsulated in a `MeasureSet` called `meas_set`. This is done in order to have it combined with all of our data into a single entity later on for analysis.

## Impact Function
An impact function is a function used to model property damages by tropical cyclones in the United States. This enables creating cost estimates for damages caused by the simulated storms in CLIMADA. The function used in this analysis comes from the paper "[Global Warming Effects on Hurricane Damage](https://doi.org/10.1175/WCAS-D-11-00007.1)" (Emanuel, 2011).

We can load this function directly into CLIMADA for use in our analysis with the following code. We will also put it in a "set" like our `MeasureSet` for consistency and integration into the final entity.

    # Imp Funcs
    impf_tc = ImpfTropCyclone.from_emanuel_usa()
    impf_all = ImpactFuncSet([impf_tc])
    
## Applying Measure(s) to Impact Calculation
After defining the impact, we need to apply the effects of our measure to a new version of our impact function. The following code creates variables that are copies of the original hazard, impact function, and exposure with the effects of the measure applied. The last line plots the intensity of new hazard across the map we defined earlier using centroids.

    # Clone components with measure applied (wetlands)
    new_exp, new_impfs, new_haz = meas.apply(exp, impf_all, tc_storm) # replace 'tc_storm' with any TropCyclone object
    new_haz.plot_intensity(0);
    
Now the damage calculations will be based on the storm scenarios minus the damage prevented by adaptation measure, showcasing the pure benefit and benefit/cost ratio of the policy/infrastructure.

### New vs Old Impact
We can visualize the impact curves of the storm before and after the adaptation measure is applied. This way, you can see how damage is modeled differently after the measure is implemented.
    
    # Create impact calculations
    imp = ImpactCalc(exp, impf_all, tc_storm).impact()
    ax = imp.calc_freq_curve().plot(label='original');

    new_imp = ImpactCalc(new_exp, new_impfs, new_haz).impact()
    new_imp.calc_freq_curve().plot(axis=ax, label='measure');
    plt.legend()

Since the mean damage degree was reduced by 25% (`mdd_impact=(1,-0.25)`), the curve is shifted right and begins later. The red line intersecting the y-axis is also shifted down since it reduced the percentage of assets affected from 100% to 95% (`paa_impact=(1,-0.05)`).

## Discount Rates
CLIMADA offers the ability to implement discount rates to help with fiscal evaluation of adaptation measures. The damage prevented in the current year by a measure is more valuable than damage prevented in future years due to economic forces. Below, rates are defined as a blanket from 2000 to 2100.

    # define discount rates
    years = np.arange(2000, 2100)
    rates = np.ones(years.size) * 0.014 # 1.4% is the most commonly used rate in climate economics per the docs.
    rates[51:55] = 0.025
    rates[95:120] = 0.035
    disc = DiscRates(years=years, rates=rates)
    disc.plot()
    
According to the CLIMADA documentation, 1.4% is the standard for cost discounting in climatology research. Thus, the rates for this analysis will mirror what the CLIMADA documentation suggests to support consistency.

## Creating An Entity
Now that the elements for the analysis have been created, they get combined into an `Entity` that can be plugged into analytical functions in CLIMADA. 

    # Create Entity combining elements.
    ent = Entity(
        exposures=exp,
        disc_rates=disc,
        impact_func_set=impf_all,
        measure_set=meas_set
    )
    
## Benefit-Cost Analysis
The entity can now be inserted into a Benefit-Cost analysis. This will calculate the pure benefit, as well as the total climate risk, average annual risk, and any residual risk. Each `tc_storm` copy including historical and each RCP scenario was passed through the following analysis with identical parameters.

    # Create the cost-benefit analysis
    costben = CostBenefit()
    costben.calc(tc_storm, ent, haz_future=None, ent_future=None,
                               future_year=2050, risk_func=risk_aai_agg, imp_time_depen=None, save_imp=True)
                               
A few things to note: the `risk_aai_agg` value in the `risk_func` parameter is the default risk function that CLIMADA offers. There are also built-in functions for 100 and 250 year return periods to use for analysis. The `future_year` was also chosen mostly arbitrarily to be 2050. Many international climate standards (such as the Paris Climate Accord) call for net-zero carbon emissions by 2050, so it makes sense to base any goals off of a similar timeline.

Below are the benefit-cost analysis results for each RCP scenario comapred to SANDY's historical data.

| RCP Scenario | Benefit ($)             | Benefit/Cost | % Change in Benefit | Max Intensity (m/s) | % Change in Max Intensity | Residual Risk ($)      |
|--------------|--------------------------|--------------|---------------------|----------------------|---------------------------|-------------------------|
| Sandy 2012   | 4,212,470,000,000.00     | 42,124.7     | 0                   | 51.751               | 0                         | 0.00                    |
| 2.6          | 4,503,380,000,000.00     | 45,033.8     | 6.91%               | 52.364               | 1.18%                     | 0.00                    |
| 4.5          | 5,383,380,000,000.00     | 53,833.8     | 27.80%              | 54.117               | 4.57%                     | 0.00                    |
| 6.0          | 6,055,240,000,000.00     | 60,552.4     | 43.75%              | 55.404               | 7.06%                     | 0.00                    |
| 8.5          | 7,839,270,000,000.00     | 78,392.7     | 86.10%              | 58.597               | 13.23%                    | 54,800,000,000.00       |

## Results & Conclusion
The biggest takeaway from these analyses is that small changes in storm intensity can create massive differences in damage costs and disaster relief spending. All storm versions in this analysis fall within or right outside of Category 3 status, yet there is an almost $4 trillion spread in terms of benefit between the historical and most adverse scenarios. Additionally, the most adverse scenario (RCP 8.5) generated residual risk of $54.8 billion, meaning that the adaptation measure was unable to mitigate all of the risk created by the storm under the most powerful forecast.

Over time, as these storm become slightly more powerful on average, it still equates to massive increases in disaster relief funds needed. This also doesn't account for deaths, labor, and other complications from storm damage. Additionally, it does not consider the economic losses that are not reflected in the price tag itself, so while the price is already high, the lasting economic losses are far greater.

This becomes important to consider when thinking about climate change policy and action. Small gains should not be ignored, and implementing measures consistently will help offset the increasingly damaging trends of storms.