// wthr_equip: module OnPlayerEquipItem and OnPlayerUnEquipItem.
// New armor brings new textures, so the creature's dust and snow are sent
// to its new materials. The delay lets the new look settle first.
// If the module already has scripts there, add this line to them:
//     ExecuteScript("wthr_equip", OBJECT_SELF);

#include "wthr_inc"

void main()
{
    object oCreature = GetPCItemLastEquippedBy();
    if (!GetIsObjectValid(oCreature)) oCreature = GetPCItemLastUnequippedBy();
    if (!GetIsObjectValid(oCreature)) return;
    if (GetLocalFloat(oCreature, WTHR_VAR_DUST) <= 0.0 && GetLocalFloat(oCreature, WTHR_VAR_SNOW) <= 0.0) return;
    DelayCommand(0.5, WthrRefresh(oCreature));
}
