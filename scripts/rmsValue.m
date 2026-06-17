function y = rmsValue(x)
%RMSVALUE Root-mean-square ignoring non-finite values.

x = x(:);
x = x(isfinite(x));
if isempty(x)
    y = NaN;
else
    y = sqrt(mean(x.^2));
end
end
