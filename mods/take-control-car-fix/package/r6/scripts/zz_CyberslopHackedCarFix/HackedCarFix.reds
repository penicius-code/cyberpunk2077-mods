// Cyberslop Hacked Car Fix 1.1.3 (penicius-code), patch 2.5
// 1.1.3 (2026-11-24): the engine stays on after Take Control ends (the game switches the car off on release):
// for 4 s after the release a car that is off is switched on again, unless V got in or it is destroyed.
// 1.1.2 (2026-11-23): an autodrive start the game refuses (K does nothing) is logged with the reason: lane,
// availability, combat / seat state, health, race lock and the car's state. Log only, nothing is changed.
// 1.1.1 (2026-11-23): getter CSHCF_TakenOver() for the CET window Vehicle Actions (CET 1.38.1 reads fields as nil).
// Fixes a car after the vanilla "Take Control" vehicle quickhack (Quickhack All Vehicles / StealthRC make it
// available on most cars).
//
// Trunk: vanilla bug. Take Control sends DisableAllInteractions (all 6 door slots: 4 seats, trunk, hood -> Disabled).
// Release sends ResetInteractions, whose ResetVehicleInteractionState only resets the 4 seats, so trunk and hood
// stay Disabled for good and GetTrunkActions offers nothing. Fix: the trunk / hood state from before the hack is
// saved when control starts and put back when it ends (Available if nothing was saved).
//
// 1.1.0 (2026-11-20, bug report: "controlling the vehicle doesn't turn on the vehicle" with 1.0.0): while Take Control runs,
// every 0.5 s: a car that is off (engine or vehicle state) is switched on (EVS power + engine flags set, so EVS and
// EVS Vehicle On Fix agree), first catch logged with the car's state. Repairs no longer send "NoDriver" and no
// longer cancel AI vehicle commands (both only logged now); the light repair on entry touches no AI at all.
// Every log line also goes to the CSHCFLog scriptable system, which Vehicle Actions 1.3.1 writes to its own
// file (CET's gamelog.log is buffered and only reaches disk late).
//
// Autodrive (vanilla native AI, K): turns itself off in a car V took control of; ADE's modded AI works. The native
// cause is not visible in scripts, so this clears what Take Control can leave on the car and logs the state:
//   - getting into the driver seat of a hacked car: stale remote-control flag, stale player remote-control id,
//     trunk / hood
//   - vanilla autodrive switching itself off within 6 s (not by V: K, accelerate or ADE's disable request): one
//     log line with the car's state; in a hacked car also a full repair (above + lingering forced brakes, unused
//     seat reservations, engine on through EVS, car On, DriverReady) and one automatic retry of autodrive.
//     A run of 8 s clears the car's hacked flag.
// CET window "Vehicle Actions" 1.3.x calls CSHCF_Repair(true, ...) from its "Fix hacked car" button.

@addField(VehicleComponentPS)
public persistent let m_csHcfTakenOver: Bool;          // V took control of this car with the Take Control hack

@addField(VehicleComponentPS)
public persistent let m_csHcfRemoteActive: Bool;       // remote control running (start seen, release not yet)

// 1.1.1: for CET (Vehicle Actions "hacked earlier; autodrive watched")
@addMethod(VehicleComponentPS)
public func CSHCF_TakenOver() -> Bool {
  return this.m_csHcfTakenOver;
}

@addField(VehicleComponentPS)
public persistent let m_csHcfHasSnapshot: Bool;

@addField(VehicleComponentPS)
public persistent let m_csHcfTrunkBefore: Int32;       // VehicleDoorInteractionState before the hack

@addField(VehicleComponentPS)
public persistent let m_csHcfHoodBefore: Int32;

@addField(VehicleComponent)
private let m_csHcfOnGen: Int32;                        // take-control keep-on loop generation

// ------------------------------------------------------------------ log (CET gamelog.log + ring for Vehicle Actions)

public class CSHCFLog extends ScriptableSystem {
  private let m_lines: array<String>;
  private let m_count: Int32;

  public static func Get(gi: GameInstance) -> ref<CSHCFLog> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"CSHCFLog") as CSHCFLog;
  }

  public final func Add(line: String) -> Void {
    this.m_count += 1;
    ArrayPush(this.m_lines, line);
    if ArraySize(this.m_lines) > 30 {
      ArrayErase(this.m_lines, 0);
    };
  }

  // lines ever added (Vehicle Actions compares it with what it has written)
  public final func Count() -> Int32 {
    return this.m_count;
  }

  public final func Size() -> Int32 {
    return ArraySize(this.m_lines);
  }

  public final func Line(i: Int32) -> String {
    if i < 0 || i >= ArraySize(this.m_lines) {
      return "";
    };
    return this.m_lines[i];
  }
}

public static func CSHCF_Log(gi: GameInstance, text: String) -> Void {
  let log: ref<CSHCFLog>;
  FTLog("[CSHackedCar] " + text);
  log = CSHCFLog.Get(gi);
  if IsDefined(log) {
    log.Add(text);
  };
}

public class CSHCFRepairCallback extends DelayCallback {
  public let comp: wref<VehicleComponent>;
  public let forced: Bool;
  public let reason: String;

  public func Call() -> Void {
    let comp: ref<VehicleComponent> = this.comp;
    if IsDefined(comp) {
      comp.CSHCF_Repair(this.forced, this.reason);
    };
  }
}

public class CSHCFKeepOnCallback extends DelayCallback {
  public let comp: wref<VehicleComponent>;
  public let gen: Int32;
  public let ticks: Int32;
  public let caught: Int32;

  public func Call() -> Void {
    let comp: ref<VehicleComponent> = this.comp;
    if IsDefined(comp) {
      comp.CSHCF_KeepOnTick(this.gen, this.ticks, this.caught);
    };
  }
}

public class CSHCFAutodriveOkCheck extends DelayCallback {
  public let sys: wref<AutoDriveSystem>;
  public let gen: Int32;

  public func Call() -> Void {
    let sys: ref<AutoDriveSystem> = this.sys;
    if IsDefined(sys) {
      sys.CSHCF_OkCheck(this.gen);
    };
  }
}

// ------------------------------------------------------------------ take control start / end

@wrapMethod(VehicleComponent)
protected cb func OnRemoteControlEvent(evt: ref<VehicleRemoteControlEvent>) -> Bool {
  let ps: ref<VehicleComponentPS> = this.GetPS();
  let vehicle: ref<VehicleObject> = this.GetVehicle();
  let result: Bool;
  let restored: String;
  let tick: ref<CSHCFKeepOnCallback>;
  let stay: ref<CSHCFStayOnCallback>;
  if !IsDefined(ps) || !IsDefined(vehicle) {
    return wrappedMethod(evt);
  };
  if evt.remoteControl {
    // read before vanilla queues DisableAllInteractions; a second start during the same control keeps the first
    if !ps.m_csHcfRemoteActive {
      ps.m_csHcfTrunkBefore = EnumInt(ps.GetDoorInteractionState(EVehicleDoor.trunk));
      ps.m_csHcfHoodBefore = EnumInt(ps.GetDoorInteractionState(EVehicleDoor.hood));
      ps.m_csHcfHasSnapshot = true;
    };
    ps.m_csHcfRemoteActive = true;
    ps.m_csHcfTakenOver = true;
    result = wrappedMethod(evt);
    CSHCF_Log(vehicle.GetGame(), s"take control started (engine \(vehicle.IsEngineTurnedOn()), on \(vehicle.IsVehicleTurnedOn()))" + this.CSHCF_EvsText());
    // keep the car switched on while V drives it remotely
    this.m_csHcfOnGen += 1;
    tick = new CSHCFKeepOnCallback();
    tick.comp = this;
    tick.gen = this.m_csHcfOnGen;
    tick.ticks = 0;
    tick.caught = 0;
    GameInstance.GetDelaySystem(vehicle.GetGame()).DelayCallback(tick, 0.3, false);
    return result;
  };
  this.m_csHcfOnGen += 1;
  result = wrappedMethod(evt);
  ps.m_csHcfRemoteActive = false;
  // vanilla resets the seats only when shouldModifyInteractionState is set; trunk and hood never
  restored = this.CSHCF_RestoreDoors(!evt.shouldModifyInteractionState);
  CSHCF_Log(vehicle.GetGame(), s"take control ended (distance disconnect \(evt.isDistanceDisconnect), vanilla door reset \(evt.shouldModifyInteractionState), engine \(vehicle.IsEngineTurnedOn())): restored" + (StrLen(restored) > 0 ? restored : " nothing"));
  // 1.1.3: keep the engine running after the release
  stay = new CSHCFStayOnCallback();
  stay.comp = this;
  stay.gen = this.m_csHcfOnGen;
  stay.ticks = 0;
  stay.caught = 0;
  GameInstance.GetDelaySystem(vehicle.GetGame()).DelayCallback(stay, 0.1, false);
  return result;
}

// every 0.5 s while the car is remote-controlled (up to 30 min); switches a car that went off back on
@addMethod(VehicleComponent)
public final func CSHCF_KeepOnTick(gen: Int32, ticks: Int32, caught: Int32) -> Void {
  let vehicle: ref<VehicleObject> = this.GetVehicle();
  let ps: ref<VehicleComponentPS> = this.GetPS();
  let ctrl: ref<vehicleControllerPS>;
  let next: ref<CSHCFKeepOnCallback>;
  let engine: Bool;
  let on: Bool;
  let state: Int32 = -1;
  let before: String;
  if gen != this.m_csHcfOnGen || !IsDefined(vehicle) || !IsDefined(ps) || !vehicle.IsVehicleRemoteControlled() || ps.GetIsDestroyed() {
    return;
  };
  engine = vehicle.IsEngineTurnedOn();
  on = vehicle.IsVehicleTurnedOn();
  ctrl = this.GetVehicleControllerPS();
  if IsDefined(ctrl) {
    state = EnumInt(ctrl.GetState());
  };
  if !engine || !on {
    if caught == 0 {
      before = this.CSHCF_StateText();
    };
    vehicle.TurnVehicleOn(true);
    this.CSHCF_EngineOn();
    if IsDefined(ctrl) && NotEquals(ctrl.GetState(), vehicleEState.On) {
      ctrl.SetState(vehicleEState.On);
    };
    caught += 1;
    if caught == 1 {
      CSHCF_Log(vehicle.GetGame(), s"take control: car was off after \(Cast<Float>(ticks) * 0.5 + 0.3) s (engine \(engine), on \(on), state \(state)) -> switched on | " + before);
    } else {
      if caught == 2 || caught == 10 {
        CSHCF_Log(vehicle.GetGame(), s"take control: car went off again (\(caught) times, engine \(engine), on \(on), state \(state)) -> switched on");
      };
    };
  };
  if ticks < 3600 {
    next = new CSHCFKeepOnCallback();
    next.comp = this;
    next.gen = gen;
    next.ticks = ticks + 1;
    next.caught = caught;
    GameInstance.GetDelaySystem(vehicle.GetGame()).DelayCallback(next, 0.5, false);
  };
}

// ------------------------------------------------------------------ V gets into the driver seat

@wrapMethod(VehicleComponent)
protected cb func OnVehicleFinishedMountingEvent(evt: ref<VehicleFinishedMountingEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  let cb: ref<CSHCFRepairCallback>;
  let vehicle: ref<VehicleObject> = this.GetVehicle();
  if evt.isMounting && VehicleComponent.IsDriverSlot(evt.slotID) && IsDefined(evt.character) && evt.character.IsPlayer()
  && IsDefined(vehicle) && this.CSHCF_IsSuspect() {
    // after EVS and the vanilla mount code have run
    cb = new CSHCFRepairCallback();
    cb.comp = this;
    cb.forced = false;
    cb.reason = "V entered";
    GameInstance.GetDelaySystem(vehicle.GetGame()).DelayCallback(cb, 0.5, false);
  };
  return result;
}

// ------------------------------------------------------------------ helpers on the car

// hacked by V, still flagged remote-controlled, or the vanilla bug's footprint (trunk + hood Disabled, seats not)
@addMethod(VehicleComponent)
public final func CSHCF_IsSuspect() -> Bool {
  let vehicle: ref<VehicleObject> = this.GetVehicle();
  let ps: ref<VehicleComponentPS> = this.GetPS();
  if !IsDefined(vehicle) || !IsDefined(ps) {
    return false;
  };
  if ps.m_csHcfTakenOver || vehicle.IsVehicleRemoteControlled() {
    return true;
  };
  return this.CSHCF_HasBugFootprint();
}

@addMethod(VehicleComponent)
public final func CSHCF_HasBugFootprint() -> Bool {
  let ps: ref<VehicleComponentPS> = this.GetPS();
  if !IsDefined(ps) {
    return false;
  };
  return Equals(ps.GetDoorInteractionState(EVehicleDoor.trunk), VehicleDoorInteractionState.Disabled)
    && Equals(ps.GetDoorInteractionState(EVehicleDoor.hood), VehicleDoorInteractionState.Disabled)
    && NotEquals(ps.GetDoorInteractionState(EVehicleDoor.seat_front_left), VehicleDoorInteractionState.Disabled);
}

// Disabled -> target, through the PS event vanilla uses (DetermineInteractionState runs on the entity)
@addMethod(VehicleComponent)
public final func CSHCF_SetDoorIfDisabled(door: EVehicleDoor, target: VehicleDoorInteractionState) -> Bool {
  let ps: ref<VehicleComponentPS> = this.GetPS();
  let vehicle: ref<VehicleObject> = this.GetVehicle();
  let evt: ref<VehicleDoorInteractionStateChange>;
  if !IsDefined(ps) || !IsDefined(vehicle) || Equals(target, VehicleDoorInteractionState.Disabled) {
    return false;
  };
  if NotEquals(ps.GetDoorInteractionState(door), VehicleDoorInteractionState.Disabled) {
    return false;
  };
  evt = new VehicleDoorInteractionStateChange();
  evt.door = door;
  evt.newState = target;
  evt.source = "CyberslopHackedCarFix";
  GameInstance.GetPersistencySystem(vehicle.GetGame()).QueuePSEvent(ps.GetID(), ps.GetClassName(), evt);
  return true;
}

// trunk + hood back to their pre-hack state (Available without a snapshot); front seats too when asked
@addMethod(VehicleComponent)
public final func CSHCF_RestoreDoors(frontSeats: Bool) -> String {
  let ps: ref<VehicleComponentPS> = this.GetPS();
  let out: String = "";
  let trunkTo: VehicleDoorInteractionState = VehicleDoorInteractionState.Available;
  let hoodTo: VehicleDoorInteractionState = VehicleDoorInteractionState.Available;
  if !IsDefined(ps) {
    return out;
  };
  if ps.m_csHcfHasSnapshot {
    trunkTo = IntEnum<VehicleDoorInteractionState>(ps.m_csHcfTrunkBefore);
    hoodTo = IntEnum<VehicleDoorInteractionState>(ps.m_csHcfHoodBefore);
  };
  if this.CSHCF_SetDoorIfDisabled(EVehicleDoor.trunk, trunkTo) {
    out = out + " trunk";
  };
  if this.CSHCF_SetDoorIfDisabled(EVehicleDoor.hood, hoodTo) {
    out = out + " hood";
  };
  if frontSeats {
    if this.CSHCF_SetDoorIfDisabled(EVehicleDoor.seat_front_left, VehicleDoorInteractionState.Available) {
      out = out + " driver-door";
    };
    if this.CSHCF_SetDoorIfDisabled(EVehicleDoor.seat_front_right, VehicleDoorInteractionState.Available) {
      out = out + " passenger-door";
    };
  };
  ps.m_csHcfHasSnapshot = false;
  return out;
}

@if(ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(VehicleComponent)
private final func CSHCF_EngineOn() -> Void {
  // EVS's own engine path keeps its flags in step (EVS Vehicle On Fix and EVS read them)
  this.hgyi56_EVS_TogglePowerState(true);
  this.hgyi56_EVS_ToggleEngineState(true);
}

@if(!ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(VehicleComponent)
private final func CSHCF_EngineOn() -> Void {
  let vehicle: ref<VehicleObject> = this.GetVehicle();
  vehicle.TurnVehicleOn(true);
  vehicle.TurnEngineOn(true);
}

@if(ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(VehicleComponent)
private final func CSHCF_EvsText() -> String {
  let ps: ref<VehicleComponentPS> = this.GetPS();
  return s" evsEngine=\(ps.m_hgyi56_EVS_engineState) evsPower=\(ps.m_hgyi56_EVS_powerState) evsDrivenByV=\(ps.m_hgyi56_EVS_vehicleDrivenByV)";
}

@if(!ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(VehicleComponent)
private final func CSHCF_EvsText() -> String {
  return "";
}

@addMethod(VehicleComponent)
public final func CSHCF_StateText() -> String {
  let vehicle: ref<VehicleObject> = this.GetVehicle();
  let ps: ref<VehicleComponentPS> = this.GetPS();
  let ctrl: ref<vehicleControllerPS>;
  let ai: ref<AIVehicleAgent>;
  let cmd: ref<AICommand>;
  let cmdName: String = "none";
  let reserved: Int32 = -1;
  let driverReserved: Bool = false;
  let ctrlState: Int32 = -1;
  let gi: GameInstance;
  if !IsDefined(vehicle) || !IsDefined(ps) {
    return "no vehicle";
  };
  gi = vehicle.GetGame();
  ai = vehicle.GetAIComponent();
  if IsDefined(ai) {
    cmd = ai.GetEnqueuedOrExecutingCommand(n"AIVehicleCommand", true);
    if IsDefined(cmd) {
      cmdName = NameToString(cmd.GetClassName());
    };
    reserved = Cast<Int32>(ai.GetReservedSeatsCount());
    driverReserved = ai.IsSeatReserved(n"seat_front_left");
  };
  ctrl = this.GetVehicleControllerPS();
  if IsDefined(ctrl) {
    ctrlState = EnumInt(ctrl.GetState());
  };
  return s"car=\(TDBID.ToStringDEBUG(vehicle.GetRecordID())) takenOver=\(ps.m_csHcfTakenOver) remote=\(vehicle.IsVehicleRemoteControlled()) accelHack=\(vehicle.IsVehicleAccelerateQuickhackActive()) brakeHack=\(vehicle.IsVehicleForceBrakesQuickhackActive())"
    + s" questPhys=\(vehicle.IsInQuestOrScenePhysicsState()) trafficPhys=\(vehicle.IsInTrafficPhysicsState()) trafficSlot=\(vehicle.HasTrafficSlot()) driverCmds=\(vehicle.CommandsFromDriverEnabled()) anyCmd=\(vehicle.IsExecutingAnyCommand()) aiCmd=\(cmdName)"
    + s" reserved=\(reserved) driverSeatReserved=\(driverReserved) autopilotBB=\(VehicleComponent.HasActiveAutopilot(gi, vehicle)) playerVeh=\(vehicle.IsPlayerVehicle()) stolen=\(vehicle.IsStolen()) crowd=\(vehicle.IsCrowdVehicle()) quest=\(vehicle.IsQuest())"
    + s" engine=\(vehicle.IsEngineTurnedOn()) on=\(vehicle.IsVehicleTurnedOn()) ctrlState=\(ctrlState) speed=\(vehicle.GetCurrentSpeed())"
    + s" doors fl/fr/trunk/hood=\(EnumInt(ps.GetDoorInteractionState(EVehicleDoor.seat_front_left)))/\(EnumInt(ps.GetDoorInteractionState(EVehicleDoor.seat_front_right)))/\(EnumInt(ps.GetDoorInteractionState(EVehicleDoor.trunk)))/\(EnumInt(ps.GetDoorInteractionState(EVehicleDoor.hood)))"
    + this.CSHCF_EvsText();
}

// forced = autodrive dropped or the Vehicle Actions button: everything; otherwise (V got in) doors and stale flags only
@addMethod(VehicleComponent)
public final func CSHCF_Repair(forced: Bool, reason: String) -> String {
  let vehicle: ref<VehicleObject> = this.GetVehicle();
  let ps: ref<VehicleComponentPS> = this.GetPS();
  let gi: GameInstance;
  let player: ref<PlayerPuppet>;
  let isDriver: Bool;
  let done: String = "";
  let before: String;
  let bb: ref<IBlackboard>;
  let remoteID: EntityID;
  let noID: EntityID;
  let remoteVehicle: wref<VehicleObject>;
  let ai: ref<AIVehicleAgent>;
  let adSys: ref<AutoDriveSystem>;
  let autodriveOn: Bool = false;
  let seats: array<CName>;
  let ctrl: ref<vehicleControllerPS>;
  let aiEvent: ref<AIEvent>;
  if !IsDefined(vehicle) || !IsDefined(ps) {
    return " no vehicle";
  };
  gi = vehicle.GetGame();
  player = GetPlayer(gi);
  isDriver = vehicle.IsPlayerDriver();
  before = this.CSHCF_StateText();

  // 1. remote-control flag still on (V sits in the car, or asked for it)
  if vehicle.IsVehicleRemoteControlled() && (isDriver || forced) {
    vehicle.SetVehicleRemoteControlled(false, false, true);
    done = done + " remote-flag-off";
  };
  if !vehicle.IsVehicleRemoteControlled() {
    ps.m_csHcfRemoteActive = false;
  };

  // 2. player's remote-control vehicle id left set (vanilla then ignores every car interaction)
  if IsDefined(player) {
    bb = player.GetPlayerStateMachineBlackboard();
    if IsDefined(bb) {
      remoteID = bb.GetEntityID(GetAllBlackboardDefs().PlayerStateMachine.EntityIDVehicleRemoteControlled);
      if EntityID.IsDefined(remoteID) {
        if !VehicleComponent.GetVehicleFromID(gi, remoteID, remoteVehicle) || !remoteVehicle.IsVehicleRemoteControlled() {
          bb.SetEntityID(GetAllBlackboardDefs().PlayerStateMachine.EntityIDVehicleRemoteControlled, noID);
          done = done + " player-remote-id";
        };
      };
    };
  };

  // 3. trunk / hood (and front doors) left Disabled
  if forced || ps.m_csHcfTakenOver || this.CSHCF_HasBugFootprint() {
    done = done + this.CSHCF_RestoreDoors(true);
  };

  if forced {
    ai = vehicle.GetAIComponent();
    adSys = GameInstance.GetScriptableSystemsContainer(gi).Get(n"AutoDriveSystem") as AutoDriveSystem;
    if IsDefined(adSys) && isDriver {
      autodriveOn = adSys.GetAutodriveEnabled();
    };
    // 4. forced brakes still holding the car (vanilla autodrive stop / remote-control release)
    if isDriver && !autodriveOn {
      vehicle.ForceBrakesUntilStoppedOrFor(0.0);
      done = done + " brakes-released";
    };
    // 5. seat reservations nobody sits in (the fled NPC driver's)
    if IsDefined(ai) && ai.GetReservedSeatsCount() > 0u {
      ArrayPush(seats, n"seat_front_left");
      ArrayPush(seats, n"seat_front_right");
      ArrayPush(seats, n"seat_back_left");
      ArrayPush(seats, n"seat_back_right");
      for seat in seats {
        if ai.IsSeatReserved(seat) && !VehicleComponent.IsSlotOccupied(gi, vehicle.GetEntityID(), seat) {
          ai.ReleaseSeat(seat);
          done = done + " seat-" + NameToString(seat);
        };
      };
    };
    // 6. engine running and the car On while V drives (EVS keeps a car at Default otherwise)
    if isDriver {
      if !vehicle.IsEngineTurnedOn() {
        this.CSHCF_EngineOn();
        done = done + " engine-on";
      };
      ctrl = this.GetVehicleControllerPS();
      if IsDefined(ctrl) && vehicle.IsEngineTurnedOn() && Equals(ctrl.GetState(), vehicleEState.Default) {
        ctrl.SetState(vehicleEState.On);
        done = done + " state-on";
      };
    };
    // 7. tell the vehicle AI V is the driver (no NoDriver first: that is the event a car gets when its driver leaves)
    if isDriver && !autodriveOn {
      aiEvent = new AIEvent();
      aiEvent.name = n"DriverReady";
      vehicle.QueueEvent(aiEvent);
      done = done + " driver-ready";
    };
  };

  CSHCF_Log(gi, s"repair (\(reason), forced \(forced)):" + (StrLen(done) > 0 ? done : " nothing to fix") + " | before: " + before);
  return done;
}

// ------------------------------------------------------------------ autodrive watch

@addField(AutoDriveSystem)
private let m_csHcfStart: Float;

@addField(AutoDriveSystem)
private let m_csHcfUserOff: Bool;

@addField(AutoDriveSystem)
private let m_csHcfVanilla: Bool;

@addField(AutoDriveSystem)
private let m_csHcfGen: Int32;

@addField(AutoDriveSystem)
private let m_csHcfRetried: EntityID;

@if(ModuleExists("AutoDriveEnhanced"))
@addMethod(AutoDriveSystem)
private final func CSHCF_IsVanillaAI() -> Bool {
  return this.GetVanillaAIEnabled_ADE();
}

@if(!ModuleExists("AutoDriveEnhanced"))
@addMethod(AutoDriveSystem)
private final func CSHCF_IsVanillaAI() -> Bool {
  return true;
}

// V's own stop: K hold, accelerate / brake input, ADE's stop (all reach this request)
@wrapMethod(AutoDriveSystem)
private final func OnDisableAutoDriveRequest(request: ref<DisableAutoDriveRequest>) -> Void {
  this.m_csHcfUserOff = true;
  wrappedMethod(request);
}

@wrapMethod(AutoDriveSystem)
private final func OnAutodriveToggled(enabled: Bool, isDelamain: Bool) -> Void {
  let gi: GameInstance;
  let now: Float;
  let ran: Float;
  let player: ref<PlayerPuppet>;
  let vehicle: ref<VehicleObject>;
  let comp: ref<VehicleComponent>;
  let check: ref<CSHCFAutodriveOkCheck>;
  let aiName: String;
  wrappedMethod(enabled, isDelamain);
  if isDelamain {
    this.m_csHcfStart = 0.0;
    return;
  };
  gi = this.GetGameInstance();
  now = EngineTime.ToFloat(GameInstance.GetSimTime(gi));
  if enabled {
    this.m_csHcfStart = now;
    this.m_csHcfUserOff = false;
    this.m_csHcfVanilla = this.CSHCF_IsVanillaAI();
    this.m_csHcfGen += 1;
    check = new CSHCFAutodriveOkCheck();
    check.sys = this;
    check.gen = this.m_csHcfGen;
    GameInstance.GetDelaySystem(gi).DelayCallback(check, 8.0, false);
    return;
  };
  if this.m_csHcfStart <= 0.0 {
    return;
  };
  ran = now - this.m_csHcfStart;
  this.m_csHcfStart = 0.0;
  if this.m_csHcfUserOff || ran >= 6.0 {
    return;
  };
  player = GetPlayer(gi);
  if IsDefined(player) {
    vehicle = player.GetMountedVehicle();
  };
  if !IsDefined(vehicle) {
    return;
  };
  comp = vehicle.GetVehicleComponent();
  if !IsDefined(comp) {
    return;
  };
  aiName = this.m_csHcfVanilla ? "vanilla" : "modded";
  CSHCF_Log(gi, s"autodrive switched itself off after \(ran) s (\(aiName) AI, available now \(this.GetAutodriveAvailable())): " + comp.CSHCF_StateText());
  if this.m_csHcfVanilla && vehicle.IsPlayerDriver() && comp.CSHCF_IsSuspect() && this.m_csHcfRetried != vehicle.GetEntityID() {
    this.m_csHcfRetried = vehicle.GetEntityID();
    comp.CSHCF_Repair(true, "autodrive dropped");
    GameInstance.GetDelaySystem(gi).DelayScriptableSystemRequest(n"AutoDriveSystem", new EnableAutoDriveRequest(), 1.0, false);
    CSHCF_Log(gi, "hacked car: repaired, autodrive retried once in 1 s");
  };
}

@addMethod(AutoDriveSystem)
public final func CSHCF_OkCheck(gen: Int32) -> Void {
  let player: ref<PlayerPuppet>;
  let vehicle: ref<VehicleObject>;
  let ps: ref<VehicleComponentPS>;
  let none: EntityID;
  if gen != this.m_csHcfGen || this.m_csHcfStart <= 0.0 || !this.GetAutodriveEnabled() {
    return;
  };
  this.m_csHcfRetried = none;
  player = GetPlayer(this.GetGameInstance());
  if IsDefined(player) {
    vehicle = player.GetMountedVehicle();
  };
  if IsDefined(vehicle) {
    ps = vehicle.GetVehiclePS();
    if IsDefined(ps) && ps.m_csHcfTakenOver {
      ps.m_csHcfTakenOver = false;
      CSHCF_Log(this.GetGameInstance(), "autodrive runs fine in the hacked car (8 s): hacked flag cleared");
    };
  };
}

// ------------------------------------------------------------------ 1.1.2: refused autodrive start

@addField(AutoDriveSystem)
private let m_csHcfRefusedAt: Float;

@addMethod(AutoDriveSystem)
private final func CSHCF_RefusalText() -> String {
  let gi: GameInstance = this.GetGameInstance();
  let player: ref<PlayerPuppet> = GetPlayer(gi);
  let vehicle: ref<VehicleObject>;
  let comp: ref<VehicleComponent>;
  let bb: ref<IBlackboard>;
  let health: Float;
  let text: String;
  if !IsDefined(player) {
    return "no player";
  };
  vehicle = player.GetMountedVehicle();
  if !IsDefined(vehicle) {
    return "V is in no vehicle";
  };
  bb = player.GetPlayerStateMachineBlackboard();
  health = GameInstance.GetStatPoolsSystem(gi).GetStatPoolValue(Cast<StatsObjectID>(vehicle.GetEntityID()), gamedataStatPoolType.Health, true);
  text = s"driver=\(vehicle.IsPlayerDriver()) combat=\(bb.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Combat))"
    + s" seatState=\(bb.GetInt(GetAllBlackboardDefs().PlayerStateMachine.Vehicle)) health=\(health)"
    + s" healthMin=\(TDB.GetFloat(t"Vehicle.autodrive_settings.healthDeactivationThreshold"))"
    + s" raceLock=\(GameInstance.GetQuestsContentSystem(gi).IsTokensActivationBlockedBySource(n"sq024_race_active"))";
  comp = vehicle.GetVehicleComponent();
  if IsDefined(comp) {
    text = text + " | " + comp.CSHCF_StateText();
  };
  return text;
}

// K on a car the game will not autodrive: vanilla and ADE both return without a word unless the lane is wrong
@wrapMethod(AutoDriveSystem)
private final func OnEnableAutoDriveRequest(request: ref<EnableAutoDriveRequest>) -> Void {
  let lane: gameAutodriveLaneValidityResult;
  let available: Bool;
  let now: Float;
  let aiName: String;
  if request.isDelamain || this.GetAutodriveEnabled() {
    wrappedMethod(request);
    return;
  };
  lane = this.CheckCurrentLaneValidity();
  available = this.GetAutodriveAvailable();
  wrappedMethod(request);
  if this.GetAutodriveEnabled() {
    return;
  };
  now = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
  if this.m_csHcfRefusedAt > 0.0 && now - this.m_csHcfRefusedAt < 2.0 && now >= this.m_csHcfRefusedAt {
    return;
  };
  this.m_csHcfRefusedAt = now;
  aiName = this.CSHCF_IsVanillaAI() ? "vanilla" : "modded";
  CSHCF_Log(this.GetGameInstance(), s"autodrive did not start (\(aiName) AI): lane \(lane), available \(available) | " + this.CSHCF_RefusalText());
}

// ------------------------------------------------------------------ 1.1.3: engine stays on after the release

public class CSHCFStayOnCallback extends DelayCallback {
  public let comp: wref<VehicleComponent>;
  public let gen: Int32;
  public let ticks: Int32;
  public let caught: Int32;

  public func Call() -> Void {
    let comp: ref<VehicleComponent> = this.comp;
    if IsDefined(comp) {
      comp.CSHCF_StayOnTick(this.gen, this.ticks, this.caught);
    };
  }
}

// gen = m_csHcfOnGen at the release: a new Take Control (or a second release) ends this loop
@addMethod(VehicleComponent)
public final func CSHCF_StayOnTick(gen: Int32, ticks: Int32, caught: Int32) -> Void {
  let vehicle: ref<VehicleObject> = this.GetVehicle();
  let ps: ref<VehicleComponentPS> = this.GetPS();
  let ctrl: ref<vehicleControllerPS>;
  let next: ref<CSHCFStayOnCallback>;
  let player: ref<PlayerPuppet>;
  let engine: Bool;
  let on: Bool;
  if gen != this.m_csHcfOnGen || !IsDefined(vehicle) || !IsDefined(ps) || vehicle.IsVehicleRemoteControlled() || ps.GetIsDestroyed() {
    return;
  };
  // V got in: the engine is V's from here
  player = GetPlayer(vehicle.GetGame());
  if IsDefined(player) && player.GetMountedVehicle() == vehicle {
    return;
  };
  engine = vehicle.IsEngineTurnedOn();
  on = vehicle.IsVehicleTurnedOn();
  if !engine || !on {
    vehicle.TurnVehicleOn(true);
    this.CSHCF_EngineOn();
    // a running car V is not in sits at Default, like EVS keeps it: the game shuts an empty car at On down
    ctrl = this.GetVehicleControllerPS();
    if IsDefined(ctrl) && Equals(ctrl.GetState(), vehicleEState.On) {
      ctrl.SetState(vehicleEState.Default);
    };
    caught += 1;
    if caught == 1 || caught == 4 {
      CSHCF_Log(vehicle.GetGame(), s"after take control: car was off \(Cast<Float>(ticks) * 0.5 + 0.1) s after the release (engine \(engine), on \(on)) -> switched on (\(caught) times)");
    };
  };
  if ticks < 8 {
    next = new CSHCFStayOnCallback();
    next.comp = this;
    next.gen = gen;
    next.ticks = ticks + 1;
    next.caught = caught;
    GameInstance.GetDelaySystem(vehicle.GetGame()).DelayCallback(next, 0.5, false);
  } else {
    if caught > 0 {
      CSHCF_Log(vehicle.GetGame(), s"after take control: 4 s watched, switched on \(caught) times, now engine \(vehicle.IsEngineTurnedOn()), on \(vehicle.IsVehicleTurnedOn())");
    };
  };
}
