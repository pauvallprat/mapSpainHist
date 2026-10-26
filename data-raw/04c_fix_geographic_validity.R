# 04c. Validesa en coordenades geogràfiques preservant la topologia -------------------
# Algunes unitats simplificades són vàlides en EPSG:3035 però no després de reprojectar a
# EPSG:4258 (GEOS) o sobre l'esfera (s2): hi ha vèrtexs gairebé sobre un segment no
# adjacent. Es corregeix allunyant uns metres el vèrtex conflictiu del segment a TOTES les
# unitats que el comparteixen (les fronteres
# continuen sent idèntiques a banda i banda) i
# s'accepta el canvi només si totes les unitats afectades queden vàlides en 3035, en 4258
# (GEOS) i en s2 i si l'àrea de cap unitat no canvia més de 2.000 m2.
# Llegeix intermediate/atoms_simpl.gpkg i escriu intermediate/atoms_final.gpkg.

source("data-raw/00_config.R")
source(file.path(dir_pkg, "data-raw", "utils_topology.R"))

f <- file.path(dir_int, "atoms_simpl.gpkg")
a <- read_sf(f, "atoms")
a <- st_cast(a, "MULTIPOLYGON")

valid_all <- function(g) {
  ok1 <- st_is_valid(g)
  ll <- st_transform(g, crs_out)
  ok2 <- st_is_valid(ll)
  ok3 <- suppressMessages({ sf_use_s2(TRUE); r <- s2::s2_is_valid(ll); sf_use_s2(FALSE); r })
  ok1 & ok2 & ok3
}

# Coordenades de cada àtom com a llista d'anells (matrius tancades)
rings_of <- function(g) {
  lapply(unclass(g), function(p) lapply(p, function(r) r[, 1:2, drop = FALSE]))
}
build_geom <- function(pl) st_multipolygon(lapply(pl, function(p) lapply(p, function(r) r)))

# Elimina el vèrtex xy (coordenada exacta) dels anells; NULL si algun anell queda degenerat
drop_vertex <- function(pl, xy) {
  for (i in seq_along(pl)) for (j in seq_along(pl[[i]])) {
    r <- pl[[i]][[j]]
    hit <- which(r[, 1] == xy[1] & r[, 2] == xy[2])
    if (!length(hit)) next
    # un vèrtex repetit dins l'anell (punt de pinçament) no es toca
    if (length(setdiff(hit, c(1, nrow(r)))) > 1 || (length(hit) > 1 && !all(c(1, nrow(r)) %in% hit))) return(NULL)
    n <- nrow(r)
    closing <- hit %in% c(1, n)
    r <- r[-hit, , drop = FALSE]
    if (any(closing)) r <- rbind(r, r[1, ])       # el primer/últim vèrtex: es torna a tancar
    if (nrow(r) < 4) return(NULL)
    pl[[i]][[j]] <- r
  }
  pl
}

# Mou el vèrtex xy (coordenada exacta) a nxy a tots els anells on apareix
move_vertex <- function(pl, xy, nxy) {
  for (i in seq_along(pl)) for (j in seq_along(pl[[i]])) {
    r <- pl[[i]][[j]]
    hit <- which(r[, 1] == xy[1] & r[, 2] == xy[2])
    if (length(hit)) { r[hit, 1] <- nxy[1]; r[hit, 2] <- nxy[2]; pl[[i]][[j]] <- r }
  }
  pl
}

# Vèrtexs candidats d'un àtom: els que són a menys de tol m d'un segment no adjacent del
# mateix àtom, amb el punt més proper d'aquest segment
candidates <- function(g, tol) {
  out <- list()
  rings <- unlist(lapply(unclass(g), function(p) lapply(p, function(r) r[, 1:2, drop = FALSE])), recursive = FALSE)
  segs <- do.call(rbind, lapply(seq_along(rings), function(k) {
    r <- rings[[k]]; n <- nrow(r) - 1
    data.frame(ring = k, i = seq_len(n), x1 = r[1:n, 1], y1 = r[1:n, 2], x2 = r[2:(n + 1), 1], y2 = r[2:(n + 1), 2])
  }))
  sg <- st_sfc(lapply(seq_len(nrow(segs)), function(q) st_linestring(rbind(c(segs$x1[q], segs$y1[q]), c(segs$x2[q], segs$y2[q])))), crs = crs_work)
  pts <- st_sfc(lapply(seq_len(nrow(segs)), function(q) st_point(c(segs$x1[q], segs$y1[q]))), crs = crs_work)
  w <- st_is_within_distance(pts, sg, tol)
  for (q in seq_len(nrow(segs))) {
    n <- max(segs$i[segs$ring == segs$ring[q]])
    prev <- which(segs$ring == segs$ring[q] & segs$i == ifelse(segs$i[q] == 1, n, segs$i[q] - 1))
    near <- setdiff(w[[q]], c(q, prev))
    for (o in near) {
      np <- st_coordinates(st_cast(st_nearest_points(pts[q], sg[o]), "POINT"))[2, 1:2]
      out[[length(out) + 1]] <- c(segs$x1[q], segs$y1[q], np)
    }
  }
  if (!length(out)) return(NULL)
  unique(do.call(rbind, out))
}

g_all <- st_geometry(a)
index <- function(g) { xy <- st_coordinates(g); split(xy[, "L3"], paste(xy[, 1], xy[, 2])) }
atom_of <- index(g_all)

# El canvi no pot obrir forats ni solapaments amb els veïns
local_topo_ok <- function(aff, gnew) {
  nb <- unique(c(aff, unlist(st_intersects(st_as_sfc(st_bbox(g_all[aff])), g_all))))
  old <- g_all[nb]; new <- old
  for (q in seq_along(aff)) new[[match(aff[q], nb)]] <- gnew[[q]]
  u_old <- as.numeric(st_area(st_union(old))); u_new <- as.numeric(st_area(st_union(new)))
  abs(u_new - u_old) < 1 && abs(sum(as.numeric(st_area(new))) - u_new) < 1
}

try_fix <- function(b) {
  for (tol in c(2, 10, 30)) {
    cand <- candidates(g_all[[b]], tol)
    if (is.null(cand)) next
    for (k in seq_len(nrow(cand))) {
      xy <- cand[k, 1:2]; cp <- cand[k, 3:4]
      aff <- unique(atom_of[[paste(xy[1], xy[2])]])
      d <- xy - cp; L <- sqrt(sum(d^2))
      # primer s'allunya el vèrtex del segment proper; si no n'hi ha prou, es proven
      # desplaçaments en 8 direccions
      ang <- seq(0, 2 * pi, length.out = 9)[-9]
      moves <- c(if (L > 1e-9) lapply(c(3, 6, 12, 25), function(p) cp + d / L * p - xy),
                 unlist(lapply(c(1, 2, 3, 6, 12), function(r) lapply(ang, function(t) r * c(cos(t), sin(t)))),
                        recursive = FALSE))
      for (mv in moves) {
        nxy <- xy + mv; push <- sqrt(sum(mv^2)) + L
        new <- lapply(aff, function(i) move_vertex(rings_of(g_all[[i]]), xy, nxy))
        gnew <- st_sfc(lapply(new, build_geom), crs = crs_work)
        dA <- abs(as.numeric(st_area(gnew)) - as.numeric(st_area(g_all[aff])))
        if (all(dA < 2000) && all(valid_all(gnew)) && local_topo_ok(aff, gnew)) {
          for (q in seq_along(aff)) g_all[[aff[q]]] <<- gnew[[q]]
          cat("  àtom", a$atom[b], ": vèrtex desplaçat", round(push - L, 1), "m (", length(aff), "àtoms, dA màx",
              round(max(dA)), "m2)
")
          return(TRUE)
        }
      }
    }
  }
  FALSE
}

for (round in 1:5) {
  bad <- which(!valid_all(g_all))
  cat("Ronda", round, ": àtoms invàlids", length(bad), "
")
  if (!length(bad)) break
  for (b in bad) if (!try_fix(b)) cat("  àtom", a$atom[b], ": no s'ha pogut corregir
")
  atom_of <- index(g_all)
}
st_geometry(a) <- g_all
print(topo_report(a, "àtoms (validesa geogràfica)"))
f_out <- file.path(dir_int, "atoms_final.gpkg")
write_sf(a, f_out, layer = "atoms", delete_dsn = TRUE)
cat("Desat a", f_out, "
")
