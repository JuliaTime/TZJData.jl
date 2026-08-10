module TZJData

using Artifacts

# Store the relocatable artifact identity rather than the depot-specific path. Resolve
# it at runtime, with artifact overrides, without the world-age trampoline emitted by
# the `artifact"..."` macro.
const _ARTIFACT_HASH = let
    artifacts_toml = joinpath(@__DIR__, "..", "Artifacts.toml")
    hash = Artifacts.artifact_hash("tzjdata", artifacts_toml)
    hash === nothing && error("Unable to determine tzjdata artifact hash")
    hash
end

artifact_dir() = Artifacts.artifact_path(_ARTIFACT_HASH)

# Deprecation for TZJData.jl v1
Base.@deprecate_binding ARTIFACT_DIR artifact_dir() false

const TZDATA_VERSION = let
    artifact_dict = Artifacts.parse_toml(joinpath(@__DIR__, "..", "Artifacts.toml"))
    url = first(artifact_dict["tzjdata"]["download"])["url"]
    m = match(r"tzdata(?<version>\d{2}\d{2}?[a-z])", url)
    m !== nothing ? m[:version] : error("Unable to determine tzdata version")
end

precompile(artifact_dir, ())

end
