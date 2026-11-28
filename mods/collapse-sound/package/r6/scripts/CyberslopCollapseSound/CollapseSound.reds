// Cyberslop Collapse Sound 1.2.2, patch 2.5
// 1.2.2: Mod Settings "Debug log" (default off): FTLog lines in the CET gamelog.log for every collapse SFX start.
// System Collapse plays the Short Circuit zap instead of its own sound (Mod Settings switch, default on).
// 1.1.0: optional Short Circuit electrocution look on the target (Mod Settings switch, default off).
// 1.2.0: optional sparks for the whole collapse (Mod Settings switch, default off): every 1 s the effect is
// started again if it is not running (startOnlyIfNotStarted), until the System Collapse effect is gone
// (ObjectHasStatusEffect on the applied record), then the loop is broken. Safety cap 60 ticks.
// 1.2.1: PlaySFXEffector wrap removed: the only PlaySFXEffectors with quickhack_system_reset are the android
// branches of DeviceTrapHit / MagnetDeviceHit (misc.tweak, device traps), not System Collapse, so 1.0.0-1.2.0
// changed a trap sound. Effects without SFX skip the wrap after one GetSFXCount call.
// Vanilla: BaseStatusEffect.SystemCollapse / BossSystemCollapse carry SFX "quickhack_system_reset",
// played by GameObject.StartStatusEffectSFX when the effect lands. Swapped here for the
// Short Circuit events of BaseOverload: "quickhack_shortcircuit" on humans, "quickhack_shortcircuit_mech"
// on everything else (same prereqs as Short Circuit: NPCIsHuman / NPCIsNotHuman).
// Removal stays vanilla: StopStatusEffectSFX stops "quickhack_system_reset" (harmless when it never
// played, and it ends a vanilla sound started while the switch was off). The zap is a one-shot and is
// never stopped, so a real Short Circuit on the same NPC is not cut off.
// Electrocution look = what BaseOverload does: its PlayVFXEffector starts "status_electrocuted" when the
// 0.1 s Overload effect lands and breaks the loop when it ends (ActionOff -> BreakEffectLoopEvent).
// Here: started on a new System Collapse application, loop broken 0.1 s later by a DelayCallback.
// The collapse's own visual (hacks_system_collapse) stays.
module CyberslopCollapseSound

public class CSCollapseSoundSettings extends ScriptableSystem {

  @runtimeProperty("ModSettings.mod", "Cyberslop Collapse Sound")
  @runtimeProperty("ModSettings.displayName", "Short Circuit sound for System Collapse")
  @runtimeProperty("ModSettings.description", "On: System Collapse plays the Short Circuit zap (mech zap on drones, mechs and androids). Off: vanilla System Collapse sound.")
  public let enabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Cyberslop Collapse Sound")
  @runtimeProperty("ModSettings.displayName", "Short Circuit electric effect for System Collapse")
  @runtimeProperty("ModSettings.description", "On: the target gets the same electrocution sparks as Short Circuit when System Collapse lands. The System Collapse effect itself stays.")
  public let electrify: Bool = false;

  @runtimeProperty("ModSettings.mod", "Cyberslop Collapse Sound")
  @runtimeProperty("ModSettings.displayName", "Sparks for the whole collapse")
  @runtimeProperty("ModSettings.description", "Needs the electric effect switch. On: the sparks keep going until System Collapse wears off (about 9 s). Off: one short burst like Short Circuit.")
  public let electrifyLong: Bool = false;

  @runtimeProperty("ModSettings.mod", "Cyberslop Collapse Sound")
  @runtimeProperty("ModSettings.displayName", "Debug log")
  @runtimeProperty("ModSettings.description", "On: every System Collapse sound swap and spark tick is written to the CET gamelog.log. For testing.")
  public let debugLog: Bool = false;

  private func OnAttach() -> Void {
    CSCollapseSoundSettings.Register(this);
  }

  private func OnDetach() -> Void {
    CSCollapseSoundSettings.Unregister(this);
  }

  public static func Get(gi: GameInstance) -> ref<CSCollapseSoundSettings> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(NameOf<CSCollapseSoundSettings>()) as CSCollapseSoundSettings;
  }

  public static func IsOn(gi: GameInstance) -> Bool {
    let s: ref<CSCollapseSoundSettings> = CSCollapseSoundSettings.Get(gi);
    if !IsDefined(s) {
      return true;
    }
    return s.enabled;
  }

  public static func ElectrifyOn(gi: GameInstance) -> Bool {
    let s: ref<CSCollapseSoundSettings> = CSCollapseSoundSettings.Get(gi);
    if !IsDefined(s) {
      return false;
    }
    return s.electrify;
  }

  public static func ElectrifyLongOn(gi: GameInstance) -> Bool {
    let s: ref<CSCollapseSoundSettings> = CSCollapseSoundSettings.Get(gi);
    if !IsDefined(s) {
      return false;
    }
    return s.electrifyLong;
  }

  public static func Log(gi: GameInstance, msg: String) -> Void {
    let s: ref<CSCollapseSoundSettings> = CSCollapseSoundSettings.Get(gi);
    if IsDefined(s) && s.debugLog {
      FTLog("[CollapseSound] " + msg);
    }
  }

  public static func Replacement(obj: ref<GameObject>) -> CName {
    let puppet: ref<ScriptedPuppet> = obj as ScriptedPuppet;
    if IsDefined(puppet) && !puppet.IsHuman() {
      return n"quickhack_shortcircuit_mech";
    }
    return n"quickhack_shortcircuit";
  }

  // short: same start / stop as BaseOverload's PlayVFXEffector (0.1 s effect); long: kept up while the collapse lasts
  public static func Electrify(obj: ref<GameObject>, effectID: TweakDBID) -> Void {
    let cb: ref<CSCollapseElectrifyEnd> = new CSCollapseElectrifyEnd();
    cb.target = obj;
    cb.effectID = effectID;
    cb.long = CSCollapseSoundSettings.ElectrifyLongOn(obj.GetGame());
    CSCollapseSoundSettings.Log(obj.GetGame(), "sparks start, long " + ToString(cb.long));
    GameObjectEffectHelper.StartEffectEvent(obj, n"status_electrocuted");
    GameInstance.GetDelaySystem(obj.GetGame()).DelayCallback(cb, cb.long ? 1.0 : 0.1, true);
  }

  @if(ModuleExists("ModSettingsModule"))
  private static func Register(obj: ref<IScriptable>) -> Void {
    ModSettings.RegisterListenerToClass(obj);
  }

  @if(!ModuleExists("ModSettingsModule"))
  private static func Register(obj: ref<IScriptable>) -> Void {}

  @if(ModuleExists("ModSettingsModule"))
  private static func Unregister(obj: ref<IScriptable>) -> Void {
    ModSettings.UnregisterListenerToClass(obj);
  }

  @if(!ModuleExists("ModSettingsModule"))
  private static func Unregister(obj: ref<IScriptable>) -> Void {}
}

public class CSCollapseElectrifyEnd extends DelayCallback {

  public let target: wref<GameObject>;
  public let effectID: TweakDBID;
  public let long: Bool;
  public let ticks: Int32;

  public func Call() -> Void {
    let next: ref<CSCollapseElectrifyEnd>;
    if !IsDefined(this.target) {
      return;
    }
    if this.long && this.ticks < 60 && StatusEffectSystem.ObjectHasStatusEffect(this.target, this.effectID) {
      GameObjectEffectHelper.StartEffectEvent(this.target, n"status_electrocuted", false, null, true);
      next = new CSCollapseElectrifyEnd();
      next.target = this.target;
      next.effectID = this.effectID;
      next.long = true;
      next.ticks = this.ticks + 1;
      GameInstance.GetDelaySystem(this.target.GetGame()).DelayCallback(next, 1.0, true);
      return;
    }
    CSCollapseSoundSettings.Log(this.target.GetGame(), "sparks end after " + IntToString(this.ticks) + " ticks");
    GameObjectEffectHelper.BreakEffectLoopEvent(this.target, n"status_electrocuted");
  }
}

// Status effect SFX (SystemCollapse, BossSystemCollapse and any mod effect using the same event)
@wrapMethod(GameObject)
protected func StartStatusEffectSFX(evt: ref<ApplyStatusEffectEvent>) -> Void {
  let sfxList: array<wref<StatusEffectFX_Record>>;
  let i: Int32;
  let hit: Bool = false;
  if !IsDefined(evt) || !IsDefined(evt.staticData) || evt.staticData.GetSFXCount() == 0 {
    wrappedMethod(evt);
    return;
  }
  evt.staticData.SFX(sfxList);
  while i < ArraySize(sfxList) && !hit {
    if IsDefined(sfxList[i]) && Equals(sfxList[i].Name(), n"quickhack_system_reset") {
      hit = true;
    }
    i += 1;
  }
  if !hit {
    wrappedMethod(evt);
    return;
  }
  CSCollapseSoundSettings.Log(this.GetGame(), "collapse SFX on " + NameToString(this.GetClassName()) + " " + TDBID.ToStringDEBUG(evt.staticData.GetID()) + ", new " + ToString(evt.isNewApplication) + ", swap " + ToString(CSCollapseSoundSettings.IsOn(this.GetGame())) + " -> " + NameToString(CSCollapseSoundSettings.Replacement(this)) + ", sparks " + ToString(CSCollapseSoundSettings.ElectrifyOn(this.GetGame())));
  if evt.isNewApplication && CSCollapseSoundSettings.ElectrifyOn(this.GetGame()) {
    CSCollapseSoundSettings.Electrify(this, evt.staticData.GetID());
  }
  if !CSCollapseSoundSettings.IsOn(this.GetGame()) {
    wrappedMethod(evt);
    return;
  }
  // same loop as vanilla, with the collapse sound swapped
  i = 0;
  while i < ArraySize(sfxList) {
    if IsDefined(sfxList[i]) && (evt.isNewApplication || sfxList[i].ShouldReapply()) {
      if Equals(sfxList[i].Name(), n"quickhack_system_reset") {
        GameObject.PlaySound(this, CSCollapseSoundSettings.Replacement(this));
      } else {
        GameObject.PlaySound(this, sfxList[i].Name());
      }
    }
    i += 1;
  }
}

