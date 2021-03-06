###################################################################
# Media Coverage of Trump
# Read, format newspaper articles
# NYT and WP from Lexis-Nexis; WSJ from Factiva
# Michele Claibourn
# Created February 1, 2017
# Updated August 29, 2018 with newspapers through July 31, 2018
####################################################################


####################################################################
# Loading libraries, Setting directories, Creating functions ----

# install.packages("tm")
# install.packages("tm.plugin.lexisnexis")
# install.packages("tm.plugin.factiva")
# install.packages("quanteda")

rm(list=ls())
library(tm)
library(xml2) # instead of XML?
library(tm.plugin.factiva)
library(tm.plugin.lexisnexis)
library(quanteda)
library(tidyverse)
library(rvest)

# Point to path for html files
setwd("~/Box Sync/mpc/dataForDemocracy/presidency_project/newspaper/")

# Adjust readFactivaHTML function (see readNewsError.R for background)
source("codeR/readFactivaHTML3.R")
assignInNamespace("readFactivaHTML", readFactivaHTML3, ns="tm.plugin.factiva")

# Function to read lexis-nexis article files and turn into a corpus
read_lnfiles <- function(x){
  source <- LexisNexisSource(x)
  Corpus(source)
}

# Function to read lexis-nexis meta files and turn into a dataframe
read_lnmeta <- function(x){
  read_csv(x)
}

# Function to read factiva files and turn into a corpus
read_fvfiles <- function(x){
  source <- FactivaSource(x)
  Corpus(source)
}


####################################################################
# Read in NYT articles, using tm.plugin and tm, and clean up ----

# List article files
nytfiles <- DirSource(directory="nyt2/", pattern=".html", recursive=TRUE)

# Read article files
nytcorpus <- lapply(nytfiles$filelist, read_lnfiles) 
nytcorpus <- do.call(c, nytcorpus)

# View the corpus
nytcorpus
nytcorpus[[1]][1]
meta(nytcorpus[[1]])

# In later exploration, found that NYT and WSJ use different abbreviation styles, 
# altered the most common ones in NYT to match WSJ
# f.b.i; c.i.a; e.p.a (appears mostly with periods (sometimes all caps) in NYT; usually all caps (sometimes with periods) in WSJ
nytcorpus <- tm_map(nytcorpus, content_transformer(function(x) gsub("F.B.I.", "FBI", x, fixed = TRUE)))
nytcorpus <- tm_map(nytcorpus, content_transformer(function(x) gsub("C.I.A.", "CIA", x, fixed = TRUE)))
nytcorpus <- tm_map(nytcorpus, content_transformer(function(x) gsub("E.P.A.", "EPA", x, fixed = TRUE)))
nytcorpus <- tm_map(nytcorpus, content_transformer(function(x) gsub("U.S.", "United States", x, fixed = TRUE)))

# Need to do something about this text -- appears frequently, and is pulled out as topic in later analysis...
# "Follow The New York Times Opinion section on Facebook and Twitter (@NYTopinion), and sign up for the Opinion Today newsletter."
nytcorpus <- tm_map(nytcorpus, content_transformer(function(x) gsub("Follow The New York Times Opinion section on Facebook and Twitter (@NYTopinion), and sign up for the Opinion Today newsletter.", "", x)))


####################################################################
# Read in NYT metadata, using readr, and clean up ----

# List meta files
nytmetafiles <- DirSource(directory="nyt2/", pattern="CSV", recursive=TRUE)
length(nytmetafiles) == length(nytfiles) # test that meta and articles match

# Read meta files
nytmeta <- lapply(nytmetafiles$filelist, read_lnmeta) 
nytmeta <- do.call(rbind, nytmeta)
nrow(nytmeta) == length(nytcorpus) # test that meta and articles still match

# Improve the metadata
nytmeta$length <- as.integer(str_extract(nytmeta$LENGTH, "[0-9]{1,4}"))
nytmeta$date <- as.Date(nytmeta$DATE, "%B %d, %Y")
nytmeta$pub <- "NYT"
nytmeta$oped <- if_else(str_detect(nytmeta$SECTION, "Editorial Desk"), 1, 0)
nytmeta$blog <- if_else(str_detect(nytmeta$PUBLICATION, "Blogs"), 1, 0)
nytmeta <- nytmeta %>% select(byline = BYLINE, headline = HEADLINE, length, date, pub, oped, blog, subject = SUBJECT, person = PERSON)


####################################################################
# Read in WP articles, using tm.plugin and tm, and clean up ----

# List article files
wpfiles <- DirSource(directory="wp/", pattern=".html", recursive=TRUE)

# Read article files
wpcorpus <- lapply(wpfiles$filelist, read_lnfiles) 
wpcorpus <- do.call(c, wpcorpus)

# View the corpus
wpcorpus
wpcorpus[[1]][1]
meta(wpcorpus[[1]])

# In later exploration, found that WP and WSJ use different abbreviation styles, 
wpcorpus <- tm_map(wpcorpus, content_transformer(function(x) gsub("U.S.", "United States", x, fixed = TRUE)))


####################################################################
# Read in WP metadata, using readr, and clean up ----

# List meta files
wpmetafiles <- DirSource(directory="wp/", pattern="CSV", recursive=TRUE)
length(wpmetafiles) == length(wpfiles) # test that meta and articles match

# Read meta files
wpmeta <- lapply(wpmetafiles$filelist, read_lnmeta) 
wpmeta <- do.call(rbind, wpmeta)
nrow(wpmeta) == length(wpcorpus) # test that meta and articles still match

# Improve the metadata
wpmeta$length <- as.integer(str_extract(wpmeta$LENGTH, "[0-9]{1,4}"))
wpmeta$date <- as.Date(wpmeta$DATE, "%B %d, %Y")
wpmeta$pub <- "WP"
wpmeta$oped <- if_else(str_detect(wpmeta$SECTION, "Editorial") | str_detect(wpmeta$SECTION, "Outlook"), 1, 0)
wpmeta$blog <- 0
wpmeta <- wpmeta %>% select(byline = BYLINE, headline = HEADLINE, length, date, pub, oped, blog, subject = SUBJECT, person = PERSON)


####################################################################
# Read in WSJ articles, using tm.plugin and tm, and clean up ----

# List article files
wsjfiles <- DirSource(directory="wsj/", pattern=".htm", recursive=TRUE)

# Read article files
wsjcorpus <- lapply(wsjfiles$filelist, read_fvfiles) 
wsjcorpus <- do.call(c, wsjcorpus)

# View the corpus
wsjcorpus
wsjcorpus[[1]][1]
meta(wsjcorpus[[1]])

# Remove Factiva-added line from WSJ articles (discovered in later exploration): 
# "License this article from Dow Jones Reprint Service[http://www.djreprints.com/link/DJRFactiva.html?FACTIVA=wjco20170123000044]"
wsjcorpus <- tm_map(wsjcorpus, content_transformer(function(x) gsub("License this article from Dow Jones Reprint Service\\[[[:print:]]+\\]", "", x)))
# Replace U.S. with United States for later bigram analysis
wsjcorpus <- tm_map(wsjcorpus, content_transformer(function(x) gsub("U.S.", "United States", x, fixed = TRUE)))
# Replace "---" with null (causes problems for readability in WSJ "roundup"-style pieces, where items are separated by ---)
wsjcorpus <- tm_map(wsjcorpus, content_transformer(function(x) gsub("---", "", x))) # change this to regexp?


####################################################################
# Turn NYT into a quanteda corpus and assign metadata ----

qcorpus_nyt <- corpus(nytcorpus) # note corpus is from quanteda, Corpus is from tm
summary(qcorpus_nyt, showmeta=TRUE)

# Assign document variables to corpus
docvars(qcorpus_nyt, "author") <- nytmeta$byline
docvars(qcorpus_nyt, "length") <- nytmeta$length
docvars(qcorpus_nyt, "date") <- nytmeta$date
docvars(qcorpus_nyt, "pub") <- nytmeta$pub
docvars(qcorpus_nyt, "oped") <- nytmeta$oped
docvars(qcorpus_nyt, "blog") <- nytmeta$blog
docvars(qcorpus_nyt, "subject") <- nytmeta$subject

# Remove several empty metadata fields
docvars(qcorpus_nyt, c("description", "language", "intro", "section", "coverage", "company", "stocksymbol", "industry", "type", "wordcount", "rights")) <- NULL
summary(qcorpus_nyt, showmeta=TRUE)


####################################################################
# Turn WP into a quanteda corpus and assign metadata ----

qcorpus_wp <- corpus(wpcorpus) 
summary(qcorpus_wp, showmeta=TRUE)

# Assign document variables to corpus
docvars(qcorpus_wp, "author") <- wpmeta$byline
docvars(qcorpus_wp, "length") <- wpmeta$length
docvars(qcorpus_wp, "date") <- wpmeta$date
docvars(qcorpus_wp, "pub") <- wpmeta$pub
docvars(qcorpus_wp, "oped") <- wpmeta$oped
docvars(qcorpus_wp, "blog") <- wpmeta$blog
docvars(qcorpus_wp, "subject") <- wpmeta$subject

# Remove several empty metadata fields
docvars(qcorpus_wp, c("description", "language", "intro", "section", "coverage", "company", "stocksymbol", "industry", "type", "wordcount", "rights")) <- NULL
summary(qcorpus_wp, showmeta=TRUE)


####################################################################
# Turn WSJ into a quanteda corpus and assign metadata ----

qcorpus_wsj <- corpus(wsjcorpus) # note corpus is from quanteda, Corpus is from tm
summary(qcorpus_wsj, showmeta=TRUE)

# Assign document variables to corpus
docvars(qcorpus_wsj, "length") <- docvars(qcorpus_wsj, "wordcount")
docvars(qcorpus_wsj, "date") <- docvars(qcorpus_wsj, "datetimestamp")
docvars(qcorpus_wsj, "date") <- as.Date(docvars(qcorpus_wsj, "date"))
docvars(qcorpus_wsj, "pub") <- "WSJ"
oped <- c("Commentaries/Opinions", "Columns", "Editorials")
docvars(qcorpus_wsj, "oped") <- if_else(str_detect(docvars(qcorpus_wsj, "subject"), paste(oped, collapse = '|')), 1, 0)
docvars(qcorpus_wsj, "blog") <- 0

# Remove several empty (or unused) metadata fields
docvars(qcorpus_wsj, c("description", "language", "edition", "section", "coverage", "company", "industry", "infocode", "infodesc", "wordcount", "publisher", "rights")) <- NULL
summary(qcorpus_wsj, showmeta=TRUE)


####################################################################
# Combine corpora and metadata and save in workspaceR ----

qcorpus <- qcorpus_nyt + qcorpus_wsj + qcorpus_wp
qcorpus
summary(qcorpus)
qmeta <- docvars(qcorpus)

# add approx first two paragraphs as field in qmeta; probably a better way
qmeta$leadlines <- str_sub(qcorpus$documents$texts, 1,500)

# Save data
save(nytcorpus, nytmeta, qcorpus_nyt, wsjcorpus, qcorpus_wsj, wpcorpus, wpmeta, qcorpus_wp, qcorpus, qmeta, file="workspaceR/newspaper.Rdata")
# load("workspaceR/newspaper.RData")