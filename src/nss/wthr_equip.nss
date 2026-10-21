// wthr_equip: module OnPlayerEquipItem and OnPlayerUnEquipItem (set by
// wthr_modload, or add this line to the module's own scripts there:
//     ExecuteScript("wthr_equip", OBJECT_SELF);
// New armor brings new textures, so the creature's dust and snow are sent
// to its new materials. The delay lets the new look settle first.

#include "wthr_inc"

void WthrRefreshLater(object oCreature)
{
    if (!GetIsObjectValid(oCreature)) return;
    if (GetLocalFloat(oCreature, WTHR_VAR_DUST) <= 0.0 && GetLocalFloat(oCreature, WTHR_VAR_SNOW) <= 0.0) return;
    DelayCommand(0.5, WthrRefresh(oCreature));
}

void main()
{
    WthrRunOriginal(GetCurrentlyRunningEvent());

    // Both getters keep their last value between events, so in one of the
    // two events the other one names whoever changed gear before. Refreshing
    // that creature too costs little and needs no check of which event runs.
    object oEquipped = GetPCItemLastEquippedBy();
    object oUnequipped = GetPCItemLastUnequippedBy();
    WthrRefreshLater(oEquipped);
    if (oUnequipped != oEquipped) WthrRefreshLater(oUnequipped);
}
