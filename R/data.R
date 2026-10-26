#' Census figures of Spanish municipalities, 1842-2011
#'
#' Population census data for every municipality and census edition, from
#' `Municipis_Espanya_1842-2011.xlsx`. A municipality is in force at a census when
#' `hogares` is not missing. Rows with `no_munic == 1` are the non-municipal
#' territories (codes 53xxx) present in the maps, which have no census figures.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{cod_ine}{INE municipality code (5 characters; 6 for municipalities
#'     extinct before 1900).}
#'   \item{censo}{Census year.}
#'   \item{municipio}{Municipality name.}
#'   \item{prov}{Province.}
#'   \item{cod_ccaa, ccaa}{Autonomous community code and name.}
#'   \item{PJ}{Judicial district (partido judicial).}
#'   \item{hogares}{Households.}
#'   \item{pder}{De jure population.}
#'   \item{phec}{De facto population.}
#'   \item{pob_serie}{Continuous population series.}
#'   \item{no_munic}{1 for non-municipal territories (53xxx), 0 otherwise.}
#' }
"censos"

#' Municipalities of each historical higher-level unit
#'
#' Correspondence between municipalities (`cod_ine`) and the units returned by
#' [esp_get_prov_hist()], [esp_get_pj_hist()] and [esp_get_circ_hist()]. Useful to
#' aggregate municipal data. Non-municipal territories (53xxx) are included with
#' the unit they were assigned to.
#'
#' @format A data frame with columns:
#' \describe{
#'   \item{tipus}{`"prov"`, `"pj"` (judicial district) or `"circ"` (electoral district).}
#'   \item{any}{Census year (prov, pj) or election year (circ: 1920, 1931, 1933, 1936).}
#'   \item{cod_ine}{INE municipality code.}
#'   \item{cod_unit}{Unit code (2 digits for provinces, 4 digits otherwise).}
#' }
"unitats"
