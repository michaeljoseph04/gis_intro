## GIS in R

*An Introduction to using R as a GIS for urban spatial analysts*

As an urban planner and policy analyst, I have to do a lot of data analysis of spatial data. But there are few good introductions to the types of analyses which are common and useful, and how to go about them. This brief tutorial and the accompanying code should guide readers through some of this territory. I will leave most GIScience and spatial analysis for future introductions. Where this everything should be extremely clear, and the workflows should be the most optimal for data analysis. I'll cover:

- Importing spatial data into R
- Visualizing spatial data
- Performing a spatial join
- Performing a dissolve
- Performing basic spatial data exploration

More advanced operations may be added in the future.

# Data
The data I will be using is available from the [City of Seattle](https://data.seattle.gov/), which has made great strides in [Open Data practices](http://www.seattle.gov/tech/initiatives/open-data). To begin, I will use:

- [Vehicle collisions data](https://data.seattle.gov/Transportation/Collisions/vac5-r8kk), which is available as [.csv file](http://data-seattlecitygis.opendata.arcgis.com/datasets/5b5c745e0f1f48e7a53acec63a0022ab_0.csv).
- [City Clerk data on the neighborhoods of Seattle](https://data.seattle.gov/dataset/City-Clerk-Neighborhoods/926y-cwh9), specifically the [shapefile](http://data-seattlecitygis.opendata.arcgis.com/datasets/b76cdd45f7b54f2a96c5e97f2dda3408_2.zip) of the neighborhood boundaries with their identities.

Each of these files is available in the "data" folder above. Our workflow will involve:
- Importing the neighborhood boundaries
- 

# Importing data

We will import all the libraries we need:
```
library(sf)
library(tidyverse)
library(ggplot2)
library(scales)
```
The first, `sf`, is for dealing with data. The `tidyverse` will give us our data wrangling tools, and `ggplot2`, with the `scales` package, will be our framework for graphics.

Starting with the shapefile the shapefile can be done with `read_sf()`:
```
neighborhoods <- read_sf("project/data/City_Clerk_Neighborhoods.shp")
```
