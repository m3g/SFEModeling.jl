# ── Shrinking Core Model (Moreno-Pulido et al., 2026) ────────────────────────
#
# Moreno-Pulido, C.; Olwande, R.; Myers, T.; Font, F. (2026).
# Approximate solutions to the shrinking core model and their interpretation.
# Appl. Math. Model. 154, 116715.  doi:10.1016/j.apm.2025.116715
#
# PSS analytical solution (Eq. 34):
#
#     (s³ − 1)/3 − (s² − 1)/2 − Tₘ⁻¹(s − 1) = t      (non-dimensional)
#
# where  Tₘ = R*k/D  (Thiele modulus),  t  is non-dimensional time scaled by τ_g.
# The reacted fraction is  X(t) = 1 − s³.

"""
    ShrinkingCoreModel()

Shrinking Core Model for supercritical fluid extraction (Moreno-Pulido *et al.*, 2026).

The model describes diffusion-limited leaching from a spherical solid particle whose
extractable core shrinks as solute is removed.  The pseudo-steady-state (PSS) analytical
solution relates the core radius ``s`` to non-dimensional time via

```math
\\frac{s^3 - 1}{3} - \\frac{s^2 - 1}{2} - \\frac{s - 1}{T_m} = t
```

Two fitted parameters:
- `Tm`    — Thiele modulus ``T_m = R k / D`` (—)
- `tau_g` — growth time-scale ``\\tau_g`` (s), used to convert experimental time to
  non-dimensional time: ``t = t_{\\mathrm{dim}} / \\tau_g``
"""
struct ShrinkingCoreModel <: ExtractionModel end

param_spec(::ShrinkingCoreModel) = [
    ParamSpec("Tm",    "Tₘ — Thiele modulus R·k/D (—)",        0.01,  100.0),
    ParamSpec("tau_g", "τ_g — growth time-scale (s)",          1.0,   1e5),
]

function simulate(::ShrinkingCoreModel, curve::ExtractionCurve, p::Vector{Float64})
    m_total = curve.x0 * curve.solid_mass
    Tm, tau_g = p[1], p[2]
    return map(curve.t) do t_dim
        t_nondim = t_dim / tau_g
        s = shrinking_core_pss(t_nondim, Tm)
        m_total * reacted_fraction(s)
    end
end

# ── Helper functions ──────────────────────────────────────────────────────────

"""
    _pss_time(s, Tm)

Non-dimensional time corresponding to core radius `s` for Thiele modulus `Tm`.
Evaluates the PSS relation  t(s) = (s³−1)/3 − (s²−1)/2 − (s−1)/Tm.
Note: returns a *negative* value for t because s decreases from 1 → 0.
Actually, since s ∈ (0,1], (s³−1) < 0, (s²−1) < 0, (s−1) < 0, so the
overall sign is positive (each term contributes positively).
"""
function _pss_time(s, Tm)
    return (s^3 - 1.0) / 3.0 - (s^2 - 1.0) / 2.0 - (s - 1.0) / Tm
end

"""
    _pss_final_time(Tm)

Non-dimensional time at which the core is fully consumed (s = 0).
``t_f = 1/6 + 1/T_m``
"""
_pss_final_time(Tm) = 1.0 / 6.0 + 1.0 / Tm

"""
    shrinking_core_pss(t_nondim, Tm)

Solve the PSS relation for core radius `s` at non-dimensional time `t_nondim`.
Uses bisection via `Roots.find_zero`.  Returns `s ∈ [0, 1]`.
"""
function shrinking_core_pss(t_nondim, Tm)
    t_f = _pss_final_time(Tm)
    t_nondim >= t_f && return 0.0   # fully consumed
    t_nondim <= 0.0 && return 1.0   # nothing happened yet
    f(s) = _pss_time(s, Tm) - t_nondim
    return find_zero(f, (0.0, 1.0))
end

"""
    reacted_fraction(s)

Reacted (extracted) volume fraction  X = 1 − s³.
"""
reacted_fraction(s) = 1.0 - s^3