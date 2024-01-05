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
include(joinpath((@__DIR__,"src/core/analysing_results.jl")))

##################################################################
## Processing input data
folder_results = @__DIR__

# Belgium grid without energy island
BE_grid_file = joinpath(folder_results,"test_cases/Belgian_transmission_grid_data_Elia_2023.json")
BE_grid = _PM.parse_file(BE_grid_file)
BE_grid_json = JSON.parsefile(BE_grid_file)

_PMACDC.process_additional_data!(BE_grid)
_PMACDC.process_additional_data!(BE_grid_json)

## Adding the energy island
BE_grid_energy_island = deepcopy(BE_grid)
add_energy_island(BE_grid_energy_island)

# BE grid with Ventilus & Boucle-Du-Hainaut (Belgian scheduled grid reinforcements)
BE_grid_vbdh = deepcopy(BE_grid)
BE_grid_energy_island_vbdh = deepcopy(BE_grid_energy_island)

build_ventilus_and_boucle_du_hainaut_interconnections = true
if build_ventilus_and_boucle_du_hainaut_interconnections == true
    create_ventilus(BE_grid_vbdh)
    create_boucle_du_hainaut(BE_grid_vbdh)
    create_ventilus(BE_grid_energy_island_vbdh)
    create_boucle_du_hainaut(BE_grid_energy_island_vbdh)
end

# Calling the desktop folder with the results
folder_results = "/Users/giacomobastianel/Desktop/Results_Belgium/Simulations_one_year"

results_base_case = JSON.parsefile(joinpath(folder_results,"one_year_BE.json"))
results_ei = JSON.parsefile(joinpath(folder_results,"one_year_BE_EI.json"))
results_vbdh = JSON.parsefile(joinpath(folder_results,"one_year_BE_vbdh.json"))
results_vbdh_ei = JSON.parsefile(joinpath(folder_results,"one_year_BE_EI_vbdh.json"))

obj_ = sum(results_base_case["$i"]["objective"] for i in 1:number_of_hours)*100
obj_ei = sum(results_ei["$i"]["objective"] for i in 1:number_of_hours)*100
obj_vbdh = sum(results_vbdh["$i"]["objective"] for i in 1:number_of_hours)*100
obj_vbdh_ei = sum(results_vbdh_ei["$i"]["objective"] for i in 1:number_of_hours)*100


# Computing the electricity prices
el_price_ = obj_/sum(load_BE)
el_price_ei = obj_ei/sum(load_BE)
el_price_vbdh = obj_vbdh/sum(load_BE)
el_price_ei_vbdh = obj_vbdh_ei/sum(load_BE)

######## Creating CO2 emission vectors ########
CO2_base_case = []
CO2_ei = []
CO2_vbdh = []
CO2_vbdh_ei = []

compute_CO2_emissions(BE_grid,8760,results_base_case,CO2_base_case)
compute_CO2_emissions(BE_grid,8760,results_ei,CO2_ei)
compute_CO2_emissions(BE_grid,8760,results_vbdh,CO2_vbdh)
compute_CO2_emissions(BE_grid,8760,results_vbdh_ei,CO2_vbdh_ei)

# Computing the total CO2 emission per case
sum(CO2_base_case)
sum(CO2_ei)
sum(CO2_vbdh)
sum(CO2_vbdh_ei)


######## Creating RES generation vectors ########
RES_base_case = []
RES_ei = []
RES_vbdh = []
RES_vbdh_ei = []

compute_RES_generation(BE_grid,8760,results_base_case,RES_base_case)
compute_RES_generation(BE_grid_energy_island,8760,results_ei,RES_ei)
compute_RES_generation(BE_grid_vbdh,8760,results_vbdh,RES_vbdh)
compute_RES_generation(BE_grid_energy_island_vbdh,8760,results_vbdh_ei,RES_vbdh_ei)

# Computing the total RES generation per case
sum(RES_base_case)
sum(RES_ei)
sum(RES_vbdh)
sum(RES_vbdh_ei)


# Vectors to build figures
#=
ven_pt = []
bdh_pt = []
pt_7 = []
pt_8 = []

ven_pt_ei = []
bdh_pt_ei = []
pt_7_ei = []
pt_8_ei = []


pt_10 = []
pt_22 = []
pt_23 = []
pt_24 = []
pt_25 = []
pt_26 = []

pt_10_ei = []
pt_22_ei = []
pt_23_ei = []
pt_24_ei = []
pt_25_ei = []
pt_26_ei = []

for i in 1:number_of_hours
    push!(ven_pt,results_vbdh["$i"]["solution"]["branch"]["189"]["pt"])
    push!(bdh_pt,results_vbdh["$i"]["solution"]["branch"]["190"]["pt"])
    push!(pt_7,results_vbdh["$i"]["solution"]["branch"]["7"]["pt"])
    push!(pt_8,results_vbdh["$i"]["solution"]["branch"]["8"]["pt"])

    push!(pt_10,results_vbdh["$i"]["solution"]["branch"]["10"]["pt"])
    push!(pt_22,results_vbdh["$i"]["solution"]["branch"]["22"]["pt"])
    push!(pt_23,results_vbdh["$i"]["solution"]["branch"]["23"]["pt"])
    push!(pt_24,results_vbdh["$i"]["solution"]["branch"]["24"]["pt"])
    push!(pt_25,results_vbdh["$i"]["solution"]["branch"]["25"]["pt"])
    push!(pt_26,results_vbdh["$i"]["solution"]["branch"]["26"]["pt"])    

    push!(ven_pt_ei,results_vbdh_ei["$i"]["solution"]["branch"]["196"]["pt"])
    push!(bdh_pt_ei,results_vbdh_ei["$i"]["solution"]["branch"]["197"]["pt"])
    push!(pt_7_ei,results_vbdh_ei["$i"]["solution"]["branch"]["7"]["pt"])
    push!(pt_8_ei,results_vbdh_ei["$i"]["solution"]["branch"]["8"]["pt"])

    push!(pt_10_ei,results_vbdh_ei["$i"]["solution"]["branch"]["10"]["pt"])
    push!(pt_22_ei,results_vbdh_ei["$i"]["solution"]["branch"]["22"]["pt"])
    push!(pt_23_ei,results_vbdh_ei["$i"]["solution"]["branch"]["23"]["pt"])
    push!(pt_24_ei,results_vbdh_ei["$i"]["solution"]["branch"]["24"]["pt"])
    push!(pt_25_ei,results_vbdh_ei["$i"]["solution"]["branch"]["25"]["pt"])
    push!(pt_26_ei,results_vbdh_ei["$i"]["solution"]["branch"]["26"]["pt"])    
end

ei_503_ei = [] #MWh
ei_502_ei = []
ei_503_vbdh_ei = []
ei_502_vbdh_ei = []
for i in 1:number_of_hours
    push!(ei_503_ei,results_ei["$i"]["solution"]["gen"]["503"]["pg"]*100)
    push!(ei_502_ei,results_ei["$i"]["solution"]["gen"]["502"]["pg"]*100)
    push!(ei_503_vbdh_ei,results_vbdh_ei["$i"]["solution"]["gen"]["503"]["pg"]*100)
    push!(ei_502_vbdh_ei,results_vbdh_ei["$i"]["solution"]["gen"]["502"]["pg"]*100)
end
sum(ei_503_ei)/10^3 #GWh
sum(ei_502_ei)/10^3 #GWh
sum(ei_503_vbdh_ei)/10^3 #GWh
sum(ei_502_vbdh_ei)/10^3 #GWh

sum(load_BE)/10^3 #GWh

(sum(ei_503_ei)/10^3+sum(ei_502_ei)/10^3)/(sum(load_BE)/10^3)
(sum(ei_503_vbdh_ei)/10^3+sum(ei_502_vbdh_ei)/10^3)/(sum(load_BE)/10^3)


res_ei_GWh = (ei_503_ei.+ei_502_ei)/10^3
res_ei_vbdh_GWh = (ei_503_vbdh_ei.+ei_502_vbdh_ei)/10^3

BE_grid_energy_island["gen"]["502"]
BE_grid_energy_island["gen"]["503"]

maximum(ven_pt)
maximum(ven_pt_ei)
minimum(ven_pt)
minimum(ven_pt_ei)

abs(minimum(ven_pt_ei))
abs(maximum(ven_pt))


hours = collect(1:number_of_hours)

/abs(maximum(ven_pt)
/abs(minimum(ven_pt_ei))
abs(maximum(ven_pt))
abs(minimum(ven_pt_ei))


p1 = Plots.scatter(hours, ven_pt/10, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$Timesteps~[h]\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization~[GW]\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-3,3],xlims=[0,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
p2 = Plots.scatter(hours, ven_pt_ei/10, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$Timesteps~[h]\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization~[GW]\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-3,3],xlims=[0,8760])#,title = "Power flow through AC branch 3 for different RES levels, AC/DC grid",titlefont = font(10,"Computer Modern"))

#p3 = Plots.scatter(res_ei_GWh, ven_pt/10, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$RES~Generation~[GWh]\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization~[GW]\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-3,3],xlims=[0,3.5])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
p4 = Plots.scatter(res_ei_vbdh_GWh, ven_pt_ei/10, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$RES~Generation~energy~island~[GWh]\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization~[GW]\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-3,3],xlims=[0,3.5])#,title = "Power flow through AC branch 3 for different RES levels, AC/DC grid",titlefont = font(10,"Computer Modern"))

p5 = Plots.scatter(hours, RES_ei/10^3, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$Timesteps~[h]\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$RES~Generation~[GWh]\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[3,15],xlims=[0,8760])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
p6 = Plots.scatter(hours, RES_vbdh_ei/10^3,legend=:none, mc=:red, ms=2, ma=0.5,marker = :diamond,xlabel = "\$Timesteps~[h]\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$RES~Generation~[GWh]\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[3,15],xlims=[0,8760])#,title = "Power flow through AC branch 3 for different RES levels, AC/DC grid",titlefont = font(10,"Computer Modern"))

p7 = Plots.scatter(hours, load_BE/10^3,legend=:none, mc=:blue, ms=2, ma=0.5,marker = :circle,xlabel = "\$Timesteps~[h]\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Load~[GW]\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[8,18],xlims=[0,8760])#,title = "Power flow through AC branch 3 for different RES levels, AC/DC grid",titlefont = font(10,"Computer Modern"))


folder_results = "/Users/giacomobastianel/Desktop/Results_Belgium/Figures"


plot_filename = joinpath(folder_results,"BU_hours_vbdh.pdf")
Plots.savefig(p1, plot_filename)

plot_filename = joinpath(folder_results,"BU_hours_vbdh_ei.pdf")
Plots.savefig(p2, plot_filename)

plot_filename = joinpath(folder_results,"BU_RES_vbdh.pdf")
Plots.savefig(p3, plot_filename)

plot_filename = joinpath(folder_results,"BU_RES_vbdh_ei.pdf")
Plots.savefig(p4, plot_filename)

plot_filename = joinpath(folder_results,"RES_ei.pdf")
Plots.savefig(p5, plot_filename)

plot_filename = joinpath(folder_results,"RES_vbdh_ei.pdf")
Plots.savefig(p6, plot_filename)

plot_filename = joinpath(folder_results,"Load.pdf")
Plots.savefig(p7, plot_filename)
=#
