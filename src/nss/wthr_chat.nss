// wthr_chat: module OnPlayerChat (set by wthr_modload, or add this line to
// the module's own OnPlayerChat script:
//     ExecuteScript("wthr_chat", OBJECT_SELF);
//
// For everyone:
//   /dirt        how dusty and snowy you and your companions are
//   /brush       brush yourself down; needs a clothes brush
// Test commands (/dust, /snow, /storm, /clean, /wthr): see wthr_cmd_inc. A
// DM gets a cursor to pick the creature (wthr_target does the rest); add
// "near" for the nearest creature or "me" for yourself instead.

#include "wthr_cmd_inc"

void main()
{
    WthrRunOriginal(EVENT_SCRIPT_MODULE_ON_PLAYER_CHAT);

    object oPC = GetPCChatSpeaker();
    string sMsg = GetStringLowerCase(GetPCChatMessage());

    if (WthrIsCommand(sMsg, "/dirt"))
    {
        SetPCChatMessage("");
        WthrDirtReport(oPC);
        return;
    }

    if (WthrIsCommand(sMsg, "/brush"))
    {
        SetPCChatMessage("");
        if (!GetIsObjectValid(GetItemPossessedBy(oPC, WTHR_BRUSH_TAG)))
            SendMessageToPC(oPC, "You need a clothes brush.");
        else if (!WthrBrush(oPC))
            SendMessageToPC(oPC, "Your clothes are clean already.");
        return;
    }

    if (!WthrIsTestCommand(sMsg) || !WthrCanTest(oPC)) return;
    SetPCChatMessage("");

    object oTarget = oPC;
    if (FindSubString(sMsg, " near") >= 0)
    {
        oTarget = GetNearestObject(OBJECT_TYPE_CREATURE, oPC);
        if (!GetIsObjectValid(oTarget))
        {
            SendMessageToPC(oPC, "No creature nearby.");
            return;
        }
    }
    else if (WthrIsDM(oPC) && FindSubString(sMsg, " me") < 0)
    {
        SetLocalString(oPC, WTHR_VAR_PENDING, sMsg);
        SendMessageToPC(oPC, "Pick a creature, placeable or door for " + sMsg + " (right-click to cancel).");
        EnterTargetingMode(oPC, OBJECT_TYPE_CREATURE | OBJECT_TYPE_PLACEABLE | OBJECT_TYPE_DOOR,
                           MOUSECURSOR_MAGIC, MOUSECURSOR_NOMAGIC);
        return;
    }
    WthrRunCommand(oPC, oTarget, sMsg);
}
