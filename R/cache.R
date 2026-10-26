# Geometries: descàrrega i memòria cau ------------------------------------------------
# Les geometries de tots els censos i unitats són en un sol fitxer TopoJSON comprimit
# dipositat a Zenodo. Es descarrega la primera vegada i es desa a la memòria cau.

# Versió de les dades i URL de descàrrega (Zenodo)
mhist_data_version <- "1.0.0"
mhist_data_file <- function() paste0("mapSpainHist_geometries_v", mhist_data_version, ".topojson.gz")
mhist_data_url <- function() {
  getOption("mapSpainHist.url",
            paste0("https://zenodo.org/records/ZENODO_RECORD/files/", mhist_data_file(), "?download=1"))
}

#' Cache directory of mapSpainHist
#'
#' The geometries are downloaded from Zenodo the first time they are needed and
#' stored in a cache directory. By default it is the user cache directory given by
#' [tools::R_user_dir()]. It can be changed for the session with
#' `mhist_set_cache_dir()` or with the `cache_dir` argument of the `esp_get_*_hist()`
#' functions.
#'
#' @param cache_dir Path of the cache directory. If `NULL`, returns the current one.
#' @return The path of the cache directory (invisibly for `mhist_set_cache_dir()`).
#' @export
#' @examples
#' mhist_cache_dir()
#' \donttest{
#' old <- mhist_set_cache_dir(tempdir())
#' options(mapSpainHist.cache_dir = NULL)
#' }
mhist_cache_dir <- function(cache_dir = NULL) {
  if (is.null(cache_dir)) {
    cache_dir <- getOption("mapSpainHist.cache_dir", tools::R_user_dir("mapSpainHist", "cache"))
  }
  path.expand(cache_dir)
}

#' @rdname mhist_cache_dir
#' @export
mhist_set_cache_dir <- function(cache_dir) {
  options(mapSpainHist.cache_dir = cache_dir)
  invisible(mhist_cache_dir())
}

#' Clear the cache of mapSpainHist
#'
#' Deletes the downloaded geometries, which will be downloaded again the next time
#' they are needed.
#'
#' @inheritParams mhist_cache_dir
#' @return `TRUE` invisibly if a file was deleted, `FALSE` otherwise.
#' @export
#' @examples
#' \donttest{
#' mhist_clear_cache(tempdir())
#' }
mhist_clear_cache <- function(cache_dir = NULL) {
  f <- list.files(mhist_cache_dir(cache_dir), pattern = "^mapSpainHist_geometries", full.names = TRUE)
  if (length(f)) unlink(f)
  invisible(length(f) > 0)
}

# Camí local del fitxer de geometries (el descarrega si cal); NULL si no és possible
mhist_geometry_file <- function(cache_dir = NULL, update_cache = FALSE, verbose = FALSE) {
  local <- Sys.getenv("MAPSPAINHIST_DATA")
  if (nzchar(local) && file.exists(local)) return(local)
  dir <- mhist_cache_dir(cache_dir)
  f <- file.path(dir, mhist_data_file())
  if (file.exists(f) && !update_cache) {
    if (verbose) message("Using cached file: ", f)
    return(f)
  }
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  url <- mhist_data_url()
  if (verbose) message("Downloading ", url)
  tmp <- tempfile(fileext = ".topojson.gz")
  ok <- tryCatch({
    utils::download.file(url, tmp, mode = "wb", quiet = !verbose)
    file.exists(tmp) && file.size(tmp) > 0
  }, error = function(e) FALSE, warning = function(w) FALSE)
  if (!ok) {
    message("The geometries of mapSpainHist could not be downloaded from ", url,
            ". Check your internet connection and try again.")
    return(NULL)
  }
  file.copy(tmp, f, overwrite = TRUE)
  unlink(tmp)
  f
}

# Llegeix una capa de les geometries; NULL si no estan disponibles
read_hist_layer <- function(layer, cache_dir = NULL, update_cache = FALSE, verbose = FALSE) {
  f <- mhist_geometry_file(cache_dir, update_cache, verbose)
  if (is.null(f)) return(NULL)
  x <- sf::st_read(paste0("/vsigzip/", f), layer = layer, quiet = TRUE)
  sf::st_crs(x) <- 4258
  x[, setdiff(names(x), "id")]
}
