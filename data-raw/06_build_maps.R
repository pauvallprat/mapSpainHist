# 06. Mapes finals per cens -------------------------------------------------------
# Dissol els àtoms (simplificats, si existeix atoms_simpl.gpkg) per municipi a cada cens
# i desa només la geometria i el codi:
#   output/shp/map_muni_es_hist_YYYY.shp  (un per cens; cod_ine, no_munic)
#   output/mapSpainHist.gpkg              (capes muni_YYYY + taula censos)
#   output/censos.csv                     (dades de l'Excel de censos + noms dels 53xxx)
# i comprova la topologia del resultat (solapaments, forats, codis).

source("data-raw/00_config.R")
source(file.path(dir_pkg, "data-raw", "utils_topology.R"))

f_atoms <- file.path(dir_int, "atoms_final.gpkg")
if (!file.exists(f_atoms)) f_atoms <- file.path(dir_int, "atoms_simpl.gpkg")
if (!file.exists(f_atoms)) f_atoms <- file.path(dir_int, "atoms.gpkg")
cat("Àtoms:", basename(f_atoms), "\n")
atoms <- read_sf(f_atoms, "atoms")
asg <- readRDS(file.path(dir_int, "assign.rds"))
src05 <- read_sf(file.path(dir_int, "sources.gpkg"), "src_2005") |> st_drop_geometry()

cens <- read_xlsx(file.path(dir_maps, "Municipis_Espanya_1842-2011.xlsx"), sheet = "fullcens") |>
  mutate(cod = as.integer(cod_mun), censo = as.integer(censo))

dir_shp <- file.path(dir_out, "shp"); dir.create(dir_shp, showWarnings = FALSE)
gpkg <- file.path(dir_out, "mapSpainHist.gpkg")
if (file.exists(gpkg)) file.remove(gpkg)

dissolve <- function(geom, cod) {
  ids <- split(seq_along(cod), cod)
  one <- lengths(ids) == 1
  g <- vector("list", length(ids))
  g[one] <- lapply(ids[one], function(i) geom[[i]])
  g[!one] <- lapply(ids[!one], function(i) st_union(geom[i])[[1]])
  g <- st_sfc(g, crs = st_crs(geom))
  bad <- !st_is_valid(g)
  if (any(bad)) g[bad] <- polys(st_make_valid(g[bad]))
  st_sf(cod = as.integer(names(ids)), geometry = st_cast(g, "MULTIPOLYGON"))
}

checks <- list(); condos <- list()
for (t in census_years) {
  t0 <- Sys.time()
  r <- asg$res[[as.character(t)]]
  cod <- r$cod[match(atoms$atom, r$atom)]
  m <- dissolve(st_geometry(atoms), cod)
  m$no_munic <- as.integer(m$cod >= 53000 & m$cod < 100000)
  nm <- m$no_munic == 1
  condos[[as.character(t)]] <- data.frame(cod = m$cod[nm], censo = t,
                                          mun = src05$name[match(m$cod[nm], src05$cod)],
                                          prov = src05$prov[match(m$cod[nm], src05$cod)])
  m <- m |> transmute(cod_ine = sprintf("%05d", cod), no_munic)

  # Topologia i codis
  tr <- topo_report(m, as.character(t))
  vig <- sprintf("%05d", cens$cod[cens$censo == t & !is.na(cens$hogares)])
  tr$falten_vigents <- length(setdiff(vig, m$cod_ine))
  tr$sobren_no_vigents <- sum(!m$cod_ine %in% vig & m$no_munic == 0)
  tr$area_km2 <- round(sum(as.numeric(st_area(m))) / 1e6)
  tr$vertexs <- nrow(st_coordinates(m))
  checks[[as.character(t)]] <- tr

  out <- fix_ll(st_transform(m, crs_out), t)
  write_sf(out, file.path(dir_shp, sprintf("map_muni_es_hist_%d.shp", t)),
           delete_dsn = TRUE, layer_options = "ENCODING=UTF-8")
  write_sf(out, gpkg, layer = paste0("muni_", t))
  cat(t, ": municipis", nrow(m), "| temps", round(difftime(Sys.time(), t0, units = "mins"), 1), "min\n")
}
checks <- do.call(rbind, checks)
print(checks)
write.csv(checks, file.path(dir_out, "validacio_topologia.csv"), row.names = FALSE)

# Taula de censos (totes les edicions de l'Excel) + territoris no municipals ----------
censos <- cens |>
  transmute(cod_ine = sprintf("%05d", cod), censo, municipio = mun, prov, cod_ccaa, ccaa, PJ,
            hogares, pder, phec, pob_serie = poblacion_serie_seguida, no_munic = 0L)
cd <- do.call(rbind, condos)
censos <- bind_rows(censos, data.frame(cod_ine = sprintf("%05d", cd$cod), censo = cd$censo,
                                       municipio = cd$mun, prov = cd$prov, no_munic = 1L))
censos <- censos |> arrange(cod_ine, censo)
write.csv(censos, file.path(dir_out, "censos.csv"), row.names = FALSE, fileEncoding = "UTF-8")
write_sf(censos, gpkg, layer = "censos")
cat("Taula censos:", nrow(censos), "files\n")
