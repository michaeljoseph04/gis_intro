library(sf)
library(tidyverse)
library(ggplot2)
library(scales)

# Read file
neighborhoods <- read_sf("project/data/City_Clerk_Neighborhoods.shp")

# Investigate
ggplot() +
  geom_sf(data = neighborhoods)

# Drop the empty neighborhoods.
neighborhods <- neighborhoods %>% drop_na(S_HOOD)

# You can add geom_sf_label(aes(label = S_HOOD)) to visualize the neighborhood labels.
# It's not pretty though and requires modification. It is useful to drop the S_HOOD
# cases which are NA, since many of these are small islands and other areas which
# will not be used later (obviously, use caution in this).

s_crs <- st_crs(neighborhoods)

# Now for other information.

collisions <- read.csv("project/data/collisions.csv", stringsAsFactors = FALSE)

# Change a misnamed column name in the csv
names <- colnames(collisions)
names[1] <-"X"
colnames(collisions) <- names
collisions <- na.omit(collisions)

# Select the data we want.
collisions <- collisions %>%
  select(x = X, y = Y, date = INCDATE) %>%
  mutate(date = substr(date, start = 1, stop = 4)) %>%
  filter(date == "2018") %>%
  select(-date)

# Make it a sf by setting the crs, which (City of Seattle affirms) is the same
collisions_sf <- st_as_sf(collisions,
                   coords = c('x', 'y'),
                   crs = s_crs,
                   remove = F)

# If we want to see it:
ggplot() +
  geom_sf(data=collisions_sf, alpha=.3)

# Perform the join.
collisions_join <- st_join(collisions_sf, neighborhoods, join = st_within)
head(collisions_join)

# Show the results of the join in a basic plot.
plot(collisions_join["S_HOOD"])

# So, let's now simply summarize.
collisions_count <- collisions_join %>%
  as.data.frame() %>%  #Use this to remove the sticky geometry
  group_by(S_HOOD) %>%
  summarize(collisions_n = n())

# Now we have the count by neighborhood:
head(collisions_count)

# Now left join it back to the shapefile just like normal, making sure to drop the NA's:
neighborhood_collisions <- left_join(neighborhoods,
                                     collisions_count,
                                     by="S_HOOD")


# We are effectively done, but let's do some more work that would be typical,
# namely counting collisions *per neighborhood area* rather than just as a through
# count.

# Now you can write it as a shapefile.
write_sf(neighborhood_collisions, "project/data/neighborhood_collisions.shp", delete_layer = TRUE)
# And a csv for any tables you might have to make.
write.csv(neighborhood_collisions, "project/data/neighborhood_collisions.csv")
write.csv(collisions_freq, "project/data/collisions_freq.csv")

# Or plot with ggplot. First, the count:
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

# Let's also, instead of a count, plot the collisions per the areas of the neighborhood:
library(lwgeom)
library(units)
neighborhood_areas <- st_area(neighborhood_collisions)
units(neighborhood_areas) <- with(ud_units, ft^2)

neighborhood_collisions$areas <- as.numeric(neighborhood_areas) #add row, convert to numeric

neighborhood_collisions <- neighborhood_collisions %>%
    mutate(collisions_sqft = collisions_n/areas)

# And plot that:
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

# Subset one by the other
s_city_tracts <- s_tracts[s_city,]

# See the tracts:
#ggplot() +
#  geom_sf(data=s_city)+
#  geom_sf(data=s_city_tracts, fill= NA, color = "darkblue")

# Now we do the spatial join of the collisions data, like before:
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

# Calculate areas, like before:
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
