// Cyberslop Combat Log 1.4.0 (2026-11-17, for game 2.5 and Much Better AI 3.0: MBAI 3.0 has no Nerve module and no
// hit model mode, so the session row writes hitmodel=mbai3-<marksmanship on> and nerve=none, and broke= is always false)
// 1.3.0 (2026-11-02, hits between NPCs are summed into npcfight rows every 5 s, so NPC fights
// cost no more than the shots rows; dealt rows get stop= (whole armor share, vanilla Armor included) and varm=
// (Armor before Cyberslop Enemy Armor's hand-out) for drones, mechs and armored elites)
// 1.2.0 (2026-11-02, light for normal play: rows are collected in memory and written every 5 s
// or every 40 rows instead of one file write per row; the per-hit hit= row is off, set HitRows() to true for it)
// 1.1.4 (2026-11-01, hit= row for every hit of V's on an NPC, damage or not: every flag with
// its source, the computed damage, invulnerability and body state, so a punch that dealt nothing names who zeroed it)
// 1.1.3 (2026-10-31, nonlethal flag carries its source name, down= state on NPC rows)
// 1.1.2 (2026-10-31, cut= and ap= fields for Cyberslop Enemy Armor, stealth flag)
// Writes combat stats to r6\storages\CyberslopCombatLog\combat-N.txt, one new file per game launch.
// One event per line, tab separated: kind, then key=value fields. It reads, it changes nothing in combat.
// Report: python -I -X utf8 tools\combat-log-report.py (in the research folder of this probe)
// Remove: delete this folder. Nothing depends on it.
module CyberslopCombatLog

import RedFileSystem.*
import PDO.*
import MuchBetterAIConfig.*
import MuchBetterAI.Fireteam.*

@addField(NPCPuppet)
public let cclFirstHit: Float;

@addField(NPCPuppet)
public let cclHits: Int32;

@addField(NPCPuppet)
public let cclDamage: Float;

@addField(NPCPuppet)
public let cclDowned: Bool;

@addField(NPCPuppet)
public let cclBroke: Bool;

// One npcfight row: hits between NPCs of one kind, summed until the next flush
public class CombatLogFightBucket {
  public let key: String;
  public let hits: Int32;
  public let stopped: Int32;
  public let kills: Int32;
  public let raw: Float;
  public let dmg: Float;
  public let cut: Float;
  public let stop: Float;
  public let armor: Float;
}

public class CombatLog extends ScriptableService {
  private let file: ref<File>;
  private let needSession: Bool;
  private let lastEvent: wref<gameDamageReceivedEvent>;
  private let lastFlush: Float;
  private let shotKeys: array<String>;
  private let shotRolls: array<Int32>;
  private let shotHits: array<Int32>;
  private let fights: array<ref<CombatLogFightBucket>>;
  private let buffer: String;
  private let bufLines: Int32;
  private let lastNow: Float;

  // RedFileSystem grants a storage only once per process, so the service holds it
  private cb func OnLoad() -> Void {
    let storage: ref<FileSystemStorage> = FileSystem.GetStorage("CyberslopCombatLog");
    if !IsDefined(storage) {
      return;
    };
    let number: Int32 = ArraySize(storage.GetFiles()) + 1;
    while Equals(storage.Exists(s"combat-\(number).txt"), FileSystemStatus.True) {
      number += 1;
    };
    this.file = storage.GetFile(s"combat-\(number).txt");
    this.needSession = true;
  }

  // 1.1.4's hit= row (every hit of V's, all flags, status effects, god mode) was for the knockout hunt, which is
  // solved. It is the most expensive row and over half the file, so it is off; true brings it back.
  public static func HitRows() -> Bool = true // crash hunt

  public static func Get() -> ref<CombatLog> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"CyberslopCombatLog.CombatLog") as CombatLog;
  }

  // Buffered: rows go to the file with the next flush (MaybeFlush after every event, every 5 s of game time),
  // at 40 rows, at V's death and when the session ends
  private final func Write(line: String) -> Void {
    if !IsDefined(this.file) {
      return;
    };
    this.buffer += line + "\n";
    this.bufLines += 1;
    if this.bufLines >= 1 { // crash hunt: unbuffered
      this.WriteOut();
    };
  }

  private final func WriteOut() -> Void {
    if IsDefined(this.file) && this.bufLines > 0 {
      this.file.WriteText(this.buffer, FileSystemWriteMode.Append);
    };
    this.buffer = "";
    this.bufLines = 0;
  }

  public final func FlushNow() -> Void {
    this.Flush(this.lastNow);
  }

  private final func Num(value: Float) -> String {
    return FloatToStringPrec(value, 2);
  }

  private final func Now(game: GameInstance) -> Float {
    return EngineTime.ToFloat(GameInstance.GetSimTime(game));
  }

  private final func HealthPct(game: GameInstance, id: EntityID) -> Float {
    return GameInstance.GetStatPoolsSystem(game).GetStatPoolValue(Cast<StatsObjectID>(id), gamedataStatPoolType.Health, true);
  }

  private final func HealthMax(game: GameInstance, id: EntityID) -> Float {
    return GameInstance.GetStatPoolsSystem(game).GetStatPoolMaxPointValue(Cast<StatsObjectID>(id), gamedataStatPoolType.Health);
  }

  private final func Armor(game: GameInstance, id: EntityID) -> Float {
    return GameInstance.GetStatsSystem(game).GetStatValue(Cast<StatsObjectID>(id), gamedataStatType.Armor);
  }

  public final func MarkSession() -> Void {
    this.needSession = true;
  }

  // Settings are written with every load, so two tunings can be told apart later
  private final func WriteSession(player: ref<GameObject>) -> Void {
    this.needSession = false;
    let game: GameInstance = player.GetGame();
    let id: EntityID = player.GetEntityID();
    let pdo: ref<PedDamageOverhaul2077> = PedDamageOverhaul2077.GetInstance();
    let line: String = s"session\tt=\(this.Num(this.Now(game)))\tdifficulty=\(GameInstance.GetStatsDataSystem(game).GetDifficulty())";
    line += s"\tlevel=\(this.Num(GameInstance.GetStatsSystem(game).GetStatValue(Cast<StatsObjectID>(id), gamedataStatType.Level)))";
    line += s"\tvhp=\(this.Num(this.HealthMax(game, id)))\tvarmor=\(this.Num(this.Armor(game, id)))";
    // 2.5 port: Much Better AI 3.0 has no hit model mode and no Nerve module; the fields stay for the report script
    line += s"\thitmodel=mbai3-\(MuchBetterAISettings.EnableMarksmanship())\taccuracy=\(this.Num(MuchBetterAISettings.MarksmanshipAccuracy()))\tnerve=none";
    if IsDefined(pdo) {
      line += s"\tdying=\(pdo.GetDyingStateThreshold())\theadkill=\(pdo.GetHeadshotKillThreshold())\tdsheadkill=\(pdo.GetDSHeadshotKillThreshold())\ttorsokill=\(pdo.GetTorsoshotKillThreshold())";
    };
    this.Write(line);
  }

  private final func Zone(hit: ref<gameHitEvent>) -> String {
    let shapes: array<HitShapeData> = hit.hitRepresentationResult.hitShapes;
    if ArraySize(shapes) == 0 {
      return "none";
    };
    let data: ref<HitShapeUserDataBase> = DamageSystemHelper.GetHitShapeUserDataBase(shapes[0]);
    if !IsDefined(data) {
      return "none";
    };
    if HitShapeUserDataBase.IsHitReactionZoneHead(data) {
      return "head";
    };
    if HitShapeUserDataBase.IsHitReactionZoneTorso(data) {
      return "torso";
    };
    if HitShapeUserDataBase.IsHitReactionZoneLeftArm(data) || HitShapeUserDataBase.IsHitReactionZoneRightArm(data) {
      return "arm";
    };
    if HitShapeUserDataBase.IsHitReactionZoneLeftLeg(data) || HitShapeUserDataBase.IsHitReactionZoneRightLeg(data) {
      return "leg";
    };
    return "other";
  }

  private final func Shape(hit: ref<gameHitEvent>) -> String {
    if ArraySize(hit.hitRepresentationResult.hitShapes) == 0 {
      return "None";
    };
    return ToString(DamageSystemHelper.GetHitShapeTypeFromData(DamageSystemHelper.GetHitShape(hit)));
  }

  private final func Raw(hit: ref<gameHitEvent>) -> Float {
    if !IsDefined(hit.attackComputed) {
      return 0.00;
    };
    let values: array<Float> = hit.attackComputed.GetOriginalAttackValues();
    let total: Float = 0.00;
    let i: Int32 = 0;
    while i < ArraySize(values) {
      total += values[i];
      i += 1;
    };
    return total;
  }

  // Share of the hit Cyberslop Enemy Armor stopped; the log works without that mod
  @if(ModuleExists("CyberslopEnemyArmor"))
  private final func ArmorCut(hit: ref<gameHitEvent>) -> Float {
    return hit.csaCut;
  }

  @if(!ModuleExists("CyberslopEnemyArmor"))
  private final func ArmorCut(hit: ref<gameHitEvent>) -> Float {
    return 0.00;
  }

  // Whole share armor stopped: vanilla's stat Armor step and Enemy Armor's cut together
  @if(ModuleExists("CyberslopEnemyArmor"))
  private final func ArmorStop(hit: ref<gameHitEvent>) -> Float {
    return hit.csaStop;
  }

  @if(!ModuleExists("CyberslopEnemyArmor"))
  private final func ArmorStop(hit: ref<gameHitEvent>) -> Float {
    return 0.00;
  }

  // Armor the NPC had before Enemy Armor's hand-out (vanilla's own), "-" until the hand-out ran
  @if(ModuleExists("CyberslopEnemyArmor"))
  private final func VanillaArmor(npc: ref<NPCPuppet>) -> String {
    return npc.csaBossArmorDone ? this.Num(npc.csaArmorVanilla) : "-";
  }

  @if(!ModuleExists("CyberslopEnemyArmor"))
  private final func VanillaArmor(npc: ref<NPCPuppet>) -> String {
    return "-";
  }

  // nonlethal carries who set it (AttackData.AddFlag source): the eyes' native effector, a weapon record or a mod
  private final func Flags(data: ref<AttackData>) -> String {
    let flags: String = "";
    let all: array<SHitFlag> = data.GetFlags();
    let i: Int32 = 0;
    while i < ArraySize(all) {
      if Equals(all[i].flag, hitFlag.Nonlethal) {
        flags += s"nonlethal:\(NameToString(all[i].source)),";
      };
      i += 1;
    };
    if data.HasFlag(hitFlag.WasKillingBlow) {
      flags += "killing,";
    };
    if data.HasFlag(hitFlag.CriticalHit) {
      flags += "crit,";
    };
    if data.HasFlag(hitFlag.WeakspotHit) {
      flags += "weakspot,";
    };
    if data.HasFlag(hitFlag.StealthHit) {
      flags += "stealth,";
    };
    return flags;
  }

  // Weapon name and class of a hit; grenades, burns and rams have no weapon
  private final func WeaponFields(data: ref<AttackData>) -> String {
    let weapon: ref<WeaponObject> = data.GetWeapon();
    if !IsDefined(weapon) {
      return "wpn=none\twtype=none";
    };
    let item: ItemID = weapon.GetItemID();
    return s"wpn=\(TDBID.ToStringDEBUG(ItemID.GetTDBID(item)))\twtype=\(WeaponObject.GetWeaponType(item))\tap=\(this.Num(WeaponObject.CanIgnoreArmor(weapon)))";
  }

  // State of the body as the hit lands: X dead, U unconscious, D defeated (PDO dying state too), A about to die or be
  // defeated, R ragdoll, K knockdown, - standing. Letters add up, so "UD" is a knocked out body of the Defeated type
  private final func Down(npc: ref<NPCPuppet>) -> String {
    let state: String = "";
    if !ScriptedPuppet.IsAlive(npc) {
      state += "X";
    };
    if ScriptedPuppet.IsUnconscious(npc) {
      state += "U";
    };
    if ScriptedPuppet.IsDefeated(npc) {
      state += "D";
    };
    if npc.IsAboutToDieOrDefeated() {
      state += "A";
    };
    if npc.IsRagdolling() {
      state += "R";
    };
    if StatusEffectSystem.ObjectHasStatusEffectOfType(npc, gamedataStatusEffectType.Knockdown) {
      state += "K";
    };
    return Equals(state, "") ? "-" : state;
  }

  private final func Broken(npc: ref<NPCPuppet>) -> Bool {
    // 2.5 port: Much Better AI 3.0 dropped its Nerve (morale break) system, so no NPC ever counts as broken;
    // broke= stays in the rows (always false) so the report script reads old and new logs alike
    return false;
  }

  private final func Who(npc: ref<NPCPuppet>) -> String {
    return s"id=\(EntityID.GetHash(npc.GetEntityID()))\tnpc=\(TDBID.ToStringDEBUG(npc.GetRecordID()))\trarity=\(npc.GetNPCRarity())\ttype=\(npc.GetNPCType())\tfaction=\(MBAI_GetAffiliation(npc))";
  }

  public final func OnDamage(evt: ref<gameDamageReceivedEvent>) -> Void {
    // Two hooks see the same event: the damage funnel V is known to pass and the puppet callback
    if !IsDefined(evt) || !IsDefined(evt.hitEvent) || this.lastEvent == evt {
      return;
    };
    this.lastEvent = evt;
    let hit: ref<gameHitEvent> = evt.hitEvent;
    let target: ref<ScriptedPuppet> = hit.target as ScriptedPuppet;
    let data: ref<AttackData> = hit.attackData;
    if !IsDefined(target) || !IsDefined(data) {
      return;
    };
    let instigator: ref<GameObject> = data.GetInstigator();
    let toV: Bool = target.IsPlayer();
    if !toV && (!IsDefined(instigator) || !instigator.IsPlayer()) {
      this.OnNpcFight(hit, target, instigator, evt.totalDamageReceived);
      return;
    };
    let game: GameInstance = target.GetGame();
    let player: ref<GameObject> = GetPlayer(game);
    if !IsDefined(player) {
      return;
    };
    if this.needSession {
      this.WriteSession(player);
    };
    let now: Float = this.Now(game);
    let id: EntityID = target.GetEntityID();
    let dealt: Float = evt.totalDamageReceived;
    let maxHealth: Float = this.HealthMax(game, id);
    let percent: Float = maxHealth > 0.00 ? dealt / maxHealth * 100.00 : 0.00;
    let line: String = toV ? "took" : "dealt";
    line += s"\tt=\(this.Num(now))\tdmg=\(this.Num(dealt))\traw=\(this.Num(this.Raw(hit)))\tpct=\(this.Num(percent))\thpa=\(this.Num(this.HealthPct(game, id)))\tmaxhp=\(this.Num(maxHealth))\tarmor=\(this.Num(this.Armor(game, id)))";
    line += s"\t\(this.WeaponFields(data))\tatk=\(data.GetAttackType())\tzone=\(this.Zone(hit))\tshape=\(this.Shape(hit))\tflags=\(this.Flags(data))";
    if IsDefined(instigator) {
      line += s"\tdist=\(this.Num(Vector4.Distance(instigator.GetWorldPosition(), target.GetWorldPosition())))";
    };
    if toV {
      let attacker: ref<NPCPuppet> = instigator as NPCPuppet;
      if IsDefined(attacker) {
        line += s"\t\(this.Who(attacker))";
      };
      line += s"\tvspeed=\(this.Num(Vector4.Length(target.GetVelocity())))\tvcar=\(VehicleComponent.IsMountedToVehicle(game, target))";
    } else {
      let npc: ref<NPCPuppet> = target as NPCPuppet;
      if !IsDefined(npc) {
        return;
      };
      if npc.cclHits == 0 {
        npc.cclFirstHit = now;
      };
      npc.cclHits += 1;
      npc.cclDamage += dealt;
      let broken: Bool = this.Broken(npc);
      line += s"\tcut=\(this.Num(this.ArmorCut(hit)))\tstop=\(this.Num(this.ArmorStop(hit)))\tvarm=\(this.VanillaArmor(npc))\t\(this.Who(npc))\tn=\(npc.cclHits)\tsince=\(this.Num(now - npc.cclFirstHit))\tbroke=\(broken && !npc.cclBroke)";
      line += s"\tpdohead=\(npc.headhitcounter)\tpdotorso=\(npc.torsohitcounter)\tpdodown=\(npc.toBeIncapacitated)\tdown=\(this.Down(npc))";
      npc.cclBroke = broken;
    };
    this.Write(line);
    this.MaybeFlush(now);
  }

  // 1.3.0: hits on NPCs by other NPCs, turrets or cars. A gang war lands dozens a second, so they are summed by
  // target, attacker kind, weapon class and surface and written with the next flush, like the shots rows.
  // Burn and bleed ticks are left out
  private final func OnNpcFight(hit: ref<gameHitEvent>, target: ref<ScriptedPuppet>, instigator: ref<GameObject>, dealt: Float) -> Void {
    let npc: ref<NPCPuppet> = target as NPCPuppet;
    let data: ref<AttackData> = hit.attackData;
    if !IsDefined(npc) || AttackData.IsDoT(data) {
      return;
    };
    let by: String = "none";
    if IsDefined(instigator) {
      let attacker: ref<ScriptedPuppet> = instigator as ScriptedPuppet;
      if IsDefined(attacker) {
        by = s"\(attacker.GetNPCType())";
      } else {
        by = IsDefined(instigator as Device) ? "device" : IsDefined(instigator as VehicleObject) ? "vehicle" : "other";
      };
    };
    let weapon: ref<WeaponObject> = data.GetWeapon();
    let wtype: String = IsDefined(weapon) ? s"\(WeaponObject.GetWeaponType(weapon.GetItemID()))" : s"\(data.GetAttackType())";
    let key: String = s"type=\(npc.GetNPCType())\trarity=\(npc.GetNPCRarity())\tfaction=\(MBAI_GetAffiliation(npc))\tby=\(by)\twtype=\(wtype)\tzone=\(this.Zone(hit))\tshape=\(this.Shape(hit))";
    let bucket: ref<CombatLogFightBucket>;
    let i: Int32 = 0;
    while i < ArraySize(this.fights) && !IsDefined(bucket) {
      if Equals(this.fights[i].key, key) {
        bucket = this.fights[i];
      };
      i += 1;
    };
    if !IsDefined(bucket) {
      bucket = new CombatLogFightBucket();
      bucket.key = key;
      ArrayPush(this.fights, bucket);
    };
    let game: GameInstance = npc.GetGame();
    let stop: Float = this.ArmorStop(hit);
    bucket.hits += 1;
    bucket.raw += this.Raw(hit);
    bucket.dmg += dealt;
    bucket.cut += this.ArmorCut(hit);
    bucket.stop += stop;
    bucket.armor += this.Armor(game, npc.GetEntityID());
    if stop > 0.005 {
      bucket.stopped += 1;
    };
    if data.HasFlag(hitFlag.WasKillingBlow) {
      bucket.kills += 1;
    };
    this.MaybeFlush(this.Now(game));
  }

  // Every flag with who set it (AttackData.AddFlag source), DealNoDamage included
  private final func AllFlags(data: ref<AttackData>) -> String {
    let flags: String = "";
    let all: array<SHitFlag> = data.GetFlags();
    let i: Int32 = 0;
    while i < ArraySize(all) {
      flags += s"\(all[i].flag):\(NameToString(all[i].source)),";
      i += 1;
    };
    return flags;
  }

  // Status effects that stop damage or mark a downed body: I Invulnerable, J InvulnerableAfterDefeated, U Unconscious,
  // D Defeated, W DefeatedWithRecover, N NonInteractable
  private final func Effects(npc: ref<NPCPuppet>) -> String {
    let fx: String = "";
    if StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.Invulnerable") {
      fx += "I";
    };
    if StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.InvulnerableAfterDefeated") {
      fx += "J";
    };
    if StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.Unconscious") {
      fx += "U";
    };
    if StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.Defeated") {
      fx += "D";
    };
    if StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.DefeatedWithRecover") {
      fx += "W";
    };
    if StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.NonInteractable") {
      fx += "N";
    };
    return Equals(fx, "") ? "-" : fx;
  }

  // 1.1.4: written from NPCPuppet.OnHit after the damage pipeline, for every hit of V's, whether it dealt damage or
  // not (a dealt row needs damage). total= is the computed health damage of the hit, invuln= the IsInvulnerable stat,
  // god= the god mode system, defeat= whether the defeat mechanic is still on, pdo= PDO's dying state flag
  public final func OnHit(npc: ref<NPCPuppet>, hit: ref<gameHitEvent>) -> Void {
    if !IsDefined(npc) || !IsDefined(hit) || !IsDefined(hit.attackData) {
      return;
    };
    let data: ref<AttackData> = hit.attackData;
    let instigator: ref<GameObject> = data.GetInstigator();
    if !IsDefined(instigator) || !instigator.IsPlayer() {
      return;
    };
    let game: GameInstance = npc.GetGame();
    let id: EntityID = npc.GetEntityID();
    let now: Float = this.Now(game);
    let total: Float = IsDefined(hit.attackComputed) ? hit.attackComputed.GetTotalAttackValue(gamedataStatPoolType.Health) : -1.00;
    let god: String = "";
    let godSystem: ref<GodModeSystem> = GameInstance.GetGodModeSystem(game);
    if godSystem.HasGodMode(id, gameGodModeType.Invulnerable) {
      god += "invulnerable,";
    };
    if godSystem.HasGodMode(id, gameGodModeType.Immortal) {
      god += "immortal,";
    };
    let line: String = s"hit\tt=\(this.Num(now))\ttotal=\(this.Num(total))\traw=\(this.Num(this.Raw(hit)))\thp=\(this.Num(this.HealthPct(game, id)))";
    line += s"\t\(this.WeaponFields(data))\tatk=\(data.GetAttackType())\tzone=\(this.Zone(hit))\tshape=\(this.Shape(hit))";
    line += s"\tflags=\(this.AllFlags(data))\tinvuln=\(this.Num(GameInstance.GetStatsSystem(game).GetStatValue(Cast<StatsObjectID>(id), gamedataStatType.IsInvulnerable)))\tgod=\(god)";
    line += s"\tfx=\(this.Effects(npc))\tdefeat=\(npc.IsDefeatMechanicActive())\tpdo=\(npc.toBeIncapacitated)/\(npc.hasBeenAffectedByMod)\tdown=\(this.Down(npc))\t\(this.Who(npc))";
    this.Write(line);
    this.MaybeFlush(now);
  }

  public final func OnOutcome(npc: ref<NPCPuppet>, kind: String) -> Void {
    if npc.cclHits == 0 {
      return;
    };
    if Equals(kind, "down") {
      if npc.cclDowned {
        return;
      };
      npc.cclDowned = true;
    };
    let game: GameInstance = npc.GetGame();
    let now: Float = this.Now(game);
    this.Write(s"\(kind)\tt=\(this.Num(now))\t\(this.Who(npc))\thits=\(npc.cclHits)\tdamage=\(this.Num(npc.cclDamage))\tsecs=\(this.Num(now - npc.cclFirstHit))\thpa=\(this.Num(this.HealthPct(game, npc.GetEntityID())))\twasdown=\(npc.cclDowned)\tbroke=\(npc.cclBroke)\tpdohead=\(npc.headhitcounter)\tpdotorso=\(npc.torsohitcounter)");
    this.MaybeFlush(now);
  }

  public final func OnVDeath(player: ref<GameObject>) -> Void {
    let now: Float = this.Now(player.GetGame());
    this.Write(s"vdead\tt=\(this.Num(now))");
    this.Flush(now);
  }

  // NPC shots come too fast to write singly, so they are counted and written every 5 seconds
  public final func OnShot(target: ref<GameObject>, owner: ref<GameObject>, weapon: wref<WeaponObject>, hit: Bool) -> Void {
    let npc: ref<NPCPuppet> = owner as NPCPuppet;
    if !IsDefined(npc) || !IsDefined(target) || !target.IsPlayer() || !IsDefined(weapon) {
      return;
    };
    let game: GameInstance = target.GetGame();
    let distance: Float = Vector4.Distance(weapon.GetWorldPosition(), target.GetWorldPosition());
    let range: String = distance < 10.00 ? "0-10" : distance < 25.00 ? "10-25" : distance < 50.00 ? "25-50" : "50+";
    let moving: String = VehicleComponent.IsMountedToVehicle(game, target) ? "car" : Vector4.Length((target as ScriptedPuppet).GetVelocity()) > 2.00 ? "moving" : "still";
    let key: String = s"rarity=\(npc.GetNPCRarity())\twtype=\(WeaponObject.GetWeaponType(weapon.GetItemID()))\trange=\(range)\tv=\(moving)";
    let i: Int32 = ArrayFindFirst(this.shotKeys, key);
    if i < 0 {
      ArrayPush(this.shotKeys, key);
      ArrayPush(this.shotRolls, 0);
      ArrayPush(this.shotHits, 0);
      i = ArraySize(this.shotKeys) - 1;
    };
    this.shotRolls[i] += 1;
    if hit {
      this.shotHits[i] += 1;
    };
    this.MaybeFlush(this.Now(game));
  }

  private final func MaybeFlush(now: Float) -> Void {
    this.lastNow = now;
    if now - this.lastFlush >= 5.00 || now < this.lastFlush {
      this.Flush(now);
    };
  }

  private final func Flush(now: Float) -> Void {
    this.lastFlush = now;
    let i: Int32 = 0;
    while i < ArraySize(this.shotKeys) {
      this.Write(s"shots\tt=\(this.Num(now))\t\(this.shotKeys[i])\trolls=\(this.shotRolls[i])\thits=\(this.shotHits[i])");
      i += 1;
    };
    ArrayClear(this.shotKeys);
    ArrayClear(this.shotRolls);
    ArrayClear(this.shotHits);
    // cut, stop and armor are averages per hit
    let j: Int32 = 0;
    while j < ArraySize(this.fights) {
      let f: ref<CombatLogFightBucket> = this.fights[j];
      let n: Float = Cast<Float>(f.hits);
      this.Write(s"npcfight\tt=\(this.Num(now))\t\(f.key)\thits=\(f.hits)\traw=\(this.Num(f.raw))\tdmg=\(this.Num(f.dmg))\tcut=\(this.Num(f.cut / n))\tstop=\(this.Num(f.stop / n))\tstopped=\(f.stopped)\tkills=\(f.kills)\tarmor=\(this.Num(f.armor / n))");
      j += 1;
    };
    ArrayClear(this.fights);
    this.WriteOut();
  }
}

// Writes what is still buffered when a session ends (load, main menu, quit)
public class CyberslopCombatLogFlusher extends ScriptableSystem {
  private func OnDetach() -> Void {
    let log: ref<CombatLog> = CombatLog.Get();
    if IsDefined(log) {
      log.FlushNow();
    };
  }
}

@wrapMethod(ScriptedPuppet)
protected cb func OnDamageReceived(evt: ref<gameDamageReceivedEvent>) -> Bool {
  let handled: Bool = wrappedMethod(evt);
  let log: ref<CombatLog> = CombatLog.Get();
  if IsDefined(log) {
    log.OnDamage(evt);
  };
  return handled;
}

@wrapMethod(GameObject)
protected final func ProcessDamageReceived(evt: ref<gameDamageReceivedEvent>) -> Void {
  wrappedMethod(evt);
  let log: ref<CombatLog> = CombatLog.Get();
  if IsDefined(log) {
    log.OnDamage(evt);
  };
}

// After the damage pipeline: attackComputed and the flags are final here (OnHit fires before it: the combat log rows
// had total=-1 and no flags)
@wrapMethod(NPCPuppet)
protected func DamagePipelineFinalized(evt: ref<gameHitEvent>) -> Void {
  wrappedMethod(evt);
  if !CombatLog.HitRows() {
    return;
  };
  let log: ref<CombatLog> = CombatLog.Get();
  if IsDefined(log) {
    log.OnHit(this, evt);
  };
}

@wrapMethod(ScriptedPuppet)
protected cb func OnDefeated(evt: ref<DefeatedEvent>) -> Bool {
  let handled: Bool = wrappedMethod(evt);
  let npc: ref<NPCPuppet> = this as NPCPuppet;
  let log: ref<CombatLog> = CombatLog.Get();
  if IsDefined(npc) && IsDefined(log) {
    log.OnOutcome(npc, "down");
  };
  return handled;
}

@wrapMethod(NPCPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
  let handled: Bool = wrappedMethod(evt);
  let log: ref<CombatLog> = CombatLog.Get();
  if IsDefined(log) {
    log.OnOutcome(this, "dead");
  };
  return handled;
}

@wrapMethod(PlayerPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
  let handled: Bool = wrappedMethod(evt);
  let log: ref<CombatLog> = CombatLog.Get();
  if IsDefined(log) {
    log.OnVDeath(this);
  };
  return handled;
}

@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
  // 10 New Quickhacks (zeusico_quickhacks) wraps this callback as -> Void and sorts just before zz_,
  // so take no value from wrappedMethod() here; the engine ignores a callback's return value.
  wrappedMethod();
  let log: ref<CombatLog> = CombatLog.Get();
  if IsDefined(log) {
    log.MarkSession();
  };
  return true;
}

// zz_ loads after Much Better AI, so this sees the final answer of its hit model
@wrapMethod(TargetShootComponent)
private final func ShouldBeHit(weaponOwner: ref<GameObject>, weapon: wref<WeaponObject>, weaponRecord: ref<WeaponItem_Record>, visibilityThresholdCoefficient: Float) -> Bool {
  let hit: Bool = wrappedMethod(weaponOwner, weapon, weaponRecord, visibilityThresholdCoefficient);
  let log: ref<CombatLog> = CombatLog.Get();
  if IsDefined(log) {
    log.OnShot(this.GetGameObject(), weaponOwner, weapon, hit);
  };
  return hit;
}
