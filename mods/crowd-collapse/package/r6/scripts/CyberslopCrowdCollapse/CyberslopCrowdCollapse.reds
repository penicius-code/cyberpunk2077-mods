// Cyberslop Crowd Collapse 1.0.0 (2026-11-22). Built for game 2.5.
//
// System Collapse knocks crowd NPCs out.
//
// Cause: in 2.5 System Collapse knocks a target out only through the AI's status-effect behaviour
// (BaseStatusEffect.SystemCollapse AIData, SystemCollapseManagerTask). Crowd NPCs run the reduced crowd AI, which has
// no behaviour for it, because vanilla never lets crowd NPCs be hit by System Collapse. Hackable Civilians adds the quickhack
// to crowd records, so it uploads and lands with no knockout. The only effect left is Quickhack_Fixes' TriggerGLP damage
// hit (killTriggerCollapse.yaml). If that hit reaches 0 HP, Quickhack_Fixes' OnPotentialDeath branch applies no
// Unconscious / Defeated either (it leaves the fall to the System Collapse behaviour), so the NPC would stand at 0 HP.
// Seen in testing (JunkieFemale, three casts; TenantWoman, 60 -> 25 HP, stagger only).
//
// Fix: 0.1 s after System Collapse lands on a living crowd NPC (after the damage hit resolves), apply the vanilla knockout
// BaseStatusEffect.Unconscious from the caster (the effect vanilla OnPotentialDeath gives a crowd NPC knocked out
// non-lethally) and a ragdoll so the body drops. Regular NPCs keep the vanilla / Quickhack_Fixes path.
// Skipped: children, god-mode NPCs (quest-protected), NPCs with UnconsciousImmunity, anyone already down or dead.
// Log: one [CrowdCollapse] line per knockout or skip in the CET gamelog.log (buffered: flushed in 4 KB blocks / at quit).

module CyberslopCrowdCollapse

public class CrowdCollapseCallback extends DelayCallback {
  public let npc: wref<NPCPuppet>;
  public let instigator: EntityID;

  public func Call() -> Void {
    let npc: ref<NPCPuppet> = this.npc;
    if !IsDefined(npc) {
      return;
    };
    CrowdCollapse.KnockOut(npc, this.instigator);
  }
}

public abstract class CrowdCollapse {

  public static func Name(npc: ref<NPCPuppet>) -> String {
    return TDBID.ToStringDEBUG(npc.GetRecordID());
  }

  public static func IsDown(npc: ref<NPCPuppet>) -> Bool {
    return !ScriptedPuppet.IsAlive(npc) || ScriptedPuppet.IsUnconscious(npc) || ScriptedPuppet.IsDefeated(npc);
  }

  // Why this NPC must not be knocked out by us ("" = go ahead)
  public static func SkipReason(npc: ref<NPCPuppet>) -> String {
    if CrowdCollapse.IsDown(npc) {
      return "already down";
    };
    if npc.IsCharacterChildren() {
      return "child";
    };
    let god: ref<GodModeSystem> = GameInstance.GetGodModeSystem(npc.GetGame());
    if IsDefined(god) && (god.HasGodMode(npc.GetEntityID(), gameGodModeType.Immortal) || god.HasGodMode(npc.GetEntityID(), gameGodModeType.Invulnerable)) {
      return "god mode";
    };
    if GameInstance.GetStatsSystem(npc.GetGame()).GetStatValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatType.UnconsciousImmunity) > 0.00 {
      return "UnconsciousImmunity";
    };
    return "";
  }

  public static func KnockOut(npc: ref<NPCPuppet>, instigator: EntityID) -> Void {
    let reason: String = CrowdCollapse.SkipReason(npc);
    let hp: Float = GameInstance.GetStatPoolsSystem(npc.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatPoolType.Health, true);
    if NotEquals(reason, "") {
      FTLog(s"[CrowdCollapse] \(CrowdCollapse.Name(npc)) skipped: \(reason) (hp=\(RoundF(hp))%)");
      return;
    };
    let killer: ref<GameObject> = GameInstance.FindEntityByID(npc.GetGame(), instigator) as GameObject;
    if IsDefined(killer) {
      npc.SetMyKiller(killer);
    };
    StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.Unconscious", instigator);
    npc.QueueEvent(CreateForceRagdollEvent(n"CyberslopCrowdCollapse"));
    FTLog(s"[CrowdCollapse] \(CrowdCollapse.Name(npc)) knocked out (hp=\(RoundF(hp))%, unconscious=\(ScriptedPuppet.IsUnconscious(npc)))");
  }
}

@wrapMethod(NPCPuppet)
protected cb func OnStatusEffectApplied(evt: ref<ApplyStatusEffectEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  if this.IsCrowd() && !evt.isAppliedOnSpawn && IsDefined(evt.staticData)
      && ArrayContains(evt.staticData.GameplayTags(), n"SystemCollapse") && !CrowdCollapse.IsDown(this) {
    let cb: ref<CrowdCollapseCallback> = new CrowdCollapseCallback();
    cb.npc = this;
    cb.instigator = evt.instigatorEntityID;
    GameInstance.GetDelaySystem(this.GetGame()).DelayCallback(cb, 0.10, false);
  };
  return result;
}
