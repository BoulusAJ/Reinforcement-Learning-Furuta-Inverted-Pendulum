function trainFurutaDetailed1c500HzTheta1OffsetWarm()
%TRAINFURUTADETAILED1C500HZTHETA1OFFSETWARM Fine-tune 500Hz_long on 1c
% detailed model near the observed theta1 offset balance region.

cfg = makeFurutaDetailed1c500HzTheta1OffsetWarmTD3Config();
trainFurutaDirectTD3WithConfig(cfg);
end
