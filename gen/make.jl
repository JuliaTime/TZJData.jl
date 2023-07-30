using Base: SHA1
using CodecZlib: GzipCompressorStream, GzipDecompressorStream
using LibGit2: LibGit2
using Pkg.Artifacts: bind_artifact!
using Pkg.Types: read_project, write_project
using TimeZones: TZData, _scratch_dir
using TimeZones.TZData: tzdata_latest_version
using SHA: sha256
using Tar: Tar
using TOML: TOML
using URIs: URI
using ghr_jll: ghr

const GH_RELEASE_ASSET_PATH_REGEX = r"""
    ^/(?<owner>[^/]+)/(?<repo_name>[^/]+)/
    releases/download/
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

function remote_url(repo_root::AbstractString, name::AbstractString="origin")
    return LibGit2.with(LibGit2.GitRepo(repo_root)) do repo
        LibGit2.with(LibGit2.lookup_remote(repo, name)) do remote
            LibGit2.url(remote)
        end
    end
end

function upload_to_github_release(
    archive_path::AbstractString,
    archive_url::AbstractString,
    commit;
    kwargs...
)
    return upload_to_github_release(archive_path, parse(URI, artifact_url), commit; kwargs...)
end

# TODO: Does this work properly with directories?
function upload_to_github_release(archive_path::AbstractString, archive_uri::URI, commit; kwargs...)
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

# TODO: Re-running always bumps version
if abspath(PROGRAM_FILE) == @__FILE__
    tzdata_version = tzdata_latest_version()
    tarball_name = "tzjfile-v1-tzdata$(tzdata_version).tar.gz"

    # Build tzjfile artifact content
    # TZData.cleanup(tzdata_version, _scratch_dir())
    compiled_dir = TZData.build(tzdata_version, _scratch_dir())

    @info "Creating tarball $tarball_name"
    tarball_path = joinpath(tempdir(), tarball_name)
    create_tarball(compiled_dir, tarball_path)

    repo_path = joinpath(@__DIR__, "..")
    pkg_url = remote_url(repo_path)

    # Read Project.toml
    project_path = joinpath(repo_path, "Project.toml")
    project = read_project(project_path)
    old_version = project.version
    new_version = Base.nextpatch(project.version)

    # Include tzdata version in build number
    new_version = VersionNumber(
        new_version.major,
        new_version.minor,
        new_version.patch,
        (),
        ("tzdata$(tzdata_version)",),
    )

    @info "Bumping package $(project.name) from $old_version -> $new_version"
    project.version = new_version
    write_project(project, project_path)

    tag = "v$(new_version)"
    artifact_url = "$(pkg_url)/releases/download/$(tag)/$(basename(tarball_path))"

    artifacts_toml = joinpath(repo_path, "Artifacts.toml")
    bind_artifact!(
        artifacts_toml,
        "tzjdata",
        tree_hash_sha1(tarball_path);
        download_info=[(artifact_url, sha256sum(tarball_path))],
        force=true,
    )

    # TODO: Ensure no other files are staged before committing
    @info "Committing and pushing Project.toml and Artifact.toml"
    branch = "main"
    message = "Use tzdata$(tzdata_version)"

    # TODO: ghr and LibGit2 use different credential setups. Double check
    # what BB does here.
    Base.shred!(LibGit2.CredentialPayload()) do credentials
        LibGit2.with(LibGit2.GitRepo(repo_path)) do repo
            # TODO: This allows empty commits
            LibGit2.add!(repo, basename(artifacts_toml))
            LibGit2.add!(repo, basename(project_path))
            LibGit2.commit(repo, message)

            # Same as "refs/heads/$branch" but fails if branch doesn't exist locally
            branch_ref = LibGit2.lookup_branch(repo, branch)
            refspecs = [LibGit2.name(branch_ref)]

            # TODO: Expecting users to have their branch up to date. Pushing outdated
            # branches will fail like normal git CLI
            LibGit2.push(repo; refspecs, credentials)
        end
    end

    upload_to_github_release(tarball_path, artifact_url, branch)
end


