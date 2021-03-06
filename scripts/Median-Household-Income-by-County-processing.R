library(dplyr)
library(acs)
library(datapkg)
library(tidyr)
source('./scripts/acsHelpers.R')

##################################################################
#
# Processing Script for Median Household Income by County
# Created by Jenna Daly
# On 11/27/2017
#
##################################################################

#Setup environment
sub_folders <- list.files()
raw_location <- grep("raw", sub_folders, value=T)
path_to_raw_data <- (paste0(getwd(), "/", raw_location))
x2016_files <- dir(path_to_raw_data, recursive=T, pattern = "ACS") 

#Get state data
geography=geo.make(state=09)
yearlist=c(2009:2015)
span = 5
col.names="pretty" 
key="ed0e58d2538fb239f51e01643745e83f380582d7"
options(scipen=999)

tables <- c("", "A", "B", "C", "D", "E", "F", "G", "H", "I")
races <- c("All", "White Alone", "Black or African American Alone", "American Indian and Alaska Native Alone", 
           "Asian Alone", "Native Hawaiian and Other Pacific Islander", "Some Other Race Alone", 
           "Two or More Races", "White Alone Not Hispanic or Latino", "Hispanic or Latino")

state_data <- data.table()
for (i in seq_along(yearlist)) {
  endyear = yearlist[i]
  inter_data <- data.table()
  for (j in seq_along(tables)) {
    tbl <- tables[j]
    race <- races[j]
    data <- acs.fetch(geography=geography, endyear=endyear, span=span, 
                         table.number=paste0("B19013", tbl), col.names=col.names, key=key)
    year <- data@endyear
    print(paste("Processing: ", year, race))
    year <- paste(year-4, year, sep="-")
    geo <- data@geography
    income <- acsSum(data, 1, "Median Household Income")
    estimates <- data.table(
            geo, 
            estimate(income),
            year,
            race,
            "Number",
            "Median Household Income"
        )
    moes <- data.table(
            geo,
            standard.error(income) * 1.645,
            year,
            race,
            "Number",
            "Margins of Error"
        )
    numberNames <- c(
            "County", "FIPS",
            "Total",
            "Year",
            "Race/Ethnicity",
            "Measure Type",
            "Variable"
         )
    setnames(estimates, numberNames)
    setnames(moes, numberNames)
    numbersData.melt <- melt(
            rbind(estimates, moes),
            id.vars=c("County", "FIPS", "Year", "Measure Type", "Variable", "Race/Ethnicity"),
            variable.name="Median Household Income",
            variable.factor = F,
            value.name="Value",
            value.factor = F
    )
    inter_data <- rbind(inter_data, numbersData.melt)
  }
  state_data <- rbind(state_data, inter_data)
}

#process 2016 data
races_for_2016 <- c("White Alone", "Black or African American Alone", "American Indian and Alaska Native Alone", 
           "Asian Alone", "Native Hawaiian and Other Pacific Islander", "Some Other Race Alone", 
           "Two or More Races", "White Alone Not Hispanic or Latino", "Hispanic or Latino", "All")
x2016_data <- data.frame(stringsAsFactors = FALSE)
for (i in 1:length(x2016_files)) {
  data <- read.acs(paste0(path_to_raw_data, "/", x2016_files[i]), endyear=2016, span=5)
  race <- races_for_2016[i]
  year <- data@endyear
  year <- paste(year-4, year, sep="-")
  geo <- data@geography
  #geo <- geo[geo$Geography != "Connecticut",]
  geo$Geography <- gsub(", Connecticut", "", geo$Geography)
  geo$Id2 <- gsub("^", "0", geo$Id2)
  geo$Id <- NULL
  income <- acsSum(data, 1, "Median Household Income")
  estimates <- data.table(
            geo, 
            estimate(income),
            year,
            race,
            "Number",
            "Median Household Income"
        )
    moes <- data.table(
            geo,
            standard.error(income) * 1.645,
            year,
            race,
            "Number",
            "Margins of Error"
        )
    numberNames <- c(
            "County", "FIPS",
            "Total",
            "Year",
            "Race/Ethnicity",
            "Measure Type",
            "Variable"
         )
    setnames(estimates, numberNames)
    setnames(moes, numberNames)
    numbersData.melt <- melt(
            rbind(estimates, moes),
            id.vars=c("County", "FIPS", "Year", "Measure Type", "Variable", "Race/Ethnicity"),
            variable.name="Median Household Income",
            variable.factor = F,
            value.name="Value",
            value.factor = F
    )
    x2016_data <- rbind(x2016_data, numbersData.melt)  
}

#Get county data
geography=geo.make(state=09, county="*")

county_data <- data.table()
for (i in seq_along(yearlist)) {
  endyear = yearlist[i]
  inter_data <- data.table()
  for (j in seq_along(tables)) {
    tbl <- tables[j]
    race <- races[j]
    data <- acs.fetch(geography=geography, endyear=endyear, span=span, 
                         table.number=paste0("B19013", tbl), col.names=col.names, key=key)
    year <- data@endyear
    print(paste("Processing: ", year, race))
    year <- paste(year-4, year, sep="-")
    geo <- data@geography
    geo$NAME <- gsub(", Connecticut", "", geo$NAME)
    geo$county <- gsub("^", "09", geo$county)
    geo$state <- NULL
    income <- acsSum(data, 1, "Median Household Income")
    estimates <- data.table(
            geo, 
            estimate(income),
            year,
            race,
            "Number",
            "Median Household Income"
        )
    moes <- data.table(
            geo,
            standard.error(income) * 1.645,
            year,
            race,
            "Number",
            "Margins of Error"
        )
    numberNames <- c(
            "County", "FIPS",
            "Total",
            "Year",
            "Race/Ethnicity",
            "Measure Type",
            "Variable"
         )
    setnames(estimates, numberNames)
    setnames(moes, numberNames)
    numbersData.melt <- melt(
            rbind(estimates, moes),
            id.vars=c("County", "FIPS", "Year", "Measure Type", "Variable", "Race/Ethnicity"),
            variable.name="Median Household Income",
            variable.factor = F,
            value.name="Value",
            value.factor = F
         )
    
    inter_data <- rbind(inter_data, numbersData.melt)
  }
  county_data <- rbind(county_data, inter_data)
}

med_income <- rbind(county_data, state_data, x2016_data)

med_income_wide <- spread(med_income, Variable, Value)

names(med_income_wide)[6] <- "Total"
#create CT df to merge with original to caluate ratios
ct_value <- med_income_wide[med_income_wide$FIPS == "09",]

merge <- merge(med_income_wide, ct_value, by = c("Year", "Race/Ethnicity", "Measure Type", "Total"))

merge$`Ratio to State Median Num` <- merge$`Median Household Income.x` / merge$`Median Household Income.y`
merge$`Ratio to State Median MOE` <- sqrt((merge$`Margins of Error.x`)^2 + ((merge$`Median Household Income.x`/merge$`Median Household Income.y`)*((merge$`Margins of Error.y`)^2))) / (merge$`Median Household Income.x`)

merge <- merge %>% 
  select(County.x, FIPS.x, Year, `Race/Ethnicity`, `Measure Type`, `Margins of Error.x`, 
         `Median Household Income.x`, `Ratio to State Median Num`, `Ratio to State Median MOE`) 

data_long <- gather(merge, `Variable`, Value, 6:9)

#Clean up columns
data_long$`Measure Type`[grepl("Ratio", data_long$Variable)] <- "Ratio to State Median"
data_long$Variable <- gsub(".x", "", data_long$Variable)
data_long$Variable[grepl("MOE", data_long$Variable)] <- "Margins of Error"
data_long$Variable[grepl("Num", data_long$Variable)] <- "Median Household Income"

names(data_long)[names(data_long) == "FIPS.x"] <- "FIPS"
names(data_long)[names(data_long) == "County.x"] <- "County"

data_long$Value <-  round(data_long$Value, 2)

data_long <- data_long %>% 
  arrange(County, Year, `Race/Ethnicity`, `Measure Type`, Variable)

write.table(
    data_long,
    file.path("data", "median-household-income-county-2016.csv"),
    sep = ",",
    row.names = F,
    na = "-9999"
)


