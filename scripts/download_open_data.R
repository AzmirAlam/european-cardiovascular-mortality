#!/usr/bin/env Rscript

# Refresh the open-data snapshots used by the R Markdown report.
# Run from the repository root: Rscript scripts/download_open_data.R

required_packages <- c("jsonlite", "dplyr", "purrr", "stringr", "tibble")
missing_packages <- setdiff(required_packages, rownames(installed.packages()))
if (length(missing_packages) > 0) {
  stop(
    "Install the missing packages first: ",
    paste(sprintf('install.packages("%s")', missing_packages), collapse = ", ")
  )
}

suppressPackageStartupMessages({
  library(jsonlite)
  library(dplyr)
  library(purrr)
  library(stringr)
  library(tibble)
})

dir.create("data/raw", recursive = TRUE, showWarnings = FALSE)
snapshot_date <- Sys.Date()
`%||%` <- function(x, y) if (is.null(x) || length(x) == 0) y else x

ecis_base <- paste0(
  "https://ecis.jrc.ec.europa.eu/ecis-api/v2/data/estimates/",
  "incidenceByCountrySummary"
)

download_ecis <- function(measure) {
  query <- paste0(
    "measure=", measure,
    "&country=ACA&sexId=2&cancerEntity=29",
    "&ageMin=0&ageMax=85%2B&yearFrom=2024&yearTo=2024"
  )
  response <- fromJSON(paste0(ecis_base, "?", query), simplifyDataFrame = TRUE)
  as_tibble(response) |>
    mutate(
      snapshot_date = as.character(snapshot_date),
      source_url = paste0(ecis_base, "?", query)
    )
}

ecis <- bind_rows(download_ecis("IN"), download_ecis("MO"))
write.csv(ecis, "data/raw/ecis_breast_cancer_2024.csv", row.names = FALSE, na = "")

europe_country_map <- tribble(
  ~ctgov_country, ~country_name, ~country_code,
  "Albania", "Albania", "AL",
  "Austria", "Austria", "AT",
  "Belgium", "Belgium", "BE",
  "Bosnia and Herzegovina", "Bosnia and Herzegovina", "BA",
  "Bulgaria", "Bulgaria", "BG",
  "Croatia", "Croatia", "HR",
  "Cyprus", "Cyprus", "CY",
  "Czechia", "Czechia", "CZ",
  "Czech Republic", "Czechia", "CZ",
  "Denmark", "Denmark", "DK",
  "Estonia", "Estonia", "EE",
  "Finland", "Finland", "FI",
  "France", "France", "FR",
  "Germany", "Germany", "DE",
  "Greece", "Greece", "GR",
  "Hungary", "Hungary", "HU",
  "Iceland", "Iceland", "IS",
  "Ireland", "Ireland", "IE",
  "Italy", "Italy", "IT",
  "Latvia", "Latvia", "LV",
  "Lithuania", "Lithuania", "LT",
  "Luxembourg", "Luxembourg", "LU",
  "Malta", "Malta", "MT",
  "Moldova", "Moldova", "MD",
  "Moldova, Republic of", "Moldova", "MD",
  "Montenegro", "Montenegro", "ME",
  "Netherlands", "Netherlands", "NL",
  "Norway", "Norway", "NO",
  "Poland", "Poland", "PL",
  "Portugal", "Portugal", "PT",
  "North Macedonia", "Republic of North Macedonia", "MK",
  "Romania", "Romania", "RO",
  "Serbia", "Serbia", "RS",
  "Slovakia", "Slovakia", "SK",
  "Slovenia", "Slovenia", "SI",
  "Spain", "Spain", "ES",
  "Sweden", "Sweden", "SE",
  "Switzerland", "Switzerland", "CH",
  "United Kingdom", "United Kingdom", "UK",
  "Ukraine", "Ukraine", "UA"
)

ctgov_base <- "https://clinicaltrials.gov/api/v2/studies"
ctgov_params <- list(
  "query.cond" = "Breast Cancer",
  "query.term" = "AREA[StudyType]INTERVENTIONAL",
  "filter.overallStatus" = paste(
    c(
      "RECRUITING", "NOT_YET_RECRUITING", "ACTIVE_NOT_RECRUITING",
      "ENROLLING_BY_INVITATION"
    ),
    collapse = "|"
  ),
  pageSize = "1000",
  format = "json",
  fields = paste(
    c(
      "NCTId", "BriefTitle", "OverallStatus", "StudyType", "Phase",
      "LeadSponsorName", "LeadSponsorClass", "Condition", "InterventionName",
      "InterventionType", "BriefSummary", "EligibilityCriteria", "EnrollmentCount",
      "StartDate", "PrimaryCompletionDate", "CompletionDate", "LastUpdatePostDate",
      "LocationFacility", "LocationCity", "LocationState", "LocationCountry",
      "LocationGeoPoint", "Sex", "MinimumAge", "MaximumAge"
    ),
    collapse = "|"
  )
)

make_url <- function(params) {
  encoded <- imap_chr(params, ~ paste0(URLencode(.y, reserved = TRUE), "=", URLencode(.x, reserved = TRUE)))
  paste0(ctgov_base, "?", paste(encoded, collapse = "&"))
}

all_studies <- list()
page_token <- NULL
repeat {
  page_params <- ctgov_params
  if (!is.null(page_token)) page_params$pageToken <- page_token
  response <- fromJSON(make_url(page_params), simplifyVector = FALSE)
  all_studies <- c(all_studies, response$studies)
  page_token <- response$nextPageToken %||% NULL
  if (is.null(page_token)) break
}

scalar <- function(x) if (is.null(x) || length(x) == 0) NA_character_ else as.character(x[[1]])
collapse_values <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_character_)
  paste(unique(unlist(x, use.names = FALSE)), collapse = " | ")
}

study_row <- function(study) {
  p <- study$protocolSection
  tibble(
    nct_id = scalar(p$identificationModule$nctId),
    brief_title = scalar(p$identificationModule$briefTitle),
    overall_status = scalar(p$statusModule$overallStatus),
    study_type = scalar(p$designModule$studyType),
    phase = collapse_values(p$designModule$phases),
    lead_sponsor = scalar(p$sponsorCollaboratorsModule$leadSponsor$name),
    sponsor_class = scalar(p$sponsorCollaboratorsModule$leadSponsor$class),
    conditions = collapse_values(p$conditionsModule$conditions),
    intervention_names = collapse_values(map(p$armsInterventionsModule$interventions %||% list(), "name")),
    intervention_types = collapse_values(map(p$armsInterventionsModule$interventions %||% list(), "type")),
    brief_summary = scalar(p$descriptionModule$briefSummary),
    eligibility_criteria = scalar(p$eligibilityModule$eligibilityCriteria),
    enrollment = suppressWarnings(as.numeric(scalar(p$designModule$enrollmentInfo$count))),
    sex = scalar(p$eligibilityModule$sex),
    minimum_age = scalar(p$eligibilityModule$minimumAge),
    maximum_age = scalar(p$eligibilityModule$maximumAge),
    start_date = scalar(p$statusModule$startDateStruct$date),
    primary_completion_date = scalar(p$statusModule$primaryCompletionDateStruct$date),
    completion_date = scalar(p$statusModule$completionDateStruct$date),
    last_update_post_date = scalar(p$statusModule$lastUpdatePostDateStruct$date)
  )
}

site_rows <- function(study) {
  p <- study$protocolSection
  nct_id <- scalar(p$identificationModule$nctId)
  locations <- p$contactsLocationsModule$locations %||% list()
  if (length(locations) == 0) return(tibble())
  map_dfr(locations, function(location) {
    tibble(
      nct_id = nct_id,
      facility = scalar(location$facility),
      city = scalar(location$city),
      state = scalar(location$state),
      ctgov_country = scalar(location$country),
      latitude = suppressWarnings(as.numeric(scalar(location$geoPoint$lat))),
      longitude = suppressWarnings(as.numeric(scalar(location$geoPoint$lon)))
    )
  })
}

trials_all <- map_dfr(all_studies, study_row)
sites_all <- map_dfr(all_studies, site_rows)

sites_europe <- sites_all |>
  inner_join(europe_country_map, by = "ctgov_country") |>
  distinct(nct_id, facility, city, country_code, .keep_all = TRUE) |>
  mutate(snapshot_date = as.character(snapshot_date))

europe_nct <- unique(sites_europe$nct_id)
trials_europe <- trials_all |>
  filter(nct_id %in% europe_nct) |>
  mutate(
    snapshot_date = as.character(snapshot_date),
    source_query = make_url(ctgov_params)
  )

write.csv(trials_europe, "data/raw/clinicaltrials_europe_trials.csv", row.names = FALSE, na = "")
write.csv(sites_europe, "data/raw/clinicaltrials_europe_sites.csv", row.names = FALSE, na = "")
write.csv(europe_country_map, "data/raw/country_crosswalk.csv", row.names = FALSE, na = "")

message("Saved ", nrow(ecis), " ECIS country-measure rows.")
message("Saved ", nrow(trials_europe), " European trials and ", nrow(sites_europe), " sites.")
