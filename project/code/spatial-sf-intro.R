library(sf)
library(tidyverse)
library(ggplot2)
library(scales)

# Read file
neighborhoods <- read_sf("project/data/City_Clerk_Neighborhoods.shp")

# Investigate
#ggplot() +
#  geom_sf(data = neighborhoods)

# You can add geom_sf_label(aes(label = S_HOOD)) to visualize the neighborhood labels.
# It's not pretty though and requires modification.

head(neighborhoods)

s_crs <- st_crs(neighborhoods)

# Now for other information.

collisions <- read.csv("project/data/collisions.csv", stringsAsFactors = FALSE)

# Change a misnamed column name in the csv
names <- colnames(collisions)
names[1] <-"X"
colnames(collisions) <- names

# Select the data we want.
collisions <- collisions %>%
  select(x = X, y = Y, date = INCDATE) %>%
  mutate(date = substr(date, start = 1, stop = 4)) %>%
  filter(date == "2018") %>%
  select(-date)
collisions <- na.omit(collisions)

# Make it a sf by setting the crs, which (City of Seattle affirms) is the same
collisions_sf <- st_as_sf(collisions,
                   coords = c('x', 'y'),
                   crs = s_crs,
                   remove = F)

# If we want to see it:
#ggplot() +
#  geom_sf(data=collisions_sf, alpha=.3)

# Perform the join.
collisions_join <- st_join(collisions_sf, neighborhoods, join = st_within)

# Look at it
#head(collisions_join)

# Show the results of the join in a basic plot.
#plot(collisions_join["S_HOOD"])

# So, let's now simply summarize.
collisions_count <- collisions_join %>%
  as.data.frame() %>%  #Use this to remove the sticky geometry
  group_by(S_HOOD) %>%
  summarize(collisions_n = n())

# Now we have the count by neighborhood:
#head(collisions_count)

# Now left join it back to the shapefile:
neighborhood_collisions <- left_join(neighborhoods,
                                     collisions_count,
                                     by="S_HOOD") %>%
  drop_na(S_HOOD)

# Results:
#plot(neighborhood_collisions["collisions_count"])

#Let's do the area calculations ourselves.

library(lwgeom)
library(units)
neighborhood_areas <- st_area(neighborhood_collisions)
units(neighborhood_areas) <- with(ud_units, ft^2)

neighborhood_collisions$areas <- as.numeric(neighborhood_areas) #add row, convert to numeric

neighborhood_collisions <- neighborhood_collisions %>%
  mutate(collisions_sqft = collisions_n/areas)

# Now you can write it as a shapefile.
write_sf(neighborhood_collisions, "project/data/neighborhood_collisions.shp", delete_layer = TRUE)
# And a csv for any tables you might have to make.
write.csv(neighborhood_collisions, "project/data/neighborhood_collisions.csv")
write.csv(collisions_freq, "project/data/collisions_freq.csv")

# Or plot with ggplot.
ggplot()+
  geom_sf(data = neighborhood_collisions, aes(fill = collisions_sqft)) +
  labs(fill = "Seattle Collision Density by Neighborhood, 2018
       (Collisions per sq.ft.)") +
  scale_fill_continuous(low = "grey90",
                        high = "darkblue",
                        labels=comma)+
  theme_bw() +
  theme(axis.text.x = element_blank()) +
  theme(axis.text.y = element_blank()) +
  theme(axis.ticks.x = element_blank()) +
  theme(axis.ticks.y = element_blank())

# Let's now plot it on census tracts instead.
library(tigris)

# Get the shapefiles in sf format
options(tigris_class = "sf")
options(tigris_use_cache = TRUE)
s_tracts <- tracts(state="WA", county="King", cb=TRUE)

# This file is full of valid sf polygons:
all(st_is_valid(s_tracts))

# View result
#ggplot(s_tracts) +
#  geom_sf()

# Next, dissolve the neighborhood boundaries to get the city borders.
s_city <- neighborhoods %>%
  mutate(group = 1) %>%
  group_by(group) %>%
  summarize()

#ggplot(s_city) +
#  geom_sf()

# The crs of the tract data is different, so make sure its the same as the boundaries.
st_crs(s_city)
st_crs(s_tracts)

s_tracts <- st_transform(s_tracts, crs=s_crs)

# Subset one by the other, which is incredibly easy.
# See https://www.r-bloggers.com/clipping-spatial-data-in-r/
s_city_tracts <- s_tracts[s_city,]

#or

s_city_tracts <- s_tracts %>% filter(lengths(st_intersects(s_tracts, s_city)) > 0)

# See the tracts:
ggplot() +
  geom_sf(data=s_city, fill="grey",color=NA)+
  geom_sf(data=s_city_tracts, fill= NA, color = "black")

# They are off: some are not clipped or cropped, first.
# But more problematic, some which are merely touching are included
# (see the top four tracts, which are actually outside of the City).

# You can eliminate visually

ggplot(data=s_city_tracts) +
  geom_sf(data=s_city, fill="grey",color=NA)+
  geom_sf(fill=NA, color="black")+
  geom_sf_text(aes(label=TRACTCE))

# This shows that some need to be dropped:

s_city_tracts <- s_city_tracts %>%
  filter(! TRACTCE %in% c("020900", "021000",
                          "021100", "021300", "026400", "026100",
                          "026700","026600", "026300", "026001"))

ggplot(data=s_city_tracts) +
  geom_sf(data=s_city, fill="grey",color=NA)+
  geom_sf(fill=NA, color="black")


# Now we do the spatial join of the collisions data
# and all the density calculations once more:
tract_collisions_join <- st_join(collisions_sf, s_city_tracts, join = st_within)

tract_collisions_count <- tract_collisions_join %>%
  as.data.frame() %>%
  group_by(TRACTCE) %>%
  summarize(collisions_n = n())

tract_collisions <- left_join(s_city_tracts,
                                     tract_collisions_count,
                                     by="TRACTCE") %>%
  drop_na(TRACTCE)

# Calculate areas
tract_areas <- st_area(tract_collisions)
units(neighborhood_areas) <- with(ud_units, ft^2)

tract_collisions$areas <- as.numeric(tract_areas) #add row, convert to numeric

tract_collisions <- tract_collisions %>%
  mutate(collisions_sqft = collisions_n/areas)

# Plot
ggplot()+
  geom_sf(data = tract_collisions, aes(fill = collisions_sqft)) +
  labs(fill = "Seattle Collision Density by Census Tract, 2018
       (Collisions per sq.ft.)") +
  scale_fill_continuous(low = "grey90",
                        high = "darkblue",
                        labels=comma)+
  theme_bw() +
  theme(axis.text.x = element_blank()) +
  theme(axis.text.y = element_blank()) +
  theme(axis.ticks.x = element_blank()) +
  theme(axis.ticks.y = element_blank())


# Combine with census data like income to see if there is spatial correlation:
api.key.install(key="761b0c0f232ed33089c5e342c176dcde5ab71c9f")

library(tidycensus)

#lookup MEANS OF TRANSPORTATION TO WORK BY VEHICLES AVAILABLE, B081410
#https://factfinder.census.gov/faces/tableservices/jsf/pages/productview.xhtml?src=bkmk
s_acs <- get_acs(geography = "tract", table = "B08141",
                state ="WA", county="King County", geometry = TRUE)

s_popcars <- s_acs %>%
  filter(variable %in% c("B08141_001", "B08141_002", "B08141_005")) %>%
  select(-moe) %>%
  spread(key=variable, value=estimate) %>%
  rename(pop=B08141_001, nocars=B08141_002, threecars=B08141_005) %>%
  mutate(cars = pop-nocars)

s_cars <- left_join(tract_collisions, s_popcars, by="GEOID") %>%
  select(GEOID, collisions_sqft, cars, nocars, threecars, areas, geometry)

ggplot(s_cars, aes(x=cars/areas, y=collisions_sqft)) +
  geom_point()+
  stat_smooth(method="lm", color="Orange", se=FALSE) +
  labs(title="Collision Density by Density of Households with Cars Available
       in Seattle Census Tracts")+
  xlab("Households with 1, 2, or 3+ Cars / Sq.Ft.")+
  ylab("Collisions / Sq.Ft.")+
  scale_x_continuous(labels=comma)+
  scale_y_continuous(labels=comma)+
  theme_classic()

ggplot(s_cars, aes(x=nocars/areas, y=collisions_sqft)) +
  geom_point()+
  stat_smooth(method="lm", color="Orange", se=FALSE) +
  labs(title="Collision Density by Density of Households with 0 Cars Available
       in Seattle Census Tracts")+
  xlab("Households with 0 Cars / Sq.Ft.")+
  ylab("Collisions / Sq.Ft.")+
  scale_x_continuous(labels=comma)+
  scale_y_continuous(labels=comma)+
  theme_classic()

# Just to see how much more work we need to build an accurate model,
# let's look at households with 3+ cars
ggplot(s_cars, aes(x=threecars/areas, y=collisions_sqft)) +
  geom_point()+
  stat_smooth(method="lm", color="Orange", se=FALSE) +
  labs(title="Collision Density by Density of Households with 3+ Cars Available
       in Seattle Census Tracts")+
  xlab("Households with 3+ Cars / Sq.Ft.")+
  ylab("Collisions / Sq.Ft.")+
  scale_x_continuous(labels=comma)+
  scale_y_continuous(labels=comma)+
  theme_classic()

# Plot maps to show the impact of policy decisions around these trends.
ggplot()+
  geom_sf(data = s_cars, aes(fill = nocars/areas)) +
  labs(fill = "Seattle Density of Households with 0 Cars Available, 2018
       (by Census Tract)") +
  scale_fill_continuous(low = "grey90",
                        high = "darkblue",
                        labels=comma)+
  theme_bw() +
  theme(axis.text.x = element_blank()) +
  theme(axis.text.y = element_blank()) +
  theme(axis.ticks.x = element_blank()) +
  theme(axis.ticks.y = element_blank())

ggplot()+
  geom_sf(data = s_cars, aes(fill = threecars/areas)) +
  labs(fill = "Seattle Density of Households with 3+ Cars Available, 2018
       (by Census Tract)") +
  scale_fill_continuous(low = "grey90",
                        high = "darkblue",
                        labels=comma)+
  theme_bw() +
  theme(axis.text.x = element_blank()) +
  theme(axis.text.y = element_blank()) +
  theme(axis.ticks.x = element_blank()) +
  theme(axis.ticks.y = element_blank())
