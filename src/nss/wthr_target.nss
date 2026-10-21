// wthr_target: module OnPlayerTarget (set by wthr_modload, or add this
// line to the module's own OnPlayerTarget script:
//     ExecuteScript("wthr_target", OBJECT_SELF);
// Finishes a DM's test command (/dust 0.5, /snow 1 ...) on the creature,
// placeable or door they clicked. Clicks that aren't ours are left to the
// module's script.

#include "wthr_cmd_inc"

void main()
{
    WthrRunOriginal(EVENT_SCRIPT_MODULE_ON_PLAYER_TARGET);

    object oPC = GetLastPlayerToSelectTarget();
    string sPending = GetLocalString(oPC, WTHR_VAR_PENDING);
    if (sPending == "") return;  // not our cursor
    DeleteLocalString(oPC, WTHR_VAR_PENDING);

    object oTarget = GetTargetingModeSelectedObject();
    int nType = GetObjectType(oTarget);
    if (nType != OBJECT_TYPE_CREATURE && nType != OBJECT_TYPE_PLACEABLE && nType != OBJECT_TYPE_DOOR)
    {
        SendMessageToPC(oPC, "Cancelled " + sPending + ".");
        return;
    }
    WthrRunCommand(oPC, oTarget, sPending);
}
