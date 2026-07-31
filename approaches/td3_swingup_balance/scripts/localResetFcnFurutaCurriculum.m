function in = localResetFcnFurutaCurriculum(in)
%LOCALRESETFCNFURUTACURRICULUM Curriculum reset function for Simulink RL.
%
% The base workspace must contain curriculumParams with fields:
%   Theta1ErrorRange, Theta2ErrorRange, Omega1ErrorRange, Omega2ErrorRange
%
% Update the variable names below to match the Simulink model.

curriculumParams = evalin("base", "curriculumParams");

if isfield(curriculumParams, "mode") && string(curriculumParams.mode) == "fixed"
    theta1Error0 = curriculumParams.Theta1Error0;
    theta2Error0 = curriculumParams.Theta2Error0;
    omega1Error0 = curriculumParams.Omega1Error0;
    omega2Error0 = curriculumParams.Omega2Error0;
else
    theta1Error0 = sampleUniform(curriculumParams.Theta1ErrorRange);
    theta2Error0 = sampleUniform(curriculumParams.Theta2ErrorRange);
    omega1Error0 = sampleUniform(curriculumParams.Omega1ErrorRange);
    omega2Error0 = sampleUniform(curriculumParams.Omega2ErrorRange);
end

% Initial references are zero for theta1 and both velocities. Error signals
% are controller-facing post-summation values, so raw states use the inverse
% sign of the sampled errors.
theta1_0 = -theta1Error0;
theta2_0 = pi - theta2Error0;
omega1_0 = -omega1Error0;
omega2_0 = -omega2Error0;

in = setVariable(in, "theta1_0", theta1_0);
in = setVariable(in, "theta2_0", theta2_0);
in = setVariable(in, "omega1_0", omega1_0);
in = setVariable(in, "omega2_0", omega2_0);
in = setVariable(in, "theta1Error0", theta1Error0);
in = setVariable(in, "theta2Error0", theta2Error0);
in = setVariable(in, "omega1Error0", omega1Error0);
in = setVariable(in, "omega2Error0", omega2Error0);

% Many reference scripts use theta0 as a 2-vector of initial joint angles.
in = setVariable(in, "theta0", [theta1_0; theta2_0]);

% Added an initial value for omega0
in = setVariable(in, "omega0", [omega1_0; omega2_0]);

if isfield(curriculumParams, "DomainRandomization") && ...
        isfield(curriculumParams.DomainRandomization, "Enabled") && ...
        curriculumParams.DomainRandomization.Enabled
    in = applyDetailedDomainRandomization(in, curriculumParams.DomainRandomization);
end
end

function value = sampleUniform(range)
value = range(1) + rand() * (range(2) - range(1));
end

function in = applyDetailedDomainRandomization(in, dr)
if isfield(dr, "CurrentBiasRange_A")
    in = setVariable(in, "currentBias_A", sampleUniform(dr.CurrentBiasRange_A));
end

if isfield(dr, "CurrentNoiseStdRange_A")
    in = setVariable(in, "currentNoiseStd_A", sampleUniform(dr.CurrentNoiseStdRange_A));
end

if isfield(dr, "IStaticCompRange_A")
    in = setVariable(in, "I_static_comp_A", sampleUniform(dr.IStaticCompRange_A));
end

if isfield(dr, "Theta1ViscousScalingFactorRange") || ...
        isfield(dr, "Theta1CoulombStaticScalingFactorRange")
    param = evalin("base", "param");

    if isfield(dr, "Theta1ViscousScalingFactorRange")
        param.Friction.Theta1.viscousScalingFactor = ...
            sampleUniform(dr.Theta1ViscousScalingFactorRange);
    end

    if isfield(dr, "Theta1CoulombStaticScalingFactorRange")
        param.Friction.Theta1.coulombStaticScalingFactor = ...
            sampleUniform(dr.Theta1CoulombStaticScalingFactorRange);
    end

    in = setVariable(in, "param", param);
end
end
