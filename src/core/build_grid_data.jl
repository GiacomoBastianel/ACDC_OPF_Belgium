# Help functions to process the Belgian grid

function process_grid_data(grid,generators,grid_m)
    # numbers here refer to the Belgian gri_static_data_2022
    gen_type = generators["Sheet1"]["F2:F111"]
    name_sub = generators["Sheet1"]["G2:G111"]
    sub_380_220 = generators["Sheet1"]["H2:H111"]
    sub_150 = generators["Sheet1"]["I2:I111"]
    replace!(sub_380_220, missing => 9999)
    replace!(sub_150, missing => 9999)
    
    
    # branches -> 1:93
    sub_1 = grid["Line_data_20181231"]["A5:A97"]
    sub_1_full_name = grid["Line_data_20181231"]["B5:B97"]
    sub_2 = grid["Line_data_20181231"]["C5:C97"]
    sub_2_full_name = grid["Line_data_20181231"]["D5:D97"]
    
    # interconnections -> 94:104
    sub_1_interconnection = grid["Interconnections_data_20181231"]["A5:A16"]
    sub_1_full_name_interconnection = grid["Interconnections_data_20181231"]["B5:B16"]
    sub_2_interconnection = grid["Interconnections_data_20181231"]["C5:C16"]
    sub_2_full_name_interconnection = grid["Interconnections_data_20181231"]["D5:D16"]
    
    # trafos -> 105:171
    sub_1_trafo = grid["Transformer_data_20181231"]["B5:B71"]
    sub_1_full_name_trafo = grid["Transformer_data_20181231"]["C5:C71"]
    
    for i in 1:length(sub_1)
        grid_m["branch"]["$i"]["f_bus_substation_name"] = sub_1_full_name[i]
        grid_m["branch"]["$i"]["f_bus_name"] = sub_1[i]
        grid_m["branch"]["$i"]["t_bus_substation_name"] = sub_2_full_name[i]
        grid_m["branch"]["$i"]["t_bus_name"] = sub_2[i]
        grid_m["branch"]["$i"]["transformer"] = false
    end
    for i in length(sub_1)+1:length(sub_1)+length(sub_1_interconnection)
        l = i - length(sub_1)
        grid_m["branch"]["$i"]["f_bus_substation_name"] = sub_1_full_name_interconnection[l]
        grid_m["branch"]["$i"]["f_bus_name"] = sub_1_interconnection[l]
        grid_m["branch"]["$i"]["t_bus_substation_name"] = sub_2_full_name_interconnection[l]
        grid_m["branch"]["$i"]["t_bus_name"] = sub_2_interconnection[l]
        grid_m["branch"]["$i"]["transformer"] = false
    end
    for i in length(sub_1)+length(sub_1_interconnection)+1:length(sub_1)+length(sub_1_interconnection)+length(sub_1_trafo)-1
        l = i - length(sub_1) - length(sub_1_interconnection)
        grid_m["branch"]["$i"]["f_bus_substation_name"] = sub_1_full_name_trafo[l]
        grid_m["branch"]["$i"]["f_bus_name"] = sub_1_trafo[l]
        grid_m["branch"]["$i"]["transformer"] = true
    end
    
    for (g_id,g) in grid_m["bus"]
        for (b_id,b) in grid_m["branch"]
            if g["index"] == b["f_bus"] 
               g["bus_name"] = deepcopy(b["f_bus_name"])
            elseif g["index"] == b["t_bus"] && haskey(b,"t_bus_name")
               g["bus_name"] = deepcopy(b["t_bus_name"])
            end
        end 
    end
    
    
    for (g_id,g) in grid_m["gen"]
        g["name_substation"] = name_sub[parse(Int64,g_id)]
        g["gen_type"] = gen_type[parse(Int64,g_id)]
    end
    for (g_id,g) in grid_m["gen"] 
        if g["gen_type"] == "WI" #&& "name_substation" == "Eeklo nord"
            g["type"] = "Offshore Wind"
        #elseif g["gen_type"] == "WI" && "name_substation" != "Eeklo nord"
        #    g["type"] = "Onshore Wind"
        elseif g["gen_type"] == "LF" 
            g["type"] = "Heavy oil old 1"
        elseif g["gen_type"] == "NU" 
            g["type"] = "Nuclear"
        elseif g["gen_type"] == "NG" 
            g["type"] = "Gas OCGT old"
            g["pmax"] = g["pmax"]*1.3 # adapting to real data (transparency platform)
            g["mbase"] = g["mbase"]*1.3
        elseif g["gen_type"] == "Other" 
            g["type"] = "Other RES"
        elseif g["gen_type"] == "WA" 
            g["type"] = "Reservoir"
        end
    end
    return grid_m
end

function distributing_solar_pv_onshore_wind(grid_m)
    # Based on 2022 data and Belgian grid
    substations_to_assign_pv = []
    for (g_id,g) in grid_m["bus"]
        if haskey(g,"bus_name") && g["bus_name"][1:1] != "X"
            push!(substations_to_assign_pv,g["bus_i"])
        end
    end 

    installed_capacity_solar_pv = 6475 #MW
    installed_capacity_onshore_wind = 2990 #MW

    for l in 1:20
        i = 110 + l #110 is the number of generators, to be adapted depending on the test case
        grid_m["gen"]["$i"] = deepcopy(grid_m["gen"]["1"])
        grid_m["gen"]["$i"]["pmax"] = installed_capacity_solar_pv./(20*100)
        grid_m["gen"]["$i"]["mbase"] = grid_m["gen"]["$i"]["pmax"]
        grid_m["gen"]["$i"]["source_id"][2] = i
        grid_m["gen"]["$i"]["name_substation"] = "solar_PV_"*"$i"
        grid_m["gen"]["$i"]["type"] = "Solar PV"
        grid_m["gen"]["$i"]["gen_type"] = "PV"
        grid_m["gen"]["$i"]["gen_bus"] = deepcopy(substations_to_assign_pv[l])
        grid_m["gen"]["$i"]["qmax"] = 0.0
        grid_m["gen"]["$i"]["qmin"] = 0.0
        grid_m["gen"]["$i"]["index"] = i
    end
    for l in 1:15
        i = 110 + 20 + l
        c = 20+l
        grid_m["gen"]["$i"] = deepcopy(grid_m["gen"]["1"])
        grid_m["gen"]["$i"]["pmax"] = installed_capacity_onshore_wind./(20*100)
        grid_m["gen"]["$i"]["mbase"] = grid_m["gen"]["$i"]["pmax"]
        grid_m["gen"]["$i"]["source_id"][2] = i
        grid_m["gen"]["$i"]["name_substation"] = "Wind_onshore_"*"$i"
        grid_m["gen"]["$i"]["type"] = "Onshore Wind"
        grid_m["gen"]["$i"]["gen_type"] = "WON"
        grid_m["gen"]["$i"]["gen_bus"] = deepcopy(substations_to_assign_pv[c])
        grid_m["gen"]["$i"]["qmax"] = 0.0
        grid_m["gen"]["$i"]["qmin"] = 0.0
        grid_m["gen"]["$i"]["index"] = i
    end
    return grid_m
end

function compute_installed_capacities(grid_m)
    types = []
    for (i_id,i) in grid_m["gen"]
        push!(types,i["type"])
    end
    unique_types = unique(types)
    installed_capacities = Dict()
    for i in eachindex(unique_types)
        b = unique_types[i]
        installed_capacities["$b"] = 0
    end
    for i in eachindex(installed_capacities)
        for (l_id,l) in grid_m["gen"]
            if l["type"] == i    
                installed_capacities["$i"] = installed_capacities["$i"] + l["pmax"]
            end
        end
    end
    return installed_capacities
end

function gen_values()
    gen_costs = Dict{String, Any}( # €/MWh
    "DSR" => 119,
    "Other non-RES"  => 120,
    "Offshore Wind"  => 59,
    "Onshore Wind"  => 25,
    "Solar PV"  => 18,
    "Solar Thermal"  => 89,
    "Gas CCGT new" => 89,
    "Gas CCGT old 1"  => 89,
    "Gas CCGT old 2"  => 89,
    "Gas CCGT present 1"  => 89,
    "Gas CCGT present 2"  => 89,
    "Reservoir"  => 18,
    "Run-of-River"  => 18,
    "Gas conventional old 1"  => 120,
    "Gas conventional old 2"  => 120,
    "PS Closed"  => 120,
    "PS Open"  => 120,
    "Lignite new"  => 120,
    "Lignite old 1"  => 120,
    "Lignite old 2"  => 120,
    "Hard coal new"  => 120,
    "Hard coal old 1"  => 120,
    "Hard coal old 2"  => 120,
    "Gas CCGT old 2 Bio"  => 120,
    "Gas conventional old 2 Bio"  => 120,
    "Hard coal new Bio"  => 120,
    "Hard coal old 1 Bio"  => 120,
    "Hard coal old 2 Bio" => 120,
    "Heavy oil old 1 Bio"  => 120,
    "Lignite old 1 Bio"  => 120,
    "Oil shale new Bio"  => 120,
    "Gas OCGT new"  => 89,
    "Gas OCGT old"  => 120,
    "Heavy oil old 1"  => 150,
    "Heavy oil old 2"  => 120,
    "Nuclear" => 110,
    "Light oil" => 140,
    "Oil shale new" => 150,
    "P2G" => 120,
    "Other non-RES DE00 P" => 120,
    "Other non-RES DKE1 P" => 120,
    "Other non-RES DKW1 P" => 120,
    "Other non-RES FI00 P" => 120,
    "Other non-RES FR00 P" => 120,
    "Other non-RES MT00 P" => 120,
    "Other non-RES UK00 P" => 120,
    "Other RES" => 60,
    "Gas CCGT new CCS"  => 89,
    "Gas CCGT present 1 CCS"  => 60,
    "Gas CCGT present 2 CCS" => 60,
    "Battery"  => 119,
    "Lignite old 2 Bio"  => 120,
    "Oil shale old"  => 150,
    "Gas CCGT CCS"  => 89,
    "VOLL" => 10000,
    "HVDC" => 0
    )


    # other non-RES are assumed to have the same emissions as gas
    emission_factor_CO2 = Dict{String, Any}( #kg/netGJ -> ton/MWh
    "DSR" => 0,
    "Other non-RES"  => 0,
    "Offshore Wind"  => 0,
    "Onshore Wind"  => 0,
    "Solar PV"  => 0,
    "Solar Thermal"  => 0,
    "Gas CCGT new"        => (57*3.6)*10^(-3),
    "Gas CCGT old 1"      => (57*3.6)*10^(-3),
    "Gas CCGT old 2"      => (57*3.6)*10^(-3),
    "Gas CCGT present 1"  => (57*3.6)*10^(-3),
    "Gas CCGT present 2"  => (57*3.6)*10^(-3),
    "Reservoir"  => 0,
    "Run-of-River"  => 0,
    "Gas conventional old 1"  => (57*3.6)*10^(-3),
    "Gas conventional old 2"  => (57*3.6)*10^(-3),
    "PS Closed"  => (57*3.6)*10^(-3),
    "PS Open"  =>   (57*3.6)*10^(-3),
    "Lignite new"  =>   (101*3.6)*10^(-3),
    "Lignite old 1"  => (101*3.6)*10^(-3),
    "Lignite old 2"  => (101*3.6)*10^(-3),
    "Hard coal new"  => (94*3.6)*10^(-3),
    "Hard coal old 1"  => (94*3.6)*10^(-3),
    "Hard coal old 2"  => (94*3.6)*10^(-3),
    "Gas CCGT old 2 Bio"          => (57*3.6)*10^(-3),
    "Gas conventional old 2 Bio"  => (57*3.6)*10^(-3),
    "Hard coal new Bio"  =>   (94*3.6)*10^(-3),
    "Hard coal old 1 Bio"  => (94*3.6)*10^(-3),
    "Hard coal old 2 Bio" =>  (94*3.6)*10^(-3),
    "Heavy oil old 1 Bio"  => (94*3.6)*10^(-3),
    "Lignite old 1 Bio"  => (101*3.6)*10^(-3),
    "Oil shale new Bio"  => (100*3.6)*10^(-3),
    "Gas OCGT new"  => (57*3.6)*10^(-3),
    "Gas OCGT old"  => (57*3.6)*10^(-3),
    "Heavy oil old 1"  => (78*3.6)*10^(-3),
    "Heavy oil old 2"  => (78*3.6)*10^(-3),
    "Nuclear" => 0,
    "Light oil" => (78*3.6)*10^(-3),
    "Oil shale new" => (100*3.6)*10^(-3),
    "P2G" => 0,
    "Other non-RES DE00 P" => (57*3.6)*10^(-3),
    "Other non-RES DKE1 P" => (57*3.6)*10^(-3),
    "Other non-RES DKW1 P" => (57*3.6)*10^(-3),
    "Other non-RES FI00 P" => (57*3.6)*10^(-3),
    "Other non-RES FR00 P" => (57*3.6)*10^(-3),
    "Other non-RES MT00 P" => (57*3.6)*10^(-3),
    "Other non-RES UK00 P" => (57*3.6)*10^(-3),
    "Other RES" => 0,
    "Gas CCGT new CCS"        => (5.7*3.6)*10^(-3),
    "Gas CCGT present 1 CCS"  => (5.7*3.6)*10^(-3),
    "Gas CCGT present 2 CCS"  => (5.7*3.6)*10^(-3),
    "Battery"  => 0,
    "Lignite old 2 Bio"  => (101*3.6)*10^(-3),
    "Oil shale old"  => (100*3.6)*10^(-3),
    "Gas CCGT CCS"  => (5.7*3.6)*10^(-3),
    "VOLL" => 0,
    "HVDC" => 0
    )



    inertia_constants = Dict{String, Any}( # s
    "DSR"                       => 0,
    "Other non-RES"             => 0,
    "Offshore Wind"             => 0,
    "Onshore Wind"              => 0,
    "Solar PV"                  => 0,
    "Solar Thermal"             => 0,
    "Gas CCGT new"              => 5,
    "Gas CCGT old 1"            => 5,
    "Gas CCGT old 2"            => 5,
    "Gas CCGT present 1"        => 5,
    "Gas CCGT present 2"        => 5,
    "Reservoir"                 => 3,
    "Run-of-River"              => 3,
    "Gas conventional old 1"    => 5,
    "Gas conventional old 2"    => 5,
    "PS Closed"                 => 3,
    "PS Open"                   => 3,
    "Lignite new"               => 4,
    "Lignite old 1"             => 4,
    "Lignite old 2"             => 4,
    "Hard coal new"             => 4,
    "Hard coal old 1"           => 4,
    "Hard coal old 2"           => 4,
    "Gas CCGT old 2 Bio"        => 5,
    "Gas conventional old 2 Bio"=> 5,
    "Hard coal new Bio"         => 4,
    "Hard coal old 1 Bio"       => 4,
    "Hard coal old 2 Bio"       => 4,
    "Heavy oil old 1 Bio"       => 4,
    "Lignite old 1 Bio"         => 4,
    "Oil shale new Bio"         => 4,
    "Gas OCGT new"              => 5,
    "Gas OCGT old"              => 5,
    "Heavy oil old 1"           => 4,
    "Heavy oil old 2"           => 4,
    "Nuclear"                   => 6,
    "Light oil"                 => 4,
    "Oil shale new"             => 4,
    "P2G"                       => 0,
    "Other non-RES DE00 P"      => 0,
    "Other non-RES DKE1 P"      => 0,
    "Other non-RES DKW1 P"      => 0,
    "Other non-RES FI00 P"      => 0,
    "Other non-RES FR00 P"      => 0,
    "Other non-RES MT00 P"      => 0,
    "Other non-RES UK00 P"      => 0,
    "Other RES"                 => 0,
    "Gas CCGT new CCS"          => 5,
    "Gas CCGT present 1 CCS"    => 5,
    "Gas CCGT present 2 CCS"    => 5,
    "Battery"                   => 0,
    "Lignite old 2 Bio"         => 4,
    "Oil shale old"             => 4,
    "Gas CCGT CCS"              => 5,
    "VOLL"                      => 0,
    "HVDC"                      => 0
    )

    start_up_cost = Dict{String, Any}( #EUR/MW/start
    "DSR" => 0,
    "Other non-RES"  => 90,
    "Offshore Wind"  => 0,
    "Onshore Wind"  => 0,
    "Solar PV"  => 0,
    "Solar Thermal"  => 0,
    "Gas CCGT new"        => 90,
    "Gas CCGT old 1"      => 90,
    "Gas CCGT old 2"      => 90,
    "Gas CCGT present 1"  => 90,
    "Gas CCGT present 2"  => 90,
    "Reservoir"  => 0,
    "Run-of-River"  => 0,
    "Gas conventional old 1"  => 90,
    "Gas conventional old 2"  => 90,
    "PS Closed"  => 150,
    "PS Open"  =>   150,
    "Lignite new"  =>   175,
    "Lignite old 1"  => 175,
    "Lignite old 2"  => 175,
    "Hard coal new"  => 175,
    "Hard coal old 1"  => 175,
    "Hard coal old 2"  => 175,
    "Gas CCGT old 2 Bio"          => 90,
    "Gas conventional old 2 Bio"  => 90,
    "Hard coal new Bio"  =>   175,
    "Hard coal old 1 Bio"  => 175,
    "Hard coal old 2 Bio" =>  175,
    "Heavy oil old 1 Bio"  => 150,
    "Lignite old 1 Bio"  => 175,
    "Oil shale new Bio"  => 150,
    "Gas OCGT new"  => 90,
    "Gas OCGT old"  => 90,
    "Heavy oil old 1"  => 150,
    "Heavy oil old 2"  => 150,
    "Nuclear" => 1000,
    "Light oil" =>     150,
    "Oil shale new" => 150,
    "P2G" => 0,
    "Other non-RES DE00 P" => 175,
    "Other non-RES DKE1 P" => 175,
    "Other non-RES DKW1 P" => 175,
    "Other non-RES FI00 P" => 175,
    "Other non-RES FR00 P" => 175,
    "Other non-RES MT00 P" => 175,
    "Other non-RES UK00 P" => 175,
    "Other RES" => 0,
    "Gas CCGT new CCS"        => 90,
    "Gas CCGT present 1 CCS"  => 90,
    "Gas CCGT present 2 CCS"  => 90,
    "Battery"  => 0,
    "Lignite old 2 Bio"  => 175,
    "Oil shale old"  => 150,
    "Gas CCGT CCS"  => 90,
    "VOLL" => 0,
    "HVDC" => 0
    )

    emission_factor_NOx = Dict{String, Any}( #g/kWh == kg/MWh
    "DSR"                         => 0,
    "Other non-RES"               => 0.2587,
    "Offshore Wind"               => 0,
    "Onshore Wind"                => 0,
    "Solar PV"                    => 0,
    "Solar Thermal"               => 0,
    "Gas CCGT new"                => 0.2334,
    "Gas CCGT old 1"              => 0.2334,
    "Gas CCGT old 2"              => 0.2334,
    "Gas CCGT present 1"          => 0.2334,
    "Gas CCGT present 2"          => 0.2334,
    "Reservoir"                   => 0,
    "Run-of-River"                => 0,
    "Gas conventional old 1"      => 0.2334,
    "Gas conventional old 2"      => 0.2334,
    "PS Closed"                   => 0.2334,
    "PS Open"                     => 0.2334,
    "Lignite new"                 => 0.2587,
    "Lignite old 1"               => 0.2587,
    "Lignite old 2"               => 0.2587,
    "Hard coal new"               => 0.2587,
    "Hard coal old 1"             => 0.2587,
    "Hard coal old 2"             => 0.2587,
    "Gas CCGT old 2 Bio"          => 0.2334,
    "Gas conventional old 2 Bio"  => 0.2334,
    "Hard coal new Bio"           => 0.2587,
    "Hard coal old 1 Bio"         => 0.2587,
    "Hard coal old 2 Bio"         => 0.2587,
    "Heavy oil old 1 Bio"         => 0.8049,
    "Lignite old 1 Bio"           => 0.2587,
    "Oil shale new Bio"           => 0.8049,
    "Gas OCGT new"                => 0.2334,
    "Gas OCGT old"                => 0.2334,
    "Heavy oil old 1"             => 0.8049,
    "Heavy oil old 2"             => 0.8049,
    "Nuclear"                     => 0,
    "Light oil"                   => 0.8049,
    "Oil shale new"               => 0.8049,
    "P2G"                         => 0,
    "Other non-RES DE00 P"        => 0.2334,
    "Other non-RES DKE1 P"        => 0.2334,
    "Other non-RES DKW1 P"        => 0.2334,
    "Other non-RES FI00 P"        => 0.2334,
    "Other non-RES FR00 P"        => 0.2334,
    "Other non-RES MT00 P"        => 0.2334,
    "Other non-RES UK00 P"        => 0.2334,
    "Other RES"                   => 0.2334,
    "Gas CCGT new CCS"            => 0.2334,
    "Gas CCGT present 1 CCS"      => 0.2334,
    "Gas CCGT present 2 CCS"      => 0.2334,
    "Battery"                     => 0,
    "Lignite old 2 Bio"           => 0.2587,
    "Oil shale old"               => 0.8049,
    "Gas CCGT CCS"                => 0.2334,
    "VOLL"                        => 0,
    "HVDC"                        => 0
    )

    emission_factor_SOx = Dict{String, Any}( #g/kWh == kg/MWh
    "DSR"                         => 0,
    "Other non-RES"               => 0.3322,
    "Offshore Wind"               => 0,
    "Onshore Wind"                => 0,
    "Solar PV"                    => 0,
    "Solar Thermal"               => 0,
    "Gas CCGT new"                => 0.0046,
    "Gas CCGT old 1"              => 0.0046,
    "Gas CCGT old 2"              => 0.0046,
    "Gas CCGT present 1"          => 0.0046,
    "Gas CCGT present 2"          => 0.0046,
    "Reservoir"                   => 0,
    "Run-of-River"                => 0,
    "Gas conventional old 1"      => 0.0046,
    "Gas conventional old 2"      => 0.0046,
    "PS Closed"                   => 0.0046,
    "PS Open"                     => 0.0046,
    "Lignite new"                 => 0.3322,
    "Lignite old 1"               => 0.3322,
    "Lignite old 2"               => 0.3322,
    "Hard coal new"               => 0.3322,
    "Hard coal old 1"             => 0.3322,
    "Hard coal old 2"             => 0.3322,
    "Gas CCGT old 2 Bio"          => 0.0046,
    "Gas conventional old 2 Bio"  => 0.0046,
    "Hard coal new Bio"           => 0.3322,
    "Hard coal old 1 Bio"         => 0.3322,
    "Hard coal old 2 Bio"         => 0.3322,
    "Heavy oil old 1 Bio"         => 1.1573,
    "Lignite old 1 Bio"           => 0.3322,
    "Oil shale new Bio"           => 1.1573,
    "Gas OCGT new"                => 0.0046,
    "Gas OCGT old"                => 0.0046,
    "Heavy oil old 1"             => 1.1573,
    "Heavy oil old 2"             => 1.1573,
    "Nuclear"                     => 0,
    "Light oil"                   => 1.1573,
    "Oil shale new"               => 1.1573,
    "P2G"                         => 0,
    "Other non-RES DE00 P"        => 0.0046,
    "Other non-RES DKE1 P"        => 0.0046,
    "Other non-RES DKW1 P"        => 0.0046,
    "Other non-RES FI00 P"        => 0.0046,
    "Other non-RES FR00 P"        => 0.0046,
    "Other non-RES MT00 P"        => 0.0046,
    "Other non-RES UK00 P"        => 0.0046,
    "Other RES"                   => 0.0046,
    "Gas CCGT new CCS"            => 0.0046,
    "Gas CCGT present 1 CCS"      => 0.0046,
    "Gas CCGT present 2 CCS"      => 0.0046,
    "Battery"                     => 0,
    "Lignite old 2 Bio"           => 0.3322,
    "Oil shale old"               => 1.1573,
    "Gas CCGT CCS"                => 0.0046,
    "VOLL"                        => 0,
    "HVDC"                        => 0
    )

    return gen_costs,inertia_constants,emission_factor_CO2,start_up_cost,emission_factor_NOx,emission_factor_SOx
end

function assigning_gen_values(grid_m)
    for (g_id,g) in grid_m["gen"]
        for i in eachindex(gen_costs)
            if g["type"] == i
                g["cost"] = []
                push!(g["cost"],gen_costs[i])
                push!(g["cost"],0.0)
                g["ncost"] = 2
                g["C02_emission"] = emission_factor_CO2[i]
                g["NOx_emission"] = emission_factor_NOx[i]
                g["SOx_emission"] = emission_factor_SOx[i]
                g["start_up_cost"] = start_up_cost[i]
                g["inertia_constant"] = inertia_constants[i]
                g["installed_capacity"] = deepcopy(g["pmax"])
            end
        end
        if !haskey(g,"zone")
            g["zone"] = "BE00"
        end
    end
    for (l_id,l) in grid_m["load"]
        if !haskey(l,"zone")
            l["zone"] = "BE00"
        end
    end
    return grid_m
end

function create_load_series(scenario,year,zone,hour_start,number_of_hours)
    load_file = joinpath("/Users/giacomobastianel/Desktop/tyndpdata/scenarios/"*scenario*"_Demand_CY"*"$year"*".csv")
    df = CSV.read(load_file,DataFrame)
    load_series = df[!,zone][hour_start:(hour_start+number_of_hours-1)]
    return load_series
end

function dimensioning_load(grid_m)
    tot_load = sum(grid_m["load"][i]["pd"] for i in eachindex(grid_m["load"]))
    for (l_id,l) in grid_m["load"]
        l["power_portion"] = l["pd"]/tot_load
    end
end

function create_gen_load_interconnections(grid)
    # Number of generators 500
    # Number of loads 69
    #Number of buses 129
    n_gens = 498
    n_loads = 69
    n_buses = 129
    n_branches = 176

    # Adding buses representing the countries (FR,LU,NL)
    for i in 1:3
        BE_grid["bus"]["$(n_buses+i)"] = deepcopy(BE_grid["bus"]["2"])
        BE_grid["bus"]["$(n_buses+i)"]["trafo"] = false
        BE_grid["bus"]["$(n_buses+i)"]["bus_i"] = deepcopy(n_buses+i)
        BE_grid["bus"]["$(n_buses+i)"]["bus_type"] = 1
        BE_grid["bus"]["$(n_buses+i)"]["vmax"] = 1.1
        BE_grid["bus"]["$(n_buses+i)"]["source_id"] = []
        push!(BE_grid["bus"]["$(n_buses+i)"]["source_id"],"bus")
        push!(BE_grid["bus"]["$(n_buses+i)"]["source_id"],deepcopy(n_buses+i))
        BE_grid["bus"]["$(n_buses+i)"]["vmin"] = 0.9
        BE_grid["bus"]["$(n_buses+i)"]["index"] = deepcopy(n_buses+i)
        BE_grid["bus"]["$(n_buses+i)"]["va"] = 0.0
        BE_grid["bus"]["$(n_buses+i)"]["vm"] = 1.0
    end
    BE_grid["bus"]["130"]["lat"] = 50.105803
    BE_grid["bus"]["130"]["lon"] = 3.409879
    BE_grid["bus"]["130"]["name_no_kV"] = "FR00"
    BE_grid["bus"]["130"]["full_name_kV"] = "FR00_380"
    BE_grid["bus"]["130"]["full_name"] = "FR00"
    BE_grid["bus"]["130"]["name"] = "FR00_380"

    BE_grid["bus"]["131"]["lat"] = 49.743448
    BE_grid["bus"]["131"]["lon"] = 6.051579
    BE_grid["bus"]["131"]["name_no_kV"] = "LU00"
    BE_grid["bus"]["131"]["full_name_kV"] = "LU00_380"
    BE_grid["bus"]["131"]["full_name"] = "LU00"
    BE_grid["bus"]["131"]["name"] = "LU00_380"

    BE_grid["bus"]["132"]["lat"] = 51.581652
    BE_grid["bus"]["132"]["lon"] = 4.997252
    BE_grid["bus"]["132"]["name_no_kV"] = "NL00"
    BE_grid["bus"]["132"]["full_name_kV"] = "NL00_380"
    BE_grid["bus"]["132"]["full_name"] = "NL00"
    BE_grid["bus"]["132"]["name"] = "NL00_380"

    # Adding one gen and one load for each neighbouring Country
    # Adding gens representing the countries (FR,LU,NL)
    for i in 1:3
        BE_grid["gen"]["$(n_gens+i)"] = deepcopy(BE_grid["gen"]["21"])
        BE_grid["gen"]["$(n_gens+i)"]["vg"] = 1.0
        BE_grid["gen"]["$(n_gens+i)"]["index"] = deepcopy(n_gens+i)
        BE_grid["gen"]["$(n_gens+i)"]["pmax"] = 99.99
        BE_grid["gen"]["$(n_gens+i)"]["pmin"] = 0.0#./dict["$i"]["mbase"]
        BE_grid["gen"]["$(n_gens+i)"]["source_id"][2] = deepcopy(n_gens+i)
        BE_grid["gen"]["$(n_gens+i)"]["owner"] = "Outside_BE"
        BE_grid["gen"]["$(n_gens+i)"]["qmax"] = deepcopy(BE_grid["gen"]["$(n_gens+i)"]["pmax"]/2)
        BE_grid["gen"]["$(n_gens+i)"]["qmin"] = deepcopy(BE_grid["gen"]["$(n_gens+i)"]["pmax"]/2)*(-1)
    end
    BE_grid["gen"]["499"]["zone"] = "FR00"
    BE_grid["gen"]["499"]["name"] = "FR00"
    BE_grid["gen"]["499"]["substation_full_name_kV"] = "FR00_380"
    BE_grid["gen"]["499"]["substation_full_name"] = "FR00"
    BE_grid["gen"]["499"]["substation"] = "FR00"
    BE_grid["gen"]["499"]["substation_short_name_kV"] = "FR00_380"
    BE_grid["gen"]["499"]["substation_short_name"] = "FR00_380"
    BE_grid["gen"]["499"]["gen_bus"] = 130
    BE_grid["gen"]["499"]["neighbouring"] = true

    BE_grid["gen"]["500"]["zone"] = "LU00"
    BE_grid["gen"]["500"]["name"] = "LU00"
    BE_grid["gen"]["500"]["substation_full_name_kV"] = "LU00_380"
    BE_grid["gen"]["500"]["substation_full_name"] = "LU00"
    BE_grid["gen"]["500"]["substation"] = "LU00"
    BE_grid["gen"]["500"]["substation_short_name_kV"] = "LU00_380"
    BE_grid["gen"]["500"]["substation_short_name"] = "LU00_380"
    BE_grid["gen"]["500"]["gen_bus"] = 131
    BE_grid["gen"]["500"]["neighbouring"] = true

    BE_grid["gen"]["501"]["zone"] = "NL00"
    BE_grid["gen"]["501"]["name"] = "NL00"
    BE_grid["gen"]["501"]["substation_full_name_kV"] = "NL00_380"
    BE_grid["gen"]["501"]["substation_full_name"] = "NL00"
    BE_grid["gen"]["501"]["substation"] = "NL00"
    BE_grid["gen"]["501"]["substation_short_name_kV"] = "NL00_380"
    BE_grid["gen"]["501"]["substation_short_name"] = "NL00_380"
    BE_grid["gen"]["501"]["gen_bus"] = 132
    BE_grid["gen"]["501"]["neighbouring"] = true

    # Adding loads representing the countries (FR,LU,NL)
    for i in 1:3
        BE_grid["load"]["$(n_loads+i)"] = deepcopy(BE_grid["load"]["1"])
        BE_grid["load"]["$(n_loads+i)"]["index"] = deepcopy(n_loads+i)
        BE_grid["load"]["$(n_loads+i)"]["zone"] = "BE00"
        BE_grid["load"]["$(n_loads+i)"]["cosphi"] = 0.90 #assumed fixed value
        BE_grid["load"]["$(n_loads+i)"]["pmax"] = 99.99 #it will be adjusted later
        BE_grid["load"]["$(n_loads+i)"]["pmin"] = 0.0
        BE_grid["load"]["$(n_loads+i)"]["pmax_2"] = 99.99
        BE_grid["load"]["$(n_loads+i)"]["pmax_3"] = 99.99
        BE_grid["load"]["$(n_loads+i)"]["base_kV"] = 380.0
        BE_grid["load"]["$(n_loads+i)"]["base_kV_1"] = 380.0
        BE_grid["load"]["$(n_loads+i)"]["base_kV_2"] = 380.0
        BE_grid["load"]["$(n_loads+i)"]["base_kV_3"] = 380.0
        BE_grid["load"]["$(n_loads+i)"]["qd_max"] = deepcopy(99.99) # 10 % of the total load
        BE_grid["load"]["$(n_loads+i)"]["status"] = 1
        BE_grid["load"]["$(n_loads+i)"]["pd"] = 0.0 
        BE_grid["load"]["$(n_loads+i)"]["qd"] = 0.0 
        BE_grid["load"]["$(n_loads+i)"]["source_id"] = []
        push!(BE_grid["load"]["$(n_loads+i)"]["source_id"],"bus")
        push!(BE_grid["load"]["$(n_loads+i)"]["source_id"],i)
    end
    BE_grid["load"]["70"]["name"] = "FR00_380"
    BE_grid["load"]["70"]["name_no_kV"] = "FR00"
    BE_grid["load"]["70"]["full_name_kV"] = "FR00_380"
    BE_grid["load"]["70"]["full_name"] = "FR00"
    BE_grid["load"]["70"]["zone"] = "FR00"
    BE_grid["load"]["70"]["load_bus"] = 130
    BE_grid["load"]["70"]["neighbouring"] = true

    BE_grid["load"]["71"]["name"] = "LU00_380"
    BE_grid["load"]["71"]["name_no_kV"] = "LU00"
    BE_grid["load"]["71"]["full_name_kV"] = "LU00_380"
    BE_grid["load"]["71"]["full_name"] = "LU00"
    BE_grid["load"]["71"]["zone"] = "LU00"
    BE_grid["load"]["71"]["load_bus"] = 131
    BE_grid["load"]["71"]["neighbouring"] = true

    BE_grid["load"]["72"]["name"] = "NL00_380"
    BE_grid["load"]["72"]["name_no_kV"] = "NL00"
    BE_grid["load"]["72"]["full_name_kV"] = "NL00_380"
    BE_grid["load"]["72"]["full_name"] = "NL00"
    BE_grid["load"]["72"]["zone"] = "NL00"
    BE_grid["load"]["72"]["load_bus"] = 132
    BE_grid["load"]["72"]["neighbouring"] = true

    # NEED TO CREATE BRANCHES LINKING X_BUSES TO THESE NEW BUSES -> already existing
    for i in 1:12
        BE_grid["branch"]["$(n_branches+i)"] = deepcopy(BE_grid["branch"]["1"])
        BE_grid["branch"]["$(n_branches+i)"]["source_id"][2] = deepcopy(n_branches+i)
        BE_grid["branch"]["$(n_branches+i)"]["interconnection"] = true
        BE_grid["branch"]["$(n_branches+i)"]["index"] = deepcopy(n_branches+i)
        BE_grid["branch"]["$(n_branches+i)"]["rate_a"] = 99.99
        BE_grid["branch"]["$(n_branches+i)"]["br_r"] = 0.001
        BE_grid["branch"]["$(n_branches+i)"]["br_x"] = 0.001
        delete!(BE_grid["branch"]["$(n_branches+i)"],"f_bus_name_kV")
        delete!(BE_grid["branch"]["$(n_branches+i)"],"t_bus_name_kV")
        delete!(BE_grid["branch"]["$(n_branches+i)"],"f_bus_full_name_kV")
        delete!(BE_grid["branch"]["$(n_branches+i)"],"t_bus_full_name_kV")
        delete!(BE_grid["branch"]["$(n_branches+i)"],"f_bus_full_name")
        delete!(BE_grid["branch"]["$(n_branches+i)"],"t_bus_full_name")
        delete!(BE_grid["branch"]["$(n_branches+i)"],"f_bus_name")
        delete!(BE_grid["branch"]["$(n_branches+i)"],"t_bus_name")
    end

    # France
    BE_grid["branch"]["177"]["f_bus"] = 130 #FR
    BE_grid["branch"]["177"]["f_bus_name"] = "FR00_380"
    BE_grid["branch"]["177"]["t_bus"] = 68 
    BE_grid["branch"]["177"]["t_bus_full_name_kV"] = "CHOOZ_220"
    BE_grid["branch"]["177"]["t_bus_name_kV"] = "XMO_CH21_220"
    BE_grid["branch"]["177"]["t_bus_full_name"] = "CHOOZ"
    BE_grid["branch"]["177"]["t_bus_name"] = "XMO_CH21"

    BE_grid["branch"]["178"]["f_bus"] = 130 #FR
    BE_grid["branch"]["178"]["f_bus_name"] = "FR00_380"
    BE_grid["branch"]["178"]["t_bus"] = 71
    BE_grid["branch"]["178"]["t_bus_full_name_kV"] = "MOULAINE_220"
    BE_grid["branch"]["178"]["t_bus_name_kV"] = "XAU_MO22_220"
    BE_grid["branch"]["178"]["t_bus_full_name"] = "MOULAINE"
    BE_grid["branch"]["178"]["t_bus_name"] = "XAU_MO22"

    BE_grid["branch"]["179"]["f_bus"] = 130 #FR
    BE_grid["branch"]["179"]["f_bus_name"] = "FR00_380"
    BE_grid["branch"]["179"]["t_bus"] = 72
    BE_grid["branch"]["179"]["t_bus_full_name_kV"] = "MOULAINE_220"
    BE_grid["branch"]["179"]["t_bus_name_kV"] = "XAU_M.21_220"
    BE_grid["branch"]["179"]["t_bus_full_name"] = "MOULAINE"
    BE_grid["branch"]["179"]["t_bus_name"] = "XAU_M.21"

    BE_grid["branch"]["180"]["f_bus"] = 130 #FR
    BE_grid["branch"]["180"]["f_bus_name"] = "FR00_380"
    BE_grid["branch"]["180"]["t_bus"] = 73
    BE_grid["branch"]["180"]["t_bus_full_name_kV"] = "LONNY_380"
    BE_grid["branch"]["180"]["t_bus_name_kV"] = "XAC_LO11_380"
    BE_grid["branch"]["180"]["t_bus_full_name"] = "LONNY"
    BE_grid["branch"]["180"]["t_bus_name"] = "XAC_LO11"

    BE_grid["branch"]["181"]["f_bus"] = 130 #FR
    BE_grid["branch"]["181"]["f_bus_name"] = "FR00_380"
    BE_grid["branch"]["181"]["t_bus"] = 78
    BE_grid["branch"]["181"]["t_bus_full_name_kV"] = "MASTAING_380"
    BE_grid["branch"]["181"]["t_bus_name_kV"] = "XAV_MA11_380"
    BE_grid["branch"]["181"]["t_bus_full_name"] = "MASTAING"
    BE_grid["branch"]["181"]["t_bus_name"] = "XAV_MA11"

    BE_grid["branch"]["182"]["f_bus"] = 130 #FR
    BE_grid["branch"]["182"]["f_bus_name"] = "FR00_380"
    BE_grid["branch"]["182"]["t_bus"] = 79
    BE_grid["branch"]["182"]["t_bus_full_name_kV"] = "AVELIN_380"
    BE_grid["branch"]["182"]["t_bus_name_kV"] = "XAV_AV11_380"
    BE_grid["branch"]["182"]["t_bus_full_name"] = "AVELIN"
    BE_grid["branch"]["182"]["t_bus_name"] = "XAV_AV11"

    # Luxembourg
    BE_grid["branch"]["183"]["f_bus"] = 131 #LU
    BE_grid["branch"]["183"]["f_bus_name"] = "LU00_380"
    BE_grid["branch"]["183"]["t_bus"] = 69
    BE_grid["branch"]["183"]["t_bus_full_name_kV"] = "ESCH / BELVAL_220"
    BE_grid["branch"]["183"]["t_bus_name_kV"] = "ESCH _220"
    BE_grid["branch"]["183"]["t_bus_full_name"] = "ESCH / BELVAL"
    BE_grid["branch"]["183"]["t_bus_name"] = "ESCH "

    BE_grid["branch"]["184"]["f_bus"] = 131 #LU
    BE_grid["branch"]["184"]["f_bus_name"] = "LU00_380"
    BE_grid["branch"]["184"]["t_bus"] = 70
    BE_grid["branch"]["184"]["t_bus_full_name_kV"] = "SANEM_220"
    BE_grid["branch"]["184"]["t_bus_name_kV"] = "XAU_SA21_220"
    BE_grid["branch"]["184"]["t_bus_full_name"] = "SANEM"
    BE_grid["branch"]["184"]["t_bus_name"] = "XAU_SA21 "

    # The Netherlands
    BE_grid["branch"]["185"]["f_bus"] = 132 #NL
    BE_grid["branch"]["185"]["f_bus_name"] = "NL00_380"
    BE_grid["branch"]["185"]["t_bus"] = 74
    BE_grid["branch"]["185"]["t_bus_full_name_kV"] = "MAASBRACHT_380"
    BE_grid["branch"]["185"]["t_bus_name_kV"] = "XVY_MB12_380"
    BE_grid["branch"]["185"]["t_bus_full_name"] = "MAASBRACHT"
    BE_grid["branch"]["185"]["t_bus_name"] = "XVY_MB12 "

    BE_grid["branch"]["186"]["f_bus"] = 132 #NL
    BE_grid["branch"]["186"]["f_bus_name"] = "NL00_380"
    BE_grid["branch"]["186"]["t_bus"] = 75
    BE_grid["branch"]["186"]["t_bus_full_name_kV"] = "MAASBRACHT_380"
    BE_grid["branch"]["186"]["t_bus_name_kV"] = "XVY_MB11_380"
    BE_grid["branch"]["186"]["t_bus_full_name"] = "MAASBRACHT"
    BE_grid["branch"]["186"]["t_bus_name"] = "XVY_MB11"
    
    BE_grid["branch"]["187"]["f_bus"] = 132 #NL
    BE_grid["branch"]["187"]["f_bus_name"] = "NL00_380"
    BE_grid["branch"]["187"]["t_bus"] = 76
    BE_grid["branch"]["187"]["t_bus_full_name_kV"] = "BORSSELE_380"
    BE_grid["branch"]["187"]["t_bus_name_kV"] = "XZA_BS11_380"
    BE_grid["branch"]["187"]["t_bus_full_name"] = "BORSSELE"
    BE_grid["branch"]["187"]["t_bus_name"] = "XZA_BS11"

    BE_grid["branch"]["188"]["f_bus"] = 132 #NL
    BE_grid["branch"]["188"]["f_bus_name"] = "NL00_380"
    BE_grid["branch"]["188"]["t_bus"] = 77
    BE_grid["branch"]["188"]["t_bus_full_name_kV"] = "GEERTRUIDENBERG_380"
    BE_grid["branch"]["188"]["t_bus_name_kV"] = "XZA_GT11_380"
    BE_grid["branch"]["188"]["t_bus_full_name"] = "GEERTRUIDENBERG"
    BE_grid["branch"]["188"]["t_bus_name"] = "XZA_GT11 "
    
end

function create_interconnectors_power_flow(grid)
    # BE -> LU is load
    # LU -> BE is generator
    base_file = "/Users/giacomobastianel/Desktop/Belgian_grid_data/Interconnector_power_flow"
    power_flow_LU = joinpath(base_file,"Cross-Border Physical Flow_2022_2023_BE_LU.csv")
    df_LU = DataFrame(CSV.File(power_flow_LU))
    power_flow_LU_BE = df_LU[:,2]
    power_flow_BE_LU = df_LU[:,3]

    power_flow_DE = joinpath(base_file,"Cross-Border Physical Flow_2022_2023_BE_DE.csv")
    df_DE = DataFrame(CSV.File(power_flow_DE))
    power_flow_DE_BE = df_DE[:,2]
    power_flow_BE_DE = df_DE[:,3]

    power_flow_NL = joinpath(base_file,"Cross-Border Physical Flow_2022_2023_BE_NL.csv")
    df_NL = DataFrame(CSV.File(power_flow_NL))
    power_flow_NL_BE = df_NL[:,2]
    power_flow_BE_NL = df_NL[:,3]

    power_flow_UK = joinpath(base_file,"Cross-Border Physical Flow_2022_2023_BE_UK.csv")
    df_UK = DataFrame(CSV.File(power_flow_UK))
    power_flow_UK_BE = df_UK[:,2]
    power_flow_BE_UK = df_UK[:,3]

    power_flow_FR = joinpath(base_file,"Cross-Border Physical Flow_2022_2023_BE_FR.csv")
    df_FR = DataFrame(CSV.File(power_flow_FR))
    power_flow_FR_BE = df_FR[:,2]
    power_flow_BE_FR = df_FR[:,3]

    return power_flow_LU_BE,power_flow_BE_LU,power_flow_DE_BE,power_flow_BE_DE,power_flow_NL_BE,power_flow_BE_NL,power_flow_UK_BE,power_flow_BE_UK,power_flow_FR_BE,power_flow_BE_FR
end

function create_DC_grid_and_Nemo_and_Alegro_interconnections(grid)
    # Add UK AC bus
    grid["bus"]["128"] = deepcopy(grid["bus"]["2"])
    grid["bus"]["128"]["bus_i"] = 128
    grid["bus"]["128"]["source_id"][2] = 128
    grid["bus"]["128"]["index"] = 128
    grid["bus"]["128"]["lat"] = 51.2965
    grid["bus"]["128"]["lon"] = 1.3192
    grid["bus"]["128"]["full_name"] = "UK00"
    grid["bus"]["128"]["full_name_kV"] = "UK00_380"
    grid["bus"]["128"]["name"] = "UK00_380"
    grid["bus"]["128"]["name_no_kV"] = "UK00"
    grid["bus"]["128"]["zone"] = "UK00"

    # Add DE AC bus
    grid["bus"]["129"] = deepcopy(grid["bus"]["2"])
    grid["bus"]["129"]["bus_i"] = 129
    grid["bus"]["129"]["source_id"][2] = 129
    grid["bus"]["129"]["index"] = 129
    grid["bus"]["129"]["lat"] = 50.867222
    grid["bus"]["129"]["lon"] = 6.474722
    grid["bus"]["129"]["full_name"] = "DE00"
    grid["bus"]["129"]["full_name_kV"] = "DE00_380"
    grid["bus"]["129"]["name"] = "DE00_380"
    grid["bus"]["129"]["name_no_kV"] = "DE00"
    grid["bus"]["128"]["zone"] = "DE00"

    # 498 gen in total before energy island
    # 67 loads in total before energy island
    n_gen = 496
    n_load = 67

    grid["gen"]["497"] = deepcopy(grid["gen"]["1"])
    grid["gen"]["497"]["source_id"][2] = 497
    grid["gen"]["497"]["index"] = 497
    grid["gen"]["497"]["pmax"] = 10.5
    grid["gen"]["497"]["pd"] = 1.05
    grid["gen"]["497"]["installed_capacity"] = 10.5
    grid["gen"]["497"]["mbase"] = 100.0
    grid["gen"]["497"]["substation_short_name"] = "UK00"
    grid["gen"]["497"]["substation_short_name_kV"] = "UK00_380"
    grid["gen"]["497"]["substation_full_name"] = "UK00"
    grid["gen"]["497"]["substation_full_name_kV"] = "UK00_380"
    grid["gen"]["497"]["substation"] = "UK00"
    grid["gen"]["497"]["name"] = "NEMO_Link"
    grid["gen"]["497"]["gen_bus"] = 128
    grid["gen"]["497"]["zone"] = "UK00"
    grid["gen"]["497"]["neighbouring"] = true

    grid["gen"]["498"] = deepcopy(grid["gen"]["1"])
    grid["gen"]["498"]["source_id"][2] = 498
    grid["gen"]["498"]["index"] = 498
    grid["gen"]["498"]["pmax"] = 10.5
    grid["gen"]["498"]["pd"] = 1.05
    grid["gen"]["498"]["installed_capacity"] = 10.5
    grid["gen"]["498"]["mbase"] = 100.0
    grid["gen"]["498"]["substation_short_name"] = "DE00"
    grid["gen"]["498"]["substation_short_name_kV"] = "DE00_380"
    grid["gen"]["498"]["substation_full_name"] = "DE00"
    grid["gen"]["498"]["substation_full_name_kV"] = "DE00_380"
    grid["gen"]["498"]["substation"] = "DE00"
    grid["gen"]["498"]["name"] = "Alegro_Link"
    grid["gen"]["498"]["gen_bus"] = 129
    grid["gen"]["498"]["zone"] = "DE00"
    grid["gen"]["498"]["neighbouring"] = true

    # Adding VOLL generators
    #grid["gen"]["499"] = deepcopy(grid["gen"]["1"])
    #grid["gen"]["499"]["source_id"][2] = 499
    #grid["gen"]["499"]["index"] = 499
    #grid["gen"]["499"]["pmax"] = 10.5
    #grid["gen"]["499"]["pd"] = 1.05
    #grid["gen"]["499"]["installed_capacity"] = 10.5
    #grid["gen"]["499"]["mbase"] = 100.0
    #grid["gen"]["499"]["substation_short_name"] = "UK00"
    #grid["gen"]["499"]["substation_short_name_kV"] = "UK00_380"
    #grid["gen"]["499"]["substation_full_name"] = "UK00"
    #grid["gen"]["499"]["substation_full_name_kV"] = "UK00_380"
    #grid["gen"]["499"]["substation"] = "UK00"
    #grid["gen"]["499"]["name"] = "NEMO_Link"
    #grid["gen"]["499"]["gen_bus"] = 128
    #grid["gen"]["499"]["type"] = "VOLL"
    #grid["gen"]["499"]["zone"] = "UK00"
    #grid["gen"]["499"]["neighbouring"] = true
    #
    #grid["gen"]["500"] = deepcopy(grid["gen"]["1"])
    #grid["gen"]["500"]["source_id"][2] = 500
    #grid["gen"]["500"]["index"] = 500
    #grid["gen"]["500"]["pmax"] = 10.5
    #grid["gen"]["500"]["pd"] = 1.05
    #grid["gen"]["500"]["installed_capacity"] = 10.5
    #grid["gen"]["500"]["mbase"] = 100.0
    #grid["gen"]["500"]["substation_short_name"] = "DE00"
    #grid["gen"]["500"]["substation_short_name_kV"] = "DE00_380"
    #grid["gen"]["500"]["substation_full_name"] = "DE00"
    #grid["gen"]["500"]["substation_full_name_kV"] = "DE00_380"
    #grid["gen"]["500"]["substation"] = "DE00"
    #grid["gen"]["500"]["name"] = "Alegro_Link"
    #grid["gen"]["500"]["gen_bus"] = 129
    #grid["gen"]["500"]["type"] = "VOLL"
    #grid["gen"]["500"]["zone"] = "DE00"
    #grid["gen"]["500"]["neighbouring"] = true

    # Adding and assigning generator values
    gen_costs,inertia_constants,emission_factor_CO2,start_up_cost,emission_factor_NOx,emission_factor_SOx = gen_values()
    assigning_gen_values(grid)

   # Adding loads
    # UK
    grid["load"]["68"] = deepcopy(grid["load"]["1"])
    grid["load"]["68"]["load_bus"] = 128
    grid["load"]["68"]["source_id"][2] = 128 
    grid["load"]["68"]["pd"] = 1.05
    grid["load"]["68"]["pmax"] = 10.5
    grid["load"]["68"]["qd"] = 10.5/2
    grid["load"]["68"]["qmax"] = 10.5/2
    grid["load"]["68"]["zone"] = "UK00"
    grid["load"]["68"]["index"] = 68
    grid["load"]["68"]["power_portion"] = 0.0 #Only for interconnections
    grid["load"]["68"]["name"] = "UK00_380"
    grid["load"]["68"]["name_no_kV"] = "UK00"
    grid["load"]["68"]["full_name"] = "UK00"
    grid["load"]["68"]["full_name_kV"] = "UK00_380"
    grid["load"]["68"]["neighbouring"] = true

    # DE
    grid["load"]["69"] = deepcopy(grid["load"]["1"])
    grid["load"]["69"]["load_bus"] = 129
    grid["load"]["69"]["source_id"][2] = 129
    grid["load"]["69"]["pd"] = 1.05
    grid["load"]["69"]["pmax"] = 10.5
    grid["load"]["69"]["qd"] = 10.5/20
    grid["load"]["69"]["qmax"] = 10.5/20
    grid["load"]["69"]["zone"] = "DE00"
    grid["load"]["69"]["index"] = 69
    grid["load"]["69"]["power_portion"] = 0.0 #Only for interconnections
    grid["load"]["69"]["name"] = "DE00_380"
    grid["load"]["69"]["name_no_kV"] = "DE00"
    grid["load"]["69"]["full_name"] = "DE00"
    grid["load"]["69"]["full_name_kV"] = "DE00_380"
    grid["load"]["69"]["neighbouring"] = true

    # Add DC grid
    grid["busdc"] = Dict{String,Any}()
    grid["convdc"] = Dict{String,Any}()
    grid["branchdc"] = Dict{String,Any}()
    
    # Add DC buses
    for i in 1:4
        grid["busdc"]["$i"] = deepcopy(North_sea_grid["busdc"]["1"])
        grid["busdc"]["$i"]["source_id"][2] = i
        grid["busdc"]["$i"]["busdc_i"] = i
        grid["busdc"]["$i"]["index"] = i
    end
    grid["busdc"]["1"]["bus_name"] = "BE_NEMO"
    grid["busdc"]["2"]["bus_name"] = "BE_ALEGRO"
    grid["busdc"]["3"]["bus_name"] = "UK_NEMO"
    grid["busdc"]["4"]["bus_name"] = "DE_ALEGRO"

    #Zeebrugge
    grid["busdc"]["1"]["lat"] = 51.33 
    grid["busdc"]["1"]["lon"] = 3.20
    
    #Richborough
    grid["busdc"]["3"]["lat"] = 51.30
    grid["busdc"]["3"]["lon"] = 1.33

    # Lixhe
    grid["busdc"]["2"]["lat"] = 50.75
    grid["busdc"]["2"]["lon"] = 5.68

    # Oberzier
    grid["busdc"]["4"]["lat"] = 50.87
    grid["busdc"]["4"]["lon"] = 6.47

    
    # Add HVDC converters
    for i in 1:4
        grid["convdc"]["$i"] = deepcopy(North_sea_grid["convdc"]["1"])
        grid["convdc"]["$i"]["source_id"][2] = i
        grid["convdc"]["$i"]["busdc_i"] = i
        grid["convdc"]["$i"]["index"] = i
        grid["convdc"]["$i"]["Pacmax"] = 15.0
        grid["convdc"]["$i"]["Pacmin"] = -15.0
        grid["convdc"]["$i"]["status"] = 1
        grid["convdc"]["$i"]["Pacrated"] = 15.0
    end
    grid["convdc"]["1"]["busac_i"] = 28 # NEMO substation
    grid["convdc"]["2"]["busac_i"] = 29 # Lixhe 380
    grid["convdc"]["3"]["busac_i"] = 128
    grid["convdc"]["4"]["busac_i"] = 129


    # Add HVDC links
    for i in 1:2
        grid["branchdc"]["$i"] = deepcopy(North_sea_grid["branchdc"]["1"])
        grid["branchdc"]["$i"]["source_id"][2] = i
        grid["branchdc"]["$i"]["fbusdc"] = i
        grid["branchdc"]["$i"]["index"] = i
        grid["branchdc"]["$i"]["interconnector"] = true
        grid["branchdc"]["$i"]["rateA"] = 14.0
        grid["branchdc"]["$i"]["rateB"] = 14.0
        grid["branchdc"]["$i"]["rateC"] = 14.0
    end
    grid["branchdc"]["1"]["tbusdc"] = 3
    grid["branchdc"]["2"]["tbusdc"] = 4
    grid["branchdc"]["1"]["HVDC_link"] = "NEMO"
    grid["branchdc"]["2"]["HVDC_link"] = "ALEGRO"    
end

function fix_load_BE(grid,hour,load_BE_series)
    for (l_id,l) in grid["load"]
        if !haskey(l,"neighbouring")
            l["pd"] = load_BE_series[hour]*l["power_portion"]/100 #pu
        end 
    end
end

function fix_hourly_loads_and_gen_interconnections(grid,hour) # -> doing nothing
    for (l_id,l) in grid["load"]
        if l["zone"] == "UK00" 
            l["pmax"] = deepcopy(flow_BE_UK[hour]/100) #pu
            l["pd"] = deepcopy(flow_BE_UK[hour]/100) #pu
        elseif l["zone"] == "DE00"
            l["pd"] = flow_BE_DE[hour]/100 #pu
        elseif l["zone"] == "LU00"
            l["pd"] = flow_BE_LU[hour]/100 #pu
        elseif l["zone"] == "NL00"
            l["pd"] = flow_BE_NL[hour]/100 #pu          
        elseif l["zone"] == "FR00"
            l["pd"] = flow_BE_FR[hour]/100 #pu            
        end
    end
    
    #for (l_id,l) in grid["gen"]
    #    if l["zone"] == "UK00" && l["type"] != "VOLL"
    #        print(l_id,"\n")
    #        l["pmax"] = deepcopy(flow_UK_BE[hour]/100) #pu
    #        #l["pmin"] = deepcopy(l["pmax"])
    #    elseif l["zone"] == "DE00"
    #        l["pmax"] = deepcopy(flow_DE_BE[hour]/100) #pu
    #        #l["pmin"] = deepcopy(l["pmax"])
    #    elseif l["zone"] == "LU00"
    #        l["pmax"] = deepcopy(flow_LU_BE[hour]/100) #pu
    #        #l["pmin"] = deepcopy(l["pmax"])
    #    elseif l["zone"] == "NL00"
    #        l["pmax"] = flow_NL_BE[hour]/100 #pu
    #        #l["pmin"] = deepcopy(l["pmax"])     
    #    elseif l["zone"] == "FR00"
    #        l["pmax"] = flow_FR_BE[hour]/100 #pu
    #        #l["pmin"] = deepcopy(l["pmax"])     
    #    end 
    #end    
end

function fix_RES_time_series(grid,hour,wind_onshore_series,wind_offshore_series,solar_pv_series)
    for (g_id,g) in grid["gen"]
        if g["type"] == "Onshore Wind" 
            g["pmax"] = g["installed_capacity"]*wind_onshore_series[hour] #pu
        elseif g["type"] == "Offshore Wind" 
            g["pmax"] = g["installed_capacity"]*wind_offshore_series[hour] #pu
        elseif g["type"] == "Onshore Wind" 
            g["pmax"] = g["installed_capacity"]*solar_pv_series[hour] #pu
        end
    end
end

function hourly_opf_BE(grid,number_of_hours,load_series_BE,wind_onshore, wind_offshore, solar_pv)
    results = Dict()
    grid_hour = Dict()
    hourly_grid = deepcopy(grid)
    for hour in 1:number_of_hours
        #fix_load_BE(hourly_grid,load_series_BE,hour)
        for (l_id,l) in hourly_grid["load"]
            if !haskey(l,"neighbouring")
                l["pd"] = load_BE[hour]*l["power_portion"]/100 #pu
            end 
        end
        fix_hourly_loads_and_gen_interconnections(hourly_grid,hour)
        fix_RES_time_series(hourly_grid,hour,wind_onshore, wind_offshore, solar_pv)
        hourly_results = deepcopy(_PMACDC.run_acdcopf(hourly_grid, DCPPowerModel, Gurobi.Optimizer; setting = s))
        results["$hour"] = deepcopy(hourly_results)
        grid_hour["$hour"] = deepcopy(hourly_grid)
    end
    return results#, grid_hour
end

function hourly_opf_BE_no_interconnections(grid,number_of_hours,load_series_BE,wind_onshore, wind_offshore, solar_pv)
    results = Dict()
    grid_hour = Dict()
    hourly_grid = deepcopy(grid)
    for hour in 1:number_of_hours
        #fix_load_BE(hourly_grid,load_series_BE,hour)
        for (l_id,l) in hourly_grid["load"]
            if !haskey(l,"neighbouring")
                l["pd"] = load_BE[hour]*l["power_portion"]/100 #pu
            end 
        end
        #fix_hourly_loads_and_gen_interconnections(hourly_grid,hour)
        fix_RES_time_series(hourly_grid,hour,wind_onshore, wind_offshore, solar_pv)
        hourly_results = deepcopy(_PMACDC.run_acdcopf(hourly_grid, DCPPowerModel, Gurobi.Optimizer; setting = s))
        results["$hour"] = deepcopy(hourly_results)
        grid_hour["$hour"] = deepcopy(hourly_grid)
    end
    return results, grid_hour
end




function sanity_check(power_flow_BE_DE,power_flow_DE_BE,power_flow_UK_BE,power_flow_BE_UK,power_flow_LU_BE,power_flow_BE_LU,power_flow_NL_BE,power_flow_BE_NL,power_flow_FR_BE,power_flow_BE_FR,number_of_hours)
    flow_BE_DE = []
    flow_DE_BE = []
    flow_UK_BE = []
    flow_BE_UK = []
    flow_LU_BE = []
    flow_BE_LU = []
    flow_NL_BE = []
    flow_BE_NL = []
    flow_FR_BE = []
    flow_BE_FR = []
    for i in 1:number_of_hours
        if ismissing(power_flow_DE_BE[i])
            power_flow_DE_BE[i] = deepcopy(0.0)
        end
        if ismissing(power_flow_BE_DE[i])
            power_flow_BE_DE[i] = deepcopy(0.0)
        end
        if ismissing(power_flow_UK_BE[i])
            power_flow_UK_BE[i] = deepcopy(0.0)
        end
        if ismissing(power_flow_BE_UK[i])
            power_flow_BE_UK[i] = deepcopy(0.0)
        end
        if ismissing(power_flow_LU_BE[i])
            power_flow_LU_BE[i] = deepcopy(0.0)
        end
        if ismissing(power_flow_BE_LU[i])
            power_flow_BE_LU[i] = deepcopy(0.0)
        end
        if ismissing(power_flow_NL_BE[i])
            power_flow_NL_BE[i] = deepcopy(0.0)
        end
        if ismissing(power_flow_BE_NL[i])
            power_flow_BE_NL[i] = deepcopy(0.0)
        end
        if ismissing(power_flow_FR_BE[i])
            power_flow_FR_BE[i] = deepcopy(0.0)
        end
        if ismissing(power_flow_BE_FR[i])
            power_flow_BE_FR[i] = deepcopy(0.0)
        end
        push!(flow_BE_DE,deepcopy(Float64.(power_flow_BE_DE[i])))
        push!(flow_DE_BE,deepcopy(Float64.(power_flow_DE_BE[i])))
        push!(flow_UK_BE,deepcopy(Float64.(power_flow_UK_BE[i])))
        push!(flow_BE_UK,deepcopy(Float64.(power_flow_BE_UK[i])))
        push!(flow_LU_BE,deepcopy(Float64.(power_flow_LU_BE[i])))
        push!(flow_BE_LU,deepcopy(Float64.(power_flow_BE_LU[i])))
        push!(flow_NL_BE,deepcopy(Float64.(power_flow_NL_BE[i])))
        push!(flow_BE_NL,deepcopy(Float64.(power_flow_BE_NL[i])))
        push!(flow_FR_BE,deepcopy(Float64.(power_flow_FR_BE[i])))
        push!(flow_BE_FR,deepcopy(Float64.(power_flow_BE_FR[i])))
    end
    return flow_BE_DE,flow_DE_BE,flow_UK_BE,flow_BE_UK,flow_LU_BE,flow_BE_LU,flow_NL_BE,flow_BE_NL,flow_FR_BE,flow_BE_FR
end


function add_energy_island(grid)
    # 132 buses before the energy island
    # Add Energy island #1 AC bus
    grid["bus"]["133"] = deepcopy(grid["bus"]["2"])
    grid["bus"]["133"]["bus_i"] = 133
    grid["bus"]["133"]["source_id"][2] = 133
    grid["bus"]["133"]["index"] = 133
    grid["bus"]["133"]["lat"] = 51.646504
    grid["bus"]["133"]["lon"] = 2.678687 
    grid["bus"]["133"]["full_name"] = "EI_AC_1"
    grid["bus"]["133"]["full_name_kV"] = "EI_AC_1_220"
    grid["bus"]["133"]["name"] = "EI_AC_1_220"
    grid["bus"]["133"]["name_no_kV"] = "EI_AC_1"
    grid["bus"]["133"]["zone"] = "BE01"

    #=
    # Add Energy island #2 AC bus
    grid["bus"]["133"] = deepcopy(grid["bus"]["2"])
    grid["bus"]["133"]["bus_i"] = 128
    grid["bus"]["133"]["source_id"][2] = 128
    grid["bus"]["133"]["index"] = 128
    grid["bus"]["133"]["lat"] = 51.2965
    grid["bus"]["133"]["lon"] = 1.3192
    grid["bus"]["133"]["full_name"] = "EI_AC_1"
    grid["bus"]["133"]["full_name_kV"] = "EI_AC_1_220"
    grid["bus"]["133"]["name"] = "EI_AC_1_220"
    grid["bus"]["133"]["name_no_kV"] = "EI_AC_1"
    grid["bus"]["133"]["zone"] = "BE01"
    =#

    # Add Energy island #3 AC bus
    grid["bus"]["134"] = deepcopy(grid["bus"]["2"])
    grid["bus"]["134"]["bus_i"] = 134
    grid["bus"]["134"]["source_id"][2] = 134
    grid["bus"]["134"]["index"] = 134
    grid["bus"]["134"]["lat"] = 51.646504
    grid["bus"]["134"]["lon"] = 2.678687 
    grid["bus"]["134"]["full_name"] = "EI_AC_2"
    grid["bus"]["134"]["full_name_kV"] = "EI_AC_2_220"
    grid["bus"]["134"]["name"] = "EI_AC_2_220"
    grid["bus"]["134"]["name_no_kV"] = "EI_AC_2"
    grid["bus"]["134"]["zone"] = "BE01"

    #=
    # Add Energy island #4 AC bus
    grid["bus"]["133"] = deepcopy(grid["bus"]["2"])
    grid["bus"]["133"]["bus_i"] = 128
    grid["bus"]["133"]["source_id"][2] = 128
    grid["bus"]["133"]["index"] = 128
    grid["bus"]["133"]["lat"] = 51.2965
    grid["bus"]["133"]["lon"] = 1.3192
    grid["bus"]["133"]["full_name"] = "EI_AC_1"
    grid["bus"]["133"]["full_name_kV"] = "EI_AC_1_220"
    grid["bus"]["133"]["name"] = "EI_AC_1_220"
    grid["bus"]["133"]["name_no_kV"] = "EI_AC_1"
    grid["bus"]["133"]["zone"] = "BE01"
    =#

    
    # 501 gen in total before energy island
    # 72 loads in total before energy island
    n_gen = 501
    n_load = 72
    
    grid["gen"]["502"] = deepcopy(grid["gen"]["60"])
    grid["gen"]["502"]["source_id"][2] = 502
    grid["gen"]["502"]["index"] = 502
    #grid["gen"]["502"]["pmax"] = 21.0
    #grid["gen"]["502"]["qmax"] = 3.0
    #grid["gen"]["502"]["qmin"] = - 3.0
    #grid["gen"]["502"]["pd"] = 1.05
    #grid["gen"]["502"]["installed_capacity"] = 99.0
    grid["gen"]["502"]["mbase"] = 100.0
    grid["gen"]["502"]["substation_short_name"] = "EI_AC_1"
    grid["gen"]["502"]["substation_short_name_kV"] = "EI_AC_1_220"
    grid["gen"]["502"]["substation_full_name"] = "EI_AC_1"
    grid["gen"]["502"]["substation_full_name_kV"] = "EI_AC_1_220"
    grid["gen"]["502"]["substation"] = "EI_AC_1_220"
    grid["gen"]["502"]["name"] = "OFW_EI_AC"
    grid["gen"]["502"]["gen_bus"] = 133
    grid["gen"]["502"]["zone"] = "BE00"

    grid["gen"]["503"] = deepcopy(grid["gen"]["60"])
    grid["gen"]["503"]["source_id"][2] = 503
    grid["gen"]["503"]["index"] = 503
    #grid["gen"]["503"]["pmax"] = 14.0
    #grid["gen"]["503"]["qmax"] = 3.0
    #grid["gen"]["503"]["qmin"] = - 3.0
    #grid["gen"]["503"]["pd"] = 1.05
    #grid["gen"]["503"]["installed_capacity"] = 99.0
    grid["gen"]["503"]["mbase"] = 100.0
    grid["gen"]["503"]["substation_short_name"] = "EI_AC_2"
    grid["gen"]["503"]["substation_short_name_kV"] = "EI_AC_2_220"
    grid["gen"]["503"]["substation_full_name"] = "EI_AC_2"
    grid["gen"]["503"]["substation_full_name_kV"] = "EI_AC_2_220"
    grid["gen"]["503"]["substation"] = "EI_AC_2_220"
    grid["gen"]["503"]["name"] = "OFW_EI_HVDC"
    grid["gen"]["503"]["gen_bus"] = 134
    grid["gen"]["503"]["zone"] = "BE00"

    # 188 branches in total before energy island
    n_branches = 188
    for i in 1:7
        grid["branch"]["$(n_branches+i)"] = deepcopy(BE_grid["branch"]["1"])
        grid["branch"]["$(n_branches+i)"]["source_id"][2] = deepcopy(n_branches+i)
        grid["branch"]["$(n_branches+i)"]["interconnection"] = true
        grid["branch"]["$(n_branches+i)"]["index"] = deepcopy(n_branches+i)
        grid["branch"]["$(n_branches+i)"]["rate_a"] = 4.0
        delete!(grid["branch"]["$(n_branches+i)"],"f_bus_name_kV")
        delete!(grid["branch"]["$(n_branches+i)"],"t_bus_name_kV")
        delete!(grid["branch"]["$(n_branches+i)"],"f_bus_full_name_kV")
        delete!(grid["branch"]["$(n_branches+i)"],"t_bus_full_name_kV")
        delete!(grid["branch"]["$(n_branches+i)"],"f_bus_full_name")
        delete!(grid["branch"]["$(n_branches+i)"],"t_bus_full_name")
        delete!(grid["branch"]["$(n_branches+i)"],"f_bus_name")
        delete!(grid["branch"]["$(n_branches+i)"],"t_bus_name")
    end
    # AC connections to BE
    for i in 1:6
        grid["branch"]["$(n_branches+i)"]["f_bus"] = 133 # EI_AC_1_220
        grid["branch"]["$(n_branches+i)"]["t_bus"] = 26 # GEZELLE_380 
        grid["branch"]["$(n_branches+i)"]["f_bus_full_name_kV"] = "EI_AC_1_220"
        grid["branch"]["$(n_branches+i)"]["f_bus_name_kV"] = "EI_AC_1_220"
        grid["branch"]["$(n_branches+i)"]["f_bus_full_name"] = "EI_AC_1"
        grid["branch"]["$(n_branches+i)"]["f_bus_name"] = "EI_AC_1"
        grid["branch"]["$(n_branches+i)"]["t_bus_full_name_kV"] = "GEZELLE_380"
        grid["branch"]["$(n_branches+i)"]["t_bus_name_kV"] = "GEZEL_380"
        grid["branch"]["$(n_branches+i)"]["t_bus_full_name"] = "GEZELLE"
        grid["branch"]["$(n_branches+i)"]["t_bus_name"] = "GEZEL"
    end
    # AC connections withing the energy island -> this is the switch
    for i in 7:7
        grid["branch"]["$(n_branches+i)"]["rate_a"] = 99.99
        grid["branch"]["$(n_branches+i)"]["f_bus"] = 133 # EI_AC_1_220
        grid["branch"]["$(n_branches+i)"]["t_bus"] = 134 # EI_AC_2_220 
        grid["branch"]["$(n_branches+i)"]["f_bus_full_name_kV"] = "EI_AC_1_220"
        grid["branch"]["$(n_branches+i)"]["f_bus_name_kV"] = "EI_AC_1_220"
        grid["branch"]["$(n_branches+i)"]["f_bus_full_name"] = "EI_AC_1"
        grid["branch"]["$(n_branches+i)"]["f_bus_name"] = "EI_AC_1"
        grid["branch"]["$(n_branches+i)"]["t_bus_full_name_kV"] = "EI_AC_2_220"
        grid["branch"]["$(n_branches+i)"]["t_bus_name_kV"] = "EI_AC_2_220"
        grid["branch"]["$(n_branches+i)"]["t_bus_full_name"] = "EI_AC_2"
        grid["branch"]["$(n_branches+i)"]["t_bus_name"] = "EI_AC_2"
    end

    ############## DC part ##################
    # 4 DC buses before the energy island
    # Add Energy island #1 DC bus
    grid["busdc"]["5"] = deepcopy(grid["busdc"]["1"])
    grid["busdc"]["5"]["busdc_i"] = 5
    grid["busdc"]["5"]["source_id"][2] = 5
    grid["busdc"]["5"]["index"] = 5
    grid["busdc"]["5"]["lat"] = 51.6468
    grid["busdc"]["5"]["lon"] = 2.778687 
    grid["busdc"]["5"]["full_name"] = "EI_DC_1"
    grid["busdc"]["5"]["full_name_kV"] = "EI_DC_1_525"
    grid["busdc"]["5"]["name"] = "EI_DC_1_525"
    grid["busdc"]["5"]["name_no_kV"] = "EI_DC_1"
    grid["busdc"]["5"]["zone"] = "BE01"
    grid["busdc"]["5"]["basekVdc"] = 525

    # Add Energy island #2 DC bus (DC switchyard)
    grid["busdc"]["6"] = deepcopy(grid["busdc"]["1"])
    grid["busdc"]["6"]["busdc_i"] = 6
    grid["busdc"]["6"]["source_id"][2] = 6
    grid["busdc"]["6"]["index"] = 6
    grid["busdc"]["6"]["lat"] = 51.780669
    grid["busdc"]["6"]["lon"] = 3.006469
    grid["busdc"]["6"]["full_name"] = "EI_DC_1"
    grid["busdc"]["6"]["full_name_kV"] = "EI_DC_1_525"
    grid["busdc"]["6"]["name"] = "EI_DC_1_525"
    grid["busdc"]["6"]["name_no_kV"] = "EI_DC_1"
    grid["busdc"]["6"]["zone"] = "BE01"
    grid["busdc"]["6"]["basekVdc"] = 525

    # Add UK #2 DC bus 
    grid["busdc"]["7"] = deepcopy(grid["busdc"]["1"])
    grid["busdc"]["7"]["busdc_i"] = 7
    grid["busdc"]["7"]["source_id"][2] = 7
    grid["busdc"]["7"]["index"] = 7
    grid["busdc"]["7"]["lat"] = 51.888354
    grid["busdc"]["7"]["lon"] = 1.209372
    grid["busdc"]["7"]["full_name"] = "UK_EI_DC_2"
    grid["busdc"]["7"]["full_name_kV"] = "UK_EI_DC_2_525"
    grid["busdc"]["7"]["name"] = "UK_EI_DC_2_525"
    grid["busdc"]["7"]["name_no_kV"] = "UK_EI_DC_2"
    grid["busdc"]["7"]["zone"] = "BE01"
    grid["busdc"]["7"]["basekVdc"] = 525

    # Add Gezelle DC bus
    grid["busdc"]["8"] = deepcopy(grid["busdc"]["1"])
    grid["busdc"]["8"]["busdc_i"] = 8
    grid["busdc"]["8"]["source_id"][2] = 8
    grid["busdc"]["8"]["index"] = 8
    grid["busdc"]["8"]["lat"] = 51.2747
    grid["busdc"]["8"]["lon"] = 3.22923
    grid["busdc"]["8"]["full_name"] = "GEZELLE_EI_DC_1"
    grid["busdc"]["8"]["full_name_kV"] = "GEZELLE_EI_DC_1_525"
    grid["busdc"]["8"]["name"] = "GEZEL_EI_DC_1_525"
    grid["busdc"]["8"]["name_no_kV"] = "GEZEL_EI_DC_1"
    grid["busdc"]["8"]["zone"] = "BE01"
    grid["busdc"]["8"]["basekVdc"] = 525

    # Adding 3 converters for the energy island
    n_conv_dc = 4
    for i in 1:3
        grid["convdc"]["$(n_conv_dc+i)"] = deepcopy(grid["convdc"]["1"])
        grid["convdc"]["$(n_conv_dc+i)"]["Imax"] = 2.5
        grid["convdc"]["$(n_conv_dc+i)"]["source_id"][2] = deepcopy(n_conv_dc+i)
        grid["convdc"]["$(n_conv_dc+i)"]["index"] = deepcopy(n_conv_dc+i)
    end

    grid["convdc"]["5"]["busdc_i"] = 5
    grid["convdc"]["5"]["busac_i"] = 134
    grid["convdc"]["5"]["Pacmax"] = 20.0
    grid["convdc"]["5"]["Pacmin"] = - 20.0
    grid["convdc"]["5"]["Pacrated"] = 20.0

    grid["convdc"]["6"]["busdc_i"] = 7
    grid["convdc"]["6"]["busac_i"] = 128
    grid["convdc"]["6"]["Pacmax"] = 14.0
    grid["convdc"]["6"]["Pacmin"] = - 14.0
    grid["convdc"]["6"]["Pacrated"] = 14.0

    grid["convdc"]["7"]["busdc_i"] = 8
    grid["convdc"]["7"]["busac_i"] = 26
    grid["convdc"]["7"]["Pacmax"] = 20.0
    grid["convdc"]["7"]["Pacmin"] = - 20.0
    grid["convdc"]["7"]["Pacrated"] = 20.0

    # Adding the DC branches
    n_branch_dc = 2
    for i in 1:3
        grid["branchdc"]["$(n_branch_dc+i)"] = deepcopy(grid["branchdc"]["1"])
        grid["branchdc"]["$(n_branch_dc+i)"]["source_id"][2] = deepcopy(n_branch_dc+i)
        grid["branchdc"]["$(n_branch_dc+i)"]["index"] = deepcopy(n_branch_dc+i)
    end
    grid["branchdc"]["3"]["r"] = 0.1
    grid["branchdc"]["3"]["rateA"] = 20.0
    grid["branchdc"]["3"]["rateB"] = 20.0
    grid["branchdc"]["3"]["rateC"] = 20.0
    grid["branchdc"]["3"]["fbusdc"] = 5
    grid["branchdc"]["3"]["tbusdc"] = 6
    grid["branchdc"]["3"]["HVDC_link"] = "EI -> DC Switchyard" 

    grid["branchdc"]["4"]["r"] = 0.1
    grid["branchdc"]["4"]["rateA"] = 14.0
    grid["branchdc"]["4"]["rateB"] = 14.0
    grid["branchdc"]["4"]["rateC"] = 14.0
    grid["branchdc"]["4"]["fbusdc"] = 6
    grid["branchdc"]["4"]["tbusdc"] = 7
    grid["branchdc"]["4"]["HVDC_link"] = "DC Switchyard -> UK" 

    grid["branchdc"]["5"]["r"] = 0.1
    grid["branchdc"]["5"]["rateA"] = 20.0
    grid["branchdc"]["5"]["rateB"] = 20.0
    grid["branchdc"]["5"]["rateC"] = 20.0
    grid["branchdc"]["5"]["fbusdc"] = 6
    grid["branchdc"]["5"]["tbusdc"] = 8
    grid["branchdc"]["5"]["HVDC_link"] = "DC Switchyard -> Gezelle" 

end

