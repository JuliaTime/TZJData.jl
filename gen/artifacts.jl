using TOML: TOML

const PKG_ROOT = joinpath(@__DIR__(), "..")

function gh_artifact(artifact_toml=joinpath(PKG_ROOT, "Artifacts.toml"))
    toml = TOML.parsefile(artifact_toml)
    tarball_artifact = only(toml["tzjdata"]["download"])
    tarball_filename = basename(tarball_artifact["url"])
    tarball_sha256 = tarball_artifact["sha256"]
    content_hash = toml["tzjdata"]["git-tree-sha1"]

    key = "$(tarball_filename)-$(tarball_sha256)"
    return (;
        tarball_filename,
        tarball_sha256,
        content_hash,
        key,
    )
end
