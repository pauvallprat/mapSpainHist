# mapSpainHist

[English](https://pauvallprat.github.io/mapSpainHist/README.md) ·
[Castellano](https://pauvallprat.github.io/mapSpainHist/README.es.md) ·
**Català**

**mapSpainHist** és un paquet d’R amb els **límits municipals d’Espanya
per a cada cens de població entre 1900 i 2001** (1900, 1910, 1920, 1930,
1940, 1950, 1960, 1970, 1981, 1991 i 2001) i amb les **unitats
territorials superiors** construïdes a partir d’aquests municipis:
províncies, partits judicials i circumscripcions electorals històriques.
Inclou també les **dades bàsiques dels censos** de cada municipi entre
1842 i 2011.

Tots els mapes provenen d’una mateixa partició del territori, de manera
que **no tenen forats ni solapaments** i es poden agregar sense que
quedin buits entre unitats.

> **Avís important.** La forma de la major part dels municipis històrics
> és una **reconstrucció aproximada**. Els mapes són especialment útils
> per **representar gràficament dades municipals**, però s’han de fer
> servir **amb cautela** quan es tenen en compte variables geogràfiques
> com la **superfície** o les **distàncies**. Vegeu la
> [metodologia](https://pauvallprat.github.io/mapSpainHist/articles/ca/metodologia.html).

## Instal·lació

``` r

# Versió en desenvolupament, des de GitHub
# install.packages("remotes")
remotes::install_github("pauvallprat/mapSpainHist")
```

Les geometries es descarreguen de
[Zenodo](https://doi.org/10.5281/zenodo.23663208) la primera vegada que
es fan servir (uns 6,5 MB) i es desen a la memòria cau de l’ordinador;
les vegades següents es llegeixen directament del disc.

## Ús

``` r

library(mapSpainHist)

# Municipis del cens de 1930, amb les dades del cens
m1930 <- esp_get_munic_hist(1930)

# Canàries al costat de la península, com al paquet `mapSpain`, amb la seva caixa
m1930 <- esp_get_munic_hist(1930, moveCAN = TRUE)
library(ggplot2)
ggplot(m1930) + geom_sf() + geom_sf(data = mapSpain::esp_get_can_box())

# Unitats superiors
esp_get_prov_hist(1930)   # províncies (disponible per a tots els censos)
esp_get_pj_hist(1910)     # partits judicials (1900-1930)
esp_get_circ_hist(1920)   # districtes a Corts de la Restauració
esp_get_circ_hist(1933)   # circumscripcions de la II República (també 1931 i 1936)

# Taules
head(censos)    # dades dels censos de cada municipi, 1842-2011
head(unitats)   # a quina unitat superior pertany cada municipi
```

| Funció | Contingut | Anys |
|----|----|----|
| [`esp_get_munic_hist()`](https://pauvallprat.github.io/mapSpainHist/reference/esp_get_munic_hist.md) | Municipis | 1900, 1910, 1920, 1930, 1940, 1950, 1960, 1970, 1981, 1991, 2001 |
| [`esp_get_prov_hist()`](https://pauvallprat.github.io/mapSpainHist/reference/esp_get_prov_hist.md) | Províncies | els mateixos censos |
| [`esp_get_pj_hist()`](https://pauvallprat.github.io/mapSpainHist/reference/esp_get_pj_hist.md) | Partits judicials | 1900, 1910, 1920, 1930 |
| [`esp_get_circ_hist()`](https://pauvallprat.github.io/mapSpainHist/reference/esp_get_circ_hist.md) | Districtes a Corts durant la Restauració (1920) i circumscripcions de la II República | 1920, 1931, 1933, 1936 |

## Documentació

- [Introducció](https://pauvallprat.github.io/mapSpainHist/articles/ca/introduccio.html)
- [Unitats superiors i agregació de
  dades](https://pauvallprat.github.io/mapSpainHist/articles/ca/unitats.html)
- [Guia de funcions i
  dades](https://pauvallprat.github.io/mapSpainHist/articles/ca/funcions.html)
- [Metodologia, fonts i
  advertiments](https://pauvallprat.github.io/mapSpainHist/articles/ca/metodologia.html)

## Problemes i suggeriments

Si detecteu un error als mapes o a les dades, o teniu algun suggeriment,
feu servir el [formulari de
contacte](https://pauvallprat.github.io/mapSpainHist/articles/ca/contacte.html),
escriviu a <pau.vall@ub.edu> o [obriu una
incidència](https://github.com/pauvallprat/mapSpainHist/issues/new/choose)
a GitHub.

## Com citar-lo

Si feu servir el paquet o les seves dades, citeu-los. Podeu obtenir la
referència amb:

``` r

citation("mapSpainHist")
```

- Vall Prat, P. (2026). *mapSpainHist: Historical Municipal Boundaries
  of Spain (1900-2001)*. Paquet d’R, versió 0.1.0.
  <https://github.com/pauvallprat/mapSpainHist>
- Vall Prat, P. (2026). *Historical municipal boundaries of Spain,
  1900-2001* \[conjunt de dades\]. Zenodo.
  <https://doi.org/10.5281/zenodo.23663208>

## Llicències

- **Codi:** llicència
  [MIT](https://pauvallprat.github.io/mapSpainHist/LICENSE.md).
- **Dades** (geometries i taules `censos` i `unitats`): llicència
  [Creative Commons Reconeixement 4.0 Internacional (CC BY
  4.0)](https://creativecommons.org/licenses/by/4.0/deed.ca).

Els límits municipals de referència deriven del SIANE (© Instituto
Geográfico Nacional, CC BY 4.0), descarregats a partir de l’any més
antic disponible al paquet `mapSpain`; les dades dels censos, dels
censos de població de l’INE; les variacions municipals, del document
elaborat pel Ministerio de Administraciones Públicas [*Variaciones de
los municipios de España desde
1842*](https://www.hacienda.gob.es/SGT/catalogo_sefp/100_variaciones-internet.pdf).
Vegeu-ne el detall a la metodologia.
