// Vehicle Camera Hold FPP 1.1.0 by penicius-code, for game 2.5
// 1.1.0: game 2.5 port (VehicleEventsTransition.HandleCameraInput takes the state context now).
// Holding the vehicle camera button (Q / D-pad right, 0.5 s) in any third person
// view jumps straight back to first person. Tap cycles as before. Autodrive keeps
// the vanilla hold (cinematic camera). Needs r6\input\VehicleCameraHoldFPP.xml
// (Input Loader), which adds the hold action VehCamHoldFPP to the drive,
// passenger and driver combat contexts.
// The release of the button after the hold still reaches the vanilla toggle
// (IsActionJustReleased in driver combat), so that one release is swallowed.

@addField(VehicleTransition)
let m_vchfSwallowRelease: Bool;

@addMethod(VehicleTransition)
protected final func VchfHandleHold(scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let vehicle: ref<VehicleObject>;
  if scriptInterface.IsActionJustHeld(n"VehCamHoldFPP") && !this.IsVehicleCameraChangeBlocked(scriptInterface) {
    if scriptInterface.localBlackboard.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Vision) == 1 {
      return;
    };
    // a hold never cycles, also when already in first person
    this.m_vchfSwallowRelease = true;
    vehicle = scriptInterface.owner as VehicleObject;
    if IsDefined(vehicle) && NotEquals(vehicle.GetCameraManager().GetActivePerspective(), vehicleCameraPerspective.FPP) {
      this.RequestVehicleCameraPerspective(scriptInterface, vehicleCameraPerspective.FPP);
    };
  };
}

// Drive and passenger states (Dark Future replaces this method; the wrap sits on top)
// 2.5 port: HandleCameraInput gained stateContext (vehicleTransition.swift); like the vanilla cinematic
// camera hold, the FPP hold does nothing while an item wheel is open (2.5 has the weapon wheel on a hold in vehicles).
@wrapMethod(VehicleEventsTransition)
protected final func HandleCameraInput(const stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  if !this.IsInItemWheelState(stateContext) {
    this.VchfHandleHold(scriptInterface);
  };
  wrappedMethod(stateContext, scriptInterface);
  if scriptInterface.IsActionJustReleased(n"ToggleVehCamera") {
    this.m_vchfSwallowRelease = false;
  };
}

// Driver combat state has its own OnUpdate input handling
@wrapMethod(DriverCombatEvents)
protected func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  this.VchfHandleHold(scriptInterface);
  wrappedMethod(timeDelta, stateContext, scriptInterface);
  if scriptInterface.IsActionJustReleased(n"ToggleVehCamera") {
    this.m_vchfSwallowRelease = false;
  };
}

@wrapMethod(VehicleTransition)
protected final func RequestToggleVehicleCamera(scriptInterface: ref<StateGameScriptInterface>) -> Void {
  if this.m_vchfSwallowRelease {
    this.m_vchfSwallowRelease = false;
    return;
  };
  wrappedMethod(scriptInterface);
}

@wrapMethod(DriverCombatEvents)
private final func RequestToggleVehicleDriverCombatCamera(scriptInterface: ref<StateGameScriptInterface>) -> Void {
  if this.m_vchfSwallowRelease {
    this.m_vchfSwallowRelease = false;
    return;
  };
  wrappedMethod(scriptInterface);
}
