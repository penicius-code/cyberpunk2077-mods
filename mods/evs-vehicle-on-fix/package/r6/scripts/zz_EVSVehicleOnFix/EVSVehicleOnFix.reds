// EVS Vehicle On Fix 1.1.0 by penicius-code
// 1.0.0: brings back the third person car radio muffle with Enhanced Vehicle System.
// Vanilla turns the car On (vehicleEState.On) when V takes the driver seat
// (ToggleVehicleSystems -> TurnVehicleOn). EVS replaces ToggleVehicleSystems and
// skips TurnVehicleOn in full gameplay, so the car stays at Default and the game
// stops muffling the radio outside the car. Probe 2026-10-28: every "right" mark
// had state On, every one of six "wrong" marks with Default stayed wrong.
// While V drives with the engine running this keeps the state On (checked on
// mount and every 0.5 s). Engine off through EVS puts it back to Default, as EVS
// has it. Exit is left to EVS, which sets Default itself.
//
// 1.1.0 (2026-11-04): engine stays off after V switches it off and gets out.
// Bug: engine off (EVS Numpad 1 hold), exit, the car rolls a bit, stops, and the
// engine is running again. On exit two "NoDriver" + "DriverReady" AI pairs reach
// the empty car: EVS's own (OnUnmountingEvent) and, after any autodrive use,
// Auto Drive Enhanced's "moving on its own" workaround (DriverReady ~1.5 s after
// the exit). DriverReady wakes the vehicle AI, which turns the engine on behind
// EVS, so EVS's engine flag still says off. For 8 s from the start of the exit
// this checks every 0.25 s: EVS flag off and engine on -> engine off, state
// back to Default (as EVS leaves a parked car) and, at walking speed or less, the
// brakes until it stands. Only cars V drove (EVS's flag), only when V left the
// driver seat. A new mount by anyone stops the watch. Log: [EVSOnFix] in the
// redscript / CET log, one line per catch.

@addField(VehicleComponent)
let m_evsOnFixGen: Int32;

@addField(VehicleComponent)
let m_evsOnFixSetOn: Bool;

@addField(VehicleComponent)
let m_evsOnFixExitGen: Int32;

public class EVSVehicleOnFixTick extends DelayCallback {
  public let comp: wref<VehicleComponent>;
  public let gen: Int32;

  public func Call() -> Void {
    let comp: ref<VehicleComponent> = this.comp;
    if IsDefined(comp) {
      comp.EVSOnFixTick(this.gen);
    };
  }
}

public class EVSVehicleOnFixExitWatch extends DelayCallback {
  public let comp: wref<VehicleComponent>;
  public let gen: Int32;
  public let left: Int32;

  public func Call() -> Void {
    let comp: ref<VehicleComponent> = this.comp;
    if IsDefined(comp) {
      comp.EVSOnFixExitWatch(this.gen, this.left);
    };
  }
}

@addMethod(VehicleComponent)
public final func EVSOnFixTick(gen: Int32) -> Void {
  let vehicle: ref<VehicleObject> = this.GetVehicle();
  let ctrl: ref<vehicleControllerPS>;
  let player: ref<PlayerPuppet>;
  let tick: ref<EVSVehicleOnFixTick>;
  // a newer mount or an exit started since this tick was armed
  if gen != this.m_evsOnFixGen || !IsDefined(vehicle) {
    return;
  };
  player = GameInstance.GetPlayerSystem(vehicle.GetGame()).GetLocalPlayerMainGameObject() as PlayerPuppet;
  if !IsDefined(player) || !VehicleComponent.IsMountedToProvidedVehicle(vehicle.GetGame(), player.GetEntityID(), vehicle) || !vehicle.IsPlayerDriver() {
    return;
  };
  ctrl = this.GetVehicleControllerPS();
  if IsDefined(ctrl) {
    if vehicle.IsEngineTurnedOn() {
      if Equals(ctrl.GetState(), vehicleEState.Default) {
        ctrl.SetState(vehicleEState.On);
        this.m_evsOnFixSetOn = true;
      };
    } else {
      // only undo our own On, so a quest or EVS state is never touched
      if this.m_evsOnFixSetOn && Equals(ctrl.GetState(), vehicleEState.On) {
        ctrl.SetState(vehicleEState.Default);
      };
      this.m_evsOnFixSetOn = false;
    };
  };
  tick = new EVSVehicleOnFixTick();
  tick.comp = this;
  tick.gen = gen;
  GameInstance.GetDelaySystem(vehicle.GetGame()).DelayCallback(tick, 0.5, false);
}

// EVS's own engine flag (persistent on the vehicle PS). Without EVS: "on", so the
// exit watch never touches a car.
@if(ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(VehicleComponent)
public final func EVSOnFixWantsEngine() -> Bool {
  return this.GetPS().m_hgyi56_EVS_engineState;
}

@if(!ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(VehicleComponent)
public final func EVSOnFixWantsEngine() -> Bool {
  return true;
}

@if(ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(VehicleComponent)
public final func EVSOnFixDrivenByV() -> Bool {
  return this.GetPS().m_hgyi56_EVS_vehicleDrivenByV;
}

@if(!ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(VehicleComponent)
public final func EVSOnFixDrivenByV() -> Bool {
  return false;
}

@addMethod(VehicleComponent)
public final func EVSOnFixStartExitWatch() -> Void {
  let vehicle: ref<VehicleObject> = this.GetVehicle();
  let watch: ref<EVSVehicleOnFixExitWatch>;
  if !IsDefined(vehicle) || !this.EVSOnFixDrivenByV() {
    return;
  };
  this.m_evsOnFixExitGen += 1;
  watch = new EVSVehicleOnFixExitWatch();
  watch.comp = this;
  watch.gen = this.m_evsOnFixExitGen;
  watch.left = 32; // 32 x 0.25 s = 8 s
  GameInstance.GetDelaySystem(vehicle.GetGame()).DelayCallback(watch, 0.25, false);
}

@addMethod(VehicleComponent)
public final func EVSOnFixExitWatch(gen: Int32, left: Int32) -> Void {
  let vehicle: ref<VehicleObject> = this.GetVehicle();
  let ctrl: ref<vehicleControllerPS>;
  let speed: Float;
  let watch: ref<EVSVehicleOnFixExitWatch>;
  if gen != this.m_evsOnFixExitGen || !IsDefined(vehicle) {
    return;
  };
  // V (or a script) switched the engine on through EVS since the exit: leave it
  if this.EVSOnFixWantsEngine() {
    return;
  };
  if vehicle.IsEngineTurnedOn() {
    vehicle.TurnEngineOn(false);
    ctrl = this.GetVehicleControllerPS();
    if IsDefined(ctrl) && Equals(ctrl.GetState(), vehicleEState.On) {
      ctrl.SetState(vehicleEState.Default);
    };
    speed = AbsF(vehicle.GetCurrentSpeed());
    // creep only (about 18 km/h or less); a car V bailed out of at speed keeps rolling
    if speed < 5.0 {
      vehicle.ForceBrakesUntilStoppedOrFor(3.0);
    };
    FTLog(s"[EVSOnFix] engine came back on after exit (watch tick \(32 - left + 1)/32, speed \(speed) m/s): turned off" + (speed < 5.0 ? ", brakes" : ""));
  };
  if left > 1 {
    watch = new EVSVehicleOnFixExitWatch();
    watch.comp = this;
    watch.gen = gen;
    watch.left = left - 1;
    GameInstance.GetDelaySystem(vehicle.GetGame()).DelayCallback(watch, 0.25, false);
  };
}

@wrapMethod(VehicleComponent)
protected cb func OnVehicleFinishedMountingEvent(evt: ref<VehicleFinishedMountingEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if evt.isMounting && VehicleComponent.IsDriverSlot(evt.slotID) && IsDefined(evt.character) && evt.character.IsPlayer() {
    this.m_evsOnFixGen += 1;
    this.m_evsOnFixSetOn = false;
    this.EVSOnFixTick(this.m_evsOnFixGen);
  };
  return result;
}

// Stop before EVS's exit code runs, so its Default is not turned back to On.
// 1.1.0: a player exit from the driver seat starts the engine-off watch (after
// EVS's exit code, so its exit behaviour has set the engine flag); any mount
// cancels a running watch.
@wrapMethod(VehicleComponent)
protected cb func OnVehicleStartedMountingEvent(evt: ref<VehicleStartedMountingEvent>) -> Bool {
  let result: Bool;
  let playerExitsDriverSeat: Bool = false;
  if !evt.isMounting && IsDefined(evt.character) && evt.character.IsPlayer() {
    this.m_evsOnFixGen += 1;
    this.m_evsOnFixSetOn = false;
    playerExitsDriverSeat = VehicleComponent.IsDriverSlot(evt.slotID);
  };
  if evt.isMounting {
    this.m_evsOnFixExitGen += 1;
  };
  result = wrappedMethod(evt);
  if playerExitsDriverSeat {
    this.EVSOnFixStartExitWatch();
  };
  return result;
}
