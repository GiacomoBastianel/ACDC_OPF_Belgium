using PowerModels; const _PM = PowerModels
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using ACDC_OPF_Belgium; const _BE = ACDC_OPF_Belgium
using Gurobi
using JuMP
using DataFrames
using CSV
using Plots

gurobi = JuMP.optimizer_with_attributes(Gurobi.Optimizer)

include("src/core/build_grid_data.jl")

##################################################################
## Processing input data
folder_results = @__DIR__

# Belgium grid without energy island
BE_grid_file = joinpath(folder_results,"test_cases/Belgian_transmission_grid_data_Elia_2023.json")
BE_grid = _PM.parse_file(BE_grid_file)
#_PMACDC.process_additional_data!(BE_grid)

for (br_id,br) in BE_grid["branch"]
    br["br_r"] = br["br_r"]/100
    br["br_x"] = br["br_x"]/100
end

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
## Processing time series -> this needs to be fixed for Github!
# Creating RES time series for Belgium from Feather files in tyndpdata desktop folder
pv, wind_onshore, wind_offshore = _BE.load_res_data()
wind_onshore_BE, wind_offshore_BE, solar_pv_BE = _BE.make_res_time_series(wind_onshore, wind_offshore, pv, "BE00",year_int)

# Creating load series for Belgium from TYNDP data 
load_series_BE_max = create_load_series(scenario,year,"BE00",1,number_of_hours)
load_series_BE = load_series_BE_max
load_BE = []
for i in 1:length(load_series_BE)
    push!(load_BE,load_series_BE[i])
end

# Adding "power_portion" to loads (percentage out of the total load), useful to distribute the total demand among each load 
_BE.dimensioning_load(BE_grid)

###############################################################
## Processing grid
# Creating gens and loads for each neighbouring country -> not working yet
create_gen_load_interconnections(BE_grid)

# Creating power flow series for each interconnector, to be downloaded for each year by ENTSO-E TYNDP database
power_flow_LU_BE,power_flow_BE_LU,power_flow_DE_BE,power_flow_BE_DE,power_flow_NL_BE,power_flow_BE_NL,power_flow_UK_BE,power_flow_BE_UK,power_flow_FR_BE,power_flow_BE_FR = create_interconnectors_power_flow(BE_grid)
flow_BE_DE,flow_DE_BE,flow_UK_BE,flow_BE_UK,flow_LU_BE,flow_BE_LU,flow_NL_BE,flow_BE_NL,flow_FR_BE,flow_BE_FR = _BE.sanity_check(power_flow_DE_BE,power_flow_BE_DE,power_flow_UK_BE,power_flow_BE_UK,power_flow_LU_BE,power_flow_BE_LU,power_flow_NL_BE,power_flow_BE_NL,power_flow_FR_BE,power_flow_BE_FR,number_of_hours)


## Adding the energy island
BE_grid_energy_island = deepcopy(BE_grid)
add_energy_island(BE_grid_energy_island)

# Reducing load to today's values
load_BE = load_BE*0.7

number_of_hours = 24
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
results = hourly_opf_BE(BE_grid,number_of_hours,load_BE,wind_onshore_BE, wind_offshore_BE, solar_pv_BE)

obj = []
for (i_id,i) in results
    push!(obj,i["objective"])
end

number_of_hours = 24
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
results_EI = hourly_opf_BE(BE_grid_energy_island,number_of_hours,load_BE,wind_onshore_BE, wind_offshore_BE, solar_pv_BE)

obj_EI = []
for (i_id,i) in results_EI
    push!(obj_EI,i["objective"])
end




for (br_id,br) in BE_grid_energy_island["branch"]
    #if br["f_bus"] == 26 || br["t_bus"] == 26
        print(br_id,"_",results_EI["24"]["solution"]["branch"][br_id]["pt"],"_",abs(results_EI["1"]["solution"]["branch"][br_id]["pt"]/br["rate_a"]),"\n")
    #end
end


for (br_id,br) in BE_grid_energy_island["bus"]
    #if br["f_bus"] == 26 || br["t_bus"] == 26
        print(br["bus_type"],"\n")
    #end
end


voll_ = []
for i in 1:number_of_hours
    sum_ = 0
    for (g_id,g) in BE_grid["gen"]
        if g["type"] == "VOLL"
            sum_ = sum_ + results_EI["$i"]["solution"]["gen"][g_id]["pg"]
        end
    end
    push!(voll_,sum_)
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
#=
power_flows = []
for i in 1:8760
    hourly_inflow = deepcopy(power_flow_DE_BE[i]+power_flow_FR_BE[i]+power_flow_LU_BE[i]+power_flow_NL_BE[i]+power_flow_UK_BE[i])
    push!(power_flows, hourly_inflow)
end

plot(power_flows)
=#
