# Metodología, fuentes y advertencias

## Aviso importante sobre el uso de los datos

**La forma de los municipios es aproximada.** Para la mayor parte de los
municipios históricos que ya no existen no se dispone de cartografía de
sus límites. Los polígonos se han reconstruido de manera aproximada y,
por tanto:

- Los mapas son **útiles especialmente para hacer representaciones
  gráficas de datos a nivel municipal**.
- **Deben usarse con cautela** cuando lo que se quiere tener en cuenta
  son **variables geográficas** como la **superficie** de los
  municipios, las **distancias** a otros puntos, la contigüidad precisa
  o la ubicación exacta de las fronteras.
- Son una **aproximación útil pero imperfecta**, y esto debe tenerse
  presente en cualquier análisis.

Lo mismo se aplica a las unidades superiores (partidos judiciales y
distritos electorales), que se construyen agregando los municipios.

## 1. Construcción de los polígonos municipales

1.  **Punto de partida.** Se tomó la división municipal más antigua
    disponible con límites oficiales, de principios de los años 2000
    (SIANE, Instituto Geográfico Nacional, distribuida por el paquete de
    R **mapSpain**).
2.  **Reconstrucción para cada censo.** A partir de esta división se
    generó, de manera aproximada y manual, un polígono para cada uno de
    los municipios existentes en cada censo (mapas de 1900, 1930, 1950 y
    1970):
    - Cuando un municipio actual es el resultado de la fusión de varios
      municipios históricos, su territorio se dividió entre los
      municipios antiguos.
    - La forma del polígono se dibujó procurando siempre que la **cabeza
      de municipio** (el núcleo habitado que generalmente da nombre al
      municipio) quedara incluida dentro del polígono.
    - Cuando se conocían los **núcleos que formaban parte del
      municipio**, también se procuró que quedaran incluidos dentro del
      polígono.
3.  **Municipios vigentes.** Los municipios de cada censo son los que
    tienen datos de hogares en la serie de censos del Instituto Nacional
    de Estadística (INE).

## 2. Coherencia entre censos y topología

Los mapas reconstruidos a mano contenían pequeños solapamientos y huecos
entre polígonos (imperceptibles a simple vista), y los límites de un
mismo municipio no siempre coincidían exactamente entre mapas. Para que
las agregaciones (provincias, partidos judiciales, distritos) no tengan
huecos, el proceso de construcción de los datos hace lo siguiente:

1.  **Limpieza de cada mapa.** Las zonas solapadas se reparten
    equitativamente entre los municipios implicados (cada punto va al
    municipio con la frontera más próxima) y los huecos pequeños se
    rellenan por expansión equitativa de las fronteras vecinas.
2.  **Partición en unidades mínimas.** Todas las fronteras de los mapas
    de 1900, 1930, 1950 y 1970 y del SIANE de 2005 se superponen para
    obtener una partición única del territorio en unidades mínimas. Cada
    unidad tiene un municipio asignado en cada mapa.
3.  **Censos sin mapa manual** (1910, 1920, 1940, 1960, 1981, 1991 y
    2001). Cada unidad se asigna a partir del mapa anterior y el
    posterior, de la vigencia de los municipios en el censo y de las
    variaciones municipales documentadas en el MINAP (*Variaciones de
    los municipios de España desde 1842*), a las que se ha añadido el
    código INE. Para los censos posteriores a 1970 se mantiene el
    trazado del mapa de 1970 salvo que haya un cambio documentado.
4.  **Correcciones manuales.** Algunos casos problemáticos especiales se
    han resuelto a mano (archivos `data-raw/correccions_manuals.csv`,
    `data-raw/parts_desconnectades.csv` y
    `data-raw/manual/territoris_manuals.gpkg`).
5.  **Simplificación.** La partición se simplifica preservando la
    topología (cada frontera compartida se simplifica una sola vez, con
    una tolerancia de 20 m), y los mapas de cada censo se obtienen
    disolviendo las unidades por municipio. Algunas unidades se corrigen
    para que también sean válidas en coordenadas geográficas
    (desplazando unos metros vértices casi coincidentes, siempre en
    todas las unidades que los comparten).

Como todos los mapas proceden de la misma partición, **no tienen huecos
ni solapamientos** y cualquier agregación es exacta.

### Territorios no municipales (53xxx)

Los condominios comunales o territorios mancomunados son unidades
administrativas que no son municipios. Se mantienen como unidades
propias en los mapas municipales (`no_munic = 1`). En las agregaciones:

- **Provincias:** se asignan a la provincia (SIANE 2005) dentro de la
  cual cae el polígono.
- **Partidos judiciales y distritos electorales:** se asignan a la
  unidad de su provincia con la que comparten más frontera.

### Canarias

Las coordenadas son reales por defecto. Todas las funciones tienen la
opción `moveCAN = TRUE`, que desplaza las Canarias junto a la península
exactamente como hace el paquete **mapSpain**. En estos mapas conviene
dibujar el recuadro que separa las islas, con
[`mapSpain::esp_get_can_box()`](https://ropenspain.github.io/mapSpain/reference/esp_get_can_box.html).

## 3. Unidades superiores

| Unidad | Censos / elecciones | Fuente |
|----|----|----|
| Provincias | 1900-2001 | Código INE del municipio (2 primeras cifras) |
| Partidos judiciales | 1900, 1910, 1920, 1930 | Censos del INE (variable PJ) y fuentes secundarias |
| Distritos a Cortes (Restauración) | 1920 (municipios del censo de 1920) | [Congreso de los Diputados](https://ccuc.csuc.cat/permalink/34CSUC_NETWORK/ian09j/alma991020986739706706) |
| Circunscripciones (II República) | 1931, 1933, 1936 (municipios del censo de 1930) | Censos del INE y fuentes secundarias para determinar los municipios que pertenecían a las circunscripciones vinculadas a grandes ciudades; el resto pertenecían a la circunscripción provincial |

Códigos de las unidades: 2 cifras de provincia + 2 cifras de unidad por
orden alfabético dentro de la provincia (los partidos judiciales tienen
el mismo código en todos los censos). Melilla no estaba asignada a
ningún distrito a Cortes en 1920.

## 4. Fuentes

- **Límites municipales de referencia:** SIANE (© Instituto Geográfico
  Nacional, CC BY 4.0), división de 2005, a través del paquete de R
  **mapSpain**.
- **Mapas municipales de 1900, 1930, 1950 y 1970:** reconstrucción
  propia a partir de la fuente anterior (véase la sección 1).
- **Datos de los censos (1842-2011):** censos de población del INE.
- **Variaciones municipales:** *Variaciones de los municipios de España
  desde 1842* (Ministerio de Administraciones Públicas, MINAP).
- **Distritos electorales a Cortes de 1920:**
  <https://ccuc.csuc.cat/permalink/34CSUC_NETWORK/ian09j/alma991020986739706706>
- **Partidos judiciales y circunscripciones de la II República:**
  información de los censos del INE y otras fuentes secundarias.

## 5. Licencias y citación

- **Paquete de R** (código y tablas incluidas `censos` y `unitats`):
  licencia MIT.
- **Depósito de datos en Zenodo** (geometrías, tablas de los censos y
  GeoPackage): licencia Creative Commons Atribución 4.0 Internacional
  (CC BY 4.0).

Si utiliza el paquete y/o sus datos, cítelos. Una forma orientativa de
referenciarlos es la siguiente (`citation("mapSpainHist")`):

- Vall Prat, P. (2026). *Historical municipal boundaries of Spain,
  1900-2001* \[conjunto de datos\]. Zenodo.
  <https://doi.org/10.5281/zenodo.23663208>
