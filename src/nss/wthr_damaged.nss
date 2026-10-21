// wthr_damaged: creature OnDamaged, put on each NPC and monster by
// WthrHookDamage when a player first comes near (players have no OnDamaged;
// their loop watches their hit points instead). Runs the creature's own
// OnDamaged script first, then blood: physical damage leaves the victim's
// blood on it, and spatter on a melee attacker.

#include "wthr_inc"

int WthrPhysical(int nType)
{
    int n = GetDamageDealtByType(nType);
    return n > 0 ? n : 0;  // -1: none of this type
}

void main()
{
    string sOwn = GetLocalString(OBJECT_SELF, WTHR_VAR_ORIG_DMG);
    if (sOwn != "") ExecuteScript(sOwn, OBJECT_SELF);

    int nPhysical = WthrPhysical(DAMAGE_TYPE_BLUDGEONING) + WthrPhysical(DAMAGE_TYPE_PIERCING)
                  + WthrPhysical(DAMAGE_TYPE_SLASHING);
    WthrPhysicalDamage(OBJECT_SELF, GetLastDamager(), nPhysical);
}
