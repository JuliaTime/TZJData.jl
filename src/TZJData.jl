module TZJData

using Artifacts

const ARTIFACT_DIR = artifact"tzjdata"

artifact_dir() = artifact"tzjdata"

const TZDATA_VERSION = let
    artifact_dict = Artifacts.parse_toml(joinpath(@__DIR__, "..", "Artifacts.toml"))
    url = first(artifact_dict["tzjdata"]["download"])["url"]
    m = match(r"tzdata(?<version>\d{2}\d{2}?[a-z])", url)
    m !== nothing ? m[:version] : error("Unable to determine tzdata version")
end

end
