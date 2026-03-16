# SFEModeling.jl

*Kinetic model fitting for supercritical fluid extraction.*

[![Build Status](https://github.com/m3g/SFEModeling.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/m3g/SFEModeling.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://m3g.github.io/SFEModeling.jl/stable/)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://m3g.github.io/SFEModeling.jl/dev/)

## Overview

SFEModeling.jl fits kinetic models for supercritical fluid extraction (SFE) to one or more
experimental extraction curves. The package:

- Accepts experimental data and operating conditions in **laboratory units** (g, cm, min).
- Supports **6 kinetic models**, from rigorous PDE/physical models to simple empirical correlations.
- Fits model parameters using global optimization from
  [BlackBoxOptim.jl](https://github.com/robertfeldt/BlackBoxOptim.jl) — no manual
  multi-start needed.
- Provides a **graphical interface** accessible via desktop shortcut or `sfegui()`.

## Supported models

| Model | Parameters | Description |
|-------|-----------|-------------|
| Sovová (1994) | `kya`, `kxa`, `xk/x0` | PDE — broken & intact cells; multi-curve with shared `xk/x0` |
| Shrinking Core — Moreno-Pulido *et al.* (2026) | `Tm`, `tau_g` | Physical — diffusion-limited leaching |
| Esquível (1999) | `k1` | Empirical — single exponential |
| Zekovic (2003) | `k1`, `k2` | Empirical — accessible fraction × exponential |
| PKM — Maksimovic (2012) | `k1`, `k2`, `k3` | Parallel-reaction kinetics |
| Spline — Rodrigues (2003) | `k1`–`k4` | Piecewise-linear CER/FER/DC |

See the [Models](@ref "Model Description") page for the equations.

## References

Martínez, J.; Martínez, J.M. (2008). Fitting the Sovová's supercritical fluid extraction model by means of a global optimization tool. *Computers & Chemical Engineering*, 32(8), 1735–1745. https://doi.org/10.1016/j.compchemeng.2007.08.016

Martínez, J.; Monteiro, A.R.; Rosa, P.T.V.; Marques, M.O.M.; Meireles, M.A.A. (2003). Multicomponent model to describe extraction of ginger oleoresin with supercritical carbon dioxide. *Industrial & Engineering Chemistry Research*, 42(5), 1057–1063. https://doi.org/10.1021/ie020694f

## References for models

Sovová, H. (1994). Rate of the vegetable oil extraction with supercritical CO₂ — I. Modelling of extraction curves. *Chemical Engineering Science*, 49(3), 409–414. https://doi.org/10.1016/0009-2509(94)87012-8

Moreno-Pulido, C.; Olwande, R.; Myers, T.; Font, F. (2026). Approximate solutions to the shrinking core model and their interpretation. *Applied Mathematical Modelling*, 154, 116715. https://doi.org/10.1016/j.apm.2025.116715

Esquível, M.M.; Bernardo-Gil, M.G.; King, M.B. (1999). Mathematical models for supercritical extraction of olive husk oil. *Journal of Supercritical Fluids*, 16(1), 43–58. https://doi.org/10.1016/S0896-8446(99)00014-5

Zeković, Z.P.; Lepojević, Ž.D.; Milošević, S.G.; Tolić, A.Š. (2003). Modeling of the thyme: liquid carbon dioxide extraction system. *Acta Periodica Technologica*, 34, 125–133. https://doi.org/10.2298/APT0334125Z

Maksimović, S.; Ivanović, J.; Skala, D. (2012). Supercritical extraction of essential oil from Mentha and mathematical modelling. *Procedia Engineering*, 42, 1767–1777. https://doi.org/10.1016/j.proeng.2012.07.571

Rodrigues, V.M.; Rosa, P.T.V.; Marques, M.O.M.; Petenate, A.J.; Meireles, M.A.A. (2003). Supercritical extraction of essential oil from aniseed using CO₂: Solubility, kinetics, and composition data. *Journal of Agricultural and Food Chemistry*, 51(6), 1518–1523. https://doi.org/10.1021/jf0257493
