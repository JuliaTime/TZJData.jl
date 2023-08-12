using TZJData
using TimeZones: TZJFile, TimeZone, Class
using Test

# TODO: Can be removed once this is in an official TimeZones release
function _reload_cache!(cache::AbstractDict, compiled_dir::AbstractString)
    empty!(cache)
    check = Tuple{String,String}[(compiled_dir, "")]

    for (dir, partial) in check
        for filename in readdir(dir)
            startswith(filename, ".") && continue

            path = joinpath(dir, filename)
            name = isempty(partial) ? filename : join([partial, filename], "/")

            if isdir(path)
                push!(check, (path, name))
            else
                cache[name] = open(TZJFile.read, path, "r")(name)
            end
        end
    end

    return cache
end

@testset "TZJData.jl" begin
    @test isdir(TZJData.ARTIFACT_DIR)
    @test occursin(r"^\d{4}[a-z]$", TZJData.TZDATA_VERSION)

    @testset "load compiled" begin
        cache = Dict{String,Tuple{TimeZone,Class}}()
        _reload_cache!(cache, TZJData.ARTIFACT_DIR)
        @test !isempty(cache)
    end

    # TODO: Check for changes to a `TimeZone`'s `Class` as a change from `Class(:STANDARD)`
    # to `Class(:LEGACY)` can cause end-users code to break.
end
