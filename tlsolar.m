

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

deg=180/pi;                 % conversion factor rad to deg

no1=Rot('y', Dachneigung_deg/deg)*ez;   % Normalenvektor der Solarzellen, Ostdach
nw1=Rot('y',-Dachneigung_deg/deg)*ez;

n1 = [ no1 nw1 ]

n2=Rot('z', Giebelrichtung_deg/deg)*n1;

n3=Rot('x', Lat_deg/deg)*n2;

n4=Rot('z', Lon_deg/deg)*n3;

n=[oo n1];

plot3(n(1,:),n(2,:),n(3,:), '*');  grid on;
xlabel('x'); ylabel('y'); zlabel('z');
