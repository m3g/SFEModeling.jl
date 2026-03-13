# deps/build.jl — executed automatically by Pkg.build() / Pkg.Apps.add()
#
# Creates a desktop shortcut for the SFEModeling GUI.
# If shortcut creation fails for any reason (headless server, missing desktop, etc.)
# the build succeeds anyway — the shortcut can always be created manually with:
#
#   using SFEModeling; create_shortcut()

try
    using SFEModeling
    create_shortcut()
catch e
    @warn "SFEModeling: could not create desktop shortcut (run `create_shortcut()` manually)" exception=e
end
