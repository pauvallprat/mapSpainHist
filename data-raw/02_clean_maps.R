# 02. Neteja topològica de cada mapa ---------------------------------------------
# - Solapaments: la zona solapada es reparteix equitativament entre els municipis
#   que se solapen (cada punt va al municipi amb la frontera més propera).
# - Forats < min_hole_keep: s'omplen per expansió equitativa de les fronteres veïnes.
# - Forats més grans es deixen buits: es resolen a 03 amb la informació dels
#   mapes d'altres anys (p. ex. un municipi absorbit que no s'ha reassignat).

source("data-raw/00_config.R")
source(file.path(dir_pkg, "data-raw", "utils_topology.R"))

min_hole_keep <- 1e4  # m2 (1 ha)

gp_in  <- file.path(dir_int, "sources.gpkg")
args <- commandArgs(trailingOnly = TRUE)
years <- if (length(args)) as.integer(args) else map_years

rep <- list()
for (y in years) {
  t0 <- Sys.time()
  cat("\n==", y, "==\n")
  m <- read_sf(gp_in, paste0("src_", y))
  before <- topo_report(m, paste0(y, " original"))
  m2 <- fix_topology(m, max_hole_fill = min_hole_keep)
  # Queda soroll numèric submètric (solapaments i forats < 1 m2) que desapareix
  # a 04_atoms.R, on la partició es construeix poligonitzant les fronteres noades.
  after <- topo_report(m2, paste0(y, " net"))
  rep[[as.character(y)]] <- rbind(before, after)
  print(rbind(before, after))
  write_sf(m2, file.path(dir_int, paste0("clean_", y, ".gpkg")), layer = paste0("clean_", y),
           delete_dsn = TRUE)
  cat("temps:", round(difftime(Sys.time(), t0, units = "mins"), 1), "min\n")
}
rep <- do.call(rbind, rep)
write.csv(rep, file.path(dir_int, paste0("clean_report_", paste(years, collapse = "_"), ".csv")),
          row.names = FALSE)
