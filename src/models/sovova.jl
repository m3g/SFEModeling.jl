# ── Sovová (1994) — Broken and Intact Cells PDE model ────────────────────────

"""
    Sovova()

Sovová PDE supercritical extraction model. This is the **default** model used when
calling `fit_model` without an explicit model argument.

Fits per-curve parameters `kya` (fluid-phase mass transfer coefficient, 1/s) and
`kxa` (solid-phase mass transfer coefficient, 1/s), plus a shared `xk/x0` ratio
(easily accessible solute fraction).

Returns a [`ModelFitResult`](@ref).
"""
struct Sovova <: ExtractionModel end

param_spec(::Sovova) = [
    ParamSpec("kya", "kya — fluid-phase mass transfer coeff. (1/s)", 0.0, 0.05),
    ParamSpec("kxa", "kxa — solid-phase mass transfer coeff. (1/s)", 0.0, 0.005),
    ParamSpec("xk_ratio", "xk/x₀ — accessible solute ratio (—)", 0.0, 1.0),
]

# ── Sovová simulation workspace and PDE solver ──────────────────────────────

struct SimWorkspace
    xs::Vector{Float64}
    y::Vector{Float64}
    ycal::Vector{Float64}
end

SimWorkspace(nh::Int, ndata::Int) = SimWorkspace(Vector{Float64}(undef, nh), zeros(nh + 1), zeros(ndata))

function simulate(curve::ExtractionCurve, kya, kxa, xk)
    ws = SimWorkspace(curve.nh, length(curve.t))
    simulate!(ws, curve, kya, kxa, xk)
end

function simulate!(ws::SimWorkspace, curve::ExtractionCurve, kya, kxa, xk)
    (; t, x0, solid_density, solvent_density,
       flow_rate, bed_height, bed_diameter,
       solid_mass, solubility, nh, nt) = curve

    ndata = length(t)
    xs = ws.xs
    y = ws.y
    ycal = ws.ycal

    # Initialize workspace arrays
    fill!(xs, x0)
    fill!(y, 0.0)
    fill!(ycal, 0.0)

    # Recompute porosity from bed geometry (as in Fortran code)
    eps = 1.0 - 4.0 * solid_mass / (π * bed_diameter^2 * bed_height * solid_density)
    # Interstitial velocity
    v = 4.0 * flow_rate / (solvent_density * π * bed_diameter^2 * eps)

    tempo = t[end]
    dt = tempo / nt
    dh = bed_height / nh

    yant_outlet = 0.0
    ynum_prev = 0.0
    ynum_curr = 0.0

    current_t = 0.0
    for _ in 1:nt
        current_t += dt

        # Inlet boundary condition
        y[1] = 0.0

        # Spatial loop
        for k in 1:nh
            if xs[k] > xk
                # CER period: J = kya * (Y* - Y)
                jxy = kya * (solubility - y[k])
            else
                # FER period: J = kxa * x * (1 - Y/Y*)
                jxy = kxa * xs[k] * (1.0 - y[k] / solubility)
            end

            # Update solid concentration
            xs[k] -= dt * jxy * solvent_density / (solid_density * (1.0 - eps))

            # Store previous outlet for trapezoidal rule
            if k == nh
                yant_outlet = y[nh + 1]
            end

            # Update fluid concentration (spatial march)
            y[k + 1] = y[k] + dh * jxy / (eps * v)
        end

        # Trapezoidal integration of outlet mass flow
        ynum_curr = ynum_prev + dt * (y[nh + 1] + yant_outlet) * flow_rate / 2.0

        # Interpolation: assign to experimental points in [current_t - dt, current_t]
        for i in 1:ndata
            if t[i] >= current_t - dt && t[i] <= current_t
                ycal[i] = ynum_prev + (ynum_curr - ynum_prev) * (t[i] - current_t + dt) / dt
            end
        end

        ynum_prev = ynum_curr
    end

    return ycal
end

# ── Sovová fit_model ─────────────────────────────────────────────────────────

function fit_model(
    ::Sovova,
    curves::Vector{ExtractionCurve};
    kya_bounds::Tuple{Float64,Float64} = (0.0, 0.05),
    kxa_bounds::Tuple{Float64,Float64} = (0.0, 0.005),
    xk_ratio_bounds::Tuple{Float64,Float64} = (0.0, 1.0),
    maxevals::Int = 50_000,
    tracemode::Symbol = :silent,
)
    nexp = length(curves)
    n = 2 * nexp + 1  # number of parameters

    # Build bounds: [kya_1, kxa_1, kya_2, kxa_2, ..., xk_ratio]
    search_range = Tuple{Float64,Float64}[]
    for _ in 1:nexp
        push!(search_range, kya_bounds)
        push!(search_range, kxa_bounds)
    end
    push!(search_range, xk_ratio_bounds)

    # Pre-allocate simulation workspaces (one per curve)
    workspaces = [SimWorkspace(curves[i].nh, length(curves[i].t)) for i in 1:nexp]

    # Objective function: sum of squared residuals
    function objective(a)
        xk_ratio = a[n]
        f = 0.0
        for iexp in 1:nexp
            kya_i = a[2*iexp-1]
            kxa_i = a[2*iexp]
            xk_i = curves[iexp].x0 * xk_ratio
            ycal = simulate!(workspaces[iexp], curves[iexp], kya_i, kxa_i, xk_i)
            for i in eachindex(ycal)
                f += (ycal[i] - curves[iexp].m_ext[i])^2
            end
        end
        return f
    end

    # Global optimization with BlackBoxOptim
    res = bboptimize(objective;
        SearchRange = search_range,
        NumDimensions = n,
        MaxFuncEvals = maxevals,
        TraceMode = tracemode,
    )

    best_a = best_candidate(res)
    best_f = best_fitness(res)

    # Extract results
    xk_ratio = best_a[n]
    kya_vec = [best_a[2*i-1] for i in 1:nexp]
    kxa_vec = [best_a[2*i]   for i in 1:nexp]
    xk_vec  = [curves[i].x0 * xk_ratio for i in 1:nexp]

    # Compute tcer and final calculated curves
    tcer_vec = zeros(nexp)
    ycal_all = Vector{Vector{Float64}}(undef, nexp)
    for iexp in 1:nexp
        c = curves[iexp]
        eps = 1.0 - 4.0 * c.solid_mass / (π * c.bed_diameter^2 * c.bed_height * c.solid_density)
        tcer_vec[iexp] = (c.x0 - xk_vec[iexp]) * (1.0 - eps) * c.solid_density /
                         (c.solubility * kya_vec[iexp] * c.solvent_density)
        ycal_all[iexp] = simulate(c, kya_vec[iexp], kxa_vec[iexp], xk_vec[iexp])
    end

    # Build flat spec + params for the unified show()
    _spec   = ParamSpec[ParamSpec("xk/x0", "xk/x₀ — accessible solute ratio (—)", 0.0, 1.0)]
    _params = Float64[xk_ratio]
    for i in 1:nexp
        push!(_spec,   ParamSpec("kya[$i]",  "kya — fluid-phase mass transfer coeff. (1/s)",  0.0, 0.05))
        push!(_params, kya_vec[i])
        push!(_spec,   ParamSpec("kxa[$i]",  "kxa — solid-phase mass transfer coeff. (1/s)",  0.0, 0.005))
        push!(_params, kxa_vec[i])
        push!(_spec,   ParamSpec("tCER[$i]", "tCER — CER period duration (s)",                0.0, Inf))
        push!(_params, tcer_vec[i])
    end

    return ModelFitResult(
        Sovova(), ycal_all, best_f,
        (spec=_spec, params=_params,
         kya=kya_vec, kxa=kxa_vec, xk_ratio=xk_ratio, xk=xk_vec, tcer=tcer_vec),
    )
end
