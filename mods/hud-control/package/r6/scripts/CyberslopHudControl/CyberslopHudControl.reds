// Cyberslop HUD Control 1.1.2, built on Cyberpunk 2077 2.31
// 1.1.2 (2026-11-23; 1.1.1 = CET window only): the dpad's phone / car / radio icons show at the chosen opacity, not its square (LHUD fades
//   their slots, children of the dpad root, to the same value: 25 % showed as ~6 %).
//
// Redscript side of the "Cyberslop HUD Control" CET window.
//
// 1. Hide: hard-hides HUD elements that Limited HUD manages (minimap, quest tracker, health bar,
//    stamina bar, weapon roster, hotkeys / phone, input hints, crouch indicator), on top of whatever
//    LHUD decides. The element's root widget gets SetVisible(false). Root visibility belongs to vanilla
//    (and LHUD's health bar module) through inkHUDGameController.ShowRequest / HideRequest / the fold
//    animation callbacks; those are wrapped, so while an element is hidden a show request is undone at
//    once, and on unhide the root goes back to what the game last asked for. A UI event re-sent every
//    0.5 s while anything is active covers direct SetVisible calls.
// 2. Opacity (1.1.0): per element 0-100 %, or -1 = Limited HUD's own Opacity setting. LHUD fades each
//    module's root to its config's Opacity (health bar and weapon roster: sets it directly), so the
//    override is written into that config object; LHUD's own fades then land on the chosen value and
//    nothing fights. A root that is currently shown is set at once. The nested hotkey controllers
//    inside the dpad widget (phone, radio, car, car customisation) are set to 100 % while the hotkeys
//    have an override, so the value does not multiply. Quest Compass (id 8): its root opacity, which
//    neither QC nor LHUD touch.
// 3. Compass probe (1.1.0): tells the CET window whether Quest Compass's widget exists on the HUD.
//
// Element ids (also used by the CET window):
// 0 minimap, 1 quest tracker, 2 health bar, 3 stamina bar, 4 weapon roster, 5 hotkeys (dpad / phone),
// 6 input hints, 7 crouch indicator, 8 Quest Compass (opacity only)
// No hard dependency: the LHUD parts compile only with Limited HUD installed.

@if(ModuleExists("LimitedHudConfig"))
import LimitedHudConfig.*

public class CyberslopHudControlEvent extends Event {}

public class CyberslopHudControlTick extends DelayCallback {
  public let sys: wref<CyberslopHudControl>;
  public func Call() -> Void {
    if IsDefined(this.sys) {
      this.sys.Tick();
    };
  }
}

public class CyberslopHudControl extends ScriptableSystem {
  private let m_hidden: array<Bool>;
  private let m_opacity: array<Float>;
  private let m_polling: Bool;
  private let m_cetApplied: Bool;
  private let m_compassWidgetSeen: Bool;

  private func OnAttach() -> Void {
    ArrayResize(this.m_hidden, 8);
    ArrayResize(this.m_opacity, 9);
    let i: Int32 = 0;
    while i < 9 {
      this.m_opacity[i] = -1.0;
      i += 1;
    };
    this.m_polling = false;
    this.m_cetApplied = false;
    this.m_compassWidgetSeen = false;
  }

  public final static func Get() -> ref<CyberslopHudControl> {
    return GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"CyberslopHudControl") as CyberslopHudControl;
  }

  public final func Count() -> Int32 {
    return ArraySize(this.m_hidden);
  }

  // ---- hide ----

  public final func IsHidden(id: Int32) -> Bool {
    if id < 0 || id >= ArraySize(this.m_hidden) {
      return false;
    };
    return this.m_hidden[id];
  }

  public final func SetHidden(id: Int32, hidden: Bool) -> Void {
    if id < 0 || id >= ArraySize(this.m_hidden) {
      return;
    };
    this.m_hidden[id] = hidden;
    this.Broadcast();
    this.StartPolling();
  }

  // ---- opacity ----

  // -1 = no override (Limited HUD's own setting).
  public final func GetOpacity(id: Int32) -> Float {
    if id < 0 || id >= ArraySize(this.m_opacity) {
      return -1.0;
    };
    return this.m_opacity[id];
  }

  public final func SetOpacity(id: Int32, value: Float) -> Void {
    if id < 0 || id >= ArraySize(this.m_opacity) {
      return;
    };
    this.m_opacity[id] = value < 0.0 ? -1.0 : ClampF(value, 0.0, 1.0);
    this.Broadcast();
    this.StartPolling();
  }

  public final func SetAllOpacity(value: Float) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(this.m_opacity) {
      this.m_opacity[i] = value < 0.0 ? -1.0 : ClampF(value, 0.0, 1.0);
      i += 1;
    };
    this.Broadcast();
    this.StartPolling();
  }

  // Limited HUD's own opacity for an element (Mod Settings), for the window to show when no override.
  @if(ModuleExists("LimitedHudConfig"))
  public final func LhudOpacity(id: Int32) -> Float {
    switch id {
      case 0: let c0: ref<MinimapModuleConfig> = new MinimapModuleConfig(); return c0.IsEnabled ? c0.Opacity : 1.0;
      case 1: let c1: ref<QuestTrackerModuleConfig> = new QuestTrackerModuleConfig(); return c1.IsEnabled ? c1.Opacity : 1.0;
      case 2: let c2: ref<PlayerHealthbarModuleConfig> = new PlayerHealthbarModuleConfig(); return c2.IsEnabled ? c2.Opacity : 1.0;
      case 3: let c3: ref<PlayerStaminabarModuleConfig> = new PlayerStaminabarModuleConfig(); return c3.IsEnabled ? c3.Opacity : 1.0;
      case 4: let c4: ref<WeaponRosterModuleConfig> = new WeaponRosterModuleConfig(); return c4.IsEnabled ? c4.Opacity : 1.0;
      case 5: let c5: ref<ActionButtonsModuleConfig> = new ActionButtonsModuleConfig(); return c5.IsEnabled ? c5.Opacity : 1.0;
      case 6: let c6: ref<HintsModuleConfig> = new HintsModuleConfig(); return c6.IsEnabled ? c6.Opacity : 1.0;
      case 7: let c7: ref<CrouchIndicatorModuleConfig> = new CrouchIndicatorModuleConfig(); return c7.IsEnabled ? c7.Opacity : 1.0;
      default: return 1.0;
    };
  }

  @if(!ModuleExists("LimitedHudConfig"))
  public final func LhudOpacity(id: Int32) -> Float {
    return 1.0;
  }

  // ---- compass probe ----

  public final func Probe() -> Void {
    this.Broadcast();
  }

  public final func MarkCompassWidget() -> Void {
    this.m_compassWidgetSeen = true;
  }

  public final func CompassWidgetSeen() -> Bool {
    return this.m_compassWidgetSeen;
  }

  // ---- session / polling ----

  // The CET window pushes its saved state once per game session; this tells it whether it did.
  public final func CetApplied() -> Bool { return this.m_cetApplied; }
  public final func MarkCetApplied() -> Void { this.m_cetApplied = true; }

  public final func AnyHidden() -> Bool {
    for h in this.m_hidden {
      if h {
        return true;
      };
    };
    return false;
  }

  public final func AnyActive() -> Bool {
    if this.AnyHidden() {
      return true;
    };
    for o in this.m_opacity {
      if o >= 0.0 {
        return true;
      };
    };
    return false;
  }

  private final func Broadcast() -> Void {
    GameInstance.GetUISystem(this.GetGameInstance()).QueueEvent(new CyberslopHudControlEvent());
  }

  private final func StartPolling() -> Void {
    if this.m_polling || !this.AnyActive() {
      return;
    };
    this.m_polling = true;
    this.Schedule();
  }

  private final func Schedule() -> Void {
    let cb: ref<CyberslopHudControlTick> = new CyberslopHudControlTick();
    cb.sys = this;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, 0.5, false);
  }

  public final func Tick() -> Void {
    if !this.AnyActive() {
      this.m_polling = false;
      return;
    };
    this.Broadcast();
    this.Schedule();
  }
}

// ---------------------------------------------------------------------------------------------
// Shared controller helpers
// ---------------------------------------------------------------------------------------------

// cs_hudControlHidden: this controller's root is held hidden by us.
// cs_hudControlWanted: what the game last wanted for the root while we held it (restored on unhide).
// cs_hudOpOverridden: this controller's opacity is currently overridden by us.
@addField(inkGameController)
public let cs_hudControlHidden: Bool;

@addField(inkGameController)
public let cs_hudControlWanted: Bool;

@addField(inkGameController)
public let cs_hudOpOverridden: Bool;

// last root opacity / target seen by the opacity pass (to tell a running LHUD fade from a still root)
@addField(inkGameController)
public let cs_hudOpLastCur: Float;

@addField(inkGameController)
public let cs_hudOpLastTarget: Float;

@addMethod(inkGameController)
public final func CyberslopHudControl_Apply(id: Int32) -> Void {
  let root: ref<inkWidget> = this.GetRootWidget();
  if !IsDefined(root) {
    return;
  };
  let sys: ref<CyberslopHudControl> = CyberslopHudControl.Get();
  let hide: Bool = IsDefined(sys) && sys.IsHidden(id);
  if hide {
    if !this.cs_hudControlHidden {
      this.cs_hudControlWanted = root.IsVisible();
      this.cs_hudControlHidden = true;
    } else {
      if root.IsVisible() {
        // something showed it directly since the last pass: the game wants it visible
        this.cs_hudControlWanted = true;
      };
    };
    if root.IsVisible() {
      root.SetVisible(false);
    };
  } else {
    if this.cs_hudControlHidden {
      this.cs_hudControlHidden = false;
      root.SetVisible(this.cs_hudControlWanted);
    };
  };
}

@addMethod(inkGameController)
public final func CyberslopHudControl_Opacity(id: Int32) -> Float {
  let sys: ref<CyberslopHudControl> = CyberslopHudControl.Get();
  if !IsDefined(sys) {
    return -1.0;
  };
  return sys.GetOpacity(id);
}

// op: the override (-1 = none); target: the opacity the root should have while shown.
// A root at 0 is being kept hidden by LHUD: left alone, LHUD's next fade-in uses the config value.
// A shown root is corrected when the value just changed, or when it stood still since the last pass
// (0.5 s, longer than LHUD's 0.25-0.3 s fades), so a running fade-out is never yanked back up.
@addMethod(inkGameController)
public final func CyberslopHudControl_ApplyOpacity(op: Float, target: Float) -> Void {
  if op < 0.0 && !this.cs_hudOpOverridden {
    return;
  };
  let root: ref<inkWidget> = this.GetRootWidget();
  if IsDefined(root) {
    let cur: Float = root.GetOpacity();
    let changed: Bool = AbsF(target - this.cs_hudOpLastTarget) > 0.005;
    let still: Bool = AbsF(cur - this.cs_hudOpLastCur) < 0.002;
    if cur > 0.001 && AbsF(cur - target) > 0.005 && (changed || still) {
      root.SetOpacity(target);
      cur = target;
    };
    this.cs_hudOpLastCur = cur;
    this.cs_hudOpLastTarget = target;
  };
  this.cs_hudOpOverridden = op >= 0.0;
}

// Vanilla / LHUD show and hide paths of HUD modules: keep our hide, remember the intent.
@wrapMethod(inkHUDGameController)
protected final func ShowRequest() -> Void {
  wrappedMethod();
  if this.cs_hudControlHidden {
    this.cs_hudControlWanted = true;
    this.GetRootWidget().SetVisible(false);
  };
}

@wrapMethod(inkHUDGameController)
protected final func HideRequest() -> Void {
  wrappedMethod();
  if this.cs_hudControlHidden {
    this.cs_hudControlWanted = false;
  };
}

@wrapMethod(inkHUDGameController)
protected cb func OnHideAnimationFinished(anim: ref<inkAnimProxy>) -> Bool {
  let r: Bool = wrappedMethod(anim);
  if this.cs_hudControlHidden {
    this.cs_hudControlWanted = false;
  };
  return r;
}

@wrapMethod(inkHUDGameController)
protected cb func OnPlayInitFoldingAnimFinished(anim: ref<inkAnimProxy>) -> Bool {
  let r: Bool = wrappedMethod(anim);
  if this.cs_hudControlHidden {
    this.cs_hudControlWanted = true;
    this.GetRootWidget().SetVisible(false);
  };
  return r;
}

// ---------------------------------------------------------------------------------------------
// Per-element LHUD config override. CyberslopHudControl_Cfg(op) writes op into the controller's LHUD
// config (or restores Mod Settings' value after an override) and returns the opacity the root should
// have while shown. Without LHUD: op, or 100 %.
// ---------------------------------------------------------------------------------------------

@if(ModuleExists("LimitedHudConfig"))
@addMethod(MinimapContainerController)
public final func CyberslopHudControl_Cfg(op: Float) -> Float {
  if op < 0.0 && this.cs_hudOpOverridden { this.lhudConfig = new MinimapModuleConfig(); };
  if !IsDefined(this.lhudConfig) || !this.lhudConfig.IsEnabled { return op >= 0.0 ? op : 1.0; };
  if op >= 0.0 { this.lhudConfig.Opacity = op; };
  return this.lhudConfig.Opacity;
}

@if(ModuleExists("LimitedHudConfig"))
@addMethod(QuestTrackerGameController)
public final func CyberslopHudControl_Cfg(op: Float) -> Float {
  if op < 0.0 && this.cs_hudOpOverridden { this.lhudConfig = new QuestTrackerModuleConfig(); };
  if !IsDefined(this.lhudConfig) || !this.lhudConfig.IsEnabled { return op >= 0.0 ? op : 1.0; };
  if op >= 0.0 { this.lhudConfig.Opacity = op; };
  return this.lhudConfig.Opacity;
}

@if(ModuleExists("LimitedHudConfig"))
@addMethod(healthbarWidgetGameController)
public final func CyberslopHudControl_Cfg(op: Float) -> Float {
  if op < 0.0 && this.cs_hudOpOverridden { this.lhudConfig = new PlayerHealthbarModuleConfig(); };
  if !IsDefined(this.lhudConfig) || !this.lhudConfig.IsEnabled { return op >= 0.0 ? op : 1.0; };
  if op >= 0.0 { this.lhudConfig.Opacity = op; };
  return this.lhudConfig.Opacity;
}

@if(ModuleExists("LimitedHudConfig"))
@addMethod(StaminabarWidgetGameController)
public final func CyberslopHudControl_Cfg(op: Float) -> Float {
  if op < 0.0 && this.cs_hudOpOverridden { this.lhudConfig = new PlayerStaminabarModuleConfig(); };
  if !IsDefined(this.lhudConfig) || !this.lhudConfig.IsEnabled { return op >= 0.0 ? op : 1.0; };
  if op >= 0.0 { this.lhudConfig.Opacity = op; };
  return this.lhudConfig.Opacity;
}

@if(ModuleExists("LimitedHudConfig"))
@addMethod(WeaponRosterGameController)
public final func CyberslopHudControl_Cfg(op: Float) -> Float {
  if op < 0.0 && this.cs_hudOpOverridden { this.lhudConfig = new WeaponRosterModuleConfig(); };
  if !IsDefined(this.lhudConfig) || !this.lhudConfig.IsEnabled { return op >= 0.0 ? op : 1.0; };
  if op >= 0.0 { this.lhudConfig.Opacity = op; };
  return this.lhudConfig.Opacity;
}

@if(ModuleExists("LimitedHudConfig"))
@addMethod(HotkeysWidgetController)
public final func CyberslopHudControl_Cfg(op: Float) -> Float {
  if op < 0.0 && this.cs_hudOpOverridden { this.lhudConfig = new ActionButtonsModuleConfig(); };
  if !IsDefined(this.lhudConfig) || !this.lhudConfig.IsEnabled { return op >= 0.0 ? op : 1.0; };
  if op >= 0.0 { this.lhudConfig.Opacity = op; };
  return this.lhudConfig.Opacity;
}

@if(ModuleExists("LimitedHudConfig"))
@addMethod(PhoneHotkeyController)
public final func CyberslopHudControl_Cfg(op: Float) -> Float {
  if op < 0.0 && this.cs_hudOpOverridden { this.lhudConfig = new ActionButtonsModuleConfig(); };
  if !IsDefined(this.lhudConfig) || !this.lhudConfig.IsEnabled { return op >= 0.0 ? op : 1.0; };
  if op >= 0.0 { this.lhudConfig.Opacity = op; };
  return this.lhudConfig.Opacity;
}

@if(ModuleExists("LimitedHudConfig"))
@addMethod(RadioHotkeyController)
public final func CyberslopHudControl_Cfg(op: Float) -> Float {
  if op < 0.0 && this.cs_hudOpOverridden { this.lhudConfig = new ActionButtonsModuleConfig(); };
  if !IsDefined(this.lhudConfig) || !this.lhudConfig.IsEnabled { return op >= 0.0 ? op : 1.0; };
  if op >= 0.0 { this.lhudConfig.Opacity = op; };
  return this.lhudConfig.Opacity;
}

@if(ModuleExists("LimitedHudConfig"))
@addMethod(CarHotkeyController)
public final func CyberslopHudControl_Cfg(op: Float) -> Float {
  if op < 0.0 && this.cs_hudOpOverridden { this.lhudConfig = new ActionButtonsModuleConfig(); };
  if !IsDefined(this.lhudConfig) || !this.lhudConfig.IsEnabled { return op >= 0.0 ? op : 1.0; };
  if op >= 0.0 { this.lhudConfig.Opacity = op; };
  return this.lhudConfig.Opacity;
}

@if(ModuleExists("LimitedHudConfig"))
@addMethod(vehicleVisualCustomizationHotkeyController)
public final func CyberslopHudControl_Cfg(op: Float) -> Float {
  if op < 0.0 && this.cs_hudOpOverridden { this.lhudConfig = new ActionButtonsModuleConfig(); };
  if !IsDefined(this.lhudConfig) || !this.lhudConfig.IsEnabled { return op >= 0.0 ? op : 1.0; };
  if op >= 0.0 { this.lhudConfig.Opacity = op; };
  return this.lhudConfig.Opacity;
}

@if(ModuleExists("LimitedHudConfig"))
@addMethod(HotkeyConsumableWidgetController)
public final func CyberslopHudControl_Cfg(op: Float) -> Float {
  if op < 0.0 && this.cs_hudOpOverridden { this.lhudConfig = new ActionButtonsModuleConfig(); };
  if !IsDefined(this.lhudConfig) || !this.lhudConfig.IsEnabled { return op >= 0.0 ? op : 1.0; };
  if op >= 0.0 { this.lhudConfig.Opacity = op; };
  return this.lhudConfig.Opacity;
}

@if(ModuleExists("LimitedHudConfig"))
@addMethod(HotkeyCustomRadioWidgetController)
public final func CyberslopHudControl_Cfg(op: Float) -> Float {
  if op < 0.0 && this.cs_hudOpOverridden { this.lhudConfig = new ActionButtonsModuleConfig(); };
  if !IsDefined(this.lhudConfig) || !this.lhudConfig.IsEnabled { return op >= 0.0 ? op : 1.0; };
  if op >= 0.0 { this.lhudConfig.Opacity = op; };
  return this.lhudConfig.Opacity;
}

@if(ModuleExists("LimitedHudConfig"))
@addMethod(InputHintManagerGameController)
public final func CyberslopHudControl_Cfg(op: Float) -> Float {
  if op < 0.0 && this.cs_hudOpOverridden { this.lhudConfig = new HintsModuleConfig(); };
  if !IsDefined(this.lhudConfig) || !this.lhudConfig.IsEnabled { return op >= 0.0 ? op : 1.0; };
  if op >= 0.0 { this.lhudConfig.Opacity = op; };
  return this.lhudConfig.Opacity;
}

@if(ModuleExists("LimitedHudConfig"))
@addMethod(CrouchIndicatorGameController)
public final func CyberslopHudControl_Cfg(op: Float) -> Float {
  if op < 0.0 && this.cs_hudOpOverridden { this.lhudConfig = new CrouchIndicatorModuleConfig(); };
  if !IsDefined(this.lhudConfig) || !this.lhudConfig.IsEnabled { return op >= 0.0 ? op : 1.0; };
  if op >= 0.0 { this.lhudConfig.Opacity = op; };
  return this.lhudConfig.Opacity;
}

// Without Limited HUD: plain root opacity.
@if(!ModuleExists("LimitedHudConfig"))
@addMethod(inkGameController)
public final func CyberslopHudControl_Cfg(op: Float) -> Float {
  return op >= 0.0 ? op : 1.0;
}

// ---------------------------------------------------------------------------------------------
// Event handlers
// ---------------------------------------------------------------------------------------------

@addMethod(MinimapContainerController)
protected cb func OnCyberslopHudControlEvent(evt: ref<CyberslopHudControlEvent>) -> Bool {
  this.CyberslopHudControl_Apply(0);
  let op: Float = this.CyberslopHudControl_Opacity(0);
  this.CyberslopHudControl_ApplyOpacity(op, this.CyberslopHudControl_Cfg(op));
}

@addMethod(QuestTrackerGameController)
protected cb func OnCyberslopHudControlEvent(evt: ref<CyberslopHudControlEvent>) -> Bool {
  this.CyberslopHudControl_Apply(1);
  let op: Float = this.CyberslopHudControl_Opacity(1);
  this.CyberslopHudControl_ApplyOpacity(op, this.CyberslopHudControl_Cfg(op));
}

@addMethod(healthbarWidgetGameController)
protected cb func OnCyberslopHudControlEvent(evt: ref<CyberslopHudControlEvent>) -> Bool {
  this.CyberslopHudControl_Apply(2);
  let op: Float = this.CyberslopHudControl_Opacity(2);
  this.CyberslopHudControl_ApplyOpacity(op, this.CyberslopHudControl_Cfg(op));
}

@addMethod(StaminabarWidgetGameController)
protected cb func OnCyberslopHudControlEvent(evt: ref<CyberslopHudControlEvent>) -> Bool {
  this.CyberslopHudControl_Apply(3);
  let op: Float = this.CyberslopHudControl_Opacity(3);
  this.CyberslopHudControl_ApplyOpacity(op, this.CyberslopHudControl_Cfg(op));
}

@addMethod(WeaponRosterGameController)
protected cb func OnCyberslopHudControlEvent(evt: ref<CyberslopHudControlEvent>) -> Bool {
  this.CyberslopHudControl_Apply(4);
  let op: Float = this.CyberslopHudControl_Opacity(4);
  this.CyberslopHudControl_ApplyOpacity(op, this.CyberslopHudControl_Cfg(op));
}

@addMethod(HotkeysWidgetController)
protected cb func OnCyberslopHudControlEvent(evt: ref<CyberslopHudControlEvent>) -> Bool {
  this.CyberslopHudControl_Apply(5);
  let op: Float = this.CyberslopHudControl_Opacity(5);
  let cfg: Float = this.CyberslopHudControl_Cfg(op);
  this.CyberslopHudControl_ApplyOpacity(op, cfg);
  this.CyberslopHudControl_DpadSlots(op >= 0.0 ? 1.0 : cfg);
}

// 1.1.2: LHUD fades the dpad root AND its phone / car / radio slots to the config opacity, so the icons inside showed
// at op x op. While the hotkeys have an override the slots stay at 100 % (the root carries the value); cleared, they
// go back to the config value. A slot LHUD has faded out (0) is left alone.
@addMethod(HotkeysWidgetController)
private final func CyberslopHudControl_DpadSlots(target: Float) -> Void {
  if inkWidgetRef.GetOpacity(this.m_phoneSlot) > 0.001 { inkWidgetRef.SetOpacity(this.m_phoneSlot, target); };
  if inkWidgetRef.GetOpacity(this.m_carSlot) > 0.001 { inkWidgetRef.SetOpacity(this.m_carSlot, target); };
  if inkWidgetRef.GetOpacity(this.m_radioSlot) > 0.001 { inkWidgetRef.SetOpacity(this.m_radioSlot, target); };
}

// Hotkey controllers nested inside the dpad widget: 100 % while the hotkeys have an override, so the
// dpad root's value is the one you see.
@addMethod(inkGameController)
public final func CyberslopHudControl_NestedHotkey() -> Float {
  let op: Float = this.CyberslopHudControl_Opacity(5);
  return op >= 0.0 ? 1.0 : -1.0;
}

@addMethod(PhoneHotkeyController)
protected cb func OnCyberslopHudControlEvent(evt: ref<CyberslopHudControlEvent>) -> Bool {
  let op: Float = this.CyberslopHudControl_NestedHotkey();
  this.CyberslopHudControl_ApplyOpacity(op, this.CyberslopHudControl_Cfg(op));
}

@addMethod(RadioHotkeyController)
protected cb func OnCyberslopHudControlEvent(evt: ref<CyberslopHudControlEvent>) -> Bool {
  let op: Float = this.CyberslopHudControl_NestedHotkey();
  this.CyberslopHudControl_ApplyOpacity(op, this.CyberslopHudControl_Cfg(op));
}

@addMethod(CarHotkeyController)
protected cb func OnCyberslopHudControlEvent(evt: ref<CyberslopHudControlEvent>) -> Bool {
  let op: Float = this.CyberslopHudControl_NestedHotkey();
  this.CyberslopHudControl_ApplyOpacity(op, this.CyberslopHudControl_Cfg(op));
}

@addMethod(vehicleVisualCustomizationHotkeyController)
protected cb func OnCyberslopHudControlEvent(evt: ref<CyberslopHudControlEvent>) -> Bool {
  let op: Float = this.CyberslopHudControl_NestedHotkey();
  this.CyberslopHudControl_ApplyOpacity(op, this.CyberslopHudControl_Cfg(op));
}

// Separate HUD entries of the hotkey group (vehicle consumables bar, custom radio): same value.
@addMethod(HotkeyConsumableWidgetController)
protected cb func OnCyberslopHudControlEvent(evt: ref<CyberslopHudControlEvent>) -> Bool {
  let op: Float = this.CyberslopHudControl_Opacity(5);
  this.CyberslopHudControl_ApplyOpacity(op, this.CyberslopHudControl_Cfg(op));
}

@addMethod(HotkeyCustomRadioWidgetController)
protected cb func OnCyberslopHudControlEvent(evt: ref<CyberslopHudControlEvent>) -> Bool {
  let op: Float = this.CyberslopHudControl_Opacity(5);
  this.CyberslopHudControl_ApplyOpacity(op, this.CyberslopHudControl_Cfg(op));
}

@addMethod(InputHintManagerGameController)
protected cb func OnCyberslopHudControlEvent(evt: ref<CyberslopHudControlEvent>) -> Bool {
  this.CyberslopHudControl_Apply(6);
  let op: Float = this.CyberslopHudControl_Opacity(6);
  this.CyberslopHudControl_ApplyOpacity(op, this.CyberslopHudControl_Cfg(op));
}

@addMethod(CrouchIndicatorGameController)
protected cb func OnCyberslopHudControlEvent(evt: ref<CyberslopHudControlEvent>) -> Bool {
  this.CyberslopHudControl_Apply(7);
  let op: Float = this.CyberslopHudControl_Opacity(7);
  this.CyberslopHudControl_ApplyOpacity(op, this.CyberslopHudControl_Cfg(op));
}

// Quest Compass: its widget is the IronsightGameController whose root holds "pin_container" (weapon
// iron sights use the same class without it). Root opacity is free: QC and LHUD fade its children.
@addMethod(IronsightGameController)
protected cb func OnCyberslopHudControlEvent(evt: ref<CyberslopHudControlEvent>) -> Bool {
  let root: ref<inkCompoundWidget> = this.GetRootWidget() as inkCompoundWidget;
  if !IsDefined(root) || !IsDefined(root.GetWidgetByPathName(n"pin_container")) {
    return false;
  };
  let sys: ref<CyberslopHudControl> = CyberslopHudControl.Get();
  if IsDefined(sys) {
    sys.MarkCompassWidget();
  };
  let op: Float = this.CyberslopHudControl_Opacity(8);
  if op >= 0.0 {
    root.SetOpacity(op);
    this.cs_hudOpOverridden = true;
  } else {
    if this.cs_hudOpOverridden {
      root.SetOpacity(1.0);
      this.cs_hudOpOverridden = false;
    };
  };
}
