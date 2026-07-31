function report = verifyFurutaActorExport(agentFile, weights, options)
%VERIFYFURUTAACTOREXPORT Compare exported raw actor to MATLAB actor output.

arguments
    agentFile (1,1) string
    weights struct
    options.NumTests (1,1) double = 1000
    options.PrintExamples (1,1) logical = false
    options.Tolerance (1,1) double = 1e-5
end

S = load(agentFile, "agent");
actor = getActor(S.agent);

obsBatch = localRandomObservations(options.NumTests);
err = zeros(options.NumTests, 1);
agentActions = zeros(options.NumTests, 1);
rawActions = zeros(options.NumTests, 1);

for k = 1:options.NumTests
    obs = obsBatch(:, k);
    aAgent = getAction(actor, {obs});
    if iscell(aAgent)
        aAgent = aAgent{1};
    end
    if isa(aAgent, "dlarray")
        aAgent = extractdata(aAgent);
    end
    if isa(aAgent, "gpuArray")
        aAgent = gather(aAgent);
    end
    aAgent = double(aAgent);
    aRaw = furutaActorForwardRaw(obs, weights);

    agentActions(k) = aAgent;
    rawActions(k) = aRaw;
    err(k) = abs(aAgent - aRaw);

    if options.PrintExamples && k <= 5
        fprintf("case %d: agent=% .8f raw=% .8f err=%g\n", ...
            k, aAgent, aRaw, err(k));
    end
end

report = struct();
report.NumTests = options.NumTests;
report.MaxAbsError = max(err);
report.MeanAbsError = mean(err);
report.Tolerance = options.Tolerance;
report.Passed = report.MaxAbsError <= options.Tolerance;
report.AgentActionRange = [min(agentActions), max(agentActions)];
report.RawActionRange = [min(rawActions), max(rawActions)];

if ~report.Passed
    warning("verifyFurutaActorExport:Mismatch", ...
        "Raw actor mismatch: max abs error %.6g exceeds tolerance %.6g.", ...
        report.MaxAbsError, report.Tolerance);
end
end

function obs = localRandomObservations(n)
theta1 = pi * (2*rand(1, n)-1);
theta2 = pi * (2*rand(1, n)-1);
omega1 = 20 * (2*rand(1, n)-1);
omega2 = 20 * (2*rand(1, n)-1);
prevAction = 2*rand(1, n)-1;

obs = [
    sin(theta1)
    cos(theta1)
    sin(theta2)
    cos(theta2)
    omega1
    omega2
    prevAction
    ];
end
