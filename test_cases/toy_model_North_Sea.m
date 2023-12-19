% Model developed by Giacomo Bastianel (@GiacomoBastianel) to test the Belgian Energy Island
% Date 16h Dec 2022

function mpc = interconnected_model_Belgian_energy_island()

%case 13 nodes    Power flow data for 13 AC bus, 7 DC bus, 6 generator case.
%% MATPOWER Case Format : Version 1
%%-----  Power Flow Data  -----%%
%% system MVA base
mpc.baseMVA = 100;

%% bus data
%	bus_i	type	Pd	Qd	Gs	Bs	area	Vm      Va	baseKV	zone	Vmax	Vmin
mpc.bus = [
	1       3       200	0	0   0   1       1.06	0	345     1       1.1     0.9;
	2       2       200	0	0   0   1       1       0	345     1       1.1     0.9;
	3       1       0	0	0   0   1       1       0	345     1       1.1     0.9;
	4       1       0	0	0   0   1       1       0	345     1       1.1     0.9;
	5       1       300	0	0   0   1       1       0	345     1       1.1     0.9;
	6       1       0	0	0   0   1       1       0	345     1       1.1     0.9;
	7       1       0	0	0   0   1       1       0	345     1       1.1     0.9;
	8       1       0	0	0   0   1       1       0	345     1       1.1     0.9;
	9       1       0	0	0   0   1       1       0	345     1       1.1     0.9;
	10      1       0	0	0   0   1       1       0	345     1       1.1     0.9;
	11      1       0	0	0   0   1       1       0	345     1       1.1     0.9;
	12      1       0	0	0   0   1       1       0	345     1       1.1     0.9;
	13      1       0	0	0   0   1       1       0	345     1       1.1     0.9;
];

%% generator data
%	bus	Pg      Qg	Qmax	Qmin	Vg	mBase       status	Pmax	Pmin	pc1 pc2 qlcmin qlcmax qc2min qc2max ramp_agc ramp_10 ramp_30 ramp_q apf
mpc.gen = [
	1	1000       0	500      -500    1.06	100       1       23050     0 0 0 0 0 0 0 0 0 0 0 0;
    2	1000       0    300      -300    1      100       1       53000     0 0 0 0 0 0 0 0 0 0 0 0;
    3	10000      0	300      -300    1      100       1       3000     0 0 0 0 0 0 0 0 0 0 0 0;
    4	1000       0	300      -300    1      100       1       3000     0 0 0 0 0 0 0 0 0 0 0 0;
    5	10000      0	300      -300    1      100       1       23000     0 0 0 0 0 0 0 0 0 0 0 0;
    6	1000       0	300      -300    1      100       1       3000     0 0 0 0 0 0 0 0 0 0 0 0;
];

%% branch data
%	fbus	tbus	r	x	b	rateA	rateB	rateC	ratio	angle
%	status angmin angmax
mpc.branch = [
    1   3   0.02    0.06    0.06    10000   100   100     0       0       1 -60 60;
    1   3   0.02    0.06    0.06    10000   100   100     0       0       1 -60 60;
    1   3   0.02    0.06    0.06    10000   100   100     0       0       1 -60 60;
    1   3   0.02    0.06    0.06    10000   100   100     0       0       1 -60 60;
    1   3   0.02    0.06    0.06    10000   100   100     0       0       1 -60 60;
    3   6   0.08    0.24    0.05    10000   100   100     0       0       1 -60 60;
    1   4   0.06    0.18    0.04    10000   100   100     0       0       1 -60 60;
    2   5   0.06    0.18    0.04    10000   100   100     0       0       1 -60 60;
    1   10  0.08    0.24    0.05    10000   100   100     0       0       1 -60 60;
    1   8   0.06    0.18    0.04    10000   100   100     0       0       1 -60 60;
    1   7   0.06    0.18    0.04    10000   100   100     0       0       1 -60 60;
    1   7   0.08    0.24    0.05    10000   100   100     0       0       1 -60 60;
    7   12  0.06    0.18    0.04    10000   100   100     0       0       1 -60 60;
    11  2   0.06    0.18    0.04    10000   100   100     0       0       1 -60 60;
    9   2   0.08    0.24    0.05    10000   100   100     0       0       1 -60 60; 
];


%% dc grid topology
%colunm_names% dcpoles
mpc.dcpol=2;
% numbers of poles (1=monopolar grid, 2=bipolar grid)
%% bus data
%column_names%   busdc_i grid    Pdc     Vdc     basekVdc    Vdcmax  Vdcmin  Cdc
mpc.busdc = [
    1              1       0       1       525         1.1     0.9     0;
    2              1       0       1       525         1.1     0.9     0;
	3              1       0       1       525         1.1     0.9     0;
    4              1       0       1       525         1.1     0.9     0;
    5              1       0       1       525         1.1     0.9     0;
	6              1       0       1       525         1.1     0.9     0;
	7              1       0       1       525         1.1     0.9     0;
];

%% converters
%column_names%   busdc_i busac_i type_dc type_ac P_g   Q_g islcc  Vtar    rtf xtf  transformer tm   bf filter    rc      xc  reactor   basekVac    Vmmax   Vmmin   Imax    status   LossA LossB  LossCrec LossCinv  droop      Pdcset    Vdcset  dVdcset Pacmax Pacmin Qacmax Qacmin
mpc.convdc = [
    1       4   1       1       0    0    0 1     0.01  0.01 1 1 0.01 1 0.01   0.01 1  525         1.1     0.9     1.1     1       1.103 0.887  2.885    2.885      0.0050    -58.6274   1.0079   0 100 -100 50 -50;
    2       5   2       1       0    0    0 1     0.01  0.01 1 1 0.01 1 0.01   0.01 1  525         1.1     0.9     1.1     1       1.103 0.887  2.885    2.885      0.0070     21.9013   1.0000   0 100 -100 50 -50;
    3       6   1       1       0    0    0 1     0.01  0.01 1 1 0.01 1 0.01   0.01 1  525         1.1     0.9     1.1     1       1.103 0.887  2.885    2.885      0.0050     36.1856   0.9978   0 100 -100 50 -50;    
    4       4   8       1       0    0    0 1     0.01  0.01 1 1 0.01 1 0.01   0.01 1  525         1.1     0.9     1.1     1       1.103 0.887  2.885    2.885      0.0050    -58.6274   1.0079   0 100 -100 50 -50;
    5       5   9       1       0    0    0 1     0.01  0.01 1 1 0.01 1 0.01   0.01 1  525         1.1     0.9     1.1     1       1.103 0.887  2.885    2.885      0.0070     21.9013   1.0000   0 100 -100 50 -50;
    6       7   12      1       0    0    0 1     0.01  0.01 1 1 0.01 1 0.01   0.01 1  525         1.1     0.9     1.1     1       1.103 0.887  2.885    2.885      0.0050     36.1856   0.9978   0 100 -100 50 -50;
    7       6   11      1       0    0    0 1     0.01  0.01 1 1 0.01 1 0.01   0.01 1  525         1.1     0.9     1.1     1       1.103 0.887  2.885    2.885      0.0050     36.1856   0.9978   0 100 -100 50 -50;
];

%% branches
%column_names%   fbusdc  tbusdc  r      l        c   rateA   rateB   rateC   status
mpc.branchdc = [
    1       3       0.052   0   0    10000     100     100     1;
    3       2       0.052   0   0    10000     100     100     1;
    4       5       0.052   0   0    10000     100     100     1;
    7       6       0.052   0   0    10000     100     100     1;
];

%% generator cost data
%	1	startup	shutdown	n	x1	y1	...	xn	yn
%	2	startup	shutdown	n	c(n-1)	...	c0
mpc.gencost = [
	2	0	0	3	100  100 100;
	2	0	0	3   100  100 100;
    2	0	0	3   1  1	1;
    2	0	0	3   1  1	1;
	2	0	0	3   100  100 100;
    2	0	0	3   1  1	1;
];

% adds current ratings to branch matrix
%column_names%	c_rating_a
mpc.branch_currents = [
100;100;100;100;100;100;100;100;100;100;100;100;100;100;100;
];