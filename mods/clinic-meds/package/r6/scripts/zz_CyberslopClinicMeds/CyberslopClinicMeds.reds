// Cyberslop Clinic Meds 1.0.0 (2026-11-25, patch 2.5) - replaces Cyberslop NeuroMend 1.0.0
// Seven clinic-grade cures sold at medic stores (records in r6\tweaks\zz_CyberslopClinicMeds):
//   NeuroMend   concussion (Injuries head)                       HemoSeal    bleeding (Injuries torso)
//   OsteoWeld   fractures (Injuries arms + legs)                 ReGen-9     every Injuries injury + Dark Future Injury
//   Quell       ends current DF withdrawal, cravings come back   Clean Slate cures every DF addiction
//   ChelaTox    vanilla poison
// The timed after-effects are TweakDB status effects applied by the item itself.
// Needs Injuries 1.7.6, Dark Future, Codeware (texts), TweakXL.
module CyberslopClinicMeds

import Codeware.Localization.*
import Injuries.*
import DarkFuture.Addictions.*
import DarkFuture.Conditions.*

public class CyberslopClinicMeds {

  public static func OnItemAction(player: ref<PlayerPuppet>, itemData: wref<gameItemData>, actionID: TweakDBID) -> Void {
    if !IsDefined(player) || !IsDefined(itemData) { return; }
    let item: TweakDBID = itemData.GetID().GetTDBID();
    let itemRecord: wref<Item_Record> = TweakDBInterface.GetItemRecord(item);
    if !IsDefined(itemRecord) || !itemRecord.TagsContains(n"CyberslopMeds.Item") { return; }
    let actionRecord: wref<ObjectAction_Record> = TweakDBInterface.GetObjectActionRecord(actionID);
    if !IsDefined(actionRecord) || !Equals(actionRecord.ActionName(), n"Consume") { return; }
    let delay: ref<DelaySystem> = GameInstance.GetDelaySystem(player.GetGame());
    if !IsDefined(delay) { return; }
    let cb: ref<CyberslopClinicMedsCB> = new CyberslopClinicMedsCB();
    cb.m_player = player;
    cb.m_item = item;
    delay.DelayCallback(cb, 0.0, false);
  }

  public static func Apply(player: ref<PlayerPuppet>, item: TweakDBID) -> Void {
    if !IsDefined(player) { return; }
    let r: wref<Item_Record> = TweakDBInterface.GetItemRecord(item);
    if !IsDefined(r) { return; }
    let key: String;
    if r.TagsContains(n"CyberslopNeuroMend.Ampoule") {
      key = CyberslopClinicMeds.ClearInjuries(player, 0, 0, "NeuroMend");
    } else if r.TagsContains(n"CyberslopMeds.HemoSeal") {
      key = CyberslopClinicMeds.ClearInjuries(player, 1, 1, "HemoSeal");
    } else if r.TagsContains(n"CyberslopMeds.OsteoWeld") {
      key = CyberslopClinicMeds.ClearInjuries(player, 2, 5, "OsteoWeld");
    } else if r.TagsContains(n"CyberslopMeds.ReGen9") {
      key = CyberslopClinicMeds.ReGen(player);
    } else if r.TagsContains(n"CyberslopMeds.Quell") {
      key = CyberslopClinicMeds.Quell(player);
    } else if r.TagsContains(n"CyberslopMeds.CleanSlate") {
      key = CyberslopClinicMeds.CleanSlate(player);
    } else if r.TagsContains(n"CyberslopMeds.ChelaTox") {
      key = CyberslopClinicMeds.ChelaTox(player);
    } else {
      return;
    }
    CyberslopClinicMeds.Message(player, GetLocalizedTextByKey(StringToName(key)));
  }

  // ---------------------------------------------------------------- Injuries
  // Region map (Injuries_Effects): 0 head = concussion, 1 torso = bleeding, 2-3 arms = broken arm, 4-5 legs = limp.

  private static func ClearInjuries(player: ref<PlayerPuppet>, first: Int32, last: Int32, name: String) -> String {
    let system: ref<InjuriesSystem> = InjuriesSystem.Get(player.GetGame());
    if !IsDefined(system) || !system.IsLive() {
      FTLog(s"[ClinicMeds] \(name): Injuries system not live, nothing done");
      return "CyberslopMeds-" + name + "-Nothing";
    }
    // the matching Injuries masking item has nothing left to mask: end it with the injury
    if first == 0 {
      system.SetSuppression(InjuriesInjuryKind.Concussion(), 0);
      system.SetConcussionPillExpire(0.0);
      StatusEffectHelper.RemoveStatusEffect(player, t"Injuries.CounterEffect_ConcussionPill");
    } else if first == 1 {
      system.SetSuppression(InjuriesInjuryKind.Bleeding(), 0);
      system.SetMedKitExpire(0.0);
      StatusEffectHelper.RemoveStatusEffect(player, t"Injuries.CounterEffect_MedKit");
    } else {
      system.SetSuppression(InjuriesInjuryKind.Limp(), 0);
      system.SetSuppression(InjuriesInjuryKind.BrokenArm(), 0);
      system.SetPainkillerExpire(0.0);
      system.SetPainkillerBounceQueued(false);   // no flare-up: the bones it would flare are fixed
      StatusEffectHelper.RemoveStatusEffect(player, t"Injuries.CounterEffect_Painkiller");
    }
    let found: Int32 = 0;
    let i: Int32 = first;
    while i <= last {
      let tier: Int32 = system.GetSeverity(i);
      if tier > 0 {
        found = Max(found, tier);
        system.SetSeverity(i, 0);   // Injuries recomputes its own status effects, sound and TFP bridge
      }
      i += 1;
    }
    if first == 1 { system.StopBleedTick(); }
    InjuriesEffects.RecomputeAndApply(player, system);
    FTLog(s"[ClinicMeds] \(name) used: regions \(first)-\(last), worst tier \(found) -> 0");
    if found > 0 { return "CyberslopMeds-" + name + "-Done"; }
    return "CyberslopMeds-" + name + "-Nothing";
  }

  private static func ReGen(player: ref<PlayerPuppet>) -> String {
    let worst: Int32 = 0;
    let system: ref<InjuriesSystem> = InjuriesSystem.Get(player.GetGame());
    if IsDefined(system) && system.IsLive() {
      let i: Int32 = 0;
      while i < 6 {
        worst = Max(worst, system.GetSeverity(i));
        i += 1;
      }
      system.ClearAll();   // severities, bleed tick, every masking item and its buff
    }
    let dfLevel: Uint32 = 0u;
    let df: ref<DFInjuryConditionSystem> = DFInjuryConditionSystem.GetInstance(player.GetGame());
    if IsDefined(df) {
      dfLevel = df.GetConditionLevel();
      df.SetConditionLevel(0u);
      df.RestoreCondition(100.0, true);   // level 0: zeroes the build-up and refreshes the status effects
    }
    FTLog(s"[ClinicMeds] ReGen-9 used: Injuries worst tier \(worst) -> 0, Dark Future Injury level \(dfLevel) -> \(IsDefined(df) ? df.GetConditionLevel() : 0u)");
    if worst > 0 || dfLevel > 0u { return "CyberslopMeds-ReGen9-Done"; }
    return "CyberslopMeds-ReGen9-Nothing";
  }

  // ---------------------------------------------------------------- Dark Future addictions

  private static func Quell(player: ref<PlayerPuppet>) -> String {
    let gi: GameInstance = player.GetGame();
    let n: Int32 = 0;
    n += CyberslopClinicMeds.EndWithdrawal(player, DFNicotineAddictionSystem.GetInstance(gi), n"AddictionWithdrawalNicotine", "nicotine");
    n += CyberslopClinicMeds.EndWithdrawal(player, DFAlcoholAddictionSystem.GetInstance(gi), n"AddictionWithdrawalAlcohol", "alcohol");
    n += CyberslopClinicMeds.EndWithdrawal(player, DFNarcoticAddictionSystem.GetInstance(gi), n"AddictionWithdrawalNarcotic", "narcotic");
    if n > 0 { return "CyberslopMeds-Quell-Done"; }
    return "CyberslopMeds-Quell-Nothing";
  }

  // Same steps Dark Future takes when the substance itself is used, minus the addiction roll, then the
  // back-off timer restarts: the craving comes back on the normal schedule unless V stays clean.
  private static func EndWithdrawal(player: ref<PlayerPuppet>, sys: ref<DFAddictionSystemBase>, tag: CName, name: String) -> Int32 {
    if !IsDefined(sys) { return 0; }
    let level: Int32 = sys.GetWithdrawalLevel();
    let hadEffect: Bool = StatusEffectSystem.ObjectHasStatusEffectWithTag(player, tag);
    if level <= 0 && !hadEffect { return 0; }
    if hadEffect { StatusEffectHelper.RemoveStatusEffectsWithTag(player, tag); }
    sys.SetWithdrawalLevel(0);
    sys.SetRemainingWithdrawalDurationInGameTimeSeconds(0.0);
    sys.SetRemainingBackoffDurationInGameTimeSeconds(0.0);
    sys.StartBackoffDuration();
    sys.ReevaluateSystem();
    FTLog(s"[ClinicMeds] Quell: \(name) withdrawal \(level) -> \(sys.GetWithdrawalLevel()), stage \(sys.GetAddictionStage()) kept");
    return 1;
  }

  private static func CleanSlate(player: ref<PlayerPuppet>) -> String {
    let gi: GameInstance = player.GetGame();
    let n: Int32 = 0;
    n += CyberslopClinicMeds.Cure(DFNicotineAddictionSystem.GetInstance(gi), "nicotine");
    n += CyberslopClinicMeds.Cure(DFAlcoholAddictionSystem.GetInstance(gi), "alcohol");
    n += CyberslopClinicMeds.Cure(DFNarcoticAddictionSystem.GetInstance(gi), "narcotic");
    if n > 0 { return "CyberslopMeds-CleanSlate-Done"; }
    return "CyberslopMeds-CleanSlate-Nothing";
  }

  private static func Cure(sys: ref<DFAddictionSystemBase>, name: String) -> Int32 {
    if !IsDefined(sys) { return 0; }
    let stage: Int32 = sys.GetAddictionStage();
    let amount: Float = sys.GetAddictionAmount();
    let level: Int32 = sys.GetWithdrawalLevel();
    if stage <= 0 && amount <= 0.0 && level <= 0 { return 0; }
    sys.CureAddiction();   // Dark Future's own cure: stage, amount, withdrawal, timers, effects, notification
    sys.ReevaluateSystem();
    FTLog(s"[ClinicMeds] Clean Slate: \(name) stage \(stage) / withdrawal \(level) -> \(sys.GetAddictionStage()) / \(sys.GetWithdrawalLevel())");
    return 1;
  }

  // ---------------------------------------------------------------- vanilla

  private static func ChelaTox(player: ref<PlayerPuppet>) -> String {
    let had: Bool = StatusEffectSystem.ObjectHasStatusEffectOfType(player, gamedataStatusEffectType.Poisoned);
    StatusEffectHelper.RemoveAllStatusEffectsByType(player, gamedataStatusEffectType.Poisoned);
    FTLog(s"[ClinicMeds] ChelaTox used: poisoned \(had)");
    if had { return "CyberslopMeds-ChelaTox-Done"; }
    return "CyberslopMeds-ChelaTox-Nothing";
  }

  private static func Message(player: ref<PlayerPuppet>, text: String) -> Void {
    let msg: SimpleScreenMessage;
    msg.isShown = true;
    msg.isInstant = true;
    msg.duration = 5.0;
    msg.type = SimpleMessageType.Undefined;
    msg.message = text;
    GameInstance.GetBlackboardSystem(player.GetGame()).Get(GetAllBlackboardDefs().UI_Notifications)
      .SetVariant(GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, ToVariant(msg), true);
  }
}

public class CyberslopClinicMedsCB extends DelayCallback {
  public let m_player: wref<PlayerPuppet>;
  public let m_item: TweakDBID;
  public func Call() -> Void {
    CyberslopClinicMeds.Apply(this.m_player, this.m_item);
  }
}

@wrapMethod(ItemActionsHelper)
public final static func ProcessItemAction(gi: GameInstance, executor: wref<GameObject>, itemData: wref<gameItemData>, actionID: TweakDBID, fromInventory: Bool) -> Bool {
  let result: Bool = wrappedMethod(gi, executor, itemData, actionID, fromInventory);
  if result {
    CyberslopClinicMeds.OnItemAction(executor as PlayerPuppet, itemData, actionID);
  }
  return result;
}

@wrapMethod(ItemActionsHelper)
public final static func ProcessItemAction(gi: GameInstance, executor: wref<GameObject>, itemData: wref<gameItemData>, actionID: TweakDBID, fromInventory: Bool, quantity: Int32) -> Bool {
  let result: Bool = wrappedMethod(gi, executor, itemData, actionID, fromInventory, quantity);
  if result {
    CyberslopClinicMeds.OnItemAction(executor as PlayerPuppet, itemData, actionID);
  }
  return result;
}

// ---------------------------------------------------------------- texts (Codeware)

public class CyberslopClinicMedsTexts extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    this.Text("CyberslopNeuroMend-Name", "NeuroMend Nanosurgeon Ampoule");
    this.Text("CyberslopNeuroMend-Desc", "Biotechnica clinic-grade nanosurgeons in a single-use cranial injector. They cross the blood-brain barrier, seal sheared axons and leaking micro-vessels and drain the swelling in under a minute: a week of dark-room bed rest, done before the sting fades. Clears a concussion of any grade and ends any Pain Blockers dose.\n\nLicensed-clinic stock, one ampoule per patient. Afterwards the body has to filter out the spent nanites: a mild fever and slower stamina recovery for about ten minutes. Does nothing for broken bones or bleeding.");
    this.Text("CyberslopMeds-NeuroMend-Done", "NeuroMend: cranial repair complete. Head's clear.");
    this.Text("CyberslopMeds-NeuroMend-Nothing", "NeuroMend: no concussion found. The nanites had nothing to fix.");

    this.Text("CyberslopMeds-HemoSeal-Name", "HemoSeal Hemostatic Injector");
    this.Text("CyberslopMeds-HemoSeal-Desc", "Trauma Team-pattern hemostat sold under a Biotechnica license. Expanding chitosan micro-sponges plug the wound channel from the inside while recombinant clotting factor and a plasma expander keep your pressure up. Stops bleeding of any grade at once and replaces a MedKit dressing.\n\nThe blood already on the pavement stays there: about five minutes of reduced stamina while the expander settles. Does nothing for fractures or concussion.");
    this.Text("CyberslopMeds-HemoSeal-Done", "HemoSeal: bleeding stopped. Pressure holding.");
    this.Text("CyberslopMeds-HemoSeal-Nothing", "HemoSeal: no active bleed. The foam had nothing to seal.");

    this.Text("CyberslopMeds-OsteoWeld-Name", "OsteoWeld Bone-Fusion Injector");
    this.Text("CyberslopMeds-OsteoWeld-Desc", "Kang Tao field-surgery nanites carrying calcium-phosphate cement. They align the fragments, lay a mineral scaffold across every break and harden it in about ninety seconds. Mends broken arms and legs of any grade and replaces painkillers, without their flare-up.\n\nThe welds keep curing for a while: roughly fifteen minutes of aching limbs, less stamina and slower recovery. Does nothing for bleeding or concussion.");
    this.Text("CyberslopMeds-OsteoWeld-Done", "OsteoWeld: fractures fused. Give the welds a few minutes.");
    this.Text("CyberslopMeds-OsteoWeld-Nothing", "OsteoWeld: no fractures found. The cement set with nothing to hold.");

    this.Text("CyberslopMeds-ReGen9-Name", "ReGen-9 Full Trauma Cocktail");
    this.Text("CyberslopMeds-ReGen9-Desc", "Biotechnica's top-shelf trauma swarm, the same chemistry Trauma Team Platinum crews push on a flatlining client. Nanosurgeons, clotting factor, bone cement and neural repair in one massive dose: concussion, bleeding and every fracture cleared, and all accumulated injury trauma knitted back together.\n\nExtremely rare outside corporate clinics; one per patient. Clearing a swarm that size costs the body: about twenty minutes of fever, heavy limbs and short breath.");
    this.Text("CyberslopMeds-ReGen9-Done", "ReGen-9: full trauma repair complete. Body's whole again.");
    this.Text("CyberslopMeds-ReGen9-Nothing", "ReGen-9: no injuries found. A very expensive way to run a fever.");

    this.Text("CyberslopMeds-Quell-Name", "Quell Receptor Blocker");
    this.Text("CyberslopMeds-Quell-Desc", "Long-acting receptor blocker and metabolic flush from the city's addiction clinics. Shuts down an active withdrawal from nicotine, alcohol or narcotics within minutes. It does not touch the addiction itself: if you stay hooked, the cravings return on their usual schedule.\n\nBlocked receptors cut both ways: about ten minutes of flat, foggy sluggishness.");
    this.Text("CyberslopMeds-Quell-Done", "Quell: withdrawal shut down. The craving will come back if you stay hooked.");
    this.Text("CyberslopMeds-Quell-Nothing", "Quell: no withdrawal to block.");

    this.Text("CyberslopMeds-CleanSlate-Name", "Clean Slate Rapid Detox Kit");
    this.Text("CyberslopMeds-CleanSlate-Desc", "Clinic rapid-detox protocol in a single kit: a sedative, a receptor reset and an enzyme flush that force weeks of withdrawal through your system in minutes. Cures every nicotine, alcohol and narcotic addiction outright.\n\nWhat you skip in weeks you pay for in one go: about thirty minutes wrung out, shaky and sweating, with much less stamina. Prescribed under supervision; sold over the counter in Night City anyway.");
    this.Text("CyberslopMeds-CleanSlate-Done", "Clean Slate: addictions purged. You feel like hell, and clean.");
    this.Text("CyberslopMeds-CleanSlate-Nothing", "Clean Slate: no addiction found. The detox ran for nothing.");

    this.Text("CyberslopMeds-ChelaTox-Name", "ChelaTox Antidote Autoinjector");
    this.Text("CyberslopMeds-ChelaTox-Desc", "Militech field-issue antidote: a broad-spectrum chelating agent and toxin binder in a spring-loaded autoinjector. Neutralizes poisons and chemical agents in seconds.\n\nThe agent needs a couple of minutes to bind the rest: mild nausea and slower stamina recovery.");
    this.Text("CyberslopMeds-ChelaTox-Done", "ChelaTox: toxin neutralized.");
    this.Text("CyberslopMeds-ChelaTox-Nothing", "ChelaTox: no poison in your system.");
  }
}

public class CyberslopClinicMedsLocalization extends ModLocalizationProvider {
  public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
    return new CyberslopClinicMedsTexts();
  }
  public func GetFallback() -> CName {
    return n"en-us";
  }
}
