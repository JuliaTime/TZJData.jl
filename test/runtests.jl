using Artifacts: Artifacts
using Base: SHA1
using CodecZlib: GzipDecompressorStream
using Pkg.Types: read_project
using SHA: sha256
using TZJData
using Tar: Tar
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

# Compute the Artifact.toml `git-tree-sha1`.
function tree_hash_sha1(tarball_path)
    return open(GzipDecompressorStream, tarball_path, "r") do tar
        SHA1(Tar.tree_hash(tar))
    end
end

# Compute the Artifact.toml `sha256` from the compressed archive.
function sha256sum(tarball_path)
    return open(tarball_path, "r") do tar
        bytes2hex(sha256(tar))
    end
end

@testset "TZJData.jl" begin
    @test isdir(TZJData.ARTIFACT_DIR)
    @test occursin(r"^\d{4}[a-z]$", TZJData.TZDATA_VERSION)

    @testset "validate unpublished artifact" begin
        artifact_toml = get(ENV, "TZJDATA_ARTIFACT_TOML", nothing)
        tarball_path = get(ENV, "TZJDATA_TARBALL_PATH", nothing)
        if !isnothing(artifact_toml) && !isnothing(tarball_path)
            project = read_project(joinpath(@__DIR__(), "..", "Project.toml"))
            artifacts = Artifacts.parse_toml(artifact_toml)

            @test artifacts["tzjdata"]["git-tree-sha1"] == tree_hash_sha1(tarball_path)
            @test length(artifacts["tzjdata"]["download"]) == 1
            @test artifacts["tzjdata"]["download"][1]["sha256"] == sha256sum(tarball_path)

            url = artifacts["tzjdata"]["download"][1]["url"]
            @test contains(url, "/v$(project.version)/")
            @test basename(url) == basename(tarball_path)
            @test contains(basename(url), r"tzdata(?<version>\d{2}\d{2}?[a-z])")
        end
    end

    @testset "load compiled" begin
        cache = Dict{String,Tuple{TimeZone,Class}}()
        _reload_cache!(cache, TZJData.ARTIFACT_DIR)
        @test !isempty(cache)
    end

    # TODO: Check for changes to a `TimeZone`'s `Class` as a change from `Class(:STANDARD)`
    # to `Class(:LEGACY)` can cause end-users code to break.
end
