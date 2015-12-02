tract_map <- read.csv("2010_Census_Tract_to_2010_PUMA.txt")
tract_pops <- read.csv("us2010trf.txt", header = FALSE)
fips_names <- read.csv("national_county.txt", header = FALSE)
puma_map <- read.csv("puma2k_puma2010.csv")

names(fips_names) <- c("STATE", "STATEFP", "COUNTYFP", "COUNTYNAME", "CLASSFP")
fips_names <- fips_names[,c("STATE", "STATEFP", "COUNTYFP", "COUNTYNAME")]

names(tract_pops) <- unlist(strsplit("STATE00,COUNTY00,TRACT00,GEOID00,POP00,HU00,PART00,AREA00,AREALAND00,STATE10,COUNTY10,TRACT10,GEOID10,POP10,HU10,PART10,AREA10,AREALAND10,AREAPT,AREALANDPT,AREAPCT00PT,ARELANDPCT00PT,AREAPCT10PT,AREALANDPCT10PT,POP10PT,POPPCT00,POPPCT10,HU10PT,HUPCT00,HUPCT10", split = ","))
tract_pops <- tract_pops[,c("STATE10", "COUNTY10", "TRACT10", "POP10")]

puma_map <- puma_map[,c("state","puma2k","puma12","afact")]

translate_county <- function(state, county){
  fips_names$COUNTYNAME[which(fips_names$STATEFP == state & fips_names$COUNTYFP == county)]
}

translate_statefp <- function(state){
  fips_names$STATE[which(fips_names$STATEFP == state)][[1]]
}

translate_state <- function(state){
  fips_names$STATEFP[which(fips_names$STATE == state)][[1]]
}

translate_puma10 <- function(state, puma){
  subs <- puma_map[which(puma_map$state == state & puma_map$puma12 == puma),]
  t <- subs$afact
  names(t) <- subs$puma2k
  t
}

get_pop <- function(state_tract_pops, county, tract){
  subset(state_tract_pops, state_tract_pops$COUNTY10 == county & state_tract_pops$TRACT10 == tract)$POP10[1]
}

get_state_dist <- function(state){
  # generates puma10 distribution for state
  state_tracts <- subset(tract_map, STATEFP == state)
  state_tract_pops <- subset(tract_pops, tract_pops$STATE10 == state)
  
  call_get_pop <- function(x) get_pop(state_tract_pops, x[["COUNTYFP"]], x[["TRACTCE"]])
  get_puma_pop <- function(y) lapply(split(y, y$PUMA5CE), function(x) apply(x, 1, call_get_pop))
  
  t <- lapply(split(state_tracts, state_tracts$COUNTYFP), get_puma_pop)
  
  # (puma, pop) pairs for each county
  county_puma_pops <- lapply(t, function(x) sapply(x, sum))   
  # (puma, pop) pairs for the state
  puma_pops <- sapply(get_puma_pop(state_tracts), sum)
  # Now we calculate (puma, pop percentage) pairs for each county
  county_puma_dist <- county_puma_pops
  
  for(i in seq_along(county_puma_pops)){
    county <- t[[i]]
    for(j in seq_along(county)){
      county_puma_dist[[i]][[j]] <- county_puma_dist[[i]][[j]] / puma_pops[[as.character(names(county)[[j]])]]
    }
  }
  county_puma_dist
}

state_dist_10_to_00 <- function(state, state_dist10){
  # we create a puma00 distribution in the same format as get_state_dist
  # we break down each puma to its puma00 codes in each county, multiplying by the corresponding conv. factor
  lapply(state_dist10, function(county_dist10){
    full_puma00_dist <- NULL
    
    for(j in seq_along(county_dist10)){
      puma10 <- names(county_dist10)[j]
      old_pumas <- translate_puma10(state, puma10)
      
      puma00_dist <- sapply(old_pumas, function(x) x * county_dist10[[j]])
      
      for(k in seq_along(puma00_dist)){
        puma00 <- names(puma00_dist)[k]
        if(puma00 %in% names(full_puma00_dist)){
          full_puma00_dist[[puma00]] <- puma00_dist[[k]] + full_puma00_dist[[puma00]]
        }
        else{
          full_puma00_dist <- c(full_puma00_dist, puma00_dist[[k]])
          names(full_puma00_dist)[length(full_puma00_dist)] <- puma00
        }
      }
    }
    
    full_puma00_dist
  })
}

invert_state_dist <- function(state_dist){
  # inverts the state_dist so we have it ordered by puma, county
  puma_county_dist <- list()
  
  for(i in seq_along(state_dist)){
    county <- names(state_dist)[i]
    county_dist <- state_dist[[i]]
    
    for(j in seq_along(county_dist)){
      puma <- names(county_dist)[j]
      
      if(!(puma %in% names(puma_county_dist))){
        puma_county_dist[[puma]] <- list()
      }
      
      puma_county_dist[[puma]][[county]] <- county_dist[[j]]
    }
  }
  puma_county_dist
}

generate_puma_dist_file <- function(file_name, state, county_puma_dist){
  puma_county_dist <- invert_state_dist(county_puma_dist)
  
  pumas <- sort(as.integer(names(puma_county_dist)))
  counties <- names(county_puma_dist)
  
  df <- as.data.frame(matrix(0, nrow = length(pumas), ncol = length(counties)))
  rownames(df) <- pumas
  colnames(df) <- counties
  
  for(i in seq_along(county_puma_dist)){
    county <- names(county_puma_dist)[i]
    puma_dist <- county_puma_dist[[i]]
      
    for(j in seq_along(puma_dist)){
      puma <- names(puma_dist)[j]
      
      insert_at_row <- which(rownames(df) == puma)
      insert_at_col <- which(colnames(df) == county)
      
      df[insert_at_row, insert_at_col] <- puma_dist[[j]]
    }
  }
  
  colnames(df) <- sapply(counties, function(x) as.character(translate_county(state, x)))
  
  write.csv(df, file_name)
}

generate_final_output <- function(state, year){
  state_name <- suppressWarnings(toupper(state))
  state_fp <- suppressWarnings(as.integer(state))
  
  if(state_name %in% unique(fips_names$STATE)){
    state_fp <- translate_state(state_name)
  }
  else if(state %in% unique(fips_names$STATEFP)){
    state_name <- translate_statefp(state_fp)
  }
  else{
    message("Please enter correct state fips code or state abbreviation")
    return(NA)
  }
  if(nchar(year) != 2){
    message("Please enter exactly two digits for the year")
    return(NA)
  }
  if(is.na(suppressWarnings(as.integer(year)))){
    message("Please enter a number")
    return(NA)
  }
  
  acs_file <- paste0("ss", year, "p", tolower(state_name), ".csv")
  
  if(!(file.exists(acs_file))){
    message(paste0("You don't have the csv ", acs_file, " in working dir"))
    return(NA)
  }
  
  state_dist_10 <- get_state_dist(state_fp)
  state_dist_00 <- state_dist_10_to_00(state_fp, state_dist_10)
  
  generate_puma_dist_file("puma_dist_00.csv", state_fp, state_dist_00)
  generate_puma_dist_file("puma_dist_10.csv", state_fp, state_dist_10)
  
  while (!(file.exists("puma_dist_00.csv") && file.exists("puma_dist_10.csv"))){
    Sys.sleep(0.5)
  }
  
  system(paste("python transform_acs.py", state_name, year))
}

answer <- ""
while(answer != "exit"){
  year <- readline("Please enter the year's last two digits: ")
  answer <- readline("Please enter a state abbrevation or state fips code: ")
  
  ptm <- proc.time()[[3]]
  
  generate_final_output(answer, year)
  
  print(paste("Completed in", round(proc.time()[[3]] - ptm, 2), "seconds"))
  if(file.exists("puma_dist_00.csv")) file.remove("puma_dist_00.csv")
  if(file.exists("puma_dist_10.csv")) file.remove("puma_dist_10.csv")
}
