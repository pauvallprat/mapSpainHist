# Configuració comuna del pipeline ------------------------------------------
# Tots els scripts de data-raw/ fan source() d'aquest fitxer.

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readxl)
})
sf_use_s2(FALSE)

# Carpetes ------------------------------------------------------------------
# Els scripts s'executen des de l'arrel del paquet (p. ex. source("data-raw/01_prepare_sources.R")).
# MAPSPAINHIST_ROOT: carpeta amb els materials originals (mapes manuals map_muni_es_19xx,
# Municipis_Espanya_1842-2011.xlsx, MINAP_Variaciones_processing.xlsx, municipios_1900-2000.xlsx),
# disponibles al dipòsit de dades de Zenodo. Només es llegeixen, mai s'escriuen.
dir_maps <- Sys.getenv("MAPSPAINHIST_ROOT")
if (!nzchar(dir_maps)) stop("Definiu la variable d'entorn MAPSPAINHIST_ROOT amb la carpeta dels materials originals")
dir_pkg   <- getwd()
dir_int   <- file.path(dir_pkg, "data-raw", "intermediate")
dir_out   <- file.path(dir_pkg, "output")
dir_cache <- file.path(dir_pkg, "data-raw", "cache")
for (d in c(dir_int, dir_out, dir_cache)) dir.create(d, showWarnings = FALSE, recursive = TRUE)

# Paràmetres ------------------------------------------------------------------
crs_work <- 3035            # ETRS89-LAEA, mètric, per a tot el càlcul
crs_out  <- 4258            # ETRS89 geogràfic (com mapSpain)
can_offset_3857 <- c(550000, 920000)  # desplaçament de mapSpain::esp_move_can()

# Anys amb mapa (fonts) i anys de cens a generar
map_years    <- c(1900, 1930, 1950, 1970, 2005)
census_years <- c(1900, 1910, 1920, 1930, 1940, 1950, 1960, 1970, 1981, 1991, 2001)

# Data de referència de cada cens (per comparar amb les dates del MINAP)
census_dates <- as.Date(c(
  "1900-12-31", "1910-12-31", "1920-12-31", "1930-12-31", "1940-12-31",
  "1950-12-31", "1960-12-31", "1970-12-31", "1981-03-01", "1991-03-01",
  "2001-11-01"))
names(census_dates) <- census_years
map_dates <- c(census_dates[c("1900", "1930", "1950", "1970")], `2005` = as.Date("2005-12-31"))

# Recodificació per nom ------------------------------------------------------------
# Polígons dels mapes manuals que tenen bé el nom però un codi diferent del de l'Excel
# de censos (revisat a mà). S'aplica en llegir les fonts i els mapes nets.
name_recode <- data.frame(
  cpro = 44L,
  name = c("Loscos", "Luco de Bordón", "Luco de Jiloca", "Lledó"),
  cod  = c(44138L, 44139L, 44140L, 44141L))
apply_name_recode <- function(m) {
  cpro <- ifelse(m$cod >= 100000, m$cod %/% 10000, m$cod %/% 1000)
  k <- match(paste(cpro, m$name), paste(name_recode$cpro, name_recode$name))
  m$cod[!is.na(k)] <- name_recode$cod[k[!is.na(k)]]
  m
}

# Lectura de la capa de territoris dibuixats a mà (si el fitxer en té diverses, la
# capa territoris_manuals; així es pot desar la plantilla sencera amb la referència)
read_manual_territories <- function(f) {
  ly <- st_layers(f)$name
  x <- read_sf(f, layer = if ("territoris_manuals" %in% ly) "territoris_manuals" else ly[1])
  x[!st_is_empty(x) & !is.na(x$cod_ine) & nzchar(x$cod_ine), ]
}
