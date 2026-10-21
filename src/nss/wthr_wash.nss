// wthr_wash: washes dust, snow and blood off a creature, over a couple of
// seconds. Put it on
//   - a trigger's OnEnter: a stream, a pool, a waterfall;
//   - a placeable's OnUsed: a washbasin, a water barrel;
//   - a conversation's "Actions Taken": a bathhouse keeper.
// Optional float on the trigger, placeable or speaker:
//   WTHR_WASH  share removed, 0..1 (default 1 = all of it). A shallow
//              stream might take 0.5.

#include "wthr_inc"

const float WTHR_WASH_SECONDS = 2.0;

void main()
{
    object oCreature = GetEnteringObject();
    if (!GetIsObjectValid(oCreature)) oCreature = GetLastUsedBy();
    if (!GetIsObjectValid(oCreature)) oCreature = GetPCSpeaker();
    if (!GetIsObjectValid(oCreature) && GetObjectType(OBJECT_SELF) == OBJECT_TYPE_CREATURE)
        oCreature = OBJECT_SELF;
    if (GetObjectType(oCreature) != OBJECT_TYPE_CREATURE || GetLocalInt(oCreature, WTHR_SKIP)) return;

    float fShare = GetLocalFloat(OBJECT_SELF, "WTHR_WASH");
    if (fShare <= 0.0) fShare = 1.0;
    int bDirty = WthrHasAny(oCreature);
    WthrClean(oCreature, fShare, fShare, fShare, WTHR_WASH_SECONDS);
    if (bDirty && GetIsPC(oCreature))
        FloatingTextStringOnCreature("You wash yourself clean.", oCreature, FALSE);
}
