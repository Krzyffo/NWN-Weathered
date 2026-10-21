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
    // Players' blood comes from their own OnDamaged. Only a refusal is
    // worth a word: then players get no blood.
    if (!WthrHookPlayer(oPC) && GetLocalInt(GetModule(), WTHR_DEBUG))  // later, so it isn't lost while loading in
        DelayCommand(4.0, SendMessageToPC(oPC,
            "NWN-Weathered: the game refused an OnDamaged script on you, so you get no blood."));
    if (WthrHasAny(oPC)) DelayCommand(1.0, WthrRefresh(oPC));
}
