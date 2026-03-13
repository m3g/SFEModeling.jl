# ── Kinetic models for supercritical fluid extraction ────────────────────────
#
# Shared types and individual model implementations.
# Each model lives in src/models/*.jl.

include("models/types.jl")
include("models/sovova.jl")
include("models/esquivel.jl")
include("models/zekovic.jl")
include("models/pkm.jl")
include("models/spline.jl")
include("models/shrinking_core_model.jl")
