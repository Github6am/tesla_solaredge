function [ y, ik] = remove_zero_readings(x,of,interpolate)
  % sometimes all 8 sensor values are zero, then interpolate or remove them
  %
  % Arguments:
  %   x:  typically a matrix with a sequence of measurement rows 
  %   of: [1] column index where brittle data starts, or vector of indices.
  %   interpolate: [0] flag, 1 will interpolate, preserving matrix size
  %
  % Usage example:
  %   x=rand(8,4); x(:,1)=1:8;
  %   x([3 4 6],:)=0   % introduce data gaps
  %   [y,ik]=remove_zero_readings(x)
  %   [y,ik]=remove_zero_readings(x,1,1)
  %
  % Background:
  %   - why those zeros occur in logged data but not in ksysguard is not yet clear.
  %   - we do not use interp1 but simply replace consecutive zero rows 
  %     all with the same mean values
  
  if ~exist('of','var')
    of=1;  
  end
  if ~exist('interpolate','var')
    interpolate=0;  % 0: delete zero rows
  end
  sz=size(x);
  col=of+(0:7);
  if length(of>1)
    col=of;   % select these columns
  end
  if sz(2)<8
    col=of:sz(2);
  end
  corrupt=0;   % local counter flag
  corrcnt=0;   % ovarall counter
  ik=[];       % indices of corrupted or kept data rows, respective
  if interpolate > 0
    i1=1;      % last index with valid data
    for i = 1:(sz(1)-1)
      if x(i,col) == 0
        corrupt = corrupt+1;
        corrcnt = corrcnt+1;
        ik=[ ik ; i ];  % collect korrupted indices
      else  % valid row
        if corrupt > 0
          % previous rows were corrupted, interpolate
          for j=(i1+1):(i-1)
            x(j,col) = (x(i1,col) + x(i,col))/2;  % replace zero row with mean
          end
          corrupt=0;
        end
        i1=i;  % remember this valid row.
      end
    end
    %ik=transpose(1:sz(1)); % trivial: we kept all rows
    y=x;

  else   % do not interpolate, but delete rows with zero data
    n=vecnorm(x(:,col),1,2);
    ik = find(n > 0);
    corrcnt=sz(1)-length(ik);
    y=x(ik,:);
  end  
  printf("# found %d / %d corrupted rows\n", corrcnt, sz(1));
end
