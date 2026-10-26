test_that("cada cens té tots els municipis vigents i cap codi repetit", {
  skip_if_no_geometries()
  for (y in c(1900, 1940, 2001)) {
    m <- esp_get_munic_hist(y)
    vig <- censos$cod_ine[censos$censo == y & !is.na(censos$hogares)]
    expect_false(any(duplicated(m$cod_ine)))
    expect_true(all(vig %in% m$cod_ine))
  }
})

test_that("census_data = FALSE retorna només la geometria i el codi", {
  skip_if_no_geometries()
  m <- esp_get_munic_hist(1930, census_data = FALSE)
  expect_setequal(setdiff(names(m), attr(m, "sf_column")), c("cod_ine", "no_munic"))
})

test_that("moveCAN desplaça només les Canàries", {
  skip_if_no_geometries()
  a <- esp_get_munic_hist(1950, census_data = FALSE)
  b <- esp_get_munic_hist(1950, census_data = FALSE, moveCAN = TRUE)
  can <- substr(a$cod_ine, 1, 2) %in% c("35", "38")
  expect_equal(sf::st_coordinates(a[!can, ][1, ]), sf::st_coordinates(b[!can, ][1, ]))
  expect_gt(sf::st_bbox(b[substr(b$cod_ine, 1, 2) == "38", ])[["xmin"]],
            sf::st_bbox(a[can, ])[["xmin"]])
})

test_that("un any que no és de cens dona error", {
  expect_error(esp_get_munic_hist(1975))
})
