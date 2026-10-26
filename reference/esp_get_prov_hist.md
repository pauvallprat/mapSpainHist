# Historical provinces of Spain for a census year

Provinces built by dissolving the municipalities of the census, so they
nest exactly with \[esp_get_munic_hist()\]. Non-municipal territories
(53xxx) are assigned to the province that contains them.

## Usage

``` r
esp_get_prov_hist(
  year,
  epsg = 4258,
  moveCAN = FALSE,
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

- census_data:

  If \`TRUE\` (default), adds the number of municipalities and the sum
  of the census figures (\`hogares\`, \`pder\`, \`phec\`, \`pob_serie\`)
  of the municipalities of each unit.

- cache_dir:

  Cache directory. If \`NULL\`, \[mhist_cache_dir()\] is used.

- update_cache:

  If \`TRUE\`, downloads the geometries again.

- verbose:

  If \`TRUE\`, shows download messages.

## Value

An \`sf\` object with columns \`cod_unit\` (2-digit INE province code),
\`nom\`, \`n_mun\` and, optionally, the census figures; \`NULL\` (with a
message) if the geometries cannot be downloaded.

## Examples

``` r
# \donttest{
p1930 <- esp_get_prov_hist(1930, cache_dir = tempdir())
# }
```
