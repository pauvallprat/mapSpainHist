#' Census editions available
#'
#' @return Integer vector with the census years covered by the package.
#' @export
#' @examples
#' mhist_census_years()
mhist_census_years <- function() {
  c(1900L, 1910L, 1920L, 1930L, 1940L, 1950L, 1960L, 1970L, 1981L, 1991L, 2001L)
}

#' Historical municipalities of Spain for a census year
#'
#' Returns the municipalities in force at the given census. All census maps come
#' from the same partition of the territory, so they have no gaps or overlaps and
#' can be aggregated (provinces, judicial districts, electoral districts...) without
#' slivers.
#'
#' The geometries are downloaded from Zenodo the first time and stored in a cache
#' directory (see [mhist_cache_dir()]).
#'
#' @section Warning: the boundaries of most historical municipalities are an
#'   approximate reconstruction. See [mapSpainHist-package].
#'
#' @param year Census year, one of [mhist_census_years()].
#' @param epsg EPSG code of the output (default 4258, ETRS89, as in mapSpain).
#' @param moveCAN Position of the Canary Islands. `FALSE` (default) keeps their
#'   real position. `TRUE` moves them next to the Peninsula exactly as
#'   `mapSpain::esp_move_can()` does. A numeric vector `c(lon, lat)` adds an extra
#'   displacement, also as in mapSpain.
#'   When the islands are moved, draw the box that separates them with
#'   `mapSpain::esp_get_can_box()`, which matches this displacement.
#' @param include_nonmunicipal If `FALSE`, drops the non-municipal territories
#'   (codes 53xxx, `no_munic == 1`).
#' @param census_data If `TRUE` (default), adds the census figures of `year`
#'   from [censos] (municipality name, province, households, population...).
#'   If `FALSE`, returns only `cod_ine`, `no_munic` and the geometry.
#' @param cache_dir Cache directory. If `NULL`, [mhist_cache_dir()] is used.
#' @param update_cache If `TRUE`, downloads the geometries again.
#' @param verbose If `TRUE`, shows download messages.
#'
#' @return An `sf` object with one row per municipality, or `NULL` (with a
#'   message) if the geometries cannot be downloaded.
#' @export
#' @examples
#' \donttest{
#' m1930 <- esp_get_munic_hist(1930, cache_dir = tempdir())
#' m1930_can <- esp_get_munic_hist(1930, moveCAN = TRUE, cache_dir = tempdir())
#' if (!is.null(m1930)) plot(sf::st_geometry(m1930))
#' if (!is.null(m1930_can) && requireNamespace("mapSpain", quietly = TRUE)) {
#'   plot(sf::st_geometry(m1930_can))
#'   plot(sf::st_geometry(mapSpain::esp_get_can_box()), add = TRUE)
#' }
#' }
esp_get_munic_hist <- function(year, epsg = 4258, moveCAN = FALSE,
                               include_nonmunicipal = TRUE, census_data = TRUE,
                               cache_dir = NULL, update_cache = FALSE, verbose = FALSE) {
  year <- check_year(year, mhist_census_years())
  x <- read_hist_layer(paste0("map_muni_es_hist_", year), cache_dir, update_cache, verbose)
  if (is.null(x)) return(invisible(NULL))
  x <- x[, c("cod_ine", "no_munic")]
  if (is.numeric(x$cod_ine)) x$cod_ine <- sprintf("%05d", as.integer(x$cod_ine))
  x$no_munic <- as.integer(x$no_munic)
  if (!include_nonmunicipal) x <- x[x$no_munic == 0, ]
  if (census_data) {
    cs <- mapSpainHist::censos
    cs <- cs[cs$censo == year, setdiff(names(cs), "no_munic")]
    cs <- cs[!duplicated(cs$cod_ine), ]
    geom <- attr(x, "sf_column")
    x <- merge(x, cs, by = "cod_ine", all.x = TRUE, sort = FALSE)
    x <- x[order(x$cod_ine), c(setdiff(names(x), geom), geom)]
    x <- sf::st_as_sf(x)
  }
  x <- move_can(x, moveCAN)
  sf::st_transform(x, epsg)
}

# Desplaçament de les Canàries, idèntic a mapSpain::esp_move_can()
move_can <- function(x, moveCAN, code = "cod_ine") {
  if (isFALSE(moveCAN) || is.null(moveCAN)) return(x)
  offset <- c(550000, 920000)
  if (is.numeric(moveCAN) && length(moveCAN) == 2) {
    p <- sf::st_transform(sf::st_sfc(sf::st_point(moveCAN), crs = 4326), 3857)
    offset <- offset + as.numeric(sf::st_coordinates(p))
  }
  can <- substr(x[[code]], 1, 2) %in% c("35", "38")
  if (!any(can)) return(x)
  crs0 <- sf::st_crs(x)
  y <- sf::st_transform(x[can, ], 3857)
  g <- sf::st_geometry(y) + offset
  sf::st_crs(g) <- 3857
  sf::st_geometry(y) <- sf::st_transform(g, crs0)
  out <- rbind(x[!can, ], y)
  out[order(out[[code]]), ]
}
