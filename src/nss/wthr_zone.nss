// wthr_zone: a trigger's OnEnter and OnExit, for dust and snow in part of
// an area: a dune field, a wind-swept pass. While a creature is inside, the
// trigger's variables replace the area's:
//   WTHR_DUST_RATE   float, dust per minute of travel (-1 = none here)
//   WTHR_SNOW_RATE   float, snow per minute (-1 = none here)
//   WTHR_DUST_STORM  int, 1 = dust settles all over the body
// A variable the trigger doesn't set keeps the area's value.

#include "wthr_inc"

void main()
{
    object oEntering = GetEnteringObject();
    if (GetIsObjectValid(oEntering))
    {
        SetLocalObject(oEntering, WTHR_VAR_ZONE, OBJECT_SELF);
        return;
    }
    object oExiting = GetExitingObject();
    // Overlapping zones: leaving an older one doesn't end the newer one.
    if (GetLocalObject(oExiting, WTHR_VAR_ZONE) == OBJECT_SELF)
        DeleteLocalObject(oExiting, WTHR_VAR_ZONE);
}
