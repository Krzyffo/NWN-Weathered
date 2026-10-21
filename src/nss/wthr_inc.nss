// wthr_inc: dust and snow on one creature at a time.
//
// Each creature texture of the base game has a material (built into the
// hak by tools/build.py) using the fs_weather shader, with two values a
// script can set on a single creature:
//   DustAmount 0..1, SnowAmount 0..1.
// The engine sends them to every player who sees that creature, so in
// multiplayer everyone sees the same dusty character or snowy monster.
//
// Material names are the creature's texture names. They come from the
// generated tables: wthr_<part>.2da for part-based models (players and
// NPCs), wthr_appear.2da for monsters.

const string WTHR_VAR_DUST      = "WTHR_DUST";       // float on the creature: current dust
const string WTHR_VAR_SNOW      = "WTHR_SNOW";       // float on the creature: current snow
const string WTHR_VAR_MATERIALS = "WTHR_MATERIALS";  // last material list applied to

const string WTHR_PARAM_DUST = "DustAmount";
const string WTHR_PARAM_SNOW = "SnowAmount";

const int WTHR_PART_HEAD = 20;  // CREATURE_PART_HEAD

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

// The textures (= material names) the creature shows right now, as a
// ";"-wrapped list: ";pmh0_chest001;pmh0_pelvis001;".
string WthrMaterials(object oCreature)
{
    int nAppearance = GetAppearanceType(oCreature);
    string sList = ";";
    if (GetStringUpperCase(Get2DAString("appearance", "MODELTYPE", nAppearance)) != "P")
        return WthrAddNames(sList, Get2DAString("wthr_appear", "TEXTURES", nAppearance));

    string sPrefix = WthrPartPrefix(oCreature);
    object oArmor = GetItemInSlot(INVENTORY_SLOT_CHEST, oCreature);
    int nPart;
    for (nPart = 0; nPart <= 18; nPart++)
    {
        // Armor decides each part it has a model for; the body shows through elsewhere.
        int nModel = 0;
        if (GetIsObjectValid(oArmor))
            nModel = GetItemAppearance(oArmor, ITEM_APPR_TYPE_ARMOR_MODEL, nPart);
        if (nModel <= 0 && nPart != 18)
            nModel = GetCreatureBodyPart(nPart, oCreature);
        if (nModel > 0)
            sList = WthrAddNames(sList, Get2DAString("wthr_" + WthrPartName(nPart), sPrefix, nModel));
    }
    int nHead = GetCreatureBodyPart(WTHR_PART_HEAD, oCreature);
    sList = WthrAddNames(sList, Get2DAString("wthr_head", sPrefix, nHead));
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

// Sets how dusty and snowy a creature looks, 0..1 each.
void WthrSet(object oCreature, float fDust, float fSnow)
{
    if (fDust < 0.0) fDust = 0.0;
    if (fDust > 1.0) fDust = 1.0;
    if (fSnow < 0.0) fSnow = 0.0;
    if (fSnow > 1.0) fSnow = 1.0;
    string sList = WthrMaterials(oCreature);
    WthrSetParam(oCreature, sList, WTHR_PARAM_DUST, fDust);
    WthrSetParam(oCreature, sList, WTHR_PARAM_SNOW, fSnow);
    SetLocalFloat(oCreature, WTHR_VAR_DUST, fDust);
    SetLocalFloat(oCreature, WTHR_VAR_SNOW, fSnow);
    SetLocalString(oCreature, WTHR_VAR_MATERIALS, sList);
}

// Re-sends the creature's current amounts: after changing armor, or when
// its materials may have been reset.
void WthrRefresh(object oCreature)
{
    WthrSet(oCreature, GetLocalFloat(oCreature, WTHR_VAR_DUST), GetLocalFloat(oCreature, WTHR_VAR_SNOW));
}
