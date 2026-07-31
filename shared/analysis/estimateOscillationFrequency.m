function freqHz = estimateOscillationFrequency(t, x)
%ESTIMATEOSCILLATIONFREQUENCY Estimate dominant zero-crossing frequency.

t = t(:);
x = x(:);
n = min(numel(t), numel(x));
if n < 3
    freqHz = NaN;
    return;
end

t = t(1:n);
x = x(1:n);
valid = isfinite(t) & isfinite(x);
t = t(valid);
x = x(valid);
if numel(t) < 3 || peakToPeak(x) < 1e-12
    freqHz = 0;
    return;
end

signX = sign(x);
signX(signX == 0) = 1;
crossings = find(signX(1:end-1) .* signX(2:end) < 0);
duration = t(end) - t(1);
if duration <= 0
    freqHz = NaN;
else
    freqHz = numel(crossings) / (2 * duration);
end
end
