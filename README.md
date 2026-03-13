# SFEModelling

[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://m3g.github.io/SFEModelling.jl/stable/)
[![Documentation](https://img.shields.io/badge/docs-dev-blue.svg)](https://m3g.github.io/SFEModelling.jl/dev/)
[![Build Status](https://github.com/m3g/SFEModelling.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/m3g/SFEModelling.jl/actions/workflows/CI.yml?query=branch%3Amain)

**SFEModelling** fits kinetic models for supercritical fluid extraction (SFE) to experimental extraction curves, using global optimization.

## Supported models

| Model | Parameters | Type |
|-------|-----------|------|
| [Sovová (1994)](https://doi.org/10.1016/0009-2509(94)87012-8) | `kya`, `kxa`, `xk/x0` per curve | PDE (broken & intact cells) |
| [Esquível (1999)](https://doi.org/10.1016/S0896-8446(99)00014-5) | `k1` | Empirical — single exponential |
| [Zekovic (2003)](https://doi.org/10.2298/APT0334125Z) | `k1`, `k2` | Empirical — accessible fraction + rate |
| [PKM — Maksimovic (2012)](https://doi.org/10.1016/j.proeng.2012.07.571) | `k1`, `k2`, `k3` | Parallel-reaction kinetics |
| [Spline — Rodrigues (2003)](https://doi.org/10.1021/jf0257493) | `k1`–`k4` | Piecewise-linear CER/FER/DC |

The Sovová model additionally supports **simultaneous fitting of multiple curves** sharing a common `xk/x0` parameter.

## References

Martínez, J.; Martínez, J.M. (2008). Fitting the Sovová's supercritical fluid extraction model by means of a global optimization tool. *Computers & Chemical Engineering*, 32(8), 1735–1745. https://doi.org/10.1016/j.compchemeng.2007.08.016

Martínez, J.; Monteiro, A.R.; Rosa, P.T.V.; Marques, M.O.M.; Meireles, M.A.A. (2003). Multicomponent model to describe extraction of ginger oleoresin with supercritical carbon dioxide. *Industrial & Engineering Chemistry Research*, 42(5), 1057–1063. https://doi.org/10.1021/ie020694f

## References for models

Sovová, H. (1994). Rate of the vegetable oil extraction with supercritical CO₂ — I. Modelling of extraction curves. *Chemical Engineering Science*, 49(3), 409–414. https://doi.org/10.1016/0009-2509(94)87012-8

Esquível, M.M.; Bernardo-Gil, M.G.; King, M.B. (1999). Mathematical models for supercritical extraction of olive husk oil. *Journal of Supercritical Fluids*, 16(1), 43–58. https://doi.org/10.1016/S0896-8446(99)00014-5

Zeković, Z.P.; Lepojević, Ž.D.; Milošević, S.G.; Tolić, A.Š. (2003). Modeling of the thyme: liquid carbon dioxide extraction system. *Acta Periodica Technologica*, 34, 125–133. https://doi.org/10.2298/APT0334125Z

Maksimović, S.; Ivanović, J.; Skala, D. (2012). Supercritical extraction of essential oil from Mentha and mathematical modelling. *Procedia Engineering*, 42, 1767–1777. https://doi.org/10.1016/j.proeng.2012.07.571

Rodrigues, V.M.; Rosa, P.T.V.; Marques, M.O.M.; Petenate, A.J.; Meireles, M.A.A. (2003). Supercritical extraction of essential oil from aniseed using CO₂: Solubility, kinetics, and composition data. *Journal of Agricultural and Food Chemistry*, 51(6), 1518–1523. https://doi.org/10.1021/jf0257493