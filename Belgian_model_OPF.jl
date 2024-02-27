using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
#using ACDC_OPF_Belgium; const _BE = ACDC_OPF_Belgium
using Gurobi
using JuMP
using DataFrames
using CSV
using Plots
using Feather
using JSON
using Ipopt

gurobi = JuMP.optimizer_with_attributes(Gurobi.Optimizer)
ipopt = JuMP.optimizer_with_attributes(Ipopt.Optimizer)

include(joinpath((@__DIR__,"src/core/build_grid_data.jl")))
include(joinpath((@__DIR__,"src/core/load_data.jl")))
#include(joinpath((@__DIR__,"src/core/traversal_algorithm.jl")))

##################################################################
## Processing input data
folder_results = @__DIR__

# Adjusting the substations

# Belgium grid without energy island
BE_grid_file = joinpath(folder_results,"test_cases/Belgian_transmission_grid_data_Elia_2023.json")
BE_grid = _PM.parse_file(BE_grid_file)
BE_grid_json = JSON.parsefile(BE_grid_file)

#=
# If something needs to be corrected
BE_grid["gen"]["36"]["substation_full_name_kV"] = deepcopy(BE_grid["bus"]["66"]["full_name_kV"])
BE_grid["gen"]["44"]["substation_full_name_kV"] = deepcopy(BE_grid["bus"]["66"]["full_name_kV"])
BE_grid["gen"]["25"]["substation_full_name_kV"] = deepcopy(BE_grid["bus"]["66"]["full_name_kV"])
BE_grid["gen"]["41"]["substation_full_name_kV"] = deepcopy(BE_grid["bus"]["66"]["full_name_kV"])
BE_grid["gen"]["37"]["substation_full_name_kV"] = deepcopy(BE_grid["bus"]["66"]["full_name_kV"])
BE_grid["gen"]["30"]["substation_full_name_kV"] = deepcopy(BE_grid["bus"]["66"]["full_name_kV"])
BE_grid["gen"]["40"]["substation_full_name_kV"] = deepcopy(BE_grid["bus"]["66"]["full_name_kV"])
BE_grid["gen"]["45"]["substation_full_name_kV"] = deepcopy(BE_grid["bus"]["66"]["full_name_kV"])
BE_grid["gen"]["38"]["substation_full_name_kV"] = deepcopy(BE_grid["bus"]["66"]["full_name_kV"])
BE_grid["gen"]["29"]["substation_full_name_kV"] = deepcopy(BE_grid["bus"]["66"]["full_name_kV"])

json_string_data = JSON.json(BE_grid)
folder_results = @__DIR__

open(joinpath(folder_results,"test_cases/Belgian_transmission_grid_data_Elia_2023.json"),"w" ) do f
write(f,json_string_data)
end
=#

#_PMACDC.process_additional_data!(BE_grid)
#_PMACDC.process_additional_data!(BE_grid_json)

# North sea grid backbone -> to be adjusted later
North_sea_grid_file = joinpath(folder_results,"test_cases/North_Sea_zonal_model_with_generators.m")
North_sea_grid = _PM.parse_file(North_sea_grid_file)
_PMACDC.process_additional_data!(North_sea_grid)

# Example of a PowerModels.jl dictionary
example_dc_grid_file = joinpath(folder_results,"test_cases/case5_acdc.m")
example_dc_grid = _PM.parse_file(example_dc_grid_file)
_PMACDC.process_additional_data!(example_dc_grid)


# Testing the OPF
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
result = _PMACDC.run_acdcopf(BE_grid,DCPPowerModel,gurobi; setting = s)

result = _PMACDC.run_acdcopf(BE_grid,ACPPowerModel,ipopt; setting = s)



BE_grid["branchdc"]["1"]["rateA"] = 10.0
BE_grid["branchdc"]["2"]["rateA"] = 10.0


json_string_data = JSON.json(BE_grid)
folder_results = @__DIR__

open(joinpath(folder_results,"test_cases/Belgian_transmission_grid_data_Elia_2023.json"),"w" ) do f
write(f,json_string_data)
end











##################################################################
## Choosing the number of hours, scenario and climate year
number_of_hours = 8760
scenario = "DE2040"
year = "1984"
year_int = parse(Int64,year)

##################################################################
## Processing time series -> this needs to be fixed for Github!
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
create_gen_load_interconnections(BE_grid)

# Creating power flow series for each interconnector, to be downloaded for each year by ENTSO-E TYNDP database
power_flow_LU_BE,power_flow_BE_LU,power_flow_DE_BE,power_flow_BE_DE,power_flow_NL_BE,power_flow_BE_NL,power_flow_UK_BE,power_flow_BE_UK,power_flow_FR_BE,power_flow_BE_FR = create_interconnectors_power_flow(BE_grid)
flow_BE_DE,flow_DE_BE,flow_UK_BE,flow_BE_UK,flow_LU_BE,flow_BE_LU,flow_NL_BE,flow_BE_NL,flow_FR_BE,flow_BE_FR = sanity_check(power_flow_DE_BE,power_flow_BE_DE,power_flow_UK_BE,power_flow_BE_UK,power_flow_LU_BE,power_flow_BE_LU,power_flow_NL_BE,power_flow_BE_NL,power_flow_FR_BE,power_flow_BE_FR,number_of_hours)


# Adding the energy island
BE_grid_energy_island = deepcopy(BE_grid)
add_energy_island(BE_grid_energy_island)


# Running the OPF for the base case
number_of_hours = 168
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
results = hourly_opf_BE(BE_grid,number_of_hours,load_BE,wind_onshore_BE, wind_offshore_BE, solar_pv_BE)

obj = []
for (i_id,i) in results
    push!(obj,i["objective"])
end


for (b_id,b) in BE_grid["bus"]
    print([b_id,b["full_name_kV"]],"\n")
end

BE_grid["bus"]["1"]
BE_grid["bus"]["2"]
BE_grid["bus"]["3"]
BE_grid["bus"]["4"]

BE_grid["busdc"]["4"]
BE_grid["bus"]["129"]

count_ = 0
br_ids = []
for (br_id,br) in BE_grid["branch"]
    if haskey(br,"interconnection") && br["interconnection"] == true
        count_ += 1
        push!(br_ids,br_id)
    end
end

