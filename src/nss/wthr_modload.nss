// wthr_modload: puts the NWN-Weathered scripts on the module events and
// keeps the module's own scripts: each of ours runs the original first.
//   OnClientEnter        wthr_enter     start the player's weathering
//   OnPlayerChat         wthr_chat      /brush, and test commands
//   OnActivateItem       wthr_activate  the clothes brush
//   OnPlayerTarget       wthr_target    a DM picking a creature for a test command
//   OnPlayerEquipItem    wthr_equip     keep the look across armor changes
//   OnPlayerUnEquipItem  wthr_equip
//   OnPlayerRest         wthr_rest      resting cleans up
//
// Set it as the module's OnModuleLoad, or, if the module already has one,
// add this line to that script:
//     ExecuteScript("wthr_modload", OBJECT_SELF);
// Then leave the events above as they are: don't also call our scripts
// from the module's own ones.

#include "wthr_inc"

void main()
{
    WthrRunOriginal(EVENT_SCRIPT_MODULE_ON_MODULE_LOAD);
    WthrHookEvent(EVENT_SCRIPT_MODULE_ON_CLIENT_ENTER, "wthr_enter");
    WthrHookEvent(EVENT_SCRIPT_MODULE_ON_PLAYER_CHAT, "wthr_chat");
    WthrHookEvent(EVENT_SCRIPT_MODULE_ON_ACTIVATE_ITEM, "wthr_activate");
    WthrHookEvent(EVENT_SCRIPT_MODULE_ON_PLAYER_TARGET, "wthr_target");
    WthrHookEvent(EVENT_SCRIPT_MODULE_ON_EQUIP_ITEM, "wthr_equip");
    WthrHookEvent(EVENT_SCRIPT_MODULE_ON_UNEQUIP_ITEM, "wthr_equip");
    WthrHookEvent(EVENT_SCRIPT_MODULE_ON_PLAYER_REST, "wthr_rest");
}
