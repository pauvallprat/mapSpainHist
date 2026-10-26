# mapSpainHist

**English** ·
[Castellano](https://pauvallprat.github.io/mapSpainHist/README.es.md) ·
[Català](https://pauvallprat.github.io/mapSpainHist/README.ca.md)

**mapSpainHist** is an R package with the **municipal boundaries of
Spain for each population census between 1900 and 2001** (1900, 1910,
1920, 1930, 1940, 1950, 1960, 1970, 1981, 1991 and 2001) and the
**higher-level territorial units** built from these municipalities:
provinces, judicial districts and historical electoral districts. It
also includes the **basic census figures** of every municipality between
1842 and 2011.

All maps come from a single partition of the territory, so they **have
no gaps or overlaps** and can be aggregated without leaving holes
between units.

> **Important warning.** The shape of most historical municipalities is
> an **approximate reconstruction**. The maps are especially useful to
> **represent municipal data graphically**, but they must be used **with
> caution** when geographic variables such as **area** or **distances**
> matter. See the
> [methodology](https://pauvallprat.github.io/mapSpainHist/articles/en/methodology.html).

## Installation

``` r

# Development version, from GitHub
# install.packages("remotes")
remotes::install_github("pauvallprat/mapSpainHist")
```

The geometries are downloaded from
[Zenodo](https://doi.org/10.5281/zenodo.23663208) the first time they
are used (about 6.5 MB) and stored in a local cache; afterwards they are
read directly from disk.

## Usage

``` r

library(mapSpainHist)

# Municipalities of the 1930 census, with census figures
m1930 <- esp_get_munic_hist(1930)

# Canary Islands next to the Peninsula, as in the `mapSpain` package, with their box
m1930 <- esp_get_munic_hist(1930, moveCAN = TRUE)
library(ggplot2)
ggplot(m1930) + geom_sf() + geom_sf(data = mapSpain::esp_get_can_box())

# Higher-level units
esp_get_prov_hist(1930)   # provinces (available for every census)
esp_get_pj_hist(1910)     # judicial districts (1900-1930)
esp_get_circ_hist(1920)   # districts for the Cortes of the Restoration
esp_get_circ_hist(1933)   # constituencies of the Second Republic (also 1931 and 1936)

# Tables
head(censos)    # census figures of every municipality, 1842-2011
head(unitats)   # higher-level unit of every municipality
```

| Function | Content | Years |
|----|----|----|
| [`esp_get_munic_hist()`](https://pauvallprat.github.io/mapSpainHist/reference/esp_get_munic_hist.md) | Municipalities | 1900, 1910, 1920, 1930, 1940, 1950, 1960, 1970, 1981, 1991, 2001 |
| [`esp_get_prov_hist()`](https://pauvallprat.github.io/mapSpainHist/reference/esp_get_prov_hist.md) | Provinces | the same censuses |
| [`esp_get_pj_hist()`](https://pauvallprat.github.io/mapSpainHist/reference/esp_get_pj_hist.md) | Judicial districts | 1900, 1910, 1920, 1930 |
| [`esp_get_circ_hist()`](https://pauvallprat.github.io/mapSpainHist/reference/esp_get_circ_hist.md) | Districts for the Cortes during the Restoration (1920) and constituencies of the Second Republic | 1920, 1931, 1933, 1936 |

## Documentation

- [Introduction](https://pauvallprat.github.io/mapSpainHist/articles/en/introduction.html)
- [Higher-level units and data
  aggregation](https://pauvallprat.github.io/mapSpainHist/articles/en/units.html)
- [Guide to functions and
  data](https://pauvallprat.github.io/mapSpainHist/articles/en/functions.html)
- [Methodology, sources and
  warnings](https://pauvallprat.github.io/mapSpainHist/articles/en/methodology.html)

The documentation is also available in
[Spanish](https://pauvallprat.github.io/mapSpainHist/articles/es/introduccion.html)
and
[Catalan](https://pauvallprat.github.io/mapSpainHist/articles/ca/introduccio.html).

## Problems and suggestions

If you find an error in the maps or the data, or have a suggestion, use
the [contact
form](https://pauvallprat.github.io/mapSpainHist/articles/en/contact.html),
write to <pau.vall@ub.edu> or [open an
issue](https://github.com/pauvallprat/mapSpainHist/issues/new/choose) on
GitHub.

## How to cite

If you use the package and/or its data, please cite them. You can get
the reference with:

``` r

citation("mapSpainHist")
```

- Vall Prat, P. (2026). *Historical municipal boundaries of Spain,
  1900-2001* \[Data set\]. Zenodo.
  <https://doi.org/10.5281/zenodo.23663208>

## Licenses

- **R package** (code and the bundled `censos` and `unitats` tables):
  [MIT](https://pauvallprat.github.io/mapSpainHist/LICENSE.md) license.
- **Zenodo data deposit** (geometries, census tables and GeoPackage):
  [Creative Commons Attribution 4.0 International (CC BY
  4.0)](https://creativecommons.org/licenses/by/4.0/).

The reference municipal boundaries derive from SIANE (© Instituto
Geográfico Nacional, CC BY 4.0), downloaded for the earliest year
available in the `mapSpain` package; census figures come from the
population censuses of the INE; municipal changes from the document by
the Ministerio de Administraciones Públicas [*Variaciones de los
municipios de España desde
1842*](https://www.hacienda.gob.es/SGT/catalogo_sefp/100_variaciones-internet.pdf).
See the methodology for details.
