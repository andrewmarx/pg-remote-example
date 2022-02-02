#
# Let's load data from a non-spatial table using dplyr
#
library("dplyr")
library("dbplyr")

fgsp_database = src_postgres(dbname = "fgsp-test" , 
                             host = "database-test.czjjiuh5qhb7.us-east-2.rds.amazonaws.com",
                             port = 5432, 
                             user = "fgsp-user1",
                             password = "fgsppassword")

# This connects to the table, but doesn't actually download the data locally.
# If we work with it using dplyr, the work will actually be done remotely by the
# database, and then the result will be returned to us.
sampling_data <- tbl(fgsp_database, "sampling") 

# This forces the data to be downloaded locally, so now if we work with it, the
# calculations will be done by the computer we are working on.
sampling_data_local <- collect(sampling_data)
sampling_data_local

# By default, dplyr stores data in a tibble, which is basically just an advanced
# version of a data frame. We can convert it to a regular data frame if needed.
sampling_data_df <- as.data.frame(sampling_data_local)
sampling_data_df



#
# Let's load the spatial data
#
library("rgdal")

# Info for connecting to the database
dsn <- "PG:dbname='fgsp-test' host='database-test.czjjiuh5qhb7.us-east-2.rds.amazonaws.com' user='fgsp-user1' password='fgsppassword'"

# Let's get a list of spatial layers. There are a bunch of default layers created
# when PostGIS was enabled in the database (they start with "tiger.") that can be 
# ignored.
ogrListLayers(dsn)

# Let's load the property boundaries.
fgsp_sites = readOGR(dsn, "fgsp_sites")

# These boundaries came from FNAI. Let's see what info came with them
View(fgsp_sites@data)


# Plot each of the three sites with a different color
plot(fgsp_sites, col = c("red", "cyan", "green"))


# Load the sample point locations
sample_points = readOGR(dsn, "sample_points")

# Let's add the points to the last plot using a diamond shape
points(sample_points, pch = 18)

# Note that the points and sites were created using the same projections system.
# Which is why I didn't have to do any extra work reprojecting one of them.
library(sp)

proj4string(fgsp_sites)
proj4string(sample_points)


#
# Now, lets combine some of this data together.
#
library("rgeos")

# First, our sample_points data doesn't have any columns telling us where they
# actually occur. And we don't need it to, because we can get that info easily
# using spatial functions.
sample_point_info <- over(sample_points, fgsp_sites)

# Let's combine this info, which is just a data frame where each row corresponds
# to a sample point, with the point ids
sample_point_info <- cbind(id = sample_points$id, sample_point_info)

# We can now see we have all the related site info for each sample point in a df
View(sample_point_info)


# Alternatively, we can actually put this info back into the original sample point
# data. But let's say we aren't really interested in all of it, just a few relevant
# columns, like the name of the property and the managing agency. I could rename
# them, but want to keep the column names consistent for plotting in ggplot later
sample_points$MANAME <- sample_point_info$MANAME
sample_points$MANAGING_A <- sample_point_info$MANAGING_A

# Let's take a look
View(sample_points@data)


#
# ggplot2 visualization
#

library(ggplot2)

# To visualize with ggplot, we need to convert the spatial objects to dataframes.
# The process is different for the polygon and point data

# For the polygon data
fgsp_sites_df <- fortify(fgsp_sites)
fgsp_sites_df <- merge(fgsp_sites_df, fgsp_sites@data, by.x = "id", by.y = "fid")

# For the point data
sample_points_df <- as.data.frame(sample_points)

# A simple plot
ggplot() +
  theme_bw() +
  geom_polygon(data = fgsp_sites_df, mapping = aes(x = long, y = lat, group = group, fill = MANAME)) +
  geom_point(data = sample_points_df, mapping = aes(x = coords.x1, y = coords.x2)) +
  coord_fixed()

# More elaborate
ggplot() +
  theme_bw() +
  geom_polygon(data = fgsp_sites_df, mapping = aes(x = long, y = lat, group = group, fill = MANAME)) +
  geom_point(data = sample_points_df, mapping = aes(x = coords.x1, y = coords.x2)) +
  facet_wrap(~MANAME, scales = "free") +
  theme(aspect.ratio = 1, legend.position = "bottom")
  
