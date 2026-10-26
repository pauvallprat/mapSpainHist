# Fitxers de revisió en Excel ----------------------------------------------------
# Cada fitxer té una pestanya "Instruccions" i una pestanya "Revisio" amb:
#   - id: identificador estable de la fila (no s'ha de modificar)
#   - columnes informatives i la proposta automàtica
#   - accio: desplegable amb els valors admesos (buit = pendent de revisar)
#   - columnes rev_*: on s'escriu la correcció quan accio = "CODI"
#   - comentari: text lliure
# En regenerar el fitxer es conserven les decisions ja preses (per id).

suppressPackageStartupMessages(library(openxlsx))

review_actions <- c("OK", "CODI", "IGNORA")

read_review <- function(file, rev_cols) {
  if (!file.exists(file)) return(NULL)
  r <- read.xlsx(file, sheet = "Revisio")
  keep <- intersect(c("id", "accio", rev_cols, "comentari"), names(r))
  r <- r[, keep, drop = FALSE]
  r$accio <- toupper(trimws(r$accio))
  r$accio[!r$accio %in% review_actions] <- NA
  r
}

write_review <- function(df, file, rev_cols, instructions, title) {
  # df ha de tenir la columna id; s'hi afegeixen accio, rev_* i comentari
  old <- read_review(file, rev_cols)
  for (cc in c("accio", rev_cols, "comentari")) df[[cc]] <- NA
  if (!is.null(old)) {
    old <- old[!is.na(old$accio) | rowSums(!is.na(old[, -1, drop = FALSE])) > 0, , drop = FALSE]
    m <- match(df$id, old$id)
    for (cc in intersect(c("accio", rev_cols, "comentari"), names(old))) {
      df[[cc]][!is.na(m)] <- old[[cc]][m[!is.na(m)]]
    }
    # files ja revisades que ara no són pendents: es conserven al final del fitxer
    lost <- setdiff(old$id, df$id)
    df$estat <- "pendent"
    if (length(lost)) {
      old_full <- read.xlsx(file, sheet = "Revisio")
      keep <- old_full[as.character(old_full$id) %in% as.character(lost), , drop = FALSE]
      for (n in intersect(names(keep), names(df))) {
        keep[[n]] <- suppressWarnings(methods::as(keep[[n]], class(df[[n]])[1]))
      }
      keep$estat <- "ja no pendent (es conserva la decisió)"
      df <- dplyr::bind_rows(df, keep[, intersect(names(keep), names(df)), drop = FALSE])
    }
  }
  wb <- createWorkbook()
  addWorksheet(wb, "Instruccions")
  writeData(wb, "Instruccions", data.frame(x = c(title, "", instructions)), colNames = FALSE)
  setColWidths(wb, "Instruccions", 1, 120)
  addStyle(wb, "Instruccions", createStyle(textDecoration = "bold", fontSize = 13), rows = 1, cols = 1)

  addWorksheet(wb, "Revisio")
  writeData(wb, "Revisio", df, withFilter = TRUE)
  freezePane(wb, "Revisio", firstRow = TRUE)
  setColWidths(wb, "Revisio", seq_along(df), "auto")
  hdr <- createStyle(textDecoration = "bold", fgFill = "#DDDDDD", border = "bottom")
  addStyle(wb, "Revisio", hdr, rows = 1, cols = seq_along(df), gridExpand = TRUE)
  edit_cols <- match(c("accio", rev_cols, "comentari"), names(df))
  yellow <- createStyle(fgFill = "#FFF2CC")
  addStyle(wb, "Revisio", yellow, rows = seq_len(nrow(df)) + 1, cols = edit_cols,
           gridExpand = TRUE, stack = TRUE)
  addStyle(wb, "Revisio", createStyle(textDecoration = "bold", fgFill = "#FFD966", border = "bottom"),
           rows = 1, cols = edit_cols, gridExpand = TRUE)
  if (nrow(df)) {
    dataValidation(wb, "Revisio", cols = match("accio", names(df)), rows = seq_len(nrow(df)) + 1,
                   type = "list", value = sprintf('"%s"', paste(review_actions, collapse = ",")))
  }
  saveWorkbook(wb, file, overwrite = TRUE)
  invisible(df)
}
