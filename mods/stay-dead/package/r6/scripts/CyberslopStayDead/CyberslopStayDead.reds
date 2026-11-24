// Cyberslop Stay Dead 1.0.0 (2026-11-01). Downed open-world NPCs stay away for days.
//
// Vanilla has no respawn timer: death and knockout persist per NPC on its persistent state, and the
// community system respawns the slot natively whenever it decides to. This mod remembers every
// community NPC V put down (killed: "dead"; knocked out or bleeding out: "hospital") with the game
// time, and when the same NPC comes back alive too early it is destroyed on spawn (no body, no loot,
// no XP). Knocked-out bodies are picked up ("hospital") after a while once V is away from them.
//
// Not tracked: quest NPCs, companions, crowd, police (prevention system), and anything that is not a
// community spawn (EDO, TWR, reinforcement squads have no stable identity).

public class CyberslopStayDeadSettings extends ScriptableSystem {

  @runtimeProperty("ModSettings.mod", "Cyberslop Stay Dead")
  @runtimeProperty("ModSettings.category", "Respawn")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Enabled")
  @runtimeProperty("ModSettings.description", "Off: vanilla respawn, bodies stay where they fell. Records keep being written.")
  public let enabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Cyberslop Stay Dead")
  @runtimeProperty("ModSettings.category", "Respawn")
  @runtimeProperty("ModSettings.displayName", "Killed: away for (game days)")
  @runtimeProperty("ModSettings.description", "A killed NPC that respawns before this many game days have passed is removed on spawn.")
  @runtimeProperty("ModSettings.step", "0.5")
  @runtimeProperty("ModSettings.min", "0.5")
  @runtimeProperty("ModSettings.max", "30.0")
  public let deadDays: Float = 14.0;

  @runtimeProperty("ModSettings.mod", "Cyberslop Stay Dead")
  @runtimeProperty("ModSettings.category", "Respawn")
  @runtimeProperty("ModSettings.displayName", "Knocked out: away for (game days)")
  @runtimeProperty("ModSettings.description", "A knocked out or bleeding out NPC is in hospital this long before it can be back.")
  @runtimeProperty("ModSettings.step", "0.5")
  @runtimeProperty("ModSettings.min", "0.5")
  @runtimeProperty("ModSettings.max", "30.0")
  public let hospitalDays: Float = 3.0;

  @runtimeProperty("ModSettings.mod", "Cyberslop Stay Dead")
  @runtimeProperty("ModSettings.category", "Respawn")
  @runtimeProperty("ModSettings.displayName", "Knocked out: body picked up after (game minutes)")
  @runtimeProperty("ModSettings.description", "The unconscious body vanishes this long after the knockout, once you are more than 30 m away.")
  @runtimeProperty("ModSettings.step", "5.0")
  @runtimeProperty("ModSettings.min", "5.0")
  @runtimeProperty("ModSettings.max", "120.0")
  public let hospitalPickupMinutes: Float = 20.0;

  @runtimeProperty("ModSettings.mod", "Cyberslop Stay Dead")
  @runtimeProperty("ModSettings.category", "Debug")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.displayName", "Log")
  @runtimeProperty("ModSettings.description", "Writes [StayDead] lines to CET's gamelog.log.")
  public let logEnabled: Bool = true;

  private func OnAttach() -> Void {
    ModSettings.RegisterListenerToClass(this);
    ModSettings.RegisterListenerToModifications(this);
  }

  private func OnDetach() -> Void {
    ModSettings.UnregisterListenerToClass(this);
    ModSettings.UnregisterListenerToModifications(this);
  }

  public static func Get() -> ref<CyberslopStayDeadSettings> {
    return GameInstance.GetScriptableSystemsContainer(GetGameInstance())
      .Get(n"CyberslopStayDeadSettings") as CyberslopStayDeadSettings;
  }
}

public func CsdLog(text: String) -> Void {
  let settings: ref<CyberslopStayDeadSettings> = CyberslopStayDeadSettings.Get();
  if IsDefined(settings) && settings.logEnabled {
    FTLog("[StayDead] " + text);
  };
}

public func CsdNow(game: GameInstance) -> Float {
  return GameInstance.GetTimeSystem(game).GetGameTimeStamp();
}

// The records: one entry per NPC, saved with the game (ScriptableSystem persistent fields).
public class CyberslopStayDeadSystem extends ScriptableSystem {
  private persistent let m_ids: array<Uint64>;
  private persistent let m_times: array<Float>;
  private persistent let m_dead: array<Bool>;

  public static func Get(game: GameInstance) -> ref<CyberslopStayDeadSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"CyberslopStayDeadSystem") as CyberslopStayDeadSystem;
  }

  public final func Find(id: Uint64) -> Int32 {
    let i: Int32 = 0;
    while i < ArraySize(this.m_ids) {
      if this.m_ids[i] == id {
        return i;
      };
      i += 1;
    };
    return -1;
  }

  public final func Count() -> Int32 {
    return ArraySize(this.m_ids);
  }

  public final func GetTime(index: Int32) -> Float {
    return this.m_times[index];
  }

  public final func IsDead(index: Int32) -> Bool {
    return this.m_dead[index];
  }

  // A new downing replaces the time; hospital can become dead, never the other way round
  public final func Record(id: Uint64, now: Float, dead: Bool) -> Void {
    let index: Int32 = this.Find(id);
    if index >= 0 {
      this.m_times[index] = now;
      this.m_dead[index] = this.m_dead[index] || dead;
      return;
    };
    ArrayPush(this.m_ids, id);
    ArrayPush(this.m_times, now);
    ArrayPush(this.m_dead, dead);
  }

  public final func Remove(index: Int32) -> Void {
    ArrayErase(this.m_ids, index);
    ArrayErase(this.m_times, index);
    ArrayErase(this.m_dead, index);
  }

  // Entries whose limit has passed are dropped, so the list never grows past what still matters
  public final func Prune(now: Float, deadLimit: Float, hospitalLimit: Float) -> Void {
    let i: Int32 = ArraySize(this.m_ids) - 1;
    while i >= 0 {
      if now - this.m_times[i] > (this.m_dead[i] ? deadLimit : hospitalLimit) {
        this.Remove(i);
      };
      i -= 1;
    };
  }
}

public class CsdPickupCallback extends DelayCallback {
  public let npc: wref<NPCPuppet>;

  public func Call() -> Void {
    if IsDefined(this.npc) {
      this.npc.CsdPickupCheck();
    };
  }
}

public class CsdRemoveCallback extends DelayCallback {
  public let npc: wref<NPCPuppet>;
  public let reason: String;

  public func Call() -> Void {
    if IsDefined(this.npc) {
      this.npc.CsdDestroy(this.reason);
    };
  }
}

@addField(NPCPuppet)
private let m_csdPickupQueued: Bool;

// Record a fresh downing (Unconscious, Defeated or death). Re-attached bodies return early in
// vanilla before this runs again (IsIncapacitated), so the extra check is just a guard.
@wrapMethod(NPCPuppet)
protected func OnIncapacitated() -> Void {
  let fresh: Bool = !this.GetPS().GetWasIncapacitated() && !this.WasIncapacitatedOnAttach();
  wrappedMethod();
  if fresh {
    this.CsdRecordDown(this.GetPS().GetIsDead());
  };
}

// A body finished off later (or a death that skipped OnIncapacitated's fresh path) becomes "dead"
@wrapMethod(ScriptedPuppet)
protected func OnDied() -> Void {
  wrappedMethod();
  let npc: ref<NPCPuppet> = this as NPCPuppet;
  if IsDefined(npc) && !npc.WasIncapacitatedOnAttach() {
    npc.CsdRecordDown(true);
  };
}

@wrapMethod(NPCPuppet)
protected cb func OnGameAttached() -> Bool {
  let result: Bool = wrappedMethod();
  this.CsdOnAttached();
  return result;
}

// Only community spawns have a stable EntityID; everything dynamic is skipped
@addMethod(NPCPuppet)
private final func CsdIsTracked() -> Bool {
  if !Equals(this.GetNPCType(), gamedataNPCType.Human) || this.IsQuest() || this.IsCrowd() || this.IsPrevention() || ScriptedPuppet.IsPlayerCompanion(this) {
    return false;
  };
  let stubID: PersistentID = CreatePersistentID(this.GetEntityID(), gameEntityStubComponentPS.GetPSComponentName());
  let stub: ref<gameEntityStubComponentPS> = GameInstance.GetPersistencySystem(this.GetGame()).GetConstAccessToPSObject(stubID, n"gameEntityStubComponentPS") as gameEntityStubComponentPS;
  return IsDefined(stub) && EntityID.IsDefined(stub.GetSpawnerID());
}

@addMethod(NPCPuppet)
private final func CsdKey() -> Uint64 {
  return Cast<Uint64>(EntityID.GetHash(this.GetEntityID()));
}

@addMethod(NPCPuppet)
private final func CsdName() -> String {
  return TDBID.ToStringDEBUG(this.GetRecordID());
}

@addMethod(NPCPuppet)
public final func CsdRecordDown(dead: Bool) -> Void {
  let game: GameInstance = this.GetGame();
  let player: ref<PlayerPuppet> = GetPlayer(game);
  let system: ref<CyberslopStayDeadSystem> = CyberslopStayDeadSystem.Get(game);
  let settings: ref<CyberslopStayDeadSettings> = CyberslopStayDeadSettings.Get();
  if !IsDefined(system) || !IsDefined(settings) || !IsDefined(player) || player.IsReplacer() || !this.CsdIsTracked() {
    return;
  };
  let now: Float = CsdNow(game);
  let key: Uint64 = this.CsdKey();
  let index: Int32 = system.Find(key);
  if index >= 0 && system.IsDead(index) {
    // Already booked as dead, nothing changes
    return;
  };
  system.Prune(now, settings.deadDays * 86400.00, settings.hospitalDays * 86400.00);
  system.Record(key, now, dead);
  CsdLog(s"\(this.CsdName()) recorded \(dead ? "dead" : "hospital"), away \(dead ? settings.deadDays : settings.hospitalDays) game days (\(system.Count()) records)");
  if !dead && settings.enabled {
    this.CsdQueuePickup(30.00);
  };
}

@addMethod(NPCPuppet)
private final func CsdQueuePickup(seconds: Float) -> Void {
  if this.m_csdPickupQueued {
    return;
  };
  this.m_csdPickupQueued = true;
  let callback: ref<CsdPickupCallback> = new CsdPickupCallback();
  callback.npc = this;
  GameInstance.GetDelaySystem(this.GetGame()).DelayCallback(callback, seconds, false);
}

// Every 30 s: once the pickup time has passed and V is away, the unconscious body is gone
@addMethod(NPCPuppet)
public final func CsdPickupCheck() -> Void {
  this.m_csdPickupQueued = false;
  let game: GameInstance = this.GetGame();
  let system: ref<CyberslopStayDeadSystem> = CyberslopStayDeadSystem.Get(game);
  let settings: ref<CyberslopStayDeadSettings> = CyberslopStayDeadSettings.Get();
  let player: ref<GameObject> = GetPlayer(game);
  if !IsDefined(system) || !IsDefined(settings) || !settings.enabled || !IsDefined(player) || !this.IsAttached() {
    return;
  };
  let index: Int32 = system.Find(this.CsdKey());
  if index < 0 || system.IsDead(index) || this.GetPS().GetIsDead() {
    // Died after all (V finished the body): the corpse is left to the native despawn
    return;
  };
  if this.GetPuppetStateBlackboard().GetBool(GetAllBlackboardDefs().PuppetState.IsBodyDisposed) {
    // In a container: vanilla hid it already
    return;
  };
  let due: Bool = CsdNow(game) - system.GetTime(index) >= settings.hospitalPickupMinutes * 60.00;
  let away: Bool = Vector4.Distance(player.GetWorldPosition(), this.GetWorldPosition()) > 30.00;
  let held: Bool = ScriptedPuppet.IsBeingGrappled(this) || VehicleComponent.IsMountedToVehicle(game, this) || GameInstance.GetSceneSystem(game).GetScriptInterface().IsEntityInScene(this.GetEntityID());
  if due && away && !held {
    this.CsdDestroy("hospital pickup");
    return;
  };
  this.CsdQueuePickup(30.00);
}

// On every stream-in: a body past its pickup time goes; an NPC back alive too early goes too
@addMethod(NPCPuppet)
private final func CsdOnAttached() -> Void {
  let game: GameInstance = this.GetGame();
  if GameInstance.GetSystemRequestsHandler().IsPreGame() {
    return;
  };
  let system: ref<CyberslopStayDeadSystem> = CyberslopStayDeadSystem.Get(game);
  let settings: ref<CyberslopStayDeadSettings> = CyberslopStayDeadSettings.Get();
  let player: ref<PlayerPuppet> = GetPlayer(game);
  if !IsDefined(system) || !IsDefined(settings) || !settings.enabled || !IsDefined(player) || player.IsReplacer() || system.Count() == 0 {
    return;
  };
  if !this.CsdIsTracked() {
    return;
  };
  let index: Int32 = system.Find(this.CsdKey());
  if index < 0 {
    return;
  };
  let now: Float = CsdNow(game);
  let age: Float = now - system.GetTime(index);
  let dead: Bool = system.IsDead(index);
  if this.GetPS().GetWasIncapacitated() {
    // Still a body. Dead ones are the native despawn's business, hospital ones ours
    if !dead {
      if age >= settings.hospitalPickupMinutes * 60.00 {
        this.CsdQueueDestroy("hospital pickup on stream-in", 0.05);
      } else {
        this.CsdQueuePickup(30.00);
      };
    };
    return;
  };
  // Alive again: the community respawned the slot
  let limit: Float = (dead ? settings.deadDays : settings.hospitalDays) * 86400.00;
  if age < limit {
    CsdLog(s"\(this.CsdName()) back alive after \(age / 3600.00) game h, \(dead ? "dead" : "hospital") limit \(limit / 86400.00) days: removed");
    this.CsdQueueDestroy("too early", 0.05);
    return;
  };
  CsdLog(s"\(this.CsdName()) back alive after \(age / 3600.00) game h, \(dead ? "dead" : "hospital") limit \(limit / 86400.00) days: allowed");
  system.Remove(index);
}

@addMethod(NPCPuppet)
private final func CsdQueueDestroy(reason: String, seconds: Float) -> Void {
  let callback: ref<CsdRemoveCallback> = new CsdRemoveCallback();
  callback.npc = this;
  callback.reason = reason;
  GameInstance.GetDelaySystem(this.GetGame()).DelayCallback(callback, seconds, false);
}

// The same call Night City Remembers uses to cull a spawn: the entity is gone, no death, no loot
@addMethod(NPCPuppet)
public final func CsdDestroy(reason: String) -> Void {
  if !this.IsAttached() {
    return;
  };
  CsdLog(s"\(this.CsdName()) destroyed: \(reason)");
  EntityGameInterface.Destroy(this.GetEntity());
}
