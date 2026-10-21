// wthr_activate: module OnActivateItem (set by wthr_modload, or add this
// line to the module's own OnActivateItem script:
//     ExecuteScript("wthr_activate", OBJECT_SELF);
// Using the clothes brush (tag wthr_brush) brushes the user down.

#include "wthr_inc"

void main()
{
    WthrRunOriginal(EVENT_SCRIPT_MODULE_ON_ACTIVATE_ITEM);
    object oItem = GetItemActivated();
    if (GetTag(oItem) != WTHR_BRUSH_TAG) return;

    object oUser = GetItemActivator();
    if (!WthrBrush(oUser))
        FloatingTextStringOnCreature("Your clothes are clean already.", oUser, FALSE);
}
