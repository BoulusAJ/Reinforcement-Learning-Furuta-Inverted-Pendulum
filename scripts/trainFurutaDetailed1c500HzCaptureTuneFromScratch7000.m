function trainFurutaDetailed1c500HzCaptureTuneFromScratch7000()
%TRAINFURUTADETAILED1C500HZCAPTURETUNEFROMSCRATCH7000 Fine-tune latest 1c
% scratch7000 agent with upright capture/balance reward shaping.

cfg = makeFurutaDetailed1c500HzCaptureTuneFromScratch7000TD3Config();
trainFurutaDirectTD3WithConfig(cfg);
end
