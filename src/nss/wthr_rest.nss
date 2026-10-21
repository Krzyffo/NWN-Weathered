// wthr_rest: module OnPlayerRest (set by wthr_modload, or add this line
// to the module's own OnPlayerRest script:
//     ExecuteScript("wthr_rest", OBJECT_SELF);
// After a full rest the party is cleaner: the blood is gone (wounds tended,
// clothes scrubbed) and the snow melts by the fire. Indoors (an inn, a
// house) the dust goes too; outdoors it stays.

#include "wthr_inc"

void WthrRestClean(object oCreature, int bIndoors)
{
    if (!GetIsObjectValid(oCreature) || GetLocalInt(oCreature, WTHR_SKIP)) return;
    WthrClean(oCreature, bIndoors ? 1.0 : 0.0, 1.0, 1.0, 1.0);
}

void main()
{
    WthrRunOriginal(EVENT_SCRIPT_MODULE_ON_PLAYER_REST);
    if (GetLastRestEventType() != REST_EVENTTYPE_REST_FINISHED) return;

    object oPC = GetLastPCRested();
    int bIndoors = !WthrIsOutdoors(GetArea(oPC));
    WthrRestClean(oPC, bIndoors);
    int nType;
    for (nType = ASSOCIATE_TYPE_HENCHMAN; nType <= ASSOCIATE_TYPE_DOMINATED; nType++)
    {
        int nMax = nType == ASSOCIATE_TYPE_HENCHMAN ? WTHR_MAX_HENCHMEN : 1;
        int n;
        for (n = 1; n <= nMax; n++)
        {
            object oAssociate = GetAssociate(nType, oPC, n);
            if (!GetIsObjectValid(oAssociate)) break;
            WthrRestClean(oAssociate, bIndoors);
        }
    }
}
