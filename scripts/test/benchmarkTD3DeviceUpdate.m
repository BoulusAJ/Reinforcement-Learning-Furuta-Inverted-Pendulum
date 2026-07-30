%% Benchmark TD3-like network update cost on CPU and GPU
% This benchmark isolates the actor/critic neural-network update cost from
% Simulink simulation cost. It uses deterministic random mini-batches and a
% small TD3-like actor plus two critics with SGDM updates.

scriptDir = fileparts(mfilename("fullpath"));
repoRoot = fileparts(fileparts(scriptDir));
cd(repoRoot)
addpath(genpath(fullfile(repoRoot, "scripts")))

rng(0, "twister");

cfg = makeFurutaConfig();

bench = struct();
bench.NumObs = cfg.Observation.Dimension;
bench.NumAct = 1;
bench.BatchSize = cfg.Agent.MiniBatchSize;
bench.HiddenUnits = [64 128];
bench.WarmupIterations = 10;
bench.TimedIterations = 100;
bench.ActorLearnRate = cfg.Agent.ActorLearnRate;
bench.CriticLearnRate = cfg.Agent.CriticLearnRate;
bench.Momentum = 0.9;

devices = "cpu";
try
    gpuInfo = gpuDevice();
    devices = ["cpu", "gpu"];
    fprintf("GPU detected: %s\n", gpuInfo.Name);
catch err
    fprintf("No usable GPU detected for this MATLAB session: %s\n", err.message);
end

rows = table();

for hiddenUnits = bench.HiddenUnits
    for device = devices
        fprintf("\nBenchmarking hiddenUnits=%d on %s...\n", hiddenUnits, device);
        result = runDeviceBenchmark(bench, hiddenUnits, device);
        rows = [rows; struct2table(result)]; %#ok<AGROW>
        disp(struct2table(result))
    end
end

diagnosticDir = fullfile(cfg.ResultsRoot, "diagnostics");
if ~isfolder(diagnosticDir)
    mkdir(diagnosticDir);
end

timestamp = string(datetime("now", "Format", "yyyyMMdd_HHmmss"));
outCsv = fullfile(diagnosticDir, "td3_device_update_benchmark_" + timestamp + ".csv");
outMat = fullfile(diagnosticDir, "td3_device_update_benchmark_" + timestamp + ".mat");

writetable(rows, outCsv);
save(outMat, "rows", "bench");

fprintf("\nSaved benchmark results:\n%s\n%s\n", outCsv, outMat);

%% Local functions

function result = runDeviceBenchmark(bench, hiddenUnits, device)
rng(0, "twister");

actor = createActorNet(bench.NumObs, bench.NumAct, hiddenUnits);
critic1 = createCriticNet(bench.NumObs, bench.NumAct, hiddenUnits);
critic2 = createCriticNet(bench.NumObs, bench.NumAct, hiddenUnits);

[obs, act, targetQ] = makeMiniBatch(bench.NumObs, bench.NumAct, bench.BatchSize);

if device == "gpu"
    obs = gpuArray(obs);
    act = gpuArray(act);
    targetQ = gpuArray(targetQ);
    actor = dlupdate(@gpuArray, actor);
    critic1 = dlupdate(@gpuArray, critic1);
    critic2 = dlupdate(@gpuArray, critic2);
end

obs = dlarray(obs, "CB");
act = dlarray(act, "CB");
targetQ = dlarray(targetQ, "CB");

actorVelocity = [];
critic1Velocity = [];
critic2Velocity = [];

for i = 1:bench.WarmupIterations
    [actor, critic1, critic2, actorVelocity, critic1Velocity, critic2Velocity] = ...
        td3LikeUpdate(actor, critic1, critic2, obs, act, targetQ, ...
        actorVelocity, critic1Velocity, critic2Velocity, bench);
end

if device == "gpu"
    wait(gpuDevice());
end

tic;
for i = 1:bench.TimedIterations
    [actor, critic1, critic2, actorVelocity, critic1Velocity, critic2Velocity] = ...
        td3LikeUpdate(actor, critic1, critic2, obs, act, targetQ, ...
        actorVelocity, critic1Velocity, critic2Velocity, bench);
end
if device == "gpu"
    wait(gpuDevice());
end
elapsedSeconds = toc;

result = struct();
result.Device = device;
result.HiddenUnits = hiddenUnits;
result.BatchSize = bench.BatchSize;
result.WarmupIterations = bench.WarmupIterations;
result.TimedIterations = bench.TimedIterations;
result.TotalSeconds = elapsedSeconds;
result.SecondsPerUpdate = elapsedSeconds / bench.TimedIterations;
result.UpdatesPerSecond = bench.TimedIterations / elapsedSeconds;
end

function [actor, critic1, critic2, actorVelocity, critic1Velocity, critic2Velocity] = td3LikeUpdate( ...
    actor, critic1, critic2, obs, act, targetQ, actorVelocity, critic1Velocity, critic2Velocity, bench)

[critic1Grad, critic2Grad] = dlfeval(@criticGradients, critic1, critic2, obs, act, targetQ);
[critic1, critic1Velocity] = sgdmupdate(critic1, critic1Grad, critic1Velocity, ...
    bench.CriticLearnRate, bench.Momentum);
[critic2, critic2Velocity] = sgdmupdate(critic2, critic2Grad, critic2Velocity, ...
    bench.CriticLearnRate, bench.Momentum);

[actorGrad] = dlfeval(@actorGradients, actor, critic1, obs);
[actor, actorVelocity] = sgdmupdate(actor, actorGrad, actorVelocity, ...
    bench.ActorLearnRate, bench.Momentum);
end

function [critic1Grad, critic2Grad] = criticGradients(critic1, critic2, obs, act, targetQ)
q1 = forward(critic1, obs, act);
q2 = forward(critic2, obs, act);
loss1 = mean((q1 - targetQ).^2, "all");
loss2 = mean((q2 - targetQ).^2, "all");
critic1Grad = dlgradient(loss1, critic1.Learnables);
critic2Grad = dlgradient(loss2, critic2.Learnables);
end

function actorGrad = actorGradients(actor, critic, obs)
policyAct = forward(actor, obs);
q = forward(critic, obs, policyAct);
loss = -mean(q, "all");
actorGrad = dlgradient(loss, actor.Learnables);
end

function [obs, act, targetQ] = makeMiniBatch(numObs, numAct, batchSize)
obs = single(randn(numObs, batchSize));
act = single(2 * rand(numAct, batchSize) - 1);
targetQ = single(randn(1, batchSize));
end

function net = createActorNet(numObs, numAct, hiddenUnits)
layers = [
    featureInputLayer(numObs, Normalization="none", Name="observation")
    fullyConnectedLayer(hiddenUnits, Name="actor_fc1")
    reluLayer(Name="actor_relu1")
    fullyConnectedLayer(hiddenUnits, Name="actor_fc2")
    reluLayer(Name="actor_relu2")
    fullyConnectedLayer(numAct, Name="actor_fc3")
    tanhLayer(Name="action")
    ];
net = dlnetwork(layers);
end

function net = createCriticNet(numObs, numAct, hiddenUnits)
obsPath = [
    featureInputLayer(numObs, Normalization="none", Name="observation")
    fullyConnectedLayer(hiddenUnits, Name="critic_obs_fc1")
    reluLayer(Name="critic_obs_relu1")
    ];

actPath = [
    featureInputLayer(numAct, Normalization="none", Name="action")
    fullyConnectedLayer(hiddenUnits, Name="critic_act_fc1")
    ];

commonPath = [
    additionLayer(2, Name="critic_add")
    reluLayer(Name="critic_relu2")
    fullyConnectedLayer(hiddenUnits, Name="critic_fc2")
    reluLayer(Name="critic_relu3")
    fullyConnectedLayer(1, Name="q_value")
    ];

graph = layerGraph(obsPath);
graph = addLayers(graph, actPath);
graph = addLayers(graph, commonPath);
graph = connectLayers(graph, "critic_obs_relu1", "critic_add/in1");
graph = connectLayers(graph, "critic_act_fc1", "critic_add/in2");
net = dlnetwork(graph);
end
