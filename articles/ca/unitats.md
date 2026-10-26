# Unitats superiors i agregació de dades

``` r

library(mapSpainHist)
library(ggplot2)
```

A més dels municipis, el paquet inclou unitats territorials superiors
construïdes **fusionant els municipis de cada cens**. Per això encaixen
exactament amb els mapes municipals: cada municipi pertany a una sola
unitat i les unitats no tenen forats ni solapaments entre elles.

| Funció | Unitat | Anys | Municipis de referència |
|----|----|----|----|
| [`esp_get_prov_hist()`](https://pauvallprat.github.io/mapSpainHist/reference/esp_get_prov_hist.md) | Províncies | tots els censos (1900-2001) | els del mateix cens |
| [`esp_get_pj_hist()`](https://pauvallprat.github.io/mapSpainHist/reference/esp_get_pj_hist.md) | Partits judicials | 1900, 1910, 1920, 1930 | els del mateix cens |
| [`esp_get_circ_hist()`](https://pauvallprat.github.io/mapSpainHist/reference/esp_get_circ_hist.md) | Districtes a Corts de la Restauració | 1920 | cens de 1920 |
| [`esp_get_circ_hist()`](https://pauvallprat.github.io/mapSpainHist/reference/esp_get_circ_hist.md) | Circumscripcions de la II República | 1931, 1933, 1936 | cens de 1930 |

Totes les funcions retornen el codi de la unitat (`cod_unit`), el nom
(`nom`), el nombre de municipis (`n_mun`) i, si `census_data = TRUE`
(opció per defecte), la suma de les dades del cens dels seus municipis
(`hogares`, `pder`, `phec`, `pob_serie`).

## Codis de les unitats

- **Províncies:** codi INE de la província (2 xifres).
- **Partits judicials i districtes electorals:** 4 xifres. Les dues
  primeres són la província i les dues següents numeren les unitats per
  ordre alfabètic dins la província. Els partits judicials tenen el
  mateix codi en tots els censos.

## Partits judicials

``` r

pj <- esp_get_pj_hist(1910, moveCAN = TRUE)
head(sf::st_drop_geometry(pj))
#>   cod_unit          nom n_mun hogares  pder  phec pob_serie
#> 1     0101    Laguardia    30    4606 18370 17880     18370
#> 2     0102      Vitoria    55   17414 81029 79301     81029
#> 3     0201     Albacete     5    8426 33804 33557     33804
#> 4     0202      Alcaraz    19   10764 40908 37951     40908
#> 5     0203      Almansa     4    6566 26076 26062     26076
#> 6     0204 Casas-Ibáñez    21    8708 33354 33294     33354

ggplot(pj) +
  geom_sf(aes(fill = pder / 1000), colour = "white", linewidth = 0.1) +
  scale_fill_viridis_c(option = "cividis", trans = "log10") +
  geom_sf(data = mapSpain::esp_get_can_box(), colour = "grey50") +
  labs(title = "Població de dret per partit judicial, 1910", fill = "Milers\nd'habitants") +
  theme_void()
```

![Mapa dels partits judicials d'Espanya el 1910 acolorits segons la
població](unitats_files/figure-html/pj-1910-1.png)

## Districtes electorals

Els districtes a Corts de 1920 són els de la Restauració. Les
circumscripcions de 1931, 1933 i 1936 són les de les eleccions de la II
República; en algunes províncies les capitals formen una circumscripció
pròpia.

``` r

d1920 <- esp_get_circ_hist(1920, moveCAN = TRUE, census_data = FALSE)
d1933 <- esp_get_circ_hist(1933, moveCAN = TRUE, census_data = FALSE)
c(districtes_1920 = nrow(d1920), circumscripcions_1933 = nrow(d1933))
#>       districtes_1920 circumscripcions_1933 
#>                   339                    60

d1920$tipus <- "Districtes a Corts, 1920"
d1933$tipus <- "Circumscripcions, 1933"
ggplot(rbind(d1920, d1933)) +
  geom_sf(fill = "grey95", colour = "grey20", linewidth = 0.15) +
  geom_sf(data = mapSpain::esp_get_can_box(), colour = "grey50") +
  facet_wrap(~tipus) +
  theme_void()
```

![Mapes dels districtes a Corts de 1920 i de les circumscripcions de
1933](unitats_files/figure-html/districtes-1.png)

## Agregar dades pròpies

La taula `unitats` indica a quina unitat pertany cada municipi
(`cod_ine`) per a cada tipus (`prov`, `pj`, `circ`) i any. Permet
agregar qualsevol dada municipal. Per exemple, calculem la proporció de
població que vivia en municipis de més de 10.000 habitants a cada
circumscripció de 1933 (fent servir el cens de 1930):

``` r

eq <- unitats[unitats$tipus == "circ" & unitats$any == 1933, ]
c30 <- censos[censos$censo == 1930 & !is.na(censos$hogares), c("cod_ine", "pder")]
d <- merge(eq, c30, by = "cod_ine")
d$urbana <- ifelse(d$pder > 10000, d$pder, 0)

ag <- aggregate(cbind(urbana, pder) ~ cod_unit, data = d, FUN = sum)
ag$prop_urbana <- ag$urbana / ag$pder

circ <- merge(esp_get_circ_hist(1933, moveCAN = TRUE), ag[, c("cod_unit", "prop_urbana")],
              by = "cod_unit")
ggplot(circ) +
  geom_sf(aes(fill = prop_urbana), colour = "white", linewidth = 0.2) +
  scale_fill_viridis_c(labels = scales::percent) +
  geom_sf(data = mapSpain::esp_get_can_box(), colour = "grey50") +
  labs(title = "Població en municipis de més de 10.000 habitants, 1930",
       subtitle = "Circumscripcions electorals de 1933", fill = NULL) +
  theme_void()
```

![Mapa de les circumscripcions de 1933 acolorides segons la proporció de
població en municipis de més de 10.000
habitants](unitats_files/figure-html/agregacio-1.png)

## Territoris no municipals

Els territoris no municipals (codis 53xxx) s’assignen:

- a la **província** dins la qual cau el polígon (segons les províncies
  del SIANE);
- al **partit judicial** o **districte electoral** de la seva província
  amb què comparteixen més frontera.

Melilla no tenia districte a Corts el 1920 i no apareix en aquest mapa.
