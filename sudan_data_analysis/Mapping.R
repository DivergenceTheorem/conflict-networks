install.packages("tmap")
install.packages("ggplot2")
install.packages("tidyverse")
install.packages("spData")
install.packages('spDataLarge', repos='https://nowosad.github.io/drat/',
                 type='source')
install.packages("maps")
install.packages("sf")
install.packages("gmodels")
install.packages("reshape2")
install.packages("writexl")
install.packages("dplyr")
install.packages("openxlsx")
install.packages("igraph")
install.packages("sna")

library(ggplot2)
library(tidyverse)
library(tmap)
library(spData)
library(maps)
library(sf)
require(gmodels)
library(reshape2)
library(writexl)
library(dplyr)
library(openxlsx)
library(igraph)
library(sna)

Sud_df <- read.csv("2003-01-01-2011-12-31-Northern_Africa-Sudan.csv") #Main data frame

#--------Interactive map-------------------
data(world)
Sud_sf <- st_as_sf(Sud_df, coords = c("longitude", "latitude"), crs = 4326)
tmap_mode("view")

tm_shape(Sud_sf) +
  tm_dots(col = "red", size = 0.1) +
  tm_basemap("OpenStreetMap.Mapnik") +
  tm_layout(title = "Interactive Map of Locations")
#--------------------------------------


#---------------Relationship matrices-------------------
actorsAll <- unique(c(Sud_df$actor1, Sud_df$assoc_actor_1, Sud_df$actor2, Sud_df$assoc_actor_2)) #load all actors mentioned in dataset
actorsAll <- actorsAll[!actorsAll %in% c("")] #clear empty values
#------Enmity matrix
enmity_matrix <- matrix(0, nrow = length(actorsAll), ncol = length(actorsAll), dimnames = list(actorsAll, actorsAll))
for (i in 1:nrow(Sud_df)) { #Iterating through each row in the dataset
  actor1 <- Sud_df$actor1[i] #Take value from actor1 column
  actor2 <- Sud_df$actor2[i] #Take value from actor2 column
  if (actor1 != actor2) { 
    enmity_matrix[actor1, actor2] = 1 #Once actors found themselves as enemies, their intersection at enmity matrix is set to 1
    enmity_matrix[actor2, actor1] = 1
  }
}
#------Friendship matrix
friendship_matrix <- matrix(0, nrow = length(actorsAll), ncol = length(actorsAll), dimnames = list(actorsAll, actorsAll))
for (i in 1:nrow(Sud_df)) {
  actor <- Sud_df$actor1[i] #actor is loaded
  assoc_actor <- Sud_df$assoc_actor_1[i] #actor's ally is loaded
  if (!is.na(actor) && !is.na(assoc_actor)) { #if actor and assoc_actors cells are not empty
    if (actor %in% actorsAll && assoc_actor %in% actorsAll) { #if examined actors are in the actorsAll list
      friendship_matrix[actor, assoc_actor] <- 1
      friendship_matrix[assoc_actor, actor] <- 1
    }
  }
  actor <- Sud_df$actor2[i]
  assoc_actor <- Sud_df$assoc_actor_2[i]
  if (!is.na(actor) && !is.na(assoc_actor)) {
    if (actor %in% actorsAll && assoc_actor %in% actorsAll) {
      friendship_matrix[actor, assoc_actor] <- 1
      friendship_matrix[assoc_actor, actor] <- 1
    }
  }
}

resultant_matrix = friendship_matrix - enmity_matrix

#-------Transforming matrices and saving in Excel 
resultant_df <- as.data.frame(resultant_matrix) #transforming to dataframe
resultant_df <- resultant_df %>% 
  select(actorsAll, everything())
write.xlsx(resultant_df,"Resultant_matrix.xlsx", rowNames = TRUE) #save to excel with row names

friendship_df <- as.data.frame(friendship_matrix)
friendship_df <- friendship_df %>% 
  select(actorsAll, everything())
write.xlsx(friendship_df,"Friendship_matrix.xlsx", rowNames = TRUE)

enmity_df <- as.data.frame(enmity_matrix)
enmity_df <- enmity_df %>% 
  select(actorsAll, everything())
write.xlsx(enmity_df,"Enmity_matrix.xlsx", rowNames = TRUE)
#----------------------------------------------------------------------


#---------------Calculating the centralities of each agent-------------
cent_mat <- matrix(0, nrow = length(actorsAll), ncol = 7, dimnames = list(actorsAll, c('Degree centrality', 'Closeness centrality', 'Betweenness centrality', 'Katzs prestige', 'Eigenvector centrality', 'Bonacich centrality', 'Katz-Bonacich centrality')))
#----Degree centrality----
for(i in actorsAll){
  len <- length(actorsAll) #number of all actors (i.e. nodes, agents)
  links = 0
  for(j in actorsAll){
    if (resultant_matrix[i, j] == 1 | resultant_matrix[i, j] == -1) {
      links = links + 1 #how many links a particular actor i has
    }
  }
  cent_mat[i, 'Degree centrality'] = (links)/(len - 1)
}
#----Closeness centrality----
new_res_matrix <- resultant_matrix #create a copy of the resultant matrix, because we're going to do a matrix multiplication

new_res_matrix[new_res_matrix == -1] <- 1 #transfer all -1 values to 1

shortest_paths <- matrix(0, nrow = length(actorsAll), ncol = length(actorsAll), dimnames = list(actorsAll, actorsAll))
num_links_shortest <- matrix(0, nrow = length(actorsAll), ncol = length(actorsAll), dimnames = list(actorsAll, actorsAll)) 
n = 1
while(n != 6){ #number of iterations
  for(i in actorsAll){
    for(j in actorsAll){
      if(shortest_paths[i, j] == 0){
        shortest_paths[i, j] = new_res_matrix[i, j]
        if(shortest_paths[i, j] != 0 && i!=j){
          num_links_shortest[i, j] = n #assign the length of the path by looking at the current power of the adjacency matrix
        }
      }
    }
  }
  new_res_matrix <- new_res_matrix %*% new_res_matrix #matrix multiplication to see the number of walks of length m
  n <- n + 1
}

for(i in actorsAll){
  n = 0
  sum = 0
  for(j in actorsAll){
    if(shortest_paths[i, j] != 0){
      n = n + 1 #consider only those cases where there exists a path between the agents
    }
    sum = sum + num_links_shortest[i, j]
  }
  if(sum != 0){
    cent_mat[i, 'Closeness centrality'] = (n - 1)/sum
  }
}

#----Betweenness centrality----
new_res_matrix <- resultant_matrix

new_res_matrix[new_res_matrix == -1] <- 1
g <- graph_from_adjacency_matrix(new_res_matrix, mode = "undirected")

betweenness_centrality <- igraph::betweenness(g)
n = length(actorsAll)
betweenness_centrality <- betweenness_centrality / ((n-1)*(n-2)/2) #Normalization of betweenness
cent_mat[, 'Betweenness centrality'] = betweenness_centrality

#-----Katz's prestige-----
new_res_matrix <- resultant_matrix
new_res_matrix[new_res_matrix == -1] <- 1
for (i in actorsAll){
  sum = sum(new_res_matrix[, i])
  if(sum!=0){
    new_res_matrix[, i] <- new_res_matrix[, i] / sum #normalizing the adjacency matrix to obtain g' (normalized)
  }
}

eigen_result <- eigen(new_res_matrix) #find the eigenvalues
eigenvectors <- eigen_result$vectors #derive the eigenvectors
unit_eigenvectors <- eigenvectors  #create a new set of eigenvectors that will turn into unit eigenvecotrs
for (i in 1:ncol(eigenvectors)) {
  norm <- sqrt(sum(eigenvectors[, i]^2))  # norm of eigenvectors
  unit_eigenvectors[, i] <- eigenvectors[, i] / norm  #unity eigenvectors obtained
}

vec <- matrix(c(unit_eigenvectors[, 2]), nrow = length(actorsAll), ncol = 1, dimnames = list(actorsAll, 'cent')) #choosing an arbitrary eigenvector, but which one should I pick?
for(i in actorsAll){
  cent_mat[i, 'Katzs prestige'] <- vec[i, 'cent']
}
cent_mat <- ifelse(Im(cent_mat) == 0, Re(cent_mat), cent_mat) #getting rid of the complex number notation


#----Eigenvector centrality (power iteration method until convergence to third decimal (10^-2)---- 
new_res_matrix <- resultant_matrix

new_res_matrix[new_res_matrix == -1] <- 1
n=0 
vec = matrix(1, nrow = length(actorsAll), ncol = 1, dimnames = list(actorsAll, 'cent'))
while(n!=12){
  temp_vec <- new_res_matrix %*% vec
  sum = 0
  for(i in temp_vec){
    sum = sum + i
  }
  sum_sq = sum**(0.5)
  vec <- temp_vec/sum_sq
  n = n + 1
}

cent_mat[, 'Eigenvector centrality'] = vec

#----Bonacich centrality----
new_res_matrix <- resultant_matrix 
new_res_matrix[new_res_matrix == -1] <- 1

bonacich_centrality <- bonpow(new_res_matrix, exponent = 0.5) #exponent - value of alpha in Bonacich centrality, beta is set to 1 by default
cent_mat[, 'Bonacich centrality'] = bonacich_centrality

#----Konig's paper centrality------
beta = 0.3 #pick some beta
gamma = 0.2 #pick some gamma
deg_pos <- matrix(0, nrow = length(actorsAll), ncol = 1, dimnames = list(actorsAll, 'Degree')) #di+
deg_neg <- matrix(0, nrow = length(actorsAll), ncol = 1, dimnames = list(actorsAll, 'Degree')) #di-
for (i in actorsAll){
  deg = 0
  for (j in actorsAll){
    if(friendship_matrix[i, j] == 1){
      deg = deg + 1
    }
  }
  deg_pos[i, 'Degree'] = deg
  deg = 0
  for (j in actorsAll){
    if(enmity_matrix[i, j] == 1){
      deg = deg + 1
    }
  }
  deg_neg[i, 'Degree'] = deg
}
local_hostility <- matrix(0, nrow = length(actorsAll), ncol = 1, dimnames = list(actorsAll, 'Hostility')) # Gamma[b, a](G)
for (i in actorsAll){
  hostility = 1/(1 + beta * deg_pos[i, 'Degree'] - gamma * deg_neg[i, 'Degree'])
  if(hostility > 0){ #Check for hostility to be more than 0
    local_hostility[i, 'Hostility'] = hostility
  }
  #If the hostility is negative then for now it will remain zero. It strongly depends on what value of constants I pick
}

#Now to find the centrality matrix which consists of two components - inverse matrix and local hostility matrix
len <- length(actorsAll)
inverse <- solve((diag(len) + beta * friendship_matrix - gamma * enmity_matrix)) #solve() function yields an inverse matrix
centrality <- inverse %*% local_hostility #multiplying two components and obtainig the desired matrix
dimnames(centrality) <- list(actorsAll, 'Centrality') #Rename the column to 'centrality' 

cent_mat[, 'Katz-Bonacich centrality'] <- centrality


#----------Some visualization-----------
new_res_matrix <- resultant_matrix
new_res_matrix[new_res_matrix == -1] <- 1

g <- graph_from_adjacency_matrix(new_res_matrix, mode = "undirected", diag = FALSE)
plot(g, vertex.label = V(g)$name, main = "Graph from Adjacency Matrix")

layout_fr <- layout_with_fr(g)

# Plot the graph with increased visual distance
plot(g, 
     layout = layout_fr, 
     vertex.size = 10, 
     vertex.label.cex = 0.4, 
     vertex.label.dist = 1, 
     edge.color = "blue", 
     edge.width = 2, 
     main = "Graph with Fruchterman-Reingold Layout")




