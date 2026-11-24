// Cyberslop Corpse Ragdoll 1.0.1 (2026-11-21, game 2.5)
// Dead human NPCs that keep moving on the floor go limp, and stay limp.
//
// 1.0.0 (2026-11-20): after death, checked every 0.5 s for 10 s; forced the ragdoll on Defeated bodies at 1 s,
// on any other non-ragdolling body only at 10 s, and STOPPED watching as soon as a body read IsRagdolling() once.
// 1.0.1 (2026-11-21: two Gorilla Arms kills kept moving on the ground, 1.0.0 logged nothing for them):
//  - A body that died in the defeat state (IsAboutToBeDefeated / Defeated / defeated animation, read BEFORE the
//    vanilla OnDeath clears it) is forced from 1.0 s; every other dead body that is still animating from 2.0 s
//    (was 10 s: a Mantis Blades kill in testing moved for the whole 10 s).
//  - Watching no longer stops at the first IsRagdolling() == true: each body is checked for 30 s.
//  - NPCPuppet.OnRagdollDisabledEvent wrap: when anything turns a corpse's ragdoll off again (the body goes back
//    to an animation), it is forced limp again at the next check, and the 30 s watch restarts.
//  - A corpse that is ragdolling but keeps moving for 2 s straight (0.25 to 4 m/s, from 3 s after its ragdoll
//    started, player within 50 m) gets its ragdoll reset: disable, then forced again 0.1 s later. Max 2 per body.
//  - Forces use the no-power-pose ragdoll (fully limp at once, no animation pose driving the joints).
// Never touched: living NPCs (only bodies that got OnDeath and have 0 health), bodies in a workspot (finishers,
// scripted death poses), sync animations, grappled bodies, mounted bodies (vehicle, carried), a body V is carrying
// or dropping, bodies that cannot ragdoll (bosses, MaxTac). Robots, drones and mechs are not touched.

module CyberslopCorpseRagdoll

public abstract class CybCorpseRagdoll {
  public static func Log() -> Bool = true             // [CorpseRagdoll] lines in CET gamelog.log
  public static func Interval() -> Float = 0.5        // seconds between checks
  public static func WatchChecks() -> Int32 = 60      // 60 x 0.5 s = 30 s per watch (restarts when ragdoll is lost)
  public static func DefeatGrace() -> Float = 1.0     // died in the defeat state: force from 1.0 s after death
  public static func Grace() -> Float = 2.0           // any other dead body still animating: force from 2.0 s
  public static func MaxForces() -> Int32 = 8         // per body, all causes together
  public static func MaxResets() -> Int32 = 2         // ragdoll resets for corpses that keep moving
  public static func SettleTime() -> Float = 3.0      // motion counts only this long after the ragdoll started
  public static func MoveSpeed() -> Float = 0.25      // m/s: slower = lying still
  public static func FallSpeed() -> Float = 4.0       // m/s: faster = falling / thrown, never reset
  public static func MoveChecks() -> Int32 = 4        // 4 x 0.5 s = moving for 2 s straight
  public static func ResetRange() -> Float = 50.0     // resets only near the player

  public static func Write(message: String) -> Void {
    if CybCorpseRagdoll.Log() {
      FTLog("[CorpseRagdoll] " + message);
    }
  }
}

public class CybCorpseRagdollTick extends Event {
  public let generation: Int32;
  public let check: Int32;
}

public class CybCorpseRagdollReforce extends Event {}

@addField(NPCPuppet) private let cybCrGeneration: Int32;
@addField(NPCPuppet) private let cybCrDied: Bool;
@addField(NPCPuppet) private let cybCrDefeatDeath: Bool;
@addField(NPCPuppet) private let cybCrDeathTime: Float;
@addField(NPCPuppet) private let cybCrWatching: Bool;
@addField(NPCPuppet) private let cybCrForces: Int32;
@addField(NPCPuppet) private let cybCrResets: Int32;
@addField(NPCPuppet) private let cybCrResetPending: Bool;
@addField(NPCPuppet) private let cybCrLost: Int32;
@addField(NPCPuppet) private let cybCrLostPending: Bool;
@addField(NPCPuppet) private let cybCrForcePending: Bool;
@addField(NPCPuppet) private let cybCrRagdollSince: Float;
@addField(NPCPuppet) private let cybCrFirstRagdollT: Float;
@addField(NPCPuppet) private let cybCrMoving: Int32;
@addField(NPCPuppet) private let cybCrMaxSettledSpeed: Float;
@addField(NPCPuppet) private let cybCrLastSkip: String;
@addField(NPCPuppet) private let cybCrGaveUp: Bool;

@wrapMethod(NPCPuppet)
protected cb func OnDeath(evt: ref<gameDeathEvent>) -> Bool {
  // read the defeat state before vanilla OnDeath runs ClearDefeatAndImmortality()
  let defeatDeath = this.IsAboutToBeDefeated() || ScriptedPuppet.IsDefeated(this);
  let hrc = this.GetHitReactionComponent();
  if IsDefined(hrc) && hrc.GetDefeatedHasBeenPlayed() {
    defeatDeath = true;
  }
  let result = wrappedMethod(evt);
  // spawned already dead (quest / scene corpses, bodies streamed in): vanilla leaves their pose alone, so do we
  if this.IsHuman() && this.IsAttached() && !this.WasIncapacitatedOnAttach() {
    if !this.cybCrDied {
      this.cybCrDied = true;
      this.cybCrDeathTime = this.CybCrNow();
      this.cybCrDefeatDeath = defeatDeath;
      this.cybCrForces = 0;
      this.cybCrResets = 0;
      this.cybCrLost = 0;
      this.cybCrFirstRagdollT = -1.0;
      this.cybCrMaxSettledSpeed = 0.0;
      this.cybCrGaveUp = false;
    } else {
      this.cybCrDefeatDeath = this.cybCrDefeatDeath || defeatDeath;
    }
    this.CybCrStartWatch();
  }
  return result;
}

@wrapMethod(NPCPuppet)
protected cb func OnRagdollDisabledEvent(evt: ref<RagdollNotifyDisabledEvent>) -> Bool {
  let result = wrappedMethod(evt);
  if this.cybCrDied && this.IsAttached() && this.IsDead() {
    if this.cybCrResetPending {
      // our own reset: the re-force is already queued and the watch keeps running
      this.cybCrResetPending = false;
    } else {
      this.cybCrLost += 1;
      this.cybCrLostPending = true;
      CybCorpseRagdoll.Write(s"ragdoll off npc=\(this.CybCrId()) t=\(this.CybCrSinceDeath())s lost=\(this.cybCrLost)");
      // a fresh 30 s watch from now
      this.CybCrStartWatch();
    }
  }
  return result;
}

@addMethod(NPCPuppet)
private final func CybCrNow() -> Float {
  return EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGame()));
}

@addMethod(NPCPuppet)
private final func CybCrSinceDeath() -> Float {
  return this.CybCrNow() - this.cybCrDeathTime;
}

@addMethod(NPCPuppet)
private final func CybCrId() -> String {
  return s"\(EntityID.ToDebugString(this.GetEntityID())) record=\(TDBID.ToStringDEBUG(this.GetRecordID()))";
}

@addMethod(NPCPuppet)
private final func CybCrStartWatch() -> Void {
  this.cybCrGeneration += 1;
  this.cybCrWatching = true;
  this.cybCrRagdollSince = -1.0;
  this.cybCrMoving = 0;
  this.CybCrQueue(1, CybCorpseRagdoll.Interval());
}

@addMethod(NPCPuppet)
private final func CybCrQueue(check: Int32, delay: Float) -> Void {
  let tick = new CybCorpseRagdollTick();
  tick.generation = this.cybCrGeneration;
  tick.check = check;
  GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, tick, delay, false);
}

@addMethod(NPCPuppet)
private final func CybCrIsMounted() -> Bool {
  let info = GameInstance.GetMountingFacility(this.GetGame()).GetMountingInfoSingleWithObjects(this);
  return EntityID.IsDefined(info.parentId) || EntityID.IsDefined(info.childId);
}

@addMethod(NPCPuppet)
private final func CybCrPlayerDistance() -> Float {
  let player = GetPlayer(this.GetGame());
  if !IsDefined(player) { return 9999.0; }
  return Vector4.Distance(player.GetWorldPosition(), this.GetWorldPosition());
}

@addMethod(NPCPuppet)
private final func CybCrPlayerCarriesNearby() -> Bool {
  let player = GetPlayer(this.GetGame());
  if !IsDefined(player) { return false; }
  let bb = player.GetPlayerStateMachineBlackboard();
  if !IsDefined(bb) { return false; }
  if bb.GetInt(GetAllBlackboardDefs().PlayerStateMachine.BodyCarrying) == 0 { return false; }
  return Vector4.Distance(player.GetWorldPosition(), this.GetWorldPosition()) < 4.0;
}

@addMethod(NPCPuppet)
private final func CybCrSkipReason() -> String {
  if GameInstance.GetWorkspotSystem(this.GetGame()).IsActorInWorkspot(this) { return "workspot"; }
  if StatusEffectSystem.ObjectHasStatusEffect(this, t"WorkspotStatus.SyncAnimation") { return "sync_animation"; }
  if ScriptedPuppet.IsBeingGrappled(this) { return "grappled"; }
  if this.CybCrIsMounted() { return "mounted"; }
  if this.CybCrPlayerCarriesNearby() { return "carried"; }
  if !ScriptedPuppet.CanRagdoll(this) { return "cannot_ragdoll"; }
  return "";
}

@addMethod(NPCPuppet)
private final func CybCrForce(reason: String) -> Void {
  if this.cybCrForces >= CybCorpseRagdoll.MaxForces() {
    if !this.cybCrGaveUp {
      this.cybCrGaveUp = true;
      CybCorpseRagdoll.Write(s"gave up npc=\(this.CybCrId()) forces=\(this.cybCrForces) t=\(this.CybCrSinceDeath())s");
    }
    return;
  }
  this.cybCrForces += 1;
  this.cybCrForcePending = true;
  CybCorpseRagdoll.Write(s"force npc=\(this.CybCrId()) reason=\(reason) defeatDeath=\(this.cybCrDefeatDeath) t=\(this.CybCrSinceDeath())s try=\(this.cybCrForces)");
  this.QueueEvent(CreateForceRagdollNoPowerPoseEvent(n"CyberslopCorpseRagdoll"));
}

@addMethod(NPCPuppet)
protected cb func OnCybCorpseRagdollReforce(evt: ref<CybCorpseRagdollReforce>) -> Bool {
  if !this.cybCrDied || !this.IsAttached() || !this.IsDead() { return false; }
  this.cybCrResetPending = false;
  if !this.IsRagdolling() {
    this.cybCrForcePending = true;
    this.QueueEvent(CreateForceRagdollNoPowerPoseEvent(n"CyberslopCorpseRagdoll_reset"));
  }
  return true;
}

@addMethod(NPCPuppet)
private final func CybCrSummary(reason: String) -> Void {
  CybCorpseRagdoll.Write(s"done npc=\(this.CybCrId()) end=\(reason) defeatDeath=\(this.cybCrDefeatDeath) firstRagdoll=\(this.cybCrFirstRagdollT)s ragdollNow=\(this.IsRagdolling()) lost=\(this.cybCrLost) forces=\(this.cybCrForces) resets=\(this.cybCrResets) maxSettledSpeed=\(this.cybCrMaxSettledSpeed) lastSkip=\(this.cybCrLastSkip) t=\(this.CybCrSinceDeath())s");
}

@addMethod(NPCPuppet)
protected cb func OnCybCorpseRagdollTick(evt: ref<CybCorpseRagdollTick>) -> Bool {
  if evt.generation != this.cybCrGeneration { return false; }
  if !this.IsAttached() {
    this.cybCrWatching = false;
    return false;
  }
  if !this.IsDead() {
    // resurrected / healed: not a corpse any more
    this.cybCrDied = false;
    this.cybCrWatching = false;
    CybCorpseRagdoll.Write(s"alive again npc=\(this.CybCrId())");
    return false;
  }

  let now = this.CybCrNow();
  let t = now - this.cybCrDeathTime;
  let last = evt.check >= CybCorpseRagdoll.WatchChecks();
  let skip = this.CybCrSkipReason();
  if NotEquals(skip, this.cybCrLastSkip) && NotEquals(skip, "") {
    CybCorpseRagdoll.Write(s"skip npc=\(this.CybCrId()) reason=\(skip) ragdoll=\(this.IsRagdolling()) t=\(t)s");
  }
  if NotEquals(skip, "") {
    this.cybCrLastSkip = skip;
  }

  if this.IsRagdolling() {
    this.cybCrLostPending = false;
    if this.cybCrRagdollSince < 0.0 {
      this.cybCrRagdollSince = now;
      this.cybCrMoving = 0;
      if this.cybCrFirstRagdollT < 0.0 {
        this.cybCrFirstRagdollT = t;
      }
      if this.cybCrForcePending {
        CybCorpseRagdoll.Write(s"ragdoll on npc=\(this.CybCrId()) t=\(t)s forces=\(this.cybCrForces)");
      }
    }
    this.cybCrForcePending = false;

    // ragdolling but still moving long after it should have settled
    let speed = Vector4.Length(this.GetVelocity());
    let settled = now - this.cybCrRagdollSince >= CybCorpseRagdoll.SettleTime();
    if settled && speed > this.cybCrMaxSettledSpeed {
      this.cybCrMaxSettledSpeed = speed;
    }
    if settled && Equals(skip, "") && speed >= CybCorpseRagdoll.MoveSpeed() && speed < CybCorpseRagdoll.FallSpeed() {
      this.cybCrMoving += 1;
    } else {
      this.cybCrMoving = 0;
    }
    if this.cybCrMoving >= CybCorpseRagdoll.MoveChecks() {
      this.cybCrMoving = 0;
      if this.cybCrResets < CybCorpseRagdoll.MaxResets() && this.cybCrForces < CybCorpseRagdoll.MaxForces()
        && this.CybCrPlayerDistance() <= CybCorpseRagdoll.ResetRange() {
        this.cybCrResets += 1;
        this.cybCrForces += 1;
        this.cybCrResetPending = true;
        this.cybCrRagdollSince = -1.0;
        CybCorpseRagdoll.Write(s"reset npc=\(this.CybCrId()) speed=\(speed) t=\(t)s reset=\(this.cybCrResets)");
        this.QueueEvent(CreateDisableRagdollEvent(n"CyberslopCorpseRagdoll_reset"));
        let reforce = new CybCorpseRagdollReforce();
        GameInstance.GetDelaySystem(this.GetGame()).DelayEvent(this, reforce, 0.1, false);
      } else {
        CybCorpseRagdoll.Write(s"still moving npc=\(this.CybCrId()) speed=\(speed) t=\(t)s resets=\(this.cybCrResets) (no reset left / too far)");
      }
    }
  } else {
    this.cybCrRagdollSince = -1.0;
    this.cybCrMoving = 0;
    if Equals(skip, "") {
      let defeatNow = ScriptedPuppet.IsDefeated(this);
      let hrc = this.GetHitReactionComponent();
      if IsDefined(hrc) && hrc.GetDefeatedHasBeenPlayed() {
        defeatNow = true;
      }
      let defeat = this.cybCrDefeatDeath || defeatNow;
      if this.cybCrLostPending {
        this.CybCrForce("ragdoll_lost");
      } else {
        if defeat && t >= CybCorpseRagdoll.DefeatGrace() {
          this.CybCrForce("defeat_death");
        } else {
          if t >= CybCorpseRagdoll.Grace() {
            this.CybCrForce("not_limp");
          }
        }
      }
    }
  }

  if last {
    // carried / grappled / in a vehicle / in a sync animation right now: keep watching (every 2 s) until it is let go,
    // so a body dropped after 30 s is still checked
    if Equals(skip, "carried") || Equals(skip, "mounted") || Equals(skip, "grappled") || Equals(skip, "sync_animation") {
      this.CybCrQueue(evt.check, 2.0);
      return true;
    }
    this.cybCrWatching = false;
    this.CybCrSummary("watch_end");
    return true;
  }
  this.CybCrQueue(evt.check + 1, CybCorpseRagdoll.Interval());
  return true;
}
