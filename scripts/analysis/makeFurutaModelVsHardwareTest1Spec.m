function spec = makeFurutaModelVsHardwareTest1Spec()
%MAKEFURUTAMODELVSHARDWARETEST1SPEC Definition for the first comparison test.

spec = struct();
spec.TestName = "test1_constant_current_0p2A_disable_0p8s";
spec.Duration = 4.0;
spec.CurrentCommand = 0.2;
spec.EnableDisableTime = 0.8;
spec.Description = "Constant 0.2 A current command, enabled at start, disabled at 0.8 s.";
spec.Purpose = [ ...
    "Compare model and real-system current/angle response.", ...
    "Estimate friction/damping mismatch from the post-disable free response.", ...
    "Inspect sinusoidal behavior in theta2 speed after the motor is disabled."];
end
