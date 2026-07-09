function trainFurutaDetailed1c500HzLongScratch7000()
%TRAINFURUTADETAILED1C500HZLONGSCRATCH7000 Train long scratch TD3 on the
% detailed 1c 500 Hz model path.

cfg = makeFurutaDetailed1c500HzLongScratch7000TD3Config();
trainFurutaDirectTD3WithConfig(cfg);
end
