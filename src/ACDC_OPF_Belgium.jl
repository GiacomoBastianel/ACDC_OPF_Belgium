#isdefined(Base, :__precompile__) && __precompile__()

module ACDC_OPF_Belgium

    import Ipopt
    import PowerModels
    import JuMP
    import PowerModelsACDC
    import Gurobi
    import Feather
    import CSV
    import DataFrames
    import JSON
    import ExcelFiles
    import XLSX
    import Memento

    # Create our module level logger (this will get precompiled)
    #const _LOGGER = Memento.getlogger(@__MODULE__)

    # Register the module level logger at runtime so that folks can access the logger via `getlogger(PowerModels)`
    # NOTE: If this line is not included then the precompiled `_PM._LOGGER` won't be registered at runtime.

    #__init__() = Memento.register(_LOGGER)


    include("core/load_data.jl")
    include("core/build_grid_data.jl")
    include("core/Creating_Belgian_grid.jl")
    include("core/traversal_algorithm.jl")
end

