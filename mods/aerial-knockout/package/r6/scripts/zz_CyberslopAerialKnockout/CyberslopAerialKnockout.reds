// Cyberslop Aerial Knockout 1.1.0 (2026-11-26)
// The unarmed aerial takedown (drop on an enemy, head smashed into the ground) knocks out again.
//
// Why it killed: A.I.O (all in one) (Nexus 13049) ships the CET mod `assassinatefixbro`, whose onInit sets
// Effectors.PlayerNonLethalAerialTakedown.statusEffect = BaseStatusEffect.ForceKill. CET runs after TweakXL,
// so it also overwrote Zeusico Solo's marker (BaseStatusEffect.SoloAerialTakedownMarker -> Unconscious).
//
// 1. On every player attach (after all CET onInit handlers have run) the effector points back at
//    Zeusico's Solo marker when that record exists (keeps the Solo neutralize count), else at Unconscious.
// 2. Mantis Blades aerial takedowns (a blade through the neck) stay lethal: the takedown is sent with
//    the vanilla `kill` tag (Effectors.PlayerLethalTakedown, ForceKill) instead of the aerial knockout tag.
// The A.I.O blunt finisher edits (hammer / one- and two-handed blunt finishers kill) are left alone.
// 3. (1.1.0) The victim no longer stands up before dropping. The game applies the knockout 1.8 s after the
//    synced clip starts (DurationPrereq of Effectors.PlayerNonLethalAerialTakedown) for every variant, but the
//    slam lands at 0.93 s from behind and 1.57 s from the front (Takedown System's clip timings). In the back
//    clip the victim's side ends well before 1.8 s, so the AI got up and was then knocked down by the timer.
//    Now Unconscious is applied at impact + 0.22 s (the game's own front-clip lag): 1.15 s back, 1.80 s front.
//    The game's 1.8 s effector still fires afterwards (Solo count kept; Unconscious has max 1 stack).
module CyberslopAerialKnockout

public class AerialKnockoutDropCallback extends DelayCallback {
  public let npc: wref<NPCPuppet>;
  public let instigator: EntityID;
  public let side: String;

  public func Call() -> Void {
    let npc: ref<NPCPuppet> = this.npc;
    if !IsDefined(npc) || !npc.IsAttached() || npc.IsDead() {
      return;
    };
    if StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.Unconscious")
      || StatusEffectSystem.ObjectHasStatusEffect(npc, t"BaseStatusEffect.ForceKill") {
      return;
    };
    StatusEffectHelper.ApplyStatusEffect(npc, t"BaseStatusEffect.Unconscious", this.instigator);
    FTLog("[AerialKnockout] knocked out at impact (" + this.side + ")");
  }
}

public class AerialKnockoutSystem extends ScriptableSystem {
  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    if !IsDefined(request.owner as PlayerPuppet) {
      return;
    };
    AerialKnockoutRestore();
  }
}

public func AerialKnockoutRestore() -> Void {
  let flat: TweakDBID = t"Effectors.PlayerNonLethalAerialTakedown.statusEffect";
  let want: TweakDBID = t"BaseStatusEffect.Unconscious";
  if IsDefined(TweakDBInterface.GetStatusEffectRecord(t"BaseStatusEffect.SoloAerialTakedownMarker")) {
    want = t"BaseStatusEffect.SoloAerialTakedownMarker";
  };
  let have: TweakDBID = FromVariant<TweakDBID>(TweakDBInterface.GetFlat(flat));
  if Equals(have, want) {
    return;
  };
  TweakDBManager.SetFlat(flat, want);
  TweakDBManager.UpdateRecord(t"Effectors.PlayerNonLethalAerialTakedown");
  FTLog("[AerialKnockout] aerial takedown effect " + TDBID.ToStringDEBUG(have) + " -> " + TDBID.ToStringDEBUG(want));
}

public func AerialKnockoutHasMantisBlades(owner: wref<GameObject>) -> Bool {
  let weapon: ref<WeaponObject> = ScriptedPuppet.GetWeaponRight(owner);
  if !IsDefined(weapon) {
    return false;
  };
  let rec: ref<WeaponItem_Record> = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(weapon.GetItemID()));
  if !IsDefined(rec) || !IsDefined(rec.ItemType()) {
    return false;
  };
  return Equals(rec.ItemType().Type(), gamedataItemType.Cyb_MantisBlades);
}

@wrapMethod(LocomotionTakedownEvents)
private final func DefeatTarget(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>, activator: wref<GameObject>, target: wref<GameObject>, effectName: CName, effectTag: CName) -> Void {
  if Equals(effectTag, n"setUnconsciousAerialTakedown") && AerialKnockoutHasMantisBlades(activator) {
    let npc: ref<NPCPuppet> = target as NPCPuppet;
    if IsDefined(npc) {
      npc.SetMyKiller(activator);
    };
    wrappedMethod(stateContext, scriptInterface, activator, target, effectName, n"kill");
    return;
  };
  if Equals(effectTag, n"setUnconsciousAerialTakedown") {
    AerialKnockoutScheduleDrop(activator, target);
  };
  wrappedMethod(stateContext, scriptInterface, activator, target, effectName, effectTag);
}

// Same side test as LocomotionTakedownEvents.SelectAerialTakedownWorkspot (run just before this call).
public func AerialKnockoutScheduleDrop(activator: wref<GameObject>, target: wref<GameObject>) -> Void {
  let npc: ref<NPCPuppet> = target as NPCPuppet;
  if !IsDefined(npc) || !IsDefined(activator) {
    return;
  };
  let back: Bool = AbsF(Vector4.GetAngleBetween(activator.GetWorldForward(), target.GetWorldForward())) < 90.00;
  let cb: ref<AerialKnockoutDropCallback> = new AerialKnockoutDropCallback();
  cb.npc = npc;
  cb.instigator = activator.GetEntityID();
  cb.side = back ? "back" : "front";
  GameInstance.GetDelaySystem(activator.GetGame()).DelayCallback(cb, back ? 1.15 : 1.80);
}
