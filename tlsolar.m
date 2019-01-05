function tlsolar(day, month, ndays, myroof)
%
% calculate expected solar power for a specific solar panel arrangement
%
% parameters:
%   day   - either day of month or day of year, if month is omitted
%   month - month of year
%   ndays - lenth of plot period in days
%
% usage examples:
%   tlsolar()       % use default settings
%   tlsolar(21,6)   % power on june 21
%
%   roof.tilt_deg=45;         % orientation of solar panels, 0 is horizontal
%   roof.axis_deg=90;         % rooftop axis. 0 is north
%   roof.Lon_deg=0;           % geolocation of the roof
%   roof.Lat_deg=0;
%   roof.Ppeak_kW=1;          % peak power of modules
%
% Bezugszeit ist der Sonnentag https://de.wikipedia.org/wiki/Sonnentag
% die Zaehlung beginnt mit dem 1.Januar 

dmonth=[ 31 28 31 30 31 30 31 31 30 31 30 31];
Dmonth=cumsum(dmonth);
Dmonth0=[0 Dmonth];

if ~exist('ndays')
 ndays=1;
end
if ~exist('month')
 month=[];
end
if ~exist('day')
 day=355;   % default 21.Dec
end
if ~exist('myroof')
 myroof=[];
end
if isempty(month)
  month=0;
  T1_d = day;        % assume a day number from 1... 365
  T1_cm = find(T1_d <= Dmonth); 
  T1_cm = T1_cm(1);                 % determine calendar Month
  T1_cd = T1_d-Dmonth0(T1_cm);      % determine calendar day in month
else
  T1_d = day+Dmonth0(month)         % start day
  T1_cm = month;
  T1_cd = day
end
T2_d=T1_d + ndays; % end day

T_y=1;
Ty_d=365.25;       % days/year
Ty_d=365;          % days/year ignore leap year

dT_h=0.25;         % time resolution in hours


trange=T1_d:dT_h/24:T2_d;


% x-Achse zeigt nach Osten, y nach Norden
I=eye(3);
ex=I(:,1);
ey=I(:,2);
ez=I(:,3);
oo=zeros(3,1);  % origin

if isempty(myroof)
  Dachneigung_deg=50;
  Giebelrichtung_deg=8;
  Lon_deg=11;                 % Hausstandort
  Lat_deg=48;
  Ppeak_kW=[1 6 3];           % Spitzenleistung der einzelnen Dachflaechen
else
  Dachneigung_deg=myroof.tilt_deg;
  Giebelrichtung_deg=myroof.axis_deg;
  Lon_deg=myroof.Lon_deg;             % location of the roof
  Lat_deg=myroof.Lat_deg;
  Ppeak_kW=[1 myroof.Ppeak_kW];       % peak power of modules
end


deg=180/pi;                 % conversion factor rad to deg


no1=Rot('y', Dachneigung_deg/deg)*ez;   % Normalenvektor der Solarzellen, Ostdach
nw1=Rot('y',-Dachneigung_deg/deg)*ez;

% Normalenvektoren
n1 = [ ez no1 nw1 ];     % first entry points at zenith
n2 = Rot('z', Giebelrichtung_deg/deg)*n1;
n3 = Rot('x', Lat_deg/deg)*n2;
n4 = Rot('z', Lon_deg/deg)*n3;
n5 = n4 .* (ones(3,1)*Ppeak_kW); 


mycolororder = [0.4 0.3 0.0; 0.9 0.0 0.0; 0.9 0.4 0.0; 0.8 0.8 0.0; 0.1 0.8 0.0; 0.0 0.1 0.9; 0.5 0.0 0.6; 0.4 0.4 0.4; 0.5 0.8 0.8 ; 0 0 0 ];
set(0, 'defaultAxesColorOrder', mycolororder);
set(0, 'defaultLineLineWidth', 1.5);

if 1
  n=[oo n1];    % matrix for plotting
  n=[oo n2];    % matrix for plotting
  figure(1);
  plot3(n(1,:),n(2,:),n(3,:), '*');  grid on;
  xlabel('x'); ylabel('y'); zlabel('z');
  title('roof normal directions');
end


p = zeros(length(trange), size(n1,2));   % init result power

for ii =1:length(trange)
  td = trange(ii);                 % time in days
  s1 = Rot('z',-2*pi*td/Ty_d)*ex;   % vector of solar radiation rotating in ecliptic
  s2 = Rot('y', 23/deg)*s1;        % tilt ecliptic
  
  n6 = Rot('z', 2*pi*td)*n5;       % rotation of the earth
  
  p(ii,:) = s2' * n6;              % solar power incident normal to roofs
  
  if 0
    figure(2)
    v=s2;
    plot3(v(1),v(2),v(3), '.r');  grid on; hold on
    xlabel('x'); ylabel('y'); zlabel('z');
    drawnow;
  end
end

p(find(p<0))=0;     % no negative solar powers after sundown
inight=find(p(:,1)<=0);
p(inight,:)=0;

figure;
if ndays>3
  plot(trange, [ p sum(p(:,2:end),2)]); grid on;
  xlabel('t / day'); 
else
  plot(mod(trange,1)*24, [ p sum(p(:,2:end),2)]); grid on;
  xlabel('t / h'); 
end
ylabel('p / kW');
title(sprintf('expected solar power on %d-%d', T1_cm, T1_cd)); 

