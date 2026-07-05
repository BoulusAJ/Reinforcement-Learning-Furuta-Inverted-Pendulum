function trainFurutaDetailed1c500HzNearUpright()
%TRAINFURUTADETAILED1C500HZNEARUPRIGHT Fine-tune the original 500Hz_long
% agent on the detailed 1c model from near-upright initial conditions only.

cfg = makeFurutaDetailed1c500HzNearUprightTD3Config();
trainFurutaDirectTD3WithConfig(cfg);
end
