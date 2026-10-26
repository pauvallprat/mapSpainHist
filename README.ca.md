# mapSpainHist <img src="man/figures/logo.png" align="right" height="139" alt="" />

[English](README.md) · [Castellano](README.es.md) · **Català**

**mapSpainHist** és un paquet d'R amb els **límits municipals d'Espanya per a cada cens de
població entre 1900 i 2001** (1900, 1910, 1920, 1930, 1940, 1950, 1960, 1970, 1981, 1991 i 2001)
i amb les **unitats territorials superiors** construïdes a partir d'aquests municipis: províncies,
partits judicials i districtes electorals històrics. Inclou també les **dades dels censos** de
cada municipi entre 1842 i 2011.

Tots els mapes provenen d'una mateixa partició del territori, de manera que **no tenen forats ni
solapaments** i es poden agregar sense que quedin buits entre unitats.

> **Avís important.** La forma de la major part dels municipis històrics és una **reconstrucció
> aproximada**. Els mapes són especialment útils per **representar gràficament dades
> municipals**, però s'han de fer servir **amb cautela** quan es tenen en compte variables
> geogràfiques com la **superfície** o les **distàncies**. Vegeu la
> [metodologia](https://pauvallprat.github.io/mapSpainHist/articles/ca/metodologia.html).

## Instal·lació

```r
# Versió en desenvolupament, des de GitHub
# install.packages("remotes")
remotes::install_github("pauvallprat/mapSpainHist")
```

Les geometries es descarreguen de [Zenodo](https://zenodo.org) la primera vegada que es fan servir
(uns 6,5 MB) i es desen a la memòria cau de l'ordinador; les vegades següents es llegeixen
directament del disc.

## Ús

```r
library(mapSpainHist)

# Municipis del cens de 1930, amb les dades del cens
m1930 <- esp_get_munic_hist(1930)

# Canàries al costat de la península, com al paquet mapSpain
m1930 <- esp_get_munic_hist(1930, moveCAN = TRUE)

# Unitats superiors
esp_get_prov_hist(1930)   # províncies (tots els censos)
esp_get_pj_hist(1910)     # partits judicials (1900-1930)
esp_get_circ_hist(1920)   # districtes a Corts de la Restauració
esp_get_circ_hist(1933)   # circumscripcions de la II República (1931, 1933, 1936)

# Taules
head(censos)    # dades dels censos de cada municipi, 1842-2011
head(unitats)   # a quina unitat superior pertany cada municipi
```

| Funció | Contingut | Anys |
|---|---|---|
| `esp_get_munic_hist()` | Municipis | 1900, 1910, 1920, 1930, 1940, 1950, 1960, 1970, 1981, 1991, 2001 |
| `esp_get_prov_hist()` | Províncies | els mateixos censos |
| `esp_get_pj_hist()` | Partits judicials | 1900, 1910, 1920, 1930 |
| `esp_get_circ_hist()` | Districtes a Corts (1920) i circumscripcions de la II República | 1920, 1931, 1933, 1936 |

## Documentació

- [Introducció](https://pauvallprat.github.io/mapSpainHist/articles/ca/introduccio.html)
- [Unitats superiors i agregació de dades](https://pauvallprat.github.io/mapSpainHist/articles/ca/unitats.html)
- [Guia de funcions i dades](https://pauvallprat.github.io/mapSpainHist/articles/ca/funcions.html)
- [Metodologia, fonts i advertiments](https://pauvallprat.github.io/mapSpainHist/articles/ca/metodologia.html)

## Com citar-lo

Si feu servir el paquet o les seves dades, citeu-los. Podeu obtenir la referència amb:

```r
citation("mapSpainHist")
```

- Vall Prat, P. (2026). *mapSpainHist: Historical Municipal Boundaries of Spain (1900-2001)*.
  Paquet d'R, versió 0.1.0. https://doi.org/ZENODO_DOI_SOFTWARE
- Vall Prat, P. (2026). *Historical municipal boundaries of Spain, 1900-2001 (census editions)*
  [conjunt de dades]. Zenodo. https://doi.org/ZENODO_DOI_DATA

## Llicències

- **Codi:** llicència [MIT](LICENSE.md).
- **Dades** (geometries i taules `censos` i `unitats`): llicència
  [Creative Commons Reconeixement 4.0 Internacional (CC BY 4.0)](https://creativecommons.org/licenses/by/4.0/deed.ca).

Els límits municipals de referència deriven del SIANE (© Instituto Geográfico Nacional, CC BY 4.0);
les dades dels censos, dels censos de població de l'INE; les variacions municipals, del MINAP
(*Variaciones de los municipios de España desde 1842*). Vegeu-ne el detall a la metodologia.
