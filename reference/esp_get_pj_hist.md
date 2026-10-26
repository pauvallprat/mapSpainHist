# Historical judicial districts (partidos judiciales) of Spain

Judicial districts for the censuses of 1900, 1910, 1920 and 1930, built
by dissolving the municipalities of each census. \`cod_unit\` has 4
digits: the province code and the district number (alphabetical order
within the province, the same in all censuses). Non-municipal
territories (53xxx) are assigned to the district of their province with
which they share the longest boundary.

## Usage

``` r
esp_get_pj_hist(
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

  Census year: 1900, 1910, 1920 or 1930.

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

An \`sf\` object with columns \`cod_unit\`, \`nom\`, \`n_mun\` and,
optionally, the census figures.

## Examples

``` r
# \donttest{
pj1910 <- esp_get_pj_hist(1910, cache_dir = tempdir())
# }
```
