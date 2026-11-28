// Cyberslop Merc Stims 1.2.0 (2026-11-26, patch 2.5), V
// 1.2.0: humanity for Wannabe Edgerunner: Anchor, Tether, Lumen, Circuit Breaker, Kill Switch; Rejectol wards
//   -15 %. Wards = status tags CyberslopHumanity.Ward40 / 20 / 15 read in WE AddHumanityDamage (one Cyberslop
//   line); Circuit Breaker / Kill Switch carry WE's Neuroblockers tag (WE ends any episode and blocks damage).
// A merc's pharmacy for Dark Future (records in r6\tweaks\zz_CyberslopMercStims, texts at the bottom).
// 1.0.0: Vigil, Kagami, Hold Fast, Surge, Crank. 1.1.0: Steady, Lull, Boost, Rapidetox, Antitox, Hardline, Serene,
// Zero Point, Respirocyte, Bronchodilator, Ghostline, Emberline, Synthcoke, ProteoMax, Electra, Corpo Daily, Ketone,
// Cold Brew, HydraSalt, NutriGel, NeuroSync, OsteoCal, BioCoolant, Rejectol.
// Every timer runs on the game clock (sleep, waiting and fast travel count). Effects are infinite status effects the
// tick (5 real s) applies and removes, so a load restores them.
//  - Energy hold (Vigil / Hold Fast / Surge): Energy cannot drop below the dose level; held points come back as
//    sleep debt (share per drug) when the last hold ends; sleep pays them back; Lull makes that sleep better.
//  - Nerve: Steady holds Nerve, Serene restores 30 over 1 game h, Zero Point +25 at once, Emberline halves Nerve loss
//    while smoking.
//  - Oxygen (Cyberslop Endurance 1.3.2+): status tags CyberslopOxygen.Cap / .Refill, read by Endurance itself.
//  - Ghostline: status tag CyberslopOffGrid, read by one guard line in Dark Future's DFVehicleSleepSystem.
// Needs Dark Future 3.x, Codeware, TweakXL, Mod Settings (log toggle).
module CyberslopMercStims

import Codeware.Localization.*
import DarkFuture.Needs.*
import DarkFuture.Services.*
import DarkFuture.Conditions.*
import DarkFuture.Addictions.*
import DarkFuture.Settings.DFSettings
@if(ModuleExists("Edgerunning.System"))
import Edgerunning.System.*

public class CyberslopMercStimsSystem extends ScriptableSystem {

  @runtimeProperty("ModSettings.mod", "Cyberslop Merc Stims")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.displayName", "Log to CET gamelog")
  @runtimeProperty("ModSettings.description", "Writes [MercStims] lines (doses, sleep debt, effects ending) to CET gamelog.log.")
  public let debugLog: Bool = true;

  // slot order = Slots() below; m_until[slot] = game-time stamp when it ends, 0 = off
  private persistent let m_until: array<Float>;
  private persistent let m_holdFloor: Float;
  private persistent let m_holdHeld: Float;
  private persistent let m_holdFactor: Float;
  private persistent let m_holdDoses: Int32;
  private persistent let m_kagamiEnergy: Float;
  private persistent let m_lagHours: Float;
  private persistent let m_lastEnergy: Float;
  private persistent let m_lastStamp: Float;
  private persistent let m_nerveFloor: Float;     // Steady
  private persistent let m_sereneLeft: Float;     // Serene: Nerve still to restore
  private persistent let m_lullUntil: Float;      // Lull window (dose + 4 game h), 0 = none
  private persistent let m_lullDrowsyAt: Float;   // drowsy from here if no sleep yet
  private persistent let m_lastNerve: Float;
  private persistent let m_lastHydration: Float;
  private persistent let m_lastNutrition: Float;
  private persistent let m_lastHumanity: Float;
  private persistent let m_anchorAcc: Float;    // Anchor: humanity points building up (1 per game hour)
  private persistent let m_lumenLeft: Float;    // Lumen: humanity still to restore
  private persistent let m_lumenAcc: Float;     // Lumen: restored in chunks of 3

  private let m_gen: Int32;
  private let m_narcoticsDone: Bool;
  private let m_fx: array<TweakDBID>;
  private let m_hours: array<Float>;
  private let m_keys: array<String>;

  public static func Get(gi: GameInstance) -> ref<CyberslopMercStimsSystem> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"CyberslopMercStims.CyberslopMercStimsSystem") as CyberslopMercStimsSystem;
  }

  private func OnAttach() -> Void {
    ModSettings.RegisterListenerToClass(this);
  }

  private func OnDetach() -> Void {
    ModSettings.UnregisterListenerToClass(this);
  }

  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    this.BuildTables();
    while ArraySize(this.m_until) < ArraySize(this.m_fx) {
      ArrayPush(this.m_until, 0.0);
    }
    this.m_lastStamp = 0.0;          // no sleep detection across a load
    this.m_narcoticsDone = false;    // re-check after every load
    this.m_lastNerve = -1.0;
    this.m_lastHydration = -1.0;
    this.m_lastNutrition = -1.0;
    this.m_lastHumanity = -1.0;
    this.StartTick(3.0);
  }

  // slot: status effect suffix, game hours (after-effects and specials set their own)
  private final func BuildTables() -> Void {
    if ArraySize(this.m_fx) > 0 { return; }
    this.Slot("Vigil_Active", 12.0);            // 0
    this.Slot("HoldFast_Active", 6.0);          // 1
    this.Slot("Surge_Active", 4.0);             // 2
    this.Slot("Kagami_Active", 1.5);            // 3
    this.Slot("Kagami_Lag", 1.0);               // 4
    this.Slot("Steady_Active", 4.0);            // 5
    this.Slot("Lull_Drowsy", 3.0);              // 6
    this.Slot("Boost_Active", 2.0);             // 7
    this.Slot("Boost_Migraine", 1.0);           // 8
    this.Slot("Antitox_Active", 1.0);           // 9
    this.Slot("Antitox_Nausea", 0.5);           // 10
    this.Slot("Hardline_Active", 1.0 / 6.0);    // 11
    this.Slot("Hardline_Crash", 0.5);           // 12
    this.Slot("ProteoMax_Active", 6.0);         // 13
    this.Slot("Electra_Active", 3.0);           // 14
    this.Slot("CorpoDaily_Active", 24.0);       // 15
    this.Slot("Ketone_Active", 2.0);            // 16
    this.Slot("ColdBrew_Active", 2.0);          // 17
    this.Slot("NeuroSync_Active", 12.0);        // 18
    this.Slot("OsteoCal_Active", 24.0);         // 19
    this.Slot("BioCoolant_Active", 6.0);        // 20
    this.Slot("Rejectol_Active", 24.0);         // 21
    this.Slot("Serene_Active", 1.0);            // 22
    this.Slot("ZeroPoint_Calm", 1.0 / 3.0);     // 23
    this.Slot("Respirocyte_Active", 6.0);       // 24
    this.Slot("Bronchodilator_Active", 1.0);    // 25
    this.Slot("Rapidetox_Nausea", 0.5);         // 26
    this.Slot("Ghostline_Active", 12.0);        // 27
    this.Slot("Emberline_Active", 24.0);        // 28
    this.Slot("Emberline_Focus", 0.0);          // 29: follows smoking, not timed
    this.Slot("Anchor_Active", 24.0);           // 30
    this.Slot("Tether_Active", 8.0);            // 31
    this.Slot("Lumen_Active", 2.0);             // 32
    this.Slot("CircuitBreaker_Active", 0.25);   // 33
    this.Slot("CircuitBreaker_Sedation", 1.0);  // 34
    this.Slot("KillSwitch_Active", 1.0);        // 35
    this.Slot("KillSwitch_Straitjacket", 2.0);  // 36
  }

  private final func Slot(key: String, hours: Float) -> Void {
    ArrayPush(this.m_keys, key);
    ArrayPush(this.m_fx, TDBID.Create("CyberslopStims." + key));
    ArrayPush(this.m_hours, hours);
  }

  public final func StartTick(delay: Float) -> Void {
    let cb: ref<CyberslopMercStimsTick> = new CyberslopMercStimsTick();
    this.m_gen += 1;
    cb.gi = this.GetGameInstance();
    cb.gen = this.m_gen;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, delay, false);
  }

  public final func GetGen() -> Int32 {
    return this.m_gen;
  }

  // ---------------------------------------------------------------- helpers

  private final func Now() -> Float {
    return GameInstance.GetTimeSystem(this.GetGameInstance()).GetGameTimeStamp();
  }

  private final func Props(visible: Bool) -> DFChangeNeedValueProps {
    let flags: DFNeedChangeUIFlags;
    let props: DFChangeNeedValueProps;
    if visible {
      flags.forceMomentaryUIDisplay = true;
      flags.forceBright = true;
      flags.momentaryDisplayIgnoresSceneTier = true;
    } else {
      flags.instantUIChange = true;
      props.suppressRecoveryNotification = true;
    }
    props.uiFlags = flags;
    return props;
  }

  // -1 when Dark Future is not running (menu, before its init, system off)
  private final func EnergyValue() -> Float {
    let s: ref<DFEnergySystem> = DFEnergySystem.GetInstance(this.GetGameInstance());
    return IsDefined(s) ? s.GetNeedValue() : -1.0;
  }

  private final func NerveValue() -> Float {
    let s: ref<DFNerveSystem> = DFNerveSystem.GetInstance(this.GetGameInstance());
    return IsDefined(s) ? s.GetNeedValue() : -1.0;
  }

  private final func HydrationValue() -> Float {
    let s: ref<DFHydrationSystem> = DFHydrationSystem.GetInstance(this.GetGameInstance());
    return IsDefined(s) ? s.GetNeedValue() : -1.0;
  }

  private final func NutritionValue() -> Float {
    let s: ref<DFNutritionSystem> = DFNutritionSystem.GetInstance(this.GetGameInstance());
    return IsDefined(s) ? s.GetNeedValue() : -1.0;
  }

  private final func ChangeEnergy(amount: Float, visible: Bool) -> Void {
    let s: ref<DFEnergySystem> = DFEnergySystem.GetInstance(this.GetGameInstance());
    if IsDefined(s) && AbsF(amount) >= 0.01 { s.ChangeNeedValue(amount, this.Props(visible)); }
  }

  private final func ChangeNerve(amount: Float, visible: Bool) -> Void {
    let s: ref<DFNerveSystem> = DFNerveSystem.GetInstance(this.GetGameInstance());
    if IsDefined(s) && AbsF(amount) >= 0.01 { s.ChangeNeedValue(amount, this.Props(visible)); }
  }

  private final func ChangeHydration(amount: Float, visible: Bool) -> Void {
    let s: ref<DFHydrationSystem> = DFHydrationSystem.GetInstance(this.GetGameInstance());
    if IsDefined(s) && AbsF(amount) >= 0.01 { s.ChangeNeedValue(amount, this.Props(visible)); }
  }

  private final func ChangeNutrition(amount: Float, visible: Bool) -> Void {
    let s: ref<DFNutritionSystem> = DFNutritionSystem.GetInstance(this.GetGameInstance());
    if IsDefined(s) && AbsF(amount) >= 0.01 { s.ChangeNeedValue(amount, this.Props(visible)); }
  }

  // Dark Future humanity loss as one number: level x 100 + build-up toward the next level
  private final func HumanityLoss() -> Float {
    let s: ref<DFHumanityLossConditionSystem> = DFHumanityLossConditionSystem.GetInstance(this.GetGameInstance());
    if !IsDefined(s) { return -1.0; }
    return Cast<Float>(s.GetConditionLevel()) * 100.0 + s.accumulatedPercentTowardNextLevel;
  }

  private final func Active(slot: Int32, now: Float) -> Bool {
    return this.m_until[slot] > now;
  }

  private final func HoldRunning(now: Float) -> Bool {
    return this.Active(0, now) || this.Active(1, now) || this.Active(2, now);
  }

  private final func Start(player: ref<PlayerPuppet>, slot: Int32, hours: Float, now: Float) -> Void {
    this.m_until[slot] = MaxF(this.m_until[slot], now + hours * 3600.0);
    if !StatusEffectSystem.ObjectHasStatusEffect(player, this.m_fx[slot]) {
      StatusEffectHelper.ApplyStatusEffect(player, this.m_fx[slot]);
    }
  }

  private final func Stop(player: ref<PlayerPuppet>, slot: Int32) -> Void {
    this.m_until[slot] = 0.0;
    StatusEffectHelper.RemoveStatusEffect(player, this.m_fx[slot]);
  }

  // game clock HH:MM after the given number of game hours
  private final func ClockIn(hours: Float) -> String {
    let t: GameTime = GameInstance.GetTimeSystem(this.GetGameInstance()).GetGameTime();
    let total: Int32 = GameTime.Hours(t) * 60 + GameTime.Minutes(t) + Cast<Int32>(hours * 60.0);
    let h: Int32 = (total / 60) % 24;
    let m: Int32 = total % 60;
    let hs: String = h < 10 ? "0" + ToString(h) : ToString(h);
    let ms: String = m < 10 ? "0" + ToString(m) : ToString(m);
    return hs + ":" + ms;
  }

  private final func Log(text: String) -> Void {
    if this.debugLog { FTLog("[MercStims] " + text); }
  }

  private final func Message(text: String) -> Void {
    let msg: SimpleScreenMessage;
    msg.isShown = true;
    msg.isInstant = true;
    msg.duration = 6.0;
    msg.type = SimpleMessageType.Undefined;
    msg.message = text;
    GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_Notifications)
      .SetVariant(GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, ToVariant(msg), true);
  }

  private final func Text(key: String) -> String {
    return GetLocalizedTextByKey(StringToName(key));
  }

  // "<item name>: <use line> HH:MM."
  private final func DoseMessage(id: String, hours: Float) -> Void {
    this.Message(this.Text("CyberslopStims-" + id + "-Name") + ": " + this.Text("CyberslopStims-Msg-" + id) + " " + this.ClockIn(hours) + ".");
  }

  // ---------------------------------------------------------------- dose (from the request queue, game thread)

  private final func OnCyberslopMercStimsDoseRequest(request: ref<CyberslopMercStimsDoseRequest>) -> Void {
    if IsDefined(request) { this.OnDose(request.player, request.item); }
  }

  private final func ItemKey(r: wref<Item_Record>) -> String {
    let keys: array<String> = ["Vigil", "HoldFast", "Surge", "Kagami", "Steady", "Lull", "Boost", "Rapidetox", "Antitox",
      "Hardline", "Serene", "ZeroPoint", "Respirocyte", "Bronchodilator", "Ghostline", "Emberline", "ProteoMax", "Electra",
      "CorpoDaily", "Ketone", "ColdBrew", "NeuroSync", "OsteoCal", "BioCoolant", "Rejectol", "Anchor", "Tether", "Lumen",
      "CircuitBreaker", "KillSwitch"];
    for k in keys {
      if r.TagsContains(StringToName("CyberslopStims." + k)) { return k; }
    }
    return "";   // Crank, Synthcoke, HydraSalt, NutriGel: Dark Future does all of it
  }

  private final func OnDose(player: ref<PlayerPuppet>, item: TweakDBID) -> Void {
    let r: wref<Item_Record> = TweakDBInterface.GetItemRecord(item);
    if !IsDefined(r) || !IsDefined(player) { return; }
    this.BuildTables();
    while ArraySize(this.m_until) < ArraySize(this.m_fx) {
      ArrayPush(this.m_until, 0.0);
    }
    let k: String = this.ItemKey(r);
    let now: Float = this.Now();
    if Equals(k, "") { return; }
    if Equals(k, "Vigil") { this.DoseHold(player, 0, k); }
    else if Equals(k, "HoldFast") { this.DoseHold(player, 1, k); }
    else if Equals(k, "Surge") { this.DoseHold(player, 2, k); }
    else if Equals(k, "Kagami") { this.DoseKagami(player, now); }
    else if Equals(k, "Steady") { this.DoseSteady(player, now); }
    else if Equals(k, "Lull") { this.DoseLull(now); }
    else if Equals(k, "Rapidetox") { this.DoseRapidetox(player, now); }
    else if Equals(k, "Serene") { this.DoseSerene(player, now); }
    else if Equals(k, "ZeroPoint") { this.DoseZeroPoint(player, now); }
    else if Equals(k, "Emberline") { this.DoseEmberline(player, now); }
    else if Equals(k, "Anchor") || Equals(k, "Tether") || Equals(k, "Lumen") || Equals(k, "CircuitBreaker") || Equals(k, "KillSwitch") {
      this.DoseHumanity(player, k, now);
    }
    else {
      let slot: Int32 = ArrayFindFirst(this.m_keys, k + "_Active");
      if slot < 0 { return; }
      this.Start(player, slot, this.m_hours[slot], now);
      this.DoseMessage(k, this.m_hours[slot]);
      this.Log(s"dose \(k): \(this.m_keys[slot]) for \(this.m_hours[slot]) game h");
    }
    this.m_lastEnergy = this.EnergyValue();
    this.m_lastNerve = this.NerveValue();
    this.m_lastStamp = now;
  }

  private final func DoseHold(player: ref<PlayerPuppet>, slot: Int32, k: String) -> Void {
    let now: Float = this.Now();
    let energy: Float = this.EnergyValue();
    if this.HoldRunning(now) {
      this.m_holdDoses += 1;
    } else {
      this.m_holdDoses = 1;
      this.m_holdHeld = 0.0;
      this.m_holdFactor = 0.0;
      this.m_holdFloor = 0.0;
    }
    let boost: Float = (slot == 0 ? 15.0 : (slot == 1 ? 25.0 : 20.0)) * PowF(0.75, Cast<Float>(this.m_holdDoses - 1));
    let added: Float = 0.0;
    if energy >= 0.0 {
      added = MinF(boost, 100.0 - energy);
      this.ChangeEnergy(added, true);
      this.m_holdFloor = MaxF(this.m_holdFloor, energy + added);
    }
    this.m_holdFactor = MaxF(this.m_holdFactor, slot == 0 ? 0.25 : (slot == 1 ? 0.5 : 1.0));
    this.Start(player, slot, this.m_hours[slot], now);
    let line: String = this.Text("CyberslopStims-" + k + "-Name") + ": " + this.Text("CyberslopStims-Msg-Hold") + " " + this.ClockIn(this.m_hours[slot]) + ".";
    if this.m_holdDoses >= 3 { line += " " + this.Text("CyberslopStims-Msg-Stacking"); }
    this.Message(line);
    this.Log(s"dose \(k): energy \(energy) +\(added), floor \(this.m_holdFloor), doses in run \(this.m_holdDoses), debt share \(this.m_holdFactor), held so far \(this.m_holdHeld)");
  }

  private final func DoseKagami(player: ref<PlayerPuppet>, now: Float) -> Void {
    if this.Active(3, now) {
      this.m_until[3] = now + this.m_hours[3] * 3600.0;
      this.m_lagHours = 2.0;
      this.ChangeNerve(-20.0, true);
      this.Message(this.Text("CyberslopStims-Msg-KagamiOverload"));
      this.Log("Kagami re-dosed while active: Nerve -20, Neural Lag doubled");
      return;
    }
    let energy: Float = this.EnergyValue();
    let added: Float = 0.0;
    if energy >= 0.0 {
      added = MinF(20.0, 100.0 - energy);
      this.ChangeEnergy(added, true);
    }
    this.m_kagamiEnergy = added;
    this.m_lagHours = 1.0;
    if this.Active(4, now) { this.Stop(player, 4); }
    this.Start(player, 3, this.m_hours[3], now);
    this.DoseMessage("Kagami", this.m_hours[3]);
    this.Log(s"dose Kagami: energy \(energy) +\(added) temporary");
  }

  private final func DoseSteady(player: ref<PlayerPuppet>, now: Float) -> Void {
    let nerve: Float = this.NerveValue();
    this.m_nerveFloor = MaxF(this.Active(5, now) ? this.m_nerveFloor : 0.0, nerve);
    this.Start(player, 5, this.m_hours[5], now);
    this.DoseMessage("Steady", this.m_hours[5]);
    this.Log(s"dose Steady: Nerve held at \(this.m_nerveFloor)");
  }

  private final func DoseLull(now: Float) -> Void {
    this.m_lullUntil = now + 4.0 * 3600.0;
    this.m_lullDrowsyAt = now + 3600.0;
    this.Message(this.Text("CyberslopStims-Lull-Name") + ": " + this.Text("CyberslopStims-Msg-Lull"));
    this.Log("dose Lull: sleep within 1 game h for the bonus");
  }

  private final func DoseRapidetox(player: ref<PlayerPuppet>, now: Float) -> Void {
    let pss: ref<DFPlayerStateService> = DFPlayerStateService.GetInstance(this.GetGameInstance());
    let energy: Float = 0.0;
    if IsDefined(pss) {
      energy += pss.ClearManagedEffectOfTypeAndReturnEnergyToChange(DFManagedEffectType.Alcohol);
      energy += pss.ClearManagedEffectOfTypeAndReturnEnergyToChange(DFManagedEffectType.Narcotic);
    }
    this.ChangeEnergy(energy, true);
    this.ChangeHydration(-15.0, true);
    this.Start(player, 26, this.m_hours[26], now);
    this.Message(this.Text("CyberslopStims-Rapidetox-Name") + ": " + this.Text("CyberslopStims-Msg-Rapidetox"));
    this.Log(s"dose Rapidetox: alcohol + narcotic stacks cleared, Energy \(energy), Hydration -15");
  }

  private final func DoseSerene(player: ref<PlayerPuppet>, now: Float) -> Void {
    this.m_sereneLeft = 30.0;
    this.Start(player, 22, this.m_hours[22], now);
    this.DoseMessage("Serene", this.m_hours[22]);
    this.Log("dose Serene: +30 Nerve over 1 game h");
  }

  private final func DoseZeroPoint(player: ref<PlayerPuppet>, now: Float) -> Void {
    this.ChangeNerve(25.0, true);
    this.Start(player, 23, this.m_hours[23], now);
    this.DoseMessage("ZeroPoint", this.m_hours[23]);
    this.Log("dose Zero Point: Nerve +25");
  }

  private final func DoseEmberline(player: ref<PlayerPuppet>, now: Float) -> Void {
    this.Start(player, 28, this.m_hours[28], now);
    this.EmberlineUpkeep(player);
    this.DoseMessage("Emberline", this.m_hours[28]);
    this.Log("dose Emberline: nicotine withdrawal and smoking debuff suppressed, smoking = focus");
  }

  // ---------------------------------------------------------------- 1.2.0 humanity (Wannabe Edgerunner)

  private final func DoseHumanity(player: ref<PlayerPuppet>, k: String, now: Float) -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let slot: Int32 = ArrayFindFirst(this.m_keys, k + "_Active");
    let restore: Int32 = 0;
    if slot < 0 { return; }
    if Equals(k, "Anchor") { restore = 10; this.m_anchorAcc = this.Active(30, now) ? this.m_anchorAcc : 0.0; }
    else if Equals(k, "Tether") { restore = 3; }
    else if Equals(k, "Lumen") { this.m_lumenLeft = 15.0; this.m_lumenAcc = 0.0; }
    else if Equals(k, "CircuitBreaker") { restore = 5; }
    else if Equals(k, "KillSwitch") {
      restore = 20;
      this.ChangeEnergy(-30.0, true);
      this.ChangeNerve(-20.0, true);
      if this.Active(33, now) { this.Stop(player, 33); }
    }
    this.Start(player, slot, this.m_hours[slot], now);
    if restore > 0 { MS_WERestore(gi, restore); }
    let line: String = this.Text("CyberslopStims-" + k + "-Name") + ": " + this.Text("CyberslopStims-Msg-" + k) + " " + this.ClockIn(this.m_hours[slot]) + ".";
    let state: String = MS_WEState(gi);
    if StrLen(state) > 0 { line += " " + state; } else { line += " " + this.Text("CyberslopStims-Msg-NoWE"); }
    this.Message(line);
    this.Log(s"dose \(k): \(this.m_keys[slot]) for \(this.m_hours[slot]) game h, humanity +\(restore); \(state)");
  }

  private final func HumanityTick(player: ref<PlayerPuppet>, now: Float, dt: Float) -> Void {
    let gi: GameInstance = this.GetGameInstance();
    let n: Int32;
    if dt <= 0.0 { return; }
    // Anchor: +1 humanity per game hour while it runs
    if this.Active(30, now) {
      this.m_anchorAcc += MinF(dt, 86400.0) / 3600.0;
      if this.m_anchorAcc >= 1.0 {
        n = FloorF(this.m_anchorAcc);
        this.m_anchorAcc -= Cast<Float>(n);
        MS_WERestore(gi, n);
        this.Log(s"Anchor: humanity +\(n)");
      }
    }
    // Lumen: +15 over its 2 hours, paid in chunks of 3
    if this.Active(32, now) && this.m_lumenLeft > 0.0 {
      let add: Float = MinF(this.m_lumenLeft, 15.0 / 7200.0 * MinF(dt, 7200.0));
      this.m_lumenLeft -= add;
      this.m_lumenAcc += add;
      if this.m_lumenAcc >= 3.0 || this.m_lumenLeft <= 0.0 {
        n = FloorF(this.m_lumenAcc + 0.001);
        if n > 0 {
          this.m_lumenAcc -= Cast<Float>(n);
          MS_WERestore(gi, n);
          this.Log(s"Lumen: humanity +\(n), \(this.m_lumenLeft) to come");
        }
      }
    }
  }

  // ---------------------------------------------------------------- tick (5 real seconds)

  public final func Tick() -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) { return; }
    this.BuildTables();
    if ArraySize(this.m_until) < ArraySize(this.m_fx) { return; }
    this.RegisterNarcotics();
    let energy: Float = this.EnergyValue();
    if energy < 0.0 { return; }   // Dark Future not running right now: timers wait
    let now: Float = this.Now();
    let dt: Float = this.m_lastStamp > 0.0 ? now - this.m_lastStamp : 0.0;
    let jump: Bool = dt > 1800.0;

    // sleep / long wait: the clock jumped and Energy rose on its own
    if jump && energy > this.m_lastEnergy + 1.0 {
      let rise: Float = energy - this.m_lastEnergy;
      let lull: Bool = this.m_lullUntil > 0.0 && this.m_lastStamp <= this.m_lullUntil;
      let pay: Float = lull ? rise * 1.5 : rise;
      if this.m_holdHeld > 0.0 {
        let paid: Float = MinF(this.m_holdHeld, pay);
        this.m_holdHeld -= paid;
        this.Log(s"sleep: Energy \(this.m_lastEnergy) -> \(energy), sleep debt -\(paid), left \(this.m_holdHeld)");
      }
      if lull {
        let bonus: Float = MinF(rise * 0.3, 100.0 - energy);
        this.ChangeEnergy(bonus, true);
        this.m_lullUntil = 0.0;
        if this.Active(6, now) || this.m_until[6] > 0.0 { this.Stop(player, 6); }
        this.Message(this.Text("CyberslopStims-Msg-LullSlept"));
        this.Log(s"sleep on Lull: bonus Energy +\(bonus)");
        energy = this.EnergyValue();
      }
    }

    // Energy hold
    if this.HoldRunning(now) {
      if energy < this.m_holdFloor {
        let lift: Float = this.m_holdFloor - energy;
        this.ChangeEnergy(lift, false);
        this.m_holdHeld += lift;
      }
    } else if this.m_holdDoses > 0 {
      this.EndHold(energy);
    }

    let nerve: Float = this.NerveValue();
    // Emberline: while smoking, half of any Nerve loss comes back
    let smoking: Bool = this.Active(28, now) && StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"DarkFutureSmoking");
    if smoking && !jump && this.m_lastNerve >= 0.0 && nerve >= 0.0 && nerve < this.m_lastNerve {
      this.ChangeNerve((this.m_lastNerve - nerve) * 0.5, false);
      nerve = this.NerveValue();
    }
    // Steady: Nerve held
    if this.Active(5, now) && nerve >= 0.0 && nerve < this.m_nerveFloor {
      this.ChangeNerve(this.m_nerveFloor - nerve, false);
    }
    // Serene: +30 Nerve spread over its hour
    if this.Active(22, now) && this.m_sereneLeft > 0.0 && dt > 0.0 {
      let add: Float = MinF(this.m_sereneLeft, 30.0 / 3600.0 * MinF(dt, 3600.0));
      this.m_sereneLeft -= add;
      this.ChangeNerve(add, false);
    }
    // Corpo Daily: 15 % of the Hydration / Nutrition drain comes back
    let hyd: Float = this.HydrationValue();
    let nut: Float = this.NutritionValue();
    if this.Active(15, now) && !jump {
      if this.m_lastHydration >= 0.0 && hyd >= 0.0 && hyd < this.m_lastHydration {
        this.ChangeHydration((this.m_lastHydration - hyd) * 0.15, false);
      }
      if this.m_lastNutrition >= 0.0 && nut >= 0.0 && nut < this.m_lastNutrition {
        this.ChangeNutrition((this.m_lastNutrition - nut) * 0.15, false);
      }
    }
    // Rejectol: 30 % of new Dark Future humanity loss build-up is undone
    let hum: Float = this.HumanityLoss();
    if this.Active(21, now) && this.m_lastHumanity >= 0.0 && hum > this.m_lastHumanity {
      let s: ref<DFHumanityLossConditionSystem> = DFHumanityLossConditionSystem.GetInstance(this.GetGameInstance());
      s.DecrementPercentTowardNextLevel((hum - this.m_lastHumanity) * 0.3);
      s.RefreshConditionStatusEffects();
      hum = this.HumanityLoss();
    }
    // 1.2.0 Anchor / Lumen humanity drip (Wannabe Edgerunner)
    if !jump || dt > 0.0 { this.HumanityTick(player, now, dt); }
    // Emberline upkeep + focus while a cigarette is burning
    if this.Active(28, now) {
      this.EmberlineUpkeep(player);
    }
    let focusOn: Bool = StatusEffectSystem.ObjectHasStatusEffect(player, this.m_fx[29]);
    if smoking && !focusOn {
      StatusEffectHelper.ApplyStatusEffect(player, this.m_fx[29]);
    } else if !smoking && focusOn {
      StatusEffectHelper.RemoveStatusEffect(player, this.m_fx[29]);
    }
    // Lull: no sleep within the hour -> drowsy for the rest of the window
    if this.m_lullUntil > 0.0 {
      if now >= this.m_lullUntil {
        this.m_lullUntil = 0.0;
      } else if now >= this.m_lullDrowsyAt && this.m_until[6] == 0.0 {
        this.m_until[6] = this.m_lullUntil;
        StatusEffectHelper.ApplyStatusEffect(player, this.m_fx[6]);
        this.Message(this.Text("CyberslopStims-Msg-LullDrowsy"));
        this.Log("Lull: no sleep within the hour, drowsy");
      }
    }

    // expiry, after-effects, status effects after a load
    let i: Int32 = 0;
    while i < ArraySize(this.m_fx) {
      let id: TweakDBID = this.m_fx[i];
      if i == 29 {
        // Emberline_Focus follows smoking (above), not the clock
      } else if this.m_until[i] > 0.0 && now >= this.m_until[i] {
        this.Stop(player, i);
        this.OnEnded(player, i, now);
      } else if this.m_until[i] > now {
        if !StatusEffectSystem.ObjectHasStatusEffect(player, id) { StatusEffectHelper.ApplyStatusEffect(player, id); }
      } else if StatusEffectSystem.ObjectHasStatusEffect(player, id) {
        StatusEffectHelper.RemoveStatusEffect(player, id);
      }
      i += 1;
    }

    this.m_lastEnergy = this.EnergyValue();
    this.m_lastNerve = this.NerveValue();
    this.m_lastHydration = this.HydrationValue();
    this.m_lastNutrition = this.NutritionValue();
    this.m_lastHumanity = hum;
    this.m_lastStamp = now;
  }

  private final func OnEnded(player: ref<PlayerPuppet>, slot: Int32, now: Float) -> Void {
    if slot == 3 {
      this.EndKagami(player, now);
    } else if slot == 7 {
      this.Start(player, 8, this.m_hours[8], now);
      this.Message(this.Text("CyberslopStims-Msg-BoostEnd"));
    } else if slot == 9 {
      this.ChangeHydration(-5.0, true);
      this.Start(player, 10, this.m_hours[10], now);
    } else if slot == 11 {
      this.ChangeNerve(-15.0, true);
      this.Start(player, 12, this.m_hours[12], now);
      this.Message(this.Text("CyberslopStims-Msg-HardlineEnd"));
    } else if slot == 22 {
      if this.m_sereneLeft > 0.0 { this.ChangeNerve(this.m_sereneLeft, false); }
      this.m_sereneLeft = 0.0;
    } else if slot == 27 {
      this.Message(this.Text("CyberslopStims-Msg-GhostlineEnd"));
    } else if slot == 28 {
      this.Message(this.Text("CyberslopStims-Msg-EmberlineEnd"));
    } else if slot == 30 {
      this.m_anchorAcc = 0.0;
      this.Message(this.Text("CyberslopStims-Msg-AnchorEnd"));
    } else if slot == 32 {
      let rest: Int32 = FloorF(this.m_lumenLeft + this.m_lumenAcc + 0.5);
      if rest > 0 { MS_WERestore(this.GetGameInstance(), rest); }
      this.m_lumenLeft = 0.0;
      this.m_lumenAcc = 0.0;
    } else if slot == 33 {
      this.ChangeNerve(-10.0, true);
      this.Start(player, 34, this.m_hours[34], now);
      this.Message(this.Text("CyberslopStims-Msg-CircuitBreakerEnd"));
    } else if slot == 35 {
      this.Start(player, 36, this.m_hours[36], now);
      this.Message(this.Text("CyberslopStims-Msg-KillSwitchEnd"));
    }
    this.Log(this.m_keys[slot] + " ended");
  }

  // nicotine side effects: withdrawal held at 0 (addiction stage kept), the smoker's debuff removed
  private final func EmberlineUpkeep(player: ref<PlayerPuppet>) -> Void {
    let sys: ref<DFNicotineAddictionSystem> = DFNicotineAddictionSystem.GetInstance(this.GetGameInstance());
    if IsDefined(sys) && (sys.GetWithdrawalLevel() > 0 || StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"AddictionWithdrawalNicotine")) {
      StatusEffectHelper.RemoveStatusEffectsWithTag(player, n"AddictionWithdrawalNicotine");
      sys.SetWithdrawalLevel(0);
      sys.SetRemainingWithdrawalDurationInGameTimeSeconds(0.0);
      sys.SetRemainingBackoffDurationInGameTimeSeconds(0.0);
      sys.StartBackoffDuration();
      sys.ReevaluateSystem();
      this.Log("Emberline: nicotine withdrawal suppressed");
    }
    if StatusEffectSystem.ObjectHasStatusEffectWithTag(player, n"DarkFutureSmokingDebuff") {
      StatusEffectHelper.RemoveStatusEffectsWithTag(player, n"DarkFutureSmokingDebuff");
    }
  }

  private final func EndHold(energy: Float) -> Void {
    let mult: Float = MinF(1.0 + 0.25 * Cast<Float>(this.m_holdDoses - 1), 2.0);
    let debt: Float = this.m_holdHeld * this.m_holdFactor * mult;
    let target: Float = MaxF(energy - debt, MinF(energy, 5.0));
    let drop: Float = energy - target;
    if drop > 0.5 {
      this.ChangeEnergy(-drop, true);
      this.Message(this.Text("CyberslopStims-Msg-Debt") + " -" + ToString(Cast<Int32>(drop + 0.5)) + " " + this.Text("CyberslopStims-Msg-Energy"));
    } else {
      this.Message(this.Text("CyberslopStims-Msg-Clean"));
    }
    this.Log(s"hold over: held \(this.m_holdHeld), share \(this.m_holdFactor) x \(mult) (doses \(this.m_holdDoses)) = debt \(debt); Energy \(energy) -> \(energy - drop)");
    this.m_holdDoses = 0;
    this.m_holdHeld = 0.0;
    this.m_holdFactor = 0.0;
    this.m_holdFloor = 0.0;
  }

  private final func EndKagami(player: ref<PlayerPuppet>, now: Float) -> Void {
    let energy: Float = this.EnergyValue();
    let back: Float = 0.0;
    if this.m_kagamiEnergy > 0.0 && energy >= 0.0 {
      back = MinF(this.m_kagamiEnergy, MaxF(energy - 5.0, 0.0));
      if this.HoldRunning(now) {
        back = MinF(back, MaxF(energy - this.m_holdFloor, 0.0));   // a running hold keeps its floor, no fake debt
      }
      this.ChangeEnergy(-back, true);
    }
    this.m_kagamiEnergy = 0.0;
    this.ChangeNerve(-10.0, true);
    let lag: Float = this.m_lagHours > 0.0 ? this.m_lagHours : 1.0;
    this.Start(player, 4, lag, now);
    this.Message(this.Text("CyberslopStims-Msg-KagamiEnd"));
    this.Log(s"Kagami over: temporary Energy -\(back), Nerve -10, Neural Lag \(lag) game h");
  }

  // ---------------------------------------------------------------- Crank + Synthcoke: Dark Future narcotic item definitions

  // One push per definition per load, from the tick only (DelaySystem callback), never from an event: Dark Future
  // reads this array when an item is consumed.
  public final func RegisterNarcotics() -> Void {
    if this.m_narcoticsDone { return; }
    let pss: ref<DFPlayerStateService> = DFPlayerStateService.GetInstance(this.GetGameInstance());
    if !IsDefined(pss) || ArraySize(pss.managedEffectItemDefinitions) == 0 { return; }
    this.m_narcoticsDone = true;
    let nerve: Float = 12.0;
    let settings: ref<DFSettings> = DFSettings.GetInstance(this.GetGameInstance());
    if IsDefined(settings) { nerve = settings.nerveNarcoticsRev2; }
    this.RegisterNarcotic(pss, n"CyberslopStims.CrankDF", 3, 4, 15.0, nerve, t"CyberslopStims.Crank_OnEquip_UIData");
    this.RegisterNarcotic(pss, n"CyberslopStims.SynthcokeDF", 2, 3, 12.0, nerve, t"CyberslopStims.Synthcoke_OnEquip_UIData");
  }

  private final func RegisterNarcotic(pss: ref<DFPlayerStateService>, tag: CName, lo: Int32, hi: Int32, energy: Float, nerve: Float, ui: TweakDBID) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(pss.managedEffectItemDefinitions) {
      if Equals(pss.managedEffectItemDefinitions[i].itemRecordTag, tag) { return; }
      i += 1;
    }
    let excess: DFManagedEffectExcessStackDef;
    excess.excessStackItemActionType = DFManagedEffectExcessStackItemActionType.Narcotic;
    let stacks: DFManagedEffectStackCountDef;
    stacks.mode = DFManagedEffectStackCountMode.Random;
    stacks.countToApply = lo;
    stacks.countToApplyMax = hi;
    let def: DFManagedEffectItemDefinition;
    def.itemRecordTag = tag;
    def.energyChangeWhileActive = energy;
    def.nerveChangeWhenApplied = nerve;
    def.stackCountDef = stacks;
    def.excessStackDef = excess;
    ArrayPush(pss.managedEffectItemDefinitions, def);
    TweakDBManager.SetFlat(ui + t".intValues", [lo, hi, Cast<Int32>(nerve), Cast<Int32>(energy), 3, 3]);
    TweakDBManager.UpdateRecord(ui);
    this.Log(s"\(NameToString(tag)) registered with Dark Future: \(lo)-\(hi) narcotic stacks, +\(energy) temporary Energy, +\(nerve) Nerve each");
  }
}

// ---------------------------------------------------------------- Wannabe Edgerunner bridge (no hard dependency)
@if(ModuleExists("Edgerunning.System"))
func MS_WERestore(gi: GameInstance, n: Int32) -> Bool {
  let s: ref<EdgerunningSystem> = EdgerunningSystem.GetInstance(gi);
  if !IsDefined(s) || n <= 0 { return false; }
  s.RemoveHumanityDamage(n);
  s.InvalidateCurrentState();
  return true;
}
@if(!ModuleExists("Edgerunning.System"))
func MS_WERestore(gi: GameInstance, n: Int32) -> Bool = false

@if(ModuleExists("Edgerunning.System"))
func MS_WEState(gi: GameInstance) -> String {
  let s: ref<EdgerunningSystem> = EdgerunningSystem.GetInstance(gi);
  if !IsDefined(s) || !IsDefined(s.GetPlayer()) { return ""; }
  return "Humanity " + ToString(s.GetHumanityCurrent()) + " / " + ToString(s.GetHumanityTotal()) + " (episodes below " + ToString(s.GetPsychosisThreshold()) + ").";
}
@if(!ModuleExists("Edgerunning.System"))
func MS_WEState(gi: GameInstance) -> String = ""

public class CyberslopMercStimsTick extends DelayCallback {
  public let gi: GameInstance;
  public let gen: Int32;

  public func Call() -> Void {
    let s: ref<CyberslopMercStimsSystem> = CyberslopMercStimsSystem.Get(this.gi);
    if !IsDefined(s) || this.gen != s.GetGen() { return; }
    s.Tick();
    s.StartTick(5.0);
  }
}

// The consume hook only queues this (item hooks can run on job threads in 2.5, see the exe+0x270242 CTDs); the
// system handles it from its own request queue.
public class CyberslopMercStimsDoseRequest extends ScriptableSystemRequest {
  public let player: wref<PlayerPuppet>;
  public let item: TweakDBID;
}

public abstract class CyberslopMercStims {
  public static func Taken(gi: GameInstance, executor: wref<GameObject>, item: TweakDBID, actionID: TweakDBID) -> Void {
    if !IsDefined(executor) || !executor.IsPlayer() { return; }
    let r: wref<Item_Record> = TweakDBInterface.GetItemRecord(item);
    if !IsDefined(r) || !r.TagsContains(n"CyberslopStims.Item") { return; }
    let action: wref<ObjectAction_Record> = TweakDBInterface.GetObjectActionRecord(actionID);
    if !IsDefined(action) { return; }
    let an: CName = action.ActionName();
    if NotEquals(an, n"Consume") && NotEquals(an, n"Eat") && NotEquals(an, n"Drink") { return; }
    let sys: ref<CyberslopMercStimsSystem> = CyberslopMercStimsSystem.Get(gi);
    if !IsDefined(sys) { return; }
    let req: ref<CyberslopMercStimsDoseRequest> = new CyberslopMercStimsDoseRequest();
    req.player = executor as PlayerPuppet;
    req.item = item;
    sys.QueueRequest(req);
  }
}

// Both overloads (they do not call each other); only a successful use counts. Item ID read before the call:
// the last item of a stack is gone afterwards.
@wrapMethod(ItemActionsHelper)
public final static func ProcessItemAction(gi: GameInstance, executor: wref<GameObject>, itemData: wref<gameItemData>, actionID: TweakDBID, fromInventory: Bool) -> Bool {
  let item: TweakDBID = IsDefined(itemData) ? ItemID.GetTDBID(itemData.GetID()) : TDBID.None();
  let used: Bool = wrappedMethod(gi, executor, itemData, actionID, fromInventory);
  if used {
    CyberslopMercStims.Taken(gi, executor, item, actionID);
  }
  return used;
}

@wrapMethod(ItemActionsHelper)
public final static func ProcessItemAction(gi: GameInstance, executor: wref<GameObject>, itemData: wref<gameItemData>, actionID: TweakDBID, fromInventory: Bool, quantity: Int32) -> Bool {
  let item: TweakDBID = IsDefined(itemData) ? ItemID.GetTDBID(itemData.GetID()) : TDBID.None();
  let used: Bool = wrappedMethod(gi, executor, itemData, actionID, fromInventory, quantity);
  if used {
    CyberslopMercStims.Taken(gi, executor, item, actionID);
  }
  return used;
}
