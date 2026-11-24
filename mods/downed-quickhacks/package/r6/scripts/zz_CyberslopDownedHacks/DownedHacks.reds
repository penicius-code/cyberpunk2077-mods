// DownedHacks.reds 1.0.1 (2026-11-02: the debug-only HUD register trace and the status effect report after a quickhack
// now do nothing unless the Log setting is on)
// Downed Quickhacks (DownedHacks.reds), first version 2026-10-29. Built for game 2.31.
// Quickhacks on NPCs that are down, plus the few that make sense on a corpse:
//  - Defeated (down but alive): Ping, Contagion, Short Circuit, Synapse Burnout, Overheat, Detonate Grenade,
//    System Reset and Blackwall Gateway. The damage quickhacks finish them off, System Reset knocks them out.
//  - Unconscious: the same without System Reset (they are out already).
//  - Dead: Ping (reaches the squad through the body's cyberware), Contagion (the body is the source, it spreads to the
//    living only) and Detonate Grenade (a booby-trapped corpse, once per body).
// Every other quickhack shows locked on them: Weapon Glitch, Cripple Movement, Reboot Optics, Cyberware Malfunction,
// Cyberpsychosis, Suicide, Memory Wipe, Sonic Shock, Request Backup, Distract, Breach and other mods' quickhacks.
// Breach on unconscious NPCs is Better Netrunning's own option (breach unconscious NPCs, on by default).
// Never on bosses, Immortal / Invulnerable NPCs or a fist fight opponent (FistFight, DefeatedWithRecover).
// The game's own checks stay: hostile or aggressive targets only, network breach / exposure, Better Netrunning's
// range and permissions, RAM, cooldowns, a grenade in the NPC's kit, scenes, cyberdeck.
// Quickhacks that finish on a corpse give no Intelligence XP (the game's per-target XP cap never works, so pinging bodies
// would farm it). Quickhacks on downed NPCs give XP as usual.
// The mod's Mod Settings page is optional; without it the defaults below apply.
// Install: drop the zz_CyberslopDownedHacks folder into r6/scripts/. The zz_ keeps it after the other netrunning mods.
//
// How it works:
//  - Every vanilla gate is ScriptedPuppet.IsActive (false when defeated, unconscious or dead). The wraps of
//    IsQuickHackAble and ShouldRegisterToHUD let the wheel open on eligible bodies with the vanilla checks minus that.
//  - The quickhack list is filtered in TranslateChoicesIntoQuickSlotCommands, after every GetAllChoices wrap (Better
//    Netrunning switches every quickhack it permits back on there), so the wrap order does not matter.
//  - No quickhack queueing on a body: the game only runs a queued quickhack while the target is active, so the second one would
//    be paid for and lost. The wheel shows "upload in progress" until the first one is done.
//  - Ping: a downed or dead NPC has left its combat squad, so the vanilla effector finds nobody. On completion the
//    quickhack's own Ping status effect goes to one living member of the NPC's current or recent squad, which marks the
//    rest the vanilla way (same level and duration). The network part of Ping (devices) works without this.
//  - Detonate Grenade is an AI behaviour (the NPC pulls its own grenade), which a body on the ground cannot run. On a
//    body the grenade beeps and goes off at its chest after the fuse: the medium explosion attack (barrel strength,
//    6 m, also hurts V up close), the frag grenade's own effect, the explosion sound and physics impulse. A downed NPC
//    who somehow survives the blast is killed by it 0.5 s later.
//  - Contagion: vanilla. Its spread is an effector the quickhack fires itself and only jumps to active NPCs.

enum DownedHacksState {
  None = 0,
  Defeated = 1,
  Unconscious = 2,
  Dead = 3
}

public class DownedHacksSettings extends ScriptableSystem {

  @runtimeProperty("ModSettings.mod", "Downed Hacks")
  @runtimeProperty("ModSettings.category", "Targets")
  @runtimeProperty("ModSettings.category.order", "0")
  @runtimeProperty("ModSettings.displayName", "Defeated NPCs")
  @runtimeProperty("ModSettings.description", "Quickhacks on NPCs that are down but alive: Ping, Contagion, Short Circuit, Synapse Burnout, Overheat, Detonate Grenade, System Reset and Blackwall Gateway. The damage hacks finish them off. Never on bosses or a fist fight opponent.")
  public let defeated: Bool = true;

  @runtimeProperty("ModSettings.mod", "Downed Hacks")
  @runtimeProperty("ModSettings.category", "Targets")
  @runtimeProperty("ModSettings.category.order", "0")
  @runtimeProperty("ModSettings.displayName", "Unconscious NPCs")
  @runtimeProperty("ModSettings.description", "The same hacks on knocked out NPCs, without System Reset (they are out already). Breach on unconscious NPCs is Better Netrunning's own option.")
  public let unconscious: Bool = true;

  @runtimeProperty("ModSettings.mod", "Downed Hacks")
  @runtimeProperty("ModSettings.category", "Targets")
  @runtimeProperty("ModSettings.category.order", "0")
  @runtimeProperty("ModSettings.displayName", "Corpses")
  @runtimeProperty("ModSettings.description", "Ping (reaches the dead NPC's squad through the body's cyberware), Contagion (the body is the source, it spreads to the living only) and Detonate Grenade (a booby-trapped corpse, once per body) on dead NPCs. No Intelligence XP from hacks on corpses.")
  public let corpses: Bool = true;

  @runtimeProperty("ModSettings.mod", "Downed Hacks")
  @runtimeProperty("ModSettings.category", "Hacks")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Blackwall Gateway on downed NPCs")
  @runtimeProperty("ModSettings.description", "Allows the Blackwall Gateway ultimate on defeated and unconscious NPCs.")
  public let blackwall: Bool = true;

  @runtimeProperty("ModSettings.mod", "Downed Hacks")
  @runtimeProperty("ModSettings.category", "Hacks")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Grenade fuse on a body (s)")
  @runtimeProperty("ModSettings.description", "Detonate Grenade on a downed NPC or a corpse: seconds from the end of the upload to the blast. The grenade beeps meanwhile. Slowed by Sandevistan and Kerenzikov like a real fuse.")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "3.0")
  @runtimeProperty("ModSettings.step", "0.1")
  public let grenadeFuse: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Downed Hacks")
  @runtimeProperty("ModSettings.category", "Debug")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.displayName", "Log")
  @runtimeProperty("ModSettings.description", "[DownedHacks] lines in the game log: every hack that finishes on a downed NPC or a corpse, the status effects on the body half a second later, the Ping and grenade steps. On for the first test, then switch it off.")
  public let debugLog: Bool = true;

  public static func Get(gi: GameInstance) -> ref<DownedHacksSettings> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"DownedHacksSettings") as DownedHacksSettings;
  }

  public static func StateOn(settings: ref<DownedHacksSettings>, state: DownedHacksState) -> Bool {
    switch state {
      case DownedHacksState.Defeated:
        return !IsDefined(settings) || settings.defeated;
      case DownedHacksState.Unconscious:
        return !IsDefined(settings) || settings.unconscious;
      case DownedHacksState.Dead:
        return !IsDefined(settings) || settings.corpses;
    };
    return false;
  }

  @if(ModuleExists("ModSettingsModule"))
  private func OnAttach() -> Void {
    ModSettings.RegisterListenerToClass(this);
  }

  @if(ModuleExists("ModSettingsModule"))
  private func OnDetach() -> Void {
    ModSettings.UnregisterListenerToClass(this);
  }
}

public abstract class DownedHacks extends IScriptable {

  public static func Log(gi: GameInstance, text: String) -> Void {
    if DownedHacks.Logging(gi) {
      FTLog("[DownedHacks] " + text);
    };
  }

  public static func Logging(gi: GameInstance) -> Bool {
    let settings: ref<DownedHacksSettings> = DownedHacksSettings.Get(gi);
    return !IsDefined(settings) || settings.debugLog;
  }

  public static func StateName(state: DownedHacksState) -> String {
    switch state {
      case DownedHacksState.Defeated:
        return "defeated";
      case DownedHacksState.Unconscious:
        return "unconscious";
      case DownedHacksState.Dead:
        return "dead";
    };
    return "active";
  }

  // Action name without the Boss / Chimera prefix of the boss variants (bosses are excluded anyway)
  public static func BaseName(record: wref<ObjectAction_Record>) -> CName {
    let name: String;
    if !IsDefined(record) {
      return n"None";
    };
    name = NameToString(record.ActionName());
    if StrBeginsWith(name, "Boss") {
      name = StrRight(name, StrLen(name) - 4);
    } else {
      if StrBeginsWith(name, "Chimera") {
        name = StrRight(name, StrLen(name) - 7);
      };
    };
    return StringToName(name);
  }

  public static func IsAllowed(name: CName, state: DownedHacksState, settings: ref<DownedHacksSettings>) -> Bool {
    let downed: Bool = Equals(state, DownedHacksState.Defeated) || Equals(state, DownedHacksState.Unconscious);
    switch name {
      case n"Ping":
      case n"Contagion":
      case n"Grenade":
        return true;
      case n"Overload":
      case n"BrainMelt":
      case n"Overheat":
        return downed;
      case n"SystemCollapse":
        return Equals(state, DownedHacksState.Defeated);
      case n"BlackWall":
        return downed && (!IsDefined(settings) || settings.blackwall);
    };
    return false;
  }

  public static func OnHackCompleted(action: ref<PuppetAction>, gi: GameInstance) -> Void {
    let body: ref<ScriptedPuppet> = GameInstance.FindEntityByID(gi, action.GetRequesterID()) as ScriptedPuppet;
    let player: ref<PlayerPuppet> = action.GetExecutor() as PlayerPuppet;
    let record: wref<ObjectAction_Record> = action.GetObjectActionRecord();
    let state: DownedHacksState;
    let name: CName;
    let report: ref<DownedHacksReportCallback>;
    if !IsDefined(body) || !IsDefined(player) || !IsDefined(record) {
      return;
    };
    state = body.DownedHacks_State();
    if Equals(state, DownedHacksState.None) || !DownedHacksSettings.StateOn(DownedHacksSettings.Get(gi), state) {
      return;
    };
    name = DownedHacks.BaseName(record);
    DownedHacks.Log(gi, NameToString(name) + " (" + TDBID.ToStringDEBUG(record.GetID()) + ") finished on " + DownedHacks.StateName(state) + " " + body.GetDisplayName());
    switch name {
      case n"Ping":
        DownedHacks.PingSquad(body, player, record);
        break;
      case n"Grenade":
        DownedHacks.ArmGrenade(body, player);
        break;
    };
    if DownedHacks.Logging(gi) {
      report = new DownedHacksReportCallback();
      report.m_body = body;
      report.m_hack = NameToString(name);
      GameInstance.GetDelaySystem(gi).DelayCallback(report, 0.5, false);
    };
  }

  // The status effect the Ping quickhack puts on its target (Ping, PingLevel2 ... PingLevel4PlusPlus)
  public static func PingStatusEffect(record: wref<ObjectAction_Record>) -> TweakDBID {
    let effects: array<wref<ObjectActionEffect_Record>>;
    let effect: wref<StatusEffect_Record>;
    let i: Int32 = 0;
    record.CompletionEffects(effects);
    while i < ArraySize(effects) {
      effect = effects[i].StatusEffect();
      if IsDefined(effect) && ArrayContains(effect.GameplayTags(), n"Ping") {
        return effect.GetID();
      };
      i += 1;
    };
    return TDBID.None();
  }

  public static func PingSquad(body: ref<ScriptedPuppet>, player: ref<PlayerPuppet>, record: wref<ObjectAction_Record>) -> Void {
    let gi: GameInstance = body.GetGame();
    let squadMember: ref<SquadMemberBaseComponent> = body.GetSquadMemberComponent();
    let squad: ref<SquadScriptInterface>;
    let networkSystem: ref<NetworkSystem>;
    let members: array<wref<Entity>>;
    let member: ref<ScriptedPuppet>;
    let pingEffect: TweakDBID;
    let i: Int32;
    if !IsDefined(squadMember) {
      DownedHacks.Log(gi, "Ping: no squad component");
      return;
    };
    squad = squadMember.MySquad(AISquadType.Combat);
    if !IsDefined(squad) {
      squad = squadMember.FindSquad(squadMember.MySquadNameCurrentOrRecent(AISquadType.Combat));
    };
    if !IsDefined(squad) {
      DownedHacks.Log(gi, "Ping: no current or recent squad, network ping only");
      return;
    };
    networkSystem = GameInstance.GetScriptableSystemsContainer(gi).Get(n"NetworkSystem") as NetworkSystem;
    if IsDefined(networkSystem) && networkSystem.IsSquadMarkedWithPing(squad.GetName()) {
      DownedHacks.Log(gi, "Ping: squad " + NameToString(squad.GetName()) + " is already pinged");
      return;
    };
    pingEffect = DownedHacks.PingStatusEffect(record);
    if !TDBID.IsValid(pingEffect) {
      DownedHacks.Log(gi, "Ping: no Ping status effect on the quickhack record");
      return;
    };
    members = squad.ListMembersWeak();
    i = 0;
    while i < ArraySize(members) {
      member = members[i] as ScriptedPuppet;
      if IsDefined(member) && member != body && ScriptedPuppet.IsActive(member) {
        StatusEffectHelper.ApplyStatusEffect(member, pingEffect, player.GetEntityID());
        DownedHacks.Log(gi, "Ping: squad " + NameToString(squad.GetName()) + " (" + ToString(ArraySize(members)) + " members) pinged through " + member.GetDisplayName());
        return;
      };
      i += 1;
    };
    DownedHacks.Log(gi, "Ping: squad " + NameToString(squad.GetName()) + " has no living member left");
  }

  public static func ArmGrenade(body: ref<ScriptedPuppet>, player: ref<PlayerPuppet>) -> Void {
    let gi: GameInstance = body.GetGame();
    let settings: ref<DownedHacksSettings> = DownedHacksSettings.Get(gi);
    let fuse: Float = IsDefined(settings) ? settings.grenadeFuse : 1.0;
    let callback: ref<DownedHacksGrenadeCallback> = new DownedHacksGrenadeCallback();
    body.m_downedHacksGrenadeUsed = true;
    callback.m_body = body;
    callback.m_player = player;
    GameObject.PlaySound(body, n"grenade_charge_1s");
    DownedHacks.Log(gi, "Grenade: armed, " + FloatToStringPrec(fuse, 1) + " s fuse");
    if fuse <= 0.00 {
      callback.Call();
      return;
    };
    GameInstance.GetDelaySystem(gi).DelayCallback(callback, fuse, true);
  }

  public static func Detonate(body: wref<ScriptedPuppet>, player: wref<PlayerPuppet>) -> Void {
    let gi: GameInstance;
    let position: Vector4;
    let flag: SHitFlag;
    let hitFlags: array<SHitFlag>;
    let attack: ref<Attack_GameEffect>;
    let impulseRadius: Float;
    let finish: ref<DownedHacksFinishCallback>;
    if !IsDefined(body) || !IsDefined(player) {
      return;
    };
    gi = body.GetGame();
    position = body.DownedHacks_BlastPosition();
    // a defeated NPC's own grenade behaviour must not fire a second blast
    StatusEffectHelper.RemoveStatusEffectsWithTag(body, n"SuicideWithGrenade");
    flag.source = n"DownedHacks";
    flag.flag = hitFlag.CanDamageSelf;
    ArrayPush(hitFlags, flag);
    flag.flag = hitFlag.GrenadeQuickhackExplosion;
    ArrayPush(hitFlags, flag);
    attack = RPGManager.PrepareGameEffectAttack(gi, player, player, t"Attacks.Explosion", position, hitFlags);
    if IsDefined(attack) {
      attack.StartAttack();
    };
    impulseRadius = TDB.GetFloat(t"weapons.E3_grenade.physicalImpulseRadius");
    CombatGadgetHelper.SpawnPhysicalImpulse(body, impulseRadius > 0.00 ? impulseRadius : 4.00);
    DownedHacks.SpawnBlastEffect(gi, position, player.GetWorldForward());
    GameObject.PlayMetadataEvent(body, n"exploded");
    GameInstance.GetAudioSystem(gi).PlayShockwave(n"explosion", position);
    DownedHacks.Log(gi, "Grenade: detonated on " + body.GetDisplayName() + (IsDefined(attack) ? "" : " (no attack record!)"));
    if !body.GetPuppetPS().GetIsDead() {
      finish = new DownedHacksFinishCallback();
      finish.m_body = body;
      finish.m_player = player;
      GameInstance.GetDelaySystem(gi).DelayCallback(finish, 0.5, true);
    };
  }

  public static func SpawnBlastEffect(gi: GameInstance, position: Vector4, forward: Vector4) -> Void {
    let fxSystem: ref<FxSystem> = GameInstance.GetFxSystem(gi);
    let effectRef: ResourceAsyncRef;
    let effect: FxResource;
    let worldPosition: WorldPosition;
    let transform: WorldTransform;
    if !IsDefined(fxSystem) {
      return;
    };
    effectRef = new ResourceAsyncRef();
    ResourceAsyncRef.SetPath(effectRef, r"base\\fx\\weapons\\explosives\\frag_grenade\\w_explosives_001__frag_grenade_01.effect");
    effect.effect = effectRef;
    WorldPosition.SetVector4(worldPosition, position);
    WorldTransform.SetWorldPosition(transform, worldPosition);
    WorldTransform.SetOrientationFromDir(transform, forward);
    fxSystem.SpawnEffect(effect, transform);
  }
}

public class DownedHacksGrenadeCallback extends DelayCallback {

  public let m_body: wref<ScriptedPuppet>;

  public let m_player: wref<PlayerPuppet>;

  public func Call() -> Void {
    DownedHacks.Detonate(this.m_body, this.m_player);
  }
}

public class DownedHacksFinishCallback extends DelayCallback {

  public let m_body: wref<ScriptedPuppet>;

  public let m_player: wref<PlayerPuppet>;

  public func Call() -> Void {
    let npc: ref<NPCPuppet> = this.m_body as NPCPuppet;
    if IsDefined(npc) && !npc.GetPuppetPS().GetIsDead() {
      DownedHacks.Log(npc.GetGame(), "Grenade: " + npc.GetDisplayName() + " survived the blast, killed");
      npc.Kill(this.m_player);
    };
  }
}

// Debug: which status effects the body carries half a second after a quickhack finished on it
public class DownedHacksReportCallback extends DelayCallback {

  public let m_body: wref<ScriptedPuppet>;

  public let m_hack: String;

  public func Call() -> Void {
    let effects: array<ref<StatusEffect>>;
    let names: String;
    let i: Int32 = 0;
    if !IsDefined(this.m_body) {
      return;
    };
    GameInstance.GetStatusEffectSystem(this.m_body.GetGame()).GetAppliedEffects(this.m_body.GetEntityID(), effects);
    while i < ArraySize(effects) {
      names = names + (i > 0 ? ", " : "") + TDBID.ToStringDEBUG(effects[i].GetRecord().GetID());
      i += 1;
    };
    DownedHacks.Log(this.m_body.GetGame(), this.m_hack + ": body now " + DownedHacks.StateName(this.m_body.DownedHacks_State()) + ", " + ToString(ArraySize(effects)) + " status effects: " + names);
  }
}

@addField(ScriptedPuppet)
public let m_downedHacksGrenadeUsed: Bool;

@addMethod(ScriptedPuppet)
public final const func DownedHacks_State() -> DownedHacksState {
  let godMode: ref<GodModeSystem>;
  if this.IsPlayer() || this.IsActive() || this.IsBoss() {
    return DownedHacksState.None;
  };
  godMode = GameInstance.GetGodModeSystem(this.GetGame());
  if IsDefined(godMode) && (godMode.HasGodMode(this.GetEntityID(), gameGodModeType.Immortal) || godMode.HasGodMode(this.GetEntityID(), gameGodModeType.Invulnerable)) {
    return DownedHacksState.None;
  };
  // a fist fight opponent: quickhacking them could fail the fight
  if StatusEffectSystem.ObjectHasStatusEffect(this, t"GameplayRestriction.FistFight") || StatusEffectSystem.ObjectHasStatusEffectOfType(this, gamedataStatusEffectType.DefeatedWithRecover) {
    return DownedHacksState.None;
  };
  if this.GetPuppetPS().GetIsDead() {
    return DownedHacksState.Dead;
  };
  if StatusEffectSystem.ObjectHasStatusEffectOfType(this, gamedataStatusEffectType.Defeated) {
    return DownedHacksState.Defeated;
  };
  if ScriptedPuppet.IsUnconscious(this) {
    return DownedHacksState.Unconscious;
  };
  return DownedHacksState.None;
}

// Vanilla IsQuickHackAble without the IsActive check; a downed NPC also counts as aggressive while it is hostile
@addMethod(ScriptedPuppet)
private final const func DownedHacks_CanOpenWheel() -> Bool {
  let actionRecords: array<wref<ObjectAction_Record>>;
  let player: ref<GameObject>;
  let i: Int32;
  let state: DownedHacksState = this.DownedHacks_State();
  if Equals(state, DownedHacksState.None) || !DownedHacksSettings.StateOn(DownedHacksSettings.Get(this.GetGame()), state) {
    return false;
  };
  if this.IsCrowd() && !this.IsPrevention() {
    return false;
  };
  player = GameInstance.GetPlayerSystem(this.GetGame()).GetLocalPlayerControlledGameObject();
  if !this.IsAggressive() && NotEquals(GameObject.GetAttitudeTowards(this, player), EAIAttitude.AIA_Hostile) {
    return false;
  };
  if QuickhackModule.IsQuickhackBlockedByScene(player) {
    return false;
  };
  if this.GetRecord().GetObjectActionsCount() <= 0 {
    return false;
  };
  if !EquipmentSystem.IsCyberdeckEquipped(player) {
    return false;
  };
  this.GetRecord().ObjectActions(actionRecords);
  i = 0;
  while i < ArraySize(actionRecords) {
    if Equals(actionRecords[i].ObjectActionType().Type(), gamedataObjectActionType.PuppetQuickHack) {
      return true;
    };
    i += 1;
  };
  return false;
}

@addMethod(ScriptedPuppet)
public final func DownedHacks_BlastPosition() -> Vector4 {
  let transform: WorldTransform;
  if IsDefined(this.GetSlotComponent()) && this.GetSlotComponent().GetSlotTransform(n"Chest", transform) {
    return WorldPosition.ToVector4(WorldTransform.GetWorldPosition(transform));
  };
  return this.GetWorldPosition();
}

// The quickhack list on an eligible body: the allowed quickhacks get back the vanilla "not active" lock (LocKey#7018) only if
// that lock was the reason, so breach / exposure, range and permission locks of the game and Better Netrunning stay.
// Everything else is locked with 7018, which also undoes Better Netrunning switching every permitted quickhack back on.
// With the target type switched off in Mod Settings every quickhack is locked, as in vanilla.
@addMethod(ScriptedPuppet)
private final func DownedHacks_FilterActions(const puppetActions: script_ref<array<ref<PuppetAction>>>) -> Void {
  let settings: ref<DownedHacksSettings>;
  let state: DownedHacksState = this.DownedHacks_State();
  let stateOn: Bool;
  let questBlock: Bool;
  let isOngoingUpload: Bool;
  let action: ref<PuppetAction>;
  let name: CName;
  let i: Int32;
  if Equals(state, DownedHacksState.None) {
    return;
  };
  settings = DownedHacksSettings.Get(this.GetGame());
  stateOn = DownedHacksSettings.StateOn(settings, state);
  questBlock = this.GetPuppetPS().DownedHacks_QuestBlocksHacks();
  isOngoingUpload = GameInstance.GetStatPoolsSystem(this.GetGame()).IsStatPoolAdded(Cast<StatsObjectID>(this.GetEntityID()), gamedataStatPoolType.QuickHackUpload);
  // an upload left over from before the NPC went down would hold the queue of the next quickhack
  if !isOngoingUpload && IsDefined(this.m_currentlyUploadingAction) && !this.m_currentlyUploadingAction.m_isInactive {
    this.m_currentlyUploadingAction.m_isInactive = true;
  };
  i = 0;
  while i < ArraySize(Deref(puppetActions)) {
    action = Deref(puppetActions)[i];
    if IsDefined(action) {
      name = DownedHacks.BaseName(action.GetObjectActionRecord());
      if stateOn && !questBlock && DownedHacks.IsAllowed(name, state, settings) {
        if action.IsInactive() && Equals(action.GetInactiveReason(), "LocKey#7018") {
          action.SetActive();
        };
        if Equals(name, n"Grenade") && this.m_downedHacksGrenadeUsed {
          action.SetInactiveWithReason(false, "LocKey#7019");
        };
        if isOngoingUpload && !action.IsInactive() {
          action.SetInactiveWithReason(false, "LocKey#7020");
        };
      } else {
        action.SetInactiveWithReason(false, "LocKey#7018");
      };
    };
    i += 1;
  };
}

@addMethod(ScriptedPuppetPS)
public final const func DownedHacks_QuestBlocksHacks() -> Bool {
  return this.Sts_Ep1_12_ActiveForQHack_Hack();
}

@wrapMethod(ScriptedPuppet)
public const func IsQuickHackAble() -> Bool {
  if wrappedMethod() {
    return true;
  };
  return this.DownedHacks_CanOpenWheel();
}

// Independent of the Mod Settings toggles on purpose: a body must stay registered in the HUD manager until it
// despawns once it was registered (OnPreUninitialize unregisters only if this is still true).
@wrapMethod(ScriptedPuppet)
protected const func ShouldRegisterToHUD() -> Bool {
  if wrappedMethod() {
    return true;
  };
  if !IsDefined(this.m_scanningComponent) && !IsDefined(this.m_visionComponent) {
    return false;
  };
  if Equals(this.DownedHacks_State(), DownedHacksState.None) {
    return false;
  };
  return !this.IsCrowd() || this.GetWasAggressiveCrowd();
}

@wrapMethod(ScriptedPuppet)
private func TranslateChoicesIntoQuickSlotCommands(const puppetActions: script_ref<array<ref<PuppetAction>>>, commands: script_ref<array<ref<QuickhackData>>>) -> Void {
  this.DownedHacks_FilterActions(puppetActions);
  wrappedMethod(puppetActions, commands);
}

@wrapMethod(ScriptableDeviceAction)
public func CompleteAction(gameInstance: GameInstance) -> Void {
  // vanilla skips the effects when the target died during the upload
  let targetDied: Bool = this.m_isTargetDead;
  let puppetAction: ref<PuppetAction> = this as PuppetAction;
  wrappedMethod(gameInstance);
  if !targetDied && IsDefined(puppetAction) && this.IsQuickHack() {
    DownedHacks.OnHackCompleted(puppetAction, gameInstance);
  };
}

@wrapMethod(RPGManager)
public final static func AwardExperienceFromQuickhack(player: wref<PlayerPuppet>, cost: Float, target: EntityID, category: gamedataHackCategory) -> Void {
  let body: ref<ScriptedPuppet>;
  if IsDefined(player) && EntityID.IsDefined(target) {
    body = GameInstance.FindEntityByID(player.GetGame(), target) as ScriptedPuppet;
    if IsDefined(body) && Equals(body.DownedHacks_State(), DownedHacksState.Dead) {
      return;
    };
  };
  wrappedMethod(player, cost, target, category);
}

// Debug only: when bodies are registered in / removed from the HUD manager (written to trace a sticking quickhack icon)
@wrapMethod(GameObject)
protected final func RegisterToHUDManager(shouldRegister: Bool) -> Void {
  let puppet: ref<ScriptedPuppet> = this as ScriptedPuppet;
  wrappedMethod(shouldRegister);
  if IsDefined(puppet) && DownedHacks.Logging(this.GetGame()) && NotEquals(puppet.DownedHacks_State(), DownedHacksState.None) {
    DownedHacks.Log(this.GetGame(), "HUD " + (shouldRegister ? "register" : "unregister") + " " + GetLocalizedText(puppet.GetDisplayName()) + " (" + DownedHacks.StateName(puppet.DownedHacks_State()) + ")");
  };
}
