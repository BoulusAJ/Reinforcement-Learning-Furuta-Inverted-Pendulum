function in = localResetFcnFurutaCurriculum(in)
%LOCALRESETFCNFURUTACURRICULUM Curriculum reset function for Simulink RL.
%
% The base workspace must contain curriculumParams with fields:
%   AlphaRange, AlphaDotRange
%
% Update the variable names below to match the Simulink model.

curriculumParams = evalin("base", "curriculumParams");

alpha0 = sampleUniform(curriculumParams.AlphaRange);
alphaDot0 = sampleUniform(curriculumParams.AlphaDotRange);
theta0 = 0;
thetaDot0 = 0;

in = setVariable(in, "theta0", theta0);
in = setVariable(in, "alpha0", alpha0);
in = setVariable(in, "thetaDot0", thetaDot0);
in = setVariable(in, "alphaDot0", alphaDot0);
end

function value = sampleUniform(range)
value = range(1) + rand() * (range(2) - range(1));
end
