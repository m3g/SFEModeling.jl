module SFEModeling

using BlackBoxOptim
using DelimitedFiles: readdlm
using Printf
using XLSX
using HTTP
using JSON3
using Roots: find_zero

export ExtractionCurve, TextTable, ExcelTable, sfegui, create_shortcut, export_results
export ExtractionModel, ParamSpec, ModelFitResult, fit_model, param_spec, simulate
export Sovova, Esquivel, Zekovic, PKM, SplineModel, ShrinkingCoreModel

include("extraction_curve.jl")
include("texttable.jl")
include("exceltable.jl")
include("models.jl")
include("fit_model.jl")
include("export_results.jl")
include("create_shortcut.jl")
include("gui.jl")
include("sfegui.jl")

end
