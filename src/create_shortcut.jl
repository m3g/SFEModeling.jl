# ── Desktop shortcut creation ─────────────────────────────────────────────────

"""
    create_shortcut(; location=:desktop, port=9876, name="SFEModeling")

Create a launcher shortcut for the SFEModeling GUI. Supports Windows, macOS, and Linux.

# Keyword arguments
- `location`: where to install the shortcut:
  - Windows: `:desktop` (default) or `:startmenu`
  - macOS:   `:desktop` (default) or `:applications` (`/Applications`)
  - Linux:   `:desktop` (default) or `:applications` (`~/.local/share/applications`)
- `port`: port passed to the app (default: `9876`).
- `name`: shortcut name (default: `"SFEModeling"`).

# Example
```julia
using SFEModeling
create_shortcut()                          # desktop shortcut, default port
create_shortcut(location=:applications)    # app menu entry
create_shortcut(port=8080, name="SFE Fit")
```
"""
function create_shortcut(; location::Symbol=:desktop, port::Int=9876, name::String="SFEModeling")
    if Sys.iswindows()
        _create_shortcut_windows(; location, port, name)
    elseif Sys.isapple()
        _create_shortcut_macos(; location, port, name)
    else
        _create_shortcut_linux(; location, port, name)
    end
end

# Returns the path to the Pkg.Apps-installed binary if present, otherwise nothing.
function _installed_app_exe(appname::String)
    p = joinpath(homedir(), ".julia", "bin", appname)
    isfile(p) ? p : nothing
end

function _create_shortcut_windows(; location, port, name)
    julia_exe = joinpath(Sys.BINDIR, "julia.exe")
    isfile(julia_exe) || error("Could not locate julia.exe at $julia_exe")

    dest_dir = if location == :desktop
        strip(read(`powershell -NoProfile -NonInteractive -Command "[Environment]::GetFolderPath('Desktop')"`, String))
    elseif location == :startmenu
        strip(read(`powershell -NoProfile -NonInteractive -Command "[Environment]::GetFolderPath('Programs')"`, String))
    else
        error("Unknown location $location. Use :desktop or :startmenu.")
    end

    isdir(dest_dir) || error("Destination directory not found: $dest_dir")
    lnk = joinpath(dest_dir, name * ".lnk")

    # Prefer the Pkg.Apps-installed wrapper if available (.bat on Julia 1.12+, .cmd on older)
    julia_bin_dir = joinpath(homedir(), ".julia", "bin")
    app_cmd = let
        found = nothing
        for ext in (".cmd", ".bat")
            p = joinpath(julia_bin_dir, "sfemodeling" * ext)
            if isfile(p)
                found = p
                break
            end
        end
        found
    end

    # Point the shortcut directly at the target executable.
    # Previous versions used a VBScript intermediary (wscript.exe + .vbs), but
    # VBScript is deprecated and disabled by default on modern Windows (11 24H2+).
    # Instead we use the shortcut's WindowStyle = 7 (minimized) so the console
    # opens out of the way while the browser GUI takes focus.
    if app_cmd !== nothing
        target_path = app_cmd
        target_args = "--port $port"
    else
        target_path = julia_exe
        target_args = "-m SFEModeling -- --port $port"
    end

    esc(s) = replace(s, "'" => "''")  # escape for PS single-quoted strings

    ps = """
    \$ws = New-Object -ComObject WScript.Shell
    \$sc = \$ws.CreateShortcut('$(esc(lnk))')
    \$sc.TargetPath       = '$(esc(target_path))'
    \$sc.Arguments        = '$(esc(target_args))'
    \$sc.WorkingDirectory = '$(esc(homedir()))'
    \$sc.Description      = 'Launch SFEModeling GUI'
    \$sc.WindowStyle      = 7
    \$sc.IconLocation     = '$(esc(julia_exe))'
    \$sc.Save()
    """
    run(`powershell -NoProfile -NonInteractive -Command $ps`)
    _print_install_success(lnk)
    return lnk
end

function _create_shortcut_macos(; location, port, name)
    dest_dir = if location == :desktop
        joinpath(homedir(), "Desktop")
    elseif location == :applications
        "/Applications"
    else
        error("Unknown location $location. Use :desktop or :applications.")
    end

    isdir(dest_dir) || error("Destination directory not found: $dest_dir")
    app_path = joinpath(dest_dir, name * ".app")
    macos_dir = joinpath(app_path, "Contents", "MacOS")
    mkpath(macos_dir)

    # Prefer the Pkg.Apps-installed binary; fall back to julia -m
    launcher = let p = _installed_app_exe("sfemodeling")
        if p !== nothing
            "exec '$(replace(p, "'" => "\\'"))' --port $port"
        else
            julia_bin = joinpath(Sys.BINDIR, "julia")
            "exec '$(replace(julia_bin, "'" => "\\'"))' -m SFEModeling --port $port"
        end
    end

    script = joinpath(macos_dir, name)
    write(script, "#!/bin/sh\n$launcher\n")
    chmod(script, 0o755)

    write(joinpath(app_path, "Contents", "Info.plist"), """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
      "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>CFBundleName</key>              <string>$name</string>
      <key>CFBundleExecutable</key>        <string>$name</string>
      <key>CFBundleIdentifier</key>        <string>org.julialang.sfemodeling</string>
      <key>CFBundleVersion</key>           <string>1.0</string>
      <key>CFBundlePackageType</key>       <string>APPL</string>
      <key>LSUIElement</key>               <false/>
    </dict></plist>
    """)

    _print_install_success(app_path)
    return app_path
end

function _create_shortcut_linux(; location, port, name)
    dest_dir = if location == :desktop
        joinpath(homedir(), "Desktop")
    elseif location == :applications
        joinpath(homedir(), ".local", "share", "applications")
    else
        error("Unknown location $location. Use :desktop or :applications.")
    end

    mkpath(dest_dir)
    desktop_file = joinpath(dest_dir, name * ".desktop")

    # Write SVG icon to the standard hicolor icon theme directory
    icon_dir = joinpath(homedir(), ".local", "share", "icons", "hicolor", "scalable", "apps")
    mkpath(icon_dir)
    icon_name = lowercase(replace(name, " " => ""))
    icon_path = joinpath(icon_dir, icon_name * ".svg")
    write(icon_path, """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <circle cx="32" cy="32" r="32" fill="#1e3a5f"/>
  <text x="32" y="41" font-family="Arial,sans-serif" font-size="21"
        font-weight="bold" text-anchor="middle" fill="#e0eaff">SM</text>
</svg>
""")

    # Prefer the Pkg.Apps-installed binary; fall back to julia -m
    exec_cmd = let p = _installed_app_exe("sfemodeling")
        if p !== nothing
            "$p --port $port"
        else
            julia_bin = joinpath(Sys.BINDIR, "julia")
            "$julia_bin -m SFEModeling --port $port"
        end
    end

    write(desktop_file, """
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
Comment=Sovová supercritical extraction model — multi-curve fitting
Exec=$exec_cmd
Icon=$icon_name
Terminal=false
Categories=Science;Education;
""")
    chmod(desktop_file, 0o755)

    # Mark as trusted on GNOME (suppresses the "untrusted launcher" dialog)
    try
        run(`gio set $desktop_file metadata::trusted true`)
    catch
    end

    _print_install_success(desktop_file)
    return desktop_file
end

function _print_install_success(path::String)
    println()
    println("  ╔══════════════════════════════════════════════════════════╗")
    println("  ║                                                          ║")
    println("  ║   SFEModeling desktop shortcut created successfully!     ║")
    println("  ║                                                          ║")
    # truncate long paths so the box stays aligned
    label = length(path) > 52 ? "…" * path[end-50:end] : path
    println("  ║   ", rpad(label, 55), "║")
    println("  ║                                                          ║")
    println("  ║   You can now close this Julia session and launch        ║")
    println("  ║   the app by double-clicking the desktop icon.           ║")
    println("  ║                                                          ║")
    println("  ╚══════════════════════════════════════════════════════════╝")
    println()
end
