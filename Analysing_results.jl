function compute_b_values(values_b, grid)
    values_b = []
    for i in 1:length(grid["branch"])
        print(calc_branch_y(grid["branch"]["$i"]),"\n")
        push!(values_b,calc_branch_y(grid["branch"]["$i"]))
    end
end

function print_branches_details(result,grid) 
    count_diff = 0
    branch_ = 0
    for i in 1:176 
        if result["solution"]["branch"]["$i"]["pt"] != 0.0
            #print("BRANCH $(i), transmitting $(result["solution"]["branch"]["$i"]["pt"]), transmitting $(result["solution"]["branch"]["$i"]["pt"]/grid["branch"]["$i"]["rate_a"]*100) %, b value $(values_b[i][2]), va f_bus is $(result["solution"]["bus"]["$(grid["branch"]["$i"]["f_bus"])"]["va"]), va t_bus is $(result["solution"]["bus"]["$(grid["branch"]["$i"]["t_bus"])"]["va"])","\n")
            print("BRANCH $(i), transmitting $(result["solution"]["branch"]["$i"]["pt"]), transmitting $(result["solution"]["branch"]["$i"]["pt"]/grid["branch"]["$i"]["rate_a"]*100) %, b value $(values_b[i][2]), diff va f_bus-t_bus is $(result["solution"]["bus"]["$(grid["branch"]["$i"]["f_bus"])"]["va"]-result["solution"]["bus"]["$(grid["branch"]["$i"]["t_bus"])"]["va"])","\n")
            branch_ = branch_ + result["solution"]["branch"]["$i"]["pt"]
            diff___ = result["solution"]["bus"]["$(grid["branch"]["$i"]["f_bus"])"]["va"]-result["solution"]["bus"]["$(grid["branch"]["$i"]["t_bus"])"]["va"]
            if diff___ == 1.0472
                count_diff += 1
                print(i,"\n")
            end
        end
    end
end


function compute_VOLL(grid,results)
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
    return voll_
end

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

function compute_gen_type(grid,result,type_gen) # type gen should come from a type in the ENTSO-E dataset
    _gen = 0
    for (g_id,g) in BE_grid["gen"]
        if g["type"] == "$(type_gen)"
            print("GEN $(type_gen) $(g_id), generating $(result["solution"]["gen"][g_id]["pg"])","\n")
            _gen = _gen + result["solution"]["gen"][g_id]["pg"]
        end
    end
    return _gen
end








