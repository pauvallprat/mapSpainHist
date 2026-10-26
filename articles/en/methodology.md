# Methodology, sources and warnings

## Important warning on the use of the data

**The shape of the municipalities is approximate.** For most historical
municipalities that no longer exist there is no cartography of their
limits. The polygons have been reconstructed approximately and,
therefore:

- The maps are **especially useful to represent municipal data
  graphically**.
- **They must be used with caution** when **geographic variables**
  matter, such as the **area** of the municipalities, **distances** to
  other points, precise contiguity or the exact location of the borders.
- They are a **useful but imperfect approximation**, and this must be
  kept in mind in any analysis.

The same applies to the higher-level units (judicial districts and
electoral districts), which are built by aggregating the municipalities.

## 1. Building the municipal polygons

1.  **Starting point.** The earliest available municipal division with
    official boundaries was taken, from the early 2000s (SIANE,
    Instituto Geográfico Nacional, distributed through the R package
    **mapSpain**).
2.  **Reconstruction for each census.** From this division, a polygon
    was generated approximately and manually for each municipality
    existing at each census (maps of 1900, 1930, 1950 and 1970):
    - When a current municipality results from the merger of several
      historical municipalities, its territory was divided among the
      former municipalities.
    - The polygon was always drawn so that the **municipal seat** (the
      settlement that usually names the municipality) falls inside it.
    - When the **settlements that belonged to the municipality** were
      known, they were also kept inside the polygon.
3.  **Municipalities in force.** The municipalities of each census are
    those with household figures in the census series of the Instituto
    Nacional de Estadística (INE).

## 2. Consistency between censuses and topology

The hand-drawn maps had small overlaps and gaps between polygons
(invisible to the naked eye), and the boundaries of the same
municipality did not always match exactly between maps. So that
aggregations (provinces, judicial districts, districts) have no gaps,
the data-building process does the following:

1.  **Cleaning each map.** Overlapping areas are split equally among the
    municipalities involved (each point goes to the municipality with
    the nearest border) and small gaps are filled by equal expansion of
    the neighbouring borders.
2.  **Partition into minimal units.** All the boundaries of the 1900,
    1930, 1950 and 1970 maps and of SIANE 2005 are overlaid to obtain a
    single partition of the territory into minimal units. Each unit is
    assigned a municipality in each map.
3.  **Censuses without a hand-drawn map** (1910, 1920, 1940, 1960, 1981,
    1991 and 2001). Each unit is assigned from the previous and the next
    map, the municipalities in force at the census and the municipal
    changes documented in MINAP (*Variaciones de los municipios de
    España desde 1842*), to which the INE code has been added. For
    censuses after 1970 the 1970 boundaries are kept unless a change is
    documented.
4.  **Manual corrections.** Some special problematic cases were solved
    by hand (files `data-raw/correccions_manuals.csv`,
    `data-raw/parts_desconnectades.csv` and
    `data-raw/manual/territoris_manuals.gpkg`).
5.  **Simplification.** The partition is simplified preserving its
    topology (each shared boundary is simplified only once, with a 20 m
    tolerance), and the map of each census is obtained by dissolving the
    units by municipality. Some units are corrected so that they are
    also valid in geographic coordinates (moving almost coincident
    vertices a few metres, always in every unit that shares them).

As all maps come from the same partition, **they have no gaps or
overlaps** and any aggregation is exact.

### Non-municipal territories (53xxx)

Communal condominiums or jointly administered territories are
administrative units that are not municipalities. They are kept as units
of their own in the municipal maps (`no_munic = 1`). In the
aggregations:

- **Provinces:** they are assigned to the province (SIANE 2005) that
  contains the polygon.
- **Judicial districts and electoral districts:** they are assigned to
  the unit of their province with which they share the longest boundary.

### Canary Islands

Coordinates are real by default. All functions have the option
`moveCAN = TRUE`, which moves the Canary Islands next to the Peninsula
exactly as the **mapSpain** package does. In these maps it is advisable
to draw the box that separates the islands, with
[`mapSpain::esp_get_can_box()`](https://ropenspain.github.io/mapSpain/reference/esp_get_can_box.html).

## 3. Higher-level units

| Unit | Censuses / elections | Source |
|----|----|----|
| Provinces | 1900-2001 | INE municipality code (first 2 digits) |
| Judicial districts | 1900, 1910, 1920, 1930 | INE censuses (PJ variable) and secondary sources |
| Districts for the Cortes (Restoration) | 1920 (municipalities of the 1920 census) | [Congreso de los Diputados](https://ccuc.csuc.cat/permalink/34CSUC_NETWORK/ian09j/alma991020986739706706) |
| Constituencies (Second Republic) | 1931, 1933, 1936 (municipalities of the 1930 census) | INE censuses and secondary sources to determine the municipalities that belonged to the constituencies of large cities; the rest belonged to the provincial constituency |

Unit codes: 2 province digits + 2 unit digits in alphabetical order
within the province (judicial districts have the same code in every
census). Melilla was not assigned to any district for the Cortes in
1920.

## 4. Sources

- **Reference municipal boundaries:** SIANE (© Instituto Geográfico
  Nacional, CC BY 4.0), 2005 division, through the R package
  **mapSpain**.
- **Municipal maps of 1900, 1930, 1950 and 1970:** own reconstruction
  from the previous source (see section 1).
- **Census figures (1842-2011):** population censuses of the INE.
- **Municipal changes:** *Variaciones de los municipios de España desde
  1842* (Ministerio de Administraciones Públicas, MINAP).
- **Electoral districts for the Cortes in 1920:**
  <https://ccuc.csuc.cat/permalink/34CSUC_NETWORK/ian09j/alma991020986739706706>
- **Judicial districts and constituencies of the Second Republic:**
  information from the INE censuses and other secondary sources.

## 5. Licenses and citation

- **Package code:** MIT license.
- **Data** (geometries and the `censos` and `unitats` tables): Creative
  Commons Attribution 4.0 International license (CC BY 4.0).

If you use the package and/or its data, please cite them
(`citation("mapSpainHist")`):

- Vall Prat, P. (2026). *Historical municipal boundaries of Spain,
  1900-2001* \[Data set\]. Zenodo.
  <https://doi.org/10.5281/zenodo.23663208>
