# Historical electoral districts of Spain

Electoral districts built by dissolving the municipalities of the
census:

- \`1920\`: districts for the Cortes of the Restoration, on the 1920
  municipalities (Melilla has no district and is not included).

- \`1931\`, \`1933\`, \`1936\`: constituencies (circunscripciones) of
  the Second Republic, on the 1930 municipalities.

\`cod_unit\` has 4 digits: the province code and the district number
(alphabetical order within the province). Non-municipal territories
(53xxx) are assigned to the district of their province with which they
share the longest boundary.

## Usage

``` r
esp_get_circ_hist(
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

  1920, 1931, 1933 or 1936. Census figures come from the 1920
  census (1920) or the 1930 census (1931-1936).

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
c1933 <- esp_get_circ_hist(1933, cache_dir = tempdir())
# }
```
