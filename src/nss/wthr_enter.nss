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
    int bHooked = WthrHookPlayer(oPC);
    if (GetLocalInt(GetModule(), WTHR_DEBUG))  // later, so it isn't lost while the player loads in
        DelayCommand(4.0, SendMessageToPC(oPC, bHooked
            ? "NWN-Weathered: the game accepted an OnDamaged script on you; hit point checks run until it fires."
            : "NWN-Weathered: players can't have an OnDamaged script here; blood uses hit point checks."));
    if (WthrHasAny(oPC)) DelayCommand(1.0, WthrRefresh(oPC));
}
