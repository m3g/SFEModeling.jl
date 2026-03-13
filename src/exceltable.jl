# ── Excel file I/O ────────────────────────────────────────────────────────────

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
