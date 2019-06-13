
deg=180/pi;                 % conversion factor rad to deg

% https://de.wikipedia.org/wiki/Sternzeit

ts_a=0:0.005:1;

% x-Achse zeigt nach Osten, y nach Norden
I=eye(3);
ex=I(:,1);
ey=I(:,2);
ez=I(:,3);
oo=zeros(3,1);  % origin


dpy=12;   % days per year

s1=zeros(3,length(ts_a));
s2=zeros(3,length(ts_a));
s3=zeros(3,length(ts_a));
s4=zeros(3,length(ts_a));
for its = 1:length(ts_a)
  s1(:,its) = Rot('z',-2*pi*ts_a(its))*ex;
  s2(:,its) = Rot('y', 23/deg)*s1(:,its)*1.1;                % tilt ecliptic
  s3(:,its) = Rot('z',-2*pi*ts_a(its)*dpy)*s2(:,its) *0.8;   % earth rotation, equatorial system
  s4(:,its) = Rot('z',-2*pi*ts_a(its))*Rot('y', -70/deg)*ex*0.7; % geo location
end

figure, 
plot3(s1(1,:),s1(2,:),s1(3,:)); hold on;
plot3(s2(1,:),s2(2,:),s2(3,:)); hold on;
plot3(s3(1,:),s3(2,:),s3(3,:)); hold on;
plot3(s4(1,:),s4(2,:),s4(3,:)); hold on;
hold off;
 
p=sum(s3.*s4);
figure,
plot(ts_a*(dpy),p); grid on;


