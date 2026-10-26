# 03. Codis INE per al MINAP -----------------------------------------------------
# Afegeix el codi INE (cod_muni, cod_other) a cada registre de
# MINAP_Variaciones_processing.xlsx (full Sheet1). L'original no es modifica:
# la proposta automàtica es desa a intermediate/minap_auto.rds i 03b_minap_review.R
# hi aplica les revisions manuals.
#
# Per a cada nom es proven diversos mètodes en cascada. De cada mètode només
# s'accepten els candidats coherents amb la vigència dels censos (p. ex. un
# municipi que desapareix ha de ser vigent al darrer cens anterior a la data),
# excepte les decisions manuals sobre el mateix esdeveniment (mateix nom i data),
# que s'apliquen directament (p. ex. a la fila mirall d'una fila revisada).
#   revisio      codis assignats a mà a output/revisio/MINAP_revisio.xlsx per al
#                mateix nom i província (s'apliquen a tots els registres)
#   exacte       nom normalitzat idèntic
#   sense_article  idèntic sense l'article inicial (La Parra = Parra)
#   canvi_nom    via els canvis de nom del MINAP
#   parcial      un nom conté l'altre (Carrascal del Duero = Carrascal)
#   aproximat    nom semblant (Jaro-Winkler)
#   altra_prov   nom idèntic en una altra província (registre mal ubicat)
# Els parèntesis s'interpreten: "(Burgos)" = província; "(Act: X)" / "(Ant: X)"
# = nom alternatiu; altres (localitats, partits) s'ignoren.

source("data-raw/00_config.R")
suppressPackageStartupMessages({library(stringi); library(stringdist); library(tidyr); library(openxlsx)})

# Normalització de noms -------------------------------------------------------
arts <- "(el|la|los|las|l|els|les|lo|o|a|os|as|es|sa|ses|s)"
ascii <- function(x) tolower(stri_trans_general(x, "Latin-ASCII"))
norm_name <- function(x) {
  x <- ascii(trimws(x))
  x <- gsub(",?\\s*que se extingue.*$", "", x)
  x <- gsub("\\.+$", "", x)
  x <- sub(paste0("^(.*),\\s*", sub("\\)$", "|l'|s')$", arts)), "\\2 \\1", x)
  x <- gsub("[^a-z0-9]+", " ", x)
  trimws(gsub("\\s+", " ", x))
}
strip_art <- function(k) sub(paste0("^", arts, " "), "", k)

# Informació d'un nom: variants normalitzades i província indicada entre parèntesis
name_info <- function(x, prov_lookup = NULL) {
  if (is.na(x) || !nzchar(x)) return(list(keys = character(0), prov = NA_integer_))
  inner <- regmatches(x, gregexpr("\\(([^)]*)\\)", x))[[1]]
  inner <- gsub("^\\(|\\)$", "", inner)
  base <- trimws(gsub("\\s*\\([^)]*\\)", "", x))
  # "Coruña (A)": l'article entre parèntesis forma part del nom
  art_in <- inner[grepl(paste0("^", arts, "$"), ascii(inner))]
  if (length(art_in)) base <- paste0(base, ", ", art_in[1])
  extra <- sub("^(act|ant)[.:]?\\s*", "", inner[grepl("^(act|ant)[.:]", ascii(inner))])
  prov <- NA_integer_
  if (!is.null(prov_lookup)) {
    for (s in inner) {
      for (v in c(norm_name(s), norm_name(unlist(strsplit(s, "/"))))) {
        if (v %in% names(prov_lookup)) { prov <- prov_lookup[[v]]; break }
      }
      if (!is.na(prov)) break
    }
  }
  parts <- c(base, extra, unlist(strsplit(base, "\\s*/\\s*")), unlist(strsplit(base, "\\s+-\\s+")))
  keys <- unique(norm_name(parts[nzchar(parts)]))
  list(keys = keys[nzchar(keys)], prov = prov)
}

# Censos i dates ----------------------------------------------------------------
cens <- read_xlsx(file.path(dir_maps, "Municipis_Espanya_1842-2011.xlsx"), sheet = "fullcens") |>
  mutate(cod = as.integer(cod_mun), censo = as.integer(censo))
prov_code <- function(cod) ifelse(cod >= 100000, cod %/% 10000, cod %/% 1000)
cens$cpro <- prov_code(cens$cod)
cens_years_all <- sort(unique(cens$censo))
cens_date <- function(y) {
  d <- as.Date(paste0(y, "-12-31"))
  d[y %in% c(1981, 1991)] <- as.Date(paste0(y[y %in% c(1981, 1991)], "-03-01"))
  d[y %in% c(2001, 2011)] <- as.Date(paste0(y[y %in% c(2001, 2011)], "-11-01"))
  d
}
cdates <- cens_date(cens_years_all)
vset <- split(cens$censo[!is.na(cens$hogares)], cens$cod[!is.na(cens$hogares)])
is_vig1 <- function(cod, yr) yr %in% vset[[as.character(cod)]]

# Províncies: nom normalitzat (Excel i MINAP) -> codi
prov_tab <- cens |> distinct(cpro, prov)
prov_alias <- c("alava" = 1, "araba alava" = 1, "araba" = 1, "alacant alicante" = 3,
                "alicante alacant" = 3, "alicante" = 3, "alacant" = 3, "avila" = 5,
                "illes balears" = 7, "balears illes" = 7, "baleares" = 7, "castello castellon" = 12,
                "castellon castello" = 12, "castellon" = 12, "castello" = 12, "a coruna" = 15,
                "coruna a" = 15, "la coruna" = 15, "guipuzcoa" = 20, "gipuzkoa" = 20, "las palmas" = 35,
                "palmas las" = 35, "la rioja" = 26, "rioja la" = 26, "rioja" = 26,
                "valencia valencia" = 46, "valencia" = 46, "vizcaya" = 48, "bizkaia" = 48,
                "gerona" = 17, "lerida" = 25, "orense" = 32)
prov_lookup <- c(setNames(prov_tab$cpro, norm_name(prov_tab$prov)), prov_alias)
prov_lookup <- prov_lookup[!duplicated(names(prov_lookup))]
prov_to_code <- function(p) {
  vapply(p, function(s) {
    k <- c(norm_name(s), norm_name(unlist(strsplit(s, "/"))))
    k <- k[k %in% names(prov_lookup)]
    if (length(k)) as.integer(prov_lookup[[k[1]]]) else NA_integer_
  }, integer(1), USE.NAMES = FALSE)
}

# Taula d'àlies (cpro, cod, clau) ------------------------------------------------
alias <- list(cens |> distinct(cpro, cod, nom = mun) |> mutate(font = "censos"))
mx <- file.path(dir_maps, "municipios_1900-2000.xlsx")
for (s in excel_sheets(mx)) {
  d <- read_xlsx(mx, sheet = s)
  alias[[s]] <- d |> transmute(cod = as.integer(cod_mun), nom = mun) |>
    mutate(cpro = prov_code(cod), font = s)
}
for (y in c(1900, 1930, 1950, 1970)) {
  d <- read_sf(file.path(dir_int, "sources.gpkg"), paste0("src_", y)) |> st_drop_geometry()
  alias[[paste0("map", y)]] <- d |> transmute(cod, nom = name, cpro = prov_code(cod), font = paste0("mapa", y))
}
d <- read_sf(file.path(dir_int, "sources.gpkg"), "src_2005") |> st_drop_geometry()
alias$siane <- d |> transmute(cod, nom = name, cpro = prov_code(cod), font = "siane2005")
if (requireNamespace("LAU2boundaries4spain", quietly = TRUE)) {
  d <- st_drop_geometry(LAU2boundaries4spain::municipios_2002)
  alias$lau2 <- d |> transmute(cod = as.integer(INECodMuni), nom = NombreMuni,
                               cpro = prov_code(cod), font = "lau2002")
}
alias <- bind_rows(alias) |> filter(!is.na(nom), !is.na(cod), cod < 53000 | cod >= 100000) |>
  distinct(cpro, cod, nom)
alias <- alias |> rowwise() |> reframe(cpro, cod, key = name_info(nom)$keys) |>
  distinct(cpro, cod, key)
alias$key0 <- strip_art(alias$key)
idx_exact <- split(alias$cod, paste(alias$cpro, alias$key))
idx_noart <- split(alias$cod, paste(alias$cpro, alias$key0))
idx_any   <- split(alias$cod, alias$key0)
alias_by_prov <- split(alias, alias$cpro)

# MINAP ------------------------------------------------------------------------
mi <- read_xlsx(file.path(dir_maps, "MINAP_Variaciones_processing.xlsx"), sheet = "Sheet1")
mi <- mi |> mutate(
  row_id = row_number(),
  date = as.character(date),
  fecha = coalesce(as.Date(date, "%d/%m/%Y"), as.Date(substr(date, 1, 10), "%Y-%m-%d"),
                   as.Date(suppressWarnings(as.numeric(date)), origin = "1899-12-30")),
  cpro = prov_to_code(prov))
cat("MINAP: registres", nrow(mi), "| sense província:", sum(is.na(mi$cpro)),
    "| sense data:", sum(is.na(mi$fecha)), "\n")

# Àlies pels canvis de nom (components connexos dins la província) -------------------
nc <- mi |> filter(change == "Name Change", !is.na(other_muni)) |>
  transmute(cpro, a = norm_name(muni), b = norm_name(other_muni))
nc_old <- mi |> filter(!is.na(other_muni_old)) |>
  transmute(cpro, a = norm_name(other_muni), b = norm_name(other_muni_old))
edges <- bind_rows(nc, nc_old) |> filter(a != b) |> distinct()
comp_id <- new.env()
find <- function(x) { while (!is.null(comp_id[[x]]) && comp_id[[x]] != x) x <- comp_id[[x]]; x }
for (i in seq_len(nrow(edges))) {
  a <- paste(edges$cpro[i], edges$a[i]); b <- paste(edges$cpro[i], edges$b[i])
  if (is.null(comp_id[[a]])) comp_id[[a]] <- a
  if (is.null(comp_id[[b]])) comp_id[[b]] <- b
  ra <- find(a); rb <- find(b); if (ra != rb) comp_id[[ra]] <- rb
}
nodes <- ls(comp_id)
comp <- data.frame(node = nodes, root = vapply(nodes, find, ""), row.names = NULL)
comp$key <- sub("^[0-9]+ ", "", comp$node)

# Codis après de les revisions manuals (mateix nom i província) -------------------
f_rev <- file.path(dir_out, "revisio", "MINAP_revisio.xlsx")
learned <- list(); learned_ev <- list()
# Paràmetres per avaluar variants (per defecte: tot activat)
use_learned <- Sys.getenv("MINAP_LEARN", "1") == "1"
method_order <- strsplit(Sys.getenv("MINAP_ORDER", ""), ",")[[1]]
only_rows <- as.integer(strsplit(Sys.getenv("MINAP_ROWS", ""), ",")[[1]])
out_file <- Sys.getenv("MINAP_OUT", file.path(dir_int, "minap_auto.rds"))
if (use_learned && file.exists(f_rev)) {
  rv <- read.xlsx(f_rev, sheet = "Revisio")
  rv <- rv[toupper(trimws(coalesce(rv$accio, ""))) %in% c("OK", "CODI"), ]
  cpr <- prov_to_code(rv$prov)
  side <- function(nom, prop, rev) {
    code <- suppressWarnings(as.integer(ifelse(!is.na(rev), rev, prop)))
    data.frame(nom = nom, cod = code)
  }
  L <- rbind(cbind(side(rv$muni, rv$cod_muni, rv$rev_cod_muni), cpro = cpr, date = rv$date),
             cbind(side(rv$other_muni, rv$cod_other, rv$rev_cod_other), cpro = cpr, date = rv$date))
  L <- L[!is.na(L$nom) & !is.na(L$cod), ]
  for (k in seq_len(nrow(L))) {
    ni <- name_info(L$nom[k], prov_lookup)
    cp <- if (is.na(ni$prov)) L$cpro[k] else ni$prov
    for (key in unique(c(ni$keys, strip_art(ni$keys)))) {
      nm <- paste(cp, key)
      learned[[nm]] <- unique(c(learned[[nm]], L$cod[k]))
      # mateix esdeveniment (mateix nom i data): la decisió s'aplica directament
      ne <- paste(cp, key, L$date[k])
      learned_ev[[ne]] <- unique(c(learned_ev[[ne]], L$cod[k]))
    }
  }
  cat("Noms apresos de la revisió manual:", length(learned), "\n")
}

# Coherència d'un candidat amb la vigència --------------------------------------------
# when: "before" (vigent al darrer cens anterior a la data) o "after" (vigent al primer
# cens posterior)
expected <- function(role, change) {
  if (role == "self") switch(change, Disappears = "before", New = "after", Grows = "after",
                             PartialGrows = "after", Reduces = "before", BorderChange = "before", NA)
  else switch(change, Disappears = "after", New = "before", Grows = "before",
              PartialGrows = "before", Reduces = "after", BorderChange = "after", NA)
}
coherent <- function(cands, fecha, when) {
  if (is.na(when) || is.na(fecha) || !length(cands)) return(rep(TRUE, length(cands)))
  yr <- if (when == "before") cens_years_all[max(c(0, which(cdates < fecha)))]
        else cens_years_all[min(c(Inf, which(cdates >= fecha)))]
  if (!length(yr) || is.na(yr)) return(rep(TRUE, length(cands)))
  vapply(cands, is_vig1, logical(1), yr = yr)
}

# Concordança d'un nom --------------------------------------------------------------
match_one <- function(nom, cpro0, fecha, change, role, date0 = NA) {
  ni <- name_info(nom, prov_lookup)
  if (!length(ni$keys)) return(c(NA, NA))
  cp <- if (is.na(ni$prov)) cpro0 else ni$prov
  keys <- ni$keys; keys0 <- unique(strip_art(keys))
  when <- expected(role, change)
  methods <- list(
    revisio = function() unlist(learned[paste(cp, c(keys, keys0))]),
    exacte = function() unlist(idx_exact[paste(cp, keys)]),
    sense_article = function() unlist(idx_noart[paste(cp, keys0)]),
    canvi_nom = function() {
      r <- comp$root[comp$node %in% paste(cp, keys)]
      ks <- comp$key[comp$root %in% r]
      unlist(idx_exact[paste(cp, ks)])
    },
    parcial = function() {
      a <- alias_by_prov[[as.character(cp)]]
      if (is.null(a)) return(integer(0))
      hit <- vapply(a$key0, function(k) any(startsWith(paste0(keys0, " "), paste0(k, " ")) |
                                            startsWith(paste0(k, " "), paste0(keys0, " "))), logical(1))
      a$cod[hit]
    },
    aproximat = function() {
      a <- alias_by_prov[[as.character(cp)]]
      if (is.null(a)) return(integer(0))
      dd <- stringdist(keys0[1], a$key0, method = "jw", p = 0.1)
      if (min(dd) <= 0.08) a$cod[dd <= min(dd) + 1e-9] else integer(0)
    },
    altra_prov = function() {
      c1 <- unique(unlist(idx_any[keys0]))
      c1[prov_code(c1) != cp]
    })
  if (length(method_order)) methods <- methods[intersect(method_order, names(methods))]
  # decisió manual sobre el mateix esdeveniment (fila mirall d'una de revisada)
  ev_hit <- unique(unlist(learned_ev[paste(cp, c(keys, keys0), date0)]))
  if (length(ev_hit) == 1) return(c(ev_hit, "revisio"))
  fallback <- NULL; amb <- NULL; any_inprov <- FALSE
  for (m in names(methods)) {
    # altra_prov només si a la pròpia província no hi ha cap candidat
    if (m == "altra_prov" && any_inprov) next
    cc <- unique(methods[[m]]())
    cc <- cc[!is.na(cc)]
    if (!length(cc)) next
    if (m != "altra_prov") any_inprov <- TRUE

    ok <- cc[coherent(cc, fecha, when)]
    if (length(ok) == 1) return(c(ok, m))
    if (length(ok) > 1 && is.null(amb)) amb <- c(NA, paste0("ambigu:", paste(sort(ok), collapse = ";")))
    # un candidat incoherent amb la vigència només s'accepta com a últim recurs si el
    # nom és idèntic (p. ex. el codi continua després d'una fusió)
    if (!length(ok) && is.null(fallback) && length(cc) == 1 &&
        m %in% c("revisio", "exacte", "sense_article")) fallback <- c(cc, paste0(m, "_incoherent"))
  }
  if (!is.null(amb)) return(amb)
  if (!is.null(fallback)) return(fallback)
  c(NA, NA)
}

run <- function(noms, role) {
  out <- matrix(NA_character_, nrow(mi), 2)
  rows <- if (length(only_rows)) which(mi$row_id %in% only_rows) else seq_len(nrow(mi))
  for (i in rows) {
    if (is.na(noms[i])) next
    out[i, ] <- match_one(noms[i], mi$cpro[i], mi$fecha[i], mi$change[i], role, mi$date[i])
  }
  out
}
t0 <- Sys.time()
r_self <- run(mi$muni, "self")
r_other <- run(mi$other_muni, "other")
cat("temps:", round(difftime(Sys.time(), t0, units = "mins"), 1), "min\n")

mi_out <- mi |> mutate(cod_muni = as.integer(r_self[, 1]), metode_muni = r_self[, 2],
                       cod_other = as.integer(r_other[, 1]), metode_other = r_other[, 2])

# Resum ------------------------------------------------------------------------
summ <- function(m) table(ifelse(is.na(m), "sense_match", sub(":.*", "", m)))
has_other <- !is.na(mi$other_muni)
cat("\nmuni:\n"); print(summ(mi_out$metode_muni))
cat("\nother_muni:\n"); print(summ(mi_out$metode_other[has_other]))

saveRDS(mi_out, out_file)
