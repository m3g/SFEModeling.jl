# ── ExtractionCurve type and constructor ──────────────────────────────────────

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
- `flow_rate::Float64`: solvent mass flow rate (g/min)
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
    flow_rate::Float64         # kg/s
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
    flow_rate_si = flow_rate / (60.0 * 1000.0)   # g/min → kg/s
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
        ("Flow rate",       c.flow_rate * 60.0 * 1000.0,  "g/min"),
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
