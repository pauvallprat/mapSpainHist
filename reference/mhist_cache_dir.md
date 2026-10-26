# Cache directory of mapSpainHist

The geometries are downloaded from Zenodo the first time they are needed
and stored in a cache directory. By default it is the user cache
directory given by
[`tools::R_user_dir()`](https://rdrr.io/r/tools/userdir.html). It can be
changed for the session with `mhist_set_cache_dir()` or with the
`cache_dir` argument of the `esp_get_*_hist()` functions.

## Usage

``` r
mhist_cache_dir(cache_dir = NULL)

mhist_set_cache_dir(cache_dir)
```

## Arguments

- cache_dir:

  Path of the cache directory. If `NULL`, returns the current one.

## Value

The path of the cache directory (invisibly for `mhist_set_cache_dir()`).

## Examples

``` r
mhist_cache_dir()
#> [1] "/home/runner/.cache/R/mapSpainHist"
# \donttest{
old <- mhist_set_cache_dir(tempdir())
options(mapSpainHist.cache_dir = NULL)
# }
```
