function [tCommon, absProduct] = alignProduct(tA, a, tB, b)
%ALIGNPRODUCT Align two scalar time series and return abs(a*b).

tA = tA(:);
a = a(:);
tB = tB(:);
b = b(:);

nA = min(numel(tA), numel(a));
nB = min(numel(tB), numel(b));
if nA < 2 || nB < 2
    tCommon = 0;
    absProduct = 0;
    return;
end

tA = tA(1:nA);
a = a(1:nA);
tB = tB(1:nB);
b = b(1:nB);

tStart = max(tA(1), tB(1));
tEnd = min(tA(end), tB(end));
idx = tA >= tStart & tA <= tEnd;
if nnz(idx) < 2
    tCommon = 0;
    absProduct = 0;
    return;
end

tCommon = tA(idx);
aCommon = a(idx);
bCommon = interp1(tB, b, tCommon, "linear", "extrap");
absProduct = abs(aCommon .* bCommon);
end
