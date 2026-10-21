// wthr_cmd_inc: the test commands, shared by wthr_chat (typing them) and
// wthr_target (a DM picking who they apply to).
//
//   /wthr             dust, snow and spread, and what builds up here
//   /wthr mats        the materials found
//   /dust 0.6         set dust (0..1)
//   /snow 0.6         set snow (0..1)
//   /storm 1          set how far the dust spreads (0 ground up .. 1 all over)
//   /blood 0.5        set own blood, from wounds (0..1)
//   /spatter 0.5 g    set others' blood of one colour (0..1): r, g, y or
//                     w (default red); the other colours stay
//   /dry 0.5          set how dried the blood is (0 fresh .. 1 dried)
//   /clean            remove everything
//
// For DMs, or everyone when the module has WTHR_DEBUG = 1. A DM gets a
// cursor to pick the creature; others use them on themselves. "near" uses
// the nearest creature instead, "me" yourself.

#include "wthr_inc"

const string WTHR_VAR_PENDING = "WTHR_PENDING";  // string on a DM: command waiting for a target

string WthrNum(float f)
{
    return FloatToString(f, 0, 2);
}

// TRUE if sMsg is sCommand, alone or followed by a space.
int WthrIsCommand(string sMsg, string sCommand)
{
    int nLength = GetStringLength(sCommand);
    return GetStringLeft(sMsg, nLength) == sCommand
        && (GetStringLength(sMsg) == nLength || GetSubString(sMsg, nLength, 1) == " ");
}

int WthrIsTestCommand(string sMsg)
{
    return WthrIsCommand(sMsg, "/dust") || WthrIsCommand(sMsg, "/snow") || WthrIsCommand(sMsg, "/storm")
        || WthrIsCommand(sMsg, "/blood") || WthrIsCommand(sMsg, "/spatter") || WthrIsCommand(sMsg, "/dry")
        || WthrIsCommand(sMsg, "/clean") || WthrIsCommand(sMsg, "/wthr");
}

int WthrIsDM(object oPC)
{
    return GetIsDM(oPC) || GetIsDMPossessed(oPC);
}

int WthrCanTest(object oPC)
{
    return WthrIsDM(oPC) || GetLocalInt(GetModule(), WTHR_DEBUG);
}

// Word nWord after the command (1 = the first).
string WthrArg(string sMsg, int nWord = 1)
{
    string s = sMsg;
    int i;
    for (i = 0; i < nWord; i++)
    {
        int nSpace = FindSubString(s, " ");
        if (nSpace < 0) return "";
        s = GetStringRight(s, GetStringLength(s) - nSpace - 1);
        while (GetStringLeft(s, 1) == " ") s = GetStringRight(s, GetStringLength(s) - 1);
    }
    int nEnd = FindSubString(s, " ");
    return nEnd < 0 ? s : GetStringLeft(s, nEnd);
}

void WthrReport(object oPC, object oTarget)
{
    SendMessageToPC(oPC, GetName(oTarget) + ": dust " + WthrNum(GetLocalFloat(oTarget, WTHR_VAR_DUST))
                         + ", snow " + WthrNum(GetLocalFloat(oTarget, WTHR_VAR_SNOW))
                         + ", spread " + WthrNum(GetLocalFloat(oTarget, WTHR_VAR_SPREAD))
                         + "; blood " + WthrNum(GetLocalFloat(oTarget, WTHR_VAR_WOUNDS))
                         + ", spatter red " + WthrNum(GetLocalFloat(oTarget, WthrSpatterVar(1)))
                         + " green " + WthrNum(GetLocalFloat(oTarget, WthrSpatterVar(2)))
                         + " yellow " + WthrNum(GetLocalFloat(oTarget, WthrSpatterVar(3)))
                         + " white " + WthrNum(GetLocalFloat(oTarget, WthrSpatterVar(4)))
                         + ", dried " + WthrNum(GetLocalFloat(oTarget, WTHR_VAR_DRY))
                         + "; bleeds " + IntToString(WthrBloodKind(oTarget)) + " (0 none, 1 red, 2 green, 3 yellow, 4 white).");
}

void WthrReportPlace(object oPC, object oTarget)
{
    object oArea = GetArea(oTarget);
    string sWeather = "clear";
    if (GetWeather(oArea) == WEATHER_RAIN) sWeather = "rain";
    if (GetWeather(oArea) == WEATHER_SNOW) sWeather = "snow";
    object oZone = WthrZone(oTarget);
    string sWho = WthrIsPartyMember(oTarget) || GetLocalInt(oTarget, WTHR_WEATHERS)
                  ? "weathers" : "keeps its starting look";
    SendMessageToPC(oPC, "Here: dust " + WthrNum(WthrBaseRate(oTarget, oArea, WTHR_DUST_RATE))
                         + "/min travelling, snow " + WthrNum(WthrBaseRate(oTarget, oArea, WTHR_SNOW_RATE))
                         + "/min" + (WthrIsStorm(oTarget, oArea) ? ", dust storm" : "")
                         + (GetIsObjectValid(oZone) ? " (zone " + GetTag(oZone) + ")" : "")
                         + "; weather " + sWeather
                         + " adds dust " + WthrNum(WthrWeatherRate(oArea, "WTHR_RAIN_DUST", "WTHR_SNOWFALL_DUST"))
                         + ", snow " + WthrNum(WthrWeatherRate(oArea, "WTHR_RAIN_SNOW", "WTHR_SNOWFALL_SNOW"))
                         + "/min; " + (WthrIsOutdoors(oArea) ? "outdoors" : "indoors")
                         + "; " + sWho + ".");
}

// ---- /dirt: anyone checks how dirty they are ---------------------------------

string WthrPercent(float f)
{
    return IntToString(FloatToInt(f * 100.0 + 0.5)) + "%";
}

string WthrDustWords(float f)
{
    if (f <= 0.0)  return "no dust";
    if (f < 0.25)  return "a little dusty";
    if (f < 0.5)   return "dusty";
    if (f < 0.8)   return "very dusty";
    return "caked in dust";
}

string WthrSnowWords(float f)
{
    if (f <= 0.0)  return "no snow";
    if (f < 0.25)  return "a dusting of snow";
    if (f < 0.5)   return "snowy";
    if (f < 0.8)   return "covered in snow";
    return "buried in snow";
}

// "mostly your own" -> "mostly its own", for companions.
string WthrReplaceYour(string s)
{
    int n = FindSubString(s, "your own");
    if (n < 0) return s;
    return GetStringLeft(s, n) + "its own" + GetStringRight(s, GetStringLength(s) - n - 8);
}

// "red", "red and green", "red, green and yellow" for the colours of the
// creature's spatter that show.
string WthrSpatterColours(object oCreature)
{
    string sList = "";
    int nCount = 0;
    int n;
    for (n = 1; n <= WTHR_BLOOD_KINDS; n++)
        if (GetLocalFloat(oCreature, WthrSpatterVar(n)) >= 0.05) nCount++;
    int nDone = 0;
    for (n = 1; n <= WTHR_BLOOD_KINDS; n++)
    {
        if (GetLocalFloat(oCreature, WthrSpatterVar(n)) < 0.05) continue;
        string sName = n == 1 ? "red" : (n == 2 ? "green" : (n == 3 ? "yellow" : "white"));
        nDone++;
        if (nDone == 1) sList = sName;
        else if (nDone == nCount) sList += " and " + sName;
        else sList += ", " + sName;
    }
    return sList;
}

string WthrBloodWords(float fWounds, float fSpatter, float fDry)
{
    float fBlood = fWounds > fSpatter ? fWounds : fSpatter;
    if (fBlood <= 0.0) return "no blood";
    string sHow = "a few spots of blood";
    if (fBlood >= 0.25) sHow = "bloodstained";
    if (fBlood >= 0.5)  sHow = "covered in blood";
    if (fBlood >= 0.8)  sHow = "drenched in blood";
    string sWhose = fSpatter > fWounds ? "mostly others'" : "mostly your own";
    return sHow + " (" + sWhose + (fDry >= 0.6 ? ", dried" : "") + ")";
}

// One line for a creature: "You: dusty (34%), a dusting of snow (10%), no blood."
void WthrDirtLine(object oPC, object oCreature, string sWho)
{
    float fDust = GetLocalFloat(oCreature, WTHR_VAR_DUST);
    float fSnow = GetLocalFloat(oCreature, WTHR_VAR_SNOW);
    string sDust = WthrDustWords(fDust) + (fDust > 0.0 ? " (" + WthrPercent(fDust) + ")" : "");
    string sSnow = WthrSnowWords(fSnow) + (fSnow > 0.0 ? " (" + WthrPercent(fSnow) + ")" : "");
    if (fDust > 0.0 && GetLocalFloat(oCreature, WTHR_VAR_SPREAD) >= 0.5) sDust += ", all over";
    string sBlood = WthrBloodWords(GetLocalFloat(oCreature, WTHR_VAR_WOUNDS),
                                   WthrSpatter(oCreature), GetLocalFloat(oCreature, WTHR_VAR_DRY));
    if (oCreature != oPC) sBlood = WthrReplaceYour(sBlood);
    string sColours = WthrSpatterColours(oCreature);
    if (sColours != "") sBlood += ", spattered " + sColours;
    SendMessageToPC(oPC, sWho + ": " + sDust + ", " + sSnow + ", " + sBlood + ".");
}

// The player and everyone travelling with them.
void WthrDirtReport(object oPC)
{
    WthrDirtLine(oPC, oPC, "You");
    int nType;
    for (nType = ASSOCIATE_TYPE_HENCHMAN; nType <= ASSOCIATE_TYPE_DOMINATED; nType++)
    {
        int nMax = nType == ASSOCIATE_TYPE_HENCHMAN ? WTHR_MAX_HENCHMEN : 1;
        int n;
        for (n = 1; n <= nMax; n++)
        {
            object oAssociate = GetAssociate(nType, oPC, n);
            if (!GetIsObjectValid(oAssociate)) break;
            WthrDirtLine(oPC, oAssociate, GetName(oAssociate));
        }
    }
}

// Runs a test command (lower case, as typed) on oTarget for oPC.
void WthrRunCommand(object oPC, object oTarget, string sMsg)
{
    if (WthrIsCommand(sMsg, "/wthr"))
    {
        if (WthrArg(sMsg) == "mats")
        {
            string sList = WthrMaterials(oTarget);
            SendMessageToPC(oPC, GetName(oTarget) + " (appearance " + IntToString(GetAppearanceType(oTarget))
                                 + "): " + (sList == ";" ? "no materials found" : sList));
            return;
        }
        WthrReport(oPC, oTarget);
        if (WthrIsObject(oTarget))
            SendMessageToPC(oPC, WthrIsStatic(oTarget)
                ? "Static: the game draws it as part of the area, so no look shows. Untick Static in the toolset."
                : "Not static: its look shows.");
        else
            WthrReportPlace(oPC, oTarget);
        return;
    }

    // A set look replaces the starting one; its blood is watched from now on.
    SetLocalInt(oTarget, WTHR_VAR_SEEN, TRUE);
    WthrHookDamage(oTarget);

    if (WthrIsCommand(sMsg, "/clean"))
    {
        SetLocalInt(oTarget, WTHR_VAR_FADE, GetLocalInt(oTarget, WTHR_VAR_FADE) + 1);  // stop a running fade
        SetLocalFloat(oTarget, WTHR_VAR_WOUNDS, 0.0);
        WthrSetSpatterTotal(oTarget, 0.0);
        SetLocalFloat(oTarget, WTHR_VAR_DRY, 0.0);
        WthrSet(oTarget, 0.0, 0.0, 0.0);
        WthrReport(oPC, oTarget);
        return;
    }

    string sValue = WthrArg(sMsg);
    float fValue = StringToFloat(sValue);
    if (sValue == "" || fValue < 0.0 || fValue > 1.0)
    {
        SendMessageToPC(oPC, "Give a value from 0 to 1, for example /dust 0.5.");
        return;
    }
    if (WthrIsCommand(sMsg, "/blood"))
        SetLocalFloat(oTarget, WTHR_VAR_WOUNDS, fValue);
    else if (WthrIsCommand(sMsg, "/spatter"))
    {
        int nKind = WthrBloodKindFromLetter(WthrArg(sMsg, 2));
        if (nKind == 0) nKind = 1;  // red
        SetLocalFloat(oTarget, WthrSpatterVar(nKind), fValue);  // that colour only; the others stay
    }
    else if (WthrIsCommand(sMsg, "/dry"))
        SetLocalFloat(oTarget, WTHR_VAR_DRY, fValue);
    else if (WthrIsCommand(sMsg, "/dust"))
        SetLocalFloat(oTarget, WTHR_VAR_DUST, fValue);
    else if (WthrIsCommand(sMsg, "/snow"))
        SetLocalFloat(oTarget, WTHR_VAR_SNOW, fValue);
    else
        SetLocalFloat(oTarget, WTHR_VAR_SPREAD, fValue);
    WthrSend(oTarget, TRUE);
    WthrReport(oPC, oTarget);
}
