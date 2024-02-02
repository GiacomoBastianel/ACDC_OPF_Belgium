using JSON
using PlotlyJS
using DataFrames

# INSERT HERE THE LINK TO THE GRID MODEL (run first the comparing_grids.jl script)
##############################################
BE_data = deepcopy(BE_grid)
#BE_data = deepcopy(BE_grid_energy_island)
#BE_data = deepcopy(BE_grid_vbdh)
#BE_data = deepcopy(BE_grid_energy_island_vbdh)

file_pdf = "BE_grid_fixing_.pdf"

if length(BE_data["busdc"]) > 4
    BE_data["busdc"]["6"]["lon"] = 2.85
end
##############################################

nodes = [] # vector for the buses
lat = [] # vector for the latitude of the buses
lon = [] # vector for the longitude of the buses
type = [] # to differentiate the bus type (AC or DC)

count_ = 0
for i in 1:length(BE_data["bus"]) # number of ac buses here
    print(i,"\n")
    if haskey(BE_data["bus"]["$i"],"lat") && (i < 128 || i > 132)
        push!(nodes,BE_data["bus"]["$i"]["index"])
        push!(lat,BE_data["bus"]["$i"]["lat"])
        push!(lon,BE_data["bus"]["$i"]["lon"])
        push!(type,0)
    elseif haskey(BE_data["bus"]["$i"],"lat") && (i > 127 || i < 131)
        push!(nodes,BE_data["bus"]["$i"]["index"])
        push!(lat,BE_data["bus"]["$i"]["lat"])
        push!(lon,BE_data["bus"]["$i"]["lon"])
        push!(type,2)
    end
end    
for i in 1:length(BE_data["busdc"]) # number of dc buses here
    print(i,"\n")
    if haskey(BE_data["busdc"]["$i"],"lat") 
        push!(nodes,BE_data["busdc"]["$i"]["index"])
        push!(lat,BE_data["busdc"]["$i"]["lat"])
        push!(lon,BE_data["busdc"]["$i"]["lon"])
        push!(type,1)
    end
end     

branches = [] # vector for the branches
lat_fr = [] # vector for the latitude of the fr_buses of the branches
lon_fr = [] # vector for the longitude of the fr_buses of the branches
lat_to = [] # vector for the latitude of the to_buses of the branches
lon_to = [] # vector for the longitude of the to_buses of the branches
bus_fr_ = [] # fr bus
bus_to_ = [] # to bus
rate_a = [] # rating of the line
type_branch = [] # AC or DC
overload = [] # this is the vector that allows to plot different overloading conditions for different branches in the grid 

for i in 1:length(BE_data["branch"]) # number of AC branches
    push!(branches,BE_data["branch"]["$i"]["index"])
    push!(bus_fr_,BE_data["branch"]["$i"]["f_bus"])
    push!(bus_to_,BE_data["branch"]["$i"]["t_bus"])
    bus_fr = BE_data["branch"]["$i"]["f_bus"]
    bus_to = BE_data["branch"]["$i"]["t_bus"]
    push!(rate_a,abs(BE_data["branch"]["$i"]["rate_a"]))
    push!(lat_fr,BE_data["bus"]["$bus_fr"]["lat"])
    push!(lon_fr,BE_data["bus"]["$bus_fr"]["lon"])
    push!(lat_to,BE_data["bus"]["$bus_to"]["lat"])
    push!(lon_to,BE_data["bus"]["$bus_to"]["lon"])
    push!(type_branch,0)
    if haskey(BE_data["branch"]["$i"],"base_kV") && BE_data["branch"]["$i"]["base_kV"] == 380 
        push!(overload,1.0)
    elseif haskey(BE_data["branch"]["$i"],"base_kV") && BE_data["branch"]["$i"]["base_kV"] > 219 && BE_data["branch"]["$i"]["base_kV"] < 350 
        push!(overload, 0.3)
    else
        push!(overload, 0.1)
    end
end
for i in 1:length(BE_data["branchdc"]) # number of DC branches
    push!(branches,BE_data["branchdc"]["$i"]["index"])
    push!(bus_fr_,BE_data["branchdc"]["$i"]["fbusdc"])
    push!(bus_to_,BE_data["branchdc"]["$i"]["tbusdc"])
    bus_fr = BE_data["branchdc"]["$i"]["fbusdc"]
    bus_to = BE_data["branchdc"]["$i"]["tbusdc"]
    push!(rate_a,abs(BE_data["branchdc"]["$i"]["rateA"]))
    push!(lat_fr,BE_data["busdc"]["$bus_fr"]["lat"])
    push!(lon_fr,BE_data["busdc"]["$bus_fr"]["lon"])
    push!(lat_to,BE_data["busdc"]["$bus_to"]["lat"])
    push!(lon_to,BE_data["busdc"]["$bus_to"]["lon"])
    push!(type_branch,1)
    push!(overload,1.0)
end
    
# Creating dataframe dictionart
dict_nodes =DataFrames.DataFrame("node"=>nodes,"lat"=>lat,"lon"=>lon, "type"=> type)
map_=DataFrames.DataFrame("from"=>bus_fr_,"to"=>bus_to_,"lat_fr"=>lat_fr,"lon_fr"=>lon_fr,"lat_to"=>lat_to,"lon_to"=>lon_to, "rate" => rate_a, "type" => type_branch, "overload" => overload)
txt_x=1

ac_buses=filter(:type => ==(0), dict_nodes)        
markerAC = PlotlyJS.attr(size=[15*txt_x],
            color="green")

dc_buses=filter(:type => ==(1), dict_nodes)        
markerDC = PlotlyJS.attr(size=[15*txt_x],
            color="red")

zonal_buses=filter(:type => ==(2), dict_nodes)        
markerzonal = PlotlyJS.attr(size=[15*txt_x],
            color="orange")
                        


#AC buses legend
traceAC = [PlotlyJS.scattergeo(;mode="markers",textfont=PlotlyJS.attr(size=10*txt_x),
textposition="top center",text=string(row[:node]),
lat=[row[:lat]],lon=[row[:lon]],
marker=markerAC)  for row in eachrow(ac_buses)]
 
#DC buses legend
traceDC = [PlotlyJS.scattergeo(;mode="markers",#textfont=PlotlyJS.attr(size=10*txt_x),
textposition="top center",text=string(row[:node][1]),
           lat=[row[:lat]],lon=[row[:lon]],
           marker=markerDC)  for row in eachrow(dc_buses)] 
mode="markers+text"

#AC buses legend
tracezonal = [PlotlyJS.scattergeo(;mode="markers",textfont=PlotlyJS.attr(size=10*txt_x),
textposition="top center",text=string(row[:node]),
lat=[row[:lat]],lon=[row[:lon]],
marker=markerzonal)  for row in eachrow(zonal_buses)]


#DC line display
lineDC = PlotlyJS.attr(width=1*txt_x,color="red")#,dash="dash")
  
#AC line display
lineAC = PlotlyJS.attr(width=1*txt_x,color="navy")#,dash="dash")
 
#AC line legend
trace_AC=[PlotlyJS.scattergeo(;mode="lines",
lon=[row.lon_fr,row.lon_to],
lat=[row.lat_fr,row.lat_to],
opacity = row.overload,
line=lineAC)
for row in eachrow(map_) if (row[:type]==0)]

#DC line display
#lineDC = PlotlyJS.attr(width=1*txt_x,color="red")#,dash="dash")
 
#DC line legend
trace_DC=[PlotlyJS.scattergeo(;mode="lines",
lat=[row.lat_fr,row.lat_to],
lon=[row.lon_fr,row.lon_to],
opacity = row.overload,
line=lineDC)
for row in eachrow(map_) if (row[:type]==1)]
 
#combine plot data                
trace=vcat(traceAC,trace_AC,traceDC,trace_DC,tracezonal)

 
#set map location
geo = PlotlyJS.attr(scope="europe",fitbounds="locations",#lonaxis=attr(range=[40,58], showgrid=true),
#lataxis=attr(range=[-3,15], showgrid=true))
) 
#plot layput
layout = PlotlyJS.Layout(geo=geo,geo_resolution=100, width=800, height=800,
showlegend = false, 

#legend = PlotlyJS.attr(x=0,y = 0.95,font=PlotlyJS.attr(size=25*txt_x),bgcolor= "#1C00ff00"),
margin=PlotlyJS.attr(l=0, r=0, t=0, b=0))
#display plot
#PlotlyJS.plot(trace, layout)

folder_results = "/Users/giacomobastianel/Desktop/Results_Belgium/Figures"

#display plot
#PlotlyJS.plot(trace, layout)
PlotlyJS.savefig(PlotlyJS.plot(trace, layout), joinpath(folder_results,file_pdf))
#PlotlyJS.savefig(PlotlyJS.plot(trace, layout), joinpath(folder_results,folder,"Figures_"*"$case","$hour"*".png"))
#savefig(PlotlyJS.plot(trace, layout), ".png")


