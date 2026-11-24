// Cyberslop Scanner Pins 1.1.1, built on Cyberpunk 2077 2.5 + Limited HUD 2.23.2
// (1.1.0 = 2.31 build; 1.1.1 needs Limited HUD 2.23+, whose DetermineCurrentVisibility returns Bool)
//
// World map pins (vendors, ripperdocs, fixers, fast travel, metro, drop points, other points of
// interest, world encounters) get their 3D world marker out to the chosen range (default 200 m;
// vanilla spawns them at 50 to 100 m). Past "Always visible within" (default 50 m) these markers
// show only while the scanner is up. Tracked pins are never hidden by this mod.
//
// How:
// - MappinUIProfile.Create (the 3-argument version every pin container calls) is wrapped. When the
//   world container asks for one of the vanilla POI combinations (ShortRange / WorldEncounter /
//   MediumRange spawn with a WorldMappinUIProfile.* runtime profile, see
//   WorldMappinsContainerController.CreateMappinUIProfile), the spawn profile is swapped for a
//   longer one and the runtime profile for an identical Cyberslop copy (r6\tweaks). Other mods'
//   container wraps run first and keep working: a pin they give no profile or their own profile is
//   never touched. The minimap and the world map use MinimapMappinUIProfile / MapMappinUIProfile
//   and are not touched either.
// - QuestMappinController (the controller of the world pin widget) hides pins with a Cyberslop
//   runtime profile past the near range while the scanner is off. It only ever hides; whether a pin
//   shows at all is still up to the game (and Limited HUD, whose DetermineCurrentVisibility is
//   wrapped the same way when it is installed). The folder name sorts after LHUD on purpose.
// - Scanner on / off: UI_Scanner.UIVisible blackboard listener, refresh event to the pin widgets.

public class CyberslopScanPinsRefreshEvent extends Event {}

public class CyberslopScanPinsSystem extends ScriptableSystem {

  @runtimeProperty("ModSettings.mod", "Cyberslop Scanner Pins")
  @runtimeProperty("ModSettings.displayName", "Enabled")
  @runtimeProperty("ModSettings.description", "Map pins get a world marker out to the scanner range. Applies to markers created after the change (move away and back, or reload).")
  public let enabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Cyberslop Scanner Pins")
  @runtimeProperty("ModSettings.displayName", "Scanner range (m)")
  @runtimeProperty("ModSettings.description", "How far away vendor, fixer, fast travel, drop point and other map pins show in the world while scanning. Vanilla: 50 m.")
  @runtimeProperty("ModSettings.step", "50")
  @runtimeProperty("ModSettings.min", "100")
  @runtimeProperty("ModSettings.max", "300")
  public let rangeM: Int32 = 200;

  @runtimeProperty("ModSettings.mod", "Cyberslop Scanner Pins")
  @runtimeProperty("ModSettings.displayName", "Always visible within (m)")
  @runtimeProperty("ModSettings.description", "Closer than this the marker follows the game's normal rules (and Limited HUD's). Farther away it shows only while scanning. 0 = scanner only at any distance.")
  @runtimeProperty("ModSettings.step", "10")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "100")
  public let nearM: Int32 = 50;

  private let m_scannerCallback: ref<CallbackHandle>;

  private func OnAttach() -> Void {
    this.RegisterSettings();
    let bb: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_Scanner);
    if IsDefined(bb) {
      this.m_scannerCallback = bb.RegisterListenerBool(GetAllBlackboardDefs().UI_Scanner.UIVisible, this, n"OnScannerVisible");
    };
  }

  private func OnDetach() -> Void {
    let bb: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_Scanner);
    if IsDefined(bb) && IsDefined(this.m_scannerCallback) {
      bb.UnregisterListenerBool(GetAllBlackboardDefs().UI_Scanner.UIVisible, this.m_scannerCallback);
    };
    this.m_scannerCallback = null;
    this.UnregisterSettings();
  }

  @if(ModuleExists("ModSettingsModule"))
  private func RegisterSettings() -> Void {
    ModSettings.RegisterListenerToClass(this);
  }

  @if(!ModuleExists("ModSettingsModule"))
  private func RegisterSettings() -> Void {}

  @if(ModuleExists("ModSettingsModule"))
  private func UnregisterSettings() -> Void {
    ModSettings.UnregisterListenerToClass(this);
  }

  @if(!ModuleExists("ModSettingsModule"))
  private func UnregisterSettings() -> Void {}

  protected cb func OnScannerVisible(value: Bool) -> Bool {
    GameInstance.GetUISystem(this.GetGameInstance()).QueueEvent(new CyberslopScanPinsRefreshEvent());
  }

  public final func IsScannerOn() -> Bool {
    let bb: ref<IBlackboard> = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_Scanner);
    return IsDefined(bb) && bb.GetBool(GetAllBlackboardDefs().UI_Scanner.UIVisible);
  }

  public final func NearRange() -> Float {
    return Cast<Float>(Max(this.nearM, 0));
  }

  // 1.1.0: API for the Cyberslop HUD Control CET window. Values live for the session (the CET
  // window re-applies its saved values after each load); Mod Settings still sets the defaults.
  public final func CS_GetEnabled() -> Bool { return this.enabled; }
  public final func CS_GetRange() -> Int32 { return this.rangeM; }
  public final func CS_GetNear() -> Int32 { return this.nearM; }

  public final func CS_SetEnabled(on: Bool) -> Void {
    this.enabled = on;
    this.CS_Refresh();
  }

  public final func CS_SetRange(m: Int32) -> Void {
    this.rangeM = Clamp(m, 100, 300);
    this.CS_Refresh();
  }

  public final func CS_SetNear(m: Int32) -> Void {
    this.nearM = Clamp(m, 0, 100);
    this.CS_Refresh();
  }

  // Re-gate the world pins that already exist (near range applies at once; range and on / off apply
  // to markers created after the change).
  public final func CS_Refresh() -> Void {
    GameInstance.GetUISystem(this.GetGameInstance()).QueueEvent(new CyberslopScanPinsRefreshEvent());
  }

  public final func SpawnProfile() -> TweakDBID {
    let r: Int32 = Clamp(this.rangeM, 100, 300);
    r = ((r + 25) / 50) * 50;
    return TDBID.Create("MappinUISpawnProfile.CyberslopScan" + IntToString(r));
  }

  public final static func Get() -> ref<CyberslopScanPinsSystem> {
    return GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"CyberslopScanPinsSystem") as CyberslopScanPinsSystem;
  }
}

// Vanilla (spawn, runtime) combinations of the world pin container that this mod extends, and the
// Cyberslop runtime copy that replaces each. TDBID.None() = leave the pin alone.
public func CyberslopScanPins_RuntimeFor(spawnProfile: TweakDBID, runtimeProfile: TweakDBID) -> TweakDBID {
  if Equals(spawnProfile, t"MappinUISpawnProfile.ShortRange") {
    if Equals(runtimeProfile, t"WorldMappinUIProfile.ServicePoint") {
      return t"WorldMappinUIProfile.CyberslopScanServicePoint";
    };
    if Equals(runtimeProfile, t"WorldMappinUIProfile.Fixer") {
      return t"WorldMappinUIProfile.CyberslopScanFixer";
    };
    if Equals(runtimeProfile, t"WorldMappinUIProfile.FastTravel") {
      return t"WorldMappinUIProfile.CyberslopScanFastTravel";
    };
    if Equals(runtimeProfile, t"WorldMappinUIProfile.DropPoint") {
      return t"WorldMappinUIProfile.CyberslopScanDropPoint";
    };
    if Equals(runtimeProfile, t"WorldMappinUIProfile.Default") {
      return t"WorldMappinUIProfile.CyberslopScanDefault";
    };
    return TDBID.None();
  };
  if Equals(spawnProfile, t"MappinUISpawnProfile.WorldEncounter") || Equals(spawnProfile, t"MappinUISpawnProfile.MediumRange") {
    if Equals(runtimeProfile, t"WorldMappinUIProfile.Default") {
      return t"WorldMappinUIProfile.CyberslopScanDefault";
    };
  };
  return TDBID.None();
}

public func CyberslopScanPins_IsOurRuntime(id: TweakDBID) -> Bool {
  return Equals(id, t"WorldMappinUIProfile.CyberslopScanServicePoint")
    || Equals(id, t"WorldMappinUIProfile.CyberslopScanFixer")
    || Equals(id, t"WorldMappinUIProfile.CyberslopScanFastTravel")
    || Equals(id, t"WorldMappinUIProfile.CyberslopScanDropPoint")
    || Equals(id, t"WorldMappinUIProfile.CyberslopScanDefault");
}

@wrapMethod(MappinUIProfile)
public final static func Create(_widgetResource: ResRef, spawnProfile: TweakDBID, runtimeProfile: TweakDBID) -> MappinUIProfile {
  let ours: TweakDBID = CyberslopScanPins_RuntimeFor(spawnProfile, runtimeProfile);
  if TDBID.IsValid(ours) {
    let sys: ref<CyberslopScanPinsSystem> = CyberslopScanPinsSystem.Get();
    if IsDefined(sys) && sys.enabled {
      return wrappedMethod(_widgetResource, sys.SpawnProfile(), ours);
    };
  };
  return wrappedMethod(_widgetResource, spawnProfile, runtimeProfile);
}

// Hide one of our pins when it is past the near range, not tracked and the scanner is off.
@addMethod(QuestMappinController)
private final func CyberslopScanPins_Gate() -> Void {
  let profile: ref<MappinUIRuntimeProfile_Record> = this.GetProfile();
  if !IsDefined(profile) || !CyberslopScanPins_IsOurRuntime(profile.GetID()) {
    return;
  };
  if this.IsTracked() {
    return;
  };
  let sys: ref<CyberslopScanPinsSystem> = CyberslopScanPinsSystem.Get();
  if !IsDefined(sys) {
    return;
  };
  if this.GetDistanceToPlayer() <= sys.NearRange() {
    return;
  };
  if sys.IsScannerOn() {
    return;
  };
  this.SetRootVisible(false);
}

@wrapMethod(QuestMappinController)
private func UpdateVisibility() -> Void {
  wrappedMethod();
  this.CyberslopScanPins_Gate();
}

// Limited HUD re-evaluates its world markers through this method (added by LHUD) without going
// through UpdateVisibility, e.g. when zoom or combat state changes.
// 1.1.1: since Limited HUD 2.23 (patch 2.5) the method returns true when LHUD has set the marker's
// visibility itself; LHUD's UpdateVisibility wrap runs the vanilla visibility code only on false.
// 1.1.0 wrapped it as Void, so the result was lost, always read false, and vanilla re-showed every
// marker LHUD had just hidden (quest / loot / POI markers popping in and out on their own).
@if(ModuleExists("LimitedHudCommon"))
@wrapMethod(QuestMappinController)
public func DetermineCurrentVisibility() -> Bool {
  let handled: Bool = wrappedMethod();
  this.CyberslopScanPins_Gate();
  return handled;
}

@addMethod(QuestMappinController)
protected cb func OnCyberslopScanPinsRefresh(evt: ref<CyberslopScanPinsRefreshEvent>) -> Bool {
  if !IsDefined(this.m_mappin) {
    return false;
  };
  let profile: ref<MappinUIRuntimeProfile_Record> = this.GetProfile();
  if !IsDefined(profile) || !CyberslopScanPins_IsOurRuntime(profile.GetID()) {
    return false;
  };
  this.UpdateVisibility();
  this.UpdateTrackedState();
}
