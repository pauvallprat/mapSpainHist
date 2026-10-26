# Clear the cache of mapSpainHist

Deletes the downloaded geometries, which will be downloaded again the
next time they are needed.

## Usage

``` r
mhist_clear_cache(cache_dir = NULL)
```

## Arguments

- cache_dir:

  Path of the cache directory. If \`NULL\`, returns the current one.

## Value

\`TRUE\` invisibly if a file was deleted, \`FALSE\` otherwise.

## Examples

``` r
# \donttest{
mhist_clear_cache(tempdir())
# }
```
