// wthr_enter: module OnClientEnter (set by wthr_modload, or add
//     ExecuteScript("wthr_enter", GetEnteringObject());
// to the module's own OnClientEnter script).
// Starts the player's weathering and, after loading a saved game, shows
// the dust and snow the character had.

#include "wthr_inc"

void main()
{
    WthrRunOriginal(EVENT_SCRIPT_MODULE_ON_CLIENT_ENTER);
    object oPC = GetEnteringObject();
    if (!GetIsObjectValid(oPC)) oPC = OBJECT_SELF;  // run through ExecuteScript
    if (!GetIsPC(oPC) || GetLocalInt(oPC, WTHR_SKIP)) return;

    WthrStartLoop(oPC);
    if (WthrHasAny(oPC)) DelayCommand(1.0, WthrRefresh(oPC));
}
