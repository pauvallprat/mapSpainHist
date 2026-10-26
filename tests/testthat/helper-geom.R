# Els tests que necessiten les geometries (descàrrega de Zenodo) no s'executen a CRAN
skip_if_no_geometries <- function() {
  testthat::skip_on_cran()
  if (is.null(suppressMessages(mapSpainHist:::mhist_geometry_file()))) {
    testthat::skip("Geometries not available")
  }
}
