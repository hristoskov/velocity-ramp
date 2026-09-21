
#include <math.h>
#include <stddef.h>

#include "cppmodel/CModel.h"

#define VELOCITY_EPSILON 1e-3f
#define VELOCITY_SETTLE_BAND 20.0f

typedef struct
{
    unsigned long startTime_ms;
    float desiredVelocity;
} VelocityLevel_ts;

static const VelocityLevel_ts VELOCITY_SCHEDULE[] = {
    {0, 50.0f},
    {300, 150.0f},
    {600, 30.0f},
    {900, 0.0f},
};
#define VELOCITY_SCHEDULE_LEN (sizeof(VELOCITY_SCHEDULE) / sizeof(VELOCITY_SCHEDULE[0]))

// The control system function implemented in the controller
static float RampStep(float current, float target, float maxDelta)
{
    float delta = target - current;
    if (delta > maxDelta)
    {
        return current + maxDelta;
    }
    if (delta < -maxDelta)
    {
        return current - maxDelta;
    }
    return target;
}

CMODEL_CYCLIC()
{
    static float actualVelocity = 0.0f;
    static uint8_t isAccelerating = 1;
    static unsigned long latchedLevelStartTime_ms = (unsigned long)-1;

    unsigned long levelStartTime_ms = VELOCITY_SCHEDULE[0].startTime_ms;
    float desiredVelocityFallback = VELOCITY_SCHEDULE[0].desiredVelocity;
    for (size_t i = 0; i < VELOCITY_SCHEDULE_LEN; i++)
    {
        if (currentTime_ms >= VELOCITY_SCHEDULE[i].startTime_ms)
        {
            levelStartTime_ms = VELOCITY_SCHEDULE[i].startTime_ms;
            desiredVelocityFallback = VELOCITY_SCHEDULE[i].desiredVelocity;
        }
    }

    float maxAcceleration = CppModel_getParameterF32(self, "Max Acceleration [m/s^2]", 2.0f) * 1000.0f;
    uint32_t accelerationSettleTime_ms = CppModel_getParameterU32(self, "Acceleration Window [ms]", 100);
    uint32_t decelerationSettleTime_ms = CppModel_getParameterU32(self, "Braking Window [ms]", 100);

    float desiredVelocity = CppModel_getInputF32(self, "Desired Velocity [mm/s]", desiredVelocityFallback);

    float previousVelocity = actualVelocity;
    actualVelocity = RampStep(actualVelocity, desiredVelocity, maxAcceleration * 0.001f);

    if (levelStartTime_ms != latchedLevelStartTime_ms)
    {
        isAccelerating = desiredVelocity >= previousVelocity;
        latchedLevelStartTime_ms = levelStartTime_ms;
    }
    uint32_t settleTime_ms = isAccelerating ? accelerationSettleTime_ms : decelerationSettleTime_ms;

    unsigned long timeSinceLevelChange_ms = currentTime_ms - levelStartTime_ms;
    uint8_t settleDeadlinePassed = timeSinceLevelChange_ms >= settleTime_ms;

    CppModel_setOutputF32(self, "Actual Velocity [mm/s]", actualVelocity);

    // --- Visualization only: acceleration/braking band overlays, safe to comment out ---
    uint8_t accelerationWindowActive = isAccelerating && (timeSinceLevelChange_ms < accelerationSettleTime_ms);
    uint8_t brakingWindowActive = !isAccelerating && (timeSinceLevelChange_ms < decelerationSettleTime_ms);
    float accelerationWindow = accelerationWindowActive ? VELOCITY_SETTLE_BAND : 0.0f;
    float brakingWindow = brakingWindowActive ? -VELOCITY_SETTLE_BAND : 0.0f;

    CppModel_setOutputF32(self, "Acc Window [ms]", accelerationWindow);
    CppModel_setOutputF32(self, "Brake Window [ms]", brakingWindow);
    // --- end visualization block ---

    uint8_t settledInTime = !settleDeadlinePassed || fabsf(actualVelocity - desiredVelocity) <= VELOCITY_EPSILON;

    CppModel_setOutputU8(self, "CppModel.StepResult", (uint8_t)settledInTime);
}

CMODEL_SIMULATE("velocity_ramp_controller", 1200, 1)
