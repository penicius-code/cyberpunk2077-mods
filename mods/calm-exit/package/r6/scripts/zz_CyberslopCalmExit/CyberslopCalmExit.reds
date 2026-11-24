// Cyberslop Calm Exit 1.0.0 (game 2.5) - by penicius-code
// Leaving a vehicle out of combat no longer pulls a weapon.
//
// Vanilla 2.5 (player\psm\vehicleTransition.swift):
//   CoolExitingEvents.OnExit   (double tap F = QuickExit jump-out, needs the Reflexes perk)
//     always sends RequestLastUsedOrFirstAvailableWeapon; OnUpdate draws Gorilla / Mantis / monowire
//     arms mid-exit when the last used weapon was arm chrome.
//   CombatExitingEvents.OnExit (exit while in combat, or from a car in "decay" = heavily damaged)
//     always sends RequestLastUsedOrFirstAvailableWeapon.
// This mod keeps both draws only while V is in combat (PSM Combat == 1) or had a gun out in the car
// (exit from driver combat). Combat exits through ExitingEventsBase (RequestLastUsedWeapon) stay vanilla.

// True when the vanilla exit draw should happen.
@addMethod(ExitingEvents)
protected final func CSCalmExit_ShouldDraw(scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  return this.m_fromDriverCombat || this.IsPlayerInCombat(scriptInterface);
}

// Cool exit, arm chrome: vanilla draws mid-exit once the camera is out of vehicle TPP.
// Out of combat, mark the draw as done for this tick so it never fires.
@wrapMethod(CoolExitingEvents)
protected func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  if !this.m_cwArmsEquipRequested || this.m_cwArmsEquipCompleted || this.CSCalmExit_ShouldDraw(scriptInterface) {
    wrappedMethod(timeDelta, stateContext, scriptInterface);
    return;
  };
  this.m_cwArmsEquipCompleted = true;
  wrappedMethod(timeDelta, stateContext, scriptInterface);
  this.m_cwArmsEquipCompleted = false;
}

// Cool exit: vanilla returns before its draw when (requested && completed). Set both for the call,
// restore afterwards. Everything vanilla does before that return (jump impulse, cool exit magnitude,
// TPP listener) still runs.
@wrapMethod(CoolExitingEvents)
protected func OnExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  if this.CSCalmExit_ShouldDraw(scriptInterface) {
    wrappedMethod(stateContext, scriptInterface);
    return;
  };
  let requested: Bool = this.m_cwArmsEquipRequested;
  let completed: Bool = this.m_cwArmsEquipCompleted;
  this.m_cwArmsEquipRequested = true;
  this.m_cwArmsEquipCompleted = true;
  wrappedMethod(stateContext, scriptInterface);
  this.m_cwArmsEquipRequested = requested;
  this.m_cwArmsEquipCompleted = completed;
}

// Damaged-car exit out of combat: same as vanilla minus the unconditional draw.
@replaceMethod(CombatExitingEvents)
public func OnExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  super.OnExit(stateContext, scriptInterface);
  if this.IsPlayerInCombat(scriptInterface) {
    this.SendEquipmentSystemWeaponManipulationRequest(scriptInterface, EquipmentManipulationAction.RequestLastUsedOrFirstAvailableWeapon, gameEquipAnimationType.Instant);
  };
}
