# 04. Partició en unitats mínimes (àtoms) ------------------------------------------
# Superposa els mapes nets (1900, 1930, 1950, 1970, 2005): totes les fronteres de
# tots els mapes es noden i es poligonitzen. Cada àtom rep el codi que té a cada
# mapa (cod_1900, ..., cod_2005; NA si en aquell mapa la zona és un forat gran).
# Les estelles (àtoms minúsculs o molt prims, fruit de fronteres gairebé
# coincidents) es fusionen amb el veí amb qui comparteixen més codis històrics.

source("data-raw/00_config.R")
source(file.path(dir_pkg, "data-raw", "utils_topology.R"))

sliver_area  <- 500   # m2: àtoms més petits són estelles
sliver_width <- 2     # m: amplada mitjana (2*àrea/perímetre) per sota de la qual és estella

maps <- lapply(map_years, function(y) apply_name_recode(read_sf(file.path(dir_int, paste0("clean_", y, ".gpkg")))))
names(maps) <- map_years

# Territoris dibuixats a mà (opcional): data-raw/manual/territoris_manuals.gpkg amb les
# columnes cod_ine, cens_inici, cens_fi. Les seves fronteres s'afegeixen a la partició i
# 05_assign_census.R assigna el territori al municipi en els censos indicats.
f_man <- file.path(dir_pkg, "data-raw", "manual", "territoris_manuals.gpkg")
has_man <- file.exists(f_man)
if (has_man) {
  man <- st_transform(read_manual_territories(f_man), crs_work)
  man <- polys(st_make_valid(man))
  man$man_id <- seq_len(nrow(man))
  cat("Territoris manuals:", nrow(man), "
")
}

t0 <- Sys.time()
f_raw <- file.path(dir_int, "atoms_raw.rds")
# la partició es refà si els territoris manuals són més nous que la partició desada
if (file.exists(f_raw) && has_man && file.mtime(f_man) > file.mtime(f_raw)) file.remove(f_raw)
if (file.exists(f_raw)) {
  atoms <- readRDS(f_raw)
  cat("Cares brutes llegides de", f_raw, ":", nrow(atoms), "
")
} else {
  # 1. Noding i poligonització per cel·les ------------------------------------------
  # Per estalviar memòria, el noding es fa en cel·les de 25 km. Les vores de les
  # cel·les parteixen alguns àtoms, però no afecten el resultat (després es dissol
  # per municipi).
  cell_size <- 25000
  ext <- st_as_sfc(st_bbox(maps[["2005"]]))
  grid <- st_make_grid(ext, cellsize = cell_size)
  bnd <- lapply(maps, function(m) st_cast(st_boundary(st_geometry(m)), "MULTILINESTRING"))
  if (has_man) bnd$man <- st_cast(st_boundary(st_geometry(man)), "MULTILINESTRING")
  hits <- lapply(bnd, function(b) st_intersects(grid, b))
  use <- which(Reduce(`|`, lapply(hits, function(h) lengths(h) > 0)))
  cat("Cel·les amb fronteres:", length(use), "de", length(grid), "
")
  faces <- vector("list", length(use))
  for (k in seq_along(use)) {
    ci <- use[k]
    cell <- grid[ci]
    ls <- do.call(c, lapply(seq_along(bnd), function(y) {
      ids <- hits[[y]][[ci]]
      if (!length(ids)) return(NULL)
      x <- suppressWarnings(st_intersection(bnd[[y]][ids], cell))
      lines_only(x)
    }))
    ls <- c(ls, st_cast(st_boundary(cell), "MULTILINESTRING"))
    # arrodonir a 1 cm fa robust el noding de línies gairebé coincidents (sense
    # això GEOS pot deixar trams sense nodar i la poligonització els descarta)
    ls <- lwgeom::st_snap_to_grid(ls, 0.01)
    f <- st_collection_extract(st_polygonize(st_union(ls)), "POLYGON")
    faces[[k]] <- st_cast(st_sfc(f, crs = crs_work), "POLYGON")
    if (k %% 200 == 0) {
      cat("  cel·la", k, "/", length(use), "|", round(difftime(Sys.time(), t0, units = "mins"), 1), "min
")
      gc()
    }
  }
  atoms <- do.call(c, faces)
  rm(faces, bnd, hits); gc()
  cat("Cares brutes:", length(atoms), "| temps", round(difftime(Sys.time(), t0, units = "mins"), 1), "min
")
  atoms <- st_sf(atom = seq_along(atoms), geometry = atoms)
  pt <- suppressWarnings(st_point_on_surface(atoms))
  for (y in names(maps)) {
    j <- st_intersects(pt, maps[[y]])
    atoms[[paste0("cod_", y)]] <- vapply(j, function(k) if (length(k)) maps[[y]]$cod[k[1]] else NA_integer_, integer(1))
  }
  if (has_man) {
    j <- st_intersects(pt, man)
    atoms$man_id <- vapply(j, function(k) if (length(k)) man$man_id[k[1]] else NA_integer_, integer(1))
  }
  # cares sense codi: a menys de 5 m d'algun mapa = soroll dins el territori
  nc <- which(rowSums(!is.na(st_drop_geometry(atoms)[, paste0("cod_", map_years)])) == 0)
  near <- Reduce(`|`, lapply(maps, function(m) lengths(st_is_within_distance(pt[nc, ], m, 5)) > 0))
  atoms$fora <- FALSE
  atoms$fora[nc[!near]] <- TRUE
  saveRDS(atoms, f_raw)
}
cc <- c(paste0("cod_", map_years), if ("man_id" %in% names(atoms)) "man_id")

# Cares sense codi en cap mapa: si són fora del territori (mar dins les cel·les) o
# grans (> 1 ha, llacunes tancades per la costa) es descarten; si són petites i
# dins el territori són soroll numèric i es fusionen com a estelles.
nocov <- rowSums(!is.na(st_drop_geometry(atoms)[, cc])) == 0
out <- nocov & (atoms$fora | as.numeric(st_area(atoms)) > 1e4)
cat("Cares sense codi en cap mapa:", sum(nocov), "| grans (descartades):", sum(out),
    "| àrea descartada km2", round(sum(as.numeric(st_area(atoms[out, ]))) / 1e6, 3), "
")
atoms <- atoms[!out, ]
atoms$fora <- NULL

# 2. Estelles -------------------------------------------------------------------
# Cada estella s'uneix al veí (que no sigui estella) amb qui comparteix més codis
# històrics; en cas d'empat, al de més àrea. Les estelles que només toquen estelles
# es resolen a la passada següent.
merge_slivers <- function(atoms) {
  a <- as.numeric(st_area(atoms))
  per <- as.numeric(st_length(st_cast(st_boundary(atoms), "MULTILINESTRING")))
  w <- 2 * a / per
  is_sl <- a < sliver_area | w < sliver_width
  sl <- which(is_sl)
  cat("Estelles:", length(sl), "| àrea total m2", round(sum(a[sl])), "
")
  if (!length(sl)) return(atoms)
  t1 <- Sys.time()
  nb <- st_relate(atoms[sl, ], atoms, pattern = "F***1****")   # comparteixen un tram de frontera
  cat("  veïnatge:", round(difftime(Sys.time(), t1, units = "mins"), 1), "min
")
  pr <- data.frame(s = rep(sl, lengths(nb)), j = unlist(nb))
  pr <- pr[!is_sl[pr$j], ]
  M <- as.matrix(st_drop_geometry(atoms)[, cc]); M[is.na(M)] <- -1L
  pr$score <- rowSums(M[pr$s, , drop = FALSE] == M[pr$j, , drop = FALSE])
  pr$area <- a[pr$j]
  pr <- pr[order(pr$s, -pr$score, -pr$area), ]
  pr <- pr[!duplicated(pr$s), ]
  grp <- seq_len(nrow(atoms))
  grp[pr$s] <- pr$j
  cat("  estelles assignades:", nrow(pr), "de", length(sl), "
")
  ids <- split(seq_len(nrow(atoms)), grp)
  one <- lengths(ids) == 1
  g <- vector("list", length(ids))
  g[one] <- lapply(ids[one], function(i) st_geometry(atoms)[[i]])
  g[!one] <- lapply(ids[!one], function(i) st_union(st_geometry(atoms)[i])[[1]])
  root <- as.integer(names(ids))
  res <- st_sf(atom = root, st_drop_geometry(atoms)[root, cc],
               geometry = st_sfc(g, crs = crs_work))
  cat("  unió:", round(difftime(Sys.time(), t1, units = "mins"), 1), "min
")
  res
}
for (pass in 1:3) atoms <- merge_slivers(atoms)
atoms$atom <- seq_len(nrow(atoms))
atoms <- polys(atoms)
cat("Àtoms finals:", nrow(atoms), "| temps", round(difftime(Sys.time(), t0, units = "mins"), 1), "min
")

# 3. Comprovacions -------------------------------------------------------------
for (y in map_years) {
  ccy <- paste0("cod_", y)
  na <- is.na(atoms[[ccy]])
  cat(y, ": àtoms sense codi (forats grans)", sum(na), "| àrea km2", round(sum(as.numeric(st_area(atoms[na, ]))) / 1e6, 2),
      "| codis del mapa sense cap àtom:", length(setdiff(maps[[as.character(y)]]$cod, atoms[[ccy]])), "\n")
}
# Cada municipi de cada mapa ha de tenir unitats amb la mateixa àrea que el seu polígon
aa <- as.numeric(st_area(atoms))
bad_all <- list()
for (y in map_years) {
  m <- maps[[as.character(y)]]
  got <- tapply(aa, atoms[[paste0("cod_", y)]], sum)
  ref <- setNames(as.numeric(st_area(m)), m$cod)
  dif <- (got[names(ref)] - ref) / ref
  dif[is.na(dif)] <- -1
  bad <- names(ref)[abs(dif) > 0.01 & abs(got[names(ref)] - ref) > 1e4 | is.na(got[names(ref)])]
  cat(y, ": municipis amb àrea diferent (>1% i >1 ha):", length(bad), "
")
  if (length(bad)) bad_all[[as.character(y)]] <- data.frame(any = y, cod = as.integer(bad), nom = m$name[match(as.integer(bad), m$cod)],
                                                            ha_mapa = round(ref[bad] / 1e4, 1), ha_atoms = round(coalesce(got[bad], 0) / 1e4, 1))
}
if (length(bad_all)) { bad_all <- do.call(rbind, bad_all); print(head(bad_all, 30)) }
write_sf(atoms, file.path(dir_int, "atoms.gpkg"), layer = "atoms", delete_layer = TRUE)
cat("Desat a", file.path(dir_int, "atoms.gpkg"), "\n")
