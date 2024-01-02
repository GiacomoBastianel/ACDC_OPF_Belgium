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


## Adding the energy island
BE_grid_energy_island = deepcopy(BE_grid)
add_energy_island(BE_grid_energy_island)

# BE grid with Ventilus & Bdh
BE_grid_vbdh = deepcopy(BE_grid)
BE_grid_energy_island_vbdh = deepcopy(BE_grid_energy_island)

build_ventilus_and_boucle_du_hainaut_interconnections = true
if build_ventilus_and_boucle_du_hainaut_interconnections == true
    create_ventilus(BE_grid_vbdh)
    create_boucle_du_hainaut(BE_grid_vbdh)
    create_ventilus(BE_grid_energy_island_vbdh)
    create_boucle_du_hainaut(BE_grid_energy_island_vbdh)
end


number_of_hours = 8760
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)

results = hourly_opf_BE(BE_grid,number_of_hours,load_BE,wind_onshore_BE, wind_offshore_BE, solar_pv_BE)
results_ei = hourly_opf_BE(BE_grid_energy_island,number_of_hours,load_BE,wind_onshore_BE, wind_offshore_BE, solar_pv_BE)
results_vbdh = hourly_opf_BE(BE_grid_vbdh,number_of_hours,load_BE,wind_onshore_BE, wind_offshore_BE, solar_pv_BE)
results_vbdh_ei = hourly_opf_BE(BE_grid_energy_island_vbdh,number_of_hours,load_BE,wind_onshore_BE, wind_offshore_BE, solar_pv_BE)

obj = []
for (i_id,i) in results
    push!(obj,i["objective"])
end

obj_EI = []
for (i_id,i) in results_ei
    push!(obj_EI,i["objective"])
end

obj_vbdh = []
for (i_id,i) in results_vbdh
    push!(obj_vbdh,i["objective"])
end

obj_EI_vbdh = []
for (i_id,i) in results_vbdh_ei
    push!(obj_EI_vbdh,i["objective"])
end

sum(obj)
sum(obj_EI)
sum(obj_vbdh)
sum(obj_EI_vbdh)

sum(obj_vbdh)/sum(obj)
sum(obj_EI_vbdh)/sum(obj_EI)




obj = obj*100
obj_EI = obj_EI*100
obj_vbdh = obj_vbdh*100
obj_EI_vbdh = obj_EI_vbdh*100

load_ = load_BE[1:number_of_hours]


el_price = obj./load_
el_price_EI = obj_EI./load_
el_price_vbdh = obj_vbdh./load_
el_price_EI_vbdh = obj_EI_vbdh./load_

avg_el_price = sum(el_price)/number_of_hours
avg_el_price_EI = sum(el_price_EI)/number_of_hours
avg_el_price_vdbh = sum(el_price_vbdh)/number_of_hours
avg_el_price_EI_vbdh = sum(el_price_EI_vbdh)/number_of_hours


folder_results = "/Users/giacomobastianel/Desktop/Results_Belgium/Simulations_one_year"

json_string_grid = JSON.json(results)
open(joinpath(folder_results,"one_year_BE.json"),"w" ) do f
write(f,json_string_grid)
end

json_string_grid = JSON.json(results_ei)
open(joinpath(folder_results,"one_year_BE_EI.json"),"w" ) do f
write(f,json_string_grid)
end

json_string_grid = JSON.json(results_vbdh)
open(joinpath(folder_results,"one_year_BE_vbdh.json"),"w" ) do f
write(f,json_string_grid)
end

json_string_grid = JSON.json(results_vbdh_ei)
open(joinpath(folder_results,"one_year_BE_EI_vbdh.json"),"w" ) do f
write(f,json_string_grid)
end



