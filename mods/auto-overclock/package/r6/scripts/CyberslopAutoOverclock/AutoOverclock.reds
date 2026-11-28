module CyberslopAutoOverclock

// Cyberslop Auto Overclock 1.0.2 (game 2.5)
// Execute on a quickhack that is blocked only for lack of RAM ("LocKey#27398") switches Overclock on,
// uploads the hack (missing RAM paid with health, vanilla Overclock rule) and switches Overclock off
// again Grace() real seconds after the last hack sent while it is on. Overclock you switched on yourself
// is never touched; a manual toggle during the grace window hands Overclock back to you.
// Skipped when Overclock can't start (perk, deck, charge for the grace window, Overheat burn lock)
// or when paying would leave less than HealthFloor() of max health.
// 1.0.1: the health floor also guards further hacks while auto Overclock is on; the off timer never
// outlasts the remaining charge (Overclock Overheat burns V when it runs dry); the next-frame send
// fallback leaves switching off to the timer; Mod Settings "Debug log" (FTLog "[AutoOverclock] ...").
// 1.0.2: the in-game test log showed the Overclock buff is never visible in the activating frame and the
// DelayCallbackNextFrame send never ran before the 3 s off timer (game-time callback, wheel time
// dilation), so one press only switched Overclock on. The send now retries on real-time 50 ms ticks
// (up to 1 s); a second press that sends first cancels it; log names hacks and labels floor results.

@addField(QuickhackData)
public let csAutoOcAction: ref<BaseScriptableAction>;

public class CsAutoOcSettings extends ScriptableSystem {

  @runtimeProperty("ModSettings.mod", "Cyberslop Auto Overclock")
  @runtimeProperty("ModSettings.category", "Debug")
  @runtimeProperty("ModSettings.displayName", "Debug log")
  @runtimeProperty("ModSettings.description", "On: every auto Overclock decision goes to the game log as [AutoOverclock] lines (attempts, RAM, health, Overclock on / off, reasons for doing nothing).")
  public let debugLog: Bool = false;

  private func OnAttach() -> Void {
    CsAutoOcSettings.Register(this);
  }

  private func OnDetach() -> Void {
    CsAutoOcSettings.Unregister(this);
  }

  public static func Get(gi: GameInstance) -> ref<CsAutoOcSettings> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(NameOf<CsAutoOcSettings>()) as CsAutoOcSettings;
  }

  public static func Dbg(gi: GameInstance) -> Bool {
    let s: ref<CsAutoOcSettings> = CsAutoOcSettings.Get(gi);
    return IsDefined(s) && s.debugLog;
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

public class CsAutoOc extends ScriptableSystem {
  private let m_owned: Bool;
  private let m_selfToggle: Bool;
  private let m_offID: DelayID;
  private let m_offPending: Bool;
  private let m_pendingSend: ref<CsAutoOcSendCallback>;

  // Real seconds Overclock stays on after the last hack sent while auto Overclock owns it
  public static func Grace() -> Float {
    return 3.0;
  }

  // Share of max health that must remain after the health payment
  public static func HealthFloor() -> Float {
    return 0.25;
  }

  // Charge (seconds) kept in reserve so Overclock never runs dry under the mod
  public static func ChargeMargin() -> Float {
    return 0.5;
  }

  public static func Get(gi: GameInstance) -> ref<CsAutoOc> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"CyberslopAutoOverclock.CsAutoOc") as CsAutoOc;
  }

  // NPC entries locked by RAM carry no m_action in vanilla; the puppet wrap below stores it here
  public static func ActionOf(data: ref<QuickhackData>) -> ref<BaseScriptableAction> {
    if !IsDefined(data) {
      return null;
    };
    if IsDefined(data.m_action) {
      return data.m_action;
    };
    return data.csAutoOcAction;
  }

  public final func Dbg() -> Bool {
    return CsAutoOcSettings.Dbg(this.GetGameInstance());
  }

  public final func Log(const msg: script_ref<String>) -> Void {
    FTLog("[AutoOverclock] " + Deref(msg));
  }

  public final func IsSelfToggle() -> Bool {
    return this.m_selfToggle;
  }

  public final func OwnsActive(player: ref<GameObject>) -> Bool {
    return this.m_owned && QuickHackableHelper.IsOverclockedStateActive(player);
  }

  // Any Overclock toggle that is not ours (key, hold, wheel button): Overclock belongs to V again
  public final func OnForeignToggle() -> Void {
    if this.m_owned && this.Dbg() {
      this.Log("manual Overclock toggle: handed back to V, off timer cancelled");
    };
    this.CancelOff();
    this.m_owned = false;
  }

  public final func Ram(player: ref<PlayerPuppet>) -> Float {
    return GameInstance.GetStatPoolsSystem(player.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Memory, false);
  }

  // Seconds of Overclock charge left (full charge = CyberdeckOverclockDuration)
  public final func ChargeSeconds(player: ref<PlayerPuppet>) -> Float {
    let id: StatsObjectID = Cast<StatsObjectID>(player.GetEntityID());
    let duration: Float = GameInstance.GetStatsSystem(player.GetGame()).GetStatValue(id, gamedataStatType.CyberdeckOverclockDuration);
    let pct: Float = GameInstance.GetStatPoolsSystem(player.GetGame()).GetStatPoolValue(id, gamedataStatPoolType.CyberdeckOverclock, true);
    if duration <= 0.0 {
      return -1.0;
    };
    return pct * duration / 100.0;
  }

  // True when the hack needs no health, or the health it takes keeps V at or above the floor
  public final func KeepsFloor(player: ref<PlayerPuppet>, cost: Int32, const tag: script_ref<String>) -> Bool {
    let id: StatsObjectID = Cast<StatsObjectID>(player.GetEntityID());
    let healthCost: Float;
    let health: Float;
    let maxHealth: Float;
    let ram: Float = this.Ram(player);
    if ram >= Cast<Float>(cost) {
      return true;
    };
    if !QuickHackableHelper.CanPayWithHealthInOverclockedState(player, cost, healthCost) {
      if this.Dbg() {
        this.Log("not sent " + Deref(tag) + ": health can't pay it (RAM " + FloatToStringPrec(ram, 1) + " / " + IntToString(cost) + ")");
      };
      return false;
    };
    health = GameInstance.GetStatPoolsSystem(player.GetGame()).GetStatPoolValue(id, gamedataStatPoolType.Health, false);
    maxHealth = GameInstance.GetStatsSystem(player.GetGame()).GetStatValue(id, gamedataStatType.Health);
    if maxHealth > 0.0 && health - healthCost < CsAutoOc.HealthFloor() * maxHealth {
      if this.Dbg() {
        this.Log("not sent " + Deref(tag) + ": health floor, " + FloatToStringPrec(health, 0) + " - " + FloatToStringPrec(healthCost, 0) + " < " + FloatToStringPrec(CsAutoOc.HealthFloor() * maxHealth, 0) + " (max " + FloatToStringPrec(maxHealth, 0) + ")");
      };
      return false;
    };
    if this.Dbg() {
      this.Log("floor kept " + Deref(tag) + ": health pays " + FloatToStringPrec(healthCost, 0) + " of " + FloatToStringPrec(health, 0) + " (RAM " + FloatToStringPrec(ram, 1) + " / " + IntToString(cost) + ")");
    };
    return true;
  }

  // Locked for lack of RAM and nothing else
  public final func IsRamOnlyBlock(player: ref<PlayerPuppet>, data: ref<QuickhackData>) -> Bool {
    let target: ref<GameObject>;
    if !IsDefined(player) || !IsDefined(data) || !data.m_isLocked || data.m_noQuickhackData {
      return false;
    };
    if NotEquals(data.m_actionState, EActionInactivityReson.OutOfMemory) || NotEquals(data.m_inactiveReason, "LocKey#27398") {
      if this.Dbg() {
        this.Log("skip " + GetLocalizedText(data.m_title) + ": locked for another reason (" + data.m_inactiveReason + ", state " + EnumValueToString("EActionInactivityReson", Cast<Int64>(EnumInt(data.m_actionState))) + ")");
      };
      return false;
    };
    if !IsDefined(CsAutoOc.ActionOf(data)) {
      if this.Dbg() {
        this.Log("skip " + GetLocalizedText(data.m_title) + ": no action stored for this entry");
      };
      return false;
    };
    // devices: the cooldown lock is overwritten by the RAM lock, check it here
    if TDBID.IsValid(data.m_cooldownTweak) && StatusEffectSystem.ObjectHasStatusEffect(player, data.m_cooldownTweak) {
      if this.Dbg() {
        this.Log("skip " + GetLocalizedText(data.m_title) + ": on cooldown");
      };
      return false;
    };
    target = GameInstance.FindEntityByID(player.GetGame(), data.m_actionOwner) as GameObject;
    if !IsDefined(target) {
      if this.Dbg() {
        this.Log("skip " + GetLocalizedText(data.m_title) + ": target gone");
      };
      return false;
    };
    // devices: an upload in progress without the queue perk uses the same lock text
    if target.HasActiveQuickHackUpload() && !QuickHackableQueueHelper.IsQueuePerkBought(player) {
      if this.Dbg() {
        this.Log("skip " + GetLocalizedText(data.m_title) + ": upload in progress, no queue perk");
      };
      return false;
    };
    return true;
  }

  // Overclock can start, has charge for the grace window, and the health payment keeps the floor
  public final func CanAfford(player: ref<PlayerPuppet>, data: ref<QuickhackData>, action: ref<BaseScriptableAction>) -> Bool {
    let charge: Float;
    if QuickHackableHelper.IsOverclockedStateActive(player) {
      if this.Dbg() {
        this.Log("skip " + GetLocalizedText(data.m_title) + ": Overclock already on");
      };
      return false;
    };
    if !QuickHackableHelper.CanActivateOverclockedState(player) {
      if this.Dbg() {
        this.Log("skip " + GetLocalizedText(data.m_title) + ": Overclock not available (perk, deck or replacer)");
      };
      return false;
    };
    // Overheat's partialCharge allows a start on a partial charge; running dry burns V
    charge = this.ChargeSeconds(player);
    if charge >= 0.0 && charge < CsAutoOc.Grace() + CsAutoOc.ChargeMargin() {
      if this.Dbg() {
        this.Log("skip " + GetLocalizedText(data.m_title) + ": Overclock charge " + FloatToStringPrec(charge, 1) + " s < " + FloatToStringPrec(CsAutoOc.Grace() + CsAutoOc.ChargeMargin(), 1) + " s");
      };
      return false;
    };
    return this.KeepsFloor(player, action.GetCost(), GetLocalizedText(data.m_title));
  }

  public final func Activate(player: ref<PlayerPuppet>) -> Bool {
    let ok: Bool;
    this.m_selfToggle = true;
    ok = QuickHackableHelper.TryToCycleOverclockedState(player);
    this.m_selfToggle = false;
    if this.Dbg() {
      this.Log(ok ? "Overclock ON (auto)" : "Overclock toggle refused (Overheat burn lock or cooldown)");
    };
    if ok {
      this.m_owned = true;
      this.ArmOff();
    };
    return ok;
  }

  // (Re)start the off timer: Grace() seconds, shorter if the charge would run out first
  public final func ArmOff() -> Void {
    let job: ref<CsAutoOcOffCallback>;
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    let delay: Float = CsAutoOc.Grace();
    let charge: Float;
    this.CancelOff();
    if IsDefined(player) {
      charge = this.ChargeSeconds(player);
      if charge >= 0.0 {
        // never below 0.2 s: the target pays when it handles the command, a frame or two later
        delay = MaxF(0.2, MinF(delay, charge - CsAutoOc.ChargeMargin()));
      };
    };
    job = new CsAutoOcOffCallback();
    job.system = this;
    this.m_offID = GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(job, delay, false);
    this.m_offPending = true;
    if this.Dbg() {
      this.Log("off timer " + FloatToStringPrec(delay, 2) + " s (charge " + FloatToStringPrec(charge, 1) + " s)");
    };
  }

  private final func CancelOff() -> Void {
    if this.m_offPending {
      GameInstance.GetDelaySystem(this.GetGameInstance()).CancelCallback(this.m_offID);
      this.m_offPending = false;
    };
  }

  public final func OnOffTimer() -> Void {
    this.m_offPending = false;
    if this.Dbg() {
      this.Log("off timer fired");
    };
    this.SwitchOff();
  }

  public final func SwitchOff() -> Void {
    let player: ref<PlayerPuppet>;
    this.CancelOff();
    player = GetPlayer(this.GetGameInstance());
    if this.m_owned && IsDefined(player) && QuickHackableHelper.IsOverclockedStateActive(player) {
      this.m_selfToggle = true;
      QuickHackableHelper.TryToCycleOverclockedState(player);
      this.m_selfToggle = false;
      if this.Dbg() {
        this.Log("Overclock OFF (auto), charge left " + FloatToStringPrec(this.ChargeSeconds(player), 1) + " s");
      };
    } else {
      if this.m_owned && this.Dbg() {
        this.Log("switch off: Overclock already off");
      };
    };
    this.m_owned = false;
    this.m_pendingSend = null;
  }

  public final func HasPendingSend() -> Bool {
    return IsDefined(this.m_pendingSend);
  }

  // The same hack on the same target sent from the wheel while its delayed send waits replaces it (no double upload)
  public final func DropPendingSend(data: ref<QuickhackData>, const why: script_ref<String>) -> Void {
    if IsDefined(this.m_pendingSend) && IsDefined(data) && this.m_pendingSend.data.m_actionOwner == data.m_actionOwner && Equals(this.m_pendingSend.data.m_title, data.m_title) {
      if this.Dbg() {
        this.Log("pending send of " + GetLocalizedText(this.m_pendingSend.data.m_title) + " dropped: " + Deref(why));
      };
      this.m_pendingSend = null;
    };
  }

  // The Overclock buff is never visible in the activating frame (V's log 2026-11-28): send on real-time
  // ticks. DelayCallbackNextFrame runs on game time and did not fire before the 3 s off timer.
  public static func RetryStep() -> Float {
    return 0.05;
  }

  public static func RetryMax() -> Int32 {
    return 20;
  }

  public final func QueueSend(data: ref<QuickhackData>, action: ref<BaseScriptableAction>) -> Void {
    let job: ref<CsAutoOcSendCallback> = new CsAutoOcSendCallback();
    job.system = this;
    job.data = data;
    job.action = action;
    this.m_pendingSend = job;
    if this.Dbg() {
      this.Log("Overclock buff not visible yet, sending " + GetLocalizedText(data.m_title) + " in " + FloatToStringPrec(CsAutoOc.RetryStep(), 2) + " s steps");
    };
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(job, CsAutoOc.RetryStep(), false);
  }

  public final func RetrySend(job: ref<CsAutoOcSendCallback>) -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    let cmd: ref<QuickSlotCommandUsed>;
    let hackUsed: ref<QhackExecuted>;
    let toc: ref<TakeOverControlSystem>;
    if this.m_pendingSend != job {
      return;
    };
    if !IsDefined(player) || !this.m_owned || !IsDefined(job.action) {
      if this.Dbg() {
        this.Log("send " + GetLocalizedText(job.data.m_title) + " dropped: Overclock no longer ours");
      };
      this.m_pendingSend = null;
      return;
    };
    if !QuickHackableHelper.IsOverclockedStateActive(player) {
      if job.tries < CsAutoOc.RetryMax() {
        job.tries += 1;
        GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(job, CsAutoOc.RetryStep(), false);
        return;
      };
      this.m_pendingSend = null;
      // keep ownership: the off timer armed at activation switches it off if the buff shows up late
      if this.Dbg() {
        this.Log("gave up on " + GetLocalizedText(job.data.m_title) + ": Overclock buff not visible after " + FloatToStringPrec(Cast<Float>(CsAutoOc.RetryMax()) * CsAutoOc.RetryStep(), 1) + " s");
      };
      return;
    };
    this.m_pendingSend = null;
    if !job.action.CanPayCost(null, true) {
      if this.Dbg() {
        this.Log("send " + GetLocalizedText(job.data.m_title) + ": still can't pay under Overclock");
      };
      this.SwitchOff();
      return;
    };
    cmd = new QuickSlotCommandUsed();
    cmd.action = job.action;
    player.QueueEventForEntityID(job.data.m_actionOwner, cmd);
    toc = player.GetTakeOverControlSystem();
    if IsDefined(toc) && toc.IsDeviceControlled() && IsDefined(toc.GetControlledObject()) {
      hackUsed = new QhackExecuted();
      player.QueueEventForEntityID(toc.GetControlledObject().GetEntityID(), hackUsed);
    };
    if this.Dbg() {
      this.Log("sent " + GetLocalizedText(job.data.m_title) + " after " + FloatToStringPrec(Cast<Float>(job.tries + 1) * CsAutoOc.RetryStep(), 2) + " s");
    };
    this.ArmOff();
  }
}

public class CsAutoOcOffCallback extends DelayCallback {
  public let system: wref<CsAutoOc>;

  public func Call() -> Void {
    if IsDefined(this.system) {
      this.system.OnOffTimer();
    };
  }
}

public class CsAutoOcSendCallback extends DelayCallback {
  public let system: wref<CsAutoOc>;
  public let data: ref<QuickhackData>;
  public let action: ref<BaseScriptableAction>;
  public let tries: Int32;

  public func Call() -> Void {
    if IsDefined(this.system) {
      this.system.RetrySend(this);
    };
  }
}

// Wheel execute (vanilla UI_ApplyAndClose, Overclock_Hold's OnAction, quickhackHotkeys all land here)
@wrapMethod(QuickhacksListGameController)
private final func ApplyQuickHack(shouldUseUI: Bool) -> Bool {
  let player: ref<PlayerPuppet> = GetPlayer(this.m_gameInstance);
  let sys: ref<CsAutoOc> = CsAutoOc.Get(this.m_gameInstance);
  let data: ref<QuickhackData> = this.m_selectedData;
  let action: ref<BaseScriptableAction>;
  let sent: Bool;
  if !shouldUseUI || !IsDefined(sys) || !IsDefined(player) || !IsDefined(data) {
    return wrappedMethod(shouldUseUI);
  };
  if sys.Dbg() {
    sys.Log("execute " + GetLocalizedText(data.m_title) + ": locked " + (data.m_isLocked ? "yes" : "no") + ", RAM " + FloatToStringPrec(sys.Ram(player), 1) + " / cost " + IntToString(data.m_cost) + ", Overclock " + (QuickHackableHelper.IsOverclockedStateActive(player) ? (sys.OwnsActive(player) ? "on (auto)" : "on (manual)") : "off"));
  };
  if data.m_isLocked && sys.HasPendingSend() {
    if sys.Dbg() {
      sys.Log("skip " + GetLocalizedText(data.m_title) + ": an auto send is still waiting for the Overclock buff");
    };
    return wrappedMethod(shouldUseUI);
  };
  if data.m_isLocked && sys.IsRamOnlyBlock(player, data) {
    action = CsAutoOc.ActionOf(data);
    if !sys.CanAfford(player, data, action) || !sys.Activate(player) {
      return wrappedMethod(shouldUseUI);
    };
    if !QuickHackableHelper.IsOverclockedStateActive(player) {
      sys.QueueSend(data, action);
      wrappedMethod(shouldUseUI);
      return true;
    };
    if !action.CanPayCost(null, true) {
      if sys.Dbg() {
        sys.Log("send " + GetLocalizedText(data.m_title) + ": still can't pay under Overclock");
      };
      sys.SwitchOff();
      return wrappedMethod(shouldUseUI);
    };
    // unlock the entry for this press; the menu refresh the toggle queued rebuilds it next frame
    data.m_action = action;
    data.m_isLocked = false;
    data.m_actionState = EActionInactivityReson.Ready;
    sent = wrappedMethod(shouldUseUI);
    if sys.Dbg() {
      sys.Log((sent ? "sent " : "vanilla refused ") + GetLocalizedText(data.m_title));
    };
    if sent {
      sys.ArmOff();
    } else {
      sys.SwitchOff();
    };
    return sent;
  };
  // auto Overclock window: the health floor guards every hack paid with health, not only the first
  if !data.m_isLocked && sys.OwnsActive(player) && IsDefined(data.m_action) {
    if !sys.KeepsFloor(player, data.m_action.GetCost(), GetLocalizedText(data.m_title)) {
      return false;
    };
  };
  sent = wrappedMethod(shouldUseUI);
  if sent {
    sys.DropPendingSend(data, "sent by a second press");
  };
  if sent && sys.OwnsActive(player) {
    if sys.Dbg() {
      sys.Log("sent " + GetLocalizedText(data.m_title) + " inside the auto window");
    };
    sys.ArmOff();
  };
  return sent;
}

// NPC wheel: keep the action of entries locked only for RAM (vanilla drops it)
@wrapMethod(ScriptedPuppet)
private final func TranslateChoicesIntoQuickSlotCommands(const puppetActions: script_ref<array<ref<PuppetAction>>>, commands: script_ref<array<ref<QuickhackData>>>) -> Void {
  let player: ref<PlayerPuppet>;
  let list: array<PlayerQuickhackData>;
  let listLoaded: Bool;
  let cmd: ref<QuickhackData>;
  let name: CName;
  let a: ref<PuppetAction>;
  let i: Int32;
  let j: Int32;
  let dbg: Bool;
  wrappedMethod(puppetActions, commands);
  player = GetPlayer(this.GetGame());
  if !IsDefined(player) {
    return;
  };
  dbg = CsAutoOcSettings.Dbg(this.GetGame());
  i = 0;
  while i < ArraySize(Deref(commands)) {
    cmd = Deref(commands)[i];
    if IsDefined(cmd) && cmd.m_isLocked && !IsDefined(cmd.m_action) && Equals(cmd.m_actionState, EActionInactivityReson.OutOfMemory) && Equals(cmd.m_inactiveReason, "LocKey#27398") {
      if !listLoaded {
        list = RPGManager.GetPlayerQuickHackListWithQuality(player);
        listLoaded = true;
      };
      name = n"";
      j = 0;
      while j < ArraySize(list) {
        if list[j].itemID == cmd.m_itemID && IsDefined(list[j].actionRecord) {
          name = list[j].actionRecord.ActionName();
          break;
        };
        j += 1;
      };
      if IsNameValid(name) {
        j = 0;
        while j < ArraySize(Deref(puppetActions)) {
          a = Deref(puppetActions)[j];
          if IsDefined(a) && IsDefined(a.GetObjectActionRecord()) && Equals(a.GetObjectActionRecord().ActionName(), name) && Equals(a.GetInactiveReason(), "LocKey#27398") {
            cmd.csAutoOcAction = a;
            break;
          };
          j += 1;
        };
      };
      if dbg {
        FTLog("[AutoOverclock] wheel " + GetLocalizedText(this.GetDisplayName()) + ": RAM-locked " + GetLocalizedText(cmd.m_title) + (IsDefined(cmd.csAutoOcAction) ? " -> action stored" : " -> no matching action"));
      };
    };
    i += 1;
  };
}

// Overclock toggles that are not ours hand Overclock back to V
@wrapMethod(QuickHackableHelper)
public final static func TryToCycleOverclockedState(player: ref<GameObject>) -> Bool {
  let r: Bool = wrappedMethod(player);
  let sys: ref<CsAutoOc>;
  if IsDefined(player) {
    sys = CsAutoOc.Get(player.GetGame());
    if IsDefined(sys) && !sys.IsSelfToggle() {
      sys.OnForeignToggle();
    };
  };
  return r;
}
