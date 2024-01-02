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


# Belgium grid without energy island
BE_grid_file = joinpath(folder_results,"test_cases/Belgian_transmission_grid_data_Elia_2023.json")
BE_grid = _PM.parse_file(BE_grid_file)
BE_grid_json = JSON.parsefile(BE_grid_file)

_PMACDC.process_additional_data!(BE_grid)
_PMACDC.process_additional_data!(BE_grid_json)

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


##################################################################
## Choosing the number of hours, scenario and climate year
number_of_hours = 8760
scenario = "DE2040"
year = "1984"
year_int = parse(Int64,year)

##################################################################
# Creating load series for Belgium from TYNDP data 
load_series_BE_max = create_load_series(scenario,year,"BE00",1,number_of_hours)
load_series_BE = load_series_BE_max
load_BE = []
for i in 1:length(load_series_BE)
    push!(load_BE,load_series_BE[i])
end


folder_results = "/Users/giacomobastianel/Desktop/Results_Belgium/Simulations_one_year"

results_base_case = JSON.parsefile(joinpath(folder_results,"one_year_BE.json"))
results_ei = JSON.parsefile(joinpath(folder_results,"one_year_BE_EI.json"))
results_vbdh = JSON.parsefile(joinpath(folder_results,"one_year_BE_vbdh.json"))
results_vbdh_ei = JSON.parsefile(joinpath(folder_results,"one_year_BE_EI_vbdh.json"))

obj_ = sum(results_base_case["$i"]["objective"] for i in 1:number_of_hours)*100
obj_ei = sum(results_ei["$i"]["objective"] for i in 1:number_of_hours)*100
obj_vbdh = sum(results_vbdh["$i"]["objective"] for i in 1:number_of_hours)*100
obj_vbdh_ei = sum(results_vbdh_ei["$i"]["objective"] for i in 1:number_of_hours)*100

obj_vbdh/obj_
obj_vbdh_ei/obj_ei

# Computing the electricity prices
obj_/sum(load_BE)
obj_ei/sum(load_BE)
obj_vbdh/sum(load_BE)
obj_vbdh_ei/sum(load_BE)

# Function to compute the CO2 emissions
function compute_CO2_emissions(grid,number_of_hours,results_dict,vector)
    for i in 1:number_of_hours
        sum_ = 0
        for (g_id,g) in grid["gen"]
            sum_ = sum_ + results_dict["$i"]["solution"]["gen"][g_id]["pg"]*g["C02_emission"]*100
        end
        push!(vector,sum_)
    end
end

CO2_base_case = []
CO2_ei = []
CO2_vbdh = []
CO2_vbdh_ei = []

compute_CO2_emissions(BE_grid,8760,results_base_case,CO2_base_case)
compute_CO2_emissions(BE_grid,8760,results_ei,CO2_ei)
compute_CO2_emissions(BE_grid,8760,results_vbdh,CO2_vbdh)
compute_CO2_emissions(BE_grid,8760,results_vbdh_ei,CO2_vbdh_ei)

# Computing the total CO2 emission per case
sum(CO2_base_case)
sum(CO2_ei)
sum(CO2_vbdh)
sum(CO2_vbdh_ei)