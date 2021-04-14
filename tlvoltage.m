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
mycolororder = [  0.9 0.6 0.6; 0.6 0.9 0.6; 0.6 0.6 0.9;  0.9 0.0 0.0; 0.0 0.9 0.0; 0.0 0.0 0.9; ];
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
t0str=datestr(t0m, 29);
t0tag=regexprep(t0str,'[:-]','');
t0tag=regexprep(t0tag,' ','_');


% ----------------- Voltages vs time ---------------------

figure
plot(mod(v(:,1),1)*24, v(:,2:7)); grid on; grid minor ;
%plot(10*log10(abs(fft(v(:,2:7)-225, 2^11))));  grid on;
ylim([214 236]);
xlabel('time / h'); ylabel('Voltage / V');
title(sprintf('Three-Phase AC Voltages,   %s', t0str ));
legend;
print( [t0tag '_v' ], '-dpng');

% ----------------- Voltage diff vs time ---------------------
mycolororder = [  0.9 0.0 0.0; 0.0 0.9 0.0; 0.0 0.0 0.9; ];
set(0, 'defaultAxesColorOrder', mycolororder);
dV=v(:,2:4) - v(:,5:7);
meandV=mean(dV)
mtxt=sprintf('mean sensor difference:\nL1: %7.3f\nL2: %7.3f\nL3: %7.3f', meandV(1), meandV(2), meandV(3));

figure
plot(mod(v(:,1),1)*24, dV); grid on; grid minor on;
%plot(10*log10(abs(fft(dV, 2^11))));  grid on;
ylim([-1.7 1.7]);
xlabel('time / h'); ylabel('Voltage / V');
%set(gca, 'xminorgrid','on');
title(sprintf('Three-Phase AC Voltage differences,   %s', t0str ));
legend;
print( [t0tag '_vdiff' ], '-dpng');
text( 0.04, 0.90, mtxt, 'Units','normalized');

% ----------------- Histogram of Voltages ---------------------

meanV=mean(v(:,2:7))
stdV=std(v(:,2:7))
color='rgb';
figure
for i=1:3
  subplot(3,1,i);
  colormap (summer ());
  hist(v(:,[i+1 ]), 1000, 'facecolor', color(i), 'edgecolor', color(i));  
  xlim([214 236]);
  grid on; set(gca, 'xminorgrid','on');
  title(sprintf('L%d Voltage,  mean: %6.2f V, std: %4.2f V', i, meanV(i), stdV(i)));
  text( 0.04, 0.90, t0str, 'Units','normalized');
end
xlabel('Voltage / V');
print( [ t0tag '_vhistogram' ], '-dpng');

