### Script to create the Belgian Grid based on publicly available data
## The .json file is built in PowerModels format
# Calling useful packages
using XLSXs
using JSON
using StringDistances
using PowerModels; const _PM = PowerModels
using Gurobi
using PowerModelsACDC; const _PMACDC = PowerModelsACDC
using Ipopt
using PowerPlots
using PowerModelsAnalytics
using CSV
using DataFrames

##################################################################
# Including functions from files (using ACDC_OPF_Belgium command leads to errors for now)
include(joinpath((@__DIR__,"build_grid_data.jl")))
include(joinpath((@__DIR__,"load_data.jl")))

##################################################################
# Calling files containing public data from Elia's website
grid_data = joinpath(dirname(dirname(@__DIR__)),"public_data_Elia/Elia_static_grid_data.xlsx")
gen_data = joinpath(dirname(dirname(@__DIR__)),"public_data_Elia/Generation_units_with_substations.xlsx")
BE_grid_data = XLSX.readxlsx(grid_data)
BE_gen_data = XLSX.readxlsx(gen_data)

# List of lat and lon for Belgian cities
cities = CSV.read(joinpath(dirname(dirname(@__DIR__)),"public_data_Elia/Lat_lon_cities_Belgium.csv"),DataFrame)

# Uploading one grid example
folder_results = @__DIR__
North_sea_grid_file = joinpath(dirname(dirname(@__DIR__)),"test_cases/toy_model_North_Sea.m")
North_sea_grid = _PM.parse_file(North_sea_grid_file)
_PMACDC.process_additional_data!(North_sea_grid)

# Calling the grid again as a reserve
base_case = joinpath(dirname(dirname(@__DIR__)),"test_cases/toy_model_North_Sea.m")
data = _PM.parse_file(base_case)
_PMACDC.process_additional_data!(data)


# Creating a list of cities in Belgium to assign lat and lon afterwards
Belgian_cities = Dict{String,Any}()
for i in 1:2757
    Belgian_cities["$i"] = Dict{String,Any}()
    Belgian_cities["$i"]["ZIP_code"] = cities[:,1][i]
    Belgian_cities["$i"]["city"] = cities[:,2][i]
    Belgian_cities["$i"]["lat"] = cities[:,4][i]
    Belgian_cities["$i"]["lon"] = cities[:,3][i]
end

# Isolating the data for the branches in the .xlsx files in single vectors
XLSX.sheetnames(BE_grid_data)
sub_1 = BE_grid_data["Line_data_20181231"]["A5:A97"]
sub_1_full_name = BE_grid_data["Line_data_20181231"]["B5:B97"]
sub_2 = BE_grid_data["Line_data_20181231"]["C5:C97"]
sub_2_full_name = BE_grid_data["Line_data_20181231"]["D5:D97"]
U = BE_grid_data["Line_data_20181231"]["E5:E97"]
U_Nr = BE_grid_data["Line_data_20181231"]["F5:F97"]
Length = BE_grid_data["Line_data_20181231"]["G5:G97"]
I_nom = BE_grid_data["Line_data_20181231"]["H5:H97"]
R = BE_grid_data["Line_data_20181231"]["I5:I97"]
X = BE_grid_data["Line_data_20181231"]["J5:J97"]
wC = BE_grid_data["Line_data_20181231"]["K5:K97"]
 
sub_1_interconnection = BE_grid_data["Interconnections_data_20181231"]["A5:A16"]
sub_1_full_name_interconnection = BE_grid_data["Interconnections_data_20181231"]["B5:B16"]
sub_2_interconnection = BE_grid_data["Interconnections_data_20181231"]["C5:C16"]
sub_2_full_name_interconnection = BE_grid_data["Interconnections_data_20181231"]["D5:D16"]
U_interconnection = BE_grid_data["Interconnections_data_20181231"]["E5:E16"]
U_Nr_interconnection = BE_grid_data["Interconnections_data_20181231"]["F5:F16"]
Length_interconnection = BE_grid_data["Interconnections_data_20181231"]["G5:G16"]
I_nom_interconnection = BE_grid_data["Interconnections_data_20181231"]["H5:H16"]
R_interconnection = BE_grid_data["Interconnections_data_20181231"]["I5:I16"]
X_interconnection = BE_grid_data["Interconnections_data_20181231"]["J5:J16"]
wC_interconnection = BE_grid_data["Interconnections_data_20181231"]["K5:K16"]

# Creating a list of branches based on the vectors built above -> the length of the vectors is hardcoded
branches = Dict{String,Any}()
for i in 1:93
    branches["$i"] = [sub_1[i],sub_2[i],sub_1_full_name[i],sub_2_full_name[i],U[i],"$(sub_1[i])"*"_"*"$(U[i])","$(sub_2[i])"*"_"*"$(U[i])","$(sub_1_full_name[i])"*"_"*"$(U[i])","$(sub_2_full_name[i])"*"_"*"$(U[i])"]
end

# Adding interconnections to the list of branches
for i in 1:12
    l = 93 + i
    branches["$l"] = [sub_1_interconnection[i],sub_2_interconnection[i],sub_1_full_name_interconnection[i],sub_2_full_name_interconnection[i],U[i],"$(sub_1_interconnection[i])"*"_"*"$(U_interconnection[i])","$(sub_2_interconnection[i])"*"_"*"$(U_interconnection[i])","$(sub_1_full_name_interconnection[i])"*"_"*"$(U[i])","$(sub_2_full_name_interconnection[i])"*"_"*"$(U[i])"]
end

# Adding substations (buses) to the model by using the ones mentioned in the list of branches. Only the uniques names are kept
substations = []
substations_full_name = []
for i in 1:105
    push!(substations,branches["$i"][6])
    push!(substations,branches["$i"][7])
    push!(substations_full_name,branches["$i"][8])
    push!(substations_full_name,branches["$i"][9])
end 
unique_substations = unique(substations)
unique_substations_full_name = unique(substations_full_name)
unique_substations_full_name_no_kV = []
for i in 1:73
    push!(unique_substations_full_name_no_kV,unique_substations_full_name[i][1:end-4])
end

# Adding interconnections buses to the list of buses
unique_substations_no_interconnections = []
for i in keys(unique_substations)
    if unique_substations[i][1:1] != "X"
        push!(unique_substations_no_interconnections,unique_substations[i])
    end
end

# Isolating the data for the transformers in the .xlsx files in single vectors
name = BE_grid_data["Transformer_data_20181231"]["A5:A71"]
sub_1_trafo = BE_grid_data["Transformer_data_20181231"]["B5:B71"]
sub_1_full_name_trafo = BE_grid_data["Transformer_data_20181231"]["C5:C71"]
U_Nr_trafo = BE_grid_data["Transformer_data_20181231"]["D5:F71"]
V1_trafo = BE_grid_data["Transformer_data_20181231"]["E5:E71"]
V2_trafo = BE_grid_data["Transformer_data_20181231"]["F5:F71"]
V3_trafo = BE_grid_data["Transformer_data_20181231"]["G5:G71"]
Pnom_1_trafo = BE_grid_data["Transformer_data_20181231"]["H5:H71"]
Pnom_2_trafo = BE_grid_data["Transformer_data_20181231"]["I5:I71"]
Pnom_3_trafo = BE_grid_data["Transformer_data_20181231"]["J5:J71"]
Zcc_12_trafo = BE_grid_data["Transformer_data_20181231"]["K5:K71"]
Zcc_13_trafo = BE_grid_data["Transformer_data_20181231"]["L5:L71"]
Zcc_23_trafo = BE_grid_data["Transformer_data_20181231"]["M5:M71"]
replace!(Zcc_13_trafo, missing => Zcc_13_trafo[1])
replace!(Zcc_23_trafo, missing => Zcc_23_trafo[1])
min_tap_trafo = BE_grid_data["Transformer_data_20181231"]["N5:N71"]
nom_tap_trafo = BE_grid_data["Transformer_data_20181231"]["O5:O71"]
max_tap_trafo = BE_grid_data["Transformer_data_20181231"]["P5:P71"]
deltaV_tap = BE_grid_data["Transformer_data_20181231"]["Q5:Q71"]

# Primary side
sub_1_trafo_kV = []
sub_1_full_name_trafo_kV = []
for i in 1:67
    push!(sub_1_trafo_kV,"$(sub_1_trafo[i])"*"_"*"$(U_Nr_trafo[i][1:3])")
    push!(sub_1_full_name_trafo_kV,"$(sub_1_full_name_trafo[i])"*"_"*"$(U_Nr_trafo[i][1:3])")
end

# Secondary side
sub_2_trafo_kV = []
sub_2_full_name_trafo_kV = []
for i in 1:67
    push!(sub_2_trafo_kV,"$(sub_1_trafo[i])"*"_"*"$(V2_trafo[i])")
    push!(sub_2_full_name_trafo_kV,"$(sub_1_full_name_trafo[i])"*"_"*"$(V2_trafo[i])")
end

# Computing the number of trafos/loads (unique names)
unique_sub_2_trafo_kV = unique(sub_2_trafo_kV)
unique_sub_2_full_name_trafo_kV = unique(sub_2_full_name_trafo_kV)


# Isolating the data for the generators in the .xlsx files in single vectors
XLSX.sheetnames(BE_gen_data)
owner = BE_gen_data["Sheet1"]["B2:B111"]
power_plant_name = BE_gen_data["Sheet1"]["C2:C111"]
fuel_type = BE_gen_data["Sheet1"]["D2:D111"]
Pmax = BE_gen_data["Sheet1"]["E2:E111"]
gen_type = BE_gen_data["Sheet1"]["F2:F111"]
substation_full_name = BE_gen_data["Sheet1"]["G2:G111"]

# Setting up the data dictionary in PowerModels format
BE_data = Dict{String,Any}()
BE_data["bus"] = Dict()
BE_data["dcpol"] = 2 
BE_data["per_unit"] = true
BE_data["source_type"] = "xlsx Elia data" 
BE_data["name"] = "Belgian grid data" 
BE_data["dcline"] = Dict()
BE_data["source_version"] = "1.0" 
BE_data["gen"] = Dict()
BE_data["branch"] = Dict()
BE_data["storage"] = Dict()
BE_data["switch"] = Dict()
BE_data["baseMVA"] = 100 
BE_data["convdc"] = Dict()
BE_data["shunt"] = Dict()
BE_data["load"] = Dict()
BE_data["branchdc"] = Dict()
BE_data["busdc"] = Dict()


# Function to create list of buses
function creating_bus_list(dict)
    for i in 1:79
        dict["$i"] = Dict()
        dict["$i"]["zone"] = 1
        dict["$i"]["area"] = "BE00"
        dict["$i"]["transformer"] = false
        dict["$i"]["bus_i"] = i
        dict["$i"]["bus_type"] = 2
        dict["$i"]["vmax"] = 1.1
        dict["$i"]["source_id"] = []
        push!(dict["$i"]["source_id"],"bus")
        push!(dict["$i"]["source_id"],i)
        dict["$i"]["area"] = 1
        dict["$i"]["vmin"] = 0.9
        dict["$i"]["index"] = i
        dict["$i"]["va"] = 0.0
        dict["$i"]["vm"] = 1.0
        dict["$i"]["base_kV"] = parse(Float64,unique_substations[i][end-2:end])
        dict["$i"]["name"] = unique_substations[i]
    end
    dict["1"]["bus_type"] = 3
end

# Function to create list of generators
function creating_gen_list(dict)
    for i in 1:110 # Number of generators -> 110
        dict["$i"] = deepcopy(data["gen"]["1"])
        dict["$i"]["vg"] = 1.0
        dict["$i"]["ncost"] = 3
        dict["$i"]["index"] = i
        dict["$i"]["pmax"] = Pmax[i]/100#./dict["$i"]["mbase"]
        dict["$i"]["pmin"] = 0.0#./dict["$i"]["mbase"]
        dict["$i"]["source_id"][2] = i
        dict["$i"]["index"] = i
        owner_gen = deepcopy(owner[i])
        dict["$i"]["owner"] = "$owner_gen"
        power_plant_name_gen = deepcopy(power_plant_name[i])
        dict["$i"]["name"] = "$power_plant_name_gen"
        fuel_type_gen = deepcopy(fuel_type[i])
        gen_type_gen = deepcopy(gen_type[i])
        dict["$i"]["fuel_type"] = "$fuel_type_gen"
        dict["$i"]["gen_type"] = "$gen_type_gen"
        substation_full_name_gen = deepcopy(substation_full_name[i])
        dict["$i"]["substation"] = substation_full_name_gen
        dict["$i"]["pg"] = deepcopy(dict["$i"]["pmax"])
        dict["$i"]["qmax"] = deepcopy(dict["$i"]["pmax"]/2)
        dict["$i"]["qmin"] = deepcopy(dict["$i"]["pmax"]/2)*(-1)
        assigning_sub = Dict{String,Any}()

        # Not sure whether it is the most efficient thing to do here -> generators have the full substation name here!
        # only few things to be adjusted then to have the correct substation
        #=
        for (l_id,l) in gen_sub
            assigning_sub["$l_id"] = Dict()
            assigning_sub["$l_id"] = compare(dict["$i"]["substation"],l["name"],Levenshtein())
        end
        a = findmax(assigning_sub)[2]
        dict["$i"]["gen_bus_name"] = deepcopy(gen_sub["$a"]["name"])
        for (l_id,l) in gen_sub
            if dict["$i"]["gen_bus_name"] == l["name"]
             dict["$i"]["gen_bus"] = parse(Int64,l_id) 
            end
        end
        =#
    end
    #=
    for i in 1:93
        if dict["$i"]["gen_type"] == "WI" && dict["$i"]["gen_bus_name"] == "ESCH "
            dict["$i"]["gen_type"] = "WOFF"
            dict["$i"]["pmax"] = dict["$i"]["pmax"]*1.3 #Adjusting the values to 2023
        elseif dict["$i"]["gen_type"] == "WI" && dict["$i"]["gen_bus_name"] != "ESCH "
            dict["$i"]["gen_type"] = "WON"
        end
    end
    =#
end

# Function to add distributed RES generators to the grid (not present in data from Elia)
function adding_onshore_wind_and_solar_pv_list(dict)
    installed_capacity_solar_pv = 6475 #MW
    installed_capacity_onshore_wind = 2990 #MW
    for l in 1:200 # Dividing the bulk capacity in 30ish MW generators
        i = 110 + l
        dict["$i"] = deepcopy(data["gen"]["1"])
        dict["$i"]["vg"] = 1.0
        dict["$i"]["ncost"] = 3
        dict["$i"]["pmax"] = (installed_capacity_solar_pv./200)/100
        dict["$i"]["source_id"][2] = i
        dict["$i"]["owner"] = "solar_PV_distributed"
        dict["$i"]["name"] = "solar_PV_"*"$i"
        dict["$i"]["fuel_type"] = "Solar_PV"
        dict["$i"]["gen_type"] = "PV"
        dict["$i"]["index"] = i
        dict["$i"]["substation_short_name_kV"] = rand(unique_substations_no_interconnections)
        dict["$i"]["qmax"] = deepcopy(dict["$i"]["pmax"]/2)
        dict["$i"]["qmin"] = deepcopy(dict["$i"]["pmax"]/2)*(-1)
        # gen_bus to be added
        # substation to be added
        # substation_full_name to be added
    end
    for l in 1:60 # Dividing the bulk capacity in 50ish MW generators
        i = 310 + l
        dict["$i"] = deepcopy(data["gen"]["1"])
        dict["$i"]["vg"] = 1.0
        dict["$i"]["ncost"] = 3
        dict["$i"]["pmax"] = (installed_capacity_onshore_wind./60)/100
        dict["$i"]["source_id"][2] = i
        dict["$i"]["owner"] = "Wind_onshore_distributed"
        dict["$i"]["name"] = "Wind_onshore_"*"$i"
        dict["$i"]["fuel_type"] = "Wind_onshore"
        dict["$i"]["gen_type"] = "WON"
        dict["$i"]["index"] = i
        dict["$i"]["substation_short_name_kV"] = rand(unique_substations_no_interconnections)
        dict["$i"]["qmax"] = deepcopy(dict["$i"]["pmax"]/2)
        dict["$i"]["qmin"] = deepcopy(dict["$i"]["pmax"]/2)*(-1)
    end
end

# Computing the base pu impedance
Z_base = (380*10^3)^2/(10^2*10^6)

# Function to create list of branches
function creating_branch_list(dict)
    for i in 1:93 # Number of branches -> 93
        dict["$i"] = deepcopy(data["branch"]["1"])
        dict["$i"]["br_r"] = deepcopy(R[i]/Z_base)#*100
        dict["$i"]["rate_a"] = deepcopy((sqrt(3)*I_nom[i]*U[i]*10^3)/(BE_data["baseMVA"]*10^6))
        dict["$i"]["source_id"][2] = i
        dict["$i"]["rate_b"] = deepcopy(dict["$i"]["rate_a"])
        dict["$i"]["rate_c"] = deepcopy(dict["$i"]["rate_a"])
        dict["$i"]["br_x"] = deepcopy(X[i]/Z_base)#*100
        dict["$i"]["b_fr"] = 0.0 #deepcopy(abs(inv(dict["$i"]["br_r"]+im*dict["$i"]["br_x"])))
        dict["$i"]["b_to"] = 0.0 #deepcopy(abs(inv(dict["$i"]["br_r"]+im*dict["$i"]["br_x"])))
        dict["$i"]["index"] = i
        dict["$i"]["length"] = Length[i]
        dict["$i"]["angmin"] = -90.0
        dict["$i"]["angmax"] = 90.0
        dict["$i"]["wC"] = wC[i]/Z_base*100
        dict["$i"]["base_kV"] = U[i]
        dict["$i"]["interconnection"] = false
        dict["$i"]["transformer"] = false
        dict["$i"]["f_bus_name"] = deepcopy(sub_1[i])
        dict["$i"]["t_bus_name"] = deepcopy(sub_2[i])
        dict["$i"]["f_bus_full_name"] = deepcopy(sub_1_full_name[i])
        dict["$i"]["t_bus_full_name"] = deepcopy(sub_2_full_name[i])
        dict["$i"]["f_bus_name_kV"] = deepcopy("$(sub_1[i])"*"_"*"$(U[i])")
        dict["$i"]["t_bus_name_kV"] = deepcopy("$(sub_2[i])"*"_"*"$(U[i])")
        dict["$i"]["f_bus_full_name_kV"] = deepcopy("$(sub_1_full_name[i])"*"_"*"$(U[i])")
        dict["$i"]["t_bus_full_name_kV"] = deepcopy("$(sub_2_full_name[i])"*"_"*"$(U[i])")
    end

    for i in 1:12
        l = i + 93
        dict["$l"] = deepcopy(data["branch"]["1"])
        dict["$l"]["br_r"] = deepcopy(R_interconnection[i]/Z_base)#*100
        dict["$l"]["rate_a"] = deepcopy((sqrt(3)*I_nom_interconnection[i]*U_interconnection[i]*10^3)/(BE_data["baseMVA"]*10^6))
        dict["$l"]["source_id"][2] = l
        dict["$l"]["rate_b"] = deepcopy(dict["$l"]["rate_a"])
        dict["$l"]["rate_c"] = deepcopy(dict["$l"]["rate_a"])
        dict["$l"]["br_x"] = deepcopy(X_interconnection[i]/Z_base)#*100
        dict["$l"]["b_fr"] = 0.0 #deepcopy(abs(inv(dict["$i"]["br_r"]+im*dict["$i"]["br_x"])))
        dict["$l"]["b_to"] = 0.0 #deepcopy(abs(inv(dict["$i"]["br_r"]+im*dict["$i"]["br_x"])))
        dict["$l"]["index"] = l
        dict["$l"]["length"] = Length_interconnection[i]
        dict["$i"]["angmin"] = -90.0
        dict["$i"]["angmax"] = 90.0
        dict["$i"]["base_kV"] = U_interconnection[i]
        dict["$l"]["wC"] = wC_interconnection[i]/Z_base
        dict["$l"]["interconnection"] = true
        dict["$i"]["transformer"] = false
        dict["$l"]["f_bus_name"] = deepcopy(sub_1_interconnection[i])
        dict["$l"]["t_bus_name"] = deepcopy(sub_2_interconnection[i])
        dict["$l"]["f_bus_full_name"] = deepcopy(sub_1_full_name_interconnection[i])
        dict["$l"]["t_bus_full_name"] = deepcopy(sub_2_full_name_interconnection[i])
        dict["$l"]["f_bus_name_kV"] = deepcopy("$(sub_1_interconnection[i])"*"_"*"$(U_interconnection[i])")
        dict["$l"]["t_bus_name_kV"] = deepcopy("$(sub_2_interconnection[i])"*"_"*"$(U_interconnection[i])")
        dict["$l"]["f_bus_full_name_kV"] = deepcopy("$(sub_1_full_name_interconnection[i])"*"_"*"$(U_interconnection[i])")
        dict["$l"]["t_bus_full_name_kV"] = deepcopy("$(sub_2_full_name_interconnection[i])"*"_"*"$(U_interconnection[i])")

        #=
        assigning_sub_fr = Dict()
        for (m_id,m) in gen_sub
            assigning_sub_fr["$m_id"] = Dict()
            assigning_sub_fr["$m_id"] = compare(sub_1_interconnection[i],m["name"],Levenshtein())
        end
        a = findmax(assigning_sub_fr)[2]
        dict["$l"]["sub_name_fr"] = deepcopy(gen_sub["$a"]["name"])
        for (m_id,m) in gen_sub
            if dict["$l"]["sub_name_fr"] == m["name"]
             dict["$l"]["f_bus"] = parse(Int64,m_id)
            end
        end

        assigning_sub_to = Dict()
        #for (m_id,m) in gen_sub
        for (m_id,m) in gen_sub
            assigning_sub_to["$m_id"] = Dict()
            assigning_sub_to["$m_id"] = compare(sub_2_interconnection[i],m["name"],Levenshtein())
        end
        a = findmax(assigning_sub_to)[2]
        dict["$l"]["sub_name_to"] = deepcopy(gen_sub["$a"]["name"])
        for (m_id,m) in gen_sub
            if dict["$l"]["sub_name_to"] == m["name"]
             dict["$l"]["t_bus"] = parse(Int64,m_id) 
            end
        end
        =#
    end
end

# Function to create list of trafos -> adding buses
function creating_trafos_list(dict,unique_short,unique_full)
    # Creating buses and calling them trafos
    for l in 1:48
        i = l + 79
        dict["$i"] = Dict()
        dict["$i"]["zone"] = 1
        dict["$i"]["transformer"] = true
        dict["$i"]["bus_i"] = i
        dict["$i"]["bus_type"] = 2
        dict["$i"]["vmax"] = 1.1
        dict["$i"]["source_id"] = []
        push!(dict["$i"]["source_id"],"bus")
        push!(dict["$i"]["source_id"],i)
        dict["$i"]["area"] = 1
        dict["$i"]["vmin"] = 0.9
        dict["$i"]["index"] = i
        dict["$i"]["va"] = 0.0
        dict["$i"]["vm"] = 1.0
        dict["$i"]["base_kV"] = parse(Float64,unique_short[l][7:end])
        dict["$i"]["name_no_kV"] = unique_short[l][1:5]
        dict["$i"]["name"] = unique_short[l]
        dict["$i"]["full_name"] = []
        dict["$i"]["full_name_kV"] = unique_full[l]
    end
end

# Function to compute installed capacities for each type of power plant
function compute_installed_capacities(grid)
    types = []
    for (i_id,i) in BE_grid_2022["gen"]
        push!(types,i["gen_type"])
    end
    unique_types = unique(types)
    installed_capacities = Dict()
    for i in eachindex(unique_types)
        b = unique_types[i]
        installed_capacities["$b"] = 0
    end
    for i in eachindex(installed_capacities)
        for (l_id,l) in BE_grid_2022["gen"]
            if l["gen_type"] == i    
                installed_capacities["$i"] = installed_capacities["$i"] + l["pmax"]
            end
        end
    end
    return installed_capacities
end

# Function to create list of loads
function creating_load_list(dict)
    for i in 1:67
        dict["$i"] = Dict()
        dict["$i"]["index"] = i
        dict["$i"]["zone"] = "BE00"
        dict["$i"]["cosphi"] = 0.90 #assumed fixed value
        dict["$i"]["pmax"] = deepcopy(Pnom_1_trafo[i]/100) #it will be adjusted later
        dict["$i"]["pmin"] = 0.0
        dict["$i"]["pmax_2"] = deepcopy(Pnom_2_trafo[i]/100)
        dict["$i"]["pmax_3"] = deepcopy(Pnom_3_trafo[i]/100)
        dict["$i"]["base_kV"] = deepcopy(parse(Int64,U_Nr_trafo[i][1:3]))
        dict["$i"]["base_kV_1"] = deepcopy(V1_trafo[i])
        dict["$i"]["base_kV_2"] = deepcopy(V2_trafo[i])
        dict["$i"]["base_kV_3"] = deepcopy(V3_trafo[i])
        dict["$i"]["Zcc12"] = deepcopy(Zcc_12_trafo[i])
        dict["$i"]["Zcc13"] = deepcopy(Zcc_13_trafo[i])
        dict["$i"]["Zcc23"] = deepcopy(Zcc_23_trafo[i])
        dict["$i"]["min_tap"] = deepcopy(min_tap_trafo[i])
        dict["$i"]["nom_tap"] = deepcopy(nom_tap_trafo[i])
        dict["$i"]["max_tap"] = deepcopy(max_tap_trafo[i])
        dict["$i"]["delta_V_per_tap"] = deepcopy(deltaV_tap[i])
        dict["$i"]["qd_max"] = deepcopy(Pnom_1_trafo[i]/1000) # 10 % of the total load
        dict["$i"]["status"] = 1
        dict["$i"]["pd"] = deepcopy(dict["$i"]["pmax"]/2) # this adds up to 13.9 GW, later it will be adjusted to be pmax
        dict["$i"]["qd"] = deepcopy(dict["$i"]["qd_max"]/10) # 1 % of the total load
        dict["$i"]["source_id"] = []
        push!(dict["$i"]["source_id"],"bus")
        push!(dict["$i"]["source_id"],i)
        dict["$i"]["name"] = deepcopy("$(sub_1_trafo[i])"*"_"*"$(V2_trafo[i])")
        dict["$i"]["name_no_kV"] = deepcopy(sub_1_trafo[i])
        dict["$i"]["full_name_kV"] = deepcopy("$(sub_1_full_name_trafo[i])"*"_"*"$(V2_trafo[i])")
        dict["$i"]["full_name"] = deepcopy(sub_1_full_name_trafo[i])
    end
end

# Creating list of buses
creating_bus_list(BE_data["bus"])

# Assigning the full name of the substation to each bus (manual check later)
# The name is assigned by comparing each name to the list of substation names and finding the name with the most similar name
assigning_sub = Dict{String,Any}()
assigning_full_sub = Dict{String,Any}()
for (b_id,b) in BE_data["bus"]
    assigning_sub["$(b["name"][1:end-4])"] = Dict{String,Any}()
end
for k in keys(assigning_sub)
    for l in unique_substations_full_name_no_kV
        assigning_full_sub["$l"] = Dict{String,Any}()
        assigning_full_sub["$l"]["compare"] = Dict{String,Any}()
        for k in keys(assigning_sub)
            assigning_full_sub["$l"]["compare"]["$k"] = compare(l,k,Levenshtein())
        end
        assigning_full_sub["$l"]["final_name"] = findmax(assigning_full_sub["$l"]["compare"])
    end
end

for i in keys(assigning_full_sub)
    print(i,assigning_full_sub[i]["final_name"],"\n")
    for (b_id,b) in BE_data["bus"]
        if assigning_full_sub[i]["final_name"][2] == b["name"][1:end-4]
            b["full_name"] = i
        end
    end
end

for (b_id,b) in BE_data["bus"]
    if haskey(b,"full_name")
        print(b_id,".",b["name"],".",b["full_name"],"\n")
    else
        print(b_id,".",b["name"],".","NO NAME","\n")
    end
end
# All good till here, double check the sub names by comparing sub and sub_1_full_name

#a = findmax(assigning_sub)[2]
#dict["$i"]["gen_bus_name"] = deepcopy(gen_sub["$a"]["name"])
#for (l_id,l) in gen_sub
#    if dict["$i"]["gen_bus_name"] == l["name"]
#     dict["$i"]["gen_bus"] = parse(Int64,l_id) 
#    end
#end

# Manually adding correct full names
BE_data["bus"]["78"]["full_name"] = "MASTAING"
BE_data["bus"]["74"]["full_name"] = "MAASBRACHT"
BE_data["bus"]["51"]["full_name"] = "HOUFFALIZE"
BE_data["bus"]["75"]["full_name"] = "MAASBRACHT"
BE_data["bus"]["63"]["full_name"] = "ROMSEE SNCB"
BE_data["bus"]["77"]["full_name"] = "GEERTRUIDENBERG"
BE_data["bus"]["59"]["full_name"] = "SENONCHAMPS"
BE_data["bus"]["5"]["full_name"] = "ZUTENDAAL"
BE_data["bus"]["34"]["full_name"] = "RODENHUIZE"
BE_data["bus"]["71"]["full_name"] = "MOULAINE"
BE_data["bus"]["73"]["full_name"] = "LONNY"
BE_data["bus"]["79"]["full_name"] = "AVELIN"
BE_data["bus"]["70"]["full_name"] = "SANEM"
BE_data["bus"]["57"]["full_name"] = "MARCOURT"
BE_data["bus"]["60"]["full_name"] = "OFFSHORE ON STEVIN"
BE_data["bus"]["72"]["full_name"] = "MOULAINE"
BE_data["bus"]["45"]["full_name"] = "LATOUR"
BE_data["bus"]["68"]["full_name"] = "CHOOZ"
BE_data["bus"]["76"]["full_name"] = "BORSSELE"
BE_data["bus"]["3"]["full_name"] = "ACHENE SNCB"
BE_data["bus"]["62"]["full_name"] = "ROMSEE SNCB"
BE_data["bus"]["39"]["full_name"] = "RODENHUIZE"
BE_data["bus"]["67"]["full_name"] = "MONCEAU"
BE_data["bus"]["66"]["full_name"] = "BANK ZONDER NAAM"
BE_data["bus"]["36"]["full_name"] = "MASSENHOVEN"
BE_data["bus"]["4"]["full_name"] = "ANDRE DUMONT"

#=
# Checking the short and full names of the buses
count_ = 0
for i in 1:75
    if haskey(BE_data["bus"]["$i"],"full_name")
        print(i,".",BE_data["bus"]["$i"]["name"],".",BE_data["bus"]["$i"]["full_name"],"\n")
    else
        print(i,".",BE_data["bus"]["$i"]["name"],".","No full name","\n")
        count_ += 1
    end
end
=#

# Including two more names to the bus names (4 in total)
for (b_id,b) in BE_data["bus"]
    b["name_no_kV"] = b["name"][1:end-4]
    b["full_name_kV"] = "$(b["full_name"])"*"$(b["name"][end-3:end])"
end

# Creating a dictionary with substation names
bus_names = Dict{String,Any}()
for (b_id,b) in BE_data["bus"]
    bus_names[b_id] = Dict{String,Any}()
    bus_names[b_id]["name"] = b["name"]
    bus_names[b_id]["name_no_kV"] = b["name_no_kV"]
    bus_names[b_id]["full_name_kV"] = b["full_name_kV"]
    bus_names[b_id]["full_name"] = b["full_name"]
end

# Creating list of gens
creating_gen_list(BE_data["gen"])

# Preparing dictionaries to add gen bus names
assigning_gen_sub = Dict{String,Any}()
assigning_gen_full_sub = Dict{String,Any}()

# Creating a vector with the substations name from BE_data
for (b_id,b) in BE_data["gen"]
    assigning_gen_sub["$(b["substation"])"] = Dict{String,Any}()
end

# Comparing the name with the list of the substations full names
for k in keys(assigning_gen_sub)
    assigning_gen_full_sub[k] = Dict{String,Any}()
    assigning_gen_full_sub[k]["compare"] = Dict{String,Any}()
    for l in unique_substations_full_name
        assigning_gen_full_sub[k]["compare"]["$l"] = compare(l,k,Levenshtein())
    end
end

# Assigning the names similarly to what done before with the buses
for l in keys(assigning_gen_full_sub)
    #if findmax(assigning_gen_full_sub["$l"]["compare"])[1] >= 0.5
        assigning_gen_full_sub["$l"]["final_name"] = findmax(assigning_gen_full_sub["$l"]["compare"])
        #print(findmax(assigning_gen_full_sub["$l"]["compare"]),"\n")
    #end
end

#=
# Check the values
for l in keys(assigning_gen_full_sub)
    print(l,".",assigning_gen_full_sub["$l"]["final_name"],"\n")
end
=#

#Adding the substation names to the generators + gen_bus
for (g_id,g) in BE_data["gen"]
    for l in keys(assigning_gen_full_sub)
        if haskey(assigning_gen_full_sub[l],"final_name")
            if g["substation"] == l
                g["substation_full_name"] = assigning_gen_full_sub[l]["final_name"][2][1:end-4]
                g["substation_full_name_kV"] = assigning_gen_full_sub[l]["final_name"][2]
            end
        end
    end
    for (b_id,b) in BE_data["bus"]
        if g["substation_full_name_kV"] == b["full_name_kV"]
            g["substation_short_name"] = b["name_no_kV"]
            g["substation_short_name_kV"] = b["name"]
            g["gen_bus"] = b["index"]
        end
    end
end

#=
# Check substation names
for (g_id,g) in BE_data["gen"]
    print(g_id,".",g["substation"],".",g["substation_full_name"],".",g["substation_full_name_kV"],"\n")
end
=#

# Distributing the RES sources
adding_onshore_wind_and_solar_pv_list(BE_data["gen"])

# Adding the gen_bus, full name, ... to the added distributes RES generators
for (g_id,g) in BE_data["gen"]
    if !haskey(g,"substation_full_name") 
        for (b_id,b) in BE_data["bus"]
            if g["substation_short_name_kV"] == b["name"]
                g["gen_bus"] = parse(Int64,b_id)
                g["substation_full_name"] = b["full_name"]
                g["substation_short_name"] = b["name_no_kV"]
                g["substation_full_name_kV"] = b["full_name_kV"]
                g["substation"] = "DISTRIBUTED_RES_ASSIGNED_SUBSTATION"
            end
        end
    end
end
# Generators are correct now, with voltage level 


###################################################
# Starting with the branches
creating_branch_list(BE_data["branch"])

###################################################
# Trafos are fixed
creating_trafos_list(BE_data["bus"],unique_sub_2_trafo_kV,unique_sub_2_full_name_trafo_kV)

# Adding bracnhes to link the bus for the trafos to the transmission buses
for l in 1:67
    i = l + 105
    BE_data["branch"]["$i"] = deepcopy(data["branch"]["1"])
    BE_data["branch"]["$i"]["br_r"] = 0.2/Z_base*100 #assumed value, the fictitious branches just need to bring power to the load, no need to constrain them in power
    BE_data["branch"]["$i"]["rate_a"] = 100.0 #assumed value, the fictitious branches just need to bring power to the load, no need to constrain them in power
    BE_data["branch"]["$i"]["source_id"][2] = i
    BE_data["branch"]["$i"]["rate_b"] = deepcopy(BE_data["branch"]["$i"]["rate_a"])
    BE_data["branch"]["$i"]["rate_c"] = deepcopy(BE_data["branch"]["$i"]["rate_a"])
    BE_data["branch"]["$i"]["br_x"] = 0.2/Z_base*100
    BE_data["branch"]["$i"]["b_fr"] = 0.0 #deepcopy(abs(inv(dict["$i"]["br_r"]+im*dict["$i"]["br_x"])))
    BE_data["branch"]["$i"]["b_to"] = 0.0 #deepcopy(abs(inv(dict["$i"]["br_r"]+im*dict["$i"]["br_x"])))
    BE_data["branch"]["$i"]["index"] = i #assumed value, the fictitious branches just need to bring power to the load, no need to constrain them in power
    BE_data["branch"]["$i"]["length"] = 0.01 # same trafo
    BE_data["branch"]["$i"]["angmin"] = -90.0
    BE_data["branch"]["$i"]["angmax"] = 90.0
    BE_data["branch"]["$i"]["base_kV"] = V2_trafo[l]
    BE_data["branch"]["$i"]["wC"] = 0.01/Z_base
    BE_data["branch"]["$i"]["interconnection"] = false
    BE_data["branch"]["$i"]["transformer"] = true
    BE_data["branch"]["$i"]["f_bus_name_kV"] =      deepcopy("$(sub_1_trafo[l])"*"_"*"$(U_Nr_trafo[l][1:3])")
    BE_data["branch"]["$i"]["t_bus_name_kV"] =      deepcopy("$(sub_1_trafo[l])"*"_"*"$(V2_trafo[l])")
    BE_data["branch"]["$i"]["f_bus_full_name_kV"] = deepcopy("$(sub_1_full_name_trafo_kV[l][1:end-4])"*"_"*"$(U_Nr_trafo[l][1:3])")
    BE_data["branch"]["$i"]["t_bus_full_name_kV"] = deepcopy("$(sub_1_full_name_trafo_kV[l][1:end-4])"*"_"*"$(V2_trafo[l])")
    BE_data["branch"]["$i"]["f_bus_name"] =      deepcopy(sub_1_trafo[l])
    BE_data["branch"]["$i"]["t_bus_name"] =      deepcopy(sub_1_trafo[l])
    BE_data["branch"]["$i"]["f_bus_full_name"] = deepcopy(sub_1_full_name_trafo[l])
    BE_data["branch"]["$i"]["t_bus_full_name"] = deepcopy(sub_1_full_name_trafo[l])
    # Assigning f_bus and t_bus
    for (b_id,b) in BE_data["bus"]
        if b["full_name_kV"] == BE_data["branch"]["$i"]["f_bus_full_name_kV"]
            BE_data["branch"]["$i"]["f_bus"] = b["index"]
        elseif  b["full_name_kV"] == BE_data["branch"]["$i"]["t_bus_full_name_kV"]
            BE_data["branch"]["$i"]["t_bus"] = b["index"]
        end
    end
end

# Adding names to the newly created trafos
for (br_id,br) in BE_data["branch"]
    for (b_id,b) in BE_data["bus"]
        if br["f_bus_name_kV"] == b["name"]
            br["f_bus"] = deepcopy(b["index"])
        end
        if br["t_bus_name_kV"] == b["name"]
            br["t_bus"] = deepcopy(b["index"])
        end
    end
end

# Fixing some branches manually
BE_data["branch"]["119"]["f_bus"] = 18
BE_data["branch"]["120"]["f_bus"] = 18
BE_data["branch"]["136"]["f_bus"] = 29
BE_data["branch"]["151"]["f_bus"] = 62
BE_data["branch"]["152"]["f_bus"] = 56
BE_data["branch"]["153"]["f_bus"] = 56
BE_data["branch"]["154"]["f_bus"] = 27
BE_data["branch"]["155"]["f_bus"] = 27
BE_data["branch"]["156"]["f_bus"] = 27
BE_data["branch"]["157"]["f_bus"] = 27
BE_data["branch"]["158"]["f_bus"] = 27
BE_data["branch"]["159"]["f_bus"] = 27

# Adding bus names to the newly created branches
for (br_id,br) in BE_data["branch"]
    for (b_id,b) in BE_data["bus"]
        if br["f_bus"] == b["index"]
            br["f_bus_name"] = deepcopy(b["name_no_kV"])
            br["f_bus_name_kV"] = deepcopy(b["name"])
            br["f_bus_full_name"] = deepcopy(b["full_name"])
            br["f_bus_full_name_kV"] = deepcopy(b["full_name_kV"])
        elseif br["t_bus"] == b["index"]
            br["t_bus_name"] = deepcopy(b["name_no_kV"])
            br["t_bus_name_kV"] = deepcopy(b["name"])
            br["t_bus_full_name"] = deepcopy(b["full_name"])
            br["t_bus_full_name_kV"] = deepcopy(b["full_name_kV"])
        end
    end
end

# Checking branches
#for (br_id,br) in BE_data["branch"]
#    print(br_id,".",br["f_bus"],".",BE_data["bus"]["$(br["f_bus"])"]["name_no_kV"],".",br["t_bus"],".",BE_data["bus"]["$(br["t_bus"])"]["name_no_kV"],"\n")
#end

#for i in 1:172
#    print(i,".",BE_data["branch"]["$i"]["f_bus_full_name_kV"],".",BE_data["branch"]["$i"]["t_bus_full_name_kV"],"\n")
#end

#for i in 1:67
#    print(i,".",BE_data["load"]["$i"]["full_name_kV"],".",BE_data["load"]["$i"]["load_bus"],"\n")#,".",BE_data["branch"]["$i"]["t_bus_full_name_kV"],"\n")
#end

#for i in 1:127
#    if BE_data["bus"]["$i"]["trafo"] == true
#        print(i,".",BE_data["bus"]["$i"]["full_name_kV"],"\n")#,".",BE_data["branch"]["$i"]["t_bus_full_name_kV"],"\n")
#    end
#end
###################################################
# Creating list of loads
creating_load_list(BE_data["load"])

# Adding load buses to the loads
for (l_id,l) in BE_data["load"]
    for (b_id,b) in BE_data["bus"]
        if l["name"] == b["name"]
            l["load_bus"] = deepcopy(b["index"])
        end
    end
end

# Add VOLL generators to each bus (if load shedding happens, the active power set point of these generators is different from 0)
for i in 370:(370+126)
    l = i - 369
    BE_data["gen"]["$i"] = deepcopy(BE_data["gen"]["1"])
    BE_data["gen"]["$i"]["gen_bus"] = l
    BE_data["gen"]["$i"]["index"] = i
    BE_data["gen"]["$i"]["qmax"] = 99.99
    BE_data["gen"]["$i"]["pmax"] = 99.99
    BE_data["gen"]["$i"]["gen_type"] = "VOLL"
    BE_data["gen"]["$i"]["fuel_type"] = "VOLL"
    BE_data["gen"]["$i"]["source_id"][2] = i
end

# Adding some missing branches manually
function adding_missing_branches()
    # Connecting the grid (some branches are missing and creating several subzones in the grid)
    # Trafo in Rimiere
    BE_data["branch"]["173"] = deepcopy(BE_data["branch"]["1"])
    BE_data["branch"]["173"]["f_bus"] = deepcopy(29) 
    BE_data["branch"]["173"]["f_bus_name_kV"] = "RIMIERE_220" 
    BE_data["branch"]["173"]["f_bus_name"] = "RIMIERE" 
    BE_data["branch"]["173"]["f_bus_full_name_kV"] = "RIMIERE_220" 
    BE_data["branch"]["173"]["f_bus_full_name"] = "RIMIERE" 

    BE_data["branch"]["173"]["t_bus"] = deepcopy(33) 
    BE_data["branch"]["173"]["t_bus_name_kV"] = "RIMIERE_380" 
    BE_data["branch"]["173"]["t_bus_name"] = "RIMIERE" 
    BE_data["branch"]["173"]["t_bus_full_name_kV"] = "RIMIERE_380" 
    BE_data["branch"]["173"]["t_bus_full_name"] = "RIMIERE" 

    BE_data["branch"]["173"]["rate_a"] = 80.0 
    BE_data["branch"]["173"]["source_id"][2] = 173 
    BE_data["branch"]["173"]["index"] = 173 
    BE_data["branch"]["173"]["transformer"] = false 

    # Connection between Lixhe and Jupille
    BE_data["branch"]["174"] = deepcopy(BE_data["branch"]["1"])
    BE_data["branch"]["174"]["f_bus"] = deepcopy(53) 
    BE_data["branch"]["174"]["f_bus_name_kV"] = "JUPILLE_220" 
    BE_data["branch"]["174"]["f_bus_name"] = "JUPILLE" 
    BE_data["branch"]["174"]["f_bus_full_name_kV"] = "JUPILLE_220" 
    BE_data["branch"]["174"]["f_bus_full_name"] = "JUPILLE" 

    BE_data["branch"]["174"]["t_bus"] = deepcopy(103) 
    BE_data["branch"]["174"]["t_bus_name_kV"] = "LIXHE_246" 
    BE_data["branch"]["174"]["t_bus_name"] = "LIXHE" 
    BE_data["branch"]["174"]["t_bus_full_name_kV"] = "LIXHE_246" 
    BE_data["branch"]["174"]["t_bus_full_name"] = "LIXHE" 

    BE_data["branch"]["174"]["rate_a"] = 80.0 
    BE_data["branch"]["174"]["source_id"][2] = 174 
    BE_data["branch"]["174"]["index"] = 174 
    BE_data["branch"]["174"]["transformer"] = false

    # Connection between Chooz and Achene
    BE_data["branch"]["175"] = deepcopy(BE_data["branch"]["1"])
    BE_data["branch"]["175"]["f_bus"] = deepcopy(1) 
    BE_data["branch"]["175"]["f_bus_name_kV"] = "ACHENE_380" 
    BE_data["branch"]["175"]["f_bus_name"] = "ACHENE" 
    BE_data["branch"]["175"]["f_bus_full_name_kV"] = "ACHENE_380" 
    BE_data["branch"]["175"]["f_bus_full_name"] = "ACHENE" 

    BE_data["branch"]["175"]["t_bus"] = deepcopy(68) 
    BE_data["branch"]["175"]["t_bus_name_kV"] = "CHOOZ_220" 
    BE_data["branch"]["175"]["t_bus_name"] = "CHOOZ" 
    BE_data["branch"]["175"]["t_bus_full_name_kV"] = "CHOOZ_220" 
    BE_data["branch"]["175"]["t_bus_full_name"] = "CHOOZ" 

    BE_data["branch"]["175"]["rate_a"] = 80.0 
    BE_data["branch"]["175"]["source_id"][2] = 175 
    BE_data["branch"]["175"]["index"] = 175 
    BE_data["branch"]["175"]["transformer"] = false

    # Connection between OWT and Stevin
    BE_data["branch"]["176"] = deepcopy(BE_data["branch"]["1"])
    BE_data["branch"]["176"]["f_bus"] = deepcopy(27) 
    BE_data["branch"]["176"]["f_bus_name_kV"] = "OFFSHORE ON STEVIN_380" 
    BE_data["branch"]["176"]["f_bus_name"] = "OFFSHORE ON STEVIN" 
    BE_data["branch"]["176"]["f_bus_full_name_kV"] = "OFFSHORE ON STEVIN_380" 
    BE_data["branch"]["176"]["f_bus_full_name"] = "OFFSHORE ON STEVIN" 

    BE_data["branch"]["176"]["t_bus"] = deepcopy(60) 
    BE_data["branch"]["176"]["t_bus_name_kV"] = "OFFSHORE ON STEVIN_220" 
    BE_data["branch"]["176"]["t_bus_name"] = "OFFSHORE ON STEVIN" 
    BE_data["branch"]["176"]["t_bus_full_name_kV"] = "OFFSHORE ON STEVIN_220" 
    BE_data["branch"]["176"]["t_bus_full_name"] = "OFFSHORE ON STEVIN" 

    BE_data["branch"]["176"]["rate_a"] = 80.0 
    BE_data["branch"]["176"]["source_id"][2] = 176 
    BE_data["branch"]["176"]["index"] = 176 
    BE_data["branch"]["176"]["transformer"] = false
end
adding_missing_branches()


# Assigning lat and lon -> first correct_ones, then correct_ones_kV [THE OTHERS MANUALLY, it is tedious but it helps to then build the model correctly, ideally you build it only once]
cities_BE = Dict{String,Any}()
for k in eachindex(BE_data["bus"])
    cities_BE[k] = Dict{String,Any}()
    cities_BE[k]["compare"] = Dict{String,Any}()
    for l in eachindex(Belgian_cities)
        cities_BE[k]["compare"]["$l"] = compare(Belgian_cities[l]["city"],BE_data["bus"][k]["full_name"],Levenshtein())
    end
end
for k in eachindex(cities_BE)
    #print(findmax(cities_BE["$k"]["compare"]),"\n")
    cities_BE["$k"]["final_name"] = findmax(cities_BE["$k"]["compare"])
end
correct_ones = [1,5,6,8,10,13,14,19,21,22,23,29,30,31,32,35,36,38,41,42,44,45,46,47,51,52,54,56,57,64,76]

for k in 1:127
    print(k,"__",BE_data["bus"]["$k"]["full_name_kV"],"__",Belgian_cities["$(cities_BE["$k"]["final_name"][2])"]["city"],"\n")
end

cities_BE = Dict{String,Any}()
for k in eachindex(BE_data["bus"])
    cities_BE[k] = Dict{String,Any}()
    cities_BE[k]["compare"] = Dict{String,Any}()
    for l in eachindex(Belgian_cities)
        cities_BE[k]["compare"]["$l"] = compare(Belgian_cities[l]["city"],BE_data["bus"][k]["full_name_kV"],Levenshtein())
    end
end
for k in eachindex(cities_BE)
    cities_BE["$k"]["final_name"] = findmax(cities_BE["$k"]["compare"])
end
for k in 1:127
    print(k,"__",BE_data["bus"]["$k"]["full_name_kV"],"__",Belgian_cities["$(cities_BE["$k"]["final_name"][2])"]["city"],"\n")
end
correct_ones_kV = [1,6,10,13,14,21,22,23,29,30,31,32,35,36,38,41,42,44,45,47,51,52,54,56,57,64,67,80,81,82,83,84,85,89,90,91,95,96,97,100,101,102,103,104,105,106,107,110,114,115,116,121,124,125,126,127]

count_ = 0
for k in correct_ones
    count_ += 1
    cities_BE["$k"]["substation"] = deepcopy(BE_data["bus"]["$k"]["full_name_kV"])
end
for k in correct_ones_kV
    if !haskey(cities_BE["$k"],"substation")
        count_ += 1
        cities_BE["$k"]["substation"] = deepcopy(BE_data["bus"]["$k"]["full_name_kV"])
    end
end

# Adding lat, lon and ZIP code for cities with the same name
count_ = 0
for (b_id,b) in BE_data["bus"]
    if !haskey(b,"lat")
        for k in eachindex(cities_BE)
            if haskey(cities_BE["$k"],"substation")
                if b["full_name_kV"] == cities_BE["$k"]["substation"]
                    count_ += 1
                    b["lat"] = deepcopy(Belgian_cities["$(cities_BE[k]["final_name"][2])"]["lat"])
                    b["lon"] = deepcopy(Belgian_cities["$(cities_BE[k]["final_name"][2])"]["lon"])
                    b["ZIP_code"] = deepcopy(Belgian_cities["$(cities_BE[k]["final_name"][2])"]["ZIP_code"])
                end
            end
        end
    end
end

# Adding lat and lon to the not assigned substations
function adding_lat_lon()
    # Gramme (Huy)
    BE_data["bus"]["2"]["lon"]      = 5.2357453	
    BE_data["bus"]["2"]["lat"]      = 50.5215385
    BE_data["bus"]["2"]["ZIP_code"] = 4500

    BE_data["bus"]["94"]["lon"] = 5.2357453	
    BE_data["bus"]["94"]["lat"] = 50.5215385
    BE_data["bus"]["94"]["ZIP_code"] = 4500

    # Achene (Ciney)
    BE_data["bus"]["3"]["ZIP_code"] = 5590
    BE_data["bus"]["3"]["lon"]      = 5.0974251
    BE_data["bus"]["3"]["lat"]      = 50.2949558

    BE_data["bus"]["80"]["ZIP_code"] = 5590
    BE_data["bus"]["80"]["lon"]      = 5.0974251
    BE_data["bus"]["80"]["lat"]      = 50.2949558

    # Andre Dumont (Genk)
    BE_data["bus"]["4"]["ZIP_code"] = 3600      
    BE_data["bus"]["4"]["lon"]      = 5.5001456
    BE_data["bus"]["4"]["lat"]      = 50.9654864

    # Brume
    BE_data["bus"]["7"]["ZIP_code"] = 4980            
    BE_data["bus"]["7"]["lon"]      = 5.8704355 
    BE_data["bus"]["7"]["lat"]      = 50.3727015

    BE_data["bus"]["50"]["ZIP_code"] = 4980            
    BE_data["bus"]["50"]["lon"]      = 5.8704355 
    BE_data["bus"]["50"]["lat"]      = 50.3727015

    BE_data["bus"]["62"]["ZIP_code"] = 4980            
    BE_data["bus"]["62"]["lon"]      = 5.8704355 
    BE_data["bus"]["62"]["lat"]      = 50.3727015

    BE_data["bus"]["63"]["ZIP_code"] = 4980            
    BE_data["bus"]["63"]["lon"]      = 5.8704355 
    BE_data["bus"]["63"]["lat"]      = 50.3727015

    BE_data["bus"]["87"]["ZIP_code"] = 4980            
    BE_data["bus"]["87"]["lon"]      = 5.8704355 
    BE_data["bus"]["87"]["lat"]      = 50.3727015

    BE_data["bus"]["88"]["ZIP_code"] = 4980            
    BE_data["bus"]["88"]["lon"]      = 5.8704355 
    BE_data["bus"]["88"]["lat"]      = 50.3727015

    # Horta (Zomergem)
    BE_data["bus"]["9"]["ZIP_code"] = 9930                 
    BE_data["bus"]["9"]["lon"]      = 3.5642436785112
    BE_data["bus"]["9"]["lat"]      = 51.1195778     

    # Bruegel (Dilbeek)
    BE_data["bus"]["11"]["ZIP_code"] = 1700                 
    BE_data["bus"]["11"]["lon"]      = 4.2657299667643
    BE_data["bus"]["11"]["lat"]      = 50.84408625    

    BE_data["bus"]["86"]["ZIP_code"] = 1700                 
    BE_data["bus"]["86"]["lon"]      = 4.2657299667643
    BE_data["bus"]["86"]["lat"]      = 50.84408625    

    # Mekingen (Sint-Pieters-Leeuw)
    BE_data["bus"]["12"]["ZIP_code"] = 1600      
    BE_data["bus"]["12"]["lon"]      = 4.2452186173064
    BE_data["bus"]["12"]["lat"]      = 50.78118355    
    
    # Bruegel (Dilbeek)
    BE_data["bus"]["11"]["ZIP_code"] = 1700                 
    BE_data["bus"]["11"]["lon"]      = 4.2657299667643
    BE_data["bus"]["11"]["lat"]      = 50.84408625    

    # Coo (Trois-Ponts)
    BE_data["bus"]["15"]["ZIP_code"] = 4980                 
    BE_data["bus"]["15"]["lon"]      = 5.8704355 
    BE_data["bus"]["15"]["lat"]      = 50.3727015

    # Mercator (Kruibeke)
    BE_data["bus"]["16"]["ZIP_code"] = 9150                  
    BE_data["bus"]["16"]["lon"]      = 4.3091107  
    BE_data["bus"]["16"]["lat"]      = 51.1712275

    BE_data["bus"]["108"]["ZIP_code"] = 9150            
    BE_data["bus"]["108"]["lon"]      = 4.3091107 
    BE_data["bus"]["108"]["lat"]      = 51.1712275

    BE_data["bus"]["109"]["ZIP_code"] = 9150            
    BE_data["bus"]["109"]["lon"]      = 4.3091107 
    BE_data["bus"]["109"]["lat"]      = 51.1712275

    # Verbrande Brug (Vilvoorde)
    BE_data["bus"]["17"]["ZIP_code"] = 1800           
    BE_data["bus"]["17"]["lon"]      = 4.4329052514838
    BE_data["bus"]["17"]["lat"]      = 50.92813655    

    BE_data["bus"]["123"]["ZIP_code"] = 1800           
    BE_data["bus"]["123"]["lon"]      = 4.4329052514838
    BE_data["bus"]["123"]["lat"]      = 50.92813655    

    # Senonchamps (Bastogne)
    BE_data["bus"]["18"]["ZIP_code"] = 6600                  
    BE_data["bus"]["18"]["lon"]      = 5.7153203  
    BE_data["bus"]["18"]["lat"]      = 50.0009951

    BE_data["bus"]["59"]["ZIP_code"] = 6600                  
    BE_data["bus"]["59"]["lon"]      = 5.7153203  
    BE_data["bus"]["59"]["lat"]      = 50.0009951

    # Gouy (Gouy-Lez-Pieton)
    BE_data["bus"]["20"]["ZIP_code"] = 6181                  
    BE_data["bus"]["20"]["lon"]      = 4.3287132  
    BE_data["bus"]["20"]["lat"]      = 50.4875628

    BE_data["bus"]["93"]["ZIP_code"] = 6181                  
    BE_data["bus"]["93"]["lon"]      = 4.3287132  
    BE_data["bus"]["93"]["lat"]      = 50.4875628

    # Eeklo Nord (Eeklo)
    BE_data["bus"]["24"]["ZIP_code"] = 9900                  
    BE_data["bus"]["24"]["lon"]      = 3.5665965  
    BE_data["bus"]["24"]["lat"]      = 51.1844827

    BE_data["bus"]["92"]["ZIP_code"] = 9900                  
    BE_data["bus"]["92"]["lon"]      = 3.5665965  
    BE_data["bus"]["92"]["lat"]      = 51.1844827

    # Van Maerlant (Moerkerke)
    BE_data["bus"]["25"]["ZIP_code"] = 8340                       
    BE_data["bus"]["25"]["lon"]      = 3.3558017705651 
    BE_data["bus"]["25"]["lat"]      = 51.2422333     

    # Gezelle (Dudzele)
    BE_data["bus"]["26"]["ZIP_code"] = 8380                  
    BE_data["bus"]["26"]["lon"]      = 3.2292277  
    BE_data["bus"]["26"]["lat"]      = 51.2747463

    # Offshore on Stevin (Zeebrugge)
    BE_data["bus"]["27"]["ZIP_code"] = 8380                 
    BE_data["bus"]["27"]["lon"]      = 3.2078842 
    BE_data["bus"]["27"]["lat"]      = 51.331382

    BE_data["bus"]["60"]["ZIP_code"] = 8380                 
    BE_data["bus"]["60"]["lon"]      = 3.2078842 
    BE_data["bus"]["60"]["lat"]      = 51.331382

    BE_data["bus"]["61"]["ZIP_code"] = 8380                 
    BE_data["bus"]["61"]["lon"]      = 3.2078842 
    BE_data["bus"]["61"]["lat"]      = 51.331382

    BE_data["bus"]["117"]["ZIP_code"] = 8380                 
    BE_data["bus"]["117"]["lon"]      = 3.2078842 
    BE_data["bus"]["117"]["lat"]      = 51.331382

    BE_data["bus"]["118"]["ZIP_code"] = 8380                 
    BE_data["bus"]["118"]["lon"]      = 3.2078842 
    BE_data["bus"]["118"]["lat"]      = 51.331382

    # Nemo (Zeebrugge)
    BE_data["bus"]["28"]["ZIP_code"] = 8380                 
    BE_data["bus"]["28"]["lon"]      = 3.2078842 
    BE_data["bus"]["28"]["lat"]      = 51.331382

    # Rimiere (Neuprè)
    BE_data["bus"]["33"]["ZIP_code"] = 4120                  
    BE_data["bus"]["33"]["lon"]      = 5.4901079  
    BE_data["bus"]["33"]["lat"]      = 50.5431751

    BE_data["bus"]["49"]["ZIP_code"] = 4120                  
    BE_data["bus"]["49"]["lon"]      = 5.4901079  
    BE_data["bus"]["49"]["lat"]      = 50.5431751

    BE_data["bus"]["111"]["ZIP_code"] = 4120                  
    BE_data["bus"]["111"]["lon"]      = 5.4901079  
    BE_data["bus"]["111"]["lat"]      = 50.5431751

    BE_data["bus"]["112"]["ZIP_code"] = 4120                  
    BE_data["bus"]["112"]["lon"]      = 5.4901079  
    BE_data["bus"]["112"]["lat"]      = 50.5431751

    # Rodenhuize (Desteldonk)
    BE_data["bus"]["34"]["ZIP_code"] = 9042                  
    BE_data["bus"]["34"]["lon"]      = 3.7836111  
    BE_data["bus"]["34"]["lat"]      = 51.1221778

    BE_data["bus"]["39"]["ZIP_code"] = 9042                  
    BE_data["bus"]["39"]["lon"]      = 3.7836111  
    BE_data["bus"]["39"]["lat"]      = 51.1221778

    BE_data["bus"]["113"]["ZIP_code"] = 9042                  
    BE_data["bus"]["113"]["lon"]      = 3.7836111  
    BE_data["bus"]["113"]["lat"]      = 51.1221778

    # Van Eyck (Maaseik)
    BE_data["bus"]["37"]["ZIP_code"] = 3680                  
    BE_data["bus"]["37"]["lon"]      = 5.791733   
    BE_data["bus"]["37"]["lat"]      = 51.0947181

    BE_data["bus"]["122"]["ZIP_code"] = 3680                  
    BE_data["bus"]["122"]["lon"]      = 5.791733   
    BE_data["bus"]["122"]["lat"]      = 51.0947181

    # Teergne (Leuze-en-Hainaut)
    BE_data["bus"]["40"]["ZIP_code"] = 7900                       
    BE_data["bus"]["40"]["lon"]      = 3.617736902638  
    BE_data["bus"]["40"]["lat"]      = 50.599042981582

    BE_data["bus"]["119"]["ZIP_code"] = 7900                       
    BE_data["bus"]["119"]["lon"]      = 3.617736902638  
    BE_data["bus"]["119"]["lat"]      = 50.599042981582

    BE_data["bus"]["120"]["ZIP_code"] = 7900                       
    BE_data["bus"]["120"]["lon"]      = 3.617736902638  
    BE_data["bus"]["120"]["lat"]      = 50.599042981582

    # Villeroux (Chastre-Villeroux-Blanmont)
    BE_data["bus"]["43"]["ZIP_code"] = 1450                       
    BE_data["bus"]["43"]["lon"]      = 4.6377941108725 
    BE_data["bus"]["43"]["lat"]      = 50.6106296     

    BE_data["bus"]["124"]["ZIP_code"] = 1450                       
    BE_data["bus"]["124"]["lon"]      = 4.6377941108725 
    BE_data["bus"]["124"]["lat"]      = 50.6106296  

    BE_data["bus"]["125"]["ZIP_code"] = 1450                       
    BE_data["bus"]["125"]["lon"]      = 4.6377941108725 
    BE_data["bus"]["125"]["lat"]      = 50.6106296  

    # Le Val (Seraing)
    BE_data["bus"]["48"]["ZIP_code"] = 4100                  
    BE_data["bus"]["48"]["lon"]      = 5.5083375  
    BE_data["bus"]["48"]["lat"]      = 50.5966392

    # Jupille (Jupille-Sur-Meuse)
    BE_data["bus"]["53"]["ZIP_code"] = 4020                  
    BE_data["bus"]["53"]["lon"]      = 5.6301266  
    BE_data["bus"]["53"]["lat"]      = 50.6431909

    BE_data["bus"]["98"]["ZIP_code"] = 4020                  
    BE_data["bus"]["98"]["lon"]      = 5.6301266  
    BE_data["bus"]["98"]["lat"]      = 50.6431909

    BE_data["bus"]["99"]["ZIP_code"] = 4020                  
    BE_data["bus"]["99"]["lon"]      = 5.6301266  
    BE_data["bus"]["99"]["lat"]      = 50.6431909

    BE_data["bus"]["100"]["ZIP_code"] = 4020                  
    BE_data["bus"]["100"]["lon"]      = 5.6301266  
    BE_data["bus"]["100"]["lat"]      = 50.6431909

    # La Troque (Seraing)
    BE_data["bus"]["55"]["ZIP_code"] = 4100                  
    BE_data["bus"]["55"]["lon"]      = 5.5083375  
    BE_data["bus"]["55"]["lat"]      = 50.5966392

    # Maasbracht (NL)
    BE_data["bus"]["58"]["ZIP_code"] = 0475                       
    BE_data["bus"]["58"]["lat"]      = 51.1577134      
    BE_data["bus"]["58"]["lon"]      = 5.8945473488255

    BE_data["bus"]["74"]["ZIP_code"] = 0475                       
    BE_data["bus"]["74"]["lat"]      = 51.1577134      
    BE_data["bus"]["74"]["lon"]      = 5.8945473488255

    BE_data["bus"]["75"]["ZIP_code"] = 0475                       
    BE_data["bus"]["75"]["lat"]      = 51.1577134      
    BE_data["bus"]["75"]["lon"]      = 5.8945473488255

    # Geertruidenberg (Geertruidenberg)
    BE_data["bus"]["77"]["ZIP_code"] = 339225                       
    BE_data["bus"]["77"]["lat"]      = 51.6954 
    BE_data["bus"]["77"]["lon"]      = 4.84123

    # St-Mard SNCB (Virton)
    BE_data["bus"]["65"]["ZIP_code"] = 6760                  
    BE_data["bus"]["65"]["lon"]      = 5.5329559  
    BE_data["bus"]["65"]["lat"]      = 49.5677263

    # Bank Zonder Naam (Offshore wind farm connected to Stevin)
    BE_data["bus"]["66"]["ZIP_code"] = 0000                  
    BE_data["bus"]["66"]["lon"]      = 2.968824  
    BE_data["bus"]["66"]["lat"]      = 51.690579

    # Chooz (France)
    BE_data["bus"]["68"]["ZIP_code"] = 0001                  
    BE_data["bus"]["68"]["lon"]      = 4.8071  
    BE_data["bus"]["68"]["lat"]      = 50.1024

    # Belval (Luxembourg)
    BE_data["bus"]["69"]["ZIP_code"] = 0002                  
    BE_data["bus"]["69"]["lon"]      = 5.9536  
    BE_data["bus"]["69"]["lat"]      = 49.4999

    # Sanem/Esch-Sur-Alzette (Luxembourg)
    BE_data["bus"]["70"]["ZIP_code"] = 0003                  
    BE_data["bus"]["70"]["lon"]      = 5.9722  
    BE_data["bus"]["70"]["lat"]      = 49.5024

    # Moulaine (France)
    BE_data["bus"]["71"]["ZIP_code"] = 0004                  
    BE_data["bus"]["71"]["lon"]      = 5.8186  
    BE_data["bus"]["71"]["lat"]      = 49.5021

    BE_data["bus"]["72"]["ZIP_code"] = 0005                  
    BE_data["bus"]["72"]["lon"]      = 5.8186  
    BE_data["bus"]["72"]["lat"]      = 49.5021

    # Lonny (France)
    BE_data["bus"]["73"]["ZIP_code"] = 0006                  
    BE_data["bus"]["73"]["lon"]      = 4.5864  
    BE_data["bus"]["73"]["lat"]      = 49.8161

    # Mastaing (France)
    BE_data["bus"]["78"]["ZIP_code"] = 0007                  
    BE_data["bus"]["78"]["lon"]      = 3.3036  
    BE_data["bus"]["78"]["lat"]      = 50.3062

    # Avelin (France)
    BE_data["bus"]["79"]["ZIP_code"] = 0008                  
    BE_data["bus"]["79"]["lon"]      = 3.0850  
    BE_data["bus"]["79"]["lat"]      = 50.5397

    # St-Mard (Virton)
    BE_data["bus"]["46"]["ZIP_code"] = 0008                  
    BE_data["bus"]["46"]["lon"]      = 5.5329559  
    BE_data["bus"]["46"]["lat"]      = 49.5677263

end
adding_lat_lon()

# Checking whether there are buses with no lat and lon
for i in 1:127 
    if haskey(BE_data["bus"]["$i"],"lat")
        print(i,".",BE_data["bus"]["$i"]["full_name_kV"],".",BE_data["bus"]["$i"]["lat"],".",BE_data["bus"]["$i"]["lon"],"\n")
    else
        print(i,".",BE_data["bus"]["$i"]["full_name_kV"],".","INSERT LAT",".","INSERT LON","\n")
    end
end

# Assigning the gen types to the generators 
types = []
fuel_types = []

for (g_id,g) in BE_data["gen"]
    push!(types,g["gen_type"])
    push!(fuel_types,g["fuel_type"])
end
unique(types)
unique(fuel_types)

# Assigning ENTSO-E's types
for (g_id,g) in BE_data["gen"]
    if g["gen_type"] == "WI"
        g["gen_type"] = "WOFF"
    end
    if g["gen_type"] == "WOFF"
        g["type"] = "Offshore Wind"
    elseif g["gen_type"] == "PV"
        g["type"] = "Solar PV"
    elseif g["gen_type"] == "VOLL"
        g["type"] = "VOLL"
    elseif g["gen_type"] == "WA"
        g["type"] = "Reservoir"
    elseif g["gen_type"] == "NG"
        g["type"] = "Gas CCGT new"
    elseif g["gen_type"] == "Other"
        g["type"] = "Other RES"
    elseif g["gen_type"] == "WON"
        g["type"] = "Onshore Wind"
    elseif g["gen_type"] == "LF"
        g["type"] = "Oil shale old"
    elseif g["gen_type"] == "NU"
        g["type"] = "Nuclear"
    end
end


## Assigning some big loads
# Van Eyck
BE_data["load"]["58"]["load_bus"] = 37
BE_data["load"]["59"]["load_bus"] = 37

# Zandvliet
BE_data["load"]["64"]["load_bus"] = 22
BE_data["load"]["65"]["load_bus"] = 22
BE_data["load"]["66"]["load_bus"] = 22

# Assigning the zones to each interconnector
BE_data["branch"]["94"]["zone"] = "FR"
BE_data["branch"]["95"]["zone"] = "LU"
BE_data["branch"]["96"]["zone"] = "LU"
BE_data["branch"]["97"]["zone"] = "FR"
BE_data["branch"]["98"]["zone"] = "FR"
BE_data["branch"]["99"]["zone"] = "FR"
BE_data["branch"]["100"]["zone"] = "NL"
BE_data["branch"]["101"]["zone"] = "NL"
BE_data["branch"]["102"]["zone"] = "NL"
BE_data["branch"]["103"]["zone"] = "NL"
BE_data["branch"]["104"]["zone"] = "FR"
BE_data["branch"]["105"]["zone"] = "FR"

# Fixing some resistances and reactances values (out of scale)
BE_data["branch"]["43"]["br_r"] = BE_data["branch"]["43"]["br_r"]/10
BE_data["branch"]["44"]["br_r"] = BE_data["branch"]["44"]["br_r"]/10
BE_data["branch"]["52"]["br_r"] = BE_data["branch"]["52"]["br_r"]/10
BE_data["branch"]["43"]["br_x"] = BE_data["branch"]["43"]["br_x"]/10
BE_data["branch"]["44"]["br_x"] = BE_data["branch"]["44"]["br_x"]/10
BE_data["branch"]["52"]["br_x"] = BE_data["branch"]["52"]["br_x"]/10

# Adding substations names and fixing error source_id loads
for (g_id,g) in BE_data["gen"]
    if g["type"] == "VOLL"
        for (b_id,b) in BE_data["bus"]
            if g["gen_bus"] == b["index"]
                g["substation_full_name"] = deepcopy(b["full_name"])
                g["substation_full_name_kV"] = deepcopy(b["full_name_kV"])
                g["substation"] = deepcopy(b["name"])
                g["substation_short_name"] = deepcopy(b["name_no_kV"])
                g["substation_short_name_kV"] = deepcopy(b["name"])
            end
        end
    end
end

# assigning the correct source_id to the loads
for (l_id,l) in BE_data["load"]
    l["source_id"][2] = deepcopy(l["load_bus"])
end


BE_data["bus"]["18"]["lat"] = 50.514669
BE_data["bus"]["18"]["lon"] = 4.906753

# Fixing ST-AMAND first (bottom to a bit higher)
BE_data["bus"]["19"]["lat"] = 50.506284
BE_data["bus"]["19"]["lon"] = 4.551047

BE_data["bus"]["43"]["lat"] = 49.978717
BE_data["bus"]["43"]["lon"] = 5.657869

BE_data["bus"]["76"]["lat"] = 51.410588
BE_data["bus"]["76"]["lon"] = 3.869445

BE_data["bus"]["37"]["lat"] = 51.120833
BE_data["bus"]["37"]["lon"] = 5.774167

BE_data["bus"]["124"]["lat"] = 49.978717
BE_data["bus"]["124"]["lon"] = 5.657869

BE_data["bus"]["125"]["lat"] = 49.978717
BE_data["bus"]["125"]["lon"] = 5.657869

BE_data["bus"]["68"]["lat"] = 50.1042
BE_data["bus"]["68"]["lon"] = 4.8078

BE_data["bus"]["15"]["lat"] = 50.386667
BE_data["bus"]["15"]["lon"] = 5.857222


# Adding and assigning generator values
gen_costs,inertia_constants,emission_factor_CO2,start_up_cost,emission_factor_NOx,emission_factor_SOx = gen_values()
assigning_gen_values(BE_data)

# Setting pmax for loads
load_ = 0
for (l_id,l) in BE_data["load"]
    l["pmax"] = deepcopy(l["pd"])
    load_ = load_ + l["pd"]
end

# Adding the HVDC branches currently existing in the Belgian grid
create_DC_grid_and_Nemo_and_Alegro_interconnections(BE_data)

# Removing this parameter which spoils the capacity of the branches somehow
for (br_id,br) in BE_data["branch"]
    delete!(br,"c_rating_a")
end

# Using the same name parameters for each grid element
for (b_id,b) in BE_data["bus"]
    b["name_kV"] = deepcopy(b["name"])
    b["name"] = deepcopy(b["name_no_kV"])
    delete!(b,"name_no_kV")
end


# Create JSON file to be saved (note that the grid is changed everytime one runs the script, as the distributed res generation is assigned randomly)
json_string_data = JSON.json(BE_data)
folder_results = @__DIR__

open(joinpath(dirname(dirname(folder_results)),"test_cases/Belgian_transmission_grid_data_Elia_2023.json"),"w" ) do f
write(f,json_string_data)
end

## From here on OPF simulations to check whether the OPF is feasible
# Call the grid
BE_grid_2023_file = joinpath(dirname(dirname(folder_results)),"test_cases/Belgian_transmission_grid_data_Elia_2023.json")
BE_grid_2023 = _PM.parse_file(BE_grid_2022_file)

# Run the AC/DC OPF to check whether the model is feasible
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
a = _PMACDC.run_acdcopf(BE_grid_2022, DCPPowerModel, Gurobi.Optimizer; setting = s)

#=
# Check the amount of VOLL in the system
sum_VOLL = 0
for i in 1:496
    if BE_grid_2022["gen"]["$i"]["gen_type"] == "VOLL"
        print(i,"__",a["solution"]["gen"]["$i"]["pg"],"__",BE_grid_2022["gen"]["$i"]["gen_bus"],"\n")
        sum_VOLL = sum_VOLL + a["solution"]["gen"]["$i"]["pg"]
    end
end
=#

# Check the installed capacity for each type of generator
compute_installed_capacities(BE_grid_2023)




