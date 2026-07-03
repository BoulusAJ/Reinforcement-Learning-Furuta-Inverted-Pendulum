function x0 = rampConsistentFilterX0(sysd, u0, udot, Ts)
    A = sysd.A;
    B = sysd.B;

    du = Ts * udot;

    xSlope = (eye(size(A)) - A) \ (B * du);
    x0 = (eye(size(A)) - A) \ (B * u0 - xSlope);
    x0 = single(x0); % cast to single
end