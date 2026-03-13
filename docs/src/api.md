```@meta
CollapsedDocStrings = true
```

# API Reference

## Input

```@docs
ExtractionCurve
```

## Data readers

```@docs
TextTable
ExcelTable
```

## Fitting

```@docs
fit_model
param_spec
```

Available model types (pass an instance as the first argument to `fit_model`; omit for the default Sovová PDE model):

```@docs
Sovova
Esquivel
Zekovic
PKM
SplineModel
```

## Output

```@docs
ModelFitResult
export_results
```

## Graphical Interface

See the [GUI](@ref "Graphical User Interface") page.

## Utilities

```@docs
create_shortcut
```
