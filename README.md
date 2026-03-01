# microG integration (requirement 10*)

This repo integrates microG into the build as a GApps-equivalent, built from source synced by `repo`.

## How it works

* Sources are fetched by repo into `vendor/maleicacid/microg/upstream/GmsCore`.
* Soong runs Gradle via `genrule` to build APKs from that source (allowed by requirement 10*).
* Soong imports the generated APKs via `android_app_import`.
