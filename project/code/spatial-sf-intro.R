library(sf)
library(tidyverse)
library(ggplot2)
library(scales)

# Read file
neighborhoods <- read_sf("project/data/City_Clerk_Neighborhoods.shp")

# Investigate
ggplot() +
  geom_sf(data = neighborhoods)

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

# Now left join it back to the shapefile just like normal:
neighborhood_collisions <- left_join(neighborhoods,
                                     collisions_count,
                                     by="S_HOOD")


plot(neighborhood_collisions["collisions_count"])

# Now you can write it as a shapefile.
write_sf(neighborhood_collisions, "project/data/neighborhood_collisions.shp", delete_layer = TRUE)
# And a csv for any tables you might have to make.
write.csv(neighborhood_collisions, "project/data/neighborhood_collisions.csv")
write.csv(collisions_freq, "project/data/collisions_freq.csv")

# Or plot with ggplot.
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
