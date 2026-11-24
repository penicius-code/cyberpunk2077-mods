// Cyberslop Thunderclap 1.3.0 (every cast knocks out, 3 arcs 12 m -25 % that can knock out, 16 RAM;
// 1.2.2: street MaxTac squads (rarity Elite in TweakDB) count as MaxTac = stunned,
// and NPCs immune to Unconscious (exo soldiers) are shocked + stunned instead of knocked out; 1.2.1:
// slow-motion switch through a script service, SlowMoSwitch.reds). 1.0.0 to 1.2.0 were built for game 2.31, 1.2.1 and later for 2.5.
// 1.2.0: the slow motion on cast can be switched off in the CET window "Cyberslop Thunderclap" (overlay open). The
//   window writes the TweakDB flat CyberslopThunderclap.Settings.value (1 on / 0 off, YAML default 1 = on).
// 1.1.0: the cast looks like Zeusico Thunderclap 2.04 (31484) again (design goal: "ours feels off, no raised hand"): V raises a
//   hand (the vanilla Blackwall gesture), time slows to 10 % for 0.5 s, and the burst lands 0.3 s after the upload
//   finishes with the EMP explosion visual Zeusico's blast showed. Visual only: no Zeusico record or attack is used,
//   the outcome (health loss, knockout, arcs, guards) is unchanged from 1.0.0.
//   Also (1.0.1): no program grant in the main menu's pre-game session (it logged "program added"
//   on every launch).
//
// A legendary electric burst quickhack that never kills a human. Written from scratch after Zeusico Thunderclap
// (31484) plus Cyberslop Thunderclap Non-Lethal 1.0.0 still killed in testing (seen in a damage probe log):
//   - the thrown target hit the ground at 17.8 m/s, vanilla DamageSystem.ProcessRagdollHit called MarkForDeath and
//     dealt full health (the add-on's Push/Pull mark had not landed);
//   - a bystander knocked out by the EMP blast went Defeated instead of Unconscious (UnconsciousImmunity), and the
//     next 0.1-damage EMP tick killed him: Nonlethal on a hit can't save an NPC once vanilla picks Defeated.
// So this quickhack deals no game damage to humans at all. It applies the vanilla knockout directly (BaseStatusEffect.
// Unconscious, the same call vanilla's non-lethal takedown and trap devices make) and decides everything in script.
//
// On upload (2.0 s, 16 RAM, Short Circuit shell, control quickhack; 1.3.0: stronger, more RAM):
//   the cast (1.1.0, as Zeusico's): hand gesture (weapon holstered, drawn again after 2 s; skipped in a vehicle or
//     while carrying a body), slow motion 10 % for 0.5 s, the burst 0.3 s later with the EMP explosion visual
//   target, a human who can be knocked out (1.3.0): electric hit VFX, knocked out and thrown away from V, every cast.
//     Immune to Unconscious (exo soldiers): -50 % health + stunned. Ragdoll impacts on it deal nothing for 10 s,
//     so no wall or fall can kill it.
//   up to three hostile NPCs within 12 m of the target with a clear line (vanilla chain lightning beam, visual only):
//     a human loses 25 % health and is electrocuted (vanilla ElectrocutedNoDamage); knocked out if left at 25 % or less.
//   Health never drops below 5 % through this quickhack.
//   bosses, MaxTac and quest-protected humans (god mode): stunned (vanilla Stun + ElectrocutedNoDamage), never hurt
//   drones, mechs, androids: vanilla legendary EMP grenade effect (machines can be destroyed)
// The program is given once per save (quest fact cyberslop_thunderclap_granted).
// Log: [CyberslopThunderclap] lines in CET's gamelog.log.
// Remove: delete r6\scripts\CyberslopThunderclap and r6\tweaks\CyberslopThunderclap. The program item vanishes from
// the save; nothing else depends on it.

module CyberslopThunderclap

@addField(NPCPuppet)
public let m_cstcGuardUntil: Float;

@addField(NPCPuppet)
public let m_cstcFiredAt: Float;

// 1.1.0 cast gesture state (only the newest gesture's end event cleans up)
@addField(PlayerPuppet)
public let m_cstcGestureGen: Int32;

@addField(PlayerPuppet)
public let m_cstcGestureActive: Bool;

@addField(PlayerPuppet)
public let m_cstcForcedCarryWrapper: Bool;

@addField(PlayerPuppet)
public let m_cstcRestoreWeapon: ItemID;

// The burst, 0.3 s after the quickhack lands (queued on the target)
public class BlastEvent extends Event {}

// End of the hand gesture (queued on the player)
public class GestureEndEvent extends Event {
  public let gen: Int32;
}

public abstract class TC {
  public static func Trigger() -> TweakDBID = t"BaseStatusEffect.CyberslopThunderclap"
  public static func Program() -> TweakDBID = t"Items.CyberslopThunderclapProgram"
  public static func ArcAttack() -> TweakDBID = t"Attacks.CyberslopThunderclapArc"
  // Balance 1.3.0 (design goal: "knockout every cast, much more RAM"): the target is always knocked out (immune to
  // Unconscious: -MainHealthLoss + stun); three arcs, 12 m, -25 % health, an arc knocks out if that leaves
  // ArcKnockoutAt or less; health never drops below HealthFloor from this quickhack. RAM 16 (was 9) in the YAML.
  public static func MainHealthLoss() -> Float = 50.00
  public static func ArcRange() -> Float = 12.00
  public static func ArcCount() -> Int32 = 3
  public static func ArcHealthLoss() -> Float = 25.00
  public static func ArcKnockoutAt() -> Float = 25.00
  public static func HealthFloor() -> Float = 5.00
  // ~10 m/s launch: the old 100 threw bodies at 17.8 m/s (64 km/h), more than a shock can do
  public static func ThrowForce() -> Float = 55.00
  public static func ThrowUp() -> Float = 0.60
  public static func GuardSeconds() -> Float = 10.00
  // the quickhack can land twice from one cast (probe: two uploads 0.3 s apart)
  public static func Debounce() -> Float = 1.50
  // 1.1.0 cast timing, Zeusico Thunderclap 2.04's values: burst 0.3 s (real time) after the quickhack lands, slow motion
  // 10 % for 0.5 s from the landing, weapon drawn again 2.0 s (real time) after the gesture starts
  public static func BlastDelay() -> Float = 0.30
  public static func SlowMoScale() -> Float = 0.10
  public static func SlowMoSeconds() -> Float = 0.50
  public static func GestureSeconds() -> Float = 2.00

  // 1.2.1: CET window toggle through the CyberslopThunderclapSlowMo service (SlowMoSwitch.reds); the 1.2.0 TweakDB
  // flat channel never applied on 2.5. No service = on.
  public static func SlowMoOn() -> Bool {
    let svc: ref<CyberslopThunderclapSlowMo> = CyberslopThunderclapSlowMo.Get();
    return !IsDefined(svc) || svc.IsSlowMoOn();
  }

  public static func Now(game: GameInstance) -> Float {
    return EngineTime.ToFloat(GameInstance.GetSimTime(game));
  }

  public static func Name(npc: ref<NPCPuppet>) -> String {
    return TDBID.ToStringDEBUG(npc.GetRecordID());
  }

  public static func IsMachine(npc: ref<NPCPuppet>) -> Bool {
    let t: gamedataNPCType = npc.GetNPCType();
    return Equals(t, gamedataNPCType.Drone) || Equals(t, gamedataNPCType.Mech) || Equals(t, gamedataNPCType.Android);
  }

  public static func IsProtected(npc: ref<NPCPuppet>) -> Bool {
    let god: ref<GodModeSystem> = GameInstance.GetGodModeSystem(npc.GetGame());
    return npc.IsBoss() || TC.IsMaxTac(npc)
      || god.HasGodMode(npc.GetEntityID(), gameGodModeType.Immortal)
      || god.HasGodMode(npc.GetEntityID(), gameGodModeType.Invulnerable);
  }

  // 1.2.2: the street squads (maxtac_*_elite, prevention_maxtac_rifle_ma) are rarity Elite; the record name catches
  // them (same test as Cyberslop Enemy Armor's IsMaxTac)
  public static func IsMaxTac(npc: ref<NPCPuppet>) -> Bool {
    if Equals(npc.GetNPCRarity(), gamedataNPCRarity.MaxTac) {
      return true;
    };
    let record: String = TDBID.ToStringDEBUG(npc.GetRecordID());
    return StrBeginsWith(record, "Character.maxtac_") || StrBeginsWith(record, "Character.prevention_maxtac_") || StrBeginsWith(record, "Character.q305_maxtac_");
  }

  public static func IsDown(npc: ref<NPCPuppet>) -> Bool {
    return ScriptedPuppet.IsUnconscious(npc) || ScriptedPuppet.IsDefeated(npc) || npc.IsAboutToDieOrDefeated();
  }

  // Ragdoll impacts on this NPC deal nothing until the guard runs out
  public static func Guard(npc: ref<NPCPuppet>) -> Void {
    npc.m_cstcGuardUntil = TC.Now(npc.GetGame()) + TC.GuardSeconds();
  }

  public static func KnockOut(player: ref<PlayerPuppet>, npc: ref<NPCPuppet>, throw: Bool) -> Void {
    TC.Guard(npc);
    StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.Unconscious", player.GetEntityID());
    if throw {
      TC.Throw(player, npc);
    };
  }

  public static func Throw(player: ref<PlayerPuppet>, npc: ref<NPCPuppet>) -> Void {
    let dir: Vector4 = npc.GetWorldPosition() - player.GetWorldPosition();
    dir.Z = 0.00;
    dir = Vector4.Normalize(dir);
    dir.Z = TC.ThrowUp();
    dir = Vector4.Normalize(dir);
    let at: Vector4 = npc.GetWorldPosition();
    at.Z += 1.00;
    npc.QueueEvent(CreateForceRagdollEvent(n"CyberslopThunderclap"));
    GameInstance.GetDelaySystem(npc.GetGame()).DelayEvent(npc, CreateRagdollApplyImpulseEvent(at, dir * TC.ThrowForce(), 5.00), 0.10, false);
  }

  public static func Stun(player: ref<PlayerPuppet>, npc: ref<NPCPuppet>) -> Void {
    StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.ElectrocutedNoDamage", player.GetEntityID());
    StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.Stun", player.GetEntityID());
  }

  // One NPC's share of the burst. main = the quickhacked target (knocked out and thrown), else an arc target.
  public static func Shock(player: ref<PlayerPuppet>, npc: ref<NPCPuppet>, main: Bool) -> String {
    if !ScriptedPuppet.IsAlive(npc) {
      return "dead already";
    };
    if TC.IsMachine(npc) {
      StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.LegendaryEmpGrenade", player.GetEntityID());
      return "machine: EMP";
    };
    if NotEquals(npc.GetNPCType(), gamedataNPCType.Human) {
      TC.Stun(player, npc);
      return "not human: stunned";
    };
    if TC.IsProtected(npc) {
      TC.Stun(player, npc);
      return "protected: stunned";
    };
    if TC.IsDown(npc) {
      TC.Guard(npc);
      return "down already";
    };
    let id: StatsObjectID = Cast<StatsObjectID>(npc.GetEntityID());
    let pools: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(npc.GetGame());
    let health: Float = pools.GetStatPoolValue(id, gamedataStatPoolType.Health, true);
    let was: String = FloatToStringPrec(health, 0);
    let immune: Bool = GameInstance.GetStatsSystem(npc.GetGame()).GetStatValue(id, gamedataStatType.UnconsciousImmunity) > 0.00;
    if main {
      if immune {
        // 1.2.2: immune to Unconscious (exo soldiers, some cyberpsychos): the hit lands, then a stun
        TC.Hurt(player, npc, health, TC.MainHealthLoss());
        TC.Stun(player, npc);
        return s"immune to knockout: shocked + stunned (health \(was) -> \(FloatToStringPrec(health - TC.MainHealthLoss(), 0)) %)";
      };
      // 1.3.0: every cast knocks the target out
      TC.KnockOut(player, npc, true);
      return s"knocked out + thrown (health \(was) %)";
    };
    if !immune && health - TC.ArcHealthLoss() <= TC.ArcKnockoutAt() {
      TC.KnockOut(player, npc, false);
      return s"arc knockout (health \(was) %)";
    };
    let after: Float = TC.Hurt(player, npc, health, TC.ArcHealthLoss());
    return s"arc shock (health \(was) -> \(FloatToStringPrec(after, 0)) %)";
  }

  // Health loss in percent of max, never below HealthFloor (no death possible), plus the vanilla electrocution stagger
  public static func Hurt(player: ref<PlayerPuppet>, npc: ref<NPCPuppet>, health: Float, loss: Float) -> Float {
    let take: Float = MinF(loss, MaxF(health - TC.HealthFloor(), 0.00));
    if take > 0.00 {
      GameInstance.GetStatPoolsSystem(npc.GetGame()).RequestChangingStatPoolValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatPoolType.Health, -take, player, false, true);
    };
    StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.ElectrocutedNoDamage", player.GetEntityID());
    return health - take;
  }

  public static func Chest(npc: ref<NPCPuppet>) -> Vector4 {
    let t: WorldTransform;
    if npc.GetSlotComponent().GetSlotTransform(n"Chest", t) {
      return WorldPosition.ToVector4(WorldTransform.GetWorldPosition(t));
    };
    let p: Vector4 = npc.GetWorldPosition();
    p.Z += 1.20;
    return p;
  }

  public static func ClearLine(game: GameInstance, from: Vector4, to: Vector4) -> Bool {
    let sqs: ref<SpatialQueriesSystem> = GameInstance.GetSpatialQueriesSystem(game);
    let hit: TraceResult;
    return !sqs.SyncRaycastByCollisionPreset(from, to, n"World Static", hit, true)
      && !sqs.SyncRaycastByCollisionPreset(from, to, n"World Dynamic", hit, true);
  }

  // The vanilla chain lightning beam from one body to another, effect only (no attack is started, so no hit)
  public static func ArcVisual(player: ref<PlayerPuppet>, from: Vector4, to: ref<NPCPuppet>) -> Void {
    let ctx: AttackInitContext;
    ctx.record = TweakDBInterface.GetAttackRecord(TC.ArcAttack());
    ctx.instigator = player;
    ctx.source = player;
    let attack: ref<Attack_GameEffect> = IAttack.Create(ctx) as Attack_GameEffect;
    if !IsDefined(attack) {
      return;
    };
    let effect: ref<EffectInstance> = attack.PrepareAttack(player);
    if !IsDefined(effect) {
      return;
    };
    let end: Vector4 = TC.Chest(to);
    let forward: Vector4 = end - from;
    let range: Float = Vector4.Length(forward);
    forward = Vector4.Normalize(forward);
    let defs: ref<AllBlackboardDefinitions> = GetAllBlackboardDefs();
    EffectData.SetVector(effect.GetSharedData(), defs.EffectSharedData.position, from);
    EffectData.SetVector(effect.GetSharedData(), defs.EffectSharedData.forward, forward);
    EffectData.SetFloat(effect.GetSharedData(), defs.EffectSharedData.range, range);
    EffectData.SetVector(effect.GetSharedData(), defs.EffectSharedData.raycastEnd, end);
    effect.Run();
  }

  // Up to ArcCount hostile NPCs within ArcRange of the target, nearest first, with a clear line from its chest
  public static func Arcs(player: ref<PlayerPuppet>, source: ref<NPCPuppet>, out log: String) -> Void {
    let game: GameInstance = source.GetGame();
    let origin: Vector4 = TC.Chest(source);
    let query: TargetSearchQuery;
    query.testedSet = TargetingSet.Complete;
    query.searchFilter = TSF_EnemyNPC();
    query.maxDistance = Vector4.Distance(source.GetWorldPosition(), player.GetWorldPosition()) + TC.ArcRange();
    query.filterObjectByDistance = true;
    query.includeSecondaryTargets = false;
    query.ignoreInstigator = true;
    let parts: array<TS_TargetPartInfo>;
    GameInstance.GetTargetingSystem(game).GetTargetParts(player, query, parts);

    let found: array<ref<NPCPuppet>>;
    let dists: array<Float>;
    let i: Int32 = 0;
    while i < ArraySize(parts) {
      let comp: ref<TargetingComponent> = TS_TargetPartInfo.GetComponent(parts[i]);
      if IsDefined(comp) {
        let npc: ref<NPCPuppet> = comp.GetEntity() as NPCPuppet;
        if IsDefined(npc) && npc != source && ScriptedPuppet.IsAlive(npc) && !ArrayContains(found, npc) {
          let d: Float = Vector4.Distance(source.GetWorldPosition(), npc.GetWorldPosition());
          if d > 0.30 && d <= TC.ArcRange() {
            ArrayPush(found, npc);
            ArrayPush(dists, d);
          };
        };
      };
      i += 1;
    };

    let done: Int32 = 0;
    while done < TC.ArcCount() && ArraySize(found) > 0 {
      // nearest left
      let best: Int32 = 0;
      let j: Int32 = 1;
      while j < ArraySize(found) {
        if dists[j] < dists[best] {
          best = j;
        };
        j += 1;
      };
      let target: ref<NPCPuppet> = found[best];
      ArrayErase(found, best);
      ArrayErase(dists, best);
      if TC.ClearLine(game, origin, TC.Chest(target)) {
        TC.ArcVisual(player, origin, target);
        GameObjectEffectHelper.StartEffectEvent(target, n"electric_hit");
        log += " | arc " + TC.Name(target) + ": " + TC.Shock(player, target, false);
        done += 1;
      };
    };
  }

  // ---- 1.1.0 cast visuals (Zeusico Thunderclap 2.04's look, none of its attacks) ----

  // The vanilla Blackwall hand gesture, as Zeusico plays it: both hands, weapon holstered, the carry_woundedSoldier
  // anim wrapper forced on for the gesture (Zeusico does this; not when V really carries a wounded soldier).
  // Skipped in a vehicle or while carrying a body: the upper-body state can't play it there and would play it later.
  public static func Gesture(player: ref<PlayerPuppet>) -> String {
    let game: GameInstance = player.GetGame();
    if VehicleComponent.IsMountedToVehicle(game, player) {
      return "gesture skipped: in a vehicle";
    };
    if player.GetPlayerStateMachineBlackboard().GetBool(GetAllBlackboardDefs().PlayerStateMachine.Carrying) {
      return "gesture skipped: carrying a body";
    };
    player.m_cstcGestureGen += 1;
    // the weapon to draw again afterwards; a second cast during the gesture finds the hands empty and keeps the first
    let weapon: ref<WeaponObject> = GameObject.GetActiveWeapon(player);
    if IsDefined(weapon) {
      player.m_cstcRestoreWeapon = weapon.GetItemID();
    } else {
      if !player.m_cstcGestureActive {
        player.m_cstcRestoreWeapon = ItemID.None();
      };
    };
    player.m_cstcGestureActive = true;
    if !player.m_cstcForcedCarryWrapper && !StatusEffectSystem.ObjectHasStatusEffect(player, t"GameplayRestriction.BodyCarryingWoundedSoldier") {
      AnimationControllerComponent.SetAnimWrapperWeight(player, n"carry_woundedSoldier", 1.00);
      player.m_cstcForcedCarryWrapper = true;
    };
    // vanilla's own Blackwall gesture counter and count (Items.BlackwallForce.numberOfHandAnims = 4 in 2.31)
    let bb: ref<IBlackboard> = GameInstance.GetBlackboardSystem(game).Get(GetAllBlackboardDefs().BlackwallDeathAnim);
    let count: Int32 = TweakDBInterface.GetInt(t"Items.BlackwallForce.numberOfHandAnims", 4);
    let index: Int32 = bb.GetInt(GetAllBlackboardDefs().BlackwallDeathAnim.handGestureAnimNumber);
    if index < 0 || index >= count {
      index = 0;
    };
    let anim: ref<AdHocAnimationEvent> = new AdHocAnimationEvent();
    anim.animationIndex = index;
    anim.useBothHands = true;
    anim.unequipWeapon = true;
    anim.animationDuration = -1.00;
    player.QueueEvent(anim);
    bb.SetInt(GetAllBlackboardDefs().BlackwallDeathAnim.handGestureAnimNumber, index + 1);
    let done: ref<GestureEndEvent> = new GestureEndEvent();
    done.gen = player.m_cstcGestureGen;
    GameInstance.GetDelaySystem(game).DelayEvent(player, done, TC.GestureSeconds(), false);
    return s"gesture \(index)";
  }

  // Wrapper back off (unless V now carries a wounded soldier) and the holstered weapon drawn again, instantly,
  // unless V already holds a weapon
  public static func GestureEnd(player: ref<PlayerPuppet>) -> Void {
    player.m_cstcGestureActive = false;
    if player.m_cstcForcedCarryWrapper {
      if !StatusEffectSystem.ObjectHasStatusEffect(player, t"GameplayRestriction.BodyCarryingWoundedSoldier") {
        AnimationControllerComponent.SetAnimWrapperWeight(player, n"carry_woundedSoldier", 0.00);
      };
      player.m_cstcForcedCarryWrapper = false;
    };
    let item: ItemID = player.m_cstcRestoreWeapon;
    player.m_cstcRestoreWeapon = ItemID.None();
    if !ItemID.IsValid(item) || IsDefined(GameObject.GetActiveWeapon(player)) || VehicleComponent.IsMountedToVehicle(player.GetGame(), player) {
      return;
    };
    let eqs: ref<EquipmentSystem> = GameInstance.GetScriptableSystemsContainer(player.GetGame()).Get(n"EquipmentSystem") as EquipmentSystem;
    if IsDefined(eqs) {
      let draw: ref<DrawItemRequest> = new DrawItemRequest();
      draw.owner = player;
      draw.itemID = item;
      draw.equipAnimationType = gameEquipAnimationType.HACK_ForceInstantEquip;
      eqs.QueueRequest(draw);
    };
  }

  // The EMP explosion Zeusico's blast showed (its game effect explosions / emp_explosion spawns this file at the
  // target), spawned on its own: no hit, no status, no physics impulse
  public static func BlastVisual(player: ref<PlayerPuppet>, npc: ref<NPCPuppet>) -> Void {
    let fx: FxResource;
    fx.effect *= r"base\\fx\\vehicles\\av\\av_panzer\\weapons\\v_panzer_emp_explosion.effect";
    if !FxResource.IsValid(fx) {
      return;
    };
    let t: WorldTransform;
    WorldTransform.SetPosition(t, npc.GetWorldPosition());
    let dir: Vector4 = npc.GetWorldPosition() - player.GetWorldPosition();
    dir.Z = 0.00;
    if Vector4.Length(dir) > 0.10 {
      WorldTransform.SetOrientationFromDir(t, Vector4.Normalize(dir));
    };
    GameInstance.GetFxSystem(npc.GetGame()).SpawnEffect(fx, t);
  }

  // The quickhack landed: the cast (gesture + slow motion) now, the burst BlastDelay later
  public static func Fire(target: ref<NPCPuppet>) -> Void {
    let game: GameInstance = target.GetGame();
    let player: ref<PlayerPuppet> = GetPlayer(game);
    if !IsDefined(player) {
      return;
    };
    let now: Float = TC.Now(game);
    if target.m_cstcFiredAt > 0.00 && now >= target.m_cstcFiredAt && now - target.m_cstcFiredAt < TC.Debounce() {
      FTLog(s"[CyberslopThunderclap] \(TC.Name(target)): second landing within \(TC.Debounce()) s ignored");
      return;
    };
    target.m_cstcFiredAt = now;
    let gesture: String = TC.Gesture(player);
    if TC.SlowMoOn() {
      GameInstance.GetTimeSystem(game).SetTimeDilation(n"CyberslopThunderclap", TC.SlowMoScale(), TC.SlowMoSeconds(), n"Linear", n"Linear");
    };
    GameInstance.GetDelaySystem(game).DelayEvent(target, new BlastEvent(), TC.BlastDelay(), false);
    FTLog("[CyberslopThunderclap] " + TC.Name(target) + ": landed, " + gesture + (TC.SlowMoOn() ? ", slow motion" : ", no slow motion") + ", burst in " + FloatToStringPrec(TC.BlastDelay(), 1) + " s");
  }

  // The burst itself (1.0.0's whole effect, now 0.3 s after the landing)
  public static func Blast(target: ref<NPCPuppet>) -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(target.GetGame());
    if !IsDefined(player) {
      return;
    };
    TC.BlastVisual(player, target);
    GameObjectEffectHelper.StartEffectEvent(target, n"electric_hit");
    let log: String = TC.Name(target) + ": " + TC.Shock(player, target, true);
    TC.Arcs(player, target, log);
    FTLog("[CyberslopThunderclap] " + log);
  }
}

// The quickhack's completion effect lands on the target: start the cast
@wrapMethod(NPCPuppet)
protected cb func OnStatusEffectApplied(evt: ref<ApplyStatusEffectEvent>) -> Bool {
  let r: Bool = wrappedMethod(evt);
  if IsDefined(evt) && IsDefined(evt.staticData) && evt.staticData.GetID() == TC.Trigger() {
    TC.Fire(this);
  };
  return r;
}

@addMethod(NPCPuppet)
protected cb func OnCyberslopThunderclapBlast(evt: ref<BlastEvent>) -> Bool {
  TC.Blast(this);
  return true;
}

@addMethod(PlayerPuppet)
protected cb func OnCyberslopThunderclapGestureEnd(evt: ref<GestureEndEvent>) -> Bool {
  // a newer gesture started meanwhile: its own end event cleans up
  if evt.gen == this.m_cstcGestureGen {
    TC.GestureEnd(this);
  };
  return true;
}

// A guarded body takes nothing from ragdoll impacts: vanilla would MarkForDeath it at 11 m/s or on a 6 m fall
// (and Push/Pull Non-Lethal or other wraps further in are skipped for it on purpose)
@wrapMethod(DamageSystem)
private final func ProcessRagdollHit(hitEvent: ref<gameHitEvent>) -> Void {
  let npc: ref<NPCPuppet> = hitEvent.target as NPCPuppet;
  if IsDefined(npc) && IsDefined(hitEvent as gameRagdollHitEvent) && npc.m_cstcGuardUntil > 0.00 && TC.Now(npc.GetGame()) <= npc.m_cstcGuardUntil {
    hitEvent.attackComputed.SetAttackValue(0.00);
    return;
  };
  wrappedMethod(hitEvent);
}

// The program, once per save
public class Grant extends ScriptableSystem {
  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    let game: GameInstance = this.GetGameInstance();
    // 1.0.1: the main menu's pre-game session attaches a throwaway player (sim time 0, no facts): no grant there
    if GameInstance.GetSystemRequestsHandler().IsPreGame() {
      return;
    };
    let quests: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    if quests.GetFact(n"cyberslop_thunderclap_granted") != 0 {
      return;
    };
    let player: ref<PlayerPuppet> = GetPlayer(game);
    if !IsDefined(player) {
      return;
    };
    if GameInstance.GetTransactionSystem(game).GiveItem(player, ItemID.FromTDBID(TC.Program()), 1) {
      quests.SetFact(n"cyberslop_thunderclap_granted", 1);
      FTLog("[CyberslopThunderclap] program added to the backpack");
    };
  }
}
