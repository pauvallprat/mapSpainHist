# 02b. Municipis inclosos dins d'altres polígons -------------------------------------
# Aplica fix_nested() als mapes nets: el municipi dibuixat a sobre d'un altre sense
# retallar-lo es queda tot el seu polígon (no s'hi aplica el repartiment equitatiu).

source("data-raw/00_config.R")
source(file.path(dir_pkg, "data-raw", "utils_topology.R"))

for (y in map_years) {
  f <- file.path(dir_int, paste0("clean_", y, ".gpkg"))
  m <- read_sf(f)
  src <- read_sf(file.path(dir_int, "sources.gpkg"), paste0("src_", y))
  cat(y, "\n")
  m2 <- fix_nested(m, src)
  write_sf(m2, f, layer = paste0("clean_", y), delete_dsn = TRUE)
}
