% https://de.wikipedia.org/wiki/Netzfrequenz
% https://de.wikipedia.org/wiki/Regelleistung_(Stromnetz)


close all
clear all
mycolororder = [0.4 0.3 0.0; 0.9 0.0 0.0; 0.9 0.4 0.0; 0.8 0.8 0.0; 0.1 0.8 0.0; 0.0 0.1 0.9; 0.5 0.0 0.6; 0.4 0.4 0.4; 0.5 0.8 0.8 ; 0 0 0 ];
set(0, 'defaultAxesColorOrder', mycolororder);
set(0, 'defaultLineLineWidth', 1.5);

% Namen, wie sie im Tesla Gateway benutzt werden:
%# date_time  site_instant_power  site_frequency  site_energy_exported  site_energy_imported  battery_instant_power  battery_frequency  battery_energy_exported  battery_energy_imported  load_instant_power  load_frequency  load_energy_exported  load_energy_imported  solar_instant_power  solar_frequency  solar_energy_exported  solar_energy_imported  global_percentage 

Nn=5;  % Number of nodes
Nt=7;  % number of timesteps for simulation

Mnt0=zeros(Nn,Nt);  % zero Nn x Nt matrix
Mn10=zeros(Nn,1);   % zero Nt x 1 matrix

% ---------------------------------------------------------------------
if 0
  % Vorschlag: an physikalischen Groessen orientiert Struktur:

  % init grid structure
  g.p.inci = Mnt0;    % incident solar power
  g.p.prod = Mnt0;    % power production by solar array
  g.p.batt = Mnt0;    % power delivered to battery
  g.p.load = Mnt0;    % load power consumption
  g.p.main = Mnt0;    % power delivered to mains ( grid)

  g.c.batt = Mn10;    % battery capacity in kWh

  g.Y = eye(Nn);      % Admittance matrix of all node interconnections
  g.U = Mnt0;         % Voltages at mains connection points
  g.I = Mnt0;         % currents flowing into mains

end

% ---------------------------------------------------------------------

% Vorschlag: Objekt-orientierte Struktur. 
% All powers in kW, all energies in kWh
% Vorzeichen so, dass "Plus gut fuer die site ist"
% das uebergeordnete objekt ist das "Grid". 
% Es enthaelt eine Menge aus Nn Sites (Nodes),
% die je ein Objekt prod, batt, load und main haben.
% Aus Effizienzgruenden gibt es im Grid nur ein site-Objekt, 
% das aber vektor-Komponenten hat, so kann man klassisches 
% Matlab und Matrizen verwenden. TBD.

ts = 0:300:24*3600*1;
th = ts/3600;
td = th/24;   % time in days, Simulation duration 

g.td = td;
g.Nn=5;             % Number of nodes
g.Nt=length(g.td);  % number of timesteps for simulation

g.Y = [];       % Admittance matrix of all node interconnections

g.Ndays=7;     % simulation duration in days
g.td_s=60;     % simulation time step t_delta


g.prod.i = [];    % irradiated solar power
g.prod.p = [];    % power production by solar array

g.batt.c  = [];   % battery capacity in kWh

g.batt.p  = [];   % power delivered to battery

g.load.p = [];    % load power consumption

g.main.p = [];    % site powers delivered to mains ( grid)
g.main.U = [];    % site Voltages at mains connection points
g.main.I = [];    % site currents flowing into mains


% jedes Objekt hat mindestens folgende attribute:
% x.p  % Momentanleistung, Zaehlpfeil in das Objekt
% x.e  % Energie


% Methoden

% Konstruktoren

%---------------
% grid_init
%---------------
  % Hilfsvariablen fuer ein symmetrisches Sternnetz
  N=g.Nn;
  aa= 1;
  bb= -1/N;
  g.G1_S=1;            % Default conductance in Siemens to central node
  g.Y = g.G1_S .* (aa*eye(N) + bb* ones(N,N));  % singular admittance matrix
  %g.Z = pinv(g.Y);     % Impedance Matrix

  % Annahme: Site 1 ist das oeffentliche Netz. Dort werden 230V angenommen.

%---------------
%   batt_init
%---------------
  g.batt.c  = 5*ones(g.Nn,1);


%---------------
%   prod_init
%---------------

  prod.i = (0.4 - cos( 2*pi*td ))/(1+0.4);   % einfach mal eine Sommer-Sinuskurve
  prod.i(find(prod.i < 0))=0;
  %figure,  plot(th, prod.i); grid on ;


%---------------
%   load_init
%---------------
% ein load event besteht aus: startzeit, dauer, leistung

% Hilfsvariablen zur Modellierung der Verbraucher, Indizierung
ixt=1:g.Nt;
loads = [10, 30, 100, 300, 500, 1000, 1200, 1500, 2000, 3000];          % 10 Sorten von Verbrauchern in Watt
durations = 1*[6, 10, 30, 120, 300, 600, 1100, 1450, 3600, 7000, 13000];  % 10 Sorten von Einschaltdauern in sekunden
%durations = 10000*ones(1,length(loads));
rand('state', 10);  % init random generator

ixr=mod(floor(abs(4*randn(1,1000))),11)+1; % Modellierung einer Verteilung, die kleine Werte haeufiger als grosse enthaelt
%figure, hist(ixr,11);

% Grundlast: 20W
g.load.p = 20*ones(g.Nn, g.Nt);
Nevents=30;
for ixn=1:g.Nn
  ixrand=mod(floor(abs(8*randn(2,Nevents))),length(loads))+1;   % random indices for all events
  ixbegin=1+floor(g.Nt*rand(1,Nevents));	      % random start times for all events
  for ixe=1:Nevents
    iduration=find(ts < durations(ixrand(2,ixe)));
    %length(iduration)
    ii = ixbegin(ixe):min(g.Nt, ixbegin(ixe)+iduration(end)-1);   % index-intervall
    g.load.p(ixn,ii) = g.load.p(ixn,ii) + loads(ixrand(1,ixe));
  end
end
g.load.p = g.load.p/1000;  % convert to unit kW

figure
%plot(g.td, g.load.p');
plot( g.load.p');


%---------------------
%   Simulate Voltages
%---------------------

% Start Simulation

