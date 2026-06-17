function y = peakToPeak(x)
%PEAKTOPEAK Peak-to-peak range ignoring non-finite values.

x = x(:);
x = x(isfinite(x));
if isempty(x)
    y = NaN;
else
    y = max(x) - min(x);
end
end
