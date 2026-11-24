// Tough Cars 1.0.0 by penicius-code
// Cars only blow up from explosives.
// Vanilla: every hit on a car (bullets, melee, Gorilla Arms punches, crashes, which the game
// turns into VehicleImpact hits) goes through DamageSystem.ProcessVehicleTarget. Once car health
// reaches the decay threshold (BaseStatPools.VehicleHealthDecay, damage level 3 in
// VehicleComponent.ReactToHPChange) the car is disabled, burns down to 0 and
// VehicleComponent.OnDeath explodes it. A strong punch or a few bullets could get it there.
// For every hit that is not an explosion this mod scales the damage by NonExplosiveDamage and
// never lets health drop below the decay threshold + FloorMargin (the floor the game itself uses
// for god-mode quest cars). Smoke and dents still show, the car never starts to burn.
// Explosions (grenades, launchers, rockets, a car blowing up next to it) are left vanilla.
// Flipped cars no longer catch fire and burn out.
// Cars with a hostile or aggressive NPC inside (chases, NCPD pursuit, vehicle combat gigs) are
// protected too, so pursuers can only be stopped with explosives. Set ProtectHostileVehicles to
// false to give those cars vanilla damage while the NPCs are inside.

public abstract class ToughCarsConfig {
  // Share of non-explosive damage a car takes. 0.1 = ten times tougher against bullets, punches and crashes.
  public static func NonExplosiveDamage() -> Float {
    return 0.1;
  }

  // Share of explosion damage a car takes. 1.0 = vanilla, one grenade can still do it.
  public static func ExplosionDamage() -> Float {
    return 1.0;
  }

  // Health % kept above the decay threshold by non-explosive hits.
  public static func FloorMargin() -> Float {
    return 1.0;
  }

  // V's own car (the one V sits in, or any car V owns).
  public static func ProtectPlayerVehicles() -> Bool {
    return true;
  }

  // Cars with a hostile or aggressive NPC inside. false = vanilla damage while they are inside.
  public static func ProtectHostileVehicles() -> Bool {
    return true;
  }
}

public abstract class ToughCars {
  public static func IsProtected(vehicle: ref<VehicleObject>) -> Bool {
    if !IsDefined(vehicle) || !IsDefined(vehicle.GetVehicleComponent()) {
      return false;
    };
    if vehicle.IsPlayerMounted() || vehicle.IsPlayerVehicle() {
      return ToughCarsConfig.ProtectPlayerVehicles();
    };
    if !ToughCarsConfig.ProtectHostileVehicles() && ToughCars.HasHostilePassenger(vehicle) {
      return false;
    };
    return true;
  }

  public static func HasHostilePassenger(vehicle: ref<VehicleObject>) -> Bool {
    let passengers: array<wref<GameObject>>;
    let puppet: ref<ScriptedPuppet>;
    let i: Int32 = 0;
    VehicleComponent.GetAllPassengers(vehicle.GetGame(), vehicle.GetEntityID(), false, passengers);
    while i < ArraySize(passengers) {
      puppet = passengers[i] as ScriptedPuppet;
      if IsDefined(puppet) && !puppet.IsPlayer() && !puppet.IsDead() && !IsFriendlyTowardsPlayer(puppet) && (puppet.IsAggressive() || IsHostileTowardsPlayer(puppet)) {
        return true;
      };
      i += 1;
    };
    return false;
  }
}

@wrapMethod(DamageSystem)
private final func ProcessVehicleTarget(hitEvent: ref<gameHitEvent>, cache: ref<CacheData>) -> Void {
  let vehicle: ref<VehicleObject>;
  let floor: Float;
  wrappedMethod(hitEvent, cache);
  if hitEvent.projectionPipeline || hitEvent.attackData.HasFlag(hitFlag.DealNoDamage) {
    return;
  };
  vehicle = hitEvent.target as VehicleObject;
  if !ToughCars.IsProtected(vehicle) {
    return;
  };
  if AttackData.IsExplosion(hitEvent.attackData.GetAttackType()) {
    if ToughCarsConfig.ExplosionDamage() != 1.0 {
      hitEvent.attackComputed.MultAttackValue(ToughCarsConfig.ExplosionDamage());
    };
    return;
  };
  hitEvent.attackComputed.MultAttackValue(ToughCarsConfig.NonExplosiveDamage());
  // DrainStatPool stops health at this %, so the car never reaches damage level 3 (burn, then explode)
  floor = vehicle.GetVehicleComponent().GetVehicleDecayThreshold() + ToughCarsConfig.FloorMargin();
  hitEvent.attackData.SetMinimumHealthPercent(MaxF(hitEvent.attackData.GetMinimumHealthPercent(), floor));
}

// A car left on its roof for a while gets VehicleBaseDamageOverTimeEffect and burns out.
@wrapMethod(VehicleComponent)
protected final func ApplyVehicleDOT(opt type: CName) -> Void {
  if ToughCars.IsProtected(this.GetVehicle()) {
    return;
  };
  wrappedMethod(type);
}

// Flipping at speed with hostile passengers has a 30 % chance to set the car about to explode.
// Only reached with hostile passengers, so with ProtectHostileVehicles = false this stays vanilla.
@wrapMethod(VehicleComponent)
private final func CheckAboutToExplodeStateOnFlip() -> Void {
  if ToughCars.IsProtected(this.GetVehicle()) {
    return;
  };
  wrappedMethod();
}
