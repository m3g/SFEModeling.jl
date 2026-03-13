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

1. Sovová, H. **Rate of the vegetable oil extraction with supercritical CO₂ — I. Modelling of extraction curves.** *Chemical Engineering Science*, v. 49, n. 3, p. 409–414, 1994. [doi:10.1016/0009-2509(94)87012-8](https://doi.org/10.1016/0009-2509(94)87012-8)

2. Martínez, J.; Martínez, J.M. **Fitting the Sovová's supercritical fluid extraction model by means of a global optimization tool.** *Computers & Chemical Engineering*, v. 32, n. 8, p. 1735–1745, 2008. [doi:10.1016/j.compchemeng.2007.08.016](https://doi.org/10.1016/j.compchemeng.2007.08.016)

3. Martínez, J.; Monteiro, A.R.; Rosa, P.T.V.; Marques, M.O.M.; Meireles, M.A.A. **Multicomponent model to describe extraction of ginger oleoresin with supercritical carbon dioxide.** *Industrial & Engineering Chemistry Research*, v. 42, n. 5, p. 1057–1063, 2003. [doi:10.1021/ie020694f](https://doi.org/10.1021/ie020694f)
