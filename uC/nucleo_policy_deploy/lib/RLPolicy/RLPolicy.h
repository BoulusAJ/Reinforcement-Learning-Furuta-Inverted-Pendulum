#pragma once

#include <cstddef>

class RLPolicy
{
public:
    static constexpr int InputSize = 7;

    float forward(const float observation[InputSize]) const;
    float actionToCurrent(float action) const;
    float applyCurrentOffset(float current) const;
    float clampCurrent(float current, float limitAbs) const;
};
