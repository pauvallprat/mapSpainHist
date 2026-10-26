# 04b. Simplificació de la partició preservant la topologia -----------------------------
# Les unitats mínimes es simplifiquen amb mapshaper (https://github.com/mbloch/mapshaper,
# npm install -g mapshaper): construeix els arcs compartits i simplifica cada frontera
# una sola vegada, de manera que no apareixen forats ni solapaments. keep-shapes evita
# que desaparegui cap unitat. El resultat (atoms_simpl.gpkg) és el que fa servir 06.

source("data-raw/00_config.R")
source(file.path(dir_pkg, "data-raw", "utils_topology.R"))

interval <- as.numeric(Sys.getenv("SIMPL_INTERVAL", "20"))   # m (tolerància de distància)
mapshaper <- Sys.getenv("MAPSHAPER", "mapshaper")

atoms <- read_sf(file.path(dir_int, "atoms.gpkg"), "atoms")
tmp <- file.path(tempdir(), "ms"); dir.create(tmp, showWarnings = FALSE)
f_in <- file.path(tmp, "atoms.shp"); f_out <- file.path(tmp, "atoms_s.shp")
if (file.exists(f_in)) unlink(list.files(tmp, full.names = TRUE))
write_sf(atoms["atom"], f_in)

args <- c("-i", shQuote(f_in), "snap", "snap-interval=0.02",
          "-simplify", paste0("interval=", interval), "planar", "keep-shapes",
          "-clean",
          "-o", shQuote(f_out), "force")
t0 <- Sys.time()
out <- system2(mapshaper, args, stdout = TRUE, stderr = TRUE)
cat(out, sep = "\n")
cat("temps mapshaper:", round(difftime(Sys.time(), t0, units = "mins"), 1), "min\n")

s <- read_sf(f_out)
st_crs(s) <- crs_work
s <- polys(s)
s <- s[!st_is_empty(s), ]
bad <- !st_is_valid(s)
if (any(bad)) s[bad, ] <- polys(st_make_valid(s[bad, ]))
cat("Àtoms originals:", nrow(atoms), "| simplificats:", nrow(s), "| perduts:",
    length(setdiff(atoms$atom, s$atom)), "| duplicats:", sum(duplicated(s$atom)), "\n")
lost <- setdiff(atoms$atom, s$atom)
if (length(lost)) {
  la <- as.numeric(st_area(atoms[atoms$atom %in% lost, ]))
  cat("Àtoms absorbits pels veïns en la neteja:", length(lost), "| àrees m2:", paste(round(la, 1), collapse = ", "), "
")
  stopifnot(all(la < 1e4))   # només s'accepta perdre estelles petites
}
# si mapshaper parteix algun àtom en diversos registres, es reunifiquen
if (any(duplicated(s$atom))) {
  s <- s |> group_by(atom) |> summarise(.groups = "drop")
}
atoms <- atoms[atoms$atom %in% s$atom, ]
s <- s[match(atoms$atom, s$atom), ]
s <- cbind(st_drop_geometry(atoms), geometry = st_cast(st_geometry(s), "MULTIPOLYGON")) |> st_as_sf()

nv <- function(x) sum(vapply(st_geometry(st_cast(x, "MULTIPOLYGON")), function(g) length(unlist(g)) / 2, numeric(1)))
a0 <- as.numeric(st_area(atoms)); a1 <- as.numeric(st_area(s))
cat("Vèrtexs:", nv(atoms), "->", nv(s), "\n")
cat("Àrea total km2:", round(sum(a0) / 1e6, 1), "->", round(sum(a1) / 1e6, 1), "\n")
rel <- abs(a1 - a0) / a0
cat("Canvi relatiu d'àrea per àtom (àtoms > 1 km2): mediana", signif(median(rel[a0 > 1e6]), 3),
    "| p99", signif(quantile(rel[a0 > 1e6], 0.99), 3), "| màx", signif(max(rel[a0 > 1e6]), 3), "\n")
print(topo_report(s, "àtoms simplificats"))

write_sf(s, file.path(dir_int, "atoms_simpl.gpkg"), layer = "atoms", delete_dsn = TRUE)
cat("Desat a", file.path(dir_int, "atoms_simpl.gpkg"), "\n")
