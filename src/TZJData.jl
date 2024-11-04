module TZJData

using Artifacts

artifact_dir() = artifact"tzjdata"
Base.@deprecate_binding ARTIFACT_DIR artifact_dir() false
# Why not simply use `const ARTIFACT_DIR = artifact"tzjdata"`?
# The problem is that `ARTIFACT_DIR` would be set to the artifact path at the time of precompilation.
# If the Julia depot is afterwards relocated,
# ARTIFACT_DIR will continue to point to the old no-longer-valid location.
# This occurs for example if TimeZones.jl is included inside a system image.

const TZDATA_VERSION = let
    artifact_dict = Artifacts.parse_toml(joinpath(@__DIR__, "..", "Artifacts.toml"))
    url = first(artifact_dict["tzjdata"]["download"])["url"]
    m = match(r"tzdata(?<version>\d{2}\d{2}?[a-z])", url)
    m !== nothing ? m[:version] : error("Unable to determine tzdata version")
end

precompile(artifact_dir, ())
# `@deprecate_binding ARTIFACT_DIR artifact_dir()`
# will have already precompiled `artifact_dir()`
# but once the deprecated binding is removed
# an explicit precompile statement will be necessary.

end
