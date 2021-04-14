% octave
%
% display data logged from /tmp/solarmonitor.log
% and converted to v.dat using tlvoltage.sh
%
% usage example:
%   system('./tlvoltage.sh')
%   tlvoltage
%
mycolororder = [0.4 0.3 0.0; 0.9 0.0 0.0; 0.9 0.4 0.0; 0.8 0.8 0.0; 0.1 0.8 0.0; 0.0 0.1 0.9; 0.5 0.0 0.6; 0.4 0.4 0.4;0.5 0.8 0.8 ; 0 0 0 ];
set(0, 'defaultAxesColorOrder', mycolororder);
load v.dat

% fix zero spike
i0=find(v(1,:)==0.0);
if( ~isempty(i0))
  v(1,i0)=v(2,i0);
end

% find start time of recording, unix-time to matlab-time
t0u=v(1,1);  % unix time, see also: help time
% tloc=localtime(time);
tlocal=2/24; % 0 for UTC
v(:,1)=v(:,1)/(24*3600) + tlocal + datenum('Jan-01-1970');
t0m=v(1,1);  % matlab time
t0str=datestr(t0m, 31);

% ----------------- Voltages vs time ---------------------

figure
plot(mod(v(:,1),1)*24, v(:,2:7)); grid on; 
ylim([215 230]);
xlabel('time / h'); ylabel('Voltage / V');
title(sprintf('Three-Phase AC Voltages,   %s', t0str ));
%print( 'v', '-dpng');


% ----------------- Histogram of Voltages ---------------------

meanV=mean(v(:,2:7))
stdV=std(v(:,2:7))
color='rgb'
figure
for i=1:3
  subplot(3,1,i);
  colormap (summer ());
  hist(v(:,[i+1 ]), 1000, 'facecolor', color(i), 'edgecolor', color(i));  
  grid on;
  title(sprintf('L%d Voltage,  mean: %6.2f V, std: %4.2f V', i, meanV(i), stdV(i)));
  text( 0.04, 0.90, t0str, 'Units','normalized');
end
xlabel('Voltage / V');
%print( 'vhistogram', '-dpng');

