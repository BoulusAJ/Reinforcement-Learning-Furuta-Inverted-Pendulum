function trainFurutaSimple1b500HzTheta1OffsetScratchCurrent1p5()
%TRAINFURUTASIMPLE1B500HZTHETA1OFFSETSCRATCHCURRENT1P5 Train simple 1b
% 500Hz_long-style scratch comparison with theta1 offset and 1.5 A current cap.

cfg = makeFurutaSimple1b500HzTheta1OffsetScratchCurrent1p5TD3Config();
trainFurutaDirectTD3WithConfig(cfg);
end
