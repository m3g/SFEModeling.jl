# ── Shared types for kinetic models ───────────────────────────────────────────
#
# Each model implements:
#   param_spec(model)                               → Vector{ParamSpec}
#   simulate(model, curve, params::Vector{Float64}) → Vector{Float64}  (kg, same length as curve.t)
#
# All empirical models share the same ExtractionCurve operating conditions.
# The total extractable mass is  m_total = curve.x0 * curve.solid_mass  (kg).

abstract type ExtractionModel end

struct ParamSpec
    name    ::String   # "k1", "k2", …
    label   ::String   # human-readable description shown in the GUI
    lb      ::Float64  # suggested lower bound
    ub      ::Float64  # suggested upper bound
end

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
function param_spec end
