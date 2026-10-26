# 01. Preparació de les fonts ---------------------------------------------------
# - Llegeix els mapes manuals (1900, 1930, 1950, 1970) sense modificar-los.
# - Retorna les Canàries a la seva posició real (els mapes manuals les tenen
#   desplaçades amb mapSpain::esp_move_can()).
# - Descarrega el SIANE 2005 (mateix origen geomètric que els mapes manuals) i hi
#   incorpora els territoris no municipals 53xxx dels mapes manuals.
# - Ho reprojecta tot a EPSG:3035 i desa intermediate/sources.gpkg

source("data-raw/00_config.R")

unmove_can <- function(x) {
  is_can <- substr(sprintf("%05d", x$cod), 1, 2) %in% c("35", "38")
  if (!any(is_can)) return(x)
  can <- st_transform(x[is_can, ], 3857)
  st_geometry(can) <- st_geometry(can) - can_offset_3857
  st_crs(can) <- 3857
  rbind(x[!is_can, ], st_transform(can, st_crs(x)))
}

clean_geom <- function(x) {
  st_geometry(x) <- "geometry"
  bad <- !st_is_valid(x)
  if (any(bad)) x[bad, ] <- st_make_valid(x[bad, ])
  x <- st_collection_extract(x, "POLYGON", warn = FALSE)
  # Només es fusionen els codis amb més d'un registre
  dup <- x$cod %in% x$cod[duplicated(x$cod)]
  if (any(dup)) {
    agg <- x[dup, ] |> group_by(cod) |>
      summarise(across(c(name, prov), first), .groups = "drop")
    x <- bind_rows(x[!dup, ], agg)
  }
  x <- st_cast(x, "MULTIPOLYGON")
  x[order(x$cod), ]
}

read_manual <- function(y) {
  m <- read_sf(file.path(dir_maps, sprintf("map_muni_es_%d.shp", y)))
  m <- m |> transmute(cod = as.integer(cod_ine), name = muni, prov = prov) |> apply_name_recode()
  m <- unmove_can(st_transform(m, 4326))
  clean_geom(st_transform(m, crs_work))
}

src <- lapply(c(1900, 1930, 1950, 1970), read_manual)
names(src) <- c(1900, 1930, 1950, 1970)

# SIANE 2005 ------------------------------------------------------------------
s05 <- mapSpain::esp_get_munic_siane(year = "2005-12-31", resolution = 3,
                                     moveCAN = FALSE, cache_dir = dir_cache)
# Els territoris no municipals (53xxx) tenen el codi a LAU_CODE i cmun buit
s05 <- s05 |>
  transmute(cod = as.integer(ifelse(is.na(cmun), LAU_CODE, paste0(cpro, cmun))),
            name = ifelse(is.na(name), paste("Territorio no municipal", LAU_CODE), name),
            prov = ine.prov.name) |>
  st_transform(crs_work)
s05 <- clean_geom(apply_name_recode(s05))

# Els 53xxx es mantenen tal com són als mapes manuals: un 53xxx del SIANE que no
# existeixi als mapes manuals s'assigna al municipi que el cobreix el 1970.
m70 <- src[["1970"]]
extra <- setdiff(s05$cod[s05$cod >= 53000], m70$cod)
for (k in extra) {
  x <- suppressWarnings(st_intersection(m70[, "cod"], st_geometry(s05[s05$cod == k, ])))
  x <- st_collection_extract(x, "POLYGON", warn = FALSE)
  x$name <- NA_character_; x$prov <- NA_character_
  cat("53xxx del SIANE", k, "-> es reparteix com al mapa de 1970 entre",
      paste(unique(x$cod), collapse = ", "), "\n")
  s05 <- bind_rows(s05[s05$cod != k, ], x[, c("cod", "name", "prov")])
}
s05 <- s05 |> group_by(cod) |> mutate(name = first(na.omit(name)), prov = first(na.omit(prov))) |>
  ungroup()
s05 <- clean_geom(s05)
cmp53 <- intersect(m70$cod[m70$cod >= 53000], s05$cod)
d53 <- vapply(cmp53, function(i) {
  a <- st_geometry(m70[m70$cod == i, ]); b <- st_geometry(s05[s05$cod == i, ])
  sum(as.numeric(st_area(st_sym_difference(a, b)))) / as.numeric(st_area(b))
}, numeric(1))
cat("53xxx: mapes manuals", sum(m70$cod >= 53000), "| SIANE", sum(s05$cod >= 53000),
    "| diferència relativa màxima", signif(max(d53), 3), "\n")
src[["2005"]] <- s05

# Diagnòstic ----------------------------------------------------------------
for (y in names(src)) {
  m <- src[[y]]
  cat(y, ": n =", nrow(m), "| invàlids:", sum(!st_is_valid(m)),
      "| àrea total km2:", round(sum(as.numeric(st_area(m))) / 1e6), "\n")
}
# Comprovació de l'encaix de les Canàries amb el SIANE
k <- intersect(src[["1970"]]$cod, s05$cod)
k <- k[substr(sprintf("%05d", k), 1, 2) %in% c("35", "38")]
d <- vapply(k, function(i) {
  a <- st_geometry(src[["1970"]][src[["1970"]]$cod == i, ])
  b <- st_geometry(s05[s05$cod == i, ])
  sum(as.numeric(st_area(st_sym_difference(a, b)))) / as.numeric(st_area(b))
}, numeric(1))
cat("Canàries: municipis comparats", length(k), "| diferència relativa mediana",
    signif(median(d), 3), "| màxima", signif(max(d), 3), "\n")

f <- file.path(dir_int, "sources.gpkg")
if (file.exists(f)) file.remove(f)
for (y in names(src)) write_sf(src[[y]], f, layer = paste0("src_", y))
cat("Desat a", f, "\n")
