#' Historical provinces of Spain for a census year
#'
#' Provinces built by dissolving the municipalities of the census, so they nest
#' exactly with [esp_get_munic_hist()]. Non-municipal territories (53xxx) are
#' assigned to the province that contains them.
#'
#' @inheritParams esp_get_munic_hist
#' @param census_data If `TRUE` (default), adds the number of municipalities and
#'   the sum of the census figures (`hogares`, `pder`, `phec`, `pob_serie`) of the
#'   municipalities of each unit.
#'
#' @return An `sf` object with columns `cod_unit` (2-digit INE province code),
#'   `nom`, `n_mun` and, optionally, the census figures; `NULL` (with a message)
#'   if the geometries cannot be downloaded.
#' @export
#' @examples
#' \donttest{
#' p1930 <- esp_get_prov_hist(1930, cache_dir = tempdir())
#' }
esp_get_prov_hist <- function(year, epsg = 4258, moveCAN = FALSE, census_data = TRUE,
                                 cache_dir = NULL, update_cache = FALSE, verbose = FALSE) {
  year <- check_year(year, mhist_census_years())
  get_units("prov", year, year, epsg, moveCAN, census_data, cache_dir, update_cache, verbose)
}

#' Historical judicial districts (partidos judiciales) of Spain
#'
#' Judicial districts for the censuses of 1900, 1910, 1920 and 1930, built by
#' dissolving the municipalities of each census. `cod_unit` has 4 digits: the
#' province code and the district number (alphabetical order within the province,
#' the same in all censuses). Non-municipal territories (53xxx) are assigned to the
#' district of their province with which they share the longest boundary.
#'
#' @inheritParams esp_get_prov_hist
#' @param year Census year: 1900, 1910, 1920 or 1930.
#' @return An `sf` object with columns `cod_unit`, `nom`, `n_mun` and, optionally,
#'   the census figures.
#' @export
#' @examples
#' \donttest{
#' pj1910 <- esp_get_pj_hist(1910, cache_dir = tempdir())
#' }
esp_get_pj_hist <- function(year, epsg = 4258, moveCAN = FALSE, census_data = TRUE,
                               cache_dir = NULL, update_cache = FALSE, verbose = FALSE) {
  year <- check_year(year, c(1900L, 1910L, 1920L, 1930L))
  get_units("pj", year, year, epsg, moveCAN, census_data, cache_dir, update_cache, verbose)
}

#' Historical electoral districts of Spain
#'
#' Electoral districts built by dissolving the municipalities of the census:
#' \itemize{
#'   \item `1920`: districts for the Cortes of the Restoration, on the 1920
#'     municipalities (Melilla has no district and is not included).
#'   \item `1931`, `1933`, `1936`: constituencies (circunscripciones) of the
#'     Second Republic, on the 1930 municipalities.
#' }
#' `cod_unit` has 4 digits: the province code and the district number
#' (alphabetical order within the province). Non-municipal territories (53xxx) are
#' assigned to the district of their province with which they share the longest
#' boundary.
#'
#' @inheritParams esp_get_prov_hist
#' @param year 1920, 1931, 1933 or 1936. Census figures come from the 1920
#'   census (1920) or the 1930 census (1931-1936).
#' @return An `sf` object with columns `cod_unit`, `nom`, `n_mun` and, optionally,
#'   the census figures.
#' @export
#' @examples
#' \donttest{
#' c1933 <- esp_get_circ_hist(1933, cache_dir = tempdir())
#' }
esp_get_circ_hist <- function(year, epsg = 4258, moveCAN = FALSE, census_data = TRUE,
                                 cache_dir = NULL, update_cache = FALSE, verbose = FALSE) {
  year <- check_year(year, c(1920L, 1931L, 1933L, 1936L))
  get_units("circ", year, if (year == 1920L) 1920L else 1930L, epsg, moveCAN, census_data,
            cache_dir, update_cache, verbose)
}

check_year <- function(year, valid) {
  year <- as.integer(year)
  if (length(year) != 1 || !year %in% valid) {
    stop("`year` must be one of: ", paste(valid, collapse = ", "), call. = FALSE)
  }
  year
}

get_units <- function(tipus, year, census_year, epsg, moveCAN, census_data,
                      cache_dir = NULL, update_cache = FALSE, verbose = FALSE) {
  x <- read_hist_layer(paste0(tipus, "_hist_", year), cache_dir, update_cache, verbose)
  if (is.null(x)) return(invisible(NULL))
  x <- x[, c("cod_unit", "nom", "n_mun")]
  x$n_mun <- as.integer(x$n_mun)
  if (census_data) {
    eq <- mapSpainHist::unitats
    eq <- eq[eq$tipus == tipus & eq$any == year, ]
    cs <- mapSpainHist::censos
    cs <- cs[cs$censo == census_year & cs$no_munic == 0, ]
    cs <- cs[!duplicated(cs$cod_ine), ]
    eq <- merge(eq, cs[, c("cod_ine", "hogares", "pder", "phec", "pob_serie")], by = "cod_ine")
    vars <- c("hogares", "pder", "phec", "pob_serie")
    ag <- stats::aggregate(eq[, vars], by = list(cod_unit = eq$cod_unit),
                           FUN = function(v) if (all(is.na(v))) NA_real_ else sum(v, na.rm = TRUE))
    geom <- attr(x, "sf_column")
    x <- merge(x, ag, by = "cod_unit", all.x = TRUE, sort = FALSE)
    x <- sf::st_as_sf(x[order(x$cod_unit), c(setdiff(names(x), geom), geom)])
  }
  x <- move_can(x, moveCAN, code = "cod_unit")
  sf::st_transform(x, epsg)
}
