// wthr_areaenter: every area's OnEnter (set by wthr_modload, which keeps
// the area's own script and runs it first). Fires for every creature that
// appears in the area: spawned by a script or an encounter, summoned, or
// walking in from elsewhere. Those that aren't a player's party get their
// starting look and blood set up right away. Players are handled by their
// own loop when it notices they arrived.

#include "wthr_inc"

void main()
{
    object oArea = OBJECT_SELF;
    string sOwn = GetLocalString(oArea, WTHR_VAR_ORIG_AREA_ENTER);
    if (sOwn != "") ExecuteScript(sOwn, oArea);

    object oCreature = GetEnteringObject();
    if (GetObjectType(oCreature) != OBJECT_TYPE_CREATURE || WthrIsPartyMember(oCreature)) return;
    // A moment later, so a spawn script has set its variables first.
    if (!GetLocalInt(oCreature, WTHR_VAR_SEEN)) DelayCommand(0.5, WthrStartLook(oCreature, oArea));
}
