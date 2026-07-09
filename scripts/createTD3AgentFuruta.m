function agent = createTD3AgentFuruta(obsInfo, actInfo, agentCfg)
%CREATETD3AGENTFURUTA Build a TD3 agent for Furuta direct swing-up.
%
% TD3 keeps the deterministic actor interface used by DDPG, but adds twin
% critics, delayed policy updates, and smoothed target actions.

numObs = obsInfo.Dimension(1);
numAct = actInfo.Dimension(1);

networkStyle = getAgentOption(agentCfg, "NetworkStyle", "custom");
if string(networkStyle) == "default"
    agent = createDefaultTD3Agent(obsInfo, actInfo, agentCfg);
    return;
end

if string(networkStyle) == "custom_mlp"
    actorHiddenLayerSizes = getAgentOption(agentCfg, "ActorHiddenLayerSizes", 128);
    criticHiddenLayerSizes = getAgentOption(agentCfg, "CriticHiddenLayerSizes", actorHiddenLayerSizes);
    actorNetwork = createDefaultStyleActorNetwork(numObs, numAct, actorHiddenLayerSizes);
    critic1 = createDefaultStyleCritic(obsInfo, actInfo, "critic1", criticHiddenLayerSizes);
    critic2 = createDefaultStyleCritic(obsInfo, actInfo, "critic2", criticHiddenLayerSizes);
else
    actorNetwork = [
    featureInputLayer(numObs, Name="observation")
    fullyConnectedLayer(128)
    reluLayer
    fullyConnectedLayer(128)
    reluLayer
    fullyConnectedLayer(numAct)
    tanhLayer
    scalingLayer(Name="action", Scale=(actInfo.UpperLimit - actInfo.LowerLimit) / 2, ...
        Bias=(actInfo.UpperLimit + actInfo.LowerLimit) / 2)
    ];

    critic1 = createCritic(obsInfo, actInfo, "critic1");
    critic2 = createCritic(obsInfo, actInfo, "critic2");
end

actor = rlContinuousDeterministicActor(actorNetwork, obsInfo, actInfo);

useDevice = getAgentOption(agentCfg, "UseDevice", "cpu");
actor.UseDevice = useDevice;
critic1.UseDevice = useDevice;
critic2.UseDevice = useDevice;

agentOptions = rlTD3AgentOptions( ...
    SampleTime=agentCfg.SampleTime, ...
    DiscountFactor=0.99, ...
    LearningFrequency=agentCfg.LearningFrequency, ...
    PolicyUpdateFrequency=agentCfg.PolicyUpdateFrequency, ...
    TargetUpdateFrequency=agentCfg.TargetUpdateFrequency, ...
    TargetSmoothFactor=agentCfg.TargetSmoothFactor, ...
    MiniBatchSize=agentCfg.MiniBatchSize, ...
    ExperienceBufferLength=agentCfg.ExperienceBufferLength, ...
    NumWarmStartSteps=agentCfg.NumWarmStartSteps, ...
    NumEpoch=agentCfg.NumEpoch, ...
    MaxMiniBatchPerEpoch=agentCfg.MaxMiniBatchPerEpoch);

agentOptions.ActorOptimizerOptions.Algorithm = "sgdm";
agentOptions.ActorOptimizerOptions.LearnRate = agentCfg.ActorLearnRate;
agentOptions.ActorOptimizerOptions.GradientThreshold = agentCfg.GradientThreshold;
for idx = 1:numel(agentOptions.CriticOptimizerOptions)
    agentOptions.CriticOptimizerOptions(idx).Algorithm = "sgdm";
    agentOptions.CriticOptimizerOptions(idx).LearnRate = agentCfg.CriticLearnRate;
    agentOptions.CriticOptimizerOptions(idx).GradientThreshold = agentCfg.GradientThreshold;
end

agentOptions.ExplorationModel.StandardDeviationMin = agentCfg.ExplorationNoiseStdMin;
agentOptions.ExplorationModel.StandardDeviation = agentCfg.ExplorationNoiseStd;
agentOptions.ExplorationModel.StandardDeviationDecayRate = agentCfg.ExplorationNoiseDecayRate;

agentOptions.TargetPolicySmoothModel.StandardDeviation = agentCfg.TargetPolicyNoiseStd;
agentOptions.TargetPolicySmoothModel.LowerLimit = -agentCfg.TargetPolicyNoiseLimit;
agentOptions.TargetPolicySmoothModel.UpperLimit = agentCfg.TargetPolicyNoiseLimit;

agent = rlTD3Agent(actor, [critic1 critic2], agentOptions);
end

function agent = createDefaultTD3Agent(obsInfo, actInfo, agentCfg)
initOpts = rlAgentInitializationOptions(NumHiddenUnit=agentCfg.NumHiddenUnit);
agentOptions = createTD3OptionsFuruta(agentCfg);
agent = rlTD3Agent(obsInfo, actInfo, initOpts, agentOptions);
end

function actorNetwork = createDefaultStyleActorNetwork(numObs, numAct, hiddenLayerSizes)
hiddenLayerSizes = reshape(double(hiddenLayerSizes), 1, []);

layers = [
    featureInputLayer(numObs, Name="input_1")
    ];

for idx = 1:numel(hiddenLayerSizes)
    layers = [
        layers
        fullyConnectedLayer(hiddenLayerSizes(idx), Name=localActorFcName(idx))
        reluLayer(Name=localActorReluName(idx, numel(hiddenLayerSizes)))
        ]; %#ok<AGROW>
end

actorNetwork = [
    layers
    fullyConnectedLayer(numAct, Name="output")
    tanhLayer(Name="tanh")
    ];
end

function critic = createDefaultStyleCritic(obsInfo, actInfo, criticName, hiddenLayerSizes)
numObs = obsInfo.Dimension(1);
numAct = actInfo.Dimension(1);
hiddenLayerSizes = reshape(double(hiddenLayerSizes), 1, []);
if isempty(hiddenLayerSizes)
    error("createTD3AgentFuruta:InvalidCriticHiddenLayerSizes", ...
        "CriticHiddenLayerSizes must contain at least one hidden layer.");
end

obsPath = [
    featureInputLayer(numObs, Name=criticName + "_input_1")
    fullyConnectedLayer(hiddenLayerSizes(1), Name=criticName + "_fc_1")
    ];

actPath = [
    featureInputLayer(numAct, Name=criticName + "_input_2")
    fullyConnectedLayer(hiddenLayerSizes(1), Name=criticName + "_fc_2")
    ];

commonPath = [
    concatenationLayer(1, 2, Name=criticName + "_concat")
    reluLayer(Name=criticName + "_relu_body")
    ];

for idx = 2:numel(hiddenLayerSizes)
    commonPath = [
        commonPath
        fullyConnectedLayer(hiddenLayerSizes(idx), Name=criticName + "_" + localCriticFcName(idx))
        reluLayer(Name=criticName + "_" + localCriticReluName(idx, numel(hiddenLayerSizes)))
        ]; %#ok<AGROW>
end

commonPath = [
    commonPath
    fullyConnectedLayer(1, Name=criticName + "_q_value")
    ];

criticNetwork = layerGraph(obsPath);
criticNetwork = addLayers(criticNetwork, actPath);
criticNetwork = addLayers(criticNetwork, commonPath);
criticNetwork = connectLayers(criticNetwork, criticName + "_fc_1", criticName + "_concat/in1");
criticNetwork = connectLayers(criticNetwork, criticName + "_fc_2", criticName + "_concat/in2");

critic = rlQValueFunction(criticNetwork, obsInfo, actInfo, ...
    ObservationInputNames=criticName + "_input_1", ...
    ActionInputNames=criticName + "_input_2");
end

function critic = createCritic(obsInfo, actInfo, criticName)
numObs = obsInfo.Dimension(1);
numAct = actInfo.Dimension(1);

obsPath = [
    featureInputLayer(numObs, Name=criticName + "_observation")
    fullyConnectedLayer(128, Name=criticName + "_obs_fc1")
    reluLayer(Name=criticName + "_obs_relu1")
    ];

actPath = [
    featureInputLayer(numAct, Name=criticName + "_action")
    fullyConnectedLayer(128, Name=criticName + "_act_fc1")
    ];

commonPath = [
    additionLayer(2, Name=criticName + "_add")
    reluLayer(Name=criticName + "_relu2")
    fullyConnectedLayer(128, Name=criticName + "_fc2")
    reluLayer(Name=criticName + "_relu3")
    fullyConnectedLayer(1, Name=criticName + "_q_value")
    ];

criticNetwork = layerGraph(obsPath);
criticNetwork = addLayers(criticNetwork, actPath);
criticNetwork = addLayers(criticNetwork, commonPath);
criticNetwork = connectLayers(criticNetwork, criticName + "_obs_relu1", criticName + "_add/in1");
criticNetwork = connectLayers(criticNetwork, criticName + "_act_fc1", criticName + "_add/in2");

critic = rlQValueFunction(criticNetwork, obsInfo, actInfo, ...
    ObservationInputNames=criticName + "_observation", ...
    ActionInputNames=criticName + "_action");
end

function name = localActorFcName(idx)
if idx == 1
    name = "fc_1";
elseif idx == 2
    name = "fc_body";
else
    name = "fc_body_" + string(idx - 1);
end
end

function name = localActorReluName(idx, numHiddenLayers)
if idx == numHiddenLayers
    name = "body_output";
elseif idx == 1
    name = "relu_body";
else
    name = "relu_body_" + string(idx);
end
end

function name = localCriticFcName(idx)
if idx == 2
    name = "fc_body";
else
    name = "fc_body_" + string(idx - 1);
end
end

function name = localCriticReluName(idx, numHiddenLayers)
if idx == numHiddenLayers
    name = "body_output";
else
    name = "relu_body_" + string(idx);
end
end

function value = getAgentOption(agentCfg, fieldName, defaultValue)
if isfield(agentCfg, fieldName)
    value = agentCfg.(fieldName);
else
    value = defaultValue;
end
end
