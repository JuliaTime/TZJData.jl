using Base: SHA1
using CodecZlib: GzipCompressorStream, GzipDecompressorStream
using Pkg.Artifacts: bind_artifact!
using SHA: SHA
using Tar: Tar
using TimeZones: TZData, _scratch_dir
using LibGit2: LibGit2, GitReference, GitRepo

include("libgit2.jl")
#=
1. Create artifact
2. Bind artifact to Artifact.toml
3. Commit Artifact.toml to package repo
4. Push commit to remote repo
5. Tag commit
6. Upload artifact as GitHub release asset
7. Register

Requirements:
- local package repo
- remote repo url
- tag
- artifact
- credentials



=#

function commit_push_pkg_artifact(
    body,
    repo_dir::AbstractString,
    branch::AbstractString="main";
    kwargs...
)
    repo = GitRepo(repo_dir)
    branch_ref = LibGit2.lookup_branch(repo, branch)
    return commit_push_pkg_artifact(body, repo, branch_ref; kwargs...)
end

function commit_push_pkg_artifact(
    body,
    repo::GitRepo,
    branch::GitReference;
    artifacts_toml_filename::AbstractString="Artifacts.toml",
    message::AbstractString="Updated $artifacts_toml_filename",
    credentials=nothing,
)
    pull_commit_push(repo, branch; message, credentials) do
        artifacts_toml = joinpath(LibGit2.path(repo), artifacts_toml_filename)
        result = body(artifacts_toml)
        LibGit2.add!(repo, artifacts_toml_filename)
    end

    return nothing
end

function upload_to_github_release_assets(repo_url, tag, commit, path; token=ENV["GITHUB_TOKEN"])
    owner = basename(dirname(repo_url))
    repo_name = basename(repo_url)

    # commit_sha = LibGit2.GitHash(ref)

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

version = "2023c"
TZData.cleanup(version, _scratch_dir())
compiled_dir = TZData.build(version, _scratch_dir())
tarball = "tzjfile-v1-tzdata$(version).tar.gz"

open(GzipCompressorStream, tarball, "w") do tar
    Tar.create(compiled_dir, tar)
end

git_tree_sha1 = open(GzipDecompressorStream, tarball, "r") do tar
    SHA1(Tar.tree_hash(tar))
end

# Compute the `sha256` of the archive.
sha256 = bytes2hex(open(SHA.sha256, tarball))

url = "https://foo"

repo_url = "https://github.com/JuliaTime/TZJFileData.jl"

tag = "v0.0.1"

# The future location the artifact will be available from
artifact_url = "$(repo_url)/releases/download/$(tag)"
#=
repo = "/Users/cvogt/.julia/dev/TZJFileData"
branch = "cv/wip"
commit_push_pkg_artifact(repo, branch) do artifacts_toml
    bind_artifact!(
        artifacts_toml,
        "tzjfile",
        git_tree_sha1;
        download_info=[(artifact_url, sha256)],
        force=true,
    )
end

###

commit = commit_sha(repo, branch)
upload_to_github_release_assets(repo_url, tag, commit, tarball)
=#

####

mutable struct Artifact
    name::String
    path::Union{String,Nothing}  # compressed archive
    url::String
    sha256::Union{Vector{UInt8}, Nothing}
    git_tree_sha1::Union{SHA1, Nothing}
end


RegexMatch("/JuliaTime/TZJFileData.jl/releases/downloads/v0.0.1/foo", org="JuliaTime", repo="TZJFileData.jl", tag="v0.0.1", filename="foo")
    artifact_url = "$(repo_url)/releases/download/$(tag)/tzjfile-v1-tzdata$(tzdata_version).tar.gz"

function create_artifact_tarball(content_dir, name, url; tarball_dir=tempdir())
    tarball = joinpath(tarball_dir, basename(url))

    open(GzipCompressorStream, tarball, "w") do tar
        Tar.create(content_dir, tar)
    end

    # Compute the SHA-1 of the tree content.
    git_tree_sha1 = open(GzipDecompressorStream, tarball, "r") do tar
        SHA1(Tar.tree_hash(tar))
    end

    # Compute the SHA-256 of the archive.
    sha256 = open(SHA.sha256, tarball)

    return Artifact(name, tarball, url, sha256, git_tree_sha1)
end

tzdata_version = "2023c"
pkg_url = "https://github.com/JuliaTime/TZJFileData.jl"
tag = "v0.0.1"

# The future location the artifact will be available from
artifact_url = "$(repo_url)/releases/download/$(tag)/tzjfile-v1-tzdata$(tzdata_version).tar.gz"

TZData.cleanup(tzdata_version, _scratch_dir())
compiled_dir = TZData.build(tzdata_version, _scratch_dir())

artifact = create_artifact_tarball(compiled_dir, "tzjfile", artifact_url)


bind_artifact!(
    artifacts_toml,
    "tzjfile",
    git_tree_sha1;
    download_info=[(artifact_url, sha256)],
    force=true,
)


#=
git init --bare foo.git
git clone foo.git bar
cd bar
git commit --allow-empty -m "Initial commit"
git checkout -b main
git push origin

git reset --hard 16ad967
git push origin --force-with-lease
=#

#=
function push_pkg_artifact(
    repo_dir::AbstractString,
    artifacts_toml_filename="Artifact.toml";
    message=nothing,
)
    artifacts_toml = joinpath(repo_dir, artifacts_toml_filename)

    repo = LibGit2.GitRepo(repo_dir)

    LibGit2.add!(repo, artifacts_toml_filename)
    commit = LibGit2.commit(repo, "Updated $artifacts_toml_filename")

    refspecs = [LibGit2.name(LibGit2.head(repo))]
    LibGit2.push(repo; refspecs, credentials)
end


function (
    pkg_dir,  # package dir with remote URL
    remote_name="origin",
    tag,  # Tag for the release
    branch,  # Where to add the commit

)
end


function upload_to_github_release_assets(repo, tag, path; token=ENV["GITHUB_TOKEN"])
    owner = basename(dirname(repo))
    repo_name = basename(repo)

    # Based on: https://github.com/JuliaPackaging/BinaryBuilder.jl/blob/d40ec617d131a1787851559ef1a9f04efce19f90/src/AutoBuild.jl#L487
    # TODO: Passing in a directory path uploads multiple assets
    # TODO: Would be nice to perform parallel uploads
    run(`$(ghr()) -owner $owner -repository $repo_name -token $token $tag $path`)
end

function git_remote_url(code_dir, remote_name="origin")
    git_repo = LibGit2.GitRepo(code_dir)
    git_remote = LibGit2.lookup_remote(git_repo, "origin")
    return LibGit2.url(git_remote)
end

function push_package(name)

function push_package(
    name,
    build_version;
    code_dir=joinpath(Pkg.devdir(), name),
    deploy_repo=git_remote_url(code_dir),
    gh_auth = Wizard.github_auth(; allow_anonymous=false),
    gh_username = gh_get_json(DEFAULT_API, "/user"; auth=gh_auth)["login"]
)
    git_repo = LibGit2.GitRepo(code_dir)
    LibGit2.add!(wrapper_repo, ".")
    commit = LibGit2.commit(wrapper_repo, "$(name)_jll build $(build_version)")
    Wizard.with_gitcreds(gh_username, gh_auth.token) do creds
        refspecs = ["refs/heads/main"]
        # Fetch the remote repository, to have the relevant refspecs up to date.
        LibGit2.fetch(
            wrapper_repo;
            refspecs=refspecs,
            credentials=creds,
        )
        LibGit2.branch!(wrapper_repo, "main", string(LibGit2.GitHash(commit)); track="main")
        LibGit2.push(
            wrapper_repo;
            refspecs=refspecs,
            remoteurl="https://github.com/$(deploy_repo).git",
            credentials=creds,
        )
    end
end


function f(;
    tzdata_version::AbstractString
    project_toml::AbstractString=joinpath(@__DIR__, "..", "Project.toml"),
    artifacts_toml::AbstractString=joinpath(@__DIR__, "..", "Artifacts.toml"),
)
    TZData.cleanup(version, _scratch_dir())

    # TODO: Specify the format and version desired
    compiled_dir = TZData.build(version, _scratch_dir())

    # Create the artifact tarball locally
    tarball = "tzdata$(version)_tzjf_v1.tar.gz"
    open(GzipCompressorStream, tarball, "w") do tar
        Tar.create(compiled_dir, tar)
    end

    # Determine the SHA1 ...
    artifact_hash = open(GzipDecompressorStream, tarball, "r") do tar
        SHA1(Tar.tree_hash(tar))
    end

    # Compute the `sha256` of the archive.
    archive_sha = bytes2hex(open(sha256, tarball))

    url = "https://foo"
end

function g(repo, release)
    open(GzipCompressorStream, tarball, "w") do tar
        Tar.create(compiled_dir, tar)
    end

    # Determine the SHA1 ...
    artifact_hash = open(GzipDecompressorStream, tarball, "r") do tar
        SHA1(Tar.tree_hash(tar))
    end

    # Compute the `sha256` of the archive.
    archive_sha = bytes2hex(open(sha256, tarball))

    url = "https://foo"

    ghr() do ghr_path
        run(`$ghr_path -u $(dirname(repo)) -r $(basename(repo)) -t $(gh_auth.token) $(tag) $(path)`)
    end

    unbind_artifact!(artifacts_toml, name)
bind_artifact!(
    artifacts_toml,
    name,
    artifact_hash;
    download_info=[(url, archive_sha)],
)


artifacts_toml = joinpath(@__DIR__, "..", "Artifacts.toml")

name = "tzjf"

=#

