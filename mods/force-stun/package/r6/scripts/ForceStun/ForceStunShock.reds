// ForceStun 1.2.4: shock add-on (1.2.1: RAM cost; 1.2.2: review fixes; 1.2.3: Mod Settings Debug log ->
// FTLog lines in the CET gamelog.log, default off).
// The CET hotkey (bin\x64\plugins\cyber_engine_tweaks\mods\ForceStun\init.lua) picks the NPC and calls
// ForceStunShockSystem.Shock(target). This file applies the stun with the Mod Settings duration, the silent shock
// damage (a would-be kill becomes an Unconscious knockout; 1.2.4: was System Collapse), the electrified look and the experimental options.
// Records: r6\tweaks\ForceStun\ForceStunShock.yaml. No hooks, no saved state.

enum ForceStunShockLook {
  Arcs = 0,
  Glitch = 1,
  Both = 2
}

enum ForceStunShockExperimental {
  Off = 0,
  ChromeOffline = 1,
  ConvulseAfterStun = 2,
  ConvulseAtOnce = 3
}

public class ForceStunShockSettings extends ScriptableSystem {
  @runtimeProperty("ModSettings.mod", "ForceStun")
  @runtimeProperty("ModSettings.category", "Stun")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "Stun duration (s)")
  @runtimeProperty("ModSettings.description", "How long N keeps the target stunned (and grabbable for Savage Sling). Vanilla stun: 4.6 s. After a stun the game makes the target stun-immune for a short while.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.5")
  @runtimeProperty("ModSettings.max", "30.0")
  public let stunDuration: Float = 4.6;

  @runtimeProperty("ModSettings.mod", "ForceStun")
  @runtimeProperty("ModSettings.category", "Stun")
  @runtimeProperty("ModSettings.category.order", "1")
  @runtimeProperty("ModSettings.displayName", "RAM cost")
  @runtimeProperty("ModSettings.description", "Flat RAM taken per N (perks and cyberdeck don't change it). Not enough RAM: nothing happens. A press that stuns nobody costs nothing. 0 = free.")
  @runtimeProperty("ModSettings.step", "1")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "20")
  public let ramCost: Int32 = 4;

  @runtimeProperty("ModSettings.mod", "ForceStun")
  @runtimeProperty("ModSettings.category", "Shock")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.displayName", "Shock damage (HP)")
  @runtimeProperty("ModSettings.description", "Health taken from the target on every N. Silent: no aggro, no crime, ignores armor. If it would kill, the target is knocked out instead (falls unconscious, like a non-lethal takedown); bosses and knockout-immune targets stop at 1 HP. 0 = no damage.")
  @runtimeProperty("ModSettings.step", "1")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "500")
  public let damage: Int32 = 10;

  @runtimeProperty("ModSettings.mod", "ForceStun")
  @runtimeProperty("ModSettings.category", "Shock")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.displayName", "Electrified effect duration (s)")
  @runtimeProperty("ModSettings.description", "How long the target's cyberware visibly shorts out. Can outlast the stun. 0 = no effect.")
  @runtimeProperty("ModSettings.step", "0.5")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "30.0")
  public let electrifiedDuration: Float = 5.0;

  @runtimeProperty("ModSettings.mod", "ForceStun")
  @runtimeProperty("ModSettings.category", "Shock")
  @runtimeProperty("ModSettings.category.order", "2")
  @runtimeProperty("ModSettings.displayName", "Electrified look")
  @runtimeProperty("ModSettings.description", "Short Circuit arcs, the Cyberware Malfunction glitch (with its sound), or both at once. Look only.")
  @runtimeProperty("ModSettings.displayValues.Arcs", "Short Circuit arcs")
  @runtimeProperty("ModSettings.displayValues.Glitch", "Malfunction glitch")
  @runtimeProperty("ModSettings.displayValues.Both", "Both")
  public let look: ForceStunShockLook = ForceStunShockLook.Both;

  @runtimeProperty("ModSettings.mod", "ForceStun")
  @runtimeProperty("ModSettings.category", "Experimental")
  @runtimeProperty("ModSettings.category.order", "3")
  @runtimeProperty("ModSettings.displayName", "Electrified gameplay (experimental)")
  @runtimeProperty("ModSettings.description", "For the electrified time. Chrome offline: the target can't use cyberware (like the Cyberware Malfunction quickhack), the stun is kept. Convulsions after the stun: chrome offline, and when the stun ends the target convulses for the rest of the electrified time (skipped if grabbed or down). Convulsions at once: starts right away and replaces the stun, so the Savage Sling grab is lost.")
  @runtimeProperty("ModSettings.displayValues.Off", "Off (look only)")
  @runtimeProperty("ModSettings.displayValues.ChromeOffline", "Chrome offline")
  @runtimeProperty("ModSettings.displayValues.ConvulseAfterStun", "Chrome offline + convulsions after the stun")
  @runtimeProperty("ModSettings.displayValues.ConvulseAtOnce", "Chrome offline + convulsions at once")
  public let experimental: ForceStunShockExperimental = ForceStunShockExperimental.Off;

  @runtimeProperty("ModSettings.mod", "ForceStun")
  @runtimeProperty("ModSettings.category", "Debug")
  @runtimeProperty("ModSettings.category.order", "4")
  @runtimeProperty("ModSettings.displayName", "Debug log")
  @runtimeProperty("ModSettings.description", "On: every press writes the target, HP, damage, RAM, immunity and the result to the CET gamelog.log. For testing.")
  public let debugLog: Bool = false;

  @if(ModuleExists("ModSettingsModule"))
  private func OnAttach() -> Void {
    ModSettings.RegisterListenerToClass(this);
  }

  @if(ModuleExists("ModSettingsModule"))
  private func OnDetach() -> Void {
    ModSettings.UnregisterListenerToClass(this);
  }

  public static func Get(game: GameInstance) -> ref<ForceStunShockSettings> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"ForceStunShockSettings") as ForceStunShockSettings;
  }

  public static func Log(game: GameInstance, msg: String) -> Void {
    let s: ref<ForceStunShockSettings> = ForceStunShockSettings.Get(game);
    if IsDefined(s) && s.debugLog {
      FTLog("[ForceStun] " + msg);
    }
  }
}

// Sets an effect's remaining time once a waited-for effect is gone (Buttslinger's 0.2 s Opening re-applies
// ActualStun when it ends, which resets it to 4.6 s). elapsed counts world time already spent since the apply.
public class ForceStunDurationCallback extends DelayCallback {
  public let game: GameInstance;
  public let target: EntityID;
  public let effect: TweakDBID;
  public let waitFor: TweakDBID;
  public let seconds: Float;
  public let elapsed: Float;
  public let tries: Int32;

  public func Call() -> Void {
    let ses: ref<StatusEffectSystem> = GameInstance.GetStatusEffectSystem(this.game);
    let next: ref<ForceStunDurationCallback>;
    let left: Float;
    if !IsDefined(ses) {
      return;
    }
    if TDBID.IsValid(this.waitFor) && ses.HasStatusEffect(this.target, this.waitFor) && this.tries < 30 {
      next = new ForceStunDurationCallback();
      next.game = this.game;
      next.target = this.target;
      next.effect = this.effect;
      next.waitFor = this.waitFor;
      next.seconds = this.seconds;
      next.elapsed = this.elapsed + 0.1;
      next.tries = this.tries + 1;
      GameInstance.GetDelaySystem(this.game).DelayCallback(next, 0.1, true);
      return;
    }
    if !ses.HasStatusEffect(this.target, this.effect) {
      return;
    }
    left = this.seconds - this.elapsed;
    ForceStunShockSettings.Log(this.game, "timer " + TDBID.ToStringDEBUG(this.effect) + " left " + FloatToString(left) + " after " + IntToString(this.tries) + " waits");
    if left > 0.05 {
      ses.SetStatusEffectRemainingDuration(this.target, this.effect, left);
    } else {
      ses.RemoveStatusEffect(this.target, this.effect);
    }
  }
}

// Starts the convulsions when the stun ends, for the rest of the electrified time.
public class ForceStunConvulseCallback extends DelayCallback {
  public let game: GameInstance;
  public let target: EntityID;
  public let seconds: Float;

  public let tries: Int32;

  public func Call() -> Void {
    let npc: ref<ScriptedPuppet> = GameInstance.FindEntityByID(this.game, this.target) as ScriptedPuppet;
    let ses: ref<StatusEffectSystem> = GameInstance.GetStatusEffectSystem(this.game);
    let stuns: array<ref<StatusEffect>>;
    let wait: Float = 0.0;
    let i: Int32 = 0;
    let next: ref<ForceStunConvulseCallback>;
    if !IsDefined(npc) || !IsDefined(ses) || !ScriptedPuppet.IsActive(npc) {
      return;
    }
    // Still stunned (the stun was refreshed by another press): wait for its end, shorten the convulsions to match.
    ses.GetAppliedEffectsOfType(this.target, gamedataStatusEffectType.Stunned, stuns);
    while i < ArraySize(stuns) {
      wait = MaxF(wait, stuns[i].GetRemainingDuration());
      i += 1;
    }
    if wait > 0.05 {
      if this.seconds - wait < 0.5 || this.tries >= 10 {
        return;
      }
      next = new ForceStunConvulseCallback();
      next.game = this.game;
      next.target = this.target;
      next.seconds = this.seconds - wait;
      next.tries = this.tries + 1;
      GameInstance.GetDelaySystem(this.game).DelayCallback(next, wait, true);
      return;
    }
    if ses.HasStatusEffectOfType(this.target, gamedataStatusEffectType.Grapple) {
      ForceStunShockSettings.Log(this.game, "convulse skipped: target grabbed");
      return;
    }
    if IsDefined(npc as NPCPuppet) && (npc as NPCPuppet).IsRagdolling() {
      ForceStunShockSettings.Log(this.game, "convulse skipped: target ragdolling");
      return;
    }
    ForceStunShockSettings.Log(this.game, "convulse after stun for " + FloatToString(this.seconds) + " s");
    ForceStunShockSystem.ApplyTimed(this.game, this.target, t"BaseStatusEffect.ForceStunConvulse", this.seconds, TDBID.None());
  }
}

public class ForceStunShockSystem extends ScriptableSystem {
  public static func Get(game: GameInstance) -> ref<ForceStunShockSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"ForceStunShockSystem") as ForceStunShockSystem;
  }

  // Apply an effect and give it `seconds`, re-checked 0.1 s later (or once waitFor is gone).
  public static func ApplyTimed(game: GameInstance, target: EntityID, effect: TweakDBID, seconds: Float, waitFor: TweakDBID) -> Void {
    GameInstance.GetStatusEffectSystem(game).ApplyStatusEffect(target, effect);
    ForceStunShockSystem.SetTimed(game, target, effect, seconds, waitFor);
  }

  // Give an applied effect `seconds` now and again 0.1 s later (or once waitFor is gone).
  public static func SetTimed(game: GameInstance, target: EntityID, effect: TweakDBID, seconds: Float, waitFor: TweakDBID) -> Void {
    let cb: ref<ForceStunDurationCallback>;
    GameInstance.GetStatusEffectSystem(game).SetStatusEffectRemainingDuration(target, effect, seconds);
    cb = new ForceStunDurationCallback();
    cb.game = game;
    cb.target = target;
    cb.effect = effect;
    cb.waitFor = waitFor;
    cb.seconds = seconds;
    cb.elapsed = 0.1;
    cb.tries = 0;
    GameInstance.GetDelaySystem(game).DelayCallback(cb, 0.1, true);
  }

  // The vanilla immunity test (DamageSystem): god mode Invulnerable blocks Debuff effects, any immunity stat > 0 blocks.
  public static func IsImmune(npc: ref<ScriptedPuppet>, effect: TweakDBID) -> Bool {
    let record: ref<StatusEffect_Record> = TweakDBInterface.GetStatusEffectRecord(effect);
    let stats: array<wref<Stat_Record>>;
    let statsSystem: ref<StatsSystem> = GameInstance.GetStatsSystem(npc.GetGame());
    let i: Int32 = 0;
    if !IsDefined(record) {
      return true;
    }
    if GameInstance.GetGodModeSystem(npc.GetGame()).HasGodMode(npc.GetEntityID(), gameGodModeType.Invulnerable) && record.GameplayTagsContains(n"Debuff") {
      return true;
    }
    record.ImmunityStats(stats);
    while i < ArraySize(stats) {
      if statsSystem.GetStatValue(Cast<StatsObjectID>(npc.GetEntityID()), stats[i].StatType()) > 0.0 {
        return true;
      }
      i += 1;
    }
    return false;
  }

  // Flat RAM cost (2026-11-28, design goal: no perk / cyberdeck reductions).
  public static func RamCost(game: GameInstance, base: Int32) -> Int32 {
    if base <= 0 || !IsDefined(GetPlayer(game)) {
      return 0;
    }
    return base;
  }

  // True when the shock damage would drop the target below 1 HP and it can be knocked out.
  // 1.2.4: the knockout is BaseStatusEffect.Unconscious (the vanilla non-lethal takedown result). 1.2.3's System
  // Collapse never dropped civilians (their AI has no System Collapse behaviour) and left them at ~0 HP running.
  private final func WouldKnockOut(npc: ref<ScriptedPuppet>, dmg: Float) -> Bool {
    let hp: Float;
    if dmg <= 0.0 {
      return false;
    }
    hp = GameInstance.GetStatPoolsSystem(npc.GetGame()).GetStatPoolValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatPoolType.Health, false);
    return hp - dmg < 1.0 && !npc.IsBoss() && !ForceStunShockSystem.IsImmune(npc, t"BaseStatusEffect.Unconscious");
  }

  // Silent damage. Returns true when the shock would have killed and knocked the target out instead.
  private final func DrainOrKnockOut(npc: ref<ScriptedPuppet>, dmg: Float) -> Bool {
    let game: GameInstance = npc.GetGame();
    let id: EntityID = npc.GetEntityID();
    let sid: StatsObjectID = Cast<StatsObjectID>(id);
    let pools: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(game);
    let ses: ref<StatusEffectSystem> = GameInstance.GetStatusEffectSystem(game);
    let hp: Float = pools.GetStatPoolValue(sid, gamedataStatPoolType.Health, false);
    ForceStunShockSettings.Log(game, "shock: HP " + FloatToString(hp) + " dmg " + FloatToString(dmg) + " boss " + ToString(npc.IsBoss()));
    if hp - dmg >= 1.0 {
      pools.RequestChangingStatPoolValue(sid, gamedataStatPoolType.Health, -dmg, null, false, false);
      return false;
    }
    // Would kill: knocked out (Unconscious), applied without an instigator (no damage history, no aggro, no crime).
    if this.WouldKnockOut(npc, dmg) {
      ForceStunShockSettings.Log(game, "shock would kill: Unconscious knockout");
      ses.ApplyStatusEffect(id, t"BaseStatusEffect.Unconscious");
      return true;
    }
    ForceStunShockSettings.Log(game, "shock would kill, boss or unconscious-immune: left at 1 HP");
    // Bosses and immune targets: leave them at 1 HP, never kill.
    if hp > 1.0 {
      pools.RequestChangingStatPoolValue(sid, gamedataStatPoolType.Health, 1.0 - hp, null, false, false);
    }
    return false;
  }

  // Called from CET. Result: "ko", "stun", "vanilla" (stunned without Buttslinger), "immune" (stun refused, nothing
  // done, no RAM taken), "noram:<cost>:<have>" (nothing done) or "none".
  public final func Shock(targetObj: ref<GameObject>) -> String {
    let npc: ref<ScriptedPuppet> = targetObj as ScriptedPuppet;
    let game: GameInstance;
    let settings: ref<ForceStunShockSettings>;
    let ses: ref<StatusEffectSystem>;
    let id: EntityID;
    let stunSecs: Float = 4.6;
    let dmg: Int32 = 10;
    let elecSecs: Float = 5.0;
    let look: ForceStunShockLook = ForceStunShockLook.Both;
    let exp: ForceStunShockExperimental = ForceStunShockExperimental.Off;
    let stunID: TweakDBID;
    let openingID: TweakDBID = TDBID.None();
    let result: String;
    let knockedOut: Bool = false;
    let humanoid: Bool;
    let cb: ref<ForceStunConvulseCallback>;
    let ramBase: Int32 = 4;
    let ram: Int32;
    let have: Float;
    let player: ref<PlayerPuppet>;
    let preStun: TweakDBID;
    if !IsDefined(npc) || !ScriptedPuppet.IsActive(npc) {
      ForceStunShockSettings.Log(GetGameInstance(), "press: no active ScriptedPuppet, result none");
      return "none";
    }
    game = npc.GetGame();
    ses = GameInstance.GetStatusEffectSystem(game);
    id = npc.GetEntityID();
    settings = ForceStunShockSettings.Get(game);
    if IsDefined(settings) {
      stunSecs = MaxF(0.5, settings.stunDuration);
      dmg = Max(0, settings.damage);
      elecSecs = MaxF(0.0, settings.electrifiedDuration);
      look = settings.look;
      exp = settings.experimental;
      ramBase = settings.ramCost;
    }
    ForceStunShockSettings.Log(game, "press: " + NameToString(npc.GetClassName()) + " " + TDBID.ToStringDEBUG(npc.GetRecordID()) + " type " + EnumValueToString("gamedataNPCType", Cast<Int64>(EnumInt(npc.GetNPCType()))) + " stun " + FloatToString(stunSecs) + " s, dmg " + IntToString(dmg) + ", elec " + FloatToString(elecSecs) + " s, look " + IntToString(EnumInt(look)) + ", exp " + IntToString(EnumInt(exp)) + ", ram " + IntToString(ramBase));

    // A press that stuns nobody does nothing and costs nothing: stun-immune (not already stunned, no knockout).
    preStun = IsDefined(TweakDBInterface.GetStatusEffectRecord(t"BaseStatusEffect.ActualStun")) ? t"BaseStatusEffect.ActualStun" : t"BaseStatusEffect.Stun";
    if !this.WouldKnockOut(npc, Cast<Float>(dmg)) && !ses.HasStatusEffect(id, preStun) && ForceStunShockSystem.IsImmune(npc, preStun) {
      ForceStunShockSettings.Log(game, "result immune: stun-immune, not stunned, no knockout; no RAM taken");
      return "immune";
    }
    // RAM: not enough = nothing happens.
    ram = ForceStunShockSystem.RamCost(game, ramBase);
    if ram > 0 {
      player = GetPlayer(game);
      have = GameInstance.GetStatPoolsSystem(game).GetStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Memory, false);
      if have < Cast<Float>(ram) {
        ForceStunShockSettings.Log(game, "result noram: have " + FloatToString(have) + ", cost " + IntToString(ram));
        return "noram:" + IntToString(ram) + ":" + IntToString(FloorF(have));
      }
      GameInstance.GetStatPoolsSystem(game).RequestChangingStatPoolValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatPoolType.Memory, -Cast<Float>(ram), player, false, false);
    }

    if dmg > 0 {
      knockedOut = this.DrainOrKnockOut(npc, Cast<Float>(dmg));
    }

    if knockedOut {
      result = "ko";
    } else {
      if IsDefined(TweakDBInterface.GetStatusEffectRecord(t"BaseStatusEffect.ActualStun")) {
        // Buttslinger Quickmelee: the Opening chains into ActualStun (grab prompt for Savage Sling), as in 1.1.
        openingID = t"BaseStatusEffect.Buttslinger_Opening";
        stunID = t"BaseStatusEffect.ActualStun";
        result = "stun";
      } else {
        stunID = t"BaseStatusEffect.Stun";
        result = "vanilla";
      }
      if ses.HasStatusEffect(id, stunID) {
        // Already stunned (the stun itself gives StunImmunity): refresh it to the full duration, and again once a
        // still-running Buttslinger Opening has re-applied ActualStun.
        ForceStunShockSystem.SetTimed(game, id, stunID, stunSecs, openingID);
      } else {
        if ForceStunShockSystem.IsImmune(npc, stunID) {
          result = "immune";
        } else {
          if TDBID.IsValid(openingID) {
            ses.ApplyStatusEffect(id, openingID);
          }
          ForceStunShockSystem.ApplyTimed(game, id, stunID, stunSecs, openingID);
        }
      }
    }

    ForceStunShockSettings.Log(game, "stun step: " + result + ", stun effect " + TDBID.ToStringDEBUG(stunID) + ", knocked out " + ToString(knockedOut));
    if elecSecs > 0.0 {
      if Equals(look, ForceStunShockLook.Arcs) || Equals(look, ForceStunShockLook.Both) {
        ForceStunShockSystem.ApplyTimed(game, id, t"BaseStatusEffect.ForceStunShockArcs", elecSecs, TDBID.None());
      }
      if Equals(look, ForceStunShockLook.Glitch) || Equals(look, ForceStunShockLook.Both) {
        ForceStunShockSystem.ApplyTimed(game, id, t"BaseStatusEffect.ForceStunShockGlitch", elecSecs, TDBID.None());
      }
      if !knockedOut && NotEquals(exp, ForceStunShockExperimental.Off) {
        ForceStunShockSystem.ApplyTimed(game, id, t"BaseStatusEffect.ForceStunChromeOffline", elecSecs, TDBID.None());
        humanoid = Equals(npc.GetNPCType(), gamedataNPCType.Human) || Equals(npc.GetNPCType(), gamedataNPCType.Android);
        if humanoid && Equals(exp, ForceStunShockExperimental.ConvulseAtOnce) {
          ForceStunShockSystem.ApplyTimed(game, id, t"BaseStatusEffect.ForceStunConvulse", elecSecs, TDBID.None());
        } else {
          if humanoid && Equals(exp, ForceStunShockExperimental.ConvulseAfterStun) && elecSecs - stunSecs >= 0.5 {
            cb = new ForceStunConvulseCallback();
            cb.game = game;
            cb.target = id;
            cb.seconds = elecSecs - stunSecs;
            GameInstance.GetDelaySystem(game).DelayCallback(cb, stunSecs, true);
          }
        }
      }
    }
    ForceStunShockSettings.Log(game, "result " + result);
    return result;
  }
}
