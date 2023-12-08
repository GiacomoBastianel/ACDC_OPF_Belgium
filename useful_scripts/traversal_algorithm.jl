# traversal_maximum_depth = 500

# Create dictionary containing neighbouring buses both from bus and to bus
bus_neighbour=Dict()
for (bus_id,bus) in BE_grid_2022["bus"]
    neighbour=[]
    for (br,branch) in BE_grid_2022["branch"]
        # Connect from
        if bus_id==string(branch["t_bus"])
            from_bus=string(branch["f_bus"])
            push!(neighbour,from_bus)
        end
        # Connect to
        if bus_id==string(branch["f_bus"])
            to_bus=string(branch["t_bus"])
            push!(neighbour,to_bus)
        end
    end
    push!(bus_neighbour,bus_id=>neighbour)
end

for i in eachindex(bus_neighbour)
    if size(bus_neighbour[i])[1] >= 2
        print(i,"\n") 
    end
end

# TRAVERSAL ALGORITHM
# The purpose is to obtain the connection between each bus and ultimately find the closest bus
# based on the explored network. The algorithm is based on bread first search (BFS).

traversal_maximum_depth = 1000

# Breadth first search (BFS)
# Explore the buses (bus_neighbour)
for (bus_id,bus) in BE_grid_2022["bus"]
    visited_node=[bus_id]
    queue=[bus_id]
    while !isempty(queue) && size(visited_node)[1]<=traversal_maximum_depth#length(visited_node)<=traversal_maximum_depth
        current = pop!(queue)
        if haskey(bus_neighbour,current)
            for neighbor in bus_neighbour[current]
                if !(neighbor in visited_node)
                    push!(queue,neighbor)
                    push!(visited_node,neighbor)
                end
            end
        end
    end
    popfirst!(visited_node)
    push!(BE_grid_2022["bus"][bus_id],"visited_node_all_bfs"=>visited_node)
end

for (b_id,b) in BE_grid_2022["bus"]
    print(b_id,".",size(b["visited_node_all_bfs"]),"\n")
end


BE_grid_2022["bus"]["68"]["visited_node_all_bfs"]
BE_grid_2022["bus"]["67"]["visited_node_all_bfs"]
BE_grid_2022["bus"]["110"]["visited_node_all_bfs"]

BE_grid_2022["bus"]["66"]["visited_node_all_bfs"]
BE_grid_2022["bus"]["61"]["visited_node_all_bfs"]
BE_grid_2022["bus"]["60"]["visited_node_all_bfs"]




a = ["32","22"]

for i in 1:36
    print(BE_grid_2022["bus"]["47"]["visited_node_all_bfs"][i],"__",BE_grid_2022["bus"]["$(BE_grid_2022["bus"]["47"]["visited_node_all_bfs"][i])"]["full_name_kV"],"\n")
end

for i in 1:83
    print(BE_grid_2022["bus"]["37"]["visited_node_all_bfs"][i],"__",BE_grid_2022["bus"]["$(BE_grid_2022["bus"]["37"]["visited_node_all_bfs"][i])"]["full_name_kV"],"\n")
end

BE_grid_2022["branch"]["173"]

length(a)
size(a)[1]
# # for (bus_id,bus) in FR_processed_MILES["bus"]
# #     if length(bus["visited_node_all_bfs"]) != 2665
# #         println(length(bus["visited_node_all_bfs"]))
# #     end
# # end