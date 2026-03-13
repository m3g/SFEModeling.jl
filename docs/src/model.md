# Model Description

SFEModeling implements five kinetic models for supercritical fluid extraction (SFE).
All models relate cumulative extracted mass ``m_e(t)`` to time ``t``.
The **total extractable mass** is ``m_T = x_0 \cdot m_s``, where ``x_0`` is the initial
solute loading (kg/kg) and ``m_s`` is the solid mass (kg).

---

## Sovová (1994) — Broken and Intact Cells

The only **mechanistic** model in the set. It distinguishes two fractions of the solid:
easily accessible solute (outside broken cells) and solute trapped inside intact cells.
Extraction proceeds through three consecutive phases: constant extraction rate (CER),
falling extraction rate (FER), and diffusion-controlled (DC).

### Mass balance equations

Coupled PDEs along the bed height ``h``:

**Fluid phase:**

```math
\varepsilon \, v \, \frac{\partial Y}{\partial h} = J(X, Y)
```

**Solid phase:**

```math
(1 - \varepsilon)\,\rho_s\,\frac{\partial X}{\partial t} = -\rho_f\,J(X, Y)
```

### Mass transfer rate

```math
J = \begin{cases}
  k_Y a \,(Y^* - Y) & X > x_k \quad \text{(CER)} \\[4pt]
  k_X a \, X \!\left(1 - \dfrac{Y}{Y^*}\right) & X \le x_k \quad \text{(FER)}
\end{cases}
```

**Fitted parameters** (per curve, except `xk/x0` which is shared across curves):

| Symbol | Description |
|--------|-------------|
| `kya` (``k_Y a``) | Fluid-phase volumetric mass-transfer coefficient (1/s) |
| `kxa` (``k_X a``) | Solid-phase volumetric mass-transfer coefficient (1/s) |
| `xk/x0` (``x_k/x_0``) | Fraction of easily accessible solute |

The PDE is solved numerically by the method of lines (upwind finite differences + explicit Euler).

**Reference:** Sovová, H. (1994). *Chem. Eng. Sci.*, 49(3), 409–414. [doi:10.1016/0009-2509(94)87012-8](https://doi.org/10.1016/0009-2509(94)87012-8)

---

## Esquível (1999)

Single-exponential empirical model derived from a simplified mass balance:

```math
m_e(t) = m_T \left(1 - e^{-k_1 t}\right)
```

| Symbol | Description |
|--------|-------------|
| ``k_1`` | Rate constant (1/s); physically related to solubility and flow conditions |

**Reference:** Esquível, M.M.; Bernardo-Gil, M.G.; King, M.B. (1999). *J. Supercrit. Fluids*, 16(1), 43–58. [doi:10.1016/S0896-8446(99)00014-5](https://doi.org/10.1016/S0896-8446(99)00014-5)

---

## Zekovic (2003)

Two-parameter model separating the accessible yield fraction from the extraction rate:

```math
m_e(t) = m_T \, k_1 \left(1 - e^{-k_2 t}\right)
```

| Symbol | Description |
|--------|-------------|
| ``k_1`` | Accessible yield fraction (dimensionless, 0–1) |
| ``k_2`` | Rate constant (1/s) |

**Reference:** Zeković, Z.P. *et al.* (2003). *Acta Period. Technol.*, 34, 125–133. [doi](https://doi.org/10.2298/APT0334125Z)

---

## PKM — Parallel Reaction Kinetics (Maksimovic, 2012)

Interprets extraction as parallel first-order "reactions" from two solid fractions:

```math
m_e(t) = m_T \left[ k_1 \left(1 - e^{-k_2 t}\right) + (1 - k_1)\left(1 - e^{-k_3 t}\right) \right]
```

| Symbol | Description |
|--------|-------------|
| ``k_1`` | Easily accessible solute fraction (dimensionless, 0–1) |
| ``k_2`` | Fluid-phase rate constant (1/s) |
| ``k_3`` | Solid-phase rate constant (1/s), ``k_3 < k_2`` |

**Reference:** Maksimović, S.; Ivanović, J.; Skala, D. (2012). *Procedia Eng.*, 42, 1767–1777. [doi:10.1016/j.proeng.2012.07.571](https://doi.org/10.1016/j.proeng.2012.07.571)

---

## Spline — Piecewise-linear CER/FER/DC (Rodrigues, 2003)

Fits the extraction curve with **three straight-line segments**, one per extraction phase:

```math
m_e(t) = \begin{cases}
  m_T\,k_1\,t & t \le k_2 \quad \text{(CER)} \\[4pt]
  m_T\,k_1\,k_2 + m_T\,k_3\,(t - k_2) & k_2 < t \le k_4 \quad \text{(FER)} \\[4pt]
  m_T\,k_1\,k_2 + m_T\,k_3\,(k_4 - k_2) & t > k_4 \quad \text{(DC, flat)}
\end{cases}
```

| Symbol | Description |
|--------|-------------|
| ``k_1`` | CER extraction rate (1/s) |
| ``k_2`` | End time of CER phase (s) |
| ``k_3`` | FER extraction rate (1/s), ``k_3 < k_1`` |
| ``k_4`` | End time of FER phase (s), ``k_4 > k_2`` |

**Reference:** Rodrigues, V.M. *et al.* (2003). *J. Agric. Food Chem.*, 51(6), 1518–1523. [doi:10.1021/jf0257493](https://doi.org/10.1021/jf0257493)

---

## Parameter estimation

All models minimize the **sum of squared residuals** (SSR):

```math
\text{SSR} = \sum_{i=1}^{N_{\text{curves}}} \sum_{j=1}^{m_i}
\left( m_{e,\text{cal},j}^{(i)} - m_{e,\text{exp},j}^{(i)} \right)^2
```

For empirical models, all parameters are shared across curves.
For the Sovová model, `kya` and `kxa` are per-curve while `xk/x0` is shared.

Optimization uses [BlackBoxOptim.jl](https://github.com/robertfeldt/BlackBoxOptim.jl),
a derivative-free global optimizer that handles non-convex, bound-constrained problems
without manual multi-start.
