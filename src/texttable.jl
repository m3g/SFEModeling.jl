# ── Text file I/O ─────────────────────────────────────────────────────────────

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
