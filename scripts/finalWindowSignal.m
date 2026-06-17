function [tWindow, xWindow] = finalWindowSignal(t, x, windowSeconds)
%FINALWINDOWSIGNAL Return samples in the final windowSeconds of a signal.

t = t(:);
x = x(:);
n = min(numel(t), numel(x));
if n == 0
    tWindow = [];
    xWindow = [];
    return;
end

t = t(1:n);
x = x(1:n);
windowStart = max(t(1), t(end) - windowSeconds);
idx = t >= windowStart;
tWindow = t(idx);
xWindow = x(idx);
end
