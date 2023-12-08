# Solving OPF for Belgium without energy island for now
## Calling packages
using Ipopt
using PowerModels; const _PM = PowerModels
using JuMP
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using Gurobi
using Feather
using CSV
using DataFrames; const _DF = DataFrames
using JSON
#using PowerModelsAnalytics
import ExcelFiles; const _EF = ExcelFiles
using PowerPlots
using Plots
using DataFrames
using XLSX


##################################################################
## Including other files to call the needed functions
include("load_data.jl")
include("build_grid_data.jl")
include("get_grid_data.jl")
#include("process_results.jl")
##################################################################
## Processing input data
folder_results = @__DIR__

# Belgium grid without energy island
BE_grid_file = joinpath(folder_results,"Belgian_transmission_grid_data_Elia_2023.json")
BE_grid = _PM.parse_file(BE_grid_file)
#_PMACDC.process_additional_data!(BE_grid)

# North sea grid backbone -> to be adjusted later
North_sea_grid_file = joinpath(folder_results,"North_Sea_zonal_model_with_generators.m")
North_sea_grid = _PM.parse_file(North_sea_grid_file)
_PMACDC.process_additional_data!(North_sea_grid)

# Example of a PowerModels.jl dictionary
example_dc_grid_file = "/Users/giacomobastianel/.julia/packages/PowerModelsACDC/mpvnc/test/data/case5_acdc.m"
example_dc_grid = _PM.parse_file(example_dc_grid_file)
_PMACDC.process_additional_data!(example_dc_grid)

##################################################################
## Choosing the number of hours, scenario and climate year
number_of_hours = 8760
scenario = "DE2040"
year = "1984"
year_int = parse(Int64,year)

##################################################################
## Processing time series
# Creating RES time series for Belgium from Feather files in tyndpdata desktop folder
pv, wind_onshore, wind_offshore = load_res_data()
wind_onshore_BE, wind_offshore_BE, solar_pv_BE = make_res_time_series(wind_onshore, wind_offshore, pv, "BE00",year_int)

# Creating load series for Belgium from TYNDP data 
load_series_BE_max = create_load_series(scenario,year,"BE00",1,number_of_hours)
load_series_BE = load_series_BE_max
load_BE = []
for i in 1:length(load_series_BE)
    push!(load_BE,load_series_BE[i])
end

# Adding "power_portion" to loads (percentage out of the total load), useful to distribute the total demand among each load 
dimensioning_load(BE_grid)

###############################################################
## Processing grid
# Creating gens and loads for each neighbouring country -> not working yet
#create_gen_load_interconnections(BE_grid)

# Creating power flow series for each interconnector, to be downloaded for each year by ENTSO-E TYNDP database
power_flow_LU_BE,power_flow_BE_LU,power_flow_DE_BE,power_flow_BE_DE,power_flow_NL_BE,power_flow_BE_NL,power_flow_UK_BE,power_flow_BE_UK,power_flow_FR_BE,power_flow_BE_FR = create_interconnectors_power_flow(BE_grid)
flow_BE_DE,flow_DE_BE,flow_UK_BE,flow_BE_UK,flow_LU_BE,flow_BE_LU,flow_NL_BE,flow_BE_NL,flow_FR_BE,flow_BE_FR = sanity_check(power_flow_DE_BE,power_flow_BE_DE,power_flow_UK_BE,power_flow_BE_UK,power_flow_LU_BE,power_flow_BE_LU,power_flow_NL_BE,power_flow_BE_NL,power_flow_FR_BE,power_flow_BE_FR,number_of_hours)

number_of_hours = 720
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
results = hourly_opf_BE(BE_grid,number_of_hours,load_BE,wind_onshore_BE, wind_offshore_BE, solar_pv_BE)

obj = []
for (i_id,i) in results
    push!(obj,results[i_id]["objective"])
end


#=
json_string_grid = JSON.json(BE_NS_grid)
open(joinpath(folder_results,folder,"Belgium_and_North_Sea_grid.json"),"w" ) do f
write(f,json_string_grid)

# Including Ventilus and Boucle du Hainaut -> not implemented yet
build_ventilus_and_boucle_du_hainaut_interconnections = false
if build_ventilus_and_boucle_du_hainaut_interconnections == true
    create_ventilus_and_boucle_du_hainaut_interconnections(BE_grid)
end
=#

