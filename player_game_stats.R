library(tidyr)
source("weekly_fantasy_points.R")

t <- readLines("https://www.pro-football-reference.com/years/2016/fantasy.htm")
table_start <- grep("Fantasy Rankings Table", t)
table_end <- grep("/table", t)

players <- grep("/players/", t)
players <- players[players > table_start]
players <- players[players < table_end]

players <- t[players]
players <- players[c(1:350)]

players <- plyr::ldply(players, function(x) {
  
  pos <- strsplit(strsplit(strsplit(x, "fantasy_pos")[[1]][2], ">")[[1]][2], "<")[[1]][1]
  temp <- strsplit(x, "<a href=\\\"")[[1]][2]
  temp <- strsplit(temp, "\\\">")
  link <- gsub(".htm", "", temp[[1]][1])
  name <- strsplit(temp[[1]][2], "<")[[1]][1]
  temp <- data.frame(Name = name, Link = link, Pos = pos)
  return(temp)
})

base <- "https://www.pro-football-reference.com"

players$Link <- paste0(base, players$Link, "/gamelog/2016/")

dat <- data.frame()

for(i in 1:nrow(players)) {
  print(i)
  lines <- readLines(players$Link[i])
  stats <- lines[grep("stats\\.", lines)]
  if(length(stats) > 0) {
    for(j in 1:length(stats)) {
      split <- unlist(strsplit(stats[j], "data-stat=\\\""))
      stat_start <- grep("game_result", split) + 1
      stat_end <- grep("all_td", split) - 1
      if(length(stat_end) == 0) {
        stat_end <- length(split)
      }
      split <- split[c(4, stat_start:stat_end)]
      
      dat <- dplyr::bind_rows(dat, cbind(players$Name[i], players$Pos[i], i, plyr::ldply(split, function(x) {
        temp <- strsplit(x, "\\\" >")
        return(data.frame(stat = temp[[1]][1], value = strsplit(temp[[1]][2], "<")[[1]][1]))
      }) %>% spread(., stat, value)))
      
    }
  }
}
a <- dat
colnames(dat)[c(1:4)] <- c("Player", "Pos", "I", "Week")

dat[, grep("csk", colnames(dat))] <- NULL
dat[, grep("NA", colnames(dat))] <- NULL

for(i in 1:2) {
  dat[,i] <- as.character(dat[,i])
}
for(i in 3:ncol(dat)) {
  dat[,i] <- as.numeric(dat[,i])
}

dat[is.na(dat)] <- 0

write.csv(dat, file = "gamelogs.csv", row.names = F)

for(i in 1:nrow(dat)) {
  dat$pts[i] <- weekly_fantasy_points(dat[i,])
}

dat$starts <- 0
dat$top <- 0
qb <- data.frame()
rb <- data.frame()
wr <- data.frame()
te <- data.frame()
for(i in 1:16) {
  qbs <- dat %>% filter(Pos == "QB") %>% filter(Week == i)
  qbs <- qbs[order(-qbs$pts),]
  qbs$top[c(1:3)] <- qbs$top[c(1:3)] + 1
  qbs$starts[c(1:12)] <- qbs$starts[c(1:12)] + 1
  qb <- rbind(qb, qbs)
  
  rbs <- dat %>% filter(Pos == "RB") %>% filter(Week == i)
  rbs <- rbs[order(-rbs$pts),]
  rbs$top[c(1:3)] <- rbs$top[c(1:3)] + 1
  rbs$starts[c(1:12)] <- rbs$starts[c(1:12)] + 1
  rb <- rbind(rb, rbs)
  
  wrs <- dat %>% filter(Pos == "WR") %>% filter(Week == i)
  wrs <- wrs[order(-wrs$pts),]
  wrs$top[c(1:3)] <- wrs$top[c(1:3)] + 1
  wrs$starts[c(1:12)] <- wrs$starts[c(1:12)] + 1
  wr <- rbind(wr, wrs)
  
  tes <- dat %>% filter(Pos == "TE") %>% filter(Week == i)
  tes <- tes[order(-tes$pts),]
  tes$top[c(1:3)] <- tes$top[c(1:3)] + 1
  tes$starts[c(1:12)] <- tes$starts[c(1:12)] + 1
  te <- rbind(te, tes)
}

dat <- rbind(qb, rb, wr, te)
dat <- dat[order(dat$I, dat$Week),]
rownames(dat) <- c(1:nrow(dat))

b <- dat %>%
  group_by(Player) %>%
  mutate(starts = sum(starts), top = sum(top), pts_g = mean(pts), wk_sd = sd(pts), games = n()) %>%
  data.frame() %>%
  select(Player, Pos, games, starts, top, pts_g, wk_sd) %>% unique()

b$start_pct <- b$starts / b$games
b$top_pct <- b$top / b$games

b$cons <- b$wk_sd / b$pts_g
b$met <- log(b$pts_g ^ (1/b$cons))


