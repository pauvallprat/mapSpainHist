# Historical municipalities of Spain for a census year

Returns the municipalities in force at the given census. All census maps
come from the same partition of the territory, so they have no gaps or
overlaps and can be aggregated (provinces, judicial districts, electoral
districts...) without slivers.

## Usage

``` r
esp_get_munic_hist(
  year,
  epsg = 4258,
  moveCAN = FALSE,
  include_nonmunicipal = TRUE,
  census_data = TRUE,
  cache_dir = NULL,
  update_cache = FALSE,
  verbose = FALSE
)
```

## Arguments

- year:

  Census year, one of \[mhist_census_years()\].

- epsg:

  EPSG code of the output (default 4258, ETRS89, as in mapSpain).

- moveCAN:

  Position of the Canary Islands. \`FALSE\` (default) keeps their real
  position. \`TRUE\` moves them next to the Peninsula exactly as
  \`mapSpain::esp_move_can()\` does. A numeric vector \`c(lon, lat)\`
  adds an extra displacement, also as in mapSpain. When the islands are
  moved, draw the box that separates them with
  \`mapSpain::esp_get_can_box()\`, which matches this displacement.

- include_nonmunicipal:

  If \`FALSE\`, drops the non-municipal territories (codes 53xxx,
  \`no_munic == 1\`).

- census_data:

  If \`TRUE\` (default), adds the census figures of \`year\` from
  \[censos\] (municipality name, province, households, population...).
  If \`FALSE\`, returns only \`cod_ine\`, \`no_munic\` and the geometry.

- cache_dir:

  Cache directory. If \`NULL\`, \[mhist_cache_dir()\] is used.

- update_cache:

  If \`TRUE\`, downloads the geometries again.

- verbose:

  If \`TRUE\`, shows download messages.

## Value

An \`sf\` object with one row per municipality, or \`NULL\` (with a
message) if the geometries cannot be downloaded.

## Details

The geometries are downloaded from Zenodo the first time and stored in a
cache directory (see \[mhist_cache_dir()\]).

## Warning

the boundaries of most historical municipalities are an approximate
reconstruction. See \[mapSpainHist-package\].

## Examples

``` r
# \donttest{
m1930 <- esp_get_munic_hist(1930, cache_dir = tempdir())
m1930_can <- esp_get_munic_hist(1930, moveCAN = TRUE, cache_dir = tempdir())
if (!is.null(m1930)) plot(sf::st_geometry(m1930))

if (!is.null(m1930_can) && requireNamespace("mapSpain", quietly = TRUE)) {
  plot(sf::st_geometry(m1930_can))
  plot(sf::st_geometry(mapSpain::esp_get_can_box()), add = TRUE)
}

# }
```
