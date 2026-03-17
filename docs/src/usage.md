# Advanced usage

The advanced usage is based on a programming interface. The package can be run in the Julia REPL, in a Jupyter or Pluto notebook, or in a dedicated programming interface, such as VSCode. Additional tips for a nice programming workflow using Julia can be found at the [Modern Julia Workflows](https://modernjuliaworkflows.org/).

## Defining an extraction curve

Create an [`ExtractionCurve`](@ref) with your experimental data and operating conditions.
All inputs use **laboratory units** (g, cm, min) — the package converts to SI internally.

The experimental data is provided as a **matrix** where column 1 is the extraction time (min)
and columns 2, 3, … are cumulative extracted mass (g) for each replicate:

```@example basic
using SFEModeling

# Single replicate (2 columns: time, m_ext)
data = [5.0  0.10;
        10.0 0.25;
        15.0 0.42;
        20.0 0.58;
        30.0 0.85;
        45.0 1.10;
        60.0 1.28;
        90.0 1.45;
        120.0 1.52]

curve = ExtractionCurve(
    data           = data,
    porosity       = 0.4,      # dimensionless
    x0             = 0.05,     # kg/kg (total extractable yield)
    solid_density  = 1.1,      # g/cm³
    solvent_density = 0.8,     # g/cm³
    flow_rate      = 5.0,      # g/min
    bed_height     = 20.0,     # cm
    bed_diameter   = 2.0,      # cm
    particle_diameter = 0.05,  # cm
    solid_mass     = 50.0,     # g
    solubility     = 0.005,    # kg/kg
)
```

## Fitting a single curve

Call [`fit_model`](@ref) with an [`ExtractionCurve`](@ref). With no model argument it
defaults to the Sovová PDE model:

```@example basic
result = fit_model(curve)
```

The returned object is a [`ModelFitResult`](@ref).

The calculated extraction curves (in kg) are available as:

```@example basic
result.ycal[1]  # calculated values for the first (and only) curve
```

## Reading data from files

Instead of typing the data matrix directly, you can read it from a text or Excel file.
Example files are available for download: [example\_data.txt](assets/example_data.txt) · [example\_data.xlsx](assets/example_data.xlsx)

### Text files with [`TextTable`](@ref)

A whitespace-delimited text file with an optional comment header (lines starting with `#`):

```
# t (min)   rep1 (g)   rep2 (g)
0.0         0.000      0.000
5.0         0.110      0.094
10.0        0.257      0.227
```

```julia
data = TextTable("experiment.txt")
curve = ExtractionCurve(data=data, porosity=0.4, ...)
```

### Excel files with [`ExcelTable`](@ref)

An `.xlsx` file where the first row is a header and the remaining rows contain
the data matrix (time column + replicate columns):

```julia
data = ExcelTable("experiment.xlsx")              # reads first sheet, skips header
data = ExcelTable("experiment.xlsx"; sheet=2)      # read a specific sheet
data = ExcelTable("experiment.xlsx"; header=false)  # no header row to skip
curve = ExtractionCurve(data=data, porosity=0.4, ...)
```

### Discretization

The numerical solution uses finite differences with `nh` spatial steps and `nt` temporal
steps (defaults: `nh=5`, `nt=2500`). Increase `nt` for better accuracy at the cost of
computation time:

```julia
curve = ExtractionCurve(
    # ... other arguments ...
    nh = 10,
    nt = 5000,
)
```

## Fitting multiple curves simultaneously

Pass a vector of [`ExtractionCurve`](@ref)s to fit all curves at once. Each curve gets its
own `kya` and `kxa`, but the ratio `xk/x0` is **shared** across all curves:

```julia
curve1 = ExtractionCurve(; data=data1, porosity=0.35, ...)
curve2 = ExtractionCurve(; data=data2, porosity=0.40, ...)
curve3 = ExtractionCurve(; data=data3, porosity=0.45, ...)

result = fit_model([curve1, curve2, curve3])
```

Access per-curve results by index:

```julia
result.kya[2]   # kya for curve 2
result.kxa[2]   # kxa for curve 2
result.xk[2]    # xk for curve 2
result.tcer[2]  # tCER for curve 2
result.ycal[2]  # calculated curve 2
```

## Optimizer options

The fitting uses global optimization from
[BlackBoxOptim.jl](https://github.com/robertfeldt/BlackBoxOptim.jl).
Control the optimization via keyword arguments:

```julia
result = fit_model(curves;
    kya_bounds      = (0.0, 0.05),   # bounds for kya (1/s)
    kxa_bounds      = (0.0, 0.005),  # bounds for kxa (1/s)
    xk_ratio_bounds = (0.0, 1.0),    # bounds for xk/x0
    maxevals        = 50_000,        # max function evaluations
    tracemode       = :silent,       # :silent, :compact, or :verbose
)
```

If the default bounds do not cover your expected parameter range, adjust them accordingly.
To see optimizer progress, set `tracemode = :compact`:

```julia
result = fit_model(curve; tracemode=:compact)
```

## Complete example with real data

The following example uses experimental data from a supercritical CO₂ extraction experiment
at 333.15 K (data from Mateus et al.), with two replicates:

```@example complete
using SFEModeling

# Data matrix: column 1 = time (min), columns 2-3 = replicate m_ext (g)
data = [
    0.0   0.0000  0.0000;
    5.0   0.1097  0.0935;
   10.0   0.2571  0.2265;
   15.0   0.3894  0.3507;
   20.0   0.5228  0.4746;
   30.0   0.7872  0.7270;
   45.0   1.1633  1.0636;
   60.0   1.4848  1.3746;
   75.0   1.7484  1.6411;
   90.0   1.9751  1.8913;
  110.0   2.2485  2.1785;
  135.0   2.5630  2.5539;
  155.0   2.7584  2.7690;
  180.0   3.0323  3.0527;
  210.0   3.3022  3.3416;
  240.0   3.5332  3.5906;
  270.0   3.7349  3.8130;
  300.0   3.9260  4.0177
]

# Or read from a file:
# data = TextTable("mateus1.txt")
# data = ExcelTable("mateus1.xlsx")

curve = ExtractionCurve(
    data              = data,
    porosity          = 0.7,      # bed porosity (dimensionless)
    x0                = 0.069,    # total extractable yield (kg/kg)
    solid_density     = 1.32,     # g/cm³
    solvent_density   = 0.78023,  # g/cm³
    flow_rate         = 9.9,      # g/min
    bed_height        = 9.2,      # cm
    bed_diameter      = 5.42,     # cm
    particle_diameter = 0.0337,   # cm
    solid_mass        = 100.01,   # g
    solubility        = 0.003166, # kg/kg
)

result = fit_model(curve)
```

## Fitting alternative kinetic models

In addition to the Sovová PDE model, SFEModeling provides several empirical kinetic
models that can be fitted with [`fit_model`](@ref):

| Model type | Reference | Parameters |
|:---|:---|:---|
| `ShrinkingCoreModel()` | Moreno-Pulido *et al.* (2026) | Tₘ — Thiele modulus (—); τ_g — growth time-scale (s) |
| `Esquivel()` | Esquivel (1999) | k₁ — rate constant (1/s) |
| `Zekovic()` | Žeković (2003) | k₁ — accessible yield fraction (—); k₂ — rate constant (1/s) |
| `PKM()` | Fiori et al. (2012) | k₁ — easily accessible fraction (—); k₂ — fluid-phase rate (1/s); k₃ — solid-phase rate (1/s) |
| `SplineModel()` | — | k₁ — CER rate (1/s); k₂ — CER end time (s); k₃ — FER rate (1/s); k₄ — FER end time (s) |

### Single-curve fit

```@example complete
result = fit_model(Esquivel(), curve)
```

### Multi-curve fit

When a vector of curves is passed, all model parameters are **shared** across curves:

```@example complete
result = fit_model(PKM(), [curve, curve, curve])
```

```@example complete
println(result.ycal[2])   # calculated curve 2 (kg)
```

### Custom parameter bounds

Each model has default parameter bounds (see [`param_spec`](@ref)). Override them with
the `param_bounds` keyword — a vector of `(lower, upper)` tuples, one per parameter:

```julia
result = fit_model(PKM(), curve;
    param_bounds = [(0.0, 1.0), (0.0, 0.01), (0.0, 0.001)],
    maxevals     = 100_000,
    tracemode    = :compact,
)
```

### Accessing results

The returned [`ModelFitResult`](@ref) stores fitted parameters in `result.params`
in the same order as the model's parameter list:

```julia
result = fit_model(Zekovic(), curve)
println(result.params[1])  # k1 — accessible yield fraction
println(result.params[2])  # k2 — rate constant (1/s)
println(result.ycal[1])    # calculated curve (kg)
println(result.objective)  # SSR
```

### Exporting results

Use [`export_results`](@ref) to write fitting results to a file. The format is determined
by the file extension — `.xlsx` produces an Excel workbook; any other extension produces
a space-delimited text file with parameters as `#`-comment lines (re-readable by
[`TextTable`](@ref)):

```julia
export_results("results.txt",  result, curve)   # text file
export_results("results.xlsx", result, curve)   # Excel workbook
export_results("results.txt",  result, [curve1, curve2])  # multiple curves
```

All results share the same `show` format:

```
julia> result                       # Zekovic example
ModelFitResult{Zekovic} — 1 curve fitted
  SSR = 4.2000e-06

  Parameter │         Value │ Description
  ──────────┼───────────────┼─────────────────────────────────────────
  k1        │ +8.200000e-01 │ k₁ — accessible yield fraction (—)
  k2        │ +3.100000e-04 │ k₂ — rate constant (1/s)

julia> result                       # Sovová default, 2 curves
ModelFitResult{Sovova} — 2 curves fitted
  SSR = 3.8021e-07

  Parameter │         Value │ Description
  ──────────┼───────────────┼─────────────────────────────────────────────────────
  xk/x0     │ +6.521700e-01 │ xk/x₀ — accessible solute ratio (—)
  kya[1]    │ +2.000000e-02 │ kya — fluid-phase mass transfer coeff. (1/s)
  kxa[1]    │ +2.000000e-03 │ kxa — solid-phase mass transfer coeff. (1/s)
  tCER[1]   │ +1.234500e+03 │ tCER — CER period duration (s)
  kya[2]    │ +1.500000e-02 │ kya — fluid-phase mass transfer coeff. (1/s)
  kxa[2]    │ +1.800000e-03 │ kxa — solid-phase mass transfer coeff. (1/s)
  tCER[2]   │ +1.543200e+03 │ tCER — CER period duration (s)
```

## Graphical User Interface

See the [GUI](@ref "Graphical User Interface") page for the built-in web interface.
