function agent = createTD3AgentFuruta(obsInfo, actInfo, agentCfg)
%CREATETD3AGENTFURUTA Build a TD3 agent for Furuta stabilization.
%
% TD3 keeps the deterministic actor interface used by DDPG, but adds twin
% critics, delayed policy updates, and smoothed target actions.

numObs = obsInfo.Dimension(1);
numAct = actInfo.Dimension(1);

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

actor = rlContinuousDeterministicActor(actorNetwork, obsInfo, actInfo);

critic1 = createCritic(obsInfo, actInfo, "critic1");
critic2 = createCritic(obsInfo, actInfo, "critic2");

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
    NumWarmStartSteps=agentCfg.NumWarmStartSteps);

agentOptions.ActorOptimizerOptions.LearnRate = 1e-4;
for idx = 1:numel(agentOptions.CriticOptimizerOptions)
    agentOptions.CriticOptimizerOptions(idx).LearnRate = 1e-3;
end

agentOptions.ExplorationModel.StandardDeviationMin = 0.01;
agentOptions.ExplorationModel.StandardDeviation = 0.05;

agentOptions.TargetPolicySmoothModel.StandardDeviation = agentCfg.TargetPolicyNoiseStd;
agentOptions.TargetPolicySmoothModel.LowerLimit = -agentCfg.TargetPolicyNoiseLimit;
agentOptions.TargetPolicySmoothModel.UpperLimit = agentCfg.TargetPolicyNoiseLimit;

agent = rlTD3Agent(actor, [critic1 critic2], agentOptions);
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

function value = getAgentOption(agentCfg, fieldName, defaultValue)
if isfield(agentCfg, fieldName)
    value = agentCfg.(fieldName);
else
    value = defaultValue;
end
end
