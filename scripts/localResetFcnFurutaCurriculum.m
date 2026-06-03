function in = localResetFcnFurutaCurriculum(in)
%LOCALRESETFCNFURUTACURRICULUM Curriculum reset function for Simulink RL.
%
% The base workspace must contain curriculumParams with fields:
%   Theta2ErrorRange, Omega2Range
%
% Update the variable names below to match the Simulink model.

curriculumParams = evalin("base", "curriculumParams");

theta1_0 = 0;
theta2Error0 = sampleUniform(curriculumParams.Theta2ErrorRange);
theta2_0 = pi + theta2Error0;
omega1_0 = 0;
omega2_0 = sampleUniform(curriculumParams.Omega2Range);

in = setVariable(in, "theta1_0", theta1_0);
in = setVariable(in, "theta2_0", theta2_0);
in = setVariable(in, "omega1_0", omega1_0);
in = setVariable(in, "omega2_0", omega2_0);

% Many reference scripts use theta0 as a 2-vector of initial joint angles.
in = setVariable(in, "theta0", [theta1_0; theta2_0]);
end

function value = sampleUniform(range)
value = range(1) + rand() * (range(2) - range(1));
end
