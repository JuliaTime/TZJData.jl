using URIs: URI
using ghr_jll: ghr

const GH_RELEASE_ASSET_PATH_REGEX = r"""
    ^/(?<owner>[^/]+)/(?<repo_name>[^/]+)/
    releases/downloads/
    (?<tag>[^/]+)/(?<file_name>[^/]+)$
    """x

function create_tarball(dir, tarball)
    return open(GzipCompressorStream, tarball, "w") do tar
        Tar.create(dir, tar)
    end
end

function artifact_checksums(tarball::AbstractString)
    return open(tarball, "r") do io
        artifact_checksums(io)
    end
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

function upload_to_github_release(
    archive_path::AbstractString,
    archive_url::AbstractString;
    kwargs...
)
    return upload_to_github_release(archive_path, parse(URI, artifact_url); kwargs...)
end

# TODO: Does this work properly with directories?
function upload_to_github_release(archive_path::AbstractString, archive_uri::URI; kwargs...)
    # uri = parse(URI, artifact_url)
    if archive_uri.host != "github.com"
        throw(ArgumentError("Artifact URL is not for github.com: $(archive_uri)"))
    end

    m = match(GH_RELEASE_ASSET_PATH_REGEX, archive_uri.path)
    if m === nothing 
        throw(ArgumentError(
            "Artifact URL is not a GitHub release asset path: $(archive_uri)"
        ))
    end

    # The `ghr` utility uses the local file name for the release asset. In order to have
    # have the asset match the specified URL we'll temporarily rename the file.
    org_archive_name = nothing
    if basename(archive_path) != m[:file_name]
        org_archive_name = basename(archive_path)
        archive_path = mv(archive_path, joinpath(dirname(archive_path), m[:file_name]))
    end

    upload_to_github_release(m[:owner], m[:repo_name], commit, m[:tag], archive_path; kwargs...)

    # Rename the archive back to the original name
    if org_archive_name !== nothing
        mv(archive_path, joinpath(dirname(archive_path), org_archive_name))
    end

    return nothing
end


function upload_to_github_release(owner, repo_name, commit, tag, path; token=ENV["GITHUB_TOKEN"])
    # Based on: https://github.com/JuliaPackaging/BinaryBuilder.jl/blob/d40ec617d131a1787851559ef1a9f04efce19f90/src/AutoBuild.jl#L487
    # TODO: Passing in a directory path uploads multiple assets
    # TODO: Would be nice to perform parallel uploads
    cmd = ```
        $(ghr()) \
        -owner $owner \
        -repository $repo_name \
        -commitish $commit \
        -token $token \
        $tag $path
    ```

    run(cmd)
end

if abspath(PROGRAM_FILE) == @__FILE__
    tzdata_version = "2023c"

    # Build tzjfile artifact content
    TZData.cleanup(tzdata_version, _scratch_dir())
    compiled_dir = TZData.build(tzdata_version, _scratch_dir())

    tarball_path = joinpath(tempdir(), "tzjfile-v1-tzdata$(tzdata_version).tar.gz")
    create_tarball(compiled_dir, tarball_path)

    pkg_url = "https://github.com/JuliaTime/TZJFileData.jl"
    tag = "v0.0.1"
    artifact_url = "$(pkg_url)/releases/download/$(tag)/tzjfile-v1-tzdata$(tzdata_version).tar.gz"

    artifacts_toml = joinpath(@__DIR__, "..", "Artifacts.toml")
    bind_artifact!(
        artifacts_toml,
        "tzjfile",
        tree_hash_sha1(tarball_path);
        download_info=[(artifact_url, sha256sum(tarball_path))],
        force=true,
    )

    # TODO: Ensure no other files are staged
    # TODO:

    LibGit2.with(LibGit2.GitRepo(joinpath(@__DIR__, "..")) do repo
        LibGit2.add!(repo, basename(artifacts_toml))
        LibGit2.commit(repo, message)

        # TODO: Expecting users to have their branch up to date. Pushing outdated
        # branches will fail like normal git CLI
        LibGit2.push(repo; refspecs, credentials)
    end

    upload_to_github_release(tarball_path, artifact_url)
end


