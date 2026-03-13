# ── Esquível (1999) — single-exponential model ───────────────────────────────

"""
    Esquivel()

Single-exponential model (Esquível & Bernardo-Gil, 1999):

```math
m_e(t) = m_{total}\\,(1 - e^{-k_1 t})
```

One fitted parameter: `k1` — rate constant (1/s).
"""
struct Esquivel <: ExtractionModel end

param_spec(::Esquivel) = [
    ParamSpec("k1", "k₁ — rate constant (1/s)", 0.0, 1e-2),
]

function simulate(::Esquivel, curve::ExtractionCurve, p::Vector{Float64})
    m_total = curve.x0 * curve.solid_mass
    k1 = p[1]
    return [m_total * (1.0 - exp(-k1 * t)) for t in curve.t]
end
