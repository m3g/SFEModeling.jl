# ── Kinetic models for supercritical fluid extraction ────────────────────────
#
# Each model implements:
#   param_spec(model)                               → Vector{ParamSpec}
#   simulate(model, curve, params::Vector{Float64}) → Vector{Float64}  (kg, same length as curve.t)
#
# All empirical models share the same ExtractionCurve operating conditions.
# The total extractable mass is  m_total = curve.x0 * curve.solid_mass  (kg).

abstract type ExtractionModel end

"""
    Sovova()

Sovová PDE supercritical extraction model. This is the **default** model used when
calling `fit_model` without an explicit model argument.

Fits per-curve parameters `kya` (fluid-phase mass transfer coefficient, 1/s) and
`kxa` (solid-phase mass transfer coefficient, 1/s), plus a shared `xk/x0` ratio
(easily accessible solute fraction).

Returns a [`ModelFitResult`](@ref).
"""
struct Sovova            <: ExtractionModel end

"""
    Esquivel()

Single-exponential model (Esquível & Bernardo-Gil, 1999):

```math
m_e(t) = m_{total}\\,(1 - e^{-k_1 t})
```

One fitted parameter: `k1` — rate constant (1/s).
"""
struct Esquivel          <: ExtractionModel end

"""
    Zekovic()

Two-parameter accessible-fraction model (Žeković et al., 2003):

```math
m_e(t) = m_{total}\\, k_1\\,(1 - e^{-k_2 t})
```

Two fitted parameters: `k1` — accessible yield fraction (—); `k2` — rate constant (1/s).
"""
struct Zekovic           <: ExtractionModel end

"""
    PKM()

Parallel-kinetics model (Fiori et al., 2012):

```math
m_e(t) = m_{total}\\left[k_1(1 - e^{-k_2 t}) + (1-k_1)(1 - e^{-k_3 t})\\right]
```

Three fitted parameters: `k1` — easily accessible fraction (—); `k2` — fluid-phase
rate constant (1/s); `k3` — solid-phase rate constant (1/s).
"""
struct PKM               <: ExtractionModel end

"""
    SplineModel()

Piecewise-linear CER/FER/DC model:

- **CER** phase (0 ≤ t ≤ k₂): ``m_e = m_{total}\\,k_1\\,t``
- **FER** phase (k₂ < t ≤ k₄): ``m_e = m_{CER} + m_{total}\\,k_3\\,(t - k_2)``
- **DC** phase (t > k₄): ``m_e = m_{FER}`` (constant)

Four fitted parameters: `k1` — CER rate (1/s); `k2` — CER end time (s);
`k3` — FER rate (1/s); `k4` — FER end time (s).
"""
struct SplineModel       <: ExtractionModel end

struct ParamSpec
    name    ::String   # "k1", "k2", …
    label   ::String   # human-readable description shown in the GUI
    lb      ::Float64  # suggested lower bound
    ub      ::Float64  # suggested upper bound
end

# ── Parameter specifications ──────────────────────────────────────────────────

"""
    param_spec(model) -> Vector{ParamSpec}

Return the parameter specification for `model`: a vector of `ParamSpec` values, each
describing a parameter's name, human-readable label, and default lower/upper bounds.

Used internally by [`fit_model`](@ref) to set the search range for the optimizer.
Inspect it to see parameter order and default bounds:

```julia
param_spec(PKM())
# 3-element Vector{ParamSpec}:
#  "k1"  k₁ — easily accessible fraction (—)      [0.0, 1.0]
#  "k2"  k₂ — fluid-phase rate constant (1/s)      [0.0, 0.05]
#  "k3"  k₃ — solid-phase rate constant (1/s)      [0.0, 0.005]
```
"""
param_spec(::Sovova) = [
    ParamSpec("kya", "kya — fluid-phase mass transfer coeff. (1/s)", 0.0, 0.05),
    ParamSpec("kxa", "kxa — solid-phase mass transfer coeff. (1/s)", 0.0, 0.005),
    ParamSpec("xk_ratio", "xk/x₀ — accessible solute ratio (—)", 0.0, 1.0),
]

param_spec(::Esquivel) = [
    ParamSpec("k1", "k₁ — rate constant (1/s)", 0.0, 1e-2),
]

param_spec(::Zekovic) = [
    ParamSpec("k1", "k₁ — accessible yield fraction (—)", 0.01, 1.0),
    ParamSpec("k2", "k₂ — rate constant (1/s)",           0.0,  1e-2),
]

param_spec(::PKM) = [
    ParamSpec("k1", "k₁ — easily accessible fraction (—)",          0.0, 1.0),
    ParamSpec("k2", "k₂ — fluid-phase rate constant (1/s)",         0.0, 5e-2),
    ParamSpec("k3", "k₃ — solid-phase rate constant (1/s)",         0.0, 5e-3),
]

param_spec(::SplineModel) = [
    ParamSpec("k1", "k₁ — CER rate (1/s)",             0.0, 5e-2),
    ParamSpec("k2", "k₂ — CER end time (s)",            0.0, 3600.0),
    ParamSpec("k3", "k₃ — FER rate (1/s)",             0.0, 1e-2),
    ParamSpec("k4", "k₄ — FER end time (s)",            0.0, 7200.0),
]

# ── Simulate functions ────────────────────────────────────────────────────────

function simulate(::Esquivel, curve::ExtractionCurve, p::Vector{Float64})
    m_total = curve.x0 * curve.solid_mass
    k1 = p[1]
    return [m_total * (1.0 - exp(-k1 * t)) for t in curve.t]
end

function simulate(::Zekovic, curve::ExtractionCurve, p::Vector{Float64})
    m_total = curve.x0 * curve.solid_mass
    k1, k2 = p[1], p[2]
    # m_e(t) = m_total * k1 * (1 - exp(-k2 * t))
    return [m_total * k1 * (1.0 - exp(-k2 * t)) for t in curve.t]
end

function simulate(::PKM, curve::ExtractionCurve, p::Vector{Float64})
    m_total = curve.x0 * curve.solid_mass
    k1, k2, k3 = p[1], p[2], p[3]
    # m_e(t) = m_total * [k1*(1-exp(-k2*t)) + (1-k1)*(1-exp(-k3*t))]
    return [m_total * (k1 * (1.0 - exp(-k2 * t)) + (1.0 - k1) * (1.0 - exp(-k3 * t)))
            for t in curve.t]
end

function simulate(::SplineModel, curve::ExtractionCurve, p::Vector{Float64})
    m_total = curve.x0 * curve.solid_mass
    k1, k2, k3, k4 = p[1], p[2], p[3], p[4]
    # Piecewise-linear: CER (slope k1) → FER (slope k3) → DC (flat)
    m_cer = m_total * k1 * k2                          # mass at end of CER
    m_fer = m_cer + m_total * k3 * max(k4 - k2, 0.0)  # mass at end of FER
    return map(curve.t) do t
        if t <= k2
            m_total * k1 * t
        elseif t <= k4
            m_cer + m_total * k3 * (t - k2)
        else
            m_fer  # DC phase: flat
        end
    end
end

# ── Generic multi-curve fitting ───────────────────────────────────────────────

"""
    ModelFitResult{M<:ExtractionModel}

Result of fitting kinetic model `M` to one or more extraction curves.

All models return a `ModelFitResult{M}`. 

# Common fields
- `model`: the fitted model instance
- `ycal::Vector{Vector{Float64}}`: calculated extraction curves (kg), one per input curve
- `objective::Float64`: sum of squared residuals (SSR) at the optimum

# Sovová-specific properties (accessed via `result.field`)
`kya`, `kxa`, `xk_ratio`, `xk`, `tcer`

# Empirical-model properties (accessed via `result.field`)
`params`, `spec`
"""
struct ModelFitResult{M<:ExtractionModel, D<:NamedTuple}
    model     ::M
    ycal      ::Vector{Vector{Float64}}
    objective ::Float64
    _data     ::D
end

function Base.getproperty(r::ModelFitResult, s::Symbol)
    s === :model     && return getfield(r, :model)
    s === :ycal      && return getfield(r, :ycal)
    s === :objective && return getfield(r, :objective)
    return getfield(getfield(r, :_data), s)
end

function Base.propertynames(r::ModelFitResult, private::Bool=false)
    props = (:model, :ycal, :objective, keys(getfield(r, :_data))...)
    private ? (props..., :_data) : props
end

# ── Pretty show — empirical models ────────────────────────────────────────────

function Base.show(io::IO, r::ModelFitResult)
    data   = getfield(r, :_data)
    spec   = data.spec
    params = data.params

    mname = nameof(typeof(r.model))
    println(io, "ModelFitResult{$mname}")
    println(io, "  SSR = $(Printf.@sprintf("%.4e", r.objective))")
    isempty(spec) && return

    println(io)
    # Column widths
    w_p = max(9,  maximum(length(s.name)  for s in spec))
    w_v = 13
    w_d = max(11, maximum(length(s.label) for s in spec))

    header = "  " * rpad("Parameter", w_p) * " │ " *
             lpad("Value", w_v)             * " │ Description"
    rule   = "  " * "─"^w_p * "─┼─" * "─"^w_v * "─┼─" * "─"^w_d
    println(io, header)
    println(io, rule)
    for (s, v) in zip(spec, params)
        vstr = Printf.@sprintf("%+.6e", v)
        println(io, "  " * rpad(s.name, w_p) * " │ " *
                    lpad(vstr, w_v)           * " │ " * s.label)
    end
end

"""
    fit_model(curve; kwargs...)               → ModelFitResult{Sovova}
    fit_model(curves; kwargs...)              → ModelFitResult{Sovova}
    fit_model(Sovova(), curve; kwargs...)     → ModelFitResult{Sovova}
    fit_model(model, curve; kwargs...)        → ModelFitResult{M}
    fit_model(model, curves; kwargs...)       → ModelFitResult{M}

Fit a kinetic SFE model to one or more extraction curves.

When called **without a model** (or with `Sovova()`), fits the Sovová PDE model and
returns a [`ModelFitResult{Sovova}`](@ref ModelFitResult). Each curve gets its own
`kya` and `kxa`; the ratio `xk/x0` is shared across all curves.

When called with any other model type `M`, fits that empirical model with all parameters
shared across curves, and returns a [`ModelFitResult{M}`](@ref ModelFitResult).

# Arguments
- `model`: kinetic model instance. Defaults to `Sovova()` when omitted.
  Empirical options: `Esquivel()`, `Zekovic()`, `PKM()`, `SplineModel()`.
- `curve` / `curves`: a single [`ExtractionCurve`](@ref) or a `Vector` of them.

# Keyword arguments — Sovová model
- `kya_bounds::Tuple{Float64,Float64}`: bounds for kya (default: `(0.0, 0.05)`)
- `kxa_bounds::Tuple{Float64,Float64}`: bounds for kxa (default: `(0.0, 0.005)`)
- `xk_ratio_bounds::Tuple{Float64,Float64}`: bounds for xk/x0 (default: `(0.0, 1.0)`)
- `maxevals::Int`: maximum function evaluations (default: `50_000`)
- `tracemode::Symbol`: optimizer verbosity — `:silent`, `:compact`, or `:verbose` (default: `:silent`)

# Keyword arguments — empirical models
- `param_bounds::Vector{Tuple{Float64,Float64}}`: one bound per parameter;
  defaults to the values from [`param_spec`](@ref)
- `maxevals::Int`: maximum function evaluations (default: `50_000`)
- `tracemode::Symbol`: optimizer verbosity (default: `:silent`)

# Examples
```julia
# Sovová PDE model (default)
result = fit_model(curve)
result = fit_model(Sovova(), curve)

# Empirical model
result = fit_model(PKM(), curve)
result = fit_model(PKM(), [curve1, curve2])
```
"""
function fit_model(model::ExtractionModel, curve::ExtractionCurve; kwargs...)
    fit_model(model, [curve]; kwargs...)
end

function fit_model(
    model  ::ExtractionModel,
    curves ::Vector{ExtractionCurve};
    param_bounds ::Union{Nothing, Vector{Tuple{Float64,Float64}}} = nothing,
    maxevals     ::Int    = 50_000,
    tracemode    ::Symbol = :silent,
)
    spec   = param_spec(model)
    bounds = param_bounds !== nothing ? param_bounds : [(s.lb, s.ub) for s in spec]
    n      = length(bounds)

    function objective(params)
        f = 0.0
        for curve in curves
            ycal = simulate(model, curve, params)
            for i in eachindex(ycal)
                f += (ycal[i] - curve.m_ext[i])^2
            end
        end
        return f
    end

    res    = bboptimize(objective; SearchRange = bounds, NumDimensions = n,
                        MaxFuncEvals = maxevals, TraceMode = tracemode)
    best_p = best_candidate(res)
    best_f = best_fitness(res)
    ycal_all = [simulate(model, c, best_p) for c in curves]

    return ModelFitResult(model, ycal_all, best_f, (spec=spec, params=collect(best_p)))
end

# ── Name → model instance lookup (used by the GUI) ───────────────────────────

const _MODEL_REGISTRY = Dict{String, ExtractionModel}(
    "sovova"    => Sovova(),
    "esquivel"  => Esquivel(),
    "zekovic"   => Zekovic(),
    "pkm"       => PKM(),
    "spline"    => SplineModel(),
)

model_from_name(name::String) = get(_MODEL_REGISTRY, lowercase(name), Sovova())
