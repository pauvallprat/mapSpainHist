# 05. Assignació dels àtoms a municipis per a cada cens ------------------------------
# Per a cada cens t es decideix a quin municipi pertany cada àtom:
#  - anys amb mapa (1900, 1930, 1950, 1970): el codi del mapa net
#  - anys intermedis: a partir del codi al mapa anterior (ca) i posterior (cb),
#    de la vigència dels municipis al cens (Excel) i de les dates del MINAP
#  - els casos sense informació es resolen amb el veí amb més frontera compartida
# Els casos dubtosos i els municipis vigents sense territori van a
# output/revisio/assignacio_revisio.xlsx; les decisions que s'hi prenguin
# s'apliquen en tornar a executar l'script.

source("data-raw/00_config.R")
source(file.path(dir_pkg, "data-raw", "utils_review.R"))

dir_rev <- file.path(dir_out, "revisio")
dir.create(dir_rev, showWarnings = FALSE)
f_rev <- file.path(dir_rev, "assignacio_revisio.xlsx")
min_km2_review <- 1   # grups més petits no es posen a l'Excel de revisió

atoms <- read_sf(file.path(dir_int, "atoms.gpkg"), "atoms")
A <- st_drop_geometry(atoms)
cc <- paste0("cod_", map_years)

cens <- read_xlsx(file.path(dir_maps, "Municipis_Espanya_1842-2011.xlsx"), sheet = "fullcens") |>
  mutate(cod = as.integer(cod_mun), censo = as.integer(censo))
V <- lapply(census_years, function(y) sort(unique(cens$cod[cens$censo == y & !is.na(cens$hogares)])))
names(V) <- census_years
nom_de <- function(cod) cens$mun[match(cod, cens$cod)]
condos <- sort(unique(unlist(A[, cc])[unlist(A[, cc]) >= 53000 & unlist(A[, cc]) < 100000]))

mi <- readRDS(file.path(dir_int, "minap_codes.rds")) |>
  filter(!ignora, change != "Name Change", !is.na(fecha), !is.na(cod_muni), !is.na(cod_other))
ev <- mi |> transmute(a = pmin(cod_muni, cod_other), b = pmax(cod_muni, cod_other), fecha, change) |>
  distinct()

# Adjacència entre àtoms (comparteixen un tram de frontera) ---------------------------
cat("Calculant adjacència...\n")
adj <- st_relate(atoms, atoms, pattern = "F***1****")
shared_len <- function(i, js) vapply(js, function(j) {
  x <- suppressWarnings(st_intersection(st_geometry(atoms)[i], st_geometry(atoms)[j]))
  sum(as.numeric(st_length(x)))
}, numeric(1))
# Resol iterativament els àtoms amb codi NA amb el codi del veí (resolt) amb més frontera
fill_by_neighbours <- function(code, allowed = NULL) {
  for (it in 1:50) {
    na <- which(is.na(code))
    if (!length(na)) break
    changed <- FALSE
    for (i in na) {
      js <- adj[[i]][!is.na(code[adj[[i]]])]
      if (!is.null(allowed)) js <- js[code[js] %in% allowed]
      if (!length(js)) next
      code[i] <- code[js][which.max(shared_len(i, js))]
      changed <- TRUE
    }
    if (!changed) break
  }
  code
}

# 1. Forats grans dels mapes (codi NA en un any amb mapa) ---------------------------
for (k in seq_along(map_years)) {
  y <- map_years[k]; col <- cc[k]
  na <- which(is.na(A[[col]]))
  if (!length(na)) next
  valid <- unique(na.omit(A[[col]]))
  # informació temporal: el codi en els mapes més propers, si existeix aquest any
  ord <- order(abs(map_years - y))[-1]
  for (i in na) {
    for (o in ord) {
      c0 <- A[[cc[o]]][i]
      if (!is.na(c0) && c0 %in% valid) { A[[col]][i] <- c0; break }
    }
  }
  A[[col]] <- fill_by_neighbours(A[[col]])
  cat(y, ": forats grans resolts:", length(na), "| encara NA:", sum(is.na(A[[col]])), "\n")
}

# 2. Assignació per cens ---------------------------------------------------------
decide <- function(t) {
  tt <- as.character(t)
  dt <- census_dates[[tt]]
  Vt <- c(V[[tt]], condos)
  if (t %in% map_years) {
    return(data.frame(atom = A$atom, cod = A[[paste0("cod_", t)]], regla = "mapa"))
  }
  ia <- max(which(map_dates <= dt)); ib <- min(which(map_dates > dt))
  ca <- A[[cc[ia]]]; cb <- A[[cc[ib]]]
  da <- map_dates[[ia]]; db <- map_dates[[ib]]
  va <- ca %in% Vt; vb <- cb %in% Vt
  cod <- rep(NA_integer_, nrow(A)); regla <- rep(NA_character_, nrow(A))
  s <- ca == cb & va;            cod[s] <- ca[s]; regla[s] <- "igual"
  s <- is.na(regla) & va & !vb;  cod[s] <- ca[s]; regla[s] <- "nomes_anterior_vigent"
  s <- is.na(regla) & vb & !va;  cod[s] <- cb[s]; regla[s] <- "nomes_posterior_vigent"
  # tots dos vigents:
  #  - ca desapareix abans del mapa posterior -> encara existia en t: es queda ca
  #  - cb es crea després del mapa anterior (i abans de t) -> cb
  #  - tots dos existeixen als dos mapes (canvi de límit): data del MINAP o mapa més proper
  codes_a <- unique(A[[cc[ia]]]); codes_b <- unique(A[[cc[ib]]])
  s <- which(is.na(regla) & va & vb & !ca %in% codes_b)
  cod[s] <- ca[s]; regla[s] <- "anterior_encara_existeix"
  s <- which(is.na(regla) & va & vb & !cb %in% codes_a)
  cod[s] <- cb[s]; regla[s] <- "posterior_ja_creat"
  both <- which(is.na(regla) & va & vb)
  if (length(both)) {
    pr <- unique(data.frame(ca = ca[both], cb = cb[both]))
    pr$fecha <- as.Date(vapply(seq_len(nrow(pr)), function(r) {
      e <- ev$fecha[ev$a == min(pr$ca[r], pr$cb[r]) & ev$b == max(pr$ca[r], pr$cb[r]) &
                    ev$fecha > da & ev$fecha <= db]
      if (length(e)) as.numeric(min(e)) else NA_real_
    }, numeric(1)), origin = "1970-01-01")
    m <- match(paste(ca[both], cb[both]), paste(pr$ca, pr$cb))
    f <- pr$fecha[m]
    # després de 1970 es manté el mapa de 1970 si no hi ha cap canvi datat (les diferències
    # amb el SIANE 2005 són de traçat entre fonts); abans, el mapa més proper
    near_a <- if (t > 1970) TRUE else as.numeric(dt - da) < as.numeric(db - dt)
    proper <- if (near_a) ca[both] else cb[both]   # near_a és un sol valor: no fer servir ifelse()
    cod[both] <- ifelse(!is.na(f), ifelse(f <= dt, cb[both], ca[both]), proper)
    regla[both] <- ifelse(!is.na(f), "minap_data", "sense_data_mapa_proper")
  }
  # cap dels dos vigent: municipis relacionats al MINAP vigents en t
  none <- which(is.na(regla))
  for (i in none) {
    rel <- ev[(ev$a %in% c(ca[i], cb[i]) | ev$b %in% c(ca[i], cb[i])) & ev$fecha > da & ev$fecha <= db, ]
    cand <- setdiff(intersect(unique(c(rel$a, rel$b)), Vt), c(ca[i], cb[i]))
    if (length(cand) == 1) { cod[i] <- cand; regla[i] <- "minap_relacionat" }
  }
  na <- is.na(cod)
  cod <- fill_by_neighbours(cod, allowed = Vt)
  regla[na] <- "veí"
  data.frame(atom = A$atom, cod = cod, regla = regla, ca = ca, cb = cb)
}

res <- lapply(census_years, function(t) { cat("Cens", t, "\n"); decide(t) })
names(res) <- census_years

# Correccions manuals (data-raw/correccions_manuals.csv) ------------------------------
# Cada fila assigna cod_assignat als àtoms que tenen cod_1 al mapa mapa_1 (i, si s'indica,
# cod_2 al mapa mapa_2) en els censos entre cens_inici i cens_fi.
cm <- read.csv(file.path(dir_pkg, "data-raw", "correccions_manuals.csv"), encoding = "UTF-8")
for (k in seq_len(nrow(cm))) {
  sel <- A[[paste0("cod_", cm$mapa_1[k])]] == cm$cod_1[k]
  if (!is.na(cm$mapa_2[k])) sel <- sel & A[[paste0("cod_", cm$mapa_2[k])]] == cm$cod_2[k]
  sel <- A$atom[which(sel)]
  for (t in census_years[census_years >= cm$cens_inici[k] & census_years <= cm$cens_fi[k]]) {
    r <- res[[as.character(t)]]
    s <- r$atom %in% sel
    r$cod[s] <- cm$cod_assignat[k]; r$regla[s] <- "correccio_manual"
    res[[as.character(t)]] <- r
  }
  cat("Correcció manual:", cm$comentari[k], "| àtoms:", length(sel), "\n")
}

# Territoris dibuixats a mà (data-raw/manual/territoris_manuals.gpkg) ----------------
f_man <- file.path(dir_pkg, "data-raw", "manual", "territoris_manuals.gpkg")
if (file.exists(f_man)) {
  # els àtoms es seleccionen per contenció: un mateix polígon pot tenir diverses files
  # (codis diferents segons el cens)
  man <- st_transform(read_manual_territories(f_man), crs_work)
  pts <- suppressWarnings(st_point_on_surface(st_geometry(atoms)))
  for (k in seq_len(nrow(man))) {
    sel <- atoms$atom[lengths(st_intersects(pts, st_geometry(man)[k])) > 0]
    for (t in census_years[census_years >= man$cens_inici[k] & census_years <= man$cens_fi[k]]) {
      r <- res[[as.character(t)]]
      s <- r$atom %in% sel
      r$cod[s] <- as.integer(man$cod_ine[k]); r$regla[s] <- "territori_manual"
      res[[as.character(t)]] <- r
    }
    cat("Territori manual:", man$cod_ine[k], man$cens_inici[k], "-", man$cens_fi[k], "| àtoms:", length(sel), "\n")
  }
}

# Parts desconnectades (data-raw/parts_desconnectades.csv) ---------------------------
# Les parts (components connexos) del municipi cod que no toquen cap dels municipis de
# veins passen a cod_assignat.
f_pd <- file.path(dir_pkg, "data-raw", "parts_desconnectades.csv")
if (file.exists(f_pd)) {
  pd <- read.csv(f_pd, encoding = "UTF-8", colClasses = c(veins = "character"))
  g_at <- st_geometry(atoms)
  for (k in seq_len(nrow(pd))) {
    veins <- as.integer(strsplit(pd$veins[k], ";")[[1]])
    for (t in census_years[census_years >= pd$cens_inici[k] & census_years <= pd$cens_fi[k]]) {
      r <- res[[as.character(t)]]
      ids <- r$atom[r$cod == pd$cod[k]]
      if (!length(ids)) next
      g <- g_at[match(ids, atoms$atom)]
      comp <- st_cast(st_union(g), "POLYGON")
      ac <- vapply(st_intersects(suppressWarnings(st_point_on_surface(g)), comp),
                   function(j) if (length(j)) j[1] else NA_integer_, integer(1))
      vg <- st_union(g_at[match(r$atom[r$cod %in% veins], atoms$atom)])
      toca <- lengths(st_intersects(comp, vg)) > 0
      mou <- ids[!toca[ac]]
      s <- r$atom %in% mou
      r$cod[s] <- pd$cod_assignat[k]; r$regla[s] <- "part_desconnectada"
      res[[as.character(t)]] <- r
      if (t == pd$cens_inici[k]) cat("Parts desconnectades:", pd$cod[k], "| parts:", length(comp),
                                     "| es mantenen:", sum(toca), "| àtoms a", pd$cod_assignat[k], ":", length(mou), "\n")
    }
  }
}

# 3. Revisions manuals ------------------------------------------------------------
# id de revisió de casos dubtosos: "any|ca|cb" (afecta tots els àtoms amb aquest parell)
rv <- read_review(f_rev, c("rev_cod"))
if (!is.null(rv)) {
  rv <- rv[!is.na(rv$accio) & rv$accio == "CODI" & !is.na(rv$rev_cod), ]
  for (k in seq_len(nrow(rv))) {
    p <- strsplit(rv$id[k], "\\|")[[1]]
    if (p[1] == "sense_territori") next
    r <- res[[p[1]]]
    s <- paste(r$ca, r$cb) == paste(p[2], p[3])
    r$cod[s] <- as.integer(rv$rev_cod[k]); r$regla[s] <- "manual"
    res[[p[1]]] <- r
  }
}

# 4. Diagnòstic i fitxer de revisió --------------------------------------------------
area <- as.numeric(st_area(atoms)) / 1e6
rows <- list(); diag <- list()
for (t in census_years) {
  tt <- as.character(t); r <- res[[tt]]
  Vt <- V[[tt]]
  got <- unique(r$cod)
  sense <- setdiff(Vt, got)
  extra <- setdiff(got, c(Vt, condos))
  diag[[tt]] <- data.frame(cens = t, municipis_cens = length(Vt), municipis_mapa = length(intersect(got, Vt)),
                           vigents_sense_territori = length(sense), codis_no_vigents = length(extra),
                           atoms_sense_codi = sum(is.na(r$cod)),
                           km2_sense_data = round(sum(area[r$regla %in% "sense_data_mapa_proper"]), 1),
                           km2_veí = round(sum(area[r$regla %in% "veí"]), 1))
  dub <- r[r$regla %in% c("sense_data_mapa_proper", "veí", "minap_relacionat"), ]
  # després de 1970 els canvis de límit sense data són diferències de traçat: es manté 1970
  if (t > 1970) dub <- dub[dub$regla != "sense_data_mapa_proper", ]
  if (nrow(dub)) {
    dub$km2 <- area[match(dub$atom, A$atom)]
    g <- dub |> group_by(ca, cb, cod, regla) |> summarise(km2 = round(sum(km2), 3), n_atoms = n(), .groups = "drop")
    # només els grups rellevants (els petits són diferències de traçat entre fonts)
    g <- g[g$km2 >= min_km2_review, ]
    rows[[length(rows) + 1]] <- g |> transmute(
      id = paste(t, ca, cb, sep = "|"), tipus = "assignacio_dubtosa", cens = t, regla,
      cod_anterior = ca, nom_anterior = nom_de(ca), cod_posterior = cb, nom_posterior = nom_de(cb),
      cod_proposat = cod, nom_proposat = nom_de(cod), km2, n_atoms)
  }
  if (length(sense)) {
    rows[[length(rows) + 1]] <- data.frame(
      id = paste("sense_territori", t, sense, sep = "|"), tipus = "vigent_sense_territori", cens = t,
      regla = NA, cod_anterior = NA, nom_anterior = NA, cod_posterior = NA, nom_posterior = NA,
      cod_proposat = sense, nom_proposat = nom_de(sense), km2 = 0, n_atoms = 0)
  }
}
diag <- do.call(rbind, diag); print(diag)
rev_df <- do.call(rbind, rows)
rev_df <- rev_df[order(rev_df$tipus != "vigent_sense_territori", -rev_df$km2), ]
instr <- c(
  "Casos de l'assignació de territori a cada cens que convé revisar. Les columnes grogues són les vostres.",
  "",
  "tipus = assignacio_dubtosa: una zona que al mapa anterior era de cod_anterior i al posterior de",
  "   cod_posterior s'ha assignat a cod_proposat per a aquest cens, segons la regla:",
  "     sense_data_mapa_proper: tots dos municipis existien als dos mapes i el MINAP no dona la data del",
  "                             canvi de límit; s'ha triat el mapa més proper en el temps. Sovint són",
  "                             diferències de traçat entre fonts (p. ex. Catalunya al mapa de 1970 vs SIANE).",
  "     minap_relacionat: cap dels dos era vigent; s'ha triat el municipi relacionat al MINAP.",
  "     veí: no hi havia informació; s'ha assignat al veí amb més frontera compartida.",
  "   accio: OK = correcte; CODI = escriviu a rev_cod el codi INE correcte per a tota la zona; IGNORA = com OK.",
  "",
  "tipus = vigent_sense_territori: municipi vigent al cens però que no té cap zona assignada (va existir",
  "   només entre dos mapes, o hi ha un problema de codis). Indiqueu a comentari d'on s'ha de treure el",
  "   territori (p. ex. 'part nord de 12345'); aquests casos s'han de resoldre geomètricament.",
  "",
  "Només hi surten els grups d'1 km2 o més; els més petits s'han resolt automàticament.",
  "No modifiqueu la columna id. Les decisions es conserven si el fitxer es torna a generar.")
if (!is.null(rev_df) && nrow(rev_df)) {
  write_review(rev_df, f_rev, "rev_cod", instr, "Revisió de l'assignació de territori per cens")
  cat("Files a revisar:", nrow(rev_df), "->", f_rev, "\n")
}

saveRDS(list(atoms = A, res = res, diag = diag), file.path(dir_int, "assign.rds"))
