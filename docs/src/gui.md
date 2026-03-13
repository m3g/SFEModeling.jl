# Graphical User Interface

SFEModelling includes a **built-in web GUI** — no extra packages or configuration required.
By following the [Installation](@ref) instructions you should be able the launch the GUI by clicking
on the desktop icon that is generated.

## Launch it directly from the Julia REPL:

If the desktop icon is not available, or if you experience issues with the icon launcher, 
you can, after installing the Julia package, run it from the REPL, with:

```julia
using SFEModelling
sfegui()
```

This starts a local HTTP server and opens your default browser at `http://127.0.0.1:9876`.

## Features

In the browser interface you can:

- **Upload** a data file (`.txt`, `.csv`, `.dat`, or `.xlsx`) with time and replicate columns
  — [example\_data.txt](assets/example_data.txt) · [example\_data.xlsx](assets/example_data.xlsx)
- **Select** a kinetic model from a dropdown (Sovová, Esquível, Žeković, PKM, or Spline)
- **Fill in** all operating conditions through form fields (porosity, densities, flow rate, etc.)
- **Configure** optimizer bounds for each model's parameters (bounds update automatically when
  the model is changed) and set the maximum number of evaluations
- **Run** the fitting and see results directly in the browser
- **Download** the results as a `.txt` or `.xlsx` file

No Julia code required — everything is done through the graphical form.

## Options

```julia
sfegui(port=8080, launch=false)
```

| Keyword | Default | Description |
|---------|---------|-------------|
| `port`  | `9876`  | Local port for the HTTP server |
| `launch`| `true`  | Automatically open the browser |

## Stopping the server

Press **Ctrl-C** in the REPL, or call `close(server)` on the returned server object:

```julia
server = sfegui()
# ... use the GUI ...
close(server)
```

## API

```@docs
sfegui
```
