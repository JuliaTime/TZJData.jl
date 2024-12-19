module TZJData

using Artifacts

# Avoid using a constant to define the artifact directory as this will hardcode the path
# to the location used during pre-compilation which can be problematic if the Julia depot
# relocated afterwards. One scenario where this can occur is when this package is used
# within a system image.
artifact_dir() = artifact"tzjdata"

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
