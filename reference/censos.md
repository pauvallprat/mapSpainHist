# Census figures of Spanish municipalities, 1842-2011

Population census data for every municipality and census edition, from
`Municipis_Espanya_1842-2011.xlsx`. A municipality is in force at a
census when `hogares` is not missing. Rows with `no_munic == 1` are the
non-municipal territories (codes 53xxx) present in the maps, which have
no census figures.

## Usage

``` r
censos
```

## Format

A data frame with columns:

- cod_ine:

  INE municipality code (5 characters; 6 for municipalities extinct
  before 1900).

- censo:

  Census year.

- municipio:

  Municipality name.

- prov:

  Province.

- cod_ccaa, ccaa:

  Autonomous community code and name.

- PJ:

  Judicial district (partido judicial).

- hogares:

  Households.

- pder:

  De jure population.

- phec:

  De facto population.

- pob_serie:

  Continuous population series.

- no_munic:

  1 for non-municipal territories (53xxx), 0 otherwise.
