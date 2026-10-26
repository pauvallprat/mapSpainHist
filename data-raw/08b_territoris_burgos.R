# 08b. Territoris manuals de Burgos (Los Altos i Cañizar de Amaya) -------------------
# Construeix data-raw/manual/territoris_manuals.gpkg a partir dels polígons redibuixats
# a la capa "referencia" de territoris_manuals_plantilla.gpkg (cens 1910 i 1940):
#   - Los Altos (09014) es crea entre 1900 i 1910 amb territori de la Merindad de
#     Valdivielso; Los Altos + Pesadas de Burgos + Villaescusa del Butrón (1910) formen
#     el Los Altos del 1930.
#   - El territori de Cañizar de Amaya (09511, només el 1940) és de Barrio de San
#     Felices (09042) en els censos anteriors i fins al 1970.

source("data-raw/00_config.R")

f_ref <- file.path(dir_pkg, "data-raw", "manual", "territoris_manuals_plantilla.gpkg")
ref <- read_sf(f_ref, "referencia")
g <- function(cod, cens) {
  x <- st_geometry(ref[ref$cod_ine == cod & ref$cens == cens, ])
  stopifnot(length(x) == 1)
  x
}
alt <- g("09014", 1910); pes <- g("09529", 1910); vil <- g("09541", 1910); can <- g("09511", 1940)

regles <- list(
  list(alt, "09217", 1900, 1900, "Territori de Los Altos: Merindad de Valdivielso abans de 1910"),
  list(alt, "09014", 1910, 1920, "Los Altos"),
  list(pes, "09529", 1900, 1920, "Pesadas de Burgos redibuixat"),
  list(vil, "09541", 1900, 1920, "Villaescusa del Butrón redibuixat"),
  list(can, "09042", 1900, 1930, "Territori de Cañizar de Amaya: Barrio de San Felices"),
  list(can, "09511", 1940, 1940, "Cañizar de Amaya"),
  list(can, "09042", 1950, 1970, "Territori de Cañizar de Amaya: Barrio de San Felices"))

man <- do.call(rbind, lapply(regles, function(r) {
  st_sf(cod_ine = r[[2]], cens_inici = as.integer(r[[3]]), cens_fi = as.integer(r[[4]]),
        comentari = r[[5]], geometry = st_cast(r[[1]], "MULTIPOLYGON"))
}))
f_out <- file.path(dir_pkg, "data-raw", "manual", "territoris_manuals.gpkg")
if (file.exists(f_out)) file.remove(f_out)
write_sf(man, f_out, layer = "territoris_manuals")
print(st_drop_geometry(man))
cat("Desat a", f_out, "\n")
