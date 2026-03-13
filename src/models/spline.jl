# ── Spline (2003) — piecewise-linear CER/FER/DC model ────────────────────────

"""
    SplineModel()

Piecewise-linear CER/FER/DC model:

- **CER** phase (0 ≤ t ≤ k₂): ``m_e = m_{total}\\,k_1\\,t``
- **FER** phase (k₂ < t ≤ k₄): ``m_e = m_{CER} + m_{total}\\,k_3\\,(t - k_2)``
- **DC** phase (t > k₄): ``m_e = m_{FER}`` (constant)

Four fitted parameters: `k1` — CER rate (1/s); `k2` — CER end time (s);
`k3` — FER rate (1/s); `k4` — FER end time (s).
"""
struct SplineModel <: ExtractionModel end

param_spec(::SplineModel) = [
    ParamSpec("k1", "k₁ — CER rate (1/s)",             0.0, 5e-2),
    ParamSpec("k2", "k₂ — CER end time (s)",            0.0, 3600.0),
    ParamSpec("k3", "k₃ — FER rate (1/s)",             0.0, 1e-2),
    ParamSpec("k4", "k₄ — FER end time (s)",            0.0, 7200.0),
]

function simulate(::SplineModel, curve::ExtractionCurve, p::Vector{Float64})
    m_total = curve.x0 * curve.solid_mass
    k1, k2, k3, k4 = p[1], p[2], p[3], p[4]
    m_cer = m_total * k1 * k2
    m_fer = m_cer + m_total * k3 * max(k4 - k2, 0.0)
    return map(curve.t) do t
        if t <= k2
            m_total * k1 * t
        elseif t <= k4
            m_cer + m_total * k3 * (t - k2)
        else
            m_fer
        end
    end
end
