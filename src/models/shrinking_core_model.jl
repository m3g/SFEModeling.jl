# ── Shrinking Core Model helper functions ─────────────────────────────────────
#
# Goto, Roy & Hirose (1996), J. Supercrit. Fluids 9, 128–133
# Moreno Pulido et al. (2025), arXiv:2507.21042v1
#
# PSS analytical solution (Eq. 34 from arXiv paper):
#
#     (s³ − 1)/3 − (s² − 1)/2 − Tₘ⁻¹(s − 1) = t      (non-dimensional)
#
# where  Tₘ = R*k/D  (Thiele modulus),  t  is non-dimensional time scaled by τ_g.
# The reacted fraction is  X(t) = 1 − s³.

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