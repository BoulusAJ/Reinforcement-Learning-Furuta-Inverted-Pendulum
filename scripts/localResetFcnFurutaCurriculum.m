function in = localResetFcnFurutaCurriculum(in)
%LOCALRESETFCNFURUTACURRICULUM Curriculum reset function for Simulink RL.
%
% The base workspace must contain curriculumParams with fields:
%   Theta1ErrorRange, Theta2ErrorRange, Omega1ErrorRange, Omega2ErrorRange
%
% Update the variable names below to match the Simulink model.

curriculumParams = evalin("base", "curriculumParams");

theta1Error0 = sampleUniform(curriculumParams.Theta1ErrorRange);
theta2Error0 = sampleUniform(curriculumParams.Theta2ErrorRange);
omega1Error0 = sampleUniform(curriculumParams.Omega1ErrorRange);
omega2Error0 = sampleUniform(curriculumParams.Omega2ErrorRange);

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
end

function value = sampleUniform(range)
value = range(1) + rand() * (range(2) - range(1));
end
