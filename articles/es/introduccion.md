# Introducción a mapSpainHist

**mapSpainHist** proporciona los límites municipales de España para cada
censo de población entre 1900 y 2001, junto con los datos de esos
censos. Este artículo muestra cómo obtener los mapas, cómo representar
datos en ellos y cómo seguir los cambios municipales a lo largo del
tiempo.

> **Aviso.** La forma de la mayor parte de los municipios históricos es
> una reconstrucción aproximada. Los mapas son útiles sobre todo para
> representar datos municipales; úselos con cautela para variables
> geográficas como la superficie o las distancias. Véase la
> [metodología](https://pauvallprat.github.io/mapSpainHist/articles/es/metodologia.md).

## Instalación y primera carga

``` r

remotes::install_github("pauvallprat/mapSpainHist")
```

``` r

library(mapSpainHist)
library(ggplot2)
```

Los censos disponibles son:

``` r

mhist_census_years()
#>  [1] 1900 1910 1920 1930 1940 1950 1960 1970 1981 1991 2001
```

La función
[`esp_get_munic_hist()`](https://pauvallprat.github.io/mapSpainHist/reference/esp_get_munic_hist.md)
devuelve un objeto `sf` con un polígono para cada municipio vigente en
el censo indicado. La primera vez descarga las geometrías de Zenodo
(unos 6,5 MB) y las guarda en la caché del ordenador; las veces
siguientes las lee directamente del disco.

``` r

m1930 <- esp_get_munic_hist(1930)
nrow(m1930)
#> [1] 9343
head(sf::st_drop_geometry(m1930))
#>   cod_ine no_munic censo        municipio        prov cod_ccaa       ccaa
#> 1   01001        0  1930 Alegría-Dulantzi Araba/Álava       16 País Vasco
#> 2   01002        0  1930          Amurrio Araba/Álava       16 País Vasco
#> 3   01003        0  1930          Aramaio Araba/Álava       16 País Vasco
#> 4   01004        0  1930       Artziniega Araba/Álava       16 País Vasco
#> 5   01006        0  1930          Armiñón Araba/Álava       16 País Vasco
#> 6   01007        0  1930       Arrastaria Araba/Álava       16 País Vasco
#>        PJ hogares pder phec pob_serie
#> 1 Vitoria     146  810  735       810
#> 2 Vitoria     354 1595 1755      1595
#> 3 Vitoria     388 1945 1822      1945
#> 4 Vitoria     287 1108 1230      1108
#> 5 Vitoria      98  446  432       446
#> 6 Vitoria     122  680  655       680
```

Cada fila tiene el código INE del municipio (`cod_ine`), los datos del
censo (nombre, provincia, comunidad autónoma, partido judicial, hogares
y población de derecho y de hecho) y la geometría. Los territorios no
municipales (comunidades de pastos, facerías, etc., con códigos 53xxx)
tienen `no_munic = 1` y no tienen datos del censo; se pueden excluir con
`include_nonmunicipal = FALSE`.

## Un mapa de población

Representamos la población de derecho de cada municipio en 1930. Con
`moveCAN = TRUE` las Canarias se colocan junto a la península, como hace
el paquete **mapSpain**. En estos casos conviene dibujar también el
recuadro que las separa, con
[`mapSpain::esp_get_can_box()`](https://ropenspain.github.io/mapSpain/reference/esp_get_can_box.html).

``` r

m1930 <- esp_get_munic_hist(1930, moveCAN = TRUE)
m1930$poblacion <- cut(
  m1930$pder, c(0, 500, 1000, 2000, 5000, 20000, Inf), right = FALSE,
  labels = c("< 500", "500-999", "1.000-1.999", "2.000-4.999", "5.000-19.999", "20.000 o más")
)

ggplot(m1930) +
  geom_sf(aes(fill = poblacion), colour = NA) +
  scale_fill_viridis_d(option = "magma", direction = -1, na.value = "grey85") +
  geom_sf(data = mapSpain::esp_get_can_box(), colour = "grey50") +
  labs(title = "Población de derecho por municipio, 1930", fill = "Habitantes") +
  theme_void()
```

![Mapa de los municipios de España en 1930 coloreados según la población
de derecho](introduccion_files/figure-html/mapa-1930-1.png)

## Los municipios a lo largo del siglo XX

La tabla `censos` contiene los datos de todos los municipios y de todos
los censos entre 1842 y 2011. Un municipio está vigente en un censo
cuando tiene datos de hogares (`hogares`). Podemos contar cuántos
municipios había en cada censo:

``` r

vig <- censos[!is.na(censos$hogares) & censos$censo %in% mhist_census_years(), ]
table(vig$censo)
#> 
#> 1900 1910 1920 1930 1940 1950 1960 1970 1981 1991 2001 
#> 9267 9262 9255 9262 9257 9214 9201 8653 8023 8076 8108
```

La fuerte reducción de los años 1960 y 1970 corresponde a las fusiones
de municipios de aquellos años. Como cada mapa contiene exactamente los
municipios vigentes en su censo, se pueden seguir estos cambios sobre el
territorio. Por ejemplo, Valdetórtola (Cuenca) se creó en los años 70
con varios municipios y se disolvió en los años 90:

``` r

m81 <- esp_get_munic_hist(1981, epsg = 3035, census_data = FALSE)
zona <- sf::st_buffer(m81[m81$cod_ine == "16907", ], 12000)

mapas <- lapply(c(1970, 1981, 1991), function(y) {
  m <- esp_get_munic_hist(y, epsg = 3035, census_data = FALSE)
  m <- m[lengths(sf::st_intersects(m, zona)) > 0, ]
  m$censo <- y
  m
})
d <- do.call(rbind, mapas)

ggplot(d) +
  geom_sf(aes(fill = cod_ine == "16907"), colour = "grey30", linewidth = 0.2) +
  scale_fill_manual(values = c(`FALSE` = "grey92", `TRUE` = "tomato"),
                    labels = c("Otros municipios", "Valdetórtola"), name = NULL) +
  facet_wrap(~censo) +
  theme_void()
```

![Tres mapas (1970, 1981 y 1991) de la zona de Valdetórtola, en Cuenca,
que solo existe en
1981](introduccion_files/figure-html/valdetortola-1.png)

## Añadir datos propios

Para representar datos propios (por ejemplo, resultados electorales o
datos de otro censo), basta con unirlos por el código INE, `cod_ine`,
que es un texto de 5 cifras:

``` r

datos <- read.csv("datos_municipales_1930.csv", colClasses = c(cod_ine = "character"))
m1930 <- merge(esp_get_munic_hist(1930), datos, by = "cod_ine", all.x = TRUE)
```

Para agregar datos a provincias, partidos judiciales o distritos
electorales, véase el artículo [Unidades superiores y agregación de
datos](https://pauvallprat.github.io/mapSpainHist/articles/es/unidades.md).

## Caché

Las geometrías se guardan en la carpeta que devuelve
[`mhist_cache_dir()`](https://pauvallprat.github.io/mapSpainHist/reference/mhist_cache_dir.md).
Se puede cambiar para la sesión con
[`mhist_set_cache_dir()`](https://pauvallprat.github.io/mapSpainHist/reference/mhist_cache_dir.md)
o con el argumento `cache_dir` de las funciones, y se puede vaciar con
[`mhist_clear_cache()`](https://pauvallprat.github.io/mapSpainHist/reference/mhist_clear_cache.md).
El argumento `update_cache = TRUE` fuerza una nueva descarga.

``` r

mhist_cache_dir()
#> [1] "/home/runner/.cache/R/mapSpainHist"
```
