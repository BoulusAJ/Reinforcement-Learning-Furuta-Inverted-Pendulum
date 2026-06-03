function agent = createDDPGAgentFuruta(obsInfo, actInfo, sampleTime)
%CREATEDDPGAGENTFURUTA Build a DDPG agent for continuous Furuta control.
%
% This is a conservative starter. Tune network size, learning rates, and
% noise after the simulation model is validated.

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

obsPath = [
    featureInputLayer(numObs, Name="observation")
    fullyConnectedLayer(128, Name="obs_fc1")
    reluLayer(Name="obs_relu1")
    ];

actPath = [
    featureInputLayer(numAct, Name="action")
    fullyConnectedLayer(128, Name="act_fc1")
    ];

commonPath = [
    additionLayer(2, Name="add")
    reluLayer
    fullyConnectedLayer(128)
    reluLayer
    fullyConnectedLayer(1, Name="q_value")
    ];

criticNetwork = layerGraph(obsPath);
criticNetwork = addLayers(criticNetwork, actPath);
criticNetwork = addLayers(criticNetwork, commonPath);
criticNetwork = connectLayers(criticNetwork, "obs_relu1", "add/in1");
criticNetwork = connectLayers(criticNetwork, "act_fc1", "add/in2");

critic = rlQValueFunction(criticNetwork, obsInfo, actInfo, ...
    ObservationInputNames="observation", ActionInputNames="action");

agentOptions = rlDDPGAgentOptions( ...
    SampleTime=sampleTime, ...
    DiscountFactor=0.99, ...
    MiniBatchSize=256, ...
    ExperienceBufferLength=1e6);

agentOptions.ActorOptimizerOptions.LearnRate = 1e-4;
agentOptions.CriticOptimizerOptions.LearnRate = 1e-3;
agentOptions.NoiseOptions.StandardDeviation = 0.2;
agentOptions.NoiseOptions.StandardDeviationDecayRate = 1e-5;

agent = rlDDPGAgent(actor, critic, agentOptions);
end
