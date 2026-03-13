# ── Fitting infrastructure ────────────────────────────────────────────────────

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

# ── Generic multi-curve fitting for empirical models ─────────────────────────

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

# Default: no model argument → Sovová PDE model
fit_model(curve::ExtractionCurve; kwargs...)              = fit_model(Sovova(), [curve]; kwargs...)
fit_model(curves::Vector{ExtractionCurve}; kwargs...)     = fit_model(Sovova(), curves; kwargs...)

# ── Name → model instance lookup (used by the GUI) ───────────────────────────

const _MODEL_REGISTRY = Dict{String, ExtractionModel}(
    "sovova"    => Sovova(),
    "shrinkingcore" => ShrinkingCoreModel(),
    "esquivel"  => Esquivel(),
    "zekovic"   => Zekovic(),
    "pkm"       => PKM(),
    "spline"    => SplineModel(),
)

model_from_name(name::String) = get(_MODEL_REGISTRY, lowercase(name), Sovova())
