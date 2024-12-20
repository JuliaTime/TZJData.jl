# TZJData

[![Build Status](https://github.com/JuliaTime/TZJData.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaTime/TZJData.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

TZJData provides releases of the [IANA tzdata](https://www.iana.org/time-zones) compiled into the tzjfile (time zone julia file) format. The compiled data stored via [package artifacts](https://pkgdocs.julialang.org/v1/artifacts/) and used by the [TimeZones.jl] as an the source of pre-computed time zones.

## Versioning

The TZJData package uses [semantic versioning](https://semver.org/) like any other Julia package. Unlike most Julia packages however the TZJData package also uses build metadata to indicate the associated IANA tzdata release (e.g. TZJData release `1.0.0+2023c` uses tzdata 2023c). Each TZJData release is only associated with a single IANA tzdata release but multiple TZJData releases may correspond to the same IANA tzdata release (i.e. `1.0.0+2023c` and `1.0.1+2023c` both use tzdata 2023c).

In addition to the standard semantic versioning rules used by Julia packages the TZJData package also adheres to the following internal rules: 

1. The build metadata is used to indicate the tzdata version associated with each release (e.g. `2023c`)
2. A minor release MUST be made when the tzdata version used has been updated to a newer version. A update to the tzdata version must be the immediate next release.
3. A major release MUST be made if the tzjfile format is changed in a non-backwards compatible manner
4. A major release MUST be used if it is desired to release older tzdata versions. In such a scenario ALL subsequent tzdata versions should be also be made into new releases to ensure the latest release in this major series is the latest tzdata.

## Usage

The compiled tzjfile data is stored as a series of flat files in the same way zoneinfo is on Linux distributions. Users can read this data via the [TimeZones.jl] package:

```julia
julia> using TZJData

julia> using TimeZones: TZJFile

julia> function load(tzname)
           rel_path = joinpath(split(tzname, '/'))
           return open(TZJFile.read, joinpath(TZJData.artifact_dir(), rel_path), "r")(tzname)
       end
load (generic function with 1 method)

julia> load("Europe/Warsaw")
(tz"Europe/Warsaw", TimeZones.Class(:STANDARD))
```

[TimeZones.jl]: https://github.com/JuliaTime/TimeZones.jl
