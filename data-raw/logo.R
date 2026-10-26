# Logo (hexàgon) del paquet ----------------------------------------------------------
# Logo triat: proposta B (districtes a Corts de 1920), copiat a man/figures/logo.png.
# Genera output/logo/proposta_*.png a partir de les dades del paquet. Cal tenir les
# geometries disponibles (MAPSPAINHIST_DATA o descàrrega de Zenodo).

suppressPackageStartupMessages({library(ggplot2); library(sf); library(mapSpainHist)})
sf_use_s2(FALSE)
dir_logo <- file.path("output", "logo"); dir.create(dir_logo, recursive = TRUE, showWarnings = FALSE)

# Península i Balears (sense Canàries, Ceuta ni Melilla), en ETRS89 / UTM 30N
peninsula <- function(x) {
  x <- x[!substr(x[[1]], 1, 2) %in% c("35", "38", "51", "52"), ]
  st_transform(x, 25830)
}
m1900 <- peninsula(esp_get_munic_hist(1900, census_data = FALSE))
m2001 <- peninsula(esp_get_munic_hist(2001, census_data = FALSE))
d1920 <- peninsula(esp_get_circ_hist(1920, census_data = FALSE))
p1930 <- peninsula(esp_get_prov_hist(1930, census_data = FALSE))
silueta <- st_union(p1930)

# Hexàgon amb vèrtexs a dalt i a baix (format estàndard dels stickers d'R)
hexagon <- function(cx = 1, cy = 1, r = 1) {
  a <- seq(90, 450, by = 60) * pi / 180
  data.frame(x = cx + r * cos(a), y = cy + r * sin(a))
}

sticker <- function(mapa, fons, vora, text_col, sub = "1900-2001", file, font = "Georgia") {
  hx <- hexagon()
  g <- ggplotGrob(mapa + theme_void() + theme(plot.margin = margin(0, 0, 0, 0)))
  p <- ggplot() +
    geom_polygon(data = hx, aes(x, y), fill = fons, colour = vora, linewidth = 3) +
    annotation_custom(g, xmin = 0.22, xmax = 1.78, ymin = 0.62, ymax = 1.72) +
    annotate("text", x = 1, y = 0.47, label = "mapSpainHist", family = font,
             fontface = "bold", size = 10.5, colour = text_col) +
    annotate("text", x = 1, y = 0.30, label = sub, family = font, size = 5.2, colour = text_col) +
    coord_fixed(xlim = c(0.12, 1.88), ylim = c(-0.01, 2.01), expand = FALSE) +
    theme_void() + theme(plot.background = element_rect(fill = "transparent", colour = NA))
  ragg::agg_png(file, width = 1040, height = 1200, res = 200, background = "transparent")
  print(p)
  dev.off()
  invisible(file)
}

set.seed(7)
pal_terra <- c("#c9a66b", "#b5835a", "#d8c3a5", "#a3765b", "#e0b98a", "#8f5b3e", "#cfae7e")

# A. Mosaic municipal de 1900, tons sèpia sobre fons fosc
a <- ggplot(m1900) + geom_sf(fill = "#f3e6c8", colour = "#8c3b1e", linewidth = 0.05)
sticker(a, fons = "#3b2416", vora = "#c9a66b", text_col = "#f3e6c8",
        file = file.path(dir_logo, "proposta_A_sepia.png"))

# B. Districtes a Corts de 1920 acolorits, sobre paper
d1920$col <- sample(pal_terra, nrow(d1920), replace = TRUE)
b <- ggplot(d1920) + geom_sf(aes(fill = col), colour = "#5a3a22", linewidth = 0.1) + scale_fill_identity()
sticker(b, fons = "#f4ead5", vora = "#5a3a22", text_col = "#3b2416",
        file = file.path(dir_logo, "proposta_B_districtes.png"))
file.copy(file.path(dir_logo, "proposta_B_districtes.png"), file.path("man", "figures", "logo.png"), overwrite = TRUE)

# C. Abans i després: municipis de 1900 (fons) i de 2001 (línies), blau
c1 <- ggplot() +
  geom_sf(data = m1900, fill = "#dce9f2", colour = "#9fbcd2", linewidth = 0.04) +
  geom_sf(data = m2001, fill = NA, colour = "#1f4e79", linewidth = 0.06)
sticker(c1, fons = "#ffffff", vora = "#1f4e79", text_col = "#1f4e79",
        file = file.path(dir_logo, "proposta_C_1900_2001.png"))

# D. Minimal: silueta amb províncies, granat
dmap <- ggplot() + geom_sf(data = p1930, fill = "#f6efe4", colour = "#8c1c2b", linewidth = 0.25) +
  geom_sf(data = silueta, fill = NA, colour = "#8c1c2b", linewidth = 0.6)
sticker(dmap, fons = "#8c1c2b", vora = "#f6efe4", text_col = "#f6efe4",
        file = file.path(dir_logo, "proposta_D_provincies.png"))

cat("Propostes a", normalizePath(dir_logo), "\n")
