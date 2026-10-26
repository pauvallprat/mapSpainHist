# 07. Comprovacions d'agregació i figures ---------------------------------------------
# - Agrega cada cens per província: no hi ha d'haver forats interiors (excepte
#   enclavaments reals d'una altra província, p. ex. Treviño dins d'Àlaba).
# - Figures de control a output/figures/.

source("data-raw/00_config.R")
source(file.path(dir_pkg, "data-raw", "utils_topology.R"))

gpkg <- file.path(dir_out, "mapSpainHist.gpkg")
dir_fig <- file.path(dir_out, "figures"); dir.create(dir_fig, showWarnings = FALSE)

res <- list()
censos <- read_sf(gpkg, "censos")
for (t in census_years) {
  m <- st_transform(read_sf(gpkg, paste0("muni_", t)), crs_work)
  ct <- censos[censos$censo == t, ]
  m$prov <- ct$prov[match(m$cod_ine, ct$cod_ine)]
  m$cpro <- substr(m$cod_ine, 1, 2)
  # els territoris no municipals (53xxx) compten dins la província indicada al SIANE
  key <- function(x) gsub("[^a-z]", "", tolower(stringi::stri_trans_general(x, "Latin-ASCII")))
  lk <- unique(data.frame(k = key(m$prov[m$no_munic == 0]), cpro = m$cpro[m$no_munic == 0]))
  lk <- lk[!duplicated(lk$k), ]
  nm <- m$no_munic == 1
  pk <- key(m$prov[nm])
  hit <- lk$cpro[match(pk, lk$k)]
  # noms que no coincideixen exactament (p. ex. "Araba/Álava" vs "Álava"): coincidència parcial
  for (i in which(is.na(hit))) {
    j <- which(vapply(lk$k, function(z) grepl(z, pk[i]) || grepl(pk[i], z), logical(1)))
    if (length(j)) hit[i] <- lk$cpro[j[1]]
  }
  m$cpro[nm] <- ifelse(is.na(hit), m$cpro[nm], hit)
  pr <- m |> group_by(cpro) |> summarise(.groups = "drop")
  h <- lapply(seq_len(nrow(pr)), function(i) {
    hh <- interior_holes(st_geometry(pr)[i])
    a <- as.numeric(st_area(hh))
    data.frame(cpro = pr$cpro[i], n = length(a), km2 = sum(a) / 1e6)
  })
  h <- do.call(rbind, h)
  h <- h[h$n > 0, ]
  res[[as.character(t)]] <- data.frame(cens = t, provincies = nrow(pr),
                                       provincies_amb_forats = nrow(h),
                                       forats = sum(h$n), km2_forats = round(sum(h$km2), 2),
                                       detall = paste(sprintf("%s:%d(%.1f km2)", h$cpro, h$n, h$km2), collapse = " "))
  if (t %in% c(1900, 1960, 2001)) {
    png(file.path(dir_fig, sprintf("provincies_%d.png", t)), width = 1800, height = 1500, res = 150)
    plot(st_geometry(pr), col = sample(hcl.colors(60, "Set 3")), border = "grey20", lwd = 0.4,
         main = sprintf("Províncies agregades des dels municipis del cens %d", t))
    dev.off()
  }
}
res <- do.call(rbind, res)
print(res[, 1:5])
cat("\nDetall dels forats per província (codi:n(km2)):\n")
for (i in seq_len(nrow(res))) cat(res$cens[i], ":", res$detall[i], "\n")
write.csv(res, file.path(dir_out, "validacio_provincies.csv"), row.names = FALSE)

# Zoom: Valdetórtola (Conca), municipi creat als anys 70 i dissolt als 90
m81 <- st_transform(read_sf(gpkg, "muni_1981"), crs_work)
bb <- st_bbox(st_buffer(st_geometry(m81[m81$cod_ine == "16907", ]), 15000))
zoom <- function(t) {
  m <- st_transform(read_sf(gpkg, paste0("muni_", t)), crs_work)
  suppressWarnings(st_crop(m, bb))
}
png(file.path(dir_fig, "zoom_conca_1970_1981_1991.png"), width = 2400, height = 900, res = 150)
par(mfrow = c(1, 3), mar = c(1, 1, 3, 1))
for (t in c(1970, 1981, 1991)) {
  z <- zoom(t)
  plot(st_geometry(z), col = ifelse(z$cod_ine == "16907", "tomato", "grey90"), border = "grey30", lwd = 0.5,
       main = paste("Cens", t))
}
dev.off()
cat("Figures a", dir_fig, "\n")
