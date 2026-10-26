## Resubmission

This is a resubmission. In this version I have:

* Replaced the relative links in README.md to files that are not part of the
  package (README.es.md, README.ca.md, LICENSE.md) with absolute URLs to the
  GitHub repository.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new release.

## Test environments

* Local: Windows 11, R 4.5.1 (`R CMD check --as-cran`, including `--run-donttest`).
* GitHub Actions: windows-latest (R release), macos-latest (R release),
  ubuntu-latest (R devel, release and oldrel-1).
* macOS builder: R-release.

## Notes for CRAN

* The package geometries (about 6.5 MB) are not included in the package. They are
  downloaded from a Zenodo deposit (<doi:10.5281/zenodo.23663208>) the first time they
  are needed and cached in `tools::R_user_dir("mapSpainHist", "cache")`; the user can
  choose another directory with the `cache_dir` argument or `mhist_set_cache_dir()`.
* If the download fails (e.g. no internet connection), the functions return `NULL`
  with an informative message instead of an error.
* Examples that need the download are wrapped in `\donttest{}` and write only to
  `tempdir()`. Tests that need the download are skipped on CRAN.
* The data tables `censos` and `unitats` contain Spanish place names with non-ASCII
  (UTF-8) characters.
