# 03b. Revisió manual dels codis del MINAP ------------------------------------------
# 1. Aplica les decisions de output/revisio/MINAP_revisio.xlsx (si existeix).
# 2. Comprova la coherència dels esdeveniments amb la vigència dels censos.
# 3. Torna a escriure l'Excel de revisió amb els casos pendents o dubtosos
#    (conservant-hi les decisions ja preses).
# 4. Desa intermediate/minap_codes.rds i output/MINAP_Variaciones_cod.xlsx

source("data-raw/00_config.R")
source(file.path(dir_pkg, "data-raw", "utils_review.R"))

dir_rev <- file.path(dir_out, "revisio")
dir.create(dir_rev, showWarnings = FALSE)
f_rev <- file.path(dir_rev, "MINAP_revisio.xlsx")
rev_cols <- c("rev_cod_muni", "rev_cod_other")

mi <- readRDS(file.path(dir_int, "minap_auto.rds"))
cens <- read_xlsx(file.path(dir_maps, "Municipis_Espanya_1842-2011.xlsx"), sheet = "fullcens") |>
  mutate(cod = as.integer(cod_mun), censo = as.integer(censo))
noms <- cens |> distinct(cod, mun) |> group_by(cod) |> summarise(mun = first(mun))
nom_de <- function(cod) noms$mun[match(cod, noms$cod)]
vs <- split(cens$censo[!is.na(cens$hogares)], cens$cod[!is.na(cens$hogares)])
yy <- sort(unique(cens$censo))
is_vig <- function(cod, yr) {
  !is.na(cod) & !is.na(yr) &
    mapply(function(a, b) b %in% vs[[as.character(a)]], cod, yr)
}

# 1. Revisions manuals ---------------------------------------------------------
mi$id <- mi$row_id
mi$revisat <- NA_character_
mi$ignora <- FALSE
rv <- read_review(f_rev, rev_cols)
if (!is.null(rv)) {
  rv <- rv[!is.na(rv$accio), ]
  m <- match(rv$id, mi$id)
  for (k in seq_len(nrow(rv))) {
    i <- m[k]
    if (is.na(i)) next
    mi$revisat[i] <- rv$accio[k]
    if (rv$accio[k] == "IGNORA") mi$ignora[i] <- TRUE
    if (rv$accio[k] == "CODI") {
      if (!is.na(rv$rev_cod_muni[k]))  { mi$cod_muni[i]  <- as.integer(rv$rev_cod_muni[k]);  mi$metode_muni[i]  <- "manual" }
      if (!is.na(rv$rev_cod_other[k])) { mi$cod_other[i] <- as.integer(rv$rev_cod_other[k]); mi$metode_other[i] <- "manual" }
    }
  }
  cat("Revisions aplicades:", nrow(rv), "\n"); print(table(rv$accio))
}

# 2. Coherència amb els censos -----------------------------------------------------
yr <- as.integer(format(mi$fecha, "%Y"))
yb <- vapply(yr, function(z) if (is.na(z) || z <= min(yy)) NA_integer_ else max(yy[yy < z]), integer(1))
ya <- vapply(yr, function(z) if (is.na(z) || z > max(yy)) NA_integer_ else min(yy[yy >= z]), integer(1))
d <- mi$change == "Disappears"
coh_list <- vector("list", nrow(mi))
add <- function(idx, msg) for (i in idx) coh_list[[i]] <<- c(coh_list[[i]], msg)
add(which(d & !is.na(yb) & !is_vig(mi$cod_muni, yb)), "muni no vigent al cens anterior")
add(which(d & !is.na(ya) & is_vig(mi$cod_muni, ya)), "muni encara vigent al cens posterior")
add(which(d & !is.na(ya) & !is_vig(mi$cod_other, ya)), "other no vigent al cens posterior")
n <- mi$change == "New"
add(which(n & !is.na(ya) & !is_vig(mi$cod_muni, ya)), "muni nou no vigent al cens posterior")
g <- mi$change %in% c("Grows", "PartialGrows")
add(which(g & !is.na(ya) & !is_vig(mi$cod_muni, ya)), "muni que creix no vigent al cens posterior")
add(which(g & !is.na(yb) & !is_vig(mi$cod_other, yb)), "other no vigent al cens anterior")
r <- mi$change %in% c("Reduces", "BorderChange")
add(which(r & !is.na(yb) & !is_vig(mi$cod_muni, yb)), "muni no vigent al cens anterior")
mi$coherencia <- vapply(coh_list, function(x) if (is.null(x)) NA_character_ else paste(x, collapse = "; "), "")

# 3. Excel de revisió ---------------------------------------------------------
fmt_cands <- function(m) {
  ifelse(grepl("^ambigu:", coalesce(m, "")),
         vapply(strsplit(sub("^ambigu:", "", m), ";"), function(cc)
           paste(paste(cc, nom_de(as.integer(cc))), collapse = " | "), ""), NA_character_)
}
terr <- mi$change != "Name Change"
periode <- is.na(mi$fecha) | (mi$fecha >= as.Date("1890-01-01") & mi$fecha <= as.Date("2006-12-31"))
segurs <- c("exacte", "sense_article", "revisio", "manual")
dubte_muni <- is.na(mi$cod_muni) | !coalesce(mi$metode_muni, "") %in% segurs
dubte_oth <- !is.na(mi$other_muni) &
  (is.na(mi$cod_other) | !coalesce(mi$metode_other, "") %in% segurs)

# Canvis respecte de la primera versió (v1) del codi automàtic
f_v1 <- file.path(dir_int, "minap_codes_v1.rds")
canvi <- rep(NA_character_, nrow(mi))
if (file.exists(f_v1)) {
  v1 <- readRDS(f_v1)
  m1 <- match(mi$row_id, v1$row_id)
  # només files que no heu revisat (les revisades ja tenen la vostra decisió)
  nr <- is.na(mi$revisat)
  dm <- nr & coalesce(v1$cod_muni[m1], -1L) != coalesce(mi$cod_muni, -1L)
  do <- nr & coalesce(v1$cod_other[m1], -1L) != coalesce(mi$cod_other, -1L)
  fmt <- function(a, b) paste0(coalesce(as.character(a), "NA"), " -> ", coalesce(as.character(b), "NA"),
                               " (", coalesce(nom_de(b), "?"), ")")
  canvi[dm] <- paste0("muni: ", fmt(v1$cod_muni[m1][dm], mi$cod_muni[dm]))
  canvi[do] <- paste0(ifelse(is.na(canvi[do]), "", paste0(canvi[do], " / ")),
                      "other: ", fmt(v1$cod_other[m1][do], mi$cod_other[do]))
  cat("Files amb codi diferent respecte de v1:", sum(!is.na(canvi)), "
")
}
# Les files ja revisades es mantenen sempre al fitxer (així no es perd cap decisió)
pend <- (terr & periode & (dubte_muni | dubte_oth | !is.na(mi$coherencia) | !is.na(canvi))) |
  !is.na(mi$revisat)

motiu <- character(nrow(mi))
motiu[dubte_muni] <- paste0("codi muni: ", coalesce(sub(":.*", "", mi$metode_muni[dubte_muni]), "sense codi"))
motiu[dubte_oth] <- paste0(motiu[dubte_oth], ifelse(motiu[dubte_oth] == "", "", " / "),
                           "codi other: ", coalesce(sub(":.*", "", mi$metode_other[dubte_oth]), "sense codi"))
has_coh <- !is.na(mi$coherencia)
motiu[has_coh] <- paste0(motiu[has_coh], ifelse(motiu[has_coh] == "", "", " / "), mi$coherencia[has_coh])

mm <- sub(":.*", "", coalesce(mi$metode_muni, "cap")); mo <- sub(":.*", "", coalesce(mi$metode_other, "cap"))
alta <- has_coh | mm %in% c("ambigu", "cap") | (!is.na(mi$other_muni) & mo %in% c("ambigu", "cap")) |
  grepl("incoherent", mm) | grepl("incoherent", mo)
mitj <- !alta & (mm == "aproximat" | mo == "aproximat")
prioritat <- ifelse(alta, "1-alta", ifelse(mitj, "2-mitjana", "3-baixa"))
rev_df <- mi[pend, ] |>
  transmute(id, prioritat = prioritat[pend], prov, muni, change, other_muni, date,
            motiu = motiu[pend], canvi_2a_passada = canvi[pend],
            cod_muni, nom_cod_muni = nom_de(cod_muni), metode_muni = sub(":.*", "", metode_muni),
            candidats_muni = fmt_cands(metode_muni),
            cod_other, nom_cod_other = nom_de(cod_other), metode_other = sub(":.*", "", metode_other),
            candidats_other = fmt_cands(metode_other))
rev_df <- rev_df[order(rev_df$prioritat, rev_df$prov, rev_df$muni), ]

instr <- c(
  "Aquest fitxer conté els esdeveniments territorials del MINAP (1890-2006) amb un codi INE dubtós",
  "o incoherent amb la vigència dels municipis als censos. Les columnes grogues són les vostres.",
  "",
  "accio (desplegable):",
  "   (buit)  = pendent; el procés fa servir la proposta automàtica (cod_muni / cod_other).",
  "   OK      = la proposta automàtica és correcta.",
  "   CODI    = la proposta no és correcta: escriviu el codi INE bo a rev_cod_muni i/o rev_cod_other",
  "             (només cal omplir la columna que canvia).",
  "   IGNORA  = l'esdeveniment és erroni o no és rellevant i no s'ha de fer servir.",
  "",
  "comentari: text lliure (opcional).",
  "",
  "Columnes informatives:",
  "   prioritat: 1-alta (sense codi, ambigu o incoherent amb els censos), 2-mitjana (nom aproximat),",
  "              3-baixa (trobat via canvi de nom i coherent): podeu començar per 1-alta.",
  "   canvi_2a_passada: codi que ha canviat respecte de la primera versió (després d'aplicar el que",
  "              s'ha après de les vostres revisions); convé mirar-ho encara que la fila ja estigui revisada.",
  "   motiu: per què la fila és aquí (mètode de concordança no exacte i/o incoherència amb els censos).",
  "   metode: exacte / sense_article / revisio (après de les vostres revisions) / parcial (un nom conté",
  "           l'altre) / aproximat (nom semblant) / canvi_nom (via canvis de nom del MINAP) /",
  "           altra_prov (mateix nom en una altra província) / ambigu / sense codi.",
  "           El sufix _incoherent indica que el codi no quadra amb la vigència als censos.",
  "   candidats_*: si és ambigu, codis possibles amb el nom del cens.",
  "",
  "Codis INE: 5 xifres (prov*1000 + municipi); els municipis desapareguts abans de 1900 tenen 6 xifres.",
  "No modifiqueu la columna id. El fitxer es pot tornar a generar: les decisions es conserven.")
write_review(rev_df, f_rev, rev_cols, instr, "Revisió dels codis INE del MINAP")
cat("Files a revisar:", nrow(rev_df), "-> ", f_rev, "\n")
print(table(rev_df$prioritat))

# 4. Resultat ----------------------------------------------------------------
saveRDS(mi, file.path(dir_int, "minap_codes.rds"))
writexl::write_xlsx(mi |> select(-row_id), file.path(dir_out, "MINAP_Variaciones_cod.xlsx"))
cat("Desat a", file.path(dir_out, "MINAP_Variaciones_cod.xlsx"), "\n")
