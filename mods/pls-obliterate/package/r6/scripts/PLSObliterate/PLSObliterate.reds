// PLSObliterate.reds 1.1.1
// Projectile Launch System explosions obliterate the NPCs they hit
// (the Spontaneous Obliteration dismember-kill), independent of the perk.
// Bosses and MaxTac are excluded, like vanilla.
// Install: Drop PLSObliterate folder into r6/scripts/
//
// Mod Settings (optional): "PLS Obliterate" > "Lethal hits only".
//   Off (default): every PLS blast obliterates the NPCs it hits.
//   On: only PLS hits that kill obliterate.
// Without Mod Settings the default applies. The optional file
// "PLSObliterate Lethal Only" has lethal hits only built in (same path,
// install one or the other).
//
// 1.1.0 wraps ProcessWoundsAndDismemberment instead of replacing
// IsValidBodyPerkDismemberAttack. The game sends every explosion hit to its
// explosion gore before that method runs, so 1.0.0's PLS branch never fired.
// No @replaceMethod anymore: works next to other mods that replace
// IsValidBodyPerkDismemberAttack (e.g. Revolver x Obliteration).
//
// 1.1.1 obliterates through its own copy of the vanilla Spontaneous
// Obliteration body (hit part, then 80 % each for head, torso, arms, legs)
// instead of calling ProcessBodyPerkDismembement. Mods that replace that
// method (e.g. Obliterate Dismemberment Fix, which keeps only the hit part)
// left PLS blasts cutting off a single leg.

public class PLSObliterateSettings extends ScriptableSystem {

  @runtimeProperty("ModSettings.mod", "PLS Obliterate")
  @runtimeProperty("ModSettings.displayName", "Lethal hits only")
  @runtimeProperty("ModSettings.description", "On: only Projectile Launch System hits that kill obliterate. Off: every PLS blast obliterates the NPCs it hits.")
  public let lethalOnly: Bool = false;

  public static func Get(gi: GameInstance) -> ref<PLSObliterateSettings> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"PLSObliterateSettings") as PLSObliterateSettings;
  }

  public static func LethalOnly(gi: GameInstance) -> Bool {
    let settings: ref<PLSObliterateSettings> = PLSObliterateSettings.Get(gi);
    return IsDefined(settings) && settings.lethalOnly;
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

@wrapMethod(HitReactionComponent)
protected final func ProcessWoundsAndDismemberment() -> Void {
  if this.PLSO_ShouldObliterate() {
    this.PLSO_Obliterate();
    return;
  };
  wrappedMethod();
}

@addMethod(HitReactionComponent)
private final func PLSO_ShouldObliterate() -> Bool {
  let instigator: ref<GameObject>;
  if !IsDefined(this.m_attackData) || !AttackData.IsExplosion(this.m_attackData.GetAttackType()) {
    return false;
  };
  // PLS rounds are the source of their own blast
  if !IsDefined(this.m_attackData.GetSource() as ProjectileLauncherRound) {
    return false;
  };
  instigator = this.m_attackData.GetInstigator();
  if !IsDefined(instigator) || !instigator.IsPlayer() {
    return false;
  };
  if this.m_executeDismembered || !this.CanDieCondition() {
    return false;
  };
  if this.m_ownerNPC.IsBoss() || Equals(this.m_ownerNPC.GetNPCRarity(), gamedataNPCRarity.MaxTac) {
    return false;
  };
  if PLSObliterateSettings.LethalOnly(this.m_ownerNPC.GetGame()) && !this.PLSO_IsLethalHit() {
    return false;
  };
  return true;
}

// Health left after this frame's damage, computed like vanilla ProcessWoundsAndDismemberment
@addMethod(HitReactionComponent)
private final func PLSO_IsLethalHit() -> Bool {
  let health: Float = GameInstance.GetStatPoolsSystem(this.m_ownerNPC.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(this.m_ownerNPC.GetEntityID()), gamedataStatPoolType.Health, false);
  return health - this.m_ownerNPC.GetTotalFrameDamage() <= 0.00;
}

// Vanilla 2.31 ProcessBodyPerkDismembement, kept here so a mod that replaces
// that method cannot reduce the PLS obliteration to the hit part only
// Mirrors the game's own HitReactionComponent.ProcessBodyPerkDismembement (CD PROJEKT RED game script, patch 2.31).
@addMethod(HitReactionComponent)
private final func PLSO_Obliterate() -> Void {
  let adjustedHitDirection: Vector4;
  let secondaryDismemberChance: Float = 0.80;
  let impulseFactor: Float = 1.00;
  let isLegHit: Bool = false;
  let hitPosition: Vector4 = this.m_hitShapeData.result.hitPositionEnter;
  if HitShapeUserDataBase.IsHitReactionZoneHead(this.GetHitShapeUserData()) {
    DismembermentComponent.RequestDismemberment(this.GetOwner(), gameDismBodyPart.HEAD, gameDismWoundType.COARSE, hitPosition, true);
  } else {
    if HitShapeUserDataBase.IsHitReactionZoneTorso(this.GetHitShapeUserData()) {
      DismembermentComponent.RequestDismemberment(this.GetOwner(), gameDismBodyPart.BODY, gameDismWoundType.HOLE, hitPosition, true);
    } else {
      isLegHit = HitShapeUserDataBase.IsHitReactionZoneLeg(this.GetHitShapeUserData());
      DismembermentComponent.RequestDismemberment(this.GetOwner(), HitShapeUserDataBase.GetDismembermentBodyPart(this.GetHitShapeUserData()), gameDismWoundType.COARSE, hitPosition);
    };
  };
  if !isLegHit && RandF() < secondaryDismemberChance {
    DismembermentComponent.RequestDismemberment(this.GetOwner(), gameDismBodyPart.HEAD, gameDismWoundType.COARSE, hitPosition, true);
  };
  if RandF() < secondaryDismemberChance {
    DismembermentComponent.RequestDismemberment(this.GetOwner(), gameDismBodyPart.BODY, gameDismWoundType.HOLE, hitPosition, true);
  };
  if RandF() < secondaryDismemberChance {
    DismembermentComponent.RequestDismemberment(this.GetOwner(), gameDismBodyPart.RIGHT_ARM, gameDismWoundType.COARSE, hitPosition, true);
  };
  if RandF() < secondaryDismemberChance {
    DismembermentComponent.RequestDismemberment(this.GetOwner(), gameDismBodyPart.LEFT_ARM, gameDismWoundType.COARSE, hitPosition, true);
  };
  if RandF() < secondaryDismemberChance {
    DismembermentComponent.RequestDismemberment(this.GetOwner(), gameDismBodyPart.RIGHT_LEG, gameDismWoundType.COARSE, hitPosition, true);
  };
  if RandF() < secondaryDismemberChance {
    DismembermentComponent.RequestDismemberment(this.GetOwner(), gameDismBodyPart.LEFT_LEG, gameDismWoundType.COARSE, hitPosition, true);
  };
  this.NotifyAboutDismembermentInstigated(this.m_attackData.GetInstigator(), HitShapeUserDataBase.GetHitReactionZone(this.GetHitShapeUserData()), this.m_ownerNPC.GetWorldPosition());
  this.GetOwner().Record1DamageInHistory(this.m_attackData.GetInstigator());
  adjustedHitDirection = this.GetOverridenHitDirection();
  impulseFactor = ProportionalClampF(0.00, 0.50, AbsF(adjustedHitDirection.Z), 1.50, 0.80);
  this.m_cumulatedPhysicalImpulse = this.m_knockdownImpulseThreshold + 10.00;
  this.m_ragdollImpulse = this.m_cumulatedPhysicalImpulse * impulseFactor;
  this.m_executeDismembered = true;
  GameObject.PlaySoundEvent(this.m_attackData.GetInstigator(), n"w_gun_perk_gratuitous_violence");
  if adjustedHitDirection.Z > 0.00 && adjustedHitDirection.Z < 0.25 {
    GameInstance.GetDelaySystem(this.m_ownerNPC.GetGame()).DelayEvent(this.m_ownerNPC, CreateRagdollApplyImpulseEvent(this.GetHitPosition(), new Vector4(0.00, 0.00, 1.00, 0.00) * this.m_ragdollImpulse * RandRangeF(0.10, 0.33), 1.00), 0.10, false);
  };
  GameInstance.GetDelaySystem(this.m_ownerNPC.GetGame()).DelayEvent(this.m_ownerNPC, CreateRagdollApplyImpulseEvent(this.GetHitPosition(), adjustedHitDirection * this.m_ragdollImpulse * 0.10, 1.00), 0.10, false);
  this.m_ownerPuppet.Kill(this.m_attackData.GetInstigator());
  this.m_reactionType = animHitReactionType.Ragdoll;
  this.m_isAlive = false;
  this.ClearBodyPerkDismembermentChance(this.m_attackData.GetInstigator());
}
