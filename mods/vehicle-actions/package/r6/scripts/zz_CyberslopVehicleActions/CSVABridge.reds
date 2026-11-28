// Cyberslop Vehicle Actions field bridge 1.1.0 (2026-11-26; 1.0.0 2026-11-21), for the CET window 1.6.0+
// CET 1.38.1 on patch 2.5 reads every script field as nil (vanilla and mod-added alike; methods work, proven
// with evscheck.log 2026-11-21). This gives the CET window methods to read and write the few fields it
// needs, and runs Enhanced Vehicle System's multi-tap actions (their events carry a tapCount field).
// The EVS part compiles only when EVS is installed; without it the window uses vanilla calls.
module CyberslopVehicleActions.Bridge

@if(ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
import Hgyi56.Enhanced_Vehicle_System.*

// ---------------------------------------------------------------- vanilla (always there)
@addMethod(VehicleComponent)
public func CSVA_Bridge() -> Int32 {
  return 1;
}

@addMethod(VehicleComponent)
public func CSVA_UseAuxiliary() -> Bool {
  return this.m_useAuxiliary;
}

@addMethod(VehicleComponent)
public func CSVA_HasSpoiler() -> Bool {
  return this.m_hasSpoiler;
}

// door / window / trunk / hood requests, queued like vanilla VehicleComponent does
@addMethod(VehicleComponentPS)
public func CSVA_QueueDoor(slot: CName, open: Bool) -> Void {
  let ps: ref<GamePersistencySystem> = GameInstance.GetPersistencySystem(this.GetGameInstance());
  if open {
    let req: ref<VehicleDoorOpen> = new VehicleDoorOpen();
    req.slotID = slot;
    ps.QueuePSEvent(this.GetID(), this.GetClassName(), req);
  } else {
    let req: ref<VehicleDoorClose> = new VehicleDoorClose();
    req.slotID = slot;
    req.forceScene = false;
    ps.QueuePSEvent(this.GetID(), this.GetClassName(), req);
  }
}

@addMethod(VehicleComponentPS)
public func CSVA_QueueWindow(slot: CName, open: Bool) -> Void {
  let ps: ref<GamePersistencySystem> = GameInstance.GetPersistencySystem(this.GetGameInstance());
  if open {
    let req: ref<VehicleWindowOpen> = new VehicleWindowOpen();
    req.slotID = slot;
    ps.QueuePSEvent(this.GetID(), this.GetClassName(), req);
  } else {
    let req: ref<VehicleWindowClose> = new VehicleWindowClose();
    req.slotID = slot;
    ps.QueuePSEvent(this.GetID(), this.GetClassName(), req);
  }
}

// door: EVehicleDoor as Int32 (0 seat_front_left ... trunk, hood); sets the interaction back to Available
@addMethod(VehicleComponentPS)
public func CSVA_EnableDoorInteraction(door: Int32) -> Void {
  let req: ref<VehicleDoorInteractionStateChange> = new VehicleDoorInteractionStateChange();
  req.door = IntEnum<EVehicleDoor>(door);
  req.newState = VehicleDoorInteractionState.Available;
  req.source = "CyberslopVehicleActions";
  GameInstance.GetPersistencySystem(this.GetGameInstance()).QueuePSEvent(this.GetID(), this.GetClassName(), req);
}

// the exit / entry event the CET window observes (auto engine and power off)
@addMethod(VehicleStartedMountingEvent)
public func CSVA_IsMounting() -> Bool {
  return this.isMounting;
}

@addMethod(VehicleStartedMountingEvent)
public func CSVA_Character() -> wref<GameObject> {
  return this.character;
}

@addMethod(VehicleStartedMountingEvent)
public func CSVA_Slot() -> CName {
  return this.slotID;
}

// 1.1.0: dismiss one of V's own vehicles. It pulls away driverless into traffic (same calls as a summoned car
// leaving, as in Vehicle Summon Tweaks - Dismiss) and goes back to the garage after `delay` seconds.
// 0 = done, 1 = not V's vehicle, 2 = V sits in it.
public class CSVADismissCallback extends DelayCallback {
  public let vehicleSystem: wref<VehicleSystem>;
  public let vehicleId: GarageVehicleID;

  public func Call() -> Void {
    if IsDefined(this.vehicleSystem) {
      this.vehicleSystem.DespawnPlayerVehicle(this.vehicleId);
    }
  }
}

@addMethod(VehicleObject)
public func CSVA_Dismiss(delay: Float) -> Int32 {
  let game: GameInstance = this.GetGame();
  if !this.IsPlayerVehicle() {
    return 1;
  }
  let mounted: wref<VehicleObject>;
  if VehicleComponent.GetVehicle(game, GetPlayer(game), mounted) && IsDefined(mounted)
      && Equals(mounted.GetEntityID(), this.GetEntityID()) {
    return 2;
  }
  let ready: ref<AIEvent> = new AIEvent();
  ready.name = n"DriverReady";
  this.QueueEvent(ready);
  let drive: ref<AIVehicleJoinTrafficCommand> = new AIVehicleJoinTrafficCommand();
  drive.needDriver = false;
  drive.useKinematic = true;
  let ai: ref<AIVehicleAgent> = this.GetAIComponent();
  if IsDefined(ai) {
    ai.SendCommand(drive);
  }
  let cb: ref<CSVADismissCallback> = new CSVADismissCallback();
  cb.vehicleSystem = GameInstance.GetVehicleSystem(game);
  cb.vehicleId.recordID = this.GetRecordID();
  GameInstance.GetDelaySystem(game).DelayCallback(cb, MaxF(delay, 0.0));
  return 0;
}

// ---------------------------------------------------------------- EVS
@if(ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(VehicleComponent)
public func CSVA_HasEVS() -> Bool {
  return true;
}

@if(!ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(VehicleComponent)
public func CSVA_HasEVS() -> Bool {
  return false;
}

@if(ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(VehicleComponentPS)
public func CSVA_GetBool(name: CName) -> Bool {
  switch name {
    case n"m_hgyi56_EVS_powerState": return this.m_hgyi56_EVS_powerState;
    case n"m_hgyi56_EVS_engineState": return this.m_hgyi56_EVS_engineState;
    case n"m_hgyi56_EVS_temporaryHeadlightsShutOff": return this.m_hgyi56_EVS_temporaryHeadlightsShutOff;
    case n"m_hgyi56_EVS_roofLightState": return this.m_hgyi56_EVS_roofLightState;
    case n"m_hgyi56_EVS_interiorLightsState": return this.m_hgyi56_EVS_interiorLightsState;
    case n"m_hgyi56_EVS_auxiliaryState": return this.m_hgyi56_EVS_auxiliaryState;
    case n"m_hgyi56_EVS_hasCrystalDome": return this.m_hgyi56_EVS_hasCrystalDome;
    case n"m_hgyi56_EVS_isPoliceVehicle": return this.m_hgyi56_EVS_isPoliceVehicle;
    case n"m_hgyi56_EVS_playerIsMounted": return this.m_hgyi56_EVS_playerIsMounted;
    case n"m_hgyi56_EVS_spoilerState": return this.m_hgyi56_EVS_spoilerState;
  }
  return false;
}

@if(ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(VehicleComponentPS)
public func CSVA_GetInt(name: CName) -> Int32 {
  switch name {
    case n"m_hgyi56_EVS_currentHeadlightsState": return EnumInt(this.m_hgyi56_EVS_currentHeadlightsState);
    case n"m_hgyi56_EVS_threeStatesSiren": return this.m_hgyi56_EVS_threeStatesSiren;
  }
  return -1;
}

// 0 = off, 1 = low, 2 = high (vehicleELightMode)
@if(ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(VehicleComponentPS)
public func CSVA_SetHeadlightsState(mode: Int32) -> Void {
  this.m_hgyi56_EVS_currentHeadlightsState = IntEnum<vehicleELightMode>(mode);
}

@if(ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(VehicleComponent)
public func CSVA_IsDismounting() -> Bool {
  return this.m_hgyi56_EVS_playerIsDismounting;
}

// EVS multi-tap handlers act only when the event's tapCount matches their step field: set both, call the handler
@if(ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(PlayerPuppet)
public func CSVA_CustomLightsTap(tap: Int32) -> Bool {
  let evt: ref<MultiTapLightsToggleEvent> = new MultiTapLightsToggleEvent();
  evt.tapCount = tap;
  this.m_hgyi56_EVS_toggleCustomLightsStep = tap;
  this.hgyi56_EVS_OnMultiTapLightsToggleEvent(evt);
  return true;
}

@if(ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(VehicleComponent)
public func CSVA_PoliceTap(tap: Int32) -> Bool {
  let evt: ref<MultiTapPoliceLightsEvent> = new MultiTapPoliceLightsEvent();
  evt.tapCount = tap;
  this.m_hgyi56_EVS_cyclePoliceSirenStep = tap;
  this.hgyi56_EVS_OnMultiTapPoliceLightsEvent(evt);
  return true;
}

@if(ModuleExists("Hgyi56.Enhanced_Vehicle_System"))
@addMethod(VehicleComponent)
public func CSVA_CrystalCoatTap(tap: Int32) -> Bool {
  let evt: ref<MultiTapCrystalCoatEvent> = new MultiTapCrystalCoatEvent();
  evt.tapCount = tap;
  this.m_hgyi56_EVS_cycleCrystalCoatStep = tap;
  this.hgyi56_EVS_OnMultiTapCrystalCoatEvent(evt);
  return true;
}
