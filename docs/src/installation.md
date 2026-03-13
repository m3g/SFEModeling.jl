# Installation

## Windows

For Windows we provide an installer which should take care of all the steps: 

[Download Windows Installer](https://github.com/m3g/SFEModelling.jl/releases/download/v1.2.0/SFEModelling-Installer.exe)

The installer will: 

1. Install the Julia language if not yet available. 
2. Install the SFEModelling application.
3. Add an icon to your desktop.

## Manual step-by-step installation

The manual installation can be performed on all platforms (Linux/MacOS/Windows), and is necessary for the
advanced (command-line) use of the package.  

There are to installation modes: the SFEModelling *Application* and the SFEModelling *Package*. 

- The *Application* is a standalone executable, linked to the desktop icon, and that allows the execution of the package using the graphical user interface. 
- The *Package* has the same functionalities, but is accessible through the Julia REPL (the terminal) and can be used for advanced scripting, large-scale multiple fits, etc. Installation of the package also gives access to the graphical user interface.

### 1. Installing Julia

Install Julia following the instructions of the official Julia distribution page: [https://julialang.org/downloads/](https://julialang.org/downloads/).

### 2. Installing the SFEModelling Application

Start the Julia REPL (which will open the `julia>` terminal), use these commands:

```julia-repl
julia> import Pkg; Pkg.Apps.add("SFEModelling")
```

This will add an icon to your desktop, with which you can start the graphical user interface.

### 3. Installing the SFEModelling Package

The SFEModelling package is installed similarly, but provides the advanced (command-line) interface that allows programming tasks. Installation is performed with the following command:

```julia-repl
julia> import Pkg; Pkg.add("SFEModelling")
```

The package is then used with:

```julia-repl
julia> using SFEModelling
```

The graphical user interface can also be launched, by executing the `sfegui()` command.

!!! tip "Advanced usage tips"
    - If you use **VS Code** for programming and scripting, install the
      [Julia extension](https://marketplace.visualstudio.com/items?itemName=julialang.language-julia)
      for syntax highlighting, inline evaluation, and an integrated REPL.

## Updating

To update the *Application*, start the Jula REPL and use:

```julia-repl
julia> import Pkg; Pkg.Apps.update("SFEModelling")
```

To update the *Package*, use:

```julia-repl
julia> import Pkg; Pkg.update("SFEModelling")
```

