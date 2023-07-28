using LibGit2: GitCommit, GitReference, GitRepo, GitHash, @check, ensure_initialized

# https://libgit2.org/libgit2/#HEAD/group/repository/git_repository_set_head_detached
function git_repository_set_head_detached(repo::GitRepo, oid::GitHash)
    ensure_initialized()
    @assert repo.ptr != C_NULL
    oid_ptr = Ref(oid)
    @check ccall((:git_repository_set_head_detached, :libgit2), Cint,
                 (Ptr{Cvoid}, Ptr{GitHash}),
                 repo.ptr, oid_ptr)
end

function checkout!(repo::GitRepo, ref::GitReference; detach::Bool=false)
    LibGit2.with(LibGit2.peel(GitCommit, ref)) do commit
        LibGit2.checkout_tree(repo, commit)
    end

    if LibGit2.isbranch(ref) && !detach
        LibGit2.head!(repo, ref)
    else
        git_repository_set_head_detached(repo, LibGit2.GitHash(ref))
    end
end

# TODO: Very basic right now
function branch!(repo::GitRepo, branch::GitReference; track::Union{GitReference,Nothing}=nothing)
    track = track !== nothing ? LibGit2.shortname(track) : ""
    return LibGit2.branch!(repo, LibGit2.shortname(branch); track)
end

function push(repo::GitRepo, ref::GitReference; credentials=nothing)
    refspecs = [LibGit2.name(ref)]
    return LibGit2.push(repo; refspecs, credentials)
end

function LibGit2.tag_create(repo::GitRepo, tag_name::AbstractString, commit::GitReference; kwargs...)
    oid = LibGit2.tag_create(repo, tag_name, GitHash(ref); kwargs...)
    return LibGit2.GitTag(repo, oid)
end

"""
Assumes repo isn't dirty and we can cleanly switch branches
"""
function pull_commit_push(
    body,
    repo::GitRepo,
    branch::GitReference;
    message::AbstractString,
    credentials=nothing,
)
    prev_ref = LibGit2.head(repo)
    refspecs = [LibGit2.name(branch)]

    LibGit2.fetch(repo; refspecs, credentials)

    # Create or checkout the specified `branch` then rebase so the local branch
    # is up to date with the remote branch.
    branch!(repo, branch; track=branch)

    upstream_branch = LibGit2.upstream(branch)
    upstream_branch === nothing && error("Branch $branch has no upstream")

    LibGit2.rebase!(repo, LibGit2.name(LibGit2.upstream(branch)))

    try
        body()
        LibGit2.commit(repo, message)
    finally
        if LibGit2.name(prev_ref) != LibGit2.name(branch)
            checkout!(repo, prev_ref)
        end
    end

    push(repo, branch)

    return nothing
end

commit_sha(repo::GitRepo, branch::GitReference) = LibGit2.GitHash(branch)

function commit_sha(repo::AbstractString, branch::AbstractString)
    return LibGit2.with(LibGit2.GitRepo(repo)) do repo
        branch_ref = LibGit2.lookup_branch(repo, branch)
        commit_sha(repo, branch_ref)
    end
end

#=
module Git

struct Repository
    path::String
end

struct Commit
    sha::SHA1
end

struct Tag
    tag_name::String
end

struct Branch
    tag_name::String
end

function commit_sha(repo::Repository, tag::Tag)
    with(GitRepo(repo.path)) do repo

end


repo = LibGit2.GitRepo(".")
ref = LibGit2.lookup_branch(repo, "main")
commit_sha = string(LibGit2.GitHash(ref))
=#
