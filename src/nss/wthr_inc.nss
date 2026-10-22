// wthr_inc: dust, snow and blood on one creature at a time.
//
// Each creature texture of the base game has a material (built into the
// hak by tools/build.py) using the weather shaders, with values a script
// sets on a single creature (DustAmount, SnowAmount, BloodWounds, ...).
// The engine sends them to every player who sees that creature, so in
// multiplayer everyone sees the same dusty, snowy or bloodied creature.
//
// Dust and snow: players, their henchmen, companions, familiars and
// summons, and creatures flagged WTHR_WEATHERS = 1 change over time.
// Everything else gets a starting look when a player first comes near and
// keeps it. Designers decide where dust and snow build up; nothing is
// detected from tilesets.
//
// Blood: anyone. Physical damage leaves the creature's own blood on it
// (wounds), and a melee attacker gets the victim's blood on its hands,
// arms and front (spatter). Blood dries darker, and rain, rest, washing and
// the clothes brush clean it off. Players with gore off see none of it.
//
// Placeables and doors: a look set in their variables, fixed, never
// changed over time (WthrObjectLook):
//   WTHR_DUST, WTHR_SNOW, WTHR_BLOOD   0..1
//   WTHR_SPREAD         0..1: 0 = dust from the bottom up, 1 = all over
//   WTHR_DRY            0..1: 0 = fresh blood, 1 = dried
//   WTHR_BLOOD_COLOR    string R, G, Y or W (default R)
//
// Variables (floats unless noted; 0 or unset = nothing or the default,
// -1 = none even where a default would apply):
//
// On an area, or a trigger running wthr_zone (the trigger wins while a
// creature is inside it):
//   WTHR_DUST_RATE      dust per minute of travel (a quarter of it standing)
//   WTHR_SNOW_RATE      snow per minute
//   WTHR_DUST_STORM     int, 1 = dust settles all over the body, not just
//                       from the ground up
// On an area, or the module as the default for every area:
//   WTHR_RAIN_DUST      per minute while it rains; negative washes off
//   WTHR_RAIN_SNOW
//   WTHR_SNOWFALL_DUST  per minute while it snows
//   WTHR_SNOWFALL_SNOW
//   WTHR_RAIN_BLOOD     blood washed off per minute in the rain (default 0.1)
//   WTHR_IGNORE_WEATHER int on an area, 1 = the weather does nothing here
// On an area (the look of its own creatures) or a creature (its own look):
//   WTHR_START_DUST, WTHR_START_SNOW   0..1
//   WTHR_START_VARY     0..1, random variation (default 0.3)
// On a creature:
//   WTHR_WEATHERS       int, 1 = builds up and fades like a player
//   WTHR_SKIP           int, 1 = never touched
//   WTHR_BLOOD_COLOR    string R, G, Y, W or N (none): overrides the colour
//                       from appearance.2da
// On the module:
//   WTHR_FADE_DUST           dust lost per minute where none builds up (0.03)
//   WTHR_FADE_SNOW           the same for snow, outdoors (0.05)
//   WTHR_FADE_SNOW_INDOORS   in interiors and underground (0.4)
//   WTHR_BLOOD_DRY_MINUTES   real minutes for blood to dry (5; -1 = never)
//   WTHR_BLOOD_FULL_HP       how much damage, in multiples of a creature's
//                            max HP, takes its own blood from 0 to 1 (3).
//                            Healing doesn't remove blood, so it builds up
//                            over an adventure.
//   WTHR_BLOOD_SPATTER       how much spatter hits leave (multiplier, 1)
//   WTHR_BLOOD_OFF      int, 1 = no blood at all
//   WTHR_DEBUG          int, 1 = test commands for everyone, not just DMs

// ---- Names ------------------------------------------------------------------

// On each creature:
const string WTHR_VAR_DUST      = "WTHR_DUST";       // float: dust level
const string WTHR_VAR_SNOW      = "WTHR_SNOW";       // float: snow level
const string WTHR_VAR_SPREAD    = "WTHR_SPREAD";     // float: 0 ground up .. 1 all over
const string WTHR_VAR_WOUNDS    = "WTHR_WOUNDS";     // float: own blood
const string WTHR_VAR_SPAT      = "WTHR_SPAT_";      // + blood kind 1-4: others' blood of that colour
const string WTHR_VAR_DRY       = "WTHR_DRY";        // float: 0 fresh .. 1 dried
const string WTHR_VAR_SENT      = "WTHR_SENT_";      // + param name: value last sent
const string WTHR_VAR_MATERIALS = "WTHR_MATERIALS";  // string: materials last sent to
const string WTHR_VAR_SEEN      = "WTHR_SEEN";       // int: got its starting look
const string WTHR_VAR_ZONE      = "WTHR_ZONE";       // object: wthr_zone trigger it is in
const string WTHR_VAR_FADE      = "WTHR_FADE";       // int: number of the running fade
const string WTHR_VAR_QUEUED    = "WTHR_QUEUED";     // int: a send is scheduled
const string WTHR_VAR_DRYING    = "WTHR_DRYING";     // int: the drying loop runs
const string WTHR_VAR_HOOKED    = "WTHR_HOOKED";     // int: OnDamaged is ours
const string WTHR_VAR_ORIG_DMG  = "WTHR_ORIG_DAMAGED"; // string: its own OnDamaged script

const string WTHR_DUST_RATE      = "WTHR_DUST_RATE";
const string WTHR_SNOW_RATE      = "WTHR_SNOW_RATE";
const string WTHR_DUST_STORM     = "WTHR_DUST_STORM";
const string WTHR_IGNORE_WEATHER = "WTHR_IGNORE_WEATHER";
const string WTHR_START_DUST     = "WTHR_START_DUST";
const string WTHR_START_SNOW     = "WTHR_START_SNOW";
const string WTHR_START_VARY     = "WTHR_START_VARY";
const string WTHR_WEATHERS       = "WTHR_WEATHERS";
const string WTHR_SKIP           = "WTHR_SKIP";
const string WTHR_BLOOD_COLOR    = "WTHR_BLOOD_COLOR";
const string WTHR_BLOOD_OFF      = "WTHR_BLOOD_OFF";
const string WTHR_DEBUG          = "WTHR_DEBUG";

// Material parameters.
const string WTHR_PARAM_DUST    = "DustAmount";
const string WTHR_PARAM_SPREAD  = "DustSpread";
const string WTHR_PARAM_SNOW    = "SnowAmount";
const string WTHR_PARAM_WOUNDS  = "BloodWounds";
const string WTHR_PARAM_DRY     = "BloodDry";
const string WTHR_PARAM_OWN     = "BloodOwn";

const string WTHR_BRUSH_TAG = "wthr_brush";

// The per-player shader switch for gore (scriptableInt16): 1 hides blood.
const int WTHR_U_NO_GORE = SHADER_UNIFORM_16;

// Defaults.
const float WTHR_DEFAULT_VARY             = 0.3;
const float WTHR_DEFAULT_FADE_DUST        = 0.03;
const float WTHR_DEFAULT_FADE_SNOW        = 0.05;
const float WTHR_DEFAULT_FADE_SNOW_INSIDE = 0.4;
const float WTHR_DEFAULT_RAIN_BLOOD       = 0.1;
const float WTHR_DEFAULT_DRY_MINUTES      = 5.0;
const float WTHR_STANDING                 = 0.25;  // share of the dust rate while not moving
const float WTHR_STORM_RISE               = 0.25;  // per minute: dust spreads over the body in a storm
const float WTHR_SEND_STEP                = 0.02;  // smaller changes wait; each send is network traffic

const int WTHR_PART_HEAD  = 20;  // CREATURE_PART_HEAD
const int WTHR_PART_CLOAK = 21;  // the row of wthr_parts.2da after the head

// ---- Materials -------------------------------------------------------------

// Model part names, indexed like CREATURE_PART_* / ITEM_APPR_ARMOR_MODEL_*.
string WthrPartName(int nPart)
{
    switch (nPart)
    {
        case 0:  return "footr";
        case 1:  return "footl";
        case 2:  return "shinr";
        case 3:  return "shinl";
        case 4:  return "legl";
        case 5:  return "legr";
        case 6:  return "pelvis";
        case 7:  return "chest";
        case 8:  return "belt";
        case 9:  return "neck";
        case 10: return "forer";
        case 11: return "forel";
        case 12: return "bicepr";
        case 13: return "bicepl";
        case 14: return "shor";
        case 15: return "shol";
        case 16: return "handr";
        case 17: return "handl";
        case 18: return "robe";
        case WTHR_PART_HEAD: return "head";
    }
    return "";
}

// Adds each ";"-separated name of sAdd to the ";"-wrapped list sList,
// skipping "****" and duplicates.
string WthrAddNames(string sList, string sAdd)
{
    if (sAdd == "" || sAdd == "****") return sList;
    sAdd += ";";
    int nStart = 0;
    int nSep = FindSubString(sAdd, ";", nStart);
    while (nSep >= 0)
    {
        string sName = GetSubString(sAdd, nStart, nSep - nStart);
        if (sName != "" && FindSubString(sList, ";" + sName + ";") < 0)
            sList += sName + ";";
        nStart = nSep + 1;
        nSep = FindSubString(sAdd, ";", nStart);
    }
    return sList;
}

// The model prefix of a part-based creature, e.g. "pmd0" for a male dwarf
// of normal phenotype.
string WthrPartPrefix(object oCreature)
{
    string sGender = GetGender(oCreature) == GENDER_FEMALE ? "f" : "m";
    string sRace = GetStringLowerCase(Get2DAString("appearance", "RACE", GetAppearanceType(oCreature)));
    return "p" + sGender + sRace + IntToString(GetPhenoType(oCreature));
}

// A placeable's or door's textures, from its appearance: placeables.2da
// row for placeables; doortypes.2da row for tileset doors, else the
// genericdoors.2da row. Scripts can't ask for these directly, so they come
// from the object's saved fields.
string WthrObjectTextures(object oObject)
{
    json jObject = ObjectToJson(oObject);
    int nAppearance = JsonGetInt(JsonObjectGet(JsonObjectGet(jObject, "Appearance"), "value"));
    if (GetObjectType(oObject) == OBJECT_TYPE_PLACEABLE)
        return Get2DAString("wthr_plc", "TEXTURES", nAppearance);
    if (nAppearance > 0)
        return Get2DAString("wthr_door", "TEXTURES", nAppearance);
    int nGeneric = JsonGetInt(JsonObjectGet(JsonObjectGet(jObject, "GenericType"), "value"));
    return Get2DAString("wthr_gdoor", "TEXTURES", nGeneric);
}

int WthrIsObject(object o)
{
    int nType = GetObjectType(o);
    return nType == OBJECT_TYPE_PLACEABLE || nType == OBJECT_TYPE_DOOR;
}

int WthrIsPartBased(object oCreature)
{
    return GetStringUpperCase(Get2DAString("appearance", "MODELTYPE", GetAppearanceType(oCreature))) == "P";
}

// The equipped cloak if it shows.
object WthrShownCloak(object oCreature)
{
    object oCloak = GetItemInSlot(INVENTORY_SLOT_CLOAK, oCreature);
    if (GetIsObjectValid(oCloak) && !GetHiddenWhenEquipped(oCloak)) return oCloak;
    return OBJECT_INVALID;
}

// The textures on one part of a part-based creature (a wthr_* 2DA cell,
// "" for none): a body part 0-17, the head or the cloak. Helmets, robes
// and weapons have none: the engine doesn't pass a creature's material
// values on to their models.
// oArmor: its armor, sPrefix: WthrPartPrefix.
string WthrPartTextures(object oCreature, object oArmor, string sPrefix, int nPart)
{
    if (nPart == WTHR_PART_HEAD)
        return Get2DAString("wthr_head", sPrefix, GetCreatureBodyPart(WTHR_PART_HEAD, oCreature));
    if (nPart == WTHR_PART_CLOAK)
    {
        object oCloak = WthrShownCloak(oCreature);
        if (!GetIsObjectValid(oCloak)) return "";
        return Get2DAString("wthr_cloak", "TEXTURES", GetItemAppearance(oCloak, ITEM_APPR_TYPE_SIMPLE_MODEL, 0));
    }
    if (nPart > 17) return "";  // 18 is the robe
    // Armor decides each part it has a model for; the body shows through elsewhere.
    int nModel = 0;
    if (GetIsObjectValid(oArmor))
        nModel = GetItemAppearance(oArmor, ITEM_APPR_TYPE_ARMOR_MODEL, nPart);
    if (nModel <= 0)
        nModel = GetCreatureBodyPart(nPart, oCreature);
    if (nModel <= 0) return "";
    return Get2DAString("wthr_" + WthrPartName(nPart), sPrefix, nModel);
}

// The textures (= material names) the creature or object shows right now,
// as a ";"-wrapped list: ";pmh0_chest001;pmh0_pelvis001;".
string WthrMaterials(object oCreature)
{
    if (WthrIsObject(oCreature))
        return WthrAddNames(";", WthrObjectTextures(oCreature));
    string sList = ";";
    if (!WthrIsPartBased(oCreature))
        return WthrAddNames(sList, Get2DAString("wthr_appear", "TEXTURES", GetAppearanceType(oCreature)));

    string sPrefix = WthrPartPrefix(oCreature);
    object oArmor = GetItemInSlot(INVENTORY_SLOT_CHEST, oCreature);
    int nPart;
    for (nPart = 0; nPart <= WTHR_PART_CLOAK; nPart++)
        sList = WthrAddNames(sList, WthrPartTextures(oCreature, oArmor, sPrefix, nPart));
    return sList;
}

// Sends one value to every material in the list.
void WthrSetParam(object oCreature, string sList, string sParam, float fValue)
{
    int nStart = 1;
    int nSep = FindSubString(sList, ";", nStart);
    while (nSep >= 0)
    {
        string sMaterial = GetSubString(sList, nStart, nSep - nStart);
        if (sMaterial != "")
            SetMaterialShaderUniformVec4(oCreature, sMaterial, sParam, fValue);
        nStart = nSep + 1;
        nSep = FindSubString(sList, ";", nStart);
    }
}

// ---- Part values, per creature ----------------------------------------------

// Scratch locals while WthrSendParts runs, + material name.
const string WTHR_VAR_PART      = "WTHR_PART_";
const string WTHR_VAR_PART_LOW  = "WTHR_PART_LOW_";
const string WTHR_VAR_PART_HIGH = "WTHR_PART_HIGH_";
const string WTHR_VAR_PART_WND  = "WTHR_PART_WND_";
const string WTHR_VAR_PART_SPT  = "WTHR_PART_SPT_";
const string WTHR_VAR_PART_MESH = "WTHR_PART_MESH_";

float WthrMin(float a, float b)
{
    return a < b ? a : b;
}

float WthrMax(float a, float b)
{
    return a > b ? a : b;
}

// Notes that the materials in sCell are on part nPart (a wthr_parts.2da
// row); sMesh: where a cloak hangs, "MeshBase_MeshHeight".
void WthrPartNote(object oCreature, string sCell, int nPart, string sMesh)
{
    float fLow = StringToFloat(Get2DAString("wthr_parts", "LOW", nPart));
    float fHigh = StringToFloat(Get2DAString("wthr_parts", "HIGH", nPart));
    float fWounds = StringToFloat(Get2DAString("wthr_parts", "WOUNDS", nPart));
    float fSpatter = StringToFloat(Get2DAString("wthr_parts", "SPATTER", nPart));
    sCell += ";";
    int nStart = 0;
    int nSep = FindSubString(sCell, ";", nStart);
    while (nSep >= 0)
    {
        string s = GetSubString(sCell, nStart, nSep - nStart);
        if (s != "" && !GetLocalInt(oCreature, WTHR_VAR_PART + s))
        {
            SetLocalInt(oCreature, WTHR_VAR_PART + s, TRUE);
            SetLocalFloat(oCreature, WTHR_VAR_PART_LOW + s, fLow);
            SetLocalFloat(oCreature, WTHR_VAR_PART_HIGH + s, fHigh);
            SetLocalFloat(oCreature, WTHR_VAR_PART_WND + s, fWounds);
            SetLocalFloat(oCreature, WTHR_VAR_PART_SPT + s, fSpatter);
        }
        else if (s != "")
        {
            SetLocalFloat(oCreature, WTHR_VAR_PART_LOW + s, WthrMin(fLow, GetLocalFloat(oCreature, WTHR_VAR_PART_LOW + s)));
            SetLocalFloat(oCreature, WTHR_VAR_PART_HIGH + s, WthrMax(fHigh, GetLocalFloat(oCreature, WTHR_VAR_PART_HIGH + s)));
            SetLocalFloat(oCreature, WTHR_VAR_PART_WND + s, WthrMax(fWounds, GetLocalFloat(oCreature, WTHR_VAR_PART_WND + s)));
            SetLocalFloat(oCreature, WTHR_VAR_PART_SPT + s, WthrMax(fSpatter, GetLocalFloat(oCreature, WTHR_VAR_PART_SPT + s)));
        }
        if (s != "" && sMesh != "") SetLocalString(oCreature, WTHR_VAR_PART_MESH + s, sMesh);
        nStart = nSep + 1;
        nSep = FindSubString(sCell, ";", nStart);
    }
}

// One texture can be on several parts: both thighs, a thigh and a shoulder
// pad in some armour, the default male pelvis and some robes. Its material
// has the build's values for only one of those parts, which made such
// thighs gather dust only as it reached the shoulders. So a part-based
// creature's materials get the heights they cover on this creature (all
// their parts together) and the most blood any of those parts catches;
// a cloak gets where it hangs on this race's figure.
void WthrSendParts(object oCreature, string sList)
{
    if (WthrIsObject(oCreature) || !WthrIsPartBased(oCreature)) return;
    string sPrefix = WthrPartPrefix(oCreature);
    object oArmor = GetItemInSlot(INVENTORY_SLOT_CHEST, oCreature);
    int nPart;
    for (nPart = 0; nPart <= WTHR_PART_CLOAK; nPart++)
    {
        string sCell = WthrPartTextures(oCreature, oArmor, sPrefix, nPart);
        if (sCell == "") continue;
        string sMesh = "";
        if (nPart == WTHR_PART_CLOAK)
            sMesh = Get2DAString("wthr_cloak", sPrefix,
                GetItemAppearance(WthrShownCloak(oCreature), ITEM_APPR_TYPE_SIMPLE_MODEL, 0));
        WthrPartNote(oCreature, sCell, nPart, sMesh);
    }

    int nStart = 1;
    int nSep = FindSubString(sList, ";", nStart);
    while (nSep >= 0)
    {
        string s = GetSubString(sList, nStart, nSep - nStart);
        if (s != "" && GetLocalInt(oCreature, WTHR_VAR_PART + s))
        {
            SetMaterialShaderUniformVec4(oCreature, s, "PartLow", GetLocalFloat(oCreature, WTHR_VAR_PART_LOW + s));
            SetMaterialShaderUniformVec4(oCreature, s, "PartHigh", GetLocalFloat(oCreature, WTHR_VAR_PART_HIGH + s));
            SetMaterialShaderUniformVec4(oCreature, s, "WoundWeight", GetLocalFloat(oCreature, WTHR_VAR_PART_WND + s));
            SetMaterialShaderUniformVec4(oCreature, s, "SpatterWeight", GetLocalFloat(oCreature, WTHR_VAR_PART_SPT + s));
            string sMesh = GetLocalString(oCreature, WTHR_VAR_PART_MESH + s);
            int nMid = FindSubString(sMesh, "_");
            if (nMid > 0)
            {
                SetMaterialShaderUniformVec4(oCreature, s, "MeshBase", StringToFloat(GetStringLeft(sMesh, nMid)));
                SetMaterialShaderUniformVec4(oCreature, s, "MeshHeight", StringToFloat(GetSubString(sMesh, nMid + 1, 16)));
            }
            DeleteLocalInt(oCreature, WTHR_VAR_PART + s);
            DeleteLocalFloat(oCreature, WTHR_VAR_PART_LOW + s);
            DeleteLocalFloat(oCreature, WTHR_VAR_PART_HIGH + s);
            DeleteLocalFloat(oCreature, WTHR_VAR_PART_WND + s);
            DeleteLocalFloat(oCreature, WTHR_VAR_PART_SPT + s);
            DeleteLocalString(oCreature, WTHR_VAR_PART_MESH + s);
        }
        nStart = nSep + 1;
        nSep = FindSubString(sList, ";", nStart);
    }
}

// ---- Blood colours ---------------------------------------------------------

// 0 none, 1 red, 2 green, 3 yellow, 4 white (as in the shader).
int WthrBloodKindFromLetter(string sLetter)
{
    sLetter = GetStringUpperCase(GetStringLeft(sLetter, 1));
    if (sLetter == "R") return 1;
    if (sLetter == "G") return 2;
    if (sLetter == "Y") return 3;
    if (sLetter == "W") return 4;
    return 0;
}

// The creature's blood: its WTHR_BLOOD_COLOR, else appearance.2da. The
// blood on a placeable or door: its WTHR_BLOOD_COLOR, else red.
int WthrBloodKind(object oCreature)
{
    string sOwn = GetLocalString(oCreature, WTHR_BLOOD_COLOR);
    if (sOwn != "") return WthrBloodKindFromLetter(sOwn);
    if (GetObjectType(oCreature) != OBJECT_TYPE_CREATURE) return 1;
    return WthrBloodKindFromLetter(Get2DAString("appearance", "BLOODCOLR", GetAppearanceType(oCreature)));
}

// ---- Levels ----------------------------------------------------------------

float WthrClamp(float f)
{
    return f < 0.0 ? 0.0 : (f > 1.0 ? 1.0 : f);
}

// ---- Spatter, one level per blood colour ------------------------------------

const int WTHR_BLOOD_KINDS = 4;  // 1 red, 2 green, 3 yellow, 4 white

string WthrSpatterVar(int nKind)
{
    return WTHR_VAR_SPAT + IntToString(nKind);
}

string WthrSpatterParam(int nKind)
{
    switch (nKind)
    {
        case 1: return "SpatterRed";
        case 2: return "SpatterGreen";
        case 3: return "SpatterYellow";
    }
    return "SpatterWhite";
}

// All of the creature's spatter together, 0..1.
float WthrSpatter(object oCreature)
{
    float f = 0.0;
    int n;
    for (n = 1; n <= WTHR_BLOOD_KINDS; n++) f += GetLocalFloat(oCreature, WthrSpatterVar(n));
    return WthrClamp(f);
}

// Scales every colour of spatter so they add up to fTotal: cleaning, rain
// and fades take each colour off in step.
void WthrSetSpatterTotal(object oCreature, float fTotal)
{
    fTotal = WthrClamp(fTotal);
    float fNow = WthrSpatter(oCreature);
    float fScale = fNow > 0.0 ? fTotal / fNow : 0.0;
    int n;
    for (n = 1; n <= WTHR_BLOOD_KINDS; n++)
    {
        string sVar = WthrSpatterVar(n);
        SetLocalFloat(oCreature, sVar, GetLocalFloat(oCreature, sVar) * fScale);
    }
}

int WthrChanged(float fNow, float fSent)
{
    return fabs(fNow - fSent) >= WTHR_SEND_STEP
        || (fNow == 0.0 && fSent > 0.0) || (fNow == 1.0 && fSent < 1.0);
}

// Sends one level if it changed enough since it was last sent (or bForce).
// Returns TRUE if it was sent.
int WthrPush(object oCreature, string sList, string sParam, string sVar, int bForce)
{
    float fNow = GetLocalFloat(oCreature, sVar);
    if (!bForce && !WthrChanged(fNow, GetLocalFloat(oCreature, WTHR_VAR_SENT + sParam))) return FALSE;
    WthrSetParam(oCreature, sList, sParam, fNow);
    SetLocalFloat(oCreature, WTHR_VAR_SENT + sParam, fNow);
    return TRUE;
}

// Sends the creature's levels to its materials: only those that changed
// enough to see, or all of them with bForce. bNewLook: work out the
// materials again (armor changed) and send everything.
void WthrSend(object oCreature, int bNewLook = FALSE, int bForce = FALSE)
{
    string sList = GetLocalString(oCreature, WTHR_VAR_MATERIALS);
    if (bNewLook || sList == "")
    {
        sList = WthrMaterials(oCreature);
        SetLocalString(oCreature, WTHR_VAR_MATERIALS, sList);
        bForce = TRUE;
    }
    if (bForce) WthrSendParts(oCreature, sList);
    WthrPush(oCreature, sList, WTHR_PARAM_DUST, WTHR_VAR_DUST, bForce);
    WthrPush(oCreature, sList, WTHR_PARAM_SPREAD, WTHR_VAR_SPREAD, bForce);
    WthrPush(oCreature, sList, WTHR_PARAM_SNOW, WTHR_VAR_SNOW, bForce);
    WthrPush(oCreature, sList, WTHR_PARAM_DRY, WTHR_VAR_DRY, bForce);
    if (WthrPush(oCreature, sList, WTHR_PARAM_WOUNDS, WTHR_VAR_WOUNDS, bForce))
        WthrSetParam(oCreature, sList, WTHR_PARAM_OWN, IntToFloat(WthrBloodKind(oCreature)));
    int nKind;
    for (nKind = 1; nKind <= WTHR_BLOOD_KINDS; nKind++)
        WthrPush(oCreature, sList, WthrSpatterParam(nKind), WthrSpatterVar(nKind), bForce);
}

void WthrFlush(object oCreature)
{
    if (!GetIsObjectValid(oCreature)) return;
    DeleteLocalInt(oCreature, WTHR_VAR_QUEUED);
    WthrSend(oCreature);
}

// Sends within a second; changes in the meantime (blows in a fight) go
// together in one send.
void WthrQueueSend(object oCreature)
{
    if (GetLocalInt(oCreature, WTHR_VAR_QUEUED)) return;
    SetLocalInt(oCreature, WTHR_VAR_QUEUED, TRUE);
    DelayCommand(1.0, WthrFlush(oCreature));
}

// Sets dust, snow and spread (0..1 each). The look follows once the change
// is big enough to see, or at once with bForce.
void WthrSetLevels(object oCreature, float fDust, float fSnow, float fSpread, int bForce = FALSE)
{
    SetLocalFloat(oCreature, WTHR_VAR_DUST, WthrClamp(fDust));
    SetLocalFloat(oCreature, WTHR_VAR_SNOW, WthrClamp(fSnow));
    SetLocalFloat(oCreature, WTHR_VAR_SPREAD, WthrClamp(fSpread));
    WthrSend(oCreature, FALSE, bForce);
}

// Sets wounds and all spatter together (0..1 each; the colours keep their
// shares); no blood left means fresh again.
void WthrSetBlood(object oCreature, float fWounds, float fSpatter, int bForce = FALSE)
{
    fWounds = WthrClamp(fWounds);
    SetLocalFloat(oCreature, WTHR_VAR_WOUNDS, fWounds);
    WthrSetSpatterTotal(oCreature, fSpatter);
    if (fWounds <= 0.0 && WthrSpatter(oCreature) <= 0.0) SetLocalFloat(oCreature, WTHR_VAR_DRY, 0.0);
    WthrSend(oCreature, FALSE, bForce);
}

// Sets dust, snow and spread at once (test commands, starting looks).
void WthrSet(object oCreature, float fDust, float fSnow, float fSpread = -1.0)
{
    if (fSpread < 0.0) fSpread = GetLocalFloat(oCreature, WTHR_VAR_SPREAD);
    SetLocalFloat(oCreature, WTHR_VAR_DUST, WthrClamp(fDust));
    SetLocalFloat(oCreature, WTHR_VAR_SNOW, WthrClamp(fSnow));
    SetLocalFloat(oCreature, WTHR_VAR_SPREAD, WthrClamp(fSpread));
    WthrSend(oCreature, TRUE);
}

// Re-sends the creature's whole look: after changing armor, or after
// loading a game.
void WthrRefresh(object oCreature)
{
    WthrSend(oCreature, TRUE);
}

int WthrHasBlood(object oCreature)
{
    return GetLocalFloat(oCreature, WTHR_VAR_WOUNDS) > 0.0 || WthrSpatter(oCreature) > 0.0;
}

int WthrHasAny(object oCreature)
{
    return GetLocalFloat(oCreature, WTHR_VAR_DUST) > 0.0 || GetLocalFloat(oCreature, WTHR_VAR_SNOW) > 0.0
        || WthrHasBlood(oCreature);
}

// ---- Gradual changes --------------------------------------------------------

const float WTHR_FADE_STEP = 0.5;  // seconds between steps of a fade

void WthrFadeStep(object oCreature, int nFade, int nStep, int nSteps,
                  float fDust0, float fSnow0, float fSpread0, float fWounds0, float fSpatter0,
                  float fDust1, float fSnow1, float fSpread1, float fWounds1, float fSpatter1)
{
    if (!GetIsObjectValid(oCreature) || GetLocalInt(oCreature, WTHR_VAR_FADE) != nFade) return;
    float t = IntToFloat(nStep) / IntToFloat(nSteps);
    SetLocalFloat(oCreature, WTHR_VAR_DUST, fDust0 + (fDust1 - fDust0) * t);
    SetLocalFloat(oCreature, WTHR_VAR_SNOW, fSnow0 + (fSnow1 - fSnow0) * t);
    SetLocalFloat(oCreature, WTHR_VAR_SPREAD, fSpread0 + (fSpread1 - fSpread0) * t);
    WthrSetBlood(oCreature, fWounds0 + (fWounds1 - fWounds0) * t, fSpatter0 + (fSpatter1 - fSpatter0) * t, TRUE);
    if (nStep < nSteps)
        DelayCommand(WTHR_FADE_STEP, WthrFadeStep(oCreature, nFade, nStep + 1, nSteps,
                                                  fDust0, fSnow0, fSpread0, fWounds0, fSpatter0,
                                                  fDust1, fSnow1, fSpread1, fWounds1, fSpatter1));
}

// Changes the look to these levels over fSeconds, step by step. A newer
// fade replaces a running one.
void WthrFadeTo(object oCreature, float fDust, float fSnow, float fSpread, float fWounds, float fSpatter,
                float fSeconds)
{
    int nFade = GetLocalInt(oCreature, WTHR_VAR_FADE) + 1;
    SetLocalInt(oCreature, WTHR_VAR_FADE, nFade);
    int nSteps = FloatToInt(fSeconds / WTHR_FADE_STEP);
    if (nSteps < 1) nSteps = 1;
    WthrFadeStep(oCreature, nFade, 1, nSteps,
                 GetLocalFloat(oCreature, WTHR_VAR_DUST), GetLocalFloat(oCreature, WTHR_VAR_SNOW),
                 GetLocalFloat(oCreature, WTHR_VAR_SPREAD), GetLocalFloat(oCreature, WTHR_VAR_WOUNDS),
                 WthrSpatter(oCreature),
                 WthrClamp(fDust), WthrClamp(fSnow), WthrClamp(fSpread), WthrClamp(fWounds), WthrClamp(fSpatter));
}

// Removes a share of the dust, snow and blood (1.0 = all of it) over
// fSeconds.
void WthrClean(object oCreature, float fDustShare, float fSnowShare, float fBloodShare, float fSeconds)
{
    float fDust = GetLocalFloat(oCreature, WTHR_VAR_DUST) * (1.0 - WthrClamp(fDustShare));
    float fBloodKeep = 1.0 - WthrClamp(fBloodShare);
    WthrFadeTo(oCreature, fDust,
               GetLocalFloat(oCreature, WTHR_VAR_SNOW) * (1.0 - WthrClamp(fSnowShare)),
               fDust > 0.0 ? GetLocalFloat(oCreature, WTHR_VAR_SPREAD) : 0.0,
               GetLocalFloat(oCreature, WTHR_VAR_WOUNDS) * fBloodKeep,
               WthrSpatter(oCreature) * fBloodKeep, fSeconds);
}

// ---- Where things build up -------------------------------------------------

// A designer's float: > 0 the value, -1 (or below 0) none, 0 / unset falls
// back to fElse.
float WthrValue(object oFrom, string sVar, float fElse)
{
    float f = GetLocalFloat(oFrom, sVar);
    if (f > 0.0) return f;
    if (f < 0.0) return 0.0;
    return fElse;
}

// Like WthrValue, for weather rates, which may be negative (washing off):
// set means set, unset falls back.
float WthrSigned(object oFrom, string sVar, float fElse)
{
    float f = GetLocalFloat(oFrom, sVar);
    return f != 0.0 ? f : fElse;
}

int WthrIsOutdoors(object oArea)
{
    return !GetIsAreaInterior(oArea) && GetIsAreaAboveGround(oArea) == AREA_ABOVEGROUND;
}

int WthrIsRaining(object oArea)
{
    return WthrIsOutdoors(oArea) && !GetLocalInt(oArea, WTHR_IGNORE_WEATHER) && GetWeather(oArea) == WEATHER_RAIN;
}

// The wthr_zone trigger the creature stands in, if any.
object WthrZone(object oCreature)
{
    object oZone = GetLocalObject(oCreature, WTHR_VAR_ZONE);
    if (GetIsObjectValid(oZone) && GetArea(oZone) == GetArea(oCreature)) return oZone;
    return OBJECT_INVALID;
}

// Base rate from the zone, else the area.
float WthrBaseRate(object oCreature, object oArea, string sVar)
{
    object oZone = WthrZone(oCreature);
    float fArea = WthrValue(oArea, sVar, 0.0);
    return GetIsObjectValid(oZone) ? WthrValue(oZone, sVar, fArea) : fArea;
}

int WthrIsStorm(object oCreature, object oArea)
{
    object oZone = WthrZone(oCreature);
    if (GetIsObjectValid(oZone) && GetLocalInt(oZone, WTHR_DUST_STORM)) return TRUE;
    return GetLocalInt(oArea, WTHR_DUST_STORM);
}

// What the current weather adds per minute (negative: washes off).
float WthrWeatherRate(object oArea, string sRain, string sSnowfall)
{
    if (!WthrIsOutdoors(oArea) || GetLocalInt(oArea, WTHR_IGNORE_WEATHER)) return 0.0;
    int nWeather = GetWeather(oArea);
    string sVar = nWeather == WEATHER_RAIN ? sRain : (nWeather == WEATHER_SNOW ? sSnowfall : "");
    if (sVar == "") return 0.0;
    return WthrSigned(oArea, sVar, GetLocalFloat(GetModule(), sVar));
}

float WthrModuleRate(string sVar, float fDefault)
{
    return WthrValue(GetModule(), sVar, fDefault);
}

// Blood dries over real minutes; -1 on the module: never.
void WthrDry(object oCreature, float fMinutes)
{
    if (!WthrHasBlood(oCreature)) return;
    float fDryMinutes = WthrModuleRate("WTHR_BLOOD_DRY_MINUTES", WTHR_DEFAULT_DRY_MINUTES);
    if (fDryMinutes <= 0.0) return;
    SetLocalFloat(oCreature, WTHR_VAR_DRY, WthrClamp(GetLocalFloat(oCreature, WTHR_VAR_DRY) + fMinutes / fDryMinutes));
}

// One update of a creature that weathers: fMinutes spent in oArea.
// Dust and snow build up where a rate applies and fade where none does;
// blood dries, and the rain washes it off.
void WthrWeather(object oCreature, object oArea, int bMoving, float fMinutes)
{
    float fDust = GetLocalFloat(oCreature, WTHR_VAR_DUST);
    float fSnow = GetLocalFloat(oCreature, WTHR_VAR_SNOW);
    float fSpread = GetLocalFloat(oCreature, WTHR_VAR_SPREAD);

    float fDustBase = WthrBaseRate(oCreature, oArea, WTHR_DUST_RATE) * (bMoving ? 1.0 : WTHR_STANDING);
    float fSnowBase = WthrIsOutdoors(oArea) ? WthrBaseRate(oCreature, oArea, WTHR_SNOW_RATE) : 0.0;
    float fDustRate = fDustBase + WthrWeatherRate(oArea, "WTHR_RAIN_DUST", "WTHR_SNOWFALL_DUST");
    float fSnowRate = fSnowBase + WthrWeatherRate(oArea, "WTHR_RAIN_SNOW", "WTHR_SNOWFALL_SNOW");

    if (fDustRate != 0.0)
        fDust += fDustRate * fMinutes;
    else
        fDust -= WthrModuleRate("WTHR_FADE_DUST", WTHR_DEFAULT_FADE_DUST) * fMinutes;

    if (fSnowRate != 0.0)
        fSnow += fSnowRate * fMinutes;
    else if (WthrIsOutdoors(oArea))
        fSnow -= WthrModuleRate("WTHR_FADE_SNOW", WTHR_DEFAULT_FADE_SNOW) * fMinutes;
    else
        fSnow -= WthrModuleRate("WTHR_FADE_SNOW_INDOORS", WTHR_DEFAULT_FADE_SNOW_INSIDE) * fMinutes;

    // In a storm the dust climbs over the whole body; out of it, the dust
    // that got high up wears off first.
    if (WthrIsStorm(oCreature, oArea))
        fSpread += WTHR_STORM_RISE * fMinutes;
    else if (fDustRate <= 0.0)
        fSpread -= WTHR_STORM_RISE * fMinutes;
    if (fDust <= 0.0) fSpread = 0.0;

    SetLocalFloat(oCreature, WTHR_VAR_DUST, WthrClamp(fDust));
    SetLocalFloat(oCreature, WTHR_VAR_SNOW, WthrClamp(fSnow));
    SetLocalFloat(oCreature, WTHR_VAR_SPREAD, WthrClamp(fSpread));

    WthrDry(oCreature, fMinutes);
    float fWash = 0.0;
    if (WthrIsRaining(oArea))
        fWash = WthrValue(oArea, "WTHR_RAIN_BLOOD", WthrModuleRate("WTHR_RAIN_BLOOD", WTHR_DEFAULT_RAIN_BLOOD)) * fMinutes;
    WthrSetBlood(oCreature, GetLocalFloat(oCreature, WTHR_VAR_WOUNDS) - fWash,
                 WthrSpatter(oCreature) - fWash);
}

// ---- Blood -------------------------------------------------------------------

const float WTHR_MELEE_RANGE   = 3.5;   // metres: closer than this is melee
const float WTHR_DEFAULT_FULL_HP = 3.0;  // max HP worth of damage for full wounds
const float WTHR_SPATTER_BASE  = 0.08;  // spatter per melee hit ...
const float WTHR_SPATTER_SCALE = 1.0;   // ... plus this per share of the victim's max HP
const float WTHR_SPATTER_MAX   = 0.3;   // most spatter one hit can leave
const float WTHR_DRY_TICK      = 20.0;  // seconds between drying steps of creatures without a loop

// Drying for creatures without a loop of their own (monsters, NPCs): a
// step every WTHR_DRY_TICK seconds while they have blood.
void WthrDryLoop(object oCreature)
{
    if (!GetIsObjectValid(oCreature) || !WthrHasBlood(oCreature) || GetLocalFloat(oCreature, WTHR_VAR_DRY) >= 1.0)
    {
        DeleteLocalInt(oCreature, WTHR_VAR_DRYING);
        return;
    }
    WthrDry(oCreature, WTHR_DRY_TICK / 60.0);
    WthrSend(oCreature);
    DelayCommand(WTHR_DRY_TICK, WthrDryLoop(oCreature));
}

int WthrIsPartyMember(object oCreature);

// Adds blood: fWounds of the creature's own, fSpatter of kind nKind (from
// whoever it hit, into that colour's own layer). Fresh blood makes the
// whole a little fresher.
void WthrAddBlood(object oCreature, float fWounds, float fSpatter, int nKind)
{
    float fOld = GetLocalFloat(oCreature, WTHR_VAR_WOUNDS) + WthrSpatter(oCreature);
    float fNew = fWounds + fSpatter;
    if (fNew <= 0.0) return;
    SetLocalFloat(oCreature, WTHR_VAR_DRY, GetLocalFloat(oCreature, WTHR_VAR_DRY) * fOld / (fOld + fNew));

    SetLocalFloat(oCreature, WTHR_VAR_WOUNDS, WthrClamp(GetLocalFloat(oCreature, WTHR_VAR_WOUNDS) + fWounds));
    if (fSpatter > 0.0 && nKind >= 1 && nKind <= WTHR_BLOOD_KINDS)
    {
        string sVar = WthrSpatterVar(nKind);
        SetLocalFloat(oCreature, sVar, WthrClamp(GetLocalFloat(oCreature, sVar) + fSpatter));
    }
    WthrQueueSend(oCreature);

    // Creatures with a loop dry in it; the rest get a drying loop.
    if (!WthrIsPartyMember(oCreature) && !GetLocalInt(oCreature, WTHR_WEATHERS)
        && !GetLocalInt(oCreature, WTHR_VAR_DRYING))
    {
        SetLocalInt(oCreature, WTHR_VAR_DRYING, TRUE);
        DelayCommand(WTHR_DRY_TICK, WthrDryLoop(oCreature));
    }
}

// With WTHR_DEBUG = 1 on the module: a line to every player in oNear's
// area, for following blood decisions while testing.
void WthrDebugBlood(object oNear, string sMsg)
{
    if (!GetLocalInt(GetModule(), WTHR_DEBUG)) return;
    object oArea = GetArea(oNear);
    object oPC = GetFirstPC();
    while (GetIsObjectValid(oPC))
    {
        if (GetArea(oPC) == oArea) SendMessageToPC(oPC, "NWN-Weathered blood: " + sMsg);
        oPC = GetNextPC();
    }
}

// A melee hit: close, and not with a ranged weapon.
int WthrIsMelee(object oAttacker, object oVictim)
{
    if (GetArea(oAttacker) != GetArea(oVictim) || GetDistanceBetween(oAttacker, oVictim) > WTHR_MELEE_RANGE)
        return FALSE;
    object oWeapon = GetItemInSlot(INVENTORY_SLOT_RIGHTHAND, oAttacker);
    return !GetIsObjectValid(oWeapon) || !GetWeaponRanged(oWeapon);
}

// oVictim took nDamage physical damage from oAttacker: its own blood on it,
// and on a melee attacker, spatter in the victim's colour.
void WthrPhysicalDamage(object oVictim, object oAttacker, int nDamage)
{
    object oModule = GetModule();
    if (nDamage <= 0 || GetLocalInt(oModule, WTHR_BLOOD_OFF) || GetLocalInt(oVictim, WTHR_SKIP)) return;
    int nKind = WthrBloodKind(oVictim);
    if (nKind == 0) return;  // no blood: skeletons, golems, elementals

    int nMax = GetMaxHitPoints(oVictim);
    float fShare = IntToFloat(nDamage) / IntToFloat(nMax > 0 ? nMax : 1);
    float fWounds = fShare / WthrModuleRate("WTHR_BLOOD_FULL_HP", WTHR_DEFAULT_FULL_HP);
    WthrAddBlood(oVictim, fWounds, 0.0, nKind);
    string sLine = GetName(oVictim) + " took " + IntToString(nDamage) + " from "
                 + (GetIsObjectValid(oAttacker) ? GetName(oAttacker) : "(no attacker)")
                 + ": wounds +" + FloatToString(fWounds, 0, 3)
                 + " (now " + FloatToString(GetLocalFloat(oVictim, WTHR_VAR_WOUNDS), 0, 2) + ")";

    string sNo = "";
    if (GetObjectType(oAttacker) != OBJECT_TYPE_CREATURE) sNo = "the attacker isn't a creature";
    else if (oAttacker == oVictim) sNo = "it hurt itself";
    else if (GetLocalInt(oAttacker, WTHR_SKIP)) sNo = "the attacker has WTHR_SKIP";
    else if (GetArea(oAttacker) != GetArea(oVictim)) sNo = "the attacker is in another area";
    else if (GetDistanceBetween(oAttacker, oVictim) > WTHR_MELEE_RANGE)
        sNo = "too far for melee (" + FloatToString(GetDistanceBetween(oAttacker, oVictim), 0, 1) + " m)";
    else if (!WthrIsMelee(oAttacker, oVictim)) sNo = "the attacker holds a ranged weapon";
    if (sNo != "")
    {
        WthrDebugBlood(oVictim, sLine + "; no spatter: " + sNo + ".");
        return;
    }
    float fSpatter = WTHR_SPATTER_BASE + WTHR_SPATTER_SCALE * fShare;
    if (fSpatter > WTHR_SPATTER_MAX) fSpatter = WTHR_SPATTER_MAX;
    fSpatter *= WthrModuleRate("WTHR_BLOOD_SPATTER", 1.0);
    WthrAddBlood(oAttacker, 0.0, fSpatter, nKind);
    WthrDebugBlood(oVictim, sLine + "; spatter +" + FloatToString(fSpatter, 0, 3) + " on " + GetName(oAttacker)
                            + " (now " + FloatToString(WthrSpatter(oAttacker), 0, 2) + ").");
}

// Puts wthr_damaged on a creature's OnDamaged, keeping its own script.
// Players: see WthrHookPlayer.
void WthrHookDamage(object oCreature)
{
    if (GetObjectType(oCreature) != OBJECT_TYPE_CREATURE || GetIsPC(oCreature)
        || GetLocalInt(oCreature, WTHR_VAR_HOOKED)) return;
    SetLocalInt(oCreature, WTHR_VAR_HOOKED, TRUE);
    string sOwn = GetEventScript(oCreature, EVENT_SCRIPT_CREATURE_ON_DAMAGED);
    if (sOwn == "wthr_damaged") return;
    SetLocalString(oCreature, WTHR_VAR_ORIG_DMG, sOwn);
    int bOk = SetEventScript(oCreature, EVENT_SCRIPT_CREATURE_ON_DAMAGED, "wthr_damaged");
    if (GetLocalInt(GetModule(), WTHR_DEBUG))
    {
        object oPC = GetFirstPC();
        while (GetIsObjectValid(oPC))
        {
            if (GetArea(oPC) == GetArea(oCreature))
                SendMessageToPC(oPC, "NWN-Weathered blood: watching " + GetName(oCreature) + " (its OnDamaged was '"
                                     + sOwn + "')" + (bOk ? "." : " - FAILED to set."));
            oPC = GetNextPC();
        }
    }
}

// Puts wthr_damaged on a player's own OnDamaged, keeping any script
// already there. Classic NWN gave players no creature events; EE accepts
// it. Returns FALSE if the game refused, in which case players get no
// blood of their own and give no spatter.
int WthrHookPlayer(object oPC)
{
    string sOwn = GetEventScript(oPC, EVENT_SCRIPT_CREATURE_ON_DAMAGED);
    if (sOwn == "wthr_damaged") return TRUE;
    SetLocalString(oPC, WTHR_VAR_ORIG_DMG, sOwn);
    return SetEventScript(oPC, EVENT_SCRIPT_CREATURE_ON_DAMAGED, "wthr_damaged");
}

// The player's game decides whether they see blood: gore off hides it on
// every creature, for that player only.
void WthrApplyGore(object oPC)
{
    int bHide = GetLocalInt(GetModule(), WTHR_BLOOD_OFF)
             || GetPlayerDeviceProperty(oPC, PLAYER_DEVICE_PROPERTY_GAME_GORE) == 0;
    if (GetLocalInt(oPC, "WTHR_GORE_SENT") == bHide + 1) return;
    SetLocalInt(oPC, "WTHR_GORE_SENT", bHide + 1);
    SetShaderUniformInt(oPC, WTHR_U_NO_GORE, bHide);
}

// ---- Starting looks -------------------------------------------------------

// TRUE for players and their henchmen, companions, familiars and summons.
int WthrIsPartyMember(object oCreature)
{
    if (GetIsPC(oCreature)) return TRUE;
    object oMaster = GetMaster(oCreature);
    return GetIsObjectValid(oMaster) && GetIsPC(oMaster);
}

void WthrStartLoop(object oCreature);

// A creature met for the first time: its blood is watched from now on, and
// it gets its own WTHR_START_* look, else its area's, with some variety.
// Flagged creatures then start weathering.
void WthrStartLook(object oCreature, object oArea)
{
    if (!GetIsObjectValid(oCreature) || GetLocalInt(oCreature, WTHR_VAR_SEEN)) return;
    SetLocalInt(oCreature, WTHR_VAR_SEEN, TRUE);
    if (GetLocalInt(oCreature, WTHR_SKIP)) return;
    WthrHookDamage(oCreature);

    float fDust = WthrValue(oCreature, WTHR_START_DUST, WthrValue(oArea, WTHR_START_DUST, 0.0));
    float fSnow = WthrValue(oCreature, WTHR_START_SNOW, WthrValue(oArea, WTHR_START_SNOW, 0.0));
    float fVary = WthrValue(oCreature, WTHR_START_VARY, WthrValue(oArea, WTHR_START_VARY, WTHR_DEFAULT_VARY));
    if (fDust > 0.0 || fSnow > 0.0)
    {
        float fScale = 1.0 - fVary + 2.0 * fVary * IntToFloat(Random(1001)) / 1000.0;
        WthrSet(oCreature, fDust * fScale, fSnow * fScale, GetLocalInt(oArea, WTHR_DUST_STORM) ? 1.0 : 0.0);
    }
    if (GetLocalInt(oCreature, WTHR_WEATHERS)) WthrStartLoop(oCreature);
}

// ---- Placeables and doors --------------------------------------------------

// A placeable or door with a look in its variables: shown once a player
// comes into its area, and never changed over time. WTHR_DUST, WTHR_SNOW,
// WTHR_SPREAD and WTHR_DRY are the levels themselves; WTHR_BLOOD becomes
// its blood, in WTHR_BLOOD_COLOR.
// TRUE for a placeable with Static ticked: the game draws it as part of the
// area, so a look set on it never shows. Scripts can't untick it.
int WthrIsStatic(object oObject)
{
    if (GetObjectType(oObject) != OBJECT_TYPE_PLACEABLE) return FALSE;
    return JsonGetInt(JsonObjectGet(JsonObjectGet(ObjectToJson(oObject), "Static"), "value"));
}

// oPC: who to tell (a DM or, with WTHR_DEBUG, any tester) if it can't show.
void WthrObjectLook(object oObject, object oPC = OBJECT_INVALID)
{
    if (!GetIsObjectValid(oObject) || GetLocalInt(oObject, WTHR_VAR_SEEN)) return;
    SetLocalInt(oObject, WTHR_VAR_SEEN, TRUE);
    if (GetIsObjectValid(oPC) && (GetIsDM(oPC) || GetLocalInt(GetModule(), WTHR_DEBUG)) && WthrIsStatic(oObject))
        SendMessageToPC(oPC, "NWN-Weathered: " + GetName(oObject) + " (tag " + GetTag(oObject)
                             + ") has a look but is Static, so it won't show. Untick Static on it in the toolset.");
    float fBlood = GetLocalFloat(oObject, "WTHR_BLOOD");
    if (fBlood > 0.0 && GetLocalFloat(oObject, WTHR_VAR_WOUNDS) <= 0.0)
        SetLocalFloat(oObject, WTHR_VAR_WOUNDS, WthrClamp(fBlood));
    if (WthrHasAny(oObject)) WthrSend(oObject, TRUE);
}

int WthrObjectHasLook(object oObject)
{
    return GetLocalFloat(oObject, WTHR_VAR_DUST) > 0.0 || GetLocalFloat(oObject, WTHR_VAR_SNOW) > 0.0
        || GetLocalFloat(oObject, "WTHR_BLOOD") > 0.0 || WthrHasBlood(oObject);
}

// Changes a placeable's or door's look from your own scripts: levels 0..1,
// sColor R, G, Y or W.
void WthrSetObject(object oObject, float fDust, float fSnow, float fBlood, string sColor = "R")
{
    SetLocalInt(oObject, WTHR_VAR_SEEN, TRUE);
    SetLocalString(oObject, WTHR_BLOOD_COLOR, sColor);
    SetLocalFloat(oObject, WTHR_VAR_DUST, WthrClamp(fDust));
    SetLocalFloat(oObject, WTHR_VAR_SNOW, WthrClamp(fSnow));
    SetLocalFloat(oObject, WTHR_VAR_WOUNDS, WthrClamp(fBlood));
    WthrSend(oObject, TRUE);
}

// Re-sends a creature's look; for players who arrived after it was set.
void WthrResend(object oCreature)
{
    if (GetIsObjectValid(oCreature)) WthrSend(oCreature, FALSE, TRUE);
}

const float WTHR_SCAN_GAP = 0.1;  // seconds between creatures, to spread the work

// A player just arrived: every creature in the area that hasn't got its
// starting look gets it (the ones placed in the toolset), and the ones
// already dusty, snowy or bloody are sent again so the newcomer sees them.
// Creatures that appear later get theirs from wthr_areaenter.
void WthrScanArea(object oPC)
{
    object oArea = GetArea(oPC);
    float fDelay = 0.0;
    object o = GetFirstObjectInArea(oArea, OBJECT_TYPE_CREATURE);
    while (GetIsObjectValid(o))
    {
        if (!GetLocalInt(o, WTHR_VAR_SEEN) && !WthrIsPartyMember(o))
        {
            DelayCommand(fDelay, WthrStartLook(o, oArea));
            fDelay += WTHR_SCAN_GAP;
        }
        else if (o != oPC && WthrHasAny(o))
        {
            DelayCommand(fDelay, WthrResend(o));
            fDelay += WTHR_SCAN_GAP;
        }
        o = GetNextObjectInArea(oArea, OBJECT_TYPE_CREATURE);
    }

    // Placeables and doors with a look: shown the first time, sent again
    // for each player who arrives later.
    o = GetFirstObjectInArea(oArea, OBJECT_TYPE_PLACEABLE | OBJECT_TYPE_DOOR);
    while (GetIsObjectValid(o))
    {
        if (WthrObjectHasLook(o))
        {
            if (!GetLocalInt(o, WTHR_VAR_SEEN))
                DelayCommand(fDelay, WthrObjectLook(o, oPC));
            else
                DelayCommand(fDelay, WthrResend(o));
            fDelay += WTHR_SCAN_GAP;
        }
        o = GetNextObjectInArea(oArea, OBJECT_TYPE_PLACEABLE | OBJECT_TYPE_DOOR);
    }
}

// ---- The loops --------------------------------------------------------------

// On each creature with a loop:
const string WTHR_VAR_GEN      = "WTHR_GEN";       // int: the running loop's number
const string WTHR_VAR_AREA     = "WTHR_AREA";      // object: area at the last update
const string WTHR_VAR_LAST_POS = "WTHR_LAST_POS";  // location at the last update
const string WTHR_VAR_TICKS    = "WTHR_TICKS";     // int: updates so far

const float WTHR_TICK         = 2.0;   // seconds between updates
const float WTHR_MOVED        = 1.0;   // metres per update that count as travelling
const int   WTHR_GORE_TICKS   = 5;     // and check their gore setting every 10 s
const int   WTHR_MAX_HENCHMEN = 10;

// Calls WthrWeather for a player's henchmen, companions, familiars and
// summons in the same area, and watches their blood.
void WthrWeatherAssociates(object oPC, object oArea, int bMoving, float fMinutes)
{
    int nType;
    for (nType = ASSOCIATE_TYPE_HENCHMAN; nType <= ASSOCIATE_TYPE_DOMINATED; nType++)
    {
        int nMax = nType == ASSOCIATE_TYPE_HENCHMAN ? WTHR_MAX_HENCHMEN : 1;
        int n;
        for (n = 1; n <= nMax; n++)
        {
            object oAssociate = GetAssociate(nType, oPC, n);
            if (!GetIsObjectValid(oAssociate)) break;
            if (GetLocalInt(oAssociate, WTHR_SKIP)) continue;
            WthrHookDamage(oAssociate);
            if (!GetIsDead(oAssociate) && GetArea(oAssociate) == oArea)
                WthrWeather(oAssociate, oArea, bMoving, fMinutes);
        }
    }
}

const float WTHR_FIGHT_RANGE = 20.0;  // metres: creatures this close may be fighting the player

// Gets a creature ready for blood the moment it fights a player, if it
// somehow wasn't already (wthr_areaenter sets up creatures as they appear).
void WthrReadyForBlood(object oCreature)
{
    if (GetObjectType(oCreature) != OBJECT_TYPE_CREATURE || GetIsPC(oCreature)) return;
    if (!GetLocalInt(oCreature, WTHR_VAR_SEEN) && !WthrIsPartyMember(oCreature))
        WthrStartLook(oCreature, GetArea(oCreature));
    else
        WthrHookDamage(oCreature);
}

// Each update makes sure the creatures fighting a player are ready for
// blood (whoever the player attacks, and everyone nearby attacking them): a
// safety net behind wthr_areaenter, e.g. for an area created by a script
// after the module loaded, which wthr_modload never hooked.
void WthrWatchFight(object oPC)
{
    WthrReadyForBlood(GetAttackTarget(oPC));
    location lHere = GetLocation(oPC);
    object o = GetFirstObjectInShape(SHAPE_SPHERE, WTHR_FIGHT_RANGE, lHere, FALSE, OBJECT_TYPE_CREATURE);
    while (GetIsObjectValid(o))
    {
        if (o != oPC && !GetIsDead(o) && GetAttackTarget(o) == oPC) WthrReadyForBlood(o);
        o = GetNextObjectInShape(SHAPE_SPHERE, WTHR_FIGHT_RANGE, lHere, FALSE, OBJECT_TYPE_CREATURE);
    }
}

// One update of a creature with a loop: a player (with their party) or a
// creature flagged WTHR_WEATHERS. nGen stops an old loop once a new one
// starts (after loading a saved game the old one may still be scheduled).
void WthrTick(object oCreature, int nGen)
{
    if (!GetIsObjectValid(oCreature) || GetLocalInt(oCreature, WTHR_VAR_GEN) != nGen) return;
    DelayCommand(WTHR_TICK, WthrTick(oCreature, nGen));

    object oArea = GetArea(oCreature);
    if (!GetIsObjectValid(oArea)) return;  // between areas
    int bPC = GetIsPC(oCreature);
    // A flagged creature rests while no player is around to see it.
    if (!bPC && !GetIsObjectValid(GetNearestCreature(CREATURE_TYPE_PLAYER_CHAR, PLAYER_CHAR_IS_PC, oCreature)))
        return;
    int nTicks = GetLocalInt(oCreature, WTHR_VAR_TICKS) + 1;
    SetLocalInt(oCreature, WTHR_VAR_TICKS, nTicks);

    if (bPC)
    {
        WthrWatchFight(oCreature);
        if (nTicks % WTHR_GORE_TICKS == 1) WthrApplyGore(oCreature);
    }

    location lHere = GetLocation(oCreature);
    location lLast = GetLocalLocation(oCreature, WTHR_VAR_LAST_POS);
    SetLocalLocation(oCreature, WTHR_VAR_LAST_POS, lHere);

    if (oArea != GetLocalObject(oCreature, WTHR_VAR_AREA))
    {
        SetLocalObject(oCreature, WTHR_VAR_AREA, oArea);
        if (bPC) WthrScanArea(oCreature);
        return;  // arriving is not travelling
    }

    int bMoving = GetAreaFromLocation(lLast) == oArea
                  && GetDistanceBetweenLocations(lHere, lLast) >= WTHR_MOVED;
    float fMinutes = WTHR_TICK / 60.0;
    if (!GetIsDead(oCreature)) WthrWeather(oCreature, oArea, bMoving, fMinutes);
    if (bPC) WthrWeatherAssociates(oCreature, oArea, bMoving, fMinutes);
}

// Starts (or restarts) a creature's loop.
void WthrStartLoop(object oCreature)
{
    int nGen = GetLocalInt(oCreature, WTHR_VAR_GEN) + 1;
    SetLocalInt(oCreature, WTHR_VAR_GEN, nGen);
    DeleteLocalObject(oCreature, WTHR_VAR_AREA);  // treat the first update as arriving
    DeleteLocalInt(oCreature, "WTHR_GORE_SENT");  // uniforms don't survive a login
    DelayCommand(1.0, WthrTick(oCreature, nGen));
}

// ---- The clothes brush -----------------------------------------------------

const float WTHR_BRUSH_SECONDS = 3.0;
const float WTHR_BRUSH_DUST    = 0.85;  // share of the dust a brushing removes
const float WTHR_BRUSH_SNOW    = 1.0;
const float WTHR_BRUSH_BLOOD   = 1.0;

// Brushes the creature down: an animation, and the dust, snow and blood
// come off over a few seconds. Returns FALSE if there was nothing to do.
int WthrBrush(object oCreature)
{
    if (!WthrHasAny(oCreature)) return FALSE;
    AssignCommand(oCreature, ClearAllActions());
    AssignCommand(oCreature, ActionPlayAnimation(ANIMATION_LOOPING_GET_MID, 1.0, WTHR_BRUSH_SECONDS));
    WthrClean(oCreature, WTHR_BRUSH_DUST, WTHR_BRUSH_SNOW, WTHR_BRUSH_BLOOD, WTHR_BRUSH_SECONDS);
    return TRUE;
}

// ---- Event hooks -----------------------------------------------------------
//
// wthr_modload can put our scripts on the module events and keep the
// module's own ones; each of our event scripts runs the original first.

string WthrOriginalVar(int nEvent)
{
    return "WTHR_ORIG_" + IntToString(nEvent);
}

// Runs the module's own script for this event, if wthr_modload replaced one.
void WthrRunOriginal(int nEvent)
{
    object oModule = GetModule();
    string sScript = GetLocalString(oModule, WthrOriginalVar(nEvent));
    string sBusy = "WTHR_BUSY_" + IntToString(nEvent);
    // Guard: an original that itself runs our script would loop forever.
    if (sScript == "" || GetLocalInt(oModule, sBusy)) return;
    SetLocalInt(oModule, sBusy, TRUE);
    ExecuteScript(sScript, OBJECT_SELF);
    DeleteLocalInt(oModule, sBusy);
}

const string WTHR_VAR_ORIG_AREA_ENTER = "WTHR_ORIG_AREA_ENTER";  // string on an area: its own OnEnter

// Puts wthr_areaenter on every area's OnEnter, keeping each area's own
// script: creatures get their starting look the moment they appear.
void WthrHookAreas()
{
    object oArea = GetFirstArea();
    while (GetIsObjectValid(oArea))
    {
        string sOwn = GetEventScript(oArea, EVENT_SCRIPT_AREA_ON_ENTER);
        if (sOwn != "wthr_areaenter")
        {
            SetLocalString(oArea, WTHR_VAR_ORIG_AREA_ENTER, sOwn);
            SetEventScript(oArea, EVENT_SCRIPT_AREA_ON_ENTER, "wthr_areaenter");
        }
        oArea = GetNextArea();
    }
}

// Puts sOurs on a module event, keeping the current script as the original.
void WthrHookEvent(int nEvent, string sOurs)
{
    object oModule = GetModule();
    string sCurrent = GetEventScript(oModule, nEvent);
    if (sCurrent == sOurs) return;  // hooked already
    SetLocalString(oModule, WthrOriginalVar(nEvent), sCurrent);
    SetEventScript(oModule, nEvent, sOurs);
}
