function trainFurutaDetailed1d500HzLongImeasScratch7000()
%TRAINFURUTADETAILED1D500HZLONGIMEASSCRATCH7000 Train long scratch TD3 on
% the detailed 1d 500 Hz model path with I_meas as the 8th observation.

cfg = makeFurutaDetailed1d500HzLongImeasScratch7000TD3Config();
trainFurutaDirectTD3WithConfig(cfg);
end
