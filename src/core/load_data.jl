###############################################################
#  load_data.jl
#############################################################################

function load_res_data()
 ## RES TIME SERIES as feather files (~ 350 MB)
 # wind_onshore_file_link = "https://zenodo.org/record/3702418/files/PECD-MAF2019-wide-WindOnshore.feather?download=1"
 # wind_offhore_file_link = "https://zenodo.org/record/3702418/files/PECD-MAF2019-wide-WindOffshore.feather?download=1"
 # pv_file_link = "https://zenodo.org/record/3702418/files/PECD-MAF2019-wide-PV.feather?download=1" 
 # If files are saved locally under folder scenarios
 file_wind_onshore  = join("/Users/giacomobastianel/Desktop/tyndpdata/scenarios/PECD-MAF2019-wide-WindOnshore.feather")
 file_wind_offshore = join("/Users/giacomobastianel/Desktop/tyndpdata/scenarios/PECD-MAF2019-wide-WindOffshore.feather")
 file_pv            = join("/Users/giacomobastianel/Desktop/tyndpdata/scenarios/PECD-MAF2019-wide-PV.feather")                 
 
 pv = Feather.read(file_pv) 
 wind_onshore = Feather.read(file_wind_onshore)
 wind_offshore = Feather.read(file_wind_offshore)
 # Alternatively one can use to download data: (this might take a couple of minutes)
 # pv = Feather.read(download(pv_file_link))
 # wind_onshore = Feather.read(download(wind_onshore_file_link))
 # wind_offshore = Feather.read(download(wind_offshore_file_link))

 return pv, wind_onshore, wind_offshore
end

function load_res_data_Elia()
    # If files are saved locally under folder scenarios
    file_wind  = "/Users/giacomobastianel/Desktop/Belgian_grid_data/wind.csv"
    #file_wind_offshore = "/Users/giacomobastianel/Desktop/Belgian_grid_data/Offshore_wind_generation.csv"
    file_pv            = "/Users/giacomobastianel/Desktop/Belgian_grid_data/solar_pv.csv"              
    file_load  = "/Users/giacomobastianel/Desktop/Belgian_grid_data/load_Elia.csv"
    
    x_pv = DataFrame(CSV.File(file_pv))
    x_wind = DataFrame(CSV.File(file_wind))
    x_load = DataFrame(CSV.File(file_load))

    length(x_wind[:,3])

    length(x_pv[:,1][1])#[1:4]
    x_pv[:,1][1][15:19] == "00.00"


    x_pv[:,5][1000]

    a = []
    for i in 1:length(x_pv[:,1])
        push!(a,x_pv[:,1][i])
    end

    pv = []
    count_ = 0
    for i in 1:length(x_pv[:,1])
        if x_pv[:,1][i][1:4] == "2017" && x_pv[:,1][i][15:19] == "00:00"
            count_ += 1
        end
    end


   
    return pv, wind_onshore, wind_offshore
end

function make_res_time_series(wind_onshore, wind_offshore, pv, zone,year)

    print("==============GENERATE TIME SERIES ", zone, " =======================","\n")
    wind_onshore_zone = []
    wind_offshore_zone = []
    solar_pv_zone = []
    corrected_year = year - 1981 + 4

    #wind_on = []
    #push!(wind_on,wind_onshore[!,5][1])


    for i in 1:1217640#length(wind_onshore[!,1])
        if wind_onshore[!,1][i] == zone
        push!(wind_onshore_zone, wind_onshore[!,corrected_year][i])
        end
        if wind_offshore[!,1][i] == zone
            push!(wind_offshore_zone, wind_offshore[!,corrected_year][i])
        end
        if pv[!,1][i] == zone
            push!(solar_pv_zone, pv[!,corrected_year][i])
        end   
    end

    return wind_onshore_zone, wind_offshore_zone, solar_pv_zone
end

function add_gen_types_North_Sea(data)
    l = [3,4,6]
    for i in l
     data["gen"]["$i"]["type"] = "Offshore wind"
    end
    for (i_id,i) in data["gen"]
        if !haskey(i,"type")
            i["type"] = "Conventional"
        end
    end
end

function adjusting_load_and_generators(data,wind_onshore, wind_offshore, pv,number_of_hours)
    for (i_id,i) in data["gen"]
        i["pmax_t"] = []
        for l in 1:number_of_hours
            if i["type"] == "Offshore Wind" || i["type"] == "Onshore Wind" || i["type"] == "Solar PV"
              push!(i["pmax_t"],deepcopy(i["pmax"]*wind_offshore[l]))
            else
              push!(i["pmax_t"],deepcopy(i["pmax"]))
            end
        end
        i["pmin_t"] = ones(number_of_hours)*i["pmin"] 
    end
    #for (i_id,i) in data["load"]
    #    i["pd"] = ones(number_of_hours)*i["pd"] 
    #    i["qd"] = ones(number_of_hours)*i["qd"] 
    #end          
end


function adjusting_load_and_generators_load_curtailment(data,wind_onshore, wind_offshore, pv,number_of_hours)
    for (i_id,i) in data["gen"]
        i["pmax_t"] = []
        for l in 1:number_of_hours
            if i["type"] == "Offshore Wind" || i["type"] == "Onshore Wind" || i["type"] == "Solar PV"
              push!(i["pmax_t"],deepcopy(i["pmax"]*wind_offshore[l]))
            else
              push!(i["pmax_t"],deepcopy(i["pmax"]))
            end
            if i["type"] == "Offshore Wind" || i["type"] == "Onshore Wind" || i["type"] == "Solar PV"
                i["pmin_t"] = deepcopy(i["pmax_t"])
            end
        end
    end
    #for (i_id,i) in data["load"]
    #    i["pd"] = ones(number_of_hours)*i["pd"] 
    #    i["qd"] = ones(number_of_hours)*i["qd"] 
    #end          
end


function adjusting_load_and_generators_PM(data,scenario,year,hour_start,wind_onshore, wind_offshore, pv,number_of_hours)
    for l in 1:number_of_hours
        for (i_id,i) in data["$l"]["gen"]
            if i["type"] == "Offshore wind" || i["type"] == "Onshore wind" || i["type"] == "Solar PV"
              i["pmax"] = i["pmax"]*wind_offshore[l]
            end
        end
        load_file = joinpath("/Users/giacomobastianel/Desktop/tyndpdata/scenarios/"*scenario*"_Demand_CY"*year*".csv")
        df = CSV.read(load_file,DataFrame)
        load_series_BE = df[!,"BE00"][hour_start:(hour_start+number_of_hours-1)]
        load_series_UK = df[!,"UK00"][hour_start:(hour_start+number_of_hours-1)]
        load_series_NL = df[!,"NL00"][hour_start:(hour_start+number_of_hours-1)]
        for (i_id,i) in data["$l"]["load"]
            if haskey(i,"zone") && i["zone"] == "BE00"
                i["pd"] = deepcopy(load_series_BE[l]/data["$l"]["baseMVA"])
            elseif haskey(i,"zone") && i["zone"] == "UK00"
                i["pd"] = deepcopy(load_series_UK[l]/data["$l"]["baseMVA"])
            elseif haskey(i,"zone") && i["zone"] == "NL00"
                i["pd"] = deepcopy(load_series_NL[l]/data["$l"]["baseMVA"])
            end
        end
    end
    return data            
end

function add_zone_North_Sea(data)
    #data["load"]["1"]["zone"] = "BE00"
    #data["load"]["2"]["zone"] = "UK00"
    #data["load"]["3"]["zone"] = "NL00"
    data["bus"]["2"]["zone"] = "UK00"
    data["bus"]["2"]["bus_name"] = "UK00"
    for i in 3:6
        data["bus"]["$i"]["zone"] = "BE00"
        data["bus"]["$i"]["bus_name"] = "BE_energy_island_"*"$i"
    end
    data["bus"]["7"]["zone"] = "NL00"
    data["bus"]["7"]["bus_name"] = "NL00"
    data["bus"]["8"]["zone"] = "BE00"
    data["bus"]["8"]["bus_name"] = "BE_NEMO"
    data["bus"]["9"]["zone"] = "UK00"
    data["bus"]["9"]["bus_name"] = "UK_NEMO"
    data["bus"]["10"]["zone"] = "BE00"
    data["bus"]["10"]["bus_name"] = "BE_offshore_wind"
    data["bus"]["11"]["zone"] = "UK00"
    data["bus"]["11"]["bus_name"] = "UK_BRITNED"
    data["bus"]["12"]["zone"] = "NL00"
    data["bus"]["12"]["bus_name"] = "NL_BRITNED"
    data["bus"]["13"]["zone"] = "NL00"
    data["bus"]["13"]["bus_name"] = "NL_Borssele_offshore_wind"
    data["bus"]["8"]["zone"] = "BE00"
    data["busdc"]["1"]["bus_name"] = "BE_energy_island_DC_1"
    data["busdc"]["1"]["zone"] = "BE00"
    data["busdc"]["2"]["bus_name"] = "UK_energy_island_DC_2"
    data["busdc"]["2"]["zone"] = "BE00"
    data["busdc"]["3"]["bus_name"] = "BE_energy_island_DC_3"
    data["busdc"]["3"]["zone"] = "BE00"
    data["busdc"]["4"]["bus_name"] = "BE_NEMO"
    data["busdc"]["4"]["zone"] = "BE00"
    data["busdc"]["5"]["bus_name"] = "UK_NEMO"
    data["busdc"]["5"]["zone"] = "UK00"
    data["busdc"]["6"]["bus_name"] = "UK_BRITNED"
    data["busdc"]["6"]["zone"] = "UK00"
    data["busdc"]["7"]["bus_name"] = "NL_BRITNED"
    data["busdc"]["7"]["zone"] = "NL00"
    for i in 1:6
        data["branch"]["$i"]["branch_name"] = "BE_energy_island_"*"$i"
    end
    data["branch"]["7"]["branch_name"] = "BE_energy_island_switchyard"
    data["branch"]["12"]["branch_name"] = "BE_DOEL-NL"
    data["branch"]["13"]["branch_name"] = "BE_VAN_EYCK-NL"
end

function add_load_series(data,scenario,year,zone,hour_start,number_of_hours)
    load_file = joinpath("/Users/giacomobastianel/Desktop/tyndpdata/scenarios/"*scenario*"_Demand_CY"*year*".csv")
    df = CSV.read(load_file,DataFrame)
    load_series = df[!,zone][hour_start:(hour_start+number_of_hours-1)]
    for (i_id,i) in data["load"]
        if haskey(i,"zone") && i["zone"] == zone
            i["pd"] = deepcopy(load_series/data["baseMVA"])
        end
    end
    return load_series
end

function add_gen_zones_North_tyndp(data)
    be = 1:10
    uk = 11:21
    offshore = 22:22
    nl = 23:31
    for (i_id,i) in data["gen"]
        i["zone"] = Dict()
    end
    for i in be
     data["gen"]["$i"]["zone"] = "BE00"
    end
    for i in uk
        data["gen"]["$i"]["zone"] = "UK00"
    end
    for i in offshore
        data["gen"]["$i"]["zone"] = "Offshore BE00"
    end
    for i in nl
        data["gen"]["$i"]["zone"] = "NL00"
    end
    data["load"]["1"]["zone"] = "BE00"
    data["load"]["2"]["zone"] = "UK00"
    data["load"]["3"]["zone"] = "NL00"

end

function add_gen_types_North_tyndp(data)
    for (i_id,i) in data["gen"]
     if i["zone"] == "BE00"
        if i["pmax"] == 59.43
            i["type"] = "Nuclear"
        elseif i["pmax"] == 29.9
            i["type"] = "Onshore Wind"
        elseif i["pmax"] == 1.86
            i["type"] = "Run-of-River"
        elseif i["pmax"] == 22.54
            i["type"] = "Offshore Wind"
        elseif i["pmax"] == 13.08
            i["type"] = "Reservoir"
        elseif i["pmax"] == 64.75
            i["type"] = "Solar PV"
        elseif i["pmax"] == 3.84
            i["type"] = "Lignite new"
        elseif i["pmax"] == 69.15
            i["type"] = "Gas CCGT new"
        elseif i["pmax"] == 4.55
            i["type"] = "Oil shale new"
        elseif i["pmax"] == 7.12
            i["type"] = "Other RES"
        end
     elseif i["zone"] == "UK00"
        if i["pmax"] == 82.56
            i["type"] = "Nuclear"
        elseif i["pmax"] == 129.37
            i["type"] = "Onshore Wind"
        elseif i["pmax"] == 19.19
            i["type"] = "Run-of-River"
        elseif i["pmax"] == 121.6
            i["type"] = "Offshore Wind"
        elseif i["pmax"] == 43.09
            i["type"] = "Reservoir"
        elseif i["pmax"] == 133.78
            i["type"] = "Solar PV"
        elseif i["pmax"] == 19
            i["type"] = "Other RES"
        elseif i["pmax"] == 398.22
            i["type"] = "Gas CCGT new"
        elseif i["pmax"] == 28.08
            i["type"] = "Oil shale new"
        elseif i["pmax"] == 45.28
            i["type"] = "Other RES"
        elseif i["pmax"] == 52.41
            i["type"] = "Hard coal new"
        end
     elseif i["zone"] == "NL00"
        if i["pmax"] == 4.86
            i["type"] = "Nuclear"
        elseif i["pmax"] == 61.9
            i["type"] = "Onshore Wind"
        elseif i["pmax"] == 0.37
            i["type"] = "Run-of-River"
        elseif i["pmax"] == 32.2
            i["type"] = "Offshore Wind"
        elseif i["pmax"] == 225.9
            i["type"] = "Solar PV"
        elseif i["pmax"] == 7.86
            i["type"] = "Lignite new"
        elseif i["pmax"] == 183.51
            i["type"] = "Gas CCGT new"
        elseif i["pmax"] == 4.15
            i["type"] = "Other RES"
        elseif i["pmax"] == 40.06
            i["type"] = "Hard coal new"
        end
     elseif i["zone"] == "Offshore BE00"
        i["type"] = "Offshore Wind"
    end
  end
end

function add_France_Germany(data)
    # 2 buses to be created -> originally 157, Germany to be left out for now
    data["bus"]["158"] = deepcopy(data["bus"]["157"])
    #data["bus"]["159"] = deepcopy(data["bus"]["157"])
    data["bus"]["158"]["zone"] = "FR00" 
    #data["bus"]["159"]["zone"] = "DE00" 
    data["bus"]["158"]["bus_i"] = 158
    #data["bus"]["159"]["bus_i"] = 159
    data["bus"]["158"]["index"] = 158 
    #data["bus"]["159"]["index"] = 159 
    data["bus"]["158"]["source_id"][2] = 158 
    #data["bus"]["159"]["source_id"][2] = 159     
    data["bus"]["158"]["bus_name"] = "France_zonal_Avelin"
    #data["bus"]["159"]["bus_name"] = "Germany_zonal_Oberzier"
    data["bus"]["158"]["lat"] = 50.866667
    data["bus"]["158"]["lon"] = 6.466667
    #data["bus"]["159"]["lat"] = 50.5406
    #data["bus"]["159"]["lon"] = 3.0825

    
    # 310 generators without France and Germany
     for i in 1:9
        l = 310 + i
        data["gen"]["$l"] = deepcopy(data["gen"]["309"])
        data["gen"]["$l"]["zone"] = "FR00"
        data["gen"]["$l"]["gen_bus"] = 158
        data["gen"]["$l"]["source_id"][2] = l
        data["gen"]["$l"]["index"] = l
     end 
     data["gen"]["310"]["type"] = "Nuclear"
     data["gen"]["310"]["pmax"] = 613.70
     data["gen"]["310"]["mbase"] = 61370

     data["gen"]["311"]["type"] = "Onshore Wind"
     data["gen"]["311"]["pmax"] = 206.45
     data["gen"]["311"]["mbase"] = 20645

     data["gen"]["312"]["type"] = "Hard coal old 1 Bio"
     data["gen"]["312"]["pmax"] = 18.16
     data["gen"]["312"]["mbase"] = 1816

     data["gen"]["313"]["type"] = "Reservoir"
     data["gen"]["313"]["pmax"] = 25.473
     data["gen"]["313"]["mbase"] = 25473

     data["gen"]["314"]["type"] = "Offshore wind"
     data["gen"]["314"]["pmax"] = 0.2
     data["gen"]["314"]["mbase"] = 20

     data["gen"]["315"]["type"] = "Solar PV"
     data["gen"]["315"]["pmax"] = 136.93
     data["gen"]["315"]["mbase"] = 13693

     data["gen"]["316"]["type"] = "Gas CCGT old"
     data["gen"]["316"]["pmax"] = 128.81
     data["gen"]["316"]["mbase"] = 12881

     data["gen"]["317"]["type"] = "Oil shale old"
     data["gen"]["317"]["pmax"] = 25.54
     data["gen"]["317"]["mbase"] = 2552

     data["gen"]["318"]["type"] = "Other RES"
     data["gen"]["318"]["pmax"] = 7.64
     data["gen"]["318"]["mbase"] = 764

     data["gen"]["319"]["type"] = "Lignite old 1 Bio"
     data["gen"]["319"]["pmax"] = 22.19
     data["gen"]["319"]["mbase"] = 2219

    for i in 1:9
        l = 310 + i
        for m in eachindex(gen_costs)
            if data["gen"]["$l"]["type"] == m
                data["gen"]["$l"]["CO2_emission"] = emission_factor_CO2[m]
                data["gen"]["$l"]["start_up_cost"] = 0 
                data["gen"]["$l"]["cost"][1] = gen_costs[m]
                data["gen"]["$l"]["ncost"] = 2
                data["gen"]["$l"]["inertia_constant"] = inertia_constants[m]
            end
        end
    end

    # 53 loads without France and Germany
    data["load"]["54"] = deepcopy(data["load"]["53"])
    data["load"]["54"]["zone"] = "FR00"
    data["load"]["54"]["load_bus"] = 158
    data["load"]["54"]["source_id"][2] = 158
    data["load"]["54"]["index"] = 54

    # 187 branches without France and Germany
    data["branch"]["188"] = deepcopy(data["branch"]["187"])
    data["branch"]["188"]["rate_a"] = 60
    data["branch"]["188"]["rate_b"] = 60
    data["branch"]["188"]["rate_c"] = 60
    data["branch"]["188"]["source_id"][2] = 188
    data["branch"]["188"]["f_bus"] = 158
    data["branch"]["188"]["t_bus"] = 24
    data["branch"]["188"]["index"] = 188 
 
end

function add_data_gen(gen_costs, emission_factor, inertia_constants, start_up_cost, data)
    for (i_id,i) in data["gen"]
        for l in eachindex(gen_costs)
              if i["type"] == l
               i["cost"] = deepcopy(gen_costs[l])
               i["CO2_emission"] = deepcopy(emission_factor[l])
               i["inertia_constant"] = deepcopy(inertia_constants[l])
               i["start_up_cost"] = deepcopy(start_up_cost[l])
              end
        end
    end
end

function prepare_data(data)
    add_gen_zones_North_tyndp(data)
    add_gen_types_North_tyndp(data)
    #adjusting_load_and_generators(data,wind_onshore_BE, wind_offshore_BE, solar_pv_BE,number_of_hours)
    add_load_series(data,scenario,year,"BE00",1,number_of_hours)
    add_load_series(data,scenario,year,"UK00",1,number_of_hours)
    add_load_series(data,scenario,year,"NL00",1,number_of_hours)
    ntcs, nodes, arcs, capacity, demand, gen_types, gen_costs, emission_factor, inertia_constants, start_up_cost, node_positions = get_grid_data(scenario)
    add_data_gen(gen_costs, emission_factor, inertia_constants, start_up_cost, data)
end

function attach_North_Sea_grid_to_BE(north_sea,data,gen_costs)
    
    i = 144
    for l in 1:length(North_sea_grid["bus"])
        n = i+l
        data["bus"]["$n"] = deepcopy(North_sea_grid["bus"]["$l"])
        data["bus"]["$n"]["bus_i"] = deepcopy(n)
        data["bus"]["$n"]["index"] = deepcopy(n)
        data["bus"]["$n"]["source_id"][2] = deepcopy(n)
    end
    data["bus"]["145"]["bus_type"] = 2
    
    data["busdc"] = deepcopy(North_sea_grid["busdc"])

    m = 171 #length(data["branch"])
    for o in 1:length(North_sea_grid["branch"])
        p = m+o
        data["branch"]["$p"] = deepcopy(North_sea_grid["branch"]["$o"])
        data["branch"]["$p"]["f_bus"] = data["branch"]["$p"]["f_bus"] + 144
        data["branch"]["$p"]["t_bus"] = data["branch"]["$p"]["t_bus"] + 144 # num buses
        data["branch"]["$p"]["index"] = deepcopy(p)
        data["branch"]["$p"]["source_id"][2] = deepcopy(p)
        data["branch"]["$p"]["br_r"] = data["branch"]["$p"]["br_r"]/100
        data["branch"]["$p"]["b_fr"] = data["branch"]["$p"]["b_fr"]/100
        data["branch"]["$p"]["b_to"] = data["branch"]["$p"]["b_to"]/100 
    end

    # 145 bus needs to be isolated -> connecting the lines to onshore grid from Belgium
    for (b_id,b) in data["branch"]
        if haskey(b,"branch_name") && b["branch_name"] == "BE_VAN_EYCK-NL"
            b["f_bus"] = 53
        elseif haskey(b,"branch_name") && b["branch_name"] == "BE_DOEL-NL"
            b["f_bus"] = 37
        elseif b_id != 184 && b_id != 183
            if b["f_bus"] == 145 
                b["f_bus"] = 43
            elseif b["t_bus"] == 145
                b["t_bus"] = 43
            end
        end
    end

    data["convdc"] = deepcopy(North_sea_grid["convdc"])
    for q in 1:length(North_sea_grid["convdc"])
        data["convdc"]["$q"]["busac_i"] = deepcopy(data["convdc"]["$q"]["busac_i"]+144)
    end
    data["convdc"]["1"]["type_dc"] = 3

    data["branchdc"] = deepcopy(North_sea_grid["branchdc"])
    data["branchdc"]["1"]["branchdc_name"] = "BE-energy_island"
    data["branchdc"]["2"]["branchdc_name"] = "UK-energy_island"
    data["branchdc"]["3"]["branchdc_name"] = "NEMO"
    data["branchdc"]["4"]["branchdc_name"] = "BRITNED"

    r = 51 #deepcopy(length(data["load"]))
    for s in 2:length(North_sea_grid["load"])
        t = r+s-1 #taking out Belgium
        data["load"]["$t"] = deepcopy(North_sea_grid["load"]["$s"])
        data["load"]["$t"]["index"] = deepcopy(t)
        data["load"]["$t"]["pd"] = 0
    end
    data["load"]["52"]["source_id"][2] = 146
    data["load"]["53"]["source_id"][2] = 151
    data["load"]["52"]["load_bus"] = 146
    data["load"]["53"]["load_bus"] = 151

    u = 289 #deepcopy(length(data["gen"])) with VOLL generators
    for v in 11:length(North_sea_grid["gen"]) # 11 BE generators in the original grid
        w = u+v - 10
        bus = 144 + North_sea_grid["gen"]["$v"]["gen_bus"]
        data["gen"]["$w"] = deepcopy(North_sea_grid["gen"]["$v"])
        data["gen"]["$w"]["cost"] = []
        push!(data["gen"]["$w"]["cost"],gen_costs[data["gen"]["$w"]["type"]])
        push!(data["gen"]["$w"]["cost"],0)
        data["gen"]["$w"]["index"] = deepcopy(w)
        data["gen"]["$w"]["gen_bus"] = deepcopy(bus)
        data["gen"]["$w"]["mbase"] = deepcopy(data["gen"]["$w"]["pmax"]*100)
        data["gen"]["$w"]["source_id"][2] = deepcopy(w)
        data["gen"]["$w"]["installed_capacity"] = deepcopy(data["gen"]["$w"]["pmax"])
    end
    for (g_id,g) in data["gen"]
        if g["zone"] == "UK00"
            g["gen_bus"] = 146
        elseif g["zone"] == "NL00"
            g["gen_bus"] = 151
        end
    end
end

function add_VOLL_generators(data)
    for i in 1:144
        l = 145 + i
        data["gen"]["$l"] = deepcopy(data["gen"]["3"])
        data["gen"]["$l"]["installed_capacity"] = 99.99
        data["gen"]["$l"]["gen_bus"] = i 
        data["gen"]["$l"]["pmax"] = 99.99
        data["gen"]["$l"]["mbase"] = 9999
        data["gen"]["$l"]["source_id"][2] = deepcopy(l)
        data["gen"]["$l"]["gen_type"] = "VOLL"
        data["gen"]["$l"]["index"] = i 
        data["gen"]["$l"]["type"] = "VOLL"
        data["gen"]["$l"]["cost"][1] = 5000
    end
end

function fix_branches_rate_a(data)
    data["branch"]["120"]["rate_a"] = 20.0
    data["branch"]["149"]["rate_a"] = 20.0
    data["branch"]["20"]["rate_a"] = 20.0
    data["branch"]["154"]["rate_a"] = 20.0
    data["branch"]["18"]["rate_a"] = 20.0
    data["branch"]["153"]["rate_a"] = 20.0
    data["branch"]["152"]["rate_a"] = 99.0
    data["branch"]["134"]["rate_a"] = 60.0
    data["branch"]["155"]["rate_a"] = 20.0
    data["branch"]["130"]["rate_a"] = 20.0
    data["branch"]["58"]["rate_a"] = 20.0
    data["branch"]["129"]["rate_a"] = 20.0
    data["branch"]["60"]["rate_a"] = 99.0
    data["branch"]["159"]["rate_a"] = 20.0
    data["branch"]["160"]["rate_a"] = 20.0
    data["branch"]["27"]["rate_a"] = 20.0
    data["branch"]["157"]["rate_a"] = 20.0
    data["branch"]["170"]["rate_a"] = 20.0
    data["branch"]["28"]["rate_a"] = 20.0
    data["branch"]["169"]["rate_a"] = 20.0
    data["branch"]["158"]["rate_a"] = 20.0
    data["branch"]["73"]["rate_a"] = 20.0
    data["branch"]["72"]["rate_a"] = 20.0
    data["branch"]["174"]["rate_a"] = 20.0
    data["branch"]["116"]["rate_a"] = 20.0
    data["branch"]["100"]["rate_a"] = 60.0
    data["branch"]["15"]["rate_a"] = 20.0
    data["branch"]["16"]["rate_a"] = 20.0
    data["branch"]["93"]["rate_a"] = 20.0
    data["branch"]["84"]["rate_a"] = 20.0
    data["branch"]["101"]["rate_a"] = 30.0
    data["branch"]["23"]["rate_a"] = 30.0
    #data["branch"]["186"]["rate_a"] = 30.0
    data["branch"]["106"]["rate_a"] = 30.0
    data["branch"]["98"]["rate_a"] = 30.0
    #data["branch"]["187"]["rate_a"] = 30.0
    data["branch"]["97"]["rate_a"] = 30.0
    data["branch"]["74"]["rate_a"] = 30.0
    data["branch"]["82"]["rate_a"] = 30.0
    data["branch"]["119"]["rate_a"] = 30.0
    data["branch"]["131"]["rate_a"] = 30.0
    data["branch"]["121"]["rate_a"] = 30.0
    data["branch"]["102"]["rate_a"] = 10.0
    #data["branch"]["185"]["rate_a"] = 30.0
end

function add_VOLL_generators_energy_island(data)
    for i in 145:150
        l = 304 + (i-144)
        data["gen"]["$l"] = deepcopy(data["gen"]["3"])
        data["gen"]["$l"]["installed_capacity"] = 99.99
        data["gen"]["$l"]["gen_bus"] = i 
        data["gen"]["$l"]["pmax"] = 99.99
        data["gen"]["$l"]["mbase"] = 9999
        data["gen"]["$l"]["source_id"][2] = deepcopy(l)
        data["gen"]["$l"]["gen_type"] = "VOLL"
        data["gen"]["$l"]["index"] = l 
        data["gen"]["$l"]["type"] = "VOLL"
        data["gen"]["$l"]["cost"][1] = 5000
    end
end

function assign_name_buses(data)
    file = joinpath(@__DIR__,"bus_names.xlsx")
    xf = XLSX.readxlsx(file)
    nodes = xf["nodes"]
    names = xf["nodes"]["A2:A82"]
    lat = xf["nodes"]["B2:B82"]
    long = xf["nodes"]["C2:C82"]

    for (b_id,b) in data["bus"]
        if haskey(b,"bus_name")
            for i in 1:length(names)
                if b["bus_name"] == names[i][1:5] && names[i][1:1] != "X"
                    b["lat"] = lat[i]
                    b["lon"] = long[i]
                elseif b["bus_name"] == names[i] && names[i][1:1] == "X"
                    b["lat"] = lat[i]
                    b["lon"] = long[i]
                end
            end
            if b["bus_name"][1:3] == "BE_"
                b["lat"] = 51.411386
                b["lon"] = 2.847237
            elseif b["bus_name"][1:2] == "NL"
                b["lat"] = 51.887529
                b["lon"] = 3.792526
            elseif b["bus_name"][1:2] == "UK"
                b["lat"] = 51.906538
                b["lon"] = 1.556103
            elseif b["bus_name"][1:2] == "DE"
                b["lat"] = 50.870385
                b["lon"] = 6.462833
            end
        else # Brussels
            b["bus_name"] = "Lat_long_nd"
            b["lat"] = 50.852963
            b["lon"] = 4.297724
        end
    end
end

function fix_name_buses(data)
    #Fixing name buses
    data["bus"]["79"]["bus_name"] = "RODE+"
    data["bus"]["79"]["lat"] = deepcopy(data["bus"]["34"]["lat"])
    data["bus"]["79"]["lon"] = deepcopy(data["bus"]["34"]["lon"])
    data["bus"]["80"]["bus_name"] = "ROMSS"        
    data["bus"]["80"]["lat"] = deepcopy(data["bus"]["63"]["lat"])
    data["bus"]["80"]["lon"] = deepcopy(data["bus"]["63"]["lon"])
    data["bus"]["81"]["bus_name"] = "SERAI"
    data["bus"]["81"]["lat"] = deepcopy(data["bus"]["17"]["lat"])
    data["bus"]["81"]["lon"] = deepcopy(data["bus"]["17"]["lon"])
    data["bus"]["84"]["bus_name"] = "BRUEG"        
    data["bus"]["84"]["lat"] = deepcopy(data["bus"]["44"]["lat"])
    data["bus"]["84"]["lon"] = deepcopy(data["bus"]["44"]["lon"])
    data["bus"]["86"]["bus_name"] = "ZNAAM"
    data["bus"]["86"]["lat"] = deepcopy(data["bus"]["66"]["lat"])
    data["bus"]["86"]["lon"] = deepcopy(data["bus"]["66"]["lon"])
end


