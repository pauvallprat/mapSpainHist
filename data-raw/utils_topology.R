# Funcions de topologia -----------------------------------------------------------
# Repartiment "equitatiu" d'una regió (solapament o buit) entre diversos
# municipis: cada punt de la regió s'assigna al municipi la frontera del qual
# és més propera. S'implementa amb un diagrama de Voronoi de punts densificats
# sobre les fronteres dels candidats.

# Es queda només amb la part poligonal (sfc de MULTIPOLYGON; buit si no n'hi ha)
polys <- function(x) {
  g <- st_geometry(x)
  keep <- function(gi) {
    if (inherits(gi, c("POLYGON", "MULTIPOLYGON"))) return(st_cast(st_sfc(gi), "MULTIPOLYGON")[[1]])
    if (inherits(gi, "GEOMETRYCOLLECTION")) {
      p <- Filter(function(e) inherits(e, c("POLYGON", "MULTIPOLYGON")), unclass(gi))
      if (length(p)) return(st_cast(st_union(st_sfc(p)), "MULTIPOLYGON")[[1]])
    }
    st_multipolygon()
  }
  out <- st_sfc(lapply(g, keep), crs = st_crs(g))
  if (inherits(x, "sf")) {
    st_geometry(x) <- out
    return(x[!st_is_empty(x), ])
  }
  out
}

# Divideix la regió R (sfc d'un polígon) entre els candidats (sfc de geometries
# "nucli" i vector d'identificadors). Retorna un sf amb columnes id, geometry.
split_region <- function(R, cand_geoms, cand_ids) {
  crs <- st_crs(R)
  if (length(cand_ids) == 1) {
    return(st_sf(id = cand_ids, geometry = R))
  }
  # ~300 punts per regió: suficient per a tires primes i ràpid
  per <- sum(as.numeric(st_length(st_boundary(R))))
  step <- min(25, max(0.25, per / 300))
  near <- st_buffer(R, max(0.05, step / 10))
  xy <- NULL
  for (k in seq_along(cand_ids)) {
    b <- suppressWarnings(st_intersection(st_boundary(cand_geoms[k]), near))
    if (length(b) == 0 || all(st_is_empty(b))) next
    b <- st_segmentize(b, step)
    cc <- st_coordinates(b)[, 1:2, drop = FALSE]
    if (nrow(cc)) xy <- rbind(xy, cbind(cc, k))
  }
  if (is.null(xy) || length(unique(xy[, 3])) < 2) {
    # Només un candidat realment adjacent: tota la regió per a ell
    k <- if (is.null(xy)) {
      which.min(as.numeric(st_distance(R, cand_geoms)))
    } else xy[1, 3]
    return(st_sf(id = cand_ids[k], geometry = R))
  }
  xy <- xy[!duplicated(round(xy[, 1:2], 3)), , drop = FALSE]
  pts <- st_sfc(lapply(seq_len(nrow(xy)), function(i) st_point(xy[i, 1:2])), crs = crs)
  env <- st_buffer(R, 10 * step + 10)
  vor <- st_collection_extract(st_voronoi(st_union(pts), envelope = st_geometry(env)[[1]]))
  st_crs(vor) <- crs
  w <- st_intersects(vor, pts)
  lab <- vapply(w, function(j) if (length(j)) xy[j[1], 3] else NA_real_, numeric(1))
  out <- lapply(sort(unique(na.omit(lab))), function(k) {
    g <- polys(suppressWarnings(st_intersection(st_union(vor[which(lab == k)]), R)))
    g <- g[!st_is_empty(g)]
    if (length(g)) st_sf(id = cand_ids[k], geometry = st_union(g)) else NULL
  })
  out <- do.call(rbind, out)
  if (is.null(out)) {
    k <- which.min(as.numeric(st_distance(R, cand_geoms)))
    out <- st_sf(id = cand_ids[k], geometry = R)
  }
  out
}

# Forats interiors (anells interiors) d'una geometria unió
interior_holes <- function(u) {
  polys <- st_cast(st_cast(st_sfc(u), "MULTIPOLYGON"), "POLYGON")
  crs <- st_crs(u)
  h <- unlist(lapply(polys, function(p) {
    if (length(p) > 1) lapply(p[-1], function(r) st_polygon(list(r))) else list()
  }), recursive = FALSE)
  if (!length(h)) return(st_sfc(crs = crs))
  st_sfc(h, crs = crs)
}

# Parells de polígons amb interiors solapats
overlap_pairs <- function(m) {
  rel <- st_relate(m, pattern = "2********")
  p <- do.call(rbind, lapply(seq_along(rel), function(i) {
    j <- rel[[i]][rel[[i]] > i]
    if (length(j)) cbind(i, j) else NULL
  }))
  if (is.null(p)) matrix(integer(0), ncol = 2) else p
}

# Diagnòstic topològic d'una capa
topo_report <- function(m, label = "") {
  p <- overlap_pairs(m)
  ov <- if (nrow(p)) sum(mapply(function(i, j) {
    x <- suppressWarnings(st_intersection(st_geometry(m)[i], st_geometry(m)[j]))
    x <- polys(x)
    if (length(x)) sum(as.numeric(st_area(x))) else 0
  }, p[, 1], p[, 2])) else 0
  h <- interior_holes(st_union(m))
  ha <- as.numeric(st_area(h))
  data.frame(capa = label, n = nrow(m), parells_solapats = nrow(p),
             area_solapada_m2 = round(ov, 2), forats = length(ha),
             forats_gt_1m2 = sum(ha > 1), area_forats_m2 = round(sum(ha), 2))
}

# Correcció completa: solapaments i després forats (fins a max_hole_fill m2)
fix_topology <- function(m, max_hole_fill = Inf, verbose = TRUE) {
  stopifnot(all(st_is_valid(m)))
  g <- st_geometry(m)
  crs <- st_crs(m)
  n <- nrow(m)

  t0 <- Sys.time()
  tm <- function(msg) if (verbose) cat("  ", msg, "|", round(difftime(Sys.time(), t0, units = "mins"), 2), "min
")
  # 1. Solapaments ------------------------------------------------------------
  p <- overlap_pairs(m)
  if (verbose) cat("  parells solapats:", nrow(p), "\n")
  core <- g
  if (nrow(p)) {
    inter <- lapply(seq_len(nrow(p)), function(r) {
      x <- suppressWarnings(st_intersection(g[p[r, 1]], g[p[r, 2]]))
      polys(x)
    })
    inter <- do.call(c, inter)
    ov_reg <- st_cast(st_union(inter), "POLYGON")
    ov_reg <- ov_reg[as.numeric(st_area(ov_reg)) > 0]
    involved <- sort(unique(c(p)))
    hit <- st_intersects(g[involved], ov_reg)
    for (k in seq_along(involved)) {
      i <- involved[k]
      if (!length(hit[[k]])) next
      core[i] <- st_union(polys(st_difference(g[i], st_union(ov_reg[hit[[k]]]))))
    }
    if (verbose) cat("  regions solapades:", length(ov_reg), "\n")
    # candidats de cada regió: polígons originals que hi solapen
    cand <- st_relate(ov_reg, m, pattern = "2********")
    pieces <- lapply(seq_along(ov_reg), function(r) {
      ids <- cand[[r]]
      if (!length(ids)) ids <- st_nearest_feature(ov_reg[r], m)
      split_region(ov_reg[r], core[ids], ids)
    })
    tm("solapaments repartits")
    pieces <- do.call(rbind, pieces)
    for (i in unique(pieces$id)) {
      core[i] <- st_union(c(core[i], st_geometry(pieces)[pieces$id == i]))
    }
    tm("solapaments incorporats")
  }

  # 2. Forats -----------------------------------------------------------------
  h <- interior_holes(st_union(core))
  ha <- as.numeric(st_area(h))
  if (verbose) cat("  forats:", length(h), "| es deixen sense omplir (>", max_hole_fill, "m2):",
                   sum(ha > max_hole_fill), "\n")
  h <- h[ha <= max_hole_fill]
  tm("forats identificats")
  if (length(h)) {
    touch <- st_is_within_distance(h, st_sf(geometry = core), dist = 0.01)
    pieces <- lapply(seq_along(h), function(r) {
      ids <- touch[[r]]
      if (!length(ids)) ids <- st_nearest_feature(h[r], st_sf(geometry = core))
      split_region(h[r], core[ids], ids)
    })
    tm("forats repartits")
    pieces <- do.call(rbind, pieces)
    for (i in unique(pieces$id)) {
      core[i] <- st_union(c(core[i], st_geometry(pieces)[pieces$id == i]))
    }
    tm("forats incorporats")
  }
  core <- polys(st_make_valid(st_sfc(core, crs = crs)))
  st_geometry(m) <- core
  m
}

# Només la part lineal (sfc de MULTILINESTRING; buit si no n'hi ha)
lines_only <- function(x) {
  g <- st_geometry(x)
  keep <- function(gi) {
    if (inherits(gi, c("LINESTRING", "MULTILINESTRING"))) return(st_cast(st_sfc(gi), "MULTILINESTRING")[[1]])
    if (inherits(gi, "GEOMETRYCOLLECTION")) {
      p <- Filter(function(e) inherits(e, c("LINESTRING", "MULTILINESTRING")), unclass(gi))
      if (length(p)) return(st_cast(st_union(st_sfc(p)), "MULTILINESTRING")[[1]])
    }
    st_multilinestring()
  }
  out <- st_sfc(lapply(g, keep), crs = st_crs(g))
  out[!st_is_empty(out)]
}

# Municipis inclosos dins d'altres polígons (dibuixats a sobre sense retallar el
# gran). Després de fix_topology queden encara solapats. Regla: el municipi inclòs
# (el que té la major part de la seva àrea original coberta per altres) es queda
# tot el seu polígon original i es retalla dels altres.
fix_nested <- function(m, src, min_overlap = 1000, verbose = TRUE) {
  p <- overlap_pairs(m)
  if (!nrow(p)) return(m)
  g <- st_geometry(m)
  ov <- mapply(function(i, j) sum(as.numeric(st_area(polys(suppressWarnings(st_intersection(g[i], g[j])))))),
               p[, 1], p[, 2])
  p <- p[ov > min_overlap, , drop = FALSE]
  if (!nrow(p)) return(m)
  gs <- st_geometry(src)[match(m$cod, src$cod)]
  # fracció de cada polígon original coberta per altres polígons originals
  cover <- function(i) {
    o <- setdiff(st_relate(gs[i], gs, pattern = "2********")[[1]], i)
    if (!length(o)) return(0)
    sum(as.numeric(st_area(polys(st_intersection(gs[i], st_union(gs[o])))))) / as.numeric(st_area(gs[i]))
  }
  inv <- sort(unique(c(p)))
  fr <- setNames(vapply(inv, cover, numeric(1)), inv)
  nested <- inv[fr[as.character(inv)] > 0.9]
  if (verbose) cat("  municipis inclosos dins d'altres:", paste(m$cod[nested], m$name[nested], collapse = "; "), "\n")
  for (i in nested) {
    g[i] <- gs[i]
    oth <- setdiff(st_relate(gs[i], g, pattern = "2********")[[1]], i)
    for (j in oth) g[j] <- st_union(polys(st_difference(g[j], gs[i])))
  }
  st_geometry(m) <- polys(st_make_valid(g))
  m
}

# Validesa en coordenades geogràfiques (EPSG:4258). La partició ja es corregeix a
# 04c_fix_geographic_validity.R; aquí només es reparen amb GEOS (que reorganitza els
# anells sense moure coordenades, de manera que les fronteres compartides no canvien) les
# geometries que hagin quedat invàlides en el pla, i es comprova la validesa en s2.
fix_ll <- function(x, label = "") {
  old <- sf_use_s2()
  on.exit(suppressMessages(sf_use_s2(old)))
  suppressMessages(sf_use_s2(FALSE))
  b1 <- !st_is_valid(x)
  if (any(b1)) x[b1, ] <- polys(st_make_valid(x[b1, ], geos_method = "valid_linework"))
  suppressMessages(sf_use_s2(TRUE))
  b2 <- !s2::s2_is_valid(x)
  cat("  ", label, ": reparades", sum(b1), "(GEOS) | invàlides s2:", sum(b2),
      if (any(b2)) paste0("(", paste(x[[1]][b2], collapse = ", "), ")") else "", "
")
  x
}
