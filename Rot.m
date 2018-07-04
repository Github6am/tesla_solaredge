function R = Rot(axis,phi)
% Rotation Matrix - Drehmatrix um die x,y,z Achse
%
% Usage Example:
%   Rz = Rot('z', 45 * pi/180)   % Operator rotates xy-plane
% 
% Background:
%   https://de.wikipedia.org/wiki/Drehmatrix
%
% Author:
%   Andreas Merz, 2018, GPL

dim=3;
if isstr(axis),
  axis=double(axis - 'x' + 1);
end

s=sin(phi);
c=cos(phi);

switch axis
  case 1,    R=[ 1  0  0 ; 0  c -s ;  0  s  c ];
  case 2,    R=[ c  0  s ; 0  1  0 ; -s  0  c ];
  case 3,    R=[ c -s  0 ; s  c  0 ;  0  0  1 ];
  otherwise, R=eye(dim);
end
return
