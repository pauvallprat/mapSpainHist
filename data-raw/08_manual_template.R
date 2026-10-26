# 08. Plantilla per dibuixar territoris a mà (QGIS) -------------------------------------
# Crea data-raw/manual/territoris_manuals_plantilla.gpkg amb dues capes:
#   - territoris_manuals: buida, per dibuixar-hi (cod_ine, cens_inici, cens_fi, comentari)
#   - referencia: polígons dels municipis veïns tal com queden als mapes de sortida
# Un cop dibuixats els polígons, deseu la capa territoris_manuals com a
# data-raw/manual/territoris_manuals.gpkg i torneu a executar 04-07.

source("data-raw/00_config.R")

# Municipis de referència: cas, cens del mapa de sortida i noms (província de Burgos)
refs <- list(
  list(cas = "Los Altos (09014)", censos = c(1910, 1920), cpro = "09",
       noms = c("Merindad de Valdivielso", "Pesadas de Burgos", "Villaescusa del Butrón")),
  list(cas = "Los Altos (09014)", censos = 1930, cpro = "09", noms = "Altos, Los"),
  list(cas = "Cañizar de Amaya (09511)", censos = 1940, cpro = "09",
       noms = c("Sotresgudo", "Barrio de San Felices", "Sotovellanos", "Cuevas de Amaya",
                "Amaya", "Salazar de Amaya", "Guadilla de Villamar")))

key <- function(x) gsub("[^a-z]", "", tolower(stringi::stri_trans_general(x, "Latin-ASCII")))
gpkg <- file.path(dir_out, "mapSpainHist.gpkg")
ref <- list()
for (r in refs) {
  for (t in r$censos) {
    m <- read_sf(gpkg, paste0("muni_", t))
    m <- m[substr(m$cod_ine, 1, 2) == r$cpro, ]
    k <- match(key(r$noms), key(m$municipio))
    if (any(is.na(k))) {
      # noms amb article o variants: coincidència parcial
      for (i in which(is.na(k))) {
        j <- which(grepl(key(r$noms[i]), key(m$municipio)) | grepl(paste0("^", key(m$municipio), "$"), key(r$noms[i])))
        if (length(j) == 1) k[i] <- j
      }
    }
    if (any(is.na(k))) cat("No trobats el", t, ":", paste(r$noms[is.na(k)], collapse = ", "), "\n")
    x <- m[na.omit(k), c("cod_ine", "municipio", "prov")]
    x$cens <- t
    x$cas <- r$cas
    ref[[length(ref) + 1]] <- x
  }
}
ref <- do.call(rbind, ref)
ref <- st_cast(st_transform(ref, crs_out), "MULTIPOLYGON")
print(st_drop_geometry(ref))

# Capa buida per dibuixar (tipus MULTIPOLYGON perquè QGIS la pugui editar)
plantilla <- st_sf(cod_ine = "", cens_inici = 0L, cens_fi = 0L, comentari = "",
                   geometry = st_sfc(st_multipolygon(list()), crs = crs_out))[0, ]

f <- file.path(dir_pkg, "data-raw", "manual", "territoris_manuals_plantilla.gpkg")
if (file.exists(f)) file.remove(f)
write_sf(plantilla, f, layer = "territoris_manuals")
write_sf(ref, f, layer = "referencia")
cat("Plantilla desada a", f, "| capes:", paste(st_layers(f)$name, collapse = ", "), "\n")
