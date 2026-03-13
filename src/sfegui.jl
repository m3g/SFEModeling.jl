# ── GUI launcher and CLI entry point ──────────────────────────────────────────

"""
    sfegui(; port=9876, launch=true)

Launch a local web-based GUI for SFEModeling.

Opens a browser window at `http://localhost:\$port` where you can:
- Upload a data file (text or Excel) with time and replicate columns
- Fill in all operating conditions
- Configure optimizer bounds and maximum evaluations
- Run the fitting and see results directly in the browser

Press Ctrl-C in the REPL to stop the server, or call `close(server)` on the
returned `HTTP.Server` object.
"""
function sfegui(; port::Int=9876, launch::Bool=true)
    _start_gui(port, launch)
end

#"""
#    julia -m SFEModeling [--port PORT] [--no-launch] [--create-shortcut]
#
#Launch the SFEModeling GUI as a standalone app.
#
#If `--create-shortcut` is passed, a desktop shortcut is created and the app exits
#without starting the GUI.
#"""
function main(args::Vector{String})
    port = 9876
    launch = true
    do_shortcut = false
    i = 1
    while i <= length(args)
        if args[i] == "--port" && i + 1 <= length(args)
            port = parse(Int, args[i + 1])
            i += 2
        elseif args[i] == "--no-launch"
            launch = false
            i += 1
        elseif args[i] == "--create-shortcut"
            do_shortcut = true
            i += 1
        else
            i += 1
        end
    end
    if do_shortcut
        create_shortcut(; port)
        return 0
    end
    server = sfegui(; port, launch)
    wait(server)
    return 0
end
@main
