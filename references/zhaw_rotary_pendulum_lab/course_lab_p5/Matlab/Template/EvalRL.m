function [sA,pA,sB] = EvalRL(z,p)
% Returns all relavant root locus information
% Input:
% Z: Vector of zero locations
% P: Vector of pole locations
% Output:
% sA: Intersection on real axis of asymptotes
% pA: phase(s) of asymptotes
% sB: Break-in or breakaway candidate points
    syms sb % Symbolic variable to calc sb
    f = 0;
    for i = 1:length(p) % Summing all pole terms
        f = f+1/(sb-p(i));
    end
    for i = 1:length(z) % Summing all zero terms
        f = f-1/(sb-z(i));
    end
    sB = solve(f,sb); % Solving symbolically
    sB = vpa(sB);     % Solving numerically
    
    % Calculating asymptotes
    sA = (sum(p)-sum(z))/(length(p)-length(z));
    L = length(p)-length(z);
    pA = [];
    if L > 0
        for i=0:L-1
            pA = [pA (2*i+1)*180/L];
        end
    end
end