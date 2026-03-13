# deps/build.jl — executed automatically by Pkg.build() / Pkg.Apps.add()
#
# Creates a desktop shortcut for the SFEModelling GUI.
# If shortcut creation fails for any reason (headless server, missing desktop, etc.)
# the build succeeds anyway — the shortcut can always be created manually with:
#
#   using SFEModelling; create_shortcut()

try
    using SFEModelling
    create_shortcut()
catch e
    @warn "SFEModelling: could not create desktop shortcut (run `create_shortcut()` manually)" exception=e
end
