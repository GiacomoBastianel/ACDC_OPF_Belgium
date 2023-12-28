
# The b values should be okay damn
values_b = []
for i in 1:length(BE_grid["branch"])
    print(calc_branch_y(BE_grid["branch"]["$i"]),"\n")
    push!(values_b,calc_branch_y(BE_grid["branch"]["$i"]))
end

s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
result = _PMACDC.run_acdcopf(BE_grid,DCPPowerModel,gurobi; setting = s)



result_json = _PMACDC.run_acdcopf(BE_grid_json,DCPPowerModel,gurobi; setting = s)



count_diff = 0
branch_ = 0
for i in 1:176 
    if result["solution"]["branch"]["$i"]["pt"] != 0.0
        #print("BRANCH $(i), transmitting $(result["solution"]["branch"]["$i"]["pt"]), transmitting $(result["solution"]["branch"]["$i"]["pt"]/BE_grid["branch"]["$i"]["rate_a"]*100) %, b value $(values_b[i][2]), va f_bus is $(result["solution"]["bus"]["$(BE_grid["branch"]["$i"]["f_bus"])"]["va"]), va t_bus is $(result["solution"]["bus"]["$(BE_grid["branch"]["$i"]["t_bus"])"]["va"])","\n")
        print("BRANCH $(i), transmitting $(result["solution"]["branch"]["$i"]["pt"]), transmitting $(result["solution"]["branch"]["$i"]["pt"]/BE_grid["branch"]["$i"]["rate_a"]*100) %, b value $(values_b[i][2]), diff va f_bus-t_bus is $(result["solution"]["bus"]["$(BE_grid["branch"]["$i"]["f_bus"])"]["va"]-result["solution"]["bus"]["$(BE_grid["branch"]["$i"]["t_bus"])"]["va"])","\n")
        branch_ = branch_ + result["solution"]["branch"]["$i"]["pt"]
        diff___ = result["solution"]["bus"]["$(BE_grid["branch"]["$i"]["f_bus"])"]["va"]-result["solution"]["bus"]["$(BE_grid["branch"]["$i"]["t_bus"])"]["va"]
        if diff___ == 1.0472
            count_diff += 1
            print(i,"\n")
        end
    end
end
branch_





calc_branch_y(BE_grid["branch"]["43"])
calc_branch_y(BE_grid["branch"]["44"])
calc_branch_y(BE_grid["branch"]["52"])




for i in 1:129
    print("BUS $(i) has voltage angle $(result["solution"]["bus"]["$i"]["va"])","\n")
end




# Testing the OPF
s = Dict("output" => Dict("branch_flows" => true), "conv_losses_mp" => true)
result = _PMACDC.run_acdcopf(BE_grid,DCPPowerModel,gurobi; setting = s)



voll_ = 0
voll_single = []
for (g_id,g) in BE_grid["gen"]
    if g["type"] == "VOLL"
        voll_ = voll_ + result["solution"]["gen"][g_id]["pg"]
        if result["solution"]["gen"][g_id]["pg"] != 0.0
            push!(voll_single,[g_id,result["solution"]["gen"][g_id]["pg"]])
        end
    end
end
for (g_id,g) in BE_grid["gen"]
    if g["gen_bus"] == 25
        print(g_id,"\n")
    end
end
BE_grid["gen"]["394"]
for (g_id,g) in BE_grid["load"]
    if g["load_bus"] == 25
        print(g_id,"\n")
    end
end
for (br_id,br) in BE_grid["branch"]
    if br["f_bus"] == 25 || br["t_bus"] == 25
        print(br_id,"\n")
    end
end
BE_grid["branch"]["100"]
result["solution"]["branch"]["100"]["pt"]

sum(l["pmax"] for (l_id,l) in BE_grid["load"])

for (br_id,br) in BE_grid["branch"]
    if br["f_bus"] == 37 || br["t_bus"] == 37
        print(br_id,"\n")
    end
end

voll_
for i in 1:length(voll_single)
    if voll_single[i][2] != 0.0
        print(voll_single[i],"\n")
    end
end

nuclear_gen = 0
for (g_id,g) in BE_grid["gen"]
    if g["type"] == "Nuclear"
        print("GEN NUCLEAR $(g_id), generating $(result["solution"]["gen"][g_id]["pg"])","\n")
        nuclear_gen = nuclear_gen + result["solution"]["gen"][g_id]["pg"]
    end
end
nuclear_gen

ccgt_gen = 0
for (g_id,g) in BE_grid["gen"]
    if g["type"] == "Gas CCGT new"
        print("GEN Gas CCGT new $(g_id), generating $(result["solution"]["gen"][g_id]["pg"])","\n")
        ccgt_gen = ccgt_gen + result["solution"]["gen"][g_id]["pg"]
    end
end
ccgt_gen

gen_ = 0
for i in 1:498 
    #if result["solution"]["gen"]["$i"]["pg"] != 0.0
        print("GEN $(i), type $(BE_grid["gen"]["$i"]["type"]), generating $((result["solution"]["gen"]["$i"]["pg"]/BE_grid["gen"]["$i"]["pmax"])*100) %,substation $(BE_grid["gen"]["$i"]["substation_full_name_kV"]), the gen_bus is $(BE_grid["gen"]["$i"]["gen_bus"])","\n")
        gen_ = gen_ + result["solution"]["gen"]["$i"]["pg"]
    #end
end
gen_

gen_ = 0
count_gen = 0
count_gen_VOLL = 0
for i in 1:498 
    if BE_grid["gen"]["$i"]["type"] != "VOLL" && BE_grid["gen"]["$i"]["type"] != "Onshore Wind" && BE_grid["gen"]["$i"]["type"] != "Offshore Wind" && BE_grid["gen"]["$i"]["type"] != "Solar PV" 
        if result["solution"]["gen"]["$i"]["pg"] != 0.0
            #gen_ = gen_ + result["solution"]["gen"]["$i"]["pg"]
            count_gen += 1
        end
    else
        if result["solution"]["gen"]["$i"]["pg"] != 0.0
            count_gen_VOLL += 1
        end
    end
end
gen_
branch_ = 0
for i in 1:176 
    if result["solution"]["branch"]["$i"]["pt"] != 0.0
        print("BRANCH $(i), transmitting $(result["solution"]["branch"]["$i"]["pt"]), transmitting $(result["solution"]["branch"]["$i"]["pt"]/BE_grid["branch"]["$i"]["rate_a"]*100) %","\n")
        branch_ = branch_ + result["solution"]["branch"]["$i"]["pt"]
    end
end
branch_


result = _PMACDC.run_acdcopf(example_dc_grid,DCPPowerModel,gurobi; setting = s)





diff_va = result["solution"]["bus"]["6"]["va"]- result["solution"]["bus"]["82"]["va"]
b = calc_branch_y(BE_grid["branch"]["108"])[2]

BE_grid["branch"]["108"]["br_r"] = BE_grid["branch"]["108"]["br_r"]/100
BE_grid["branch"]["108"]["br_x"] = BE_grid["branch"]["108"]["br_x"]/100

diff_va*b


for (g_id,g) in BE_grid["bus"]
   print([g_id,g["name"]],"\n")
end



for (br_id,br) in BE_grid["branch"]
    if br["f_bus"] == 21 || br["t_bus"] == 21
        print(br_id,"\n")
        print(result["solution"]["branch"][br_id]["pf"],"\n")
        print(br["rate_a"],"\n")
        print("______","\n")
    end
end
