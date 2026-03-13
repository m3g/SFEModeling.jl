# ── PKM — Parallel-kinetics model (Fiori et al., 2012) ───────────────────────

"""
    PKM()

Parallel-kinetics model (Fiori et al., 2012):

```math
m_e(t) = m_{total}\\left[k_1(1 - e^{-k_2 t}) + (1-k_1)(1 - e^{-k_3 t})\\right]
```

Three fitted parameters: `k1` — easily accessible fraction (—); `k2` — fluid-phase
rate constant (1/s); `k3` — solid-phase rate constant (1/s).
"""
struct PKM <: ExtractionModel end

param_spec(::PKM) = [
    ParamSpec("k1", "k₁ — easily accessible fraction (—)",          0.0, 1.0),
    ParamSpec("k2", "k₂ — fluid-phase rate constant (1/s)",         0.0, 5e-2),
    ParamSpec("k3", "k₃ — solid-phase rate constant (1/s)",         0.0, 5e-3),
]

function simulate(::PKM, curve::ExtractionCurve, p::Vector{Float64})
    m_total = curve.x0 * curve.solid_mass
    k1, k2, k3 = p[1], p[2], p[3]
    return [m_total * (k1 * (1.0 - exp(-k2 * t)) + (1.0 - k1) * (1.0 - exp(-k3 * t)))
            for t in curve.t]
end
