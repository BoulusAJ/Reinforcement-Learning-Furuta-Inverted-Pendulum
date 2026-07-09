function trainFurutaDetailed1c500HzTheta1OffsetGentle()
%TRAINFURUTADETAILED1C500HZTHETA1OFFSETGENTLE Gentle 1c upright fine-tune.

cfg = makeFurutaDetailed1c500HzTheta1OffsetGentleTD3Config();
trainFurutaDirectTD3WithConfig(cfg);
end
