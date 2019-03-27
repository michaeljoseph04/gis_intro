library(sf)
library(tidyverse)
library(ggplot2)
library(scales)

# Read file
neighborhoods <- read_sf("project/data/City_Clerk_Neighborhoods.shp")

# Investigate
ggplot(neighborhoods) +
  geom_sf()

head(neighborhoods)

s_crs <- st_crs(neighborhoods)

# We can access information just like a dataframe.
ggplot(data = neighborhoods) +
  geom_sf(aes(fill = AREA)) +
  labs(fill = "Neighborhood Area") +
  scale_fill_continuous(low = "grey90",
                        high = "darkblue",
                        labels=comma)+
  theme_bw()+
  geom_text(data=neighborhoods,label="S_HOOD",
            color = "darkblue", fontface = "bold", check_overlap = FALSE)

#we can manipulate just like a dataframe to dissolve
neighborhoods_d <- neighborhoods %>%
  mutate(g = "1") %>%
  group_by(g) %>%
  summarize()

ggplot(data = neighborhoods_d) +
  geom_sf() +
  theme_bw()

#now for other information
#read in the city data from a csv and turn it into an sf object
#use a spatial join (st_join) to assign each city to a region
#use group_by and summarize to calculate the total population by region

collisions <- read.csv("project/data/collisions.csv", stringsAsFactors = FALSE)

# Change a misnamed column name in the csv
names <- colnames(collisions)
names[1] <-"X"
colnames(collisions) <- names
collisions <- na.omit(collisions)

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

ggplot(collisions_sf) +
  geom_sf(alpha=.3)

collisions_join <- st_join(collisions_sf, neighborhoods, join = st_within)
head(collisions_join)

# Show the results of the join
plot(collisions_join["S_HOOD"]) #now we see each city is within a region

# So, let's now simply summarize.
collisions_count <- collisions_join %>%
  as.data.frame() %>%  #use this to remove the sticky geometry
  group_by(S_HOOD) %>%
  count()

# Now we have the count by neighborhood.
head(collisions_count)

# Now left join it back to the shapefile just like normal.
# We have to do this since we can join tables to shapes, not shapes to shapes (yet)
neighborhood_collisions <- left_join(neighborhoods,
                                     collisions_count,
                                     by="S_HOOD")


plot(neighborhood_collisions["n"])

# Now you can write it as a shapefile.
write_sf(neighborhood_collisions, "project/data/neighborhood_collisions.shp", delete_layer = TRUE)
# And a csv for any tables you might have to make.
write.csv(neighborhood_collisions, "project/data/neighborhood_collisions.csv")
write.csv(collisions_freq, "project/data/collisions_freq.csv")

# Or plot with ggplot.
ggplot(data = neighborhood_collisions) +
  geom_sf(aes(fill = n)) +
  labs(fill = "Collisions in 2018") +
  scale_fill_continuous(low = "grey90",
                        high = "darkblue",
                        labels=comma)+
  theme_bw() +
  theme(axis.text.x = element_blank()) +
  theme(axis.text.y = element_blank()) +
  theme(axis.ticks.x = element_blank()) +
  theme(axis.ticks.y = element_blank())
