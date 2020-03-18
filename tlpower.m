function tldat=tlpower(fname)
% tesla powerwall gateway teslogger data evaluation
% with gnu octave
%
% Usage Examples:
%   tlpower('aggregates_2018-05-29.json.gz');
%
%   dd=dir('aggregates_2018*.json.gz');
%   for i=1:length(dd), tlpower(dd(i).name); close all ; end
%
%   tlpower();   % fetch and display ongoing log
%
% Background:
%   - some stuff is still hardcoded yet
%   - need to create symlinks to tlpower.sh in ~/bin or /usr/local/bin
% 
% Author: A. Merz, 2018, GPL

logsrv='192.168.2.6';
user='amerz';
tlpathsrv='/home/amerz/office/projects/solar/tesla_solaredge/log'
tlpathloc='/home/amerz/office/projects/solar/tesla_solaredge/log'
if ~exist(tlpathloc,'dir')
  tlpathloc='.'
end

if ~exist('fname')
  fname='';
end
if isempty(fname)
  fname='teslog.json';
  fname='aggregates.json';
  dname=regexprep(fname,'\.json','\.dat');  % remove this to trigger rebuild
  if 1  
    % old procedure: fetch bulky actual json file
    cmd=sprintf('scp -p %s@%s:%s/aggregates.json %s ; rm %s', user, logsrv, tlpathsrv, fname, dname)
    [status,output]=system( cmd )
  else
    % new procedure: differential fetch of dat file
    % TODO: auslagern in shell skript tlpower --delta
    if  exist(dname,'file')
      % check if .dat file is from today, if not delete it. 
      % else request and add only the last missing part.
      % TODO
    end
    if ~exist(dname,'file')
      % remote call converter shell script to generate .dat file on server
      % unfortunately, this is way slower than copying the json file over the net
      cmd1=sprintf('cd %s ; ', tlpathsrv)
      cmd2=sprintf('%s/tlpower.sh %s ; ', tlpathsrv, fname)
      cmd =sprintf('ssh %s@%s "%s %s"', user, logsrv, cmd1, cmd2)
      [status,output]=system( cmd );
      cmd=sprintf('scp -p %s@%s:%s/%s .', user, logsrv, tlpathsrv, dname)
      [status,output]=system( cmd );
    end
  end

else
  if ~exist(fname,'file')
    % try to fetch it from the logger server
    cmd=sprintf('scp -p %s@%s:%s/%s .', user, logsrv, tlpathsrv, fname)
    [status,output]=system( cmd )
  end
end

mycolororder = [0.4 0.3 0.0; 0.9 0.0 0.0; 0.9 0.4 0.0; 0.8 0.8 0.0; 0.1 0.8 0.0; 0.0 0.1 0.9; 0.5 0.0 0.6; 0.4 0.4 0.4; 0.5 0.8 0.8 ; 0 0 0 ];
set(0, 'defaultAxesColorOrder', mycolororder);
set(0, 'defaultLineLineWidth', 1.5);

gname=regexprep(fname,'\.json.*','');    % generic name
dname=[gname '.dat'];

if ~exist(dname,'file')
  % call converter shell script to generate .dat file
  cmd=sprintf('%s/tlpower.sh %s', tlpathloc, fname)
  [status,output]=system( cmd );
  
  % Matlab does not like the "#"
  if ~exist('OCTAVE_VERSION','var')
    cmd=sprintf('mv %s %s.hash ; cat %s.hash | tr ''#'' ''%%'' > %s', dname, dname, dname, dname)
    [status,output]=system( cmd );
  end
end

% load solar collector log data
ee=load(dname);

% extract time info
tY=ee(:,1);	% Day
tM=ee(:,2);	% Month
tD=ee(:,3);	% Year
th=ee(:,4);	% hour
tm=ee(:,5);	% minute
ts=ee(:,6);	% seconds
t=th+tm/60+ts/3600;
days = datenum (ee(:,1:6));
%dv=datevec(days);
date1=sprintf('%4d-%02d-%02d', tY(1),   tM(1),   tD(1));
date2=sprintf('%4d-%02d-%02d', tY(end), tM(end), tD(end));

keys={'year', 'month', 'day', 'hour', 'min', 'sec', 'site_instant_power', 'site_frequency', 'site_energy_exported', 'site_energy_imported', 'battery_instant_power', 'battery_frequency', 'battery_energy_exported', 'battery_energy_imported', 'load_instant_power', 'load_frequency', 'load_energy_exported', 'load_energy_imported', 'solar_instant_power', 'solar_frequency', 'solar_energy_exported', 'solar_energy_imported', 'global_percentage'};
ienergy  = find( cellfun(@isempty, regexp (keys, 'energy')) == 0);
ienergyE = find( cellfun(@isempty, regexp (keys, 'energy.*export')) == 0);
ienergyI = find( cellfun(@isempty, regexp (keys, 'energy.*import')) == 0);
ipower   = find( cellfun(@isempty, regexp (keys, 'power' )) == 0);
ifreq    = find( cellfun(@isempty, regexp (keys, 'frequency')) == 0);
ibattpc  = find( cellfun(@isempty, regexp (keys, 'percentage')) == 0);

%---------------------
% plot instant power
%---------------------
portrait='';       % Matlab does not know this print option
if exist('OCTAVE_VERSION','var')
  portrait='-portrait';
end

if 1
  ipower=ipower(1:4);  % 3:4 select only solar and load power

  figure
  plot(t, ee(:,ipower)/1e3); grid on
  %plot(days, ee(:,ipower)/1e3); grid on
  %datetick;
  axis("tight"); ylim([-8 8]);
  tt=title(sprintf('Power %s', gname), 'Interpreter','none' );
  xlabel('t / h'); ylabel('p / kW');
  ll=legend(keys{ipower});  set(ll,'Interpreter','none');
  set(gca,'ColorOrder', mycolororder );
  tx1=text(0,  -0.08, sprintf('%s', date1), 'Units', 'normalized', 'FontSize', 8);
  tx2=text(0.9,-0.08, sprintf('%s', date2), 'Units', 'normalized', 'FontSize', 8);

  print( [ gname '_instant_power.pdf'], '-dpdf', portrait);
end

%---------------------------------
% plot energy
%---------------------------------
if 1
  eecum=ee(:,ienergy);
  eesum=ee(:,ienergyE)-ee(:,ienergyI);   % export-import
  eeday=ee(:,ienergy) - ones(size(ee,1),1)*ee(1,ienergy);  

  figure
  plot(t, eeday/1e3); grid on
  tt=title(sprintf('Energy %s', gname), 'Interpreter','none' );
  xlabel('t / h'); ylabel('E / kWh');
  axis("tight"); %ylim([-2 50]);
  ll=legend(keys{ienergy},'location','northwest');  set(ll,'Interpreter','none');
  set(gca,'colororder', mycolororder );
  tx1=text(0,  -0.08, sprintf('%s', date1), 'Units', 'normalized', 'FontSize', 8);
  tx2=text(0.9,-0.08, sprintf('%s', date2), 'Units', 'normalized', 'FontSize', 8);
  
  print( [ gname '_energy.pdf'], '-dpdf', portrait);
end

%---------------------------------
% plot short-term averaged power
%---------------------------------
% we need to evaluate more precise time tags
if 0
  ienerg=ienergy([5 6 7]);  % select only solar and load power

  dE=diff(ee(:,ienerg),1,1);
  sz=size(dE)
  dt=diff(3600*t);
  idtnegative=find(dt<=0);
  dt(idtnegative)=dt(idtnegative)+24*3600;
  pp=dE./(dt*ones(1,sz(2)));
  tavg=mean(diff(t))*3600;

  figure
  plot(t(2:end), pp); grid on
  tt=title(sprintf('%1.0fs avged Power %s',tavg, gname), 'Interpreter','none' );
  xlabel('t / h'); ylabel('p / W');
  ll=legend(keys{ienerg});  set(ll,'Interpreter','none');
  set(gca,'ColorOrder', mycolororder );

  print( [ gname '_stavg_power.pdf'], '-dpdf', portrait);
end

%---------------------------------
% plot frequency
%---------------------------------
if 0
  ifre=ifreq;
  %ifre=ifreq([ 1 3 4 ]);  % select not all
  freq=ee(:,ifre);

  if 0
    % average/filter the poorly quantized freq data
    Nfilt=31;
    %h=ones(Nfilt,1);  % Rechteckfenster
    h=hann(Nfilt);     % raised-cosine window
    h=h/sum(h);        % DC amplitude normalize
    [freqf,sf]=filter(h,1,fliplr(freq(1:Nfilt)));
    [freqf,sf]=filter(h,1,freq, sf);
  else
    freqf=freq;
  end
  
  figure
  plot(t, freqf); grid on
  tt=title(sprintf('Frequency %s', gname), 'Interpreter','none' );
  xlabel('t / h'); ylabel('f / Hz');
  axis("tight"); ylim(50+[-0.2 0.2]);
  ll=legend(keys{ifre},'location','northwest');  set(ll,'Interpreter','none');
  set(gca,'colororder', mycolororder );
  
  print( [ gname '_freq.pdf'], '-dpdf', portrait);
end

%---------------------------------
% plot battery charging level
%---------------------------------
if 1 && size(ee,2) >= ibattpc
  battperc = ee(:,ibattpc);        % quantization step 0.0074189/100*13.5e3 = 1Wh
  capacity_kWh = 13;               % Tesla powerwall 2 capacity
  battkWh = battperc*capacity_kWh;

  figure
  plot(t, battperc); grid on
  tt=title(sprintf('battery charging state, %s', gname), 'Interpreter','none' );
  xlabel('t / h'); ylabel('c / percent');
  tx1=text(0,  -0.08, sprintf('%s', date1), 'Units', 'normalized', 'FontSize', 8);
  tx2=text(0.9,-0.08, sprintf('%s', date2), 'Units', 'normalized', 'FontSize', 8);
  axis("tight"); 
  %ylim([0 100]);
  set(gca,'colororder', mycolororder );
  
  print( [ gname '_batt.pdf'], '-dpdf', portrait);
end


%---------------------
% result struct
%---------------------
tldat.name=fname;
tldat.keys=keys;
tldat.data=ee;

return

t_dayN= (1:length(W_kWh))/(24*6) -1 + 179; % 28.06.2011= day number 2*31+2*30+28+28

% short term average power within each 10min interval
%p_kW = diff(W_kWh)*3600/600;
t_dayn= t_dayN(2:length(t_dayN));

% plot the whole stuff or just a certain time range
a=round(t_dayn(1));
b=round(t_dayn(length(t_dayn)));

%a=221
%b=227
range=find( t_dayn >= a & t_dayn < b );

plot(t_dayn(range), p_kW(range));
grid
title('10min short term average solar power vs time');
xlabel('t / day of year');
ylabel('P / kW');

sdate=sprintf(" %4d-%02d-%02d", tY(range(1)), tM(range(1)), tD(range(1)));
text(t_dayn(range(1)),4.2,sdate,"color","r");

fname=sprintf("kwh_%03d_%03d", a, b);
print( [fname '.pdf'], '-dpdf');
print( [fname '.jpg'], '-djpeg');
