# ── Žeković (2003) — accessible-fraction + rate model ────────────────────────

"""
    Zekovic()

Two-parameter accessible-fraction model (Žeković et al., 2003):

```math
m_e(t) = m_{total}\\, k_1\\,(1 - e^{-k_2 t})
```

Two fitted parameters: `k1` — accessible yield fraction (—); `k2` — rate constant (1/s).
"""
struct Zekovic <: ExtractionModel end

param_spec(::Zekovic) = [
    ParamSpec("k1", "k₁ — accessible yield fraction (—)", 0.01, 1.0),
    ParamSpec("k2", "k₂ — rate constant (1/s)",           0.0,  1e-2),
]

function simulate(::Zekovic, curve::ExtractionCurve, p::Vector{Float64})
    m_total = curve.x0 * curve.solid_mass
    k1, k2 = p[1], p[2]
    return [m_total * k1 * (1.0 - exp(-k2 * t)) for t in curve.t]
end
