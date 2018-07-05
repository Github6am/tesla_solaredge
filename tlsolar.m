

% x-Achse zeigt nach Osten, y nach Norden
I=eye(3);
ex=I(:,1);
ey=I(:,2);
ez=I(:,3);
oo=zeros(3,1);  % origin

Dachneigung_deg=50;
Giebelrichtung_deg=8;
Lon_deg=11;                 % Hausstandort
Lat_deg=48;
Ppeak_kW=[1 6 3];           % Spitzenleistung der einzelnen Dachflaechen

deg=180/pi;                 % conversion factor rad to deg


no1=Rot('y', Dachneigung_deg/deg)*ez;   % Normalenvektor der Solarzellen, Ostdach
nw1=Rot('y',-Dachneigung_deg/deg)*ez;

n1 = [ ez no1 nw1 ];     % first entry points at zenith
n2 = Rot('z', Giebelrichtung_deg/deg)*n1;
n3 = Rot('x', Lat_deg/deg)*n2;
n4 = Rot('z', Lon_deg/deg)*n3;
n5 = n4 .* (ones(3,1)*Ppeak_kW); 


n=[oo n1];

mycolororder = [0.4 0.3 0.0; 0.9 0.0 0.0; 0.9 0.4 0.0; 0.8 0.8 0.0; 0.1 0.8 0.0; 0.0 0.1 0.9; 0.5 0.0 0.6; 0.4 0.4 0.4; 0.5 0.8 0.8 ; 0 0 0 ];
set(0, 'defaultAxesColorOrder', mycolororder);
set(0, 'defaultLineLineWidth', 1.5);

if 0
  figure(1);
  plot3(n(1,:),n(2,:),n(3,:), '*');  grid on;
  xlabel('x'); ylabel('y'); zlabel('z');
  title('roof normal directions');
end

T_y=1
Ty_d=365.25;
T1_d=30*6;
T2_d=30*6+2;

dT_h=0.25;

trange=T1_d:dT_h/24:T2_d;

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
plot(trange, [ p sum(p(:,2:end),2)]); grid on;
xlabel('t / day'); ylabel('p / kW');

