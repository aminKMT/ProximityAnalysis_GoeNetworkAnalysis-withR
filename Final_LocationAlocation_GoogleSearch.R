library(httr)
library(jsonlite)
library(googleway)
library(ggmap)
library(leaflet)
library(dplyr)
library(openxlsx)

# Model Inputs**************************************************************************************************
api_key      <- "Your Google Maps API Key" # Replace with your Google Maps ApI Key.
search_query <- "chinies restaurant" # define any  keyword or name
#Addresses:
Add1         <- "Philadelphia Museum of Art - 2600 Benjamin Franklin Pkwy, Philadelphia, PA 19130"
Add2         <- "Reading Terminal Market - 1136 Arch St, Philadelphia, PA 19107"
Add3         <- "Independence Hall - 520 Chestnut St, Philadelphia, PA 19106"
m            <- 7 # maximum number of selected/optimal place
radius       <- 6000    # Search Radius
price_range  <-  c(1,4) #numeric vector Specifying the minimum and maximum price ranges. Values range between 0 (most affordable) and 4 (most expensive).
open_now     <-  FALSE  #logical Returns only those places that are open for business at the time the query is sent. Places that do not specify opening hours in the Google Places database will not be returned if you include this parameter in your query
# Routing parameters:
mode           <- "driving"
departure_time <- "now"
traffic_model  <- "optimistic"
# **************************************************************************************************************

register_google(api_key)
# Prepare a data frame containing the coordinates of potential customers:
addresses <- c(Add1,Add2, Add3)
customers <- geocode(addresses)
#Define the potential store locations:
# Find the nearest location (store)
nearest_place <- function(coord) {
  result <- google_places(location = coord,
                          keyword = search_query,
                          #rankby = "distance",
                          radius = radius,
                          key = api_key, 
                          open_now = open_now,
                          price_range = price_range) 
  return(result$results)
}

sl <- lapply(1:nrow(customers), function(i) {
  nearest_place(c(customers$lat[i], customers$lon[i]))
})


# Extract the first row from each data frame and join them vertically
sl_cor <- bind_rows(sapply(1:length(sl), function(i) sl[[i]][[2]][1], simplify = FALSE))
sl_name <- bind_rows(sapply(1:length(sl), function(i) data.frame(sl[[i]][[6]]), simplify = FALSE))

#using the above function for conversion: 
sl_PriceLevel <- bind_rows(sapply(1:length(sl), function(i) data.frame(sl[[i]][[11]]), simplify = FALSE))
sl_rating <- bind_rows(sapply(1:length(sl), function(i) data.frame(sl[[i]][[12]]), simplify = FALSE))
sl_type <- bind_rows(sapply(1:length(sl), function(i) data.frame(sl[[i]][15]), simplify = FALSE))

# Function to create a Google Maps URL using a Place ID
place_id_to_url <- function(place_id) {
  base_url <- "https://www.google.com/maps/place/?q=place_id:"
  return(paste0(base_url, place_id))
}
Gmap_links <- list()
for (i in 1:length(sl)) {
  Gmap_links[[i]] <- place_id_to_url(sl[[i]][[13]])
}
Gmap_links <- data.frame(Links = unlist(Gmap_links))
sl_Number_Raters <- bind_rows(sapply(1:length(sl), function(i) data.frame(sl[[i]][16]), simplify = FALSE))
sl_address <- bind_rows(sapply(1:length(sl), function(i) data.frame(sl[[i]][17]), simplify = FALSE))


potential_store_locations <-  data.frame(cbind(id            =  1:nrow(sl_cor),
                                               lat           =  sl_cor$location$lat, 
                                               lon           =  sl_cor$location$lng,
                                               Location_name =  sl_name$sl..i....6..,
                                               Address       =  sl_address$vicinity,
                                               Price_Level   =  sl_PriceLevel$sl..i....11..,
                                               Rating        =  sl_rating$sl..i....12..,
                                               Raters_Number =  sl_Number_Raters$user_ratings_total,
                                               Gmap_link     =  Gmap_links$Links,
                                               Info          =  sl_type))

# Create a function to compute the distance matrix using the googleway package:
get_distance_matrix <- function(customers, potential_store_locations) {
  distance_matrix <- matrix(nrow = nrow(customers), ncol = nrow(potential_store_locations))
  
  for (i in 1:nrow(customers)) {
    for (j in 1:nrow(potential_store_locations)) {
      route <- google_directions(
        origin = c(customers$lat[i], customers$lon[i]),
        destination = c(potential_store_locations$lat[j], potential_store_locations$lon[j]),
        key = api_key,
        mode = mode,
        departure_time = departure_time,
        traffic_model = traffic_model
      )
      distance_matrix[i,j] <- route$routes$legs[[1]][[2,2]][1] #it is for travel time in second; for distance: route$routes$legs[[1]][1, 1][2][[1]]
    }
  }
  
  return(distance_matrix)
}

#Compute the distance matrix:
distance_matrix <- get_distance_matrix(customers, potential_store_locations)


#Now, perform location allocation analysis:
# Custom function to find the indices of the 5 smallest elements

find_min_indices <- function(x, m) {
  sorted_indices <- order(x)
  min_indices <- sorted_indices[1:m]
  return(min_indices)
}

# Apply the custom function to each row of the distance_matrix
min_distance_indices <- apply(distance_matrix, 1, find_min_indices, m )
store_location_counts <- table(min_distance_indices) # Indicates the number of customers for whom each restaurant is among their five closest restaurants.

Optimal_store_location_counts<- sort(store_location_counts,decreasing = TRUE)[1:m]



optimal_store_location_ids <-data.frame(Optimal_store_location_counts)$min_distance_indices


optimal_store_locations <- potential_store_locations[potential_store_locations$id %in% optimal_store_location_ids, ]
View(optimal_store_locations)

#Print the optimal store location:
cat("Optimal store location Names:",optimal_store_locations$Location_name, sep = "\n")


