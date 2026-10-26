# Municipalities of each historical higher-level unit

Correspondence between municipalities (`cod_ine`) and the units returned
by
[`esp_get_prov_hist()`](https://pauvallprat.github.io/mapSpainHist/reference/esp_get_prov_hist.md),
[`esp_get_pj_hist()`](https://pauvallprat.github.io/mapSpainHist/reference/esp_get_pj_hist.md)
and
[`esp_get_circ_hist()`](https://pauvallprat.github.io/mapSpainHist/reference/esp_get_circ_hist.md).
Useful to aggregate municipal data. Non-municipal territories (53xxx)
are included with the unit they were assigned to.

## Usage

``` r
unitats
```

## Format

A data frame with columns:

- tipus:

  `"prov"`, `"pj"` (judicial district) or `"circ"` (electoral district).

- any:

  Census year (prov, pj) or election year (circ: 1920, 1931, 1933,
  1936).

- cod_ine:

  INE municipality code.

- cod_unit:

  Unit code (2 digits for provinces, 4 digits otherwise).
