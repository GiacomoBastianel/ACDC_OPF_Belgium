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

# List of buses to be implemented for the synthetic network
#=
27 => "OFFSHORE ON STEVIN_380"
28 => "NEMO_380"
26 => "GEZELLE_380"
60 => "OFFSHORE ON STEVIN_220"
61 => "OFFSHORE ON STEVIN_220"
128 =>, "UK00_380"
66 => "BANK ZONDER NAAM_220"

BE_grid["branch"]["176"]
BE_grid["branch"]["93"]
BE_grid["branch"]["84"]
=#

buses_syn_BE = [27,28,26,60,61,128,66]
branches_syn_BE = [40,41,42,84,93,176]

count_ = 0
for i in buses_syn_BE
    print(i,"\n")
    for (l_id,l) in BE_grid["load"]
        if l["load_bus"] == i
            print([i,l],"\n")
            count_ += 1
        end
    end
end

BE_grid_synthetic = deepcopy(BE_grid)
BE_grid_synthetic["bus"] = Dict{String,Any}()
BE_grid_synthetic["gen"] = Dict{String,Any}()
BE_grid_synthetic["branch"] = Dict{String,Any}()
BE_grid_synthetic["load"] = Dict{String,Any}()

## Adding buses
for i in buses_syn_BE
    BE_grid_synthetic["bus"]["$i"] = deepcopy(BE_grid["bus"]["$i"])
end
# Add synthetic aggregated bus
BE_grid_synthetic["bus"]["1"] = deepcopy(BE_grid["bus"]["1"])
BE_grid_synthetic["bus"]["1"]["lat"] = 50.846667
BE_grid_synthetic["bus"]["1"]["lon"] = 4.3525
BE_grid_synthetic["bus"]["1"]["full_name_kV"] = "BE_aggregated_380"
BE_grid_synthetic["bus"]["1"]["name_kV"] = "BE_aggregated_380"
BE_grid_synthetic["bus"]["1"]["full_name"] = "BE_aggregated"
BE_grid_synthetic["bus"]["1"]["name"] = "BE_aggregated"
BE_grid_synthetic["bus"]["1"]["ZIP_code"] = 1000

# Adding branches
for i in branches_syn_BE
    BE_grid_synthetic["branch"]["$i"] = deepcopy(BE_grid["branch"]["$i"])
end
BE_grid_synthetic["branch"]["1"] = deepcopy(BE_grid["branch"]["1"])
BE_grid_synthetic["branch"]["1"]["f_bus"] = 26
BE_grid_synthetic["branch"]["1"]["f_bus_name"] = "GEZEL"
BE_grid_synthetic["branch"]["1"]["f_bus_name_kV"] = "GEZEL_380"
BE_grid_synthetic["branch"]["1"]["f_bus_full_name_kV"] = "GEZELLE_380"
BE_grid_synthetic["branch"]["1"]["f_bus_full_name"] = "GEZELLE"
BE_grid_synthetic["branch"]["1"]["t_bus"] = 1
BE_grid_synthetic["branch"]["1"]["t_bus_name"] = "BE_aggregated"
BE_grid_synthetic["branch"]["1"]["t_bus_name_kV"] = "BE_aggregated_380"
BE_grid_synthetic["branch"]["1"]["t_bus_full_name_kV"] = "BE_aggregated_380"
BE_grid_synthetic["branch"]["1"]["t_bus_full_name"] = "BE_aggregated"
BE_grid_synthetic["branch"]["1"]["rate_a"] = 200.00
BE_grid_synthetic["branch"]["1"]["base_kV"] = 380


# Deleting ALEGRO
delete!(BE_grid_synthetic["convdc"],"2")
delete!(BE_grid_synthetic["convdc"],"4")
delete!(BE_grid_synthetic["branchdc"],"2")
delete!(BE_grid_synthetic["busdc"],"4")
delete!(BE_grid_synthetic["busdc"],"2")

# Adding aggregated load
p_max = 0
q_max = 0
pd = 0
qd = 0
for (l_id,l) in BE_grid["load"]
    p_max = p_max + l["pmax"]
    pd = pd + l["pd"]
    qd = qd + l["qd"]
end
BE_grid_synthetic["load"]["1"] = deepcopy(BE_grid["load"]["1"])
BE_grid_synthetic["load"]["1"]["power_portion"] = 1.0
BE_grid_synthetic["load"]["1"]["name_no_kV"] = "BE_aggregated"
BE_grid_synthetic["load"]["1"]["name"] = "BE_aggregated_380"
BE_grid_synthetic["load"]["1"]["full_name_kV"] = "BE_aggregated_380"
BE_grid_synthetic["load"]["1"]["full_name"] = "BE_aggregated"
BE_grid_synthetic["load"]["1"]["pmax"] = 150.00 #pu
BE_grid_synthetic["load"]["1"]["pd"] = pd
BE_grid_synthetic["load"]["1"]["qd"] = qd
BE_grid_synthetic["load"]["1"]["load_bus"] = 1
BE_grid_synthetic["load"]["1"]["source_id"][2] = 1
delete!(BE_grid_synthetic["load"]["1"],"Zcc13")
delete!(BE_grid_synthetic["load"]["1"],"Zcc12")
delete!(BE_grid_synthetic["load"]["1"],"pmax_3")
delete!(BE_grid_synthetic["load"]["1"],"pmax_2")
delete!(BE_grid_synthetic["load"]["1"],"Zcc23")
delete!(BE_grid_synthetic["load"]["1"],"max_tap")
delete!(BE_grid_synthetic["load"]["1"],"base_kV_1")
delete!(BE_grid_synthetic["load"]["1"],"base_kV_2")
delete!(BE_grid_synthetic["load"]["1"],"base_kV_3")
delete!(BE_grid_synthetic["load"]["1"],"delta_V_per_tap")
delete!(BE_grid_synthetic["load"]["1"],"nom_tap")

# Adding aggregated gen -> add essentially what one can find in the ENTSO-E TYNDP
function compute_installed_capacities(grid_m)
    types = []
    for (i_id,i) in grid_m["gen"]
        push!(types,i["type"])
    end
    unique_types = unique(types)
    installed_capacities = Dict{String,Any}()
    for i in eachindex(unique_types)
        b = unique_types[i]
        installed_capacities["$b"] = Dict{String,Any}()
        installed_capacities["$b"]["pmax"] = 0
    end
    for i in eachindex(installed_capacities)
        for (l_id,l) in grid_m["gen"]
            if l["type"] == i    
                installed_capacities["$i"]["pmax"] = installed_capacities["$i"]["pmax"] + l["pmax"]
            end
        end
    end
    return installed_capacities
end


capacities = compute_installed_capacities(BE_grid)
capacities["VOLL"]["pmax"] = 99.99

# Fix this
count_ = 0
for i in eachindex(capacities)
    print(i,"\n")
    if i != "Offshore Wind" || i != "Reservoir" 
        count_ += 1 
        BE_grid_synthetic["gen"]["$count_"] = deepcopy(BE_grid["gen"]["1"])
        BE_grid_synthetic["gen"]["$count_"]["pmax"] = capacities["$i"]["pmax"]
        BE_grid_synthetic["gen"]["$count_"]["qmax"] = capacities["$i"]["pmax"]/2
        BE_grid_synthetic["gen"]["$count_"]["qmin"] = - capacities["$i"]["pmax"]/2
        BE_grid_synthetic["gen"]["$count_"]["name"] = i
        BE_grid_synthetic["gen"]["$count_"]["type"] = i
        BE_grid_synthetic["gen"]["$count_"]["installed_capacity"] = capacities["$i"]["pmax"]
        delete!(BE_grid_synthetic["gen"]["$count_"],"owner")
        delete!(BE_grid_synthetic["gen"]["$count_"],"pc1")
        delete!(BE_grid_synthetic["gen"]["$count_"],"pc2")
        delete!(BE_grid_synthetic["gen"]["$count_"],"qc1min")
        delete!(BE_grid_synthetic["gen"]["$count_"],"qc2max")
        delete!(BE_grid_synthetic["gen"]["$count_"],"ramp_10")
        delete!(BE_grid_synthetic["gen"]["$count_"],"shutdown")
        delete!(BE_grid_synthetic["gen"]["$count_"],"ramp_30")
        delete!(BE_grid_synthetic["gen"]["$count_"],"ramp_q")
        delete!(BE_grid_synthetic["gen"]["$count_"],"ramp_agc")
        delete!(BE_grid_synthetic["gen"]["$count_"],"qc1max")
        delete!(BE_grid_synthetic["gen"]["$count_"],"apf")
        delete!(BE_grid_synthetic["gen"]["$count_"],"CO2_emission")
        delete!(BE_grid_synthetic["gen"]["$count_"],"NOx_emission")
        delete!(BE_grid_synthetic["gen"]["$count_"],"SOx_emission")
        delete!(BE_grid_synthetic["gen"]["$count_"],"inertia_constant")
        BE_grid_synthetic["gen"]["$count_"]["substation"] = "BE_aggregated_380"
        BE_grid_synthetic["gen"]["$count_"]["substation_full_name_kV"] = "BE_aggregated_380"
        BE_grid_synthetic["gen"]["$count_"]["substation_full_name"] = "BE_aggregated"
        BE_grid_synthetic["gen"]["$count_"]["substation_short_name_kV"] = "BE_aggregated_380"
        BE_grid_synthetic["gen"]["$count_"]["substation_short_name"] = "BE_aggregated"
        BE_grid_synthetic["gen"]["$count_"]["gen_bus"] = 1
        for (g_id,g) in BE_grid["gen"]
            if g["type"] == BE_grid_synthetic["gen"]["$count_"]["type"]
                if haskey(g,"CO2_emission")
                    BE_grid_synthetic["gen"]["$count_"]["CO2_emission"] = deepcopy(g["CO2_emission"])
                    BE_grid_synthetic["gen"]["$count_"]["NOx_emission"] = deepcopy(g["NOx_emission"])
                    BE_grid_synthetic["gen"]["$count_"]["SOx_emission"] = deepcopy(g["SOx_emission"])
                    BE_grid_synthetic["gen"]["$count_"]["inertia_constant"] = deepcopy(g["inertia_constant"])
                end
                    BE_grid_synthetic["gen"]["$count_"]["gen_type"] = deepcopy(g["gen_type"])
                    BE_grid_synthetic["gen"]["$count_"]["fuel_type"] = deepcopy(g["fuel_type"])
                    BE_grid_synthetic["gen"]["$count_"]["cost"][1] = deepcopy(g["cost"][1])
            end
        end
    end
end

BE_grid_synthetic["gen"]["41"] = deepcopy(BE_grid["gen"]["41"])
BE_grid_synthetic["gen"]["45"] = deepcopy(BE_grid["gen"]["45"])
BE_grid_synthetic["gen"]["38"] = deepcopy(BE_grid["gen"]["38"])
BE_grid_synthetic["gen"]["30"] = deepcopy(BE_grid["gen"]["30"])
BE_grid_synthetic["gen"]["37"] = deepcopy(BE_grid["gen"]["37"])
BE_grid_synthetic["gen"]["29"] = deepcopy(BE_grid["gen"]["29"])
BE_grid_synthetic["gen"]["25"] = deepcopy(BE_grid["gen"]["25"])
BE_grid_synthetic["gen"]["44"] = deepcopy(BE_grid["gen"]["44"])
BE_grid_synthetic["gen"]["40"] = deepcopy(BE_grid["gen"]["40"])
BE_grid_synthetic["gen"]["36"] = deepcopy(BE_grid["gen"]["36"])

gen_costs,inertia_constants,emission_factor_CO2,start_up_cost,emission_factor_NOx,emission_factor_SOx = gen_values()
assigning_gen_values(BE_grid_synthetic)

delete!(BE_grid_synthetic["gen"],"5")
delete!(BE_grid_synthetic["gen"],"6")

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
result = _PMACDC.run_acdcopf(BE_grid_synthetic,DCPPowerModel,gurobi; setting = s)


add_energy_island_synthetic_network(BE_grid_synthetic)

json_string_data = JSON.json(BE_grid_synthetic)
folder_results = @__DIR__

open(joinpath(folder_results,"test_cases/Belgian_transmission_grid_synthetic_energy_island_2023.json"),"w" ) do f
write(f,json_string_data)
end

# CO2 EMISSIONS
# GEN TYPES
# FUEL TYPE
# COST
# NOx_emissions
# SOx_emissions
# inertia constant




#=
for (b_id,b) in BE_grid["bus"]
    print([b_id,b["full_name_kV"]],"\n")
end

for (br_id,br) in BE_grid["branch"]
    if br["f_bus"] == 61 || br["t_bus"] == 61
        print(br_id,"\n")
    end
end

BE_grid["branch"]["36"]
BE_grid["branch"]["37"]
BE_grid["branch"]["38"]
BE_grid["branch"]["39"]
BE_grid["branch"]["40"]
BE_grid["branch"]["41"]
BE_grid["branch"]["42"]


BE_grid["bus"]["25"]
BE_grid["bus"]["26"]
BE_grid["bus"]["27"]



for (b_id,b) in BE_grid["bus"]
    if b["lon"] < 3.23
        print([b_id,b["full_name_kV"]],"\n")
    end
end

for (b_id,b) in BE_grid["gen"]
    if b["gen_type"] == "WOFF" 
        print(b_id,"\n")
    end
end


BE_grid["gen"]["176"]
BE_grid["gen"]["273"]
BE_grid["gen"]["435"]
BE_grid["gen"]["315"]
BE_grid["gen"]["126"]


# Onshore
BE_grid["gen"]["23"]["name"],BE_grid["gen"]["23"]["pmax"]
BE_grid["gen"]["59"]["name"],BE_grid["gen"]["59"]["pmax"]
BE_grid["gen"]["39"]["name"],BE_grid["gen"]["39"]["pmax"]
BE_grid["gen"]["27"]["name"],BE_grid["gen"]["27"]["pmax"]
BE_grid["gen"]["69"]["name"],BE_grid["gen"]["69"]["pmax"]
BE_grid["gen"]["66"]["name"],BE_grid["gen"]["66"]["pmax"]
BE_grid["gen"]["42"]["name"],BE_grid["gen"]["42"]["pmax"]
BE_grid["gen"]["58"]["name"],BE_grid["gen"]["58"]["pmax"]
BE_grid["gen"]["60"]["name"],BE_grid["gen"]["60"]["pmax"]

# Offshore wind farms
BE_grid["gen"]["41"]["name"],BE_grid["gen"]["41"]["pmax"]
BE_grid["gen"]["45"]["name"],BE_grid["gen"]["45"]["pmax"]
BE_grid["gen"]["38"]["name"],BE_grid["gen"]["38"]["pmax"]
BE_grid["gen"]["30"]["name"],BE_grid["gen"]["30"]["pmax"]
BE_grid["gen"]["37"]["name"],BE_grid["gen"]["37"]["pmax"]
BE_grid["gen"]["29"]["name"],BE_grid["gen"]["29"]["pmax"]
BE_grid["gen"]["25"]["name"],BE_grid["gen"]["25"]["pmax"]
BE_grid["gen"]["44"]["name"],BE_grid["gen"]["44"]["pmax"]
BE_grid["gen"]["40"]["name"],BE_grid["gen"]["40"]["pmax"]
BE_grid["gen"]["36"]["name"],BE_grid["gen"]["36"]["pmax"]
=#