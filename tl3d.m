function tldata=tl3d(fname)
% tesla powerwall gateway teslogger data evaluation
% with gnu octave, creating a 3D map of 
% solar power vs daytime and year
%
% Usage Examples:
%
% Background
%   - we simply skip 29. February

% the path to all archived data
tlpathloc='/data/tesla_solaredge/log'
if ~exist(tlpathloc,'dir')
  tlpathloc='.'
end
tlpath0=[tlpathloc '/data0'];   % raw data goes here
tlpath1=[tlpathloc '/data1'];   % dat data goes here, dat.gz
tlpath9=[tlpathloc '/data9'];   % result plots go here

isip=19 % index of solar_instant_power in .dat files

years=2018:2025;  % range of years to process
doys  =1:366;
months=1:12;

% conversion table between day of year nr and month-day
doyarr=zeros(length(doys), 4);
doylut=zeros(12, 31);    % lookup-table to convert month-day to doy
mdlist=[31 29 31 30 31 30 31 31 30 31 30 31 ]; 
doy=1;   % day of year
valid=0;
% constructor - init table
for month=months
  for dayofmonth=1:mdlist(month)
    doyarr(doy,:) = [ doy dayofmonth month valid];
    doylut(month,dayofmonth)=doy;
    doy=doy+1;
  end
end

% collect all solar data in these arrays
Nm=1440;  % 24*60 numner of minutes in a day
solarr=zeros(Nm, length(doys), length(years));  % solar power
solavg=zeros(Nm, length(doys), length(years));  % mean solar power
solmax=zeros(Nm, length(doys), length(years));  % max solar power
solstd=zeros(Nm, length(doys), length(years));  % standard deviation of solar power

if 0
  for iyear=4:length(years)
    year=years(iyear);
    dd=dir( [tlpath1 sprintf('/aggregates_%4d-*.dat*', year)]);
    printf('# processing year %4d, found %d .dat files in %s\n', year, length(dd), tlpath1); 

    %-----------------------------------------------------  
    % gather info on existing files
    doyarr(:,4)=0;     % re-init to invalid
    for ii=1:length(dd)
      basename=strsplit (dd(ii).name, ".");
      m_day = strsplit(basename{1}, "-");
      m=str2num(m_day{2});
      d=str2num(m_day{3});
      if( m<1 || m>12)
        printf('# warning: dubious month, ignoring %s\n', dd(ii).name);
        continue;
      end
      if( d<0 || d>mdlist(m) )
        printf('# warning: dubious day, ignoring %s\n', dd(ii).name);
        continue;
      end
      %if(m==2 && d==29), continue; end; % skip leap day
      doy=doylut(m,d);
      doyarr(doy,4)=ii;  % set to valid, because a corresponding file exists
    end

    %-----------------------------------------------------  
    % load each file and extract time and solar power data
    for doy=doys
      idd=doyarr(doy,4);
      if(idd==0)
        continue;
      else
        ffname=[ dd(idd).folder "/" dd(idd).name];
        printf('# %3d %3d  %s', idd, doy, dd(idd).name);
        try
          ee=load( ffname );   % load energy data
          printf('\n');
        catch
          printf('  # corrupted - ignored\n');
          continue;
        end
        if (size(ee,2)<isip)
          printf('  # found just %d data columns - ignored\n', size(ee,2) );
          continue;
        end
      end
      % extract time info
      tY=ee(:,1);	% Day
      tM=ee(:,2);	% Month
      tD=ee(:,3);	% Year
      th=ee(:,4);	% hour
      tm=ee(:,5);	% minute
      ts=ee(:,6);	% seconds
      t=th+tm/60+ts/3600;
      days = datenum (ee(:,1:6));

      % extract solar power data into 1440 minute bins
      t1h=0; % time interval start, in hours
      for mi=1:Nm
        % map all measurement times in to minute-of-day bins
        t2h=mi/60; % time interval end, in hours
        idx=find( (t1h<=t) & (t<t2h) );
        % fill data arrays with downsampled data
        if( ~isempty(idx) )
          solarr(mi,doy,iyear)=median(ee(idx,isip));
          solmax(mi,doy,iyear)=max(ee(idx,isip));
          solavg(mi,doy,iyear)=mean(ee(idx,isip));
          solstd(mi,doy,iyear)=std(ee(idx,isip)); 
        end
        t1h=t2h;
      end

      % time grid in minutes or h/100 (36sec)
      %plot(t,ee(:,isip), 'x-'); grid on
    end

    % save for quicker post-processing
    sol.year=year;
    sol.arr=squeeze(solarr(:,:,iyear));
    sol.avg=squeeze(solavg(:,:,iyear));
    sol.max=squeeze(solmax(:,:,iyear));
    sol.std=squeeze(solstd(:,:,iyear));
    save( '-hdf5', sprintf('tl3d_sol_%d.hdf5', year), 'sol');

    % load(sprintf('tl3d_sol_%d.hdf5', year));
    figure
    imagesc(sol.arr);
    xlabel("day of year");
    ylabel("minute of day");
    title( sprintf('solar power %d, max',  sol.year));

  end
end

close all

%-----------------------------------------------------
% load the previously, time-consumingly extracted data
kW=1000;
for iyear=1:length(years)
  year=years(iyear);
  fname=sprintf('tl3d_sol_%d.hdf5', year);
  try
    load(sprintf('tl3d_sol_%d.hdf5', year));
  catch
    printf('# file not found: %s\n', fname );
    continue;
  end

  % time scales
  sz=size(sol.arr);
  tm=(0:(sz(1)-1));  % time of day in minutes
  th=tm/60;      % time of day in hours
  doy=1:sz(2);       % day of year
  woy=doy/7;         % week of year
  monthstart=find(doyarr(:,2)==1);
  xticklab = { '1','2','3','4','5','6','7','8','9','10','11','12' };
  
  fields=fieldnames(sol);  % they seem to be sorted alphabetically ...?
  for fn=2:4  % avg, max, std
    figure
    h=imagesc(doy, th, sol.(fields{fn})/kW);
    colormap('jet');
    set(gca,'YDir','normal'); 
    title( sprintf('solar power %d, %s',  sol.year, fields{fn}));
    ylabel("hour");
    xlabel("month");
    set(gca, 'xtick', monthstart);
    set(gca, 'xticklabel', xticklab);
    cbh=colorbar("EastOutside");
    ylabel(cbh,'p / kW');
  end

  solarr(:,:,iyear)=sol.arr;
  solavg(:,:,iyear)=sol.avg;
  solmax(:,:,iyear)=sol.max;
  solstd(:,:,iyear)=sol.std;
end

%--------------------------------
% the final fusion over all years
% close all
Sol.arr = median(solarr, 3);
Sol.avg = mean(solavg, 3);
Sol.max = max(solmax, [], 3);
Sol.std = std(solstd, 1, 3);
Sol.years = years;

% apply other filter methods
Sorted = sort(solmax,3,'descend');
Sol.arr = squeeze( Sorted(:,:,2));  % take the second highest value...
Sol.arr = mean(Sorted(:,:,1:3),3); % average the 3 highest values

fields=fieldnames(Sol);  % hope, we created them alphabetically sorted ..
kW=1000;
for fn=1:4  % arr, avg, max, std
  figure
  h=imagesc(doy, th, Sol.(fields{fn})/kW);
  colormap('jet');
  %colormap('cubehelix');
  set(gca,'YDir','normal'); 
  title( sprintf('solar power %d..%d, %s', Sol.years(1), Sol.years(end), fields{fn}));
  xlabel("week of year");
  ylabel("hour");
  ylim([5.5 20.5]);
  set(gca, 'xtick', monthstart);
  xlabel("month");
  set(gca, 'xtick', monthstart);
  set(gca, 'xticklabel', xticklab);
  cbh=colorbar("EastOutside");
  ylabel(cbh,'p / kW');
  grid on
end


%--------------------------------
% playground
if 0
  [xx, yy] = meshgrid (doy, th);
  figure
  kk=ones(3,3)/9000;  % rectangular 2D filter, convert to kW
  sc=conv2(Sol.arr, kk, 'same'); 
  surf(xx,yy, sc);

  figure
  h=imagesc(doy, th, sc);
  colormap('jet');
  set(gca,'YDir','normal'); 
  cbh=colorbar("EastOutside");
  ylabel(cbh,'p / kW');
end 

%--- ideas
% colormap   bl cy gr ge or rt  log scaled?
% rotating video: /y/sda2/home/amerz/demo/noise_space.m
% polyfit
% UTC
if 0
  gh=gca;
  rgbcolorder=eye(3);
  set(0,'defaultAxesColorOrder', rgbcolorder );
  
  x=(0:63)';
  t=x/63;
  a=sqrt(t)*ones(1,3);
  b=max(0, cos((t-1.0/8)*2.2*pi));
  g=max(0, cos((t-1.3/3)*0.9*pi));
  r=max(0, cos((t-2.3/3)*0.8*pi));
  cm=[r g b].*a;
  figure
  plot(cm); title('colormap'); grid on
  
  set(gh, 'colormap', cm);
  
end 
