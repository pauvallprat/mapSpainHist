# 10. Unitats superiors: províncies, partits judicials i circumscripcions --------------
# Es construeixen fusionant els municipis de cada cens (output/shp), de manera que
# hereten la topologia neta de la partició.
#   prov_hist_YYYY  : províncies, tots els censos (cod_unit = codi INE de 2 dígits)
#   pj_hist_YYYY    : partits judicials, 1900-1930 (columna PJ de l'Excel de censos)
#   circ_hist_1920  : districtes a Corts de la Restauració (munis_DistCorts.xlsx, cens 1920)
#   circ_hist_1931, 1933, 1936: circumscripcions de la II República (muni_circ_30s.xlsx, cens 1930)
# Codi de les unitats PJ i circ: 2 dígits de província + 2 dígits per ordre alfabètic
# dins la província (per als PJ, numeració comuna a tots els censos).
# Territoris no municipals (53xxx): província segons el polígon de províncies del SIANE
# 2005 (mapSpain) on cauen; PJ i circumscripció, la unitat d'aquesta província amb qui
# comparteixen més frontera.
# Sortides: output/shp_unitats/*.shp i output/unitats_municipis.csv (municipi -> unitat).

source("data-raw/00_config.R")
source(file.path(dir_pkg, "data-raw", "utils_topology.R"))

dir_u <- file.path(dir_out, "shp_unitats"); dir.create(dir_u, showWarnings = FALSE)
unlink(list.files(dir_u, full.names = TRUE))
censos <- read.csv(file.path(dir_out, "censos.csv"), encoding = "UTF-8",
                   colClasses = c(cod_ine = "character", cod_ccaa = "character"))
key <- function(x) tolower(stringi::stri_trans_general(x, "Latin-ASCII"))

read_muni <- function(t) {
  m <- read_sf(file.path(dir_out, "shp", sprintf("map_muni_es_hist_%d.shp", t)))
  st_transform(m, crs_work)
}

# Província dels territoris no municipals: polígon de províncies del SIANE on cauen
pv <- mapSpain::esp_get_prov_siane(year = "2005-12-31", resolution = 3, moveCAN = FALSE,
                                   cache_dir = dir_cache) |> st_transform(crs_work)
prov_condo <- function(m) {
  co <- m[m$no_munic == 1, ]
  w <- st_intersects(suppressWarnings(st_point_on_surface(co)), pv)
  setNames(vapply(w, function(j) if (length(j)) pv$cpro[j[1]] else NA_character_, ""), co$cod_ine)
}

# Unitat dels territoris no municipals: la de la seva província amb més frontera compartida
assign_condos <- function(m, unit, cpro_condo) {
  co <- which(m$no_munic == 1)
  nb <- st_relate(m[co, ], m, pattern = "F***1****")
  out <- setNames(rep(NA_character_, length(co)), m$cod_ine[co])
  for (k in seq_along(co)) {
    j <- nb[[k]]
    j <- j[m$no_munic[j] == 0 & !is.na(unit[m$cod_ine[j]]) &
             substr(unit[m$cod_ine[j]], 1, 2) == cpro_condo[m$cod_ine[co[k]]]]
    if (!length(j)) {
      # cap veí de la mateixa província: el municipi més proper de la província
      cand <- which(m$no_munic == 0 & substr(unit[m$cod_ine], 1, 2) %in% cpro_condo[m$cod_ine[co[k]]])
      j <- cand[st_nearest_feature(m[co[k], ], m[cand, ])]
      out[k] <- unit[m$cod_ine[j]]
      next
    }
    len <- vapply(j, function(i) sum(as.numeric(st_length(
      lines_only(suppressWarnings(st_intersection(st_geometry(m)[co[k]], st_geometry(m)[i])))))), numeric(1))
    u <- unit[m$cod_ine[j]]
    out[k] <- names(which.max(tapply(len, u, sum)))
  }
  out
}

# Dissol els municipis per unitat i desa el resultat
build <- function(m, unit, noms, layer) {
  m$cod_unit <- unit[m$cod_ine]
  miss <- is.na(m$cod_unit)
  if (any(miss)) cat("  ", layer, ": municipis sense unitat:", paste(m$cod_ine[miss], collapse = ", "), "\n")
  m <- m[!miss, ]
  ids <- split(seq_len(nrow(m)), m$cod_unit)
  g <- lapply(ids, function(i) st_union(st_geometry(m)[i])[[1]])
  u <- st_sf(cod_unit = names(ids), nom = noms[names(ids)], n_mun = vapply(ids, function(i) sum(m$no_munic[i] == 0), 1L),
             geometry = st_cast(st_sfc(g, crs = crs_work), "MULTIPOLYGON"))
  tr <- topo_report(u, layer)
  cat("  ", layer, ": unitats", nrow(u), "| solapaments", tr$parells_solapats, "| forats", tr$forats, "\n")
  write_sf(fix_ll(st_transform(u, crs_out), layer), file.path(dir_u, paste0(layer, ".shp")),
           layer_options = "ENCODING=UTF-8")
  data.frame(capa = layer, cod_ine = m$cod_ine, cod_unit = m$cod_unit)
}

# Codis: província (2 dígits) + ordre alfabètic del nom dins la província
make_codes <- function(prov2, nom) {
  d <- unique(data.frame(prov2, nom))
  d <- d[order(d$prov2, key(d$nom)), ]
  d$seq <- ave(seq_len(nrow(d)), d$prov2, FUN = seq_along)
  stopifnot(max(d$seq) < 100)
  setNames(paste0(d$prov2, sprintf("%02d", d$seq)), paste(d$prov2, d$nom))
}
# Província d'una unitat: la més freqüent entre els seus municipis (p. ex. Algeciras + Ceuta -> 11)
unit_prov <- function(cod_ine, nom) {
  p <- tapply(substr(cod_ine, 1, 2), nom, function(x) names(which.max(table(x))))
  p[nom]
}

eq <- list()

# 1. Províncies -------------------------------------------------------------------
for (t in census_years) {
  m <- read_muni(t)
  unit <- setNames(substr(m$cod_ine, 1, 2), m$cod_ine)
  pc <- prov_condo(m)
  unit[names(pc)] <- pc
  ct <- censos[censos$censo == t & censos$no_munic == 0, ]
  noms <- tapply(ct$prov, substr(ct$cod_ine, 1, 2), function(x) names(which.max(table(x))))
  eq[[length(eq) + 1]] <- build(m, unit, noms, paste0("prov_hist_", t))
}

# 2. Partits judicials (1900-1930) ------------------------------------------------
pj_years <- c(1900, 1910, 1920, 1930)
pjt <- censos[censos$censo %in% pj_years & !is.na(censos$hogares) & censos$no_munic == 0, ]
pjt$PJ[pjt$PJ == "Lucena" & substr(pjt$cod_ine, 1, 2) == "12"] <- "Lucena del Cid"
pjt$PJ[pjt$PJ == "San Sebastián" & substr(pjt$cod_ine, 1, 2) == "38"] <- "San Sebastián de La Gomera"
pjt$p2 <- unit_prov(pjt$cod_ine, pjt$PJ)
pj_codes <- make_codes(pjt$p2, pjt$PJ)
pj_noms <- setNames(sub("^[0-9]{2} ", "", names(pj_codes)), pj_codes)
for (t in pj_years) {
  m <- read_muni(t)
  ct <- pjt[pjt$censo == t, ]
  unit <- setNames(pj_codes[paste(ct$p2, ct$PJ)], ct$cod_ine)
  unit <- unit[m$cod_ine]; names(unit) <- m$cod_ine
  pc <- prov_condo(m)
  unit[names(pc)] <- assign_condos(m, unit, pc)
  eq[[length(eq) + 1]] <- build(m, unit, pj_noms, paste0("pj_hist_", t))
}

# 3. Districtes a Corts (1920) ----------------------------------------------------
dc <- read_xlsx(file.path(dir_pkg, "data-raw", "munis_DistCorts.xlsx"))
dc$cod_ine <- sprintf("%05d", as.integer(dc$cod_mun))
dc$DistCorts[dc$mun == "Estellencs"] <- "Palma"
dc$DistCorts[dc$cod_ine == "41063"] <- "Utrera"              # Los Molares
# Lavit i Terrassola formen Torrelavit (08287) al cens de 1920
dc <- rbind(dc, transform(dc[dc$cod_ine == "08716", ], cod_ine = "08287", mun = "Torrelavit"))
dc <- dc[!is.na(dc$DistCorts), ]                              # Melilla: sense districte
dc$p2 <- unit_prov(dc$cod_ine, dc$DistCorts)
c20 <- make_codes(dc$p2, dc$DistCorts)
m <- read_muni(1920)
unit <- setNames(c20[paste(dc$p2, dc$DistCorts)], dc$cod_ine)[m$cod_ine]; names(unit) <- m$cod_ine
pc <- prov_condo(m)
unit[names(pc)] <- assign_condos(m, unit, pc)
eq[[length(eq) + 1]] <- build(m, unit, setNames(sub("^[0-9]{2} ", "", names(c20)), c20), "circ_hist_1920")

# 4. Circumscripcions de la II República (1931, 1933, 1936; municipis de 1930) -----
ci <- read_xlsx(file.path(dir_pkg, "data-raw", "muni_circ_30s.xlsx"))
ci$cod_ine <- sprintf("%05d", as.integer(ci$cod_mun))
m <- read_muni(1930)
pc <- prov_condo(m)
for (v in c("dist31", "dist33", "dist36")) {
  y <- 1900 + as.integer(substr(v, 5, 6))
  p2 <- unit_prov(ci$cod_ine, ci[[v]])
  cc <- make_codes(p2, ci[[v]])
  unit <- setNames(cc[paste(p2, ci[[v]])], ci$cod_ine)[m$cod_ine]; names(unit) <- m$cod_ine
  unit[names(pc)] <- assign_condos(m, unit, pc)
  eq[[length(eq) + 1]] <- build(m, unit, setNames(sub("^[0-9]{2} ", "", names(cc)), cc), paste0("circ_hist_", y))
}

eq <- do.call(rbind, eq)
eq$tipus <- sub("_hist_.*", "", eq$capa); eq$any <- as.integer(sub(".*_", "", eq$capa))
write.csv(eq[, c("tipus", "any", "cod_ine", "cod_unit")], file.path(dir_out, "unitats_municipis.csv"),
          row.names = FALSE, fileEncoding = "UTF-8")
cat("Equivalències municipi -> unitat:", nrow(eq), "files\n")
