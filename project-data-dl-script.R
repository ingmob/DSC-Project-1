#setting download timeout to 100000 seconds
options(timeout=100000)
##########################################################
# Create edx set, validation set (final hold-out test set)
##########################################################

# Note: this process could take a couple of minutes
# Note: this process could take a couple of minutes

if(!require(tidyverse)) install.packages("tidyverse", repos = "http://cran.us.r-project.org")
if(!require(caret)) install.packages("caret", repos = "http://cran.us.r-project.org")
if(!require(data.table)) install.packages("data.table", repos = "http://cran.us.r-project.org")
if(!require(lubridate)) install.packages("lubridate", repos = "http://cran.us.r-project.org")
if(!require(xgboost)) install.packages("xgboost", repos = "http://cran.us.r-project.org")
if(!require(ggthemes)) install.packages("ggthemes", repos = "http://cran.us.r-project.org")
library(tidyverse)
library(caret)
library(data.table)
library(lubridate)
library(xgboost)
library(ggthemes)






# MovieLens 10M dataset:
# https://grouplens.org/datasets/movielens/10m/
# http://files.grouplens.org/datasets/movielens/ml-10m.zip

dl <- tempfile()
download.file("https://files.grouplens.org/datasets/movielens/ml-10m.zip", dl)

ratings <- fread(text = gsub("::", "\t", readLines(unzip(dl, "ml-10M100K/ratings.dat"))),
                 col.names = c("userId", "movieId", "rating", "timestamp"))

movies <- str_split_fixed(readLines(unzip(dl, "ml-10M100K/movies.dat")), "\\::", 3)
colnames(movies) <- c("movieId", "title", "genres")

# if using R 4.0 or later:
movies <- as.data.frame(movies) %>% mutate(movieId = as.numeric(movieId),
                                           title = as.character(title),
                                           genres = as.character(genres))


movielens <- left_join(ratings, movies, by = "movieId")

# Validation set will be 10% of MovieLens data
set.seed(1, sample.kind="Rounding") # if using R 3.5 or earlier, use `set.seed(1)`
test_index <- createDataPartition(y = movielens$rating, times = 1, p = 0.1, list = FALSE)
edx <- movielens[-test_index,]
temp <- movielens[test_index,]

# Make sure userId and movieId in validation set are also in edx set
validation <- temp %>% 
  semi_join(edx, by = "movieId") %>%
  semi_join(edx, by = "userId")

# Add rows removed from validation set back into edx set
removed <- anti_join(temp, validation)
edx <- rbind(edx, removed)

rm(dl, ratings, movies, test_index, temp, movielens, removed)


#WRANGLING
#Separating year_of_release from Title column and convert year to numeric
title_year_pattern<- "(\\(\\d\\d\\d\\d\\))"
data_set<- edx%>%mutate(year_of_release=str_extract(title,title_year_pattern),title=str_replace(title,title_year_pattern,""),year_of_release=str_replace(year_of_release,"\\(",""),year_of_release=str_replace(year_of_release,"\\)",""))
data_set<- data_set%>% mutate(year_of_release=as.integer(year_of_release))
#Converting timestamp to datetime format

data_set<- data_set%>%mutate(timestamp=as_datetime(timestamp))
#Using year from timestamp to create new predictor "years_from release"year of review - year of release
data_set<- data_set%>% mutate(year_of_rating=as.integer(year(timestamp)))
##Extract month of rating,day in the month of rating and time of rating in hours
#data_set<-data_set%>%select(!timestamp)
data_set<- data_set%>%mutate(rating_month=as.integer(month(data_set$timestamp)),rating_day=as.integer(day(data_set$timestamp)),nearest_hour_of_rating=as.integer(round(hour(data_set$timestamp)+minute(data_set$timestamp)/60+second(data_set$timestamp)/(60^2))))%>%select(!timestamp)


#Removing movie title since intuitively, it correlates to the movieID
data_set<-data_set%>%select(!title)


#EXPLORATORY ANALYSIS/PLOTS

#plot1 Plotting average rating across genres for top 5 frequently rated genres
to_plot1<-unique(data_set%>%group_by(genres)%>%mutate(n=n())%>% summarise(genres=genres,n=n(),avg=mean(rating)))%>%arrange(desc(n))
plot1<-to_plot1[1:5,]%>%ggplot(aes(genres,avg,group=1))+geom_point(color="darkgoldenrod4",size=2)+ geom_line(color="deeppink4")+xlab("Genres")+ylab("Average Rating")+ggtitle("Variation in average rating for the 5 most prevalent Genres")+theme_solarized()
#plot2 Show distribution of ratings for the most frequently rated genre: DRAMA
plot2<-data_set%>%filter(genres%in%to_plot1[1,]$genres)%>% ggplot(aes(rating))+ geom_histogram(binwidth = 1, fill = "antiquewhite4",color="darkgoldenrod4")+xlab("Rating")+ylab("Count")+ggtitle("Distribution of Ratings for the most frequently rated genre")+theme_solarized()

#plot3 Plotting average rating across movie release years for top 5 years with the most ratings 
to_plot3<-unique(data_set%>%group_by(year_of_release)%>%mutate(n=n())%>% summarise(year=year_of_release,n=n(),avg=mean(rating)))%>%arrange(desc(n))
plot3<-to_plot3[1:5,]%>%ggplot(aes(year,avg))+geom_point(color="darkgoldenrod4",size=2)+ geom_line(color="deeppink4")+xlab("Year")+ylab("Average Rating")+ggtitle("Variation in average rating for the 5 most prevalent Years of Release")+theme_solarized()
#plot4 Show distribution of ratings for movie release year with most movies: 1995
plot4<-data_set%>%filter(year_of_release%in%to_plot3[1,]$year_of_release)%>% ggplot(aes(rating))+ geom_histogram(binwidth = 1, fill = "antiquewhite4",color="darkgoldenrod4")+xlab("Rating")+ylab("Count")+ggtitle("Distribution of Ratings for movie release year with the most ratings")+theme_solarized()

#plot5 Plotting average rating across year of rating for top 5 years with the most ratings 
to_plot5<-unique(data_set%>%group_by(year_of_rating)%>%mutate(n=n())%>% summarise(year=year_of_rating,n=n(),avg=mean(rating)))%>%arrange(desc(n))
plot5<-to_plot5[1:5,]%>%ggplot(aes(year,avg))+geom_point(color="darkgoldenrod4",size=2)+ geom_line(color="deeppink4")+xlab("Year")+ylab("Average Rating")+ggtitle("Variation in average rating for the top 5 prevalent Years of Rating")+theme_solarized()
#plot6 Showing distribution of ratings for year_from_release with the most ratings
plot6<-data_set%>%filter(year_of_rating%in%to_plot5[1,]$year_of_rating)%>% ggplot(aes(rating))+ geom_histogram(binwidth = 1, fill = "antiquewhite4",color="darkgoldenrod4")+xlab("Rating")+ylab("Count")+ggtitle("Distribution of Ratings for the Year with the most ratings")+theme_solarized()


#plot7 Show variation of rating with user ID for the users with the top 5 most ratings 
to_plot7<-unique(data_set%>%group_by(userId)%>%mutate(n=n())%>% summarise(user=userId,n=n(),avg=mean(rating)))%>%arrange(desc(n))
plot7<-to_plot7[1:5,]%>%ggplot(aes(user,avg))+geom_point(color="darkgoldenrod4",size=2)+ geom_line(color="deeppink4")+xlab("userId")+ylab("Average Rating")+ggtitle("Variation in average rating for the top 5 prevalent user Id's")+theme_solarized()
#plot8 Show distribution of ratings for user with most movie ratings 
plot8<-data_set%>%filter(userId%in%to_plot7[1,]$userId)%>% ggplot(aes(rating))+ geom_histogram(binwidth = 1, fill = "antiquewhite4",color="darkgoldenrod4")+xlab("Rating")+ylab("Count")+ggtitle("Distribution of Ratings for User with the most ratings")+theme_solarized()

#plot9 Plotting average rating across movieID for top 5 users with the most ratings
to_plot9<-unique(data_set%>%group_by(movieId)%>%mutate(n=n())%>% summarise(movie=movieId,n=n(),avg=mean(rating)))%>%arrange(desc(n))
plot9<-to_plot9[1:5,]%>%ggplot(aes(movie,avg))+geom_point(color="darkgoldenrod4",size=2)+ geom_line(color="deeppink4")+xlab("movieId")+ylab("Average Rating")+ggtitle("Variation in average rating for the top 5 prevalent movieId's")+theme_solarized()
#plot10 Showing distribution of ratings for userID with the most ratings
plot10<-data_set%>%filter(movieId%in%to_plot9[1,]$movieId)%>% ggplot(aes(rating))+ geom_histogram(binwidth = 1, fill = "antiquewhite4",color="darkgoldenrod4")+xlab("Rating")+ylab("Count")+ggtitle("Distribution of Ratings for movie with the most ratings")+theme_solarized()

#MORE WRANGLING
#Coverting each possible genre to a predictor rather than having a single Genre predictor with 797 possible values

# Getting list of all possible genres
all_genres<- str_split(data_set$genres,"\\|")
all_genres<-unique(all_genres)
genres<- c()
extractor<- for (i in 1:length(all_genres)) {
  for (j in 1:length(all_genres[[i]])) {
    genres<- c(genres,all_genres[[i]][j])
  }
}
all_genres<- unique(genres) 


#Getting 1 or 0 values for each individually possible genre
Comedy=as.integer(str_detect(data_set$genres,"Comedy")*1)
Romance=as.integer(str_detect(data_set$genres,"Romance")*1)
Action=as.integer(str_detect(data_set$genres,"Action")*1)
Crime=as.integer(str_detect(data_set$genres,"Crime")*1)
Thriller=as.integer(str_detect(data_set$genres,"Thriller")*1)
Drama=as.integer(str_detect(data_set$genres,"Drama")*1)
SciFi=as.integer(str_detect(data_set$genres,"Sci-Fi")*1)
Adventure=as.integer(str_detect(data_set$genres,"Adventure")*1)
Children=as.integer(str_detect(data_set$genres,"Children")*1)
Fantasy=as.integer(str_detect(data_set$genres,"Fantasy")*1)
War=as.integer(str_detect(data_set$genres,"War")*1)
Animation=as.integer(str_detect(data_set$genres,"Animation")*1)
Musical=as.integer(str_detect(data_set$genres,"Musical")*1)
Western=as.integer(str_detect(data_set$genres,"Western")*1)
Mystery=as.integer(str_detect(data_set$genres,"Mystery")*1)
FilmNoir=as.integer(str_detect(data_set$genres,"Film-Noir")*1)
Horror=as.integer(str_detect(data_set$genres,"Horror")*1)
Documentary=as.integer(str_detect(data_set$genres,"Documentary")*1)
IMAX=as.integer(str_detect(data_set$genres,"IMAX")*1)
none=as.integer(str_detect(data_set$genres,"no genres listed")*1)
#combining them into a data frame
genres_df_main<-data.frame(Comedy,Romance,Action,Crime,Thriller,Drama,SciFi,Adventure,Children,Fantasy,War,Animation,Musical,Western,Mystery,FilmNoir,Horror,Documentary,IMAX,none)

#Joining to test set and removing current Genres predictor
data_set<-cbind(data_set,genres_df_main)
data_set<-data_set%>% select(!genres)

#Converting movieID to integer
data_set<-data_set%>%mutate(movieId=as.integer(movieId))


#Applying same wrangling to validation data before running models
validation<- validation%>%mutate(year_of_release=str_extract(title,title_year_pattern),title=str_replace(title,title_year_pattern,""),year_of_release=str_replace(year_of_release,"\\(",""),year_of_release=str_replace(year_of_release,"\\)",""))
validation<- validation%>% mutate(year_of_release=as.integer(year_of_release))
#Converting timestamp to datetime foat

validation<- validation%>%mutate(timestamp=as_datetime(timestamp))
#Using year from timestamp to create new predictor "years_from release"year of review - year of release
validation<- validation%>% mutate(year_of_rating=as.integer(year(timestamp)))

##Extracting month of rating,day in the month of rating and time of rating in hours and removing original timestamp
validation<- validation%>%mutate(rating_month=as.integer(month(validation$timestamp)),rating_day=as.integer(day(validation$timestamp)),nearest_hour_of_rating=as.integer(round(hour(validation$timestamp)+minute(validation$timestamp)/60+second(validation$timestamp)/(60^2))))%>%select(!timestamp)

#removing movie title since it correlates to the movieID
validation<-validation%>%select(!title)

#Getting 1 or 0 values for each individually possible genre
Comedy=as.integer(str_detect(validation$genres,"Comedy")*1)
Romance=as.integer(str_detect(validation$genres,"Romance")*1)
Action=as.integer(str_detect(validation$genres,"Action")*1)
Crime=as.integer(str_detect(validation$genres,"Crime")*1)
Thriller=as.integer(str_detect(validation$genres,"Thriller")*1)
Drama=as.integer(str_detect(validation$genres,"Drama")*1)
SciFi=as.integer(str_detect(validation$genres,"Sci-Fi")*1)
Adventure=as.integer(str_detect(validation$genres,"Adventure")*1)
Children=as.integer(str_detect(validation$genres,"Children")*1)
Fantasy=as.integer(str_detect(validation$genres,"Fantasy")*1)
War=as.integer(str_detect(validation$genres,"War")*1)
Animation=as.integer(str_detect(validation$genres,"Animation")*1)
Musical=as.integer(str_detect(validation$genres,"Musical")*1)
Western=as.integer(str_detect(validation$genres,"Western")*1)
Mystery=as.integer(str_detect(validation$genres,"Mystery")*1)
FilmNoir=as.integer(str_detect(validation$genres,"Film-Noir")*1)
Horror=as.integer(str_detect(validation$genres,"Horror")*1)
Documentary=as.integer(str_detect(validation$genres,"Documentary")*1)
IMAX=as.integer(str_detect(validation$genres,"IMAX")*1)
none=as.integer(str_detect(validation$genres,"no genres listed")*1)
#combining them into a data frame
genres_df_val<-data.frame(Comedy,Romance,Action,Crime,Thriller,Drama,SciFi,Adventure,Children,Fantasy,War,Animation,Musical,Western,Mystery,FilmNoir,Horror,Documentary,IMAX,none)

#Joining to test set and removing current Genres predictor
validation<-cbind(validation,genres_df_val)
validation<-validation%>% select(!genres)

#Converting movieID to integers
validation<-validation%>%mutate(movieId=as.integer(movieId))

#Remove unnecessary variables
rm(genres_df_main,genres_df_val,Action,Adventure,Animation,Children,Comedy,Crime,Documentary,Drama,Fantasy,genres,Horror,IMAX,Musical,Mystery,none,Romance,SciFi,Thriller,War,Western,title_year_pattern,i,j,FilmNoir)



#TABLE SHOWING THAT MOST OF THE GENRES ARE NOT VERY EVENLY DISTRIBUTED
genre_dist<-c(Comedy=mean(data_set$Comedy==1),Romance=mean(data_set$Romance==1),Action=mean(data_set$Action==1),Crime=mean(data_set$Crime==1),Thriller=c(mean(data_set$Thriller==1),Drama=mean(data_set$Drama==1),SciFi=mean(data_set$SciFi==1),Adventure=mean(data_set$Adventure==1),Children=mean(data_set$Children==1),Fantasy=mean(data_set$Fantasy==1),War=mean(data_set$War==1),Animation=mean(data_set$Animation==1),Musical=mean(data_set$Musical==1),Western=mean(data_set$Western==1),Mystery=mean(data_set$Mystery==1),FilmNoir=mean(data_set$FilmNoir==1),Horror=mean(data_set$Horror==1),Documentary=mean(data_set$Documentary==1),IMAX=mean(data_set$IMAX==1),none=mean(data_set$none==1)))
genre_dist<-data_frame(ones=genre_dist)
genre_dist<-genre_dist%>% mutate(zeros=1-ones)
genre_dist<-transpose(genre_dist)
colnames(genre_dist)<-all_genres
genre_dist_plot<-transpose(genre_dist)%>%mutate(genre=all_genres)%>%ggplot(aes(V1,genre,group=1))+geom_point(color="darkgoldenrod4",size=2)+ geom_line(color="deeppink4")+xlab("Proportion of 1's")+ylab("Unique Genres")+ggtitle("Plot showing percentage of 1's in each of the unique Genres")+theme_solarized()
#Creating test and train data
test_index <- createDataPartition(y = data_set$rating, times = 1, p = 0.5,list = FALSE)
test_set<-data_set%>% dplyr::slice(test_index)
train_set<-data_set%>% dplyr::slice(-test_index)


#RMSE Function
RMSE <- function(true_ratings, predicted_ratings) {
  sqrt(mean((true_ratings - predicted_ratings)^2))
}
#LM Evaluation
lm_fit<- lm(rating~.,data=train_set)
lm_prediction<-predict(lm_fit,test_set)
lm_RMSE<-RMSE(as.numeric(lm_prediction),test_set$rating)
rm(lm_fit,lm_prediction)

#XGBLINEAR
xg_start_time<-Sys.time()
xg_fit<-train(rating~.,method="xgbLinear",data=train_set,tuneGrid = data.frame(lambda=1e-04, alpha=1e-04, nrounds=150, eta=0.3))
xg_prediction<- predict(xg_fit,test_set)
xg_RMSE<- RMSE(as.numeric(xg_prediction),test_set$rating)
xg_stop_time<-Sys.time()
xg_run_time<-xg_stop_time-xg_start_time
rm(xg_start_time,xg_stop_time)


#Applying XGBOOST FIT TO VALIDATION
final_prediction<- predict(xg_fit,validation)
final_RMSE<- RMSE(as.numeric(final_prediction),validation$rating)

