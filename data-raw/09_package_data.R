# 09. Dades del paquet i del dipòsit de Zenodo --------------------------------------
# Paquet:
#   data/censos.rda   taula de censos (output/censos.csv)
#   data/unitats.rda  equivalències municipi -> província / PJ / circumscripció
# Dipòsit de dades a Zenodo (output/zenodo/), CC BY 4.0:
#   mapSpainHist_geometries_vX.Y.Z.topojson.gz  totes les capes en un sol TopoJSON (una
#       capa per cens i unitat; cada tram de frontera es desa una sola vegada i, sense
#       quantització, les coordenades són exactes). És el fitxer que descarrega el paquet.
#   mapSpainHist_vX.Y.Z.gpkg                   les mateixes capes en GeoPackage
#   censos.csv, unitats_municipis.csv          taules
# La versió de les dades ha de coincidir amb mhist_data_version (R/cache.R).

source("data-raw/00_config.R")
mapshaper <- Sys.getenv("MAPSHAPER", "mapshaper")
data_version <- "1.0.0"

dir_z <- file.path(dir_out, "zenodo"); dir.create(dir_z, recursive = TRUE, showWarnings = FALSE)
unlink(list.files(dir_z, full.names = TRUE))
shps <- c(file.path(dir_out, "shp", sprintf("map_muni_es_hist_%d.shp", census_years)),
          list.files(file.path(dir_out, "shp_unitats"), "[.]shp$", full.names = TRUE))

# TopoJSON (fitxer del paquet)
f_topo <- file.path(dir_z, paste0("mapSpainHist_geometries_v", data_version, ".topojson"))
out <- system2(mapshaper, c("-i", shQuote(shps), "combine-files",
                            "-o", shQuote(f_topo), "format=topojson", "no-quantization"),
               stdout = TRUE, stderr = TRUE)
cat(out, sep = "\n")
R.utils::gzip(f_topo, overwrite = TRUE, remove = TRUE)
cat("TopoJSON:", round(file.size(paste0(f_topo, ".gz")) / 1e6, 1), "MB\n")

# GeoPackage amb totes les capes
f_gpkg <- file.path(dir_z, paste0("mapSpainHist_v", data_version, ".gpkg"))
for (s in shps) write_sf(read_sf(s), f_gpkg, layer = sub("[.]shp$", "", basename(s)))
cat("GeoPackage:", round(file.size(f_gpkg) / 1e6, 1), "MB\n")

# Taules
file.copy(file.path(dir_out, c("censos.csv", "unitats_municipis.csv")), dir_z, overwrite = TRUE)

# Dades incloses al paquet
censos <- read.csv(file.path(dir_out, "censos.csv"), encoding = "UTF-8",
                   colClasses = c(cod_ine = "character", cod_ccaa = "character"))
censos$censo <- as.integer(censos$censo)
dir.create(file.path(dir_pkg, "data"), showWarnings = FALSE)
save(censos, file = file.path(dir_pkg, "data", "censos.rda"), compress = "xz")

unitats <- read.csv(file.path(dir_out, "unitats_municipis.csv"), encoding = "UTF-8",
                    colClasses = c(cod_ine = "character", cod_unit = "character"))
unitats$any <- as.integer(unitats$any)
save(unitats, file = file.path(dir_pkg, "data", "unitats.rda"), compress = "xz")
cat("censos.rda:", round(file.size(file.path(dir_pkg, "data", "censos.rda")) / 1e6, 2), "MB | unitats.rda:",
    round(file.size(file.path(dir_pkg, "data", "unitats.rda")) / 1e6, 2), "MB\n")
