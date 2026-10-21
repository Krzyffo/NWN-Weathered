// wthr_chat: module OnPlayerChat, test commands for the weather materials.
//   /dust 0.6         make yourself dusty (0..1)
//   /snow 0.6         make yourself snowy (0..1)
//   /dust 0.6 near    the same on the nearest other creature (players too)
//   /clean            remove dust and snow from yourself
//   /clean near       ... from the nearest creature
//   /wthr mats        list your materials (add "near" for the nearest creature)
// If the module already has an OnPlayerChat script, add this line to it:
//     ExecuteScript("wthr_chat", OBJECT_SELF);

#include "wthr_inc"

// The word after the command, and whether "near" follows.
string WthrArg(string sMsg, int nSkip)
{
    string s = GetStringRight(sMsg, GetStringLength(sMsg) - nSkip);
    while (GetStringLeft(s, 1) == " ") s = GetStringRight(s, GetStringLength(s) - 1);
    int nSpace = FindSubString(s, " ");
    return nSpace < 0 ? s : GetStringLeft(s, nSpace);
}

void main()
{
    object oPC = GetPCChatSpeaker();
    string sMsg = GetStringLowerCase(GetPCChatMessage());
    int bDust = GetStringLeft(sMsg, 5) == "/dust";
    int bSnow = GetStringLeft(sMsg, 5) == "/snow";
    int bClean = GetStringLeft(sMsg, 6) == "/clean";
    int bMats = GetStringLeft(sMsg, 10) == "/wthr mats";
    if (!bDust && !bSnow && !bClean && !bMats) return;
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

    if (bMats)
    {
        string sList = WthrMaterials(oTarget);
        SendMessageToPC(oPC, GetName(oTarget) + " (appearance " + IntToString(GetAppearanceType(oTarget))
                             + "): " + (sList == ";" ? "no materials found" : sList));
        return;
    }

    float fDust = GetLocalFloat(oTarget, WTHR_VAR_DUST);
    float fSnow = GetLocalFloat(oTarget, WTHR_VAR_SNOW);
    if (bClean)
    {
        fDust = 0.0;
        fSnow = 0.0;
    }
    else
    {
        float fValue = StringToFloat(WthrArg(sMsg, 5));
        if (bDust) fDust = fValue;
        else       fSnow = fValue;
    }
    WthrSet(oTarget, fDust, fSnow);
    SendMessageToPC(oPC, GetName(oTarget) + ": dust " + FloatToString(GetLocalFloat(oTarget, WTHR_VAR_DUST), 0, 2)
                         + ", snow " + FloatToString(GetLocalFloat(oTarget, WTHR_VAR_SNOW), 0, 2) + ".");
}
