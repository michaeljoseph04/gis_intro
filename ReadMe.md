## GIS in R with sf

*An introduction to using R as a GIS for urban spatial analysts*

As an urban policy analyst and planner, I have to do a lot of analysis of spatial data. But there are few introductions to the types of analyses which are common and useful in this area. This brief walkthrough and the accompanying code should guide readers through some of this territory, with the help of using the simple features (`sf`) package for spatial data. I will leave most GIScience and spatial analysis for future introductions. My primary aim is clarity in these introductions, and at the same time demonstrating the workflows most optimal for data analysis. Eventually, this work will migrate to a website and be featured in post form, but for now it is here.

In this introduction I'll cover:

- Importing spatial data into R
- Performing a spatial join
- Visualizing spatial data
- Other spatial operations (a dissolve) and joining to census tracts

More advanced operations may be added in the future.

# Data
The data I will be using is available from the [City of Seattle](https://data.seattle.gov/), which has made great strides in [Open Data practices](http://www.seattle.gov/tech/initiatives/open-data). To begin, I will use:

- [Vehicle collisions data](https://data.seattle.gov/Transportation/Collisions/vac5-r8kk), which is available as [.csv file](http://data-seattlecitygis.opendata.arcgis.com/datasets/5b5c745e0f1f48e7a53acec63a0022ab_0.csv).
- [City Clerk data on the neighborhoods of Seattle](https://data.seattle.gov/dataset/City-Clerk-Neighborhoods/926y-cwh9), specifically the [shapefile](http://data-seattlecitygis.opendata.arcgis.com/datasets/b76cdd45f7b54f2a96c5e97f2dda3408_2.zip) of the neighborhood boundaries with their identities.

Each of these files is available in the "data" folder above. Our workflow will involve:
- Importing the neighborhood boundaries, and importing and wrangling the collisions data to extract collisions in 2018
- Joining the collisions to the neighborhood boundaries
- Creating a summary (specifically, a count) of the number of collisions in each neighborhood
- Visualizing the result

The result will produce a simple chloropleth map differentiating the count of the collisions across neighborhoods in Seattle.

# Importing and Wrangling Data

We will import all the libraries we need:
```
library(sf)
library(tidyverse)
library(ggplot2)
library(scales)
```
The first, `sf`, is for dealing with data. The `tidyverse` will give us our data wrangling tools, and `ggplot2`, with the addition of the `scales` package, will be our framework for graphics.

Starting with the City Clerk shapefile of the neighborhood boundaries, I'll import the file with `read_sf()`:
```
neighborhoods <- read_sf("project/data/City_Clerk_Neighborhoods.shp")
```
We can immediately map the file with ggplot to see what looks like:
```
ggplot() +
  geom_sf(data = neighborhoods)
```
![plot1](/images/plot1.jpeg)

And we can see with `head()` what the data looks like:
```
OBJECTID PERIMETER S_HOOD L_HOOD L_HOODID SYMBOL SYMBOL2   AREA   ...
     <dbl>     <dbl> <chr>  <chr>     <dbl>  <dbl>   <dbl>  <dbl> ...
1       1.      618. OOO    NA           0.     0.      0.  3588. ...
2       2.      734. OOO    NA           0.     0.      0. 22295. ...
3       3.     4088. OOO    NA           0.     0.      0. 56695. ...
4       4.     1809. OOO    NA           0.     0.      0. 64157. ...
5       5.      250. OOO    NA           0.     0.      0.  2993. ...
6       6.      409. OOO    NA           0.     0.      0. 11371. ...
```
There are other variables as well. If you notice the last, *geometry*, you can see that the data also includes a variable for the geometries of the polygons in the shapefiles.

For my purposes, I want to simply look further at the *S_HOOD* variable, which has the City Clerk's names for each of the major neighborhoods. I will want to join, later, on this variable. One matter of data cleaning: we can drop the areas where *S_HOOD* has a value of *NA*. I have checked, and these mostly small areas such as [Kellogg Island](http://wikimapia.org/606799/Kellogg-Island), which should be connected to neighborhoods rather than considered seperate. A quick use of `dplyr`'s `drop_na()` can do that, which we can pipe, rather than repeatedly assign the variable. Though in this case the code is just about as long either way, it is good habit and leads to more readable code:
```
neighborhods <- neighborhoods %>% drop_na(S_HOOD)
```

One last matter before moving on to the collisions data: it is important to determine (and, for later, retrieve) the coordinate reference system from the shapefile-become-sf:
```
s_crs <- st_crs(neighborhoods)
```
Now I'll import the collisions data. I also do some data wrangling because of the way the file is organized. I'll begin with the import:
```
collisions <- read.csv("project/data/collisions.csv", stringsAsFactors = FALSE)
```
This data is tidy: the columns specify variable names, the rows specify cases. There's only a little bit of wrangling to do. First, I'll change the first variable name in the csv, which is hard to manipulate, and drop the rows which have locations but no other information (a few of which are in the dataset), using `drop_na()`, this time with all fields specified. The reasoning is that if there is a missing value, especially in the first two fields, we can't plot it. Of course, these data wrangling tasks should be done with care and attention to how they affect the entire analysis:
```
# Change a misnamed column name in the csv
names <- colnames(collisions)
names[1] <-"X"
colnames(collisions) <- names
collisions <- collisions %>% drop_na()
```
Then I will filter to retrieve the collisions from 2018. This involves some data manipulation with `dplyr`. First, I select only the x and y columns and the date variable. I choose to rename the variables as I go (by specifying first the desired field name just for ease of reference. Then I create a field with `mutate()` in which I extract the first four characters of the date variable. For this I use the substring function `substr`, in which I specify the point to start and stop extracting characters in the date string. Since I am only going to be using dates from 2018, I actually replace the old date field by assigning it the same variable name ("date"). From there, I filter for the values of 2018 and then drop the date field, leaving me with just the coordinates:
```
collisions <- collisions %>%
  select(x = X, y = Y, date = INCDATE) %>%
  mutate(year = substr(date, start = 1, stop = 4)) %>%
  filter(year == "2018") %>%
  select(-date)
```
Next, I take the resulting collisions data frame and turn it into a `sf` object. The City of Seattle confirms that the coordinate reference system is the same as the shapefile of the neighborhoods (WGS-84 or EPSG:4326), and so I set it to the crs variable I extracted from that shapefile:
```
collisions_sf <- st_as_sf(collisions,
                   coords = c('x', 'y'),
                   crs = s_crs,
                   remove = F)
```
We can plot the result. This takes a little while with ggplot given the size of the data frame. I have change the alpha of the points to make their frequency easier to display:
```
ggplot() +
  geom_sf(data=collisions_sf, alpha=.3)
```
![plot5](/images/plot5.jpeg)

# Spatially Joining the Data

Now we can join the data. I use `st_join` to specify a spatial join, and also specify that we want the *collisions_sf* shape joined to the *neighborhoods* shape. I will also make clear that I want all the collisions completely within the neighborhoods to be joined (this can be modified to include any of the usual qualities, including intersecting, touching, etc.):
```
collisions_join <- st_join(collisions_sf, neighborhoods, join = st_within)
```
We can see the results of the join, where the *x* and *y* variables of the *collisions* dataframe now have variables of the *neighborhoods* data joined to them:
```
x        y OBJECTID PERIMETER            S_HOOD           ...
1 -122.3329 47.70956      112  29413.55       Haller Lake ...
2 -122.2794 47.51707       81  38996.71 South Beacon Hill ...
3 -122.2907 47.69020       96  23840.22          Wedgwood ...
4 -122.3498 47.64651       46  26753.56  North Queen Anne ...
5 -122.3300 47.61226       63  13225.23        First Hill ...
6 -122.3050 47.60217       55  18241.55             Minor ...
```

# Summarizing the Data
Now we want to count how many crashes are within the each neighborhood, and visualize the result. Since the `sf` objects are data frames, this operation can be done simply by summarizing the data as one would normally do with the `group_by()` and `summarize()` workflow of `dplyr`, here `group_by()`, which will be set to the *S_HOOD* variable and `count()` (a quick call to just `count()` would have been sufficient, but I wanted to specify the variable name for future reference.)

The only additional step I have to consider in this operation is that we have to set aside the geometry data which attaches to each case of the spatial data, in order to perform the count. Freed of the geometries, we can then re-attach them by joining them the back to the original *neighborhoods* dataset. To do this, I then make a quick call to `as.data.frame()` before peforming the grouping and summarizing:
```
collisions_count <- collisions_join %>%
  as.data.frame() %>%  #Use this to remove the sticky geometry
  group_by(S_HOOD) %>%
  summarize(collisions_n = n())
```
This gives us the number of collisions per neighborhood:
```
S_HOOD          collisions_n
 <chr>         <int>
1 Adams           164
2 Alki             69
3 Arbor Heights    23
4 Atlantic        244
5 Belltown        437
6 Bitter Lake     146
```
(As an aside, this detaching and re-attaching geometries here has to be done because `sf` can't yet join spatial objects to spatial objects directly. But as you can see, it  makes intuitive sense from within the workflow to see geometry data as "sticky": the workflow is from extracting and manipulating the spatial data *variables* like any other tidy data, then joining the variables back to the data they came from, when they want to be used in context with all the other variables. The `sf` workflow just allows the geometries to unstick and stick back on when we want them.)

# Visualizing
As mentioned above, we have to join the count data back to the original neighborhood data in order to see it in context with the rest of the variables. Just as in any GIS interface, there's no need for any spatial joins here at all, but just a joining of the data: `sf` lets me just do this with a simple `left_join()` on the *S_HOOD* variable.
```
neighborhood_collisions <- left_join(neighborhoods,
                                     collisions_count,
                                     by="S_HOOD")
```
Now let's plot the finished product with `ggplot()`. With a simple call to `geom_sf()`, mentioned earlier, we can specify that the `fill` should be the new variable we created which counts the number of collisions. I here also specify a scale fill, with some colors, and use the `comma` argument from the `scales` package to make sure that the data doesn't display in scientific format in the legend. After setting the theme with `theme_bw()`, the final thing is to remove the axis text and ticks:
```
ggplot() +
  geom_sf(data = neighborhood_collisions, aes(fill = collisions_n)) +
  labs(fill = "Collisions in 2018") +
  scale_fill_continuous(low = "grey90",
                        high = "darkblue",
                        labels=comma)+
  theme_bw() +
  theme(axis.text.x = element_blank()) +
  theme(axis.text.y = element_blank()) +
  theme(axis.ticks.x = element_blank()) +
  theme(axis.ticks.y = element_blank())
  ```
  ![plot6](/images/plot6.jpeg)

However, a common operation would be not plotting just the count but the count per area. The City Clerk neighborhood's file has this already calculated in square feet in the *AREA* field and so a simple change of the `fill` argument to `collisions_n/AREA` will plot the collisions per sq.ft., a more accurate and informative chloropleth map. If we wanted to make the calculation ourself, however, `st_area()` in `sf` allows us to do this (with the help of the `lgeom` package, which must be loaded), and the `units` package to convert the result, which is in square meters, to square feet. We then simply add this variable (after converting it to a decimal result) to our data (we can just use `$`) and use `mutate` to add another variable which would be the collisions per square foot. This then can be used for plotting the more accurate map:
```
library(lwgeom)
library(units)
neighborhood_areas <- st_area(neighborhood_collisions)
units(neighborhood_areas) <- with(ud_units, ft^2)

neighborhood_collisions$areas <- as.numeric(neighborhood_areas) #add row, convert to numeric

neighborhood_collisions <- neighborhood_collisions %>%
  mutate(collisions_sqft = collisions_n/areas)

ggplot()+
    geom_sf(data = neighborhood_collisions, aes(fill = collisions_sqft)) +
    labs(fill = "Seattle Collision Density, 2018 (Collisions per sqft.)") +
    scale_fill_continuous(low = "grey90",
                          high = "darkblue",
                          labels=comma)+
    theme_bw() +
    theme(axis.text.x = element_blank()) +
    theme(axis.text.y = element_blank()) +
    theme(axis.ticks.x = element_blank()) +
    theme(axis.ticks.y = element_blank())
  ```
  ![plotF](/images/plotF.jpeg)

# Other Operations

We can also perform another common operation, which is to join this data to census tracts. In what follows, we will use the `tigris` and `acs` packages to do this. `acs` requires an API key, which can be obtained [from the U.S. Census Bureau](https://api.census.gov/data/key_signup.html) easily. See `help(package="acs")` for instructions on how to set this up easily, with a quick use of `api.key.install(key="YOUR API KEY")`.

Our tasks will be, then:
- Dissolving the neighborhood boundaries object to obtain a city boundary
- Downloading Census data and selecting those within  the city boundaries
- Joining the collision data to the tracts

We can dissolve the city neighborhoods by simply creating a group within the sf which includes all of the neighborhoods, and summarizing over them:
```
s_city <- neighborhoods %>%
  mutate(group = 1) %>%
  group_by(group) %>%
  summarize()
```
The result is what you would expect, a dissolved polygon:
![plot7](/images/plot7.jpeg)

Now, let's get the census tracts. We can set the environment so that we download simple features data with the tigris package, and put it in the cache as we work (rather than download it to a directory). Then with a call to `tracts()` we download the county data (specifying cb as true for a simpler geometry, rather than a 500k resolution geometry):
```
library(tigris)

options(tigris_class = "sf")
options(tigris_use_cache = TRUE)
s_tracts <- tracts(state="WA", county="King", cb=TRUE)
```
Next, we transform the tracts *sf* from its coordinate reference system into the reference system used by the Seattle census tracts, and then extract the census tracts which overlap with the city boundaries by simply subsetting one to the other:
```
s_tracts <- st_transform(s_tracts, crs=s_crs)
s_city_tracts <- s_tracts[s_city,]

```
Plotting this shows us the census tracts:
![plot8](/images/plot8.jpeg)

The shape is slightly different because some of the tracts share edges with the border of the city. We can clean this if we want, but for now let's just move on. Because immediately we can then go about all of the spatial joining to the census tracts just as we did above, and the calculations for density by the tract's area in square feet. This gives us another detailed map when we plot it:
![plotTract](/images/plotTract.jpeg)

Now we can fetch data from the Census and look for spatial correlations (which, as in this example, might be tenuous), or simply research using the Census data with the addition of the data we joined. 

# Conclusions

As you can see, you can do these common GIS operations rather easily. The only additional thing we may want to do, for now, is write our manipulated data to a shapefile with a simple call to `write_sf()`:
```
write_sf(neighborhood_collisions, "project/data/neighborhood_collisions.shp", delete_layer = TRUE)
```

There are many more things we can do with this data now within R. I will have further introductions to spatial analysis with these workflows in the future.

In the meantime, for more information on visualizing the data in a more sophisticated manner than I have attempted here, you may want to check out [r-spatial's great series of posts on making maps](https://www.r-spatial.org/r/2018/10/25/ggplot2-sf.html) in R, which also involve including many of the traditional cartographic elements useful for presentation-quality material. You might also want to see the `sf` package's [documentation](https://r-spatial.github.io/sf/) for more information, in particular their [cheatsheet](https://github.com/rstudio/cheatsheets/blob/master/sf.pdf), which works as a handy graphical summary of the package's approach to many common spatial data manipulation operations. You may also want to check out the `tigris`, `acs` and `tidycensus` packages for info on easily retrieving and manipulating census data with R.
