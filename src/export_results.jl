# ── Result export (text and Excel) ────────────────────────────────────────────

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
