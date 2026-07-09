function trainFurutaDetailed1c500HzTheta1OffsetScratch()
%TRAINFURUTADETAILED1C500HZTHETA1OFFSETSCRATCH Train scratch TD3 on the 1c
% detailed model near the observed theta1 offset balance region.

cfg = makeFurutaDetailed1c500HzTheta1OffsetScratchTD3Config();
trainFurutaDirectTD3WithConfig(cfg);
end
