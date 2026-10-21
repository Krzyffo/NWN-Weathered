// wthr_damaged: creature OnDamaged, put on each NPC and monster by
// WthrHookDamage when a player first comes near, and on players by
// WthrHookPlayer if the game allows it. Runs the creature's own OnDamaged
// script first, then blood: physical damage leaves the victim's blood on
// it, and spatter on a melee attacker.

#include "wthr_inc"

// -1 from the game means "none of this type".
int WthrPhysical(int nType)
{
    int n = GetDamageDealtByType(nType);
    return n > 0 ? n : 0;
}

void main()
{
    object oSelf = OBJECT_SELF;
    string sOwn = GetLocalString(oSelf, WTHR_VAR_ORIG_DMG);
    if (sOwn != "") ExecuteScript(sOwn, oSelf);

    int bPC = GetIsPC(oSelf);
    int bDebug = GetLocalInt(GetModule(), WTHR_DEBUG);

    object oDamager = GetLastDamager(oSelf);
    int nTotal = GetTotalDamageDealt();
    int nBludgeoning = GetDamageDealtByType(DAMAGE_TYPE_BLUDGEONING);
    int nPiercing = GetDamageDealtByType(DAMAGE_TYPE_PIERCING);
    int nSlashing = GetDamageDealtByType(DAMAGE_TYPE_SLASHING);
    int nPhysical = WthrPhysical(DAMAGE_TYPE_BLUDGEONING) + WthrPhysical(DAMAGE_TYPE_PIERCING)
                  + WthrPhysical(DAMAGE_TYPE_SLASHING);
    string sHow = "by type";

    // Some damage, but no type reported at all: judge it by the attacker
    // instead. A creature attacking us with a weapon (in melee or with a
    // bow) means a physical hit; a spell or a trap doesn't.
    if (nPhysical <= 0 && nTotal > 0 && nBludgeoning < 0 && nPiercing < 0 && nSlashing < 0
        && GetObjectType(oDamager) == OBJECT_TYPE_CREATURE && GetAttackTarget(oDamager) == oSelf)
    {
        nPhysical = nTotal;
        sHow = "by attacker";
    }

    if (bDebug && bPC)
        SendMessageToPC(oSelf, "NWN-Weathered: hit for " + IntToString(nTotal) + " by " + GetName(oDamager)
                               + " (bludgeoning " + IntToString(nBludgeoning) + ", piercing " + IntToString(nPiercing)
                               + ", slashing " + IntToString(nSlashing) + "): " + IntToString(nPhysical)
                               + " physical, " + sHow + ".");

    WthrPhysicalDamage(oSelf, oDamager, nPhysical);
}
