function agent = createZeroActionDDPGAgentFuruta(obsInfo, actInfo, sampleTime)
%CREATEZEROACTIONDDPGAGENTFURUTA Build a DDPG agent that outputs zero action.
%
% Use this only for Simulink smoke tests before training. The actor's final
% layer is initialized with zero weights and zero bias, so the normalized
% action is zero for any observation when action limits are symmetric.

numObs = obsInfo.Dimension(1);
numAct = actInfo.Dimension(1);

zeroActionLayer = fullyConnectedLayer(numAct, Name="zero_action_fc");
zeroActionLayer.Weights = zeros(numAct, numObs);
zeroActionLayer.Bias = zeros(numAct, 1);

actorNetwork = [
    featureInputLayer(numObs, Name="observation")
    zeroActionLayer
    tanhLayer
    scalingLayer(Name="action", Scale=(actInfo.UpperLimit - actInfo.LowerLimit) / 2, ...
        Bias=(actInfo.UpperLimit + actInfo.LowerLimit) / 2)
    ];

actor = rlContinuousDeterministicActor(actorNetwork, obsInfo, actInfo);

obsPath = [
    featureInputLayer(numObs, Name="observation")
    fullyConnectedLayer(16, Name="obs_fc1")
    reluLayer(Name="obs_relu1")
    ];

actPath = [
    featureInputLayer(numAct, Name="action")
    fullyConnectedLayer(16, Name="act_fc1")
    ];

commonPath = [
    additionLayer(2, Name="add")
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

agentOptions = rlDDPGAgentOptions(SampleTime=sampleTime);
agentOptions.NoiseOptions.StandardDeviation = 0;

agent = rlDDPGAgent(actor, critic, agentOptions);
end
