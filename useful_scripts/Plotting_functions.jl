# Line 6 is the most congested in this case
p1 = Plots.scatter(hourly_RES_ac_TWh, congestion_ac_7, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$RES~generation~[TWh]\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-1.1,1.1],xlims=[340,660])#,title = "Power flow through AC branch 3 for different RES levels, only AC grid",titlefont = font(10,"Computer Modern"))
p2 = Plots.scatter(hourly_RES_ac_dc_TWh, congestion_ac_dc_7, legend=:none, mc=:blue, ms=2, ma=0.5,marker = :diamond,xlabel = "\$RES~generation~[TWh]\$",xguidefontsize=10,xtickfont = "Computer Modern",ylabel = "\$Branch~utilization\$",yguidefontsize=10,ytickfont = font(8,"Computer Modern"),ylims=[-1.1,1.1],xlims=[340,660])#,title = "Power flow through AC branch 3 for different RES levels, AC/DC grid",titlefont = font(10,"Computer Modern"))

# AC/DC grid
congested_lines_hvdc = []
branches_hvdc = Dict{String,Any}()
compute_congestions_HVDC(test_case,8760,results_AC_DC,congested_lines_hvdc,branches_hvdc)

line_6_hvdc = Dict{String,Any}()
compute_congestions_line_HVDC(test_case,8760,results_AC_DC,line_6_hvdc,6)

congestion_6_hvdc = []
for i in 1:8760
    push!(congestion_6_hvdc,line_6_hvdc["$i"])
end

p3 = Plots.scatter(hourly_RES_ac_dc_TWh, congestion_6_hvdc, label="data", legend=:none, mc=:red, ms=2, ma=0.5,marker = :diamond,xlabel = "\$RES~generation~[TWh]\$",xguidefontsize=10,xtickfont = "Computer Modern",ytickfont = font(8,"Computer Modern"),ylabel = "\$Branch~utilization\$",ylims=[-1.1,1.1],xlims=[340,660])#,title = "Power flow through DC branch 6 for different RES levels, AC/DC grid",titlefont = font(10,"Computer Modern"))

p4 = Plots.plot(p2,p3,layout = (2,1))


type = "AC_AC"
number = "6"
plot_filename = "$(dirname(@__DIR__))/results/figures/$(type)_branch_$(number).svg"
Plots.savefig(p1, plot_filename)
