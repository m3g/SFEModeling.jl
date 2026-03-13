module SFEModeling

using BlackBoxOptim
using DelimitedFiles: readdlm
using Printf
using XLSX
using HTTP
using JSON3

export ExtractionCurve, TextTable, ExcelTable, sfegui, create_shortcut, export_results
export ExtractionModel, ParamSpec, ModelFitResult, fit_model, param_spec, simulate
export Sovova, Esquivel, Zekovic, PKM, SplineModel


"""
    ExtractionCurve(; data, ...)

Experimental extraction curve data and operating conditions for one experiment.

# Required keyword arguments
- `data::Matrix{Float64}`: table with column 1 = extraction times (min) and
  columns 2:N = cumulative extracted mass for each replicate (g).
  A `Matrix` can be read from files with [`TextTable`](@ref) or [`ExcelTable`](@ref).
- `porosity::Float64`: bed porosity (dimensionless)
- `x0::Float64`: total extractable yield (mass fraction, kg/kg)
- `solid_density::Float64`: solid density (g/cm³)
- `solvent_density::Float64`: solvent density (g/cm³)
- `flow_rate::Float64`: solvent flow rate (cm³/min)
- `bed_height::Float64`: bed height (cm)
- `bed_diameter::Float64`: bed diameter (cm)
- `particle_diameter::Float64`: particle diameter (cm)
- `solid_mass::Float64`: mass of solid (g)
- `solubility::Float64`: solubility (kg/kg)

# Optional keyword arguments
- `nh::Int`: spatial discretization steps (default: 5)
- `nt::Int`: temporal discretization steps (default: 2500)

# Example
```julia
data = TextTable("experiment.txt")  # or ExcelTable("experiment.xlsx")
curve = ExtractionCurve(data=data, porosity=0.4, ...)
```
"""
struct ExtractionCurve
    # Experimental data (SI units internally)
    t::Vector{Float64}         # times (s)
    m_ext::Vector{Float64}     # cumulative extracted mass (kg)
    # Operating conditions (SI)
    porosity::Float64          # dimensionless
    x0::Float64                # total extractable (kg/kg)
    solid_density::Float64     # kg/m³
    solvent_density::Float64   # kg/m³
    flow_rate::Float64         # m³/s
    bed_height::Float64        # m
    bed_diameter::Float64      # m
    particle_diameter::Float64 # m
    solid_mass::Float64        # kg
    solubility::Float64        # kg/kg
    # Discretization
    nh::Int
    nt::Int
end

function ExtractionCurve(;
    data::Matrix{Float64},
    porosity::Float64,
    x0::Float64,
    solid_density::Float64,
    solvent_density::Float64,
    flow_rate::Float64,
    bed_height::Float64,
    bed_diameter::Float64,
    particle_diameter::Float64,
    solid_mass::Float64,
    solubility::Float64,
    nh::Int = 5,
    nt::Int = 2500,
)
    # Extract time column and replicate m_ext columns from the data matrix.
    # Column 1 = time (min), columns 2:end = replicate m_ext values (g).
    # Each time is repeated once per replicate to build interleaved vectors.
    nreps = size(data, 2) - 1
    nrows = size(data, 1)
    t = Vector{Float64}(undef, nrows * nreps)
    m_ext = Vector{Float64}(undef, nrows * nreps)
    k = 0
    for i in 1:nrows
        for j in 1:nreps
            k += 1
            t[k] = data[i, 1]
            m_ext[k] = data[i, j + 1]
        end
    end

    # Convert from user-friendly units (g, cm, min) to SI (kg, m, s)
    t_si = t .* 60.0
    m_ext_si = m_ext ./ 1000.0
    solid_density_si = solid_density * 1000.0
    solvent_density_si = solvent_density * 1000.0
    flow_rate_si = flow_rate / (60.0 * 1000.0)
    bed_height_si = bed_height / 100.0
    bed_diameter_si = bed_diameter / 100.0
    particle_diameter_si = particle_diameter / 100.0
    solid_mass_si = solid_mass / 1000.0

    ExtractionCurve(
        t_si, m_ext_si,
        porosity, x0,
        solid_density_si, solvent_density_si, flow_rate_si,
        bed_height_si, bed_diameter_si, particle_diameter_si,
        solid_mass_si, solubility,
        nh, nt,
    )
end

function Base.show(io::IO, c::ExtractionCurve)
    rows = (
        ("Porosity",        c.porosity,                   "—"),
        ("x₀",              c.x0,                         "kg/kg"),
        ("Solid density",   c.solid_density / 1000.0,     "g/cm³"),
        ("Solvent density", c.solvent_density / 1000.0,   "g/cm³"),
        ("Flow rate",       c.flow_rate * 60.0 * 1000.0,  "cm³/min"),
        ("Bed height",      c.bed_height * 100.0,         "cm"),
        ("Bed diameter",    c.bed_diameter * 100.0,       "cm"),
        ("Particle diam.",  c.particle_diameter * 100.0,  "cm"),
        ("Solid mass",      c.solid_mass * 1000.0,        "g"),
        ("Solubility",      c.solubility,                 "kg/kg"),
    )
    w_p = max(16, maximum(length(r[1]) for r in rows))
    w_v = 13
    header = "  " * rpad("Property", w_p) * " │ " * lpad("Value", w_v) * " │ Unit"
    rule   = "  " * "─"^w_p * "─┼─" * "─"^w_v * "─┼─"
    println(io, "ExtractionCurve")
    println(io, header)
    println(io, rule)
    for (name, val, unit) in rows
        vstr = Printf.@sprintf("%.6g", val)
        println(io, "  " * rpad(name, w_p) * " │ " * lpad(vstr, w_v) * " │ " * unit)
    end
    println(io, rule)
    print(io, "  $(length(c.t)) data points  ·  nh=$(c.nh), nt=$(c.nt)")
end

include("./models.jl")

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

"""
    TextTable(filename; kwargs...)

Read a delimited text file and return a `Matrix{Float64}`.
The expected format is one time column followed by one or more replicate columns:

```
# t (min)   rep1 (g)   rep2 (g)
0.0         0.000      0.000
5.0         0.110      0.094
10.0        0.257      0.227
```

Lines starting with `#` are ignored. Keyword arguments are passed to
`DelimitedFiles.readdlm`.

# Example
```julia
data = TextTable("experiment.txt")
curve = ExtractionCurve(data=data, temperature=313.15, ...)
```
"""
function TextTable(filename::AbstractString; kwargs...)
    return readdlm(filename, Float64; comments=true, kwargs...)
end
function TextTable(io::IO; kwargs...)
    return readdlm(io, Float64; comments=true, kwargs...)
end

"""
    ExcelTable(filename; sheet=1, header=true)

Read an Excel `.xlsx` file and return a `Matrix{Float64}`.
The expected format is one time column followed by one or more replicate columns.

# Arguments
- `filename`: path to the `.xlsx` file.
- `sheet`: sheet index (default: `1`) or name (`String`).
- `header`: whether the first row contains column headers to skip (default: `true`).

# Example
```julia
data = ExcelTable("experiment.xlsx")
curve = ExtractionCurve(data=data, temperature=313.15, ...)
```
"""
function ExcelTable(filename::AbstractString; sheet::Union{Int,AbstractString}=1, header::Bool=true)
    xf = XLSX.readxlsx(filename)
    ws = xf[sheet]
    raw = ws[:]
    data = header ? raw[2:end, :] : raw
    return Float64.(data)
end


#"""
#    SimWorkspace
#
#Pre-allocated workspace for the Sovová simulation, avoiding repeated allocations
#in the optimization loop.
#"""
struct SimWorkspace
    xs::Vector{Float64}
    y::Vector{Float64}
    ycal::Vector{Float64}
end

SimWorkspace(nh::Int, ndata::Int) = SimWorkspace(Vector{Float64}(undef, nh), zeros(nh + 1), zeros(ndata))

#"""
#    simulate(curve::ExtractionCurve, kya, kxa, xk)
#    simulate!(workspace::SimWorkspace, curve::ExtractionCurve, kya, kxa, xk)
#
#Simulate the Sovová extraction model for one curve.
#Returns a vector of calculated cumulative extracted masses at the experimental times.
#The in-place variant `simulate!` reuses pre-allocated workspace arrays.
#"""
function simulate(curve::ExtractionCurve, kya, kxa, xk)
    ws = SimWorkspace(curve.nh, length(curve.t))
    simulate!(ws, curve, kya, kxa, xk)
end

function simulate!(ws::SimWorkspace, curve::ExtractionCurve, kya, kxa, xk)
    (; t, x0, solid_density, solvent_density,
       flow_rate, bed_height, bed_diameter,
       solid_mass, solubility, nh, nt) = curve

    ndata = length(t)
    xs = ws.xs
    y = ws.y
    ycal = ws.ycal

    # Initialize workspace arrays
    fill!(xs, x0)
    fill!(y, 0.0)
    fill!(ycal, 0.0)

    # Recompute porosity from bed geometry (as in Fortran code)
    eps = 1.0 - 4.0 * solid_mass / (π * bed_diameter^2 * bed_height * solid_density)
    # Interstitial velocity
    v = 4.0 * flow_rate / (solvent_density * π * bed_diameter^2 * eps)

    tempo = t[end]
    dt = tempo / nt
    dh = bed_height / nh

    yant_outlet = 0.0
    ynum_prev = 0.0
    ynum_curr = 0.0

    current_t = 0.0
    for _ in 1:nt
        current_t += dt

        # Inlet boundary condition
        y[1] = 0.0

        # Spatial loop
        for k in 1:nh
            if xs[k] > xk
                # CER period: J = kya * (Y* - Y)
                jxy = kya * (solubility - y[k])
            else
                # FER period: J = kxa * x * (1 - Y/Y*)
                jxy = kxa * xs[k] * (1.0 - y[k] / solubility)
            end

            # Update solid concentration
            xs[k] -= dt * jxy * solvent_density / (solid_density * (1.0 - eps))

            # Store previous outlet for trapezoidal rule
            if k == nh
                yant_outlet = y[nh + 1]
            end

            # Update fluid concentration (spatial march)
            y[k + 1] = y[k] + dh * jxy / (eps * v)
        end

        # Trapezoidal integration of outlet mass flow
        ynum_curr = ynum_prev + dt * (y[nh + 1] + yant_outlet) * flow_rate / 2.0

        # Interpolation: assign to experimental points in [current_t - dt, current_t]
        for i in 1:ndata
            if t[i] >= current_t - dt && t[i] <= current_t
                ycal[i] = ynum_prev + (ynum_curr - ynum_prev) * (t[i] - current_t + dt) / dt
            end
        end

        ynum_prev = ynum_curr
    end

    return ycal
end

function fit_model(
    ::Sovova,
    curves::Vector{ExtractionCurve};
    kya_bounds::Tuple{Float64,Float64} = (0.0, 0.05),
    kxa_bounds::Tuple{Float64,Float64} = (0.0, 0.005),
    xk_ratio_bounds::Tuple{Float64,Float64} = (0.0, 1.0),
    maxevals::Int = 50_000,
    tracemode::Symbol = :silent,
)
    nexp = length(curves)
    n = 2 * nexp + 1  # number of parameters

    # Build bounds: [kya_1, kxa_1, kya_2, kxa_2, ..., xk_ratio]
    search_range = Tuple{Float64,Float64}[]
    for _ in 1:nexp
        push!(search_range, kya_bounds)
        push!(search_range, kxa_bounds)
    end
    push!(search_range, xk_ratio_bounds)

    # Pre-allocate simulation workspaces (one per curve)
    workspaces = [SimWorkspace(curves[i].nh, length(curves[i].t)) for i in 1:nexp]

    # Objective function: sum of squared residuals
    function objective(a)
        xk_ratio = a[n]
        f = 0.0
        for iexp in 1:nexp
            kya_i = a[2*iexp-1]
            kxa_i = a[2*iexp]
            xk_i = curves[iexp].x0 * xk_ratio
            ycal = simulate!(workspaces[iexp], curves[iexp], kya_i, kxa_i, xk_i)
            for i in eachindex(ycal)
                f += (ycal[i] - curves[iexp].m_ext[i])^2
            end
        end
        return f
    end

    # Global optimization with BlackBoxOptim
    res = bboptimize(objective;
        SearchRange = search_range,
        NumDimensions = n,
        MaxFuncEvals = maxevals,
        TraceMode = tracemode,
    )

    best_a = best_candidate(res)
    best_f = best_fitness(res)

    # Extract results
    xk_ratio = best_a[n]
    kya_vec = [best_a[2*i-1] for i in 1:nexp]
    kxa_vec = [best_a[2*i]   for i in 1:nexp]
    xk_vec  = [curves[i].x0 * xk_ratio for i in 1:nexp]

    # Compute tcer and final calculated curves
    tcer_vec = zeros(nexp)
    ycal_all = Vector{Vector{Float64}}(undef, nexp)
    for iexp in 1:nexp
        c = curves[iexp]
        eps = 1.0 - 4.0 * c.solid_mass / (π * c.bed_diameter^2 * c.bed_height * c.solid_density)
        tcer_vec[iexp] = (c.x0 - xk_vec[iexp]) * (1.0 - eps) * c.solid_density /
                         (c.solubility * kya_vec[iexp] * c.solvent_density)
        ycal_all[iexp] = simulate(c, kya_vec[iexp], kxa_vec[iexp], xk_vec[iexp])
    end

    # Build flat spec + params for the unified show()
    _spec   = ParamSpec[ParamSpec("xk/x0", "xk/x₀ — accessible solute ratio (—)", 0.0, 1.0)]
    _params = Float64[xk_ratio]
    for i in 1:nexp
        push!(_spec,   ParamSpec("kya[$i]",  "kya — fluid-phase mass transfer coeff. (1/s)",  0.0, 0.05))
        push!(_params, kya_vec[i])
        push!(_spec,   ParamSpec("kxa[$i]",  "kxa — solid-phase mass transfer coeff. (1/s)",  0.0, 0.005))
        push!(_params, kxa_vec[i])
        push!(_spec,   ParamSpec("tCER[$i]", "tCER — CER period duration (s)",                0.0, Inf))
        push!(_params, tcer_vec[i])
    end

    return ModelFitResult(
        Sovova(), ycal_all, best_f,
        (spec=_spec, params=_params,
         kya=kya_vec, kxa=kxa_vec, xk_ratio=xk_ratio, xk=xk_vec, tcer=tcer_vec),
    )
end

# Default: no model argument → Sovová PDE model
fit_model(curve::ExtractionCurve; kwargs...)              = fit_model(Sovova(), [curve]; kwargs...)
fit_model(curves::Vector{ExtractionCurve}; kwargs...)     = fit_model(Sovova(), curves; kwargs...)

"""
    export_results(filename, result, curve)
    export_results(filename, result, curves)

Export fitting results to a file. The format is inferred from the extension:
- `.xlsx` — Excel workbook (one sheet per curve). Parameters occupy columns A–B;
  the data table (time, experimental replicates, calculated values) starts at column C.
- anything else — space-delimited text. Parameters are written as `#`-comment lines
  (readable by [`TextTable`](@ref)), followed by the data table.

# Example
```julia
result = fit_model(curve)
export_results("results.txt",  result, curve)
export_results("results.xlsx", result, curve)
```
"""
function export_results(filename::AbstractString, result::ModelFitResult, curve::ExtractionCurve)
    export_results(filename, result, [curve])
end

function export_results(filename::AbstractString, result::ModelFitResult, curves::Vector{ExtractionCurve})
    if endswith(lowercase(filename), ".xlsx")
        _export_xlsx(filename, result, curves)
    else
        _export_txt(filename, result, curves)
    end
    @info "Results written to $filename"
    return filename
end

# ── Number of replicates from the interleaved time vector ────────────────────
function _nreps(t::Vector{Float64})
    n = 1
    while n < length(t) && t[n + 1] ≈ t[1]
        n += 1
    end
    return n
end

# ── De-interleave a curve + ycal into user-unit arrays ───────────────────────
function _deinterleave(c::ExtractionCurve, ycal::Vector{Float64})
    nr    = _nreps(c.t)
    nrows = length(c.t) ÷ nr
    times = [c.t[1 + (i - 1)*nr] / 60.0    for i in 1:nrows]             # min
    exps  = [[c.m_ext[j + (i - 1)*nr] * 1e3 for i in 1:nrows] for j in 1:nr]  # g
    calc  = [ycal[1 + (i - 1)*nr] * 1e3     for i in 1:nrows]             # g
    return times, exps, calc, nr
end

# ── Parameter name/value/unit tuples ─────────────────────────────────────────
function _fitted_params(result::ModelFitResult{Sovova}, ic::Int)
    [("kya",   result.kya[ic],   "1/s"),
     ("kxa",   result.kxa[ic],   "1/s"),
     ("xk/x0", result.xk_ratio,  ""),
     ("xk",    result.xk[ic],    "kg/kg"),
     ("tCER",  result.tcer[ic],  "s"),
     ("SSR",   result.objective, "")]
end

function _fitted_params(result::ModelFitResult, ::Int)
    data = getfield(result, :_data)
    rows = Tuple{String,Float64,String}[(s.name, v, "") for (s, v) in zip(data.spec, data.params)]
    push!(rows, ("SSR", result.objective, ""))
    return rows
end

function _cond_params(c::ExtractionCurve)
    [("porosity",          c.porosity,                   ""),
     ("x0",                c.x0,                         "kg/kg"),
     ("solid_density",     c.solid_density  / 1000.0,    "g/cm3"),
     ("solvent_density",   c.solvent_density / 1000.0,   "g/cm3"),
     ("flow_rate",         c.flow_rate * 60.0 * 1000.0,  "cm3/min"),
     ("bed_height",        c.bed_height  * 100.0,        "cm"),
     ("bed_diameter",      c.bed_diameter * 100.0,       "cm"),
     ("particle_diameter", c.particle_diameter * 100.0,  "cm"),
     ("solid_mass",        c.solid_mass * 1000.0,        "g"),
     ("solubility",        c.solubility,                 "kg/kg")]
end

# ── Text export ───────────────────────────────────────────────────────────────
function _export_txt(filename, result, curves)
    open(filename, "w") do io
        println(io, "# SFEModeling — Fitting Results")
        println(io, "#")
        for (ic, c) in enumerate(curves)
            suffix = length(curves) > 1 ? " (Curve $ic)" : ""
            println(io, "# Fitted parameters$suffix:")
            for (k, v, u) in _fitted_params(result, ic)
                ustr = isempty(u) ? "" : "  # $u"
                @Printf.printf(io, "#   %-22s = %g%s\n", k, v, ustr)
            end
            println(io, "#")
            println(io, "# Operating conditions$suffix:")
            for (k, v, u) in _cond_params(c)
                ustr = isempty(u) ? "" : "  # $u"
                @Printf.printf(io, "#   %-22s = %g%s\n", k, v, ustr)
            end
            println(io, "#")
        end
        for (ic, c) in enumerate(curves)
            times, exps, calc, nr = _deinterleave(c, result.ycal[ic])
            if length(curves) > 1
                println(io, "# --- Curve $ic ---")
            end
            # column header
            print(io, "# time_min")
            for j in 1:nr; @Printf.printf(io, "    exp_%d_g", j); end
            println(io, "    calc_g")
            # data rows
            for i in eachindex(times)
                @Printf.printf(io, "  %10.4f", times[i])
                for j in 1:nr; @Printf.printf(io, "  %10.4f", exps[j][i]); end
                @Printf.printf(io, "  %10.4f\n", calc[i])
            end
        end
    end
end

# ── Excel export ──────────────────────────────────────────────────────────────
function _export_xlsx(filename, result, curves)
    XLSX.openxlsx(filename, mode="w") do xf
        for (ic, c) in enumerate(curves)
            ws = if ic == 1
                s = xf[1]
                XLSX.rename!(s, length(curves) > 1 ? "Curve 1" : "Results")
                s
            else
                XLSX.addsheet!(xf, "Curve $ic")
            end

            times, exps, calc, nr = _deinterleave(c, result.ycal[ic])
            all_params = vcat(_fitted_params(result, ic), _cond_params(c))

            # Columns A–B: parameters
            ws[1, 1] = "Parameter"
            ws[1, 2] = "Value"
            for (row, (k, v, u)) in enumerate(all_params)
                ws[row + 1, 1] = isempty(u) ? k : "$k ($u)"
                ws[row + 1, 2] = v
            end

            # Column C onwards: data table
            ws[1, 3] = "time (min)"
            for j in 1:nr
                ws[1, 3 + j] = "exp_$j (g)"
            end
            ws[1, 3 + nr + 1] = "calc (g)"
            for (i, t) in enumerate(times)
                row = i + 1
                ws[row, 3] = t
                for j in 1:nr
                    ws[row, 3 + j] = exps[j][i]
                end
                ws[row, 3 + nr + 1] = calc[i]
            end
        end
    end
end

include("gui.jl")

end
