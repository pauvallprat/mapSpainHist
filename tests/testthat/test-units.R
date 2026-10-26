test_that("les províncies cobreixen el mateix territori que els municipis", {
  skip_if_no_geometries()
  m <- esp_get_munic_hist(1950, census_data = FALSE)
  p <- esp_get_prov_hist(1950, census_data = FALSE)
  expect_equal(nrow(p), 52)
  expect_equal(sum(as.numeric(sf::st_area(p))), sum(as.numeric(sf::st_area(m))), tolerance = 1e-6)
})

test_that("PJ i circumscripcions tenen codi de 4 dígits que comença per la província", {
  skip_if_no_geometries()
  pj <- esp_get_pj_hist(1910)
  ci <- esp_get_circ_hist(1933)
  expect_true(all(grepl("^[0-9]{4}$", pj$cod_unit)))
  expect_true(all(grepl("^[0-9]{4}$", ci$cod_unit)))
  expect_false(any(duplicated(pj$cod_unit)))
  expect_true(all(c("Lucena del Cid", "San Sebastián de La Gomera") %in% pj$nom))
})

test_that("les unitats no se solapen", {
  skip_if_no_geometries()
  ci <- sf::st_transform(esp_get_circ_hist(1920, census_data = FALSE), 3035)
  rel <- sf::st_relate(ci, ci, pattern = "2********")
  expect_true(all(lengths(rel) == 1))
})

test_that("cada municipi té una sola unitat per tipus i any", {
  d <- unitats[unitats$tipus == "pj" & unitats$any == 1930, ]
  expect_false(any(duplicated(d$cod_ine)))
})

test_that("anys no disponibles donen error", {
  expect_error(esp_get_pj_hist(1950))
  expect_error(esp_get_circ_hist(1930))
})

test_that("moveCAN funciona per a les unitats", {
  skip_if_no_geometries()
  a <- esp_get_prov_hist(1930, census_data = FALSE)
  b <- esp_get_prov_hist(1930, census_data = FALSE, moveCAN = TRUE)
  expect_gt(sf::st_bbox(b)[["ymin"]], sf::st_bbox(a)[["ymin"]])
})

test_that("els mapes del paquet no tenen forats interiors ni són invàlids en s2", {
  skip_if_no_geometries()
  m <- esp_get_munic_hist(1930, census_data = FALSE)
  expect_true(all(s2::s2_is_valid(m)))
  u <- sf::st_union(sf::st_transform(m, 3035))
  rings <- unlist(lapply(sf::st_cast(sf::st_cast(sf::st_sfc(u), "MULTIPOLYGON"), "POLYGON"), length))
  # anells interiors de la unió = forats (Espanya no en té)
  expect_equal(sum(rings - 1), 0)
})
