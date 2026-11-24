// Cyberslop Easier Breach 1.0.0, 2026-10-29.
// Replaces an auto-solve breach mod (Nexus 6956): the Breach Protocol puzzle stays, Intelligence decides how much easier
// it gets (3 = nothing extra, 20 = full), and devices get easier than NPCs.
//
// Device breaches (access points, devices, remote breach on a device, shards):
//  - Timer x2 at Intelligence 3 up to x4 at 20 (vanilla 30 s: 60 to 120 s). Mod Settings can switch it off.
//  - Buffer +1 (Intelligence 3 to 7), +2 (8 to 15), +3 (16 to 20).
//  - Daemon chains 1 shorter and at most 4 cells, at most 3 from Intelligence 12. Never under 2 (vanilla minimum).
//  - Daemons are linked in list order: the last cell of one is the first cell of the next, so one path can finish
//    several. Chance per link 70 % at Intelligence 3 up to 100 % at 20 (replaces vanilla's random overlap rolls).
// NPC breaches (physical, unconscious and grapple breach, remote breach on an NPC, Much Better Netrunning's netrunner
// and squad networks):
//  - Timer x1 at Intelligence 3 up to x2.5 at 20 on top of vanilla (physical 45 s: up to 112 s; remote 30 s: up to 75 s).
//  - Buffer +1 at Intelligence 3 up to +5 at 20 (one more about every 4 points).
//  - Daemon chains vanilla below Intelligence 12; from 12 one shorter and at most 4 cells.
//  - No overlap at all: every daemon is its own sequence (one daemon at a time on netrunners).
// This mod never raises the buffer above 12. Records that fix their own buffer (Courier Jobs, quest boards, hard shards)
// keep their buffer and timer. Unchanged: vanilla's retry penalty (shorter timer on later attempts), board size, symbols,
// the automatic first daemon perk, fixed daemon lists (their chains come from the record).
//
// Wraps only: HackingMinigameGameController.ScaleTimer / ScaleBuffer, MinigameGenerationRuleScalingPrograms.OnProcessRule /
// DefineLength / GenerateRarities. Much Better Netrunning wraps FilterPlayerPrograms and OverridePrograms.OnProcessRule,
// Courier Jobs OverridePrograms.OnProcessRule; none of those is touched here.

public class CyberslopEasierBreachSettings extends ScriptableSystem {

  @runtimeProperty("ModSettings.mod", "Easier Breach")
  @runtimeProperty("ModSettings.displayName", "Enabled")
  @runtimeProperty("ModSettings.description", "On: Breach Protocol gets easier with Intelligence, devices more than NPCs. Off: vanilla. Applies from the next breach.")
  public let enabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Easier Breach")
  @runtimeProperty("ModSettings.displayName", "No timer on device breaches")
  @runtimeProperty("ModSettings.description", "On: access points, devices and shards have no timer. Off: their timer is 2x (Intelligence 3) to 4x (Intelligence 20) vanilla. NPC breaches always keep a timer.")
  public let deviceNoTimer: Bool = false;

  @runtimeProperty("ModSettings.mod", "Easier Breach")
  @runtimeProperty("ModSettings.displayName", "Breach log")
  @runtimeProperty("ModSettings.description", "One line per breach in the CET game log (gamelog.log): device or NPC, Intelligence, buffer, timer, daemon lengths and links.")
  public let breachLog: Bool = true;

  @if(ModuleExists("ModSettingsModule"))
  private func OnAttach() -> Void {
    ModSettings.RegisterListenerToClass(this);
  }

  @if(ModuleExists("ModSettingsModule"))
  private func OnDetach() -> Void {
    ModSettings.UnregisterListenerToClass(this);
  }
}

public abstract class CyberslopEasierBreach {

  public static func Settings(gi: GameInstance) -> ref<CyberslopEasierBreachSettings> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"CyberslopEasierBreachSettings") as CyberslopEasierBreachSettings;
  }

  public static func IsOn(player: wref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) {
      return false;
    }
    let s: ref<CyberslopEasierBreachSettings> = CyberslopEasierBreach.Settings(player.GetGame());
    return !IsDefined(s) || s.enabled;
  }

  public static func DeviceNoTimer(gi: GameInstance) -> Bool {
    let s: ref<CyberslopEasierBreachSettings> = CyberslopEasierBreach.Settings(gi);
    return IsDefined(s) && s.deviceNoTimer;
  }

  public static func LogOn(gi: GameInstance) -> Bool {
    let s: ref<CyberslopEasierBreachSettings> = CyberslopEasierBreach.Settings(gi);
    return !IsDefined(s) || s.breachLog;
  }

  public static func Intelligence(player: wref<PlayerPuppet>) -> Float {
    return GameInstance.GetStatsSystem(player.GetGame()).GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.Intelligence);
  }

  // 0 at Intelligence 3, 1 at Intelligence 20.
  public static func Ease(player: wref<PlayerPuppet>) -> Float {
    return ClampF((CyberslopEasierBreach.Intelligence(player) - 3.0) / 17.0, 0.0, 1.0);
  }

  // NPC breaches set OfficerBreach (AccessBreach.CompleteAction); the puppet check covers anything that does not.
  public static func IsNpcBreach(officerBreach: Bool, entity: wref<Entity>) -> Bool {
    return officerBreach || IsDefined(entity as ScriptedPuppet);
  }
}

@addField(HackingMinigameGameController)
public let m_cebTimer: Float;

@addField(HackingMinigameGameController)
public let m_cebBufferBonus: Int32;

@wrapMethod(HackingMinigameGameController)
public final func ScaleTimer(player: ref<PlayerPuppet>, entity: ref<Entity>, out time: Float, powerLevel: Float, out waitInteraction: Bool) -> Void {
  wrappedMethod(player, entity, time, powerLevel, waitInteraction);
  // A record with its own buffer is hand-made (Courier Jobs, quest boards, hard shards): leave its timer alone too.
  if CyberslopEasierBreach.IsOn(player) && (!IsDefined(this.m_miniGameRecord) || this.m_miniGameRecord.BufferSize() == 0) {
    let ease: Float = CyberslopEasierBreach.Ease(player);
    if CyberslopEasierBreach.IsNpcBreach(this.m_isOfficerBreach, entity) {
      time *= 1.0 + 1.5 * ease;
    } else {
      if CyberslopEasierBreach.DeviceNoTimer(player.GetGame()) {
        time = 0.0;
      } else {
        time *= 2.0 + 2.0 * ease;
      }
    }
  }
  this.m_cebTimer = time;
}

@wrapMethod(HackingMinigameGameController)
public final func ScaleBuffer(entity: ref<Entity>, out size: Float, powerLevel: Float, player: ref<PlayerPuppet>) -> Void {
  wrappedMethod(entity, size, powerLevel, player);
  this.m_cebBufferBonus = 0;
  if !CyberslopEasierBreach.IsOn(player) {
    return;
  }
  let ease: Float = CyberslopEasierBreach.Ease(player);
  let bonus: Int32;
  if CyberslopEasierBreach.IsNpcBreach(this.m_isOfficerBreach, entity) {
    bonus = 1 + RoundF(4.0 * ease);
  } else {
    bonus = 1 + RoundF(2.0 * ease);
  }
  let target: Float = MinF(size + Cast<Float>(bonus), 12.0);
  if target > size {
    this.m_cebBufferBonus = RoundF(target - size);
    size = target;
  }
}

@addField(MinigameGenerationRuleScalingPrograms)
public let m_cebHasPrev: Bool;

@addField(MinigameGenerationRuleScalingPrograms)
public let m_cebPrevLast: Uint32;

@addField(MinigameGenerationRuleScalingPrograms)
public let m_cebLengths: String;

@addField(MinigameGenerationRuleScalingPrograms)
public let m_cebDaemons: Int32;

@addField(MinigameGenerationRuleScalingPrograms)
public let m_cebLinks: Int32;

@addMethod(MinigameGenerationRuleScalingPrograms)
private final func CEB_IsNpc() -> Bool {
  return CyberslopEasierBreach.IsNpcBreach(this.m_isOfficerBreach, this.m_entity);
}

@wrapMethod(MinigameGenerationRuleScalingPrograms)
protected func OnProcessRule(size: Uint32, out grid: array<array<GridCell>>) -> Bool {
  this.m_cebHasPrev = false;
  this.m_cebLengths = "";
  this.m_cebDaemons = 0;
  this.m_cebLinks = 0;
  let result: Bool = wrappedMethod(size, grid);
  if CyberslopEasierBreach.IsOn(this.m_player) && CyberslopEasierBreach.LogOn(this.m_player.GetGame()) {
    let controller: wref<HackingMinigameGameController> = this.minigameController;
    let timer: Float = IsDefined(controller) ? controller.m_cebTimer : -1.0;
    let bonus: Int32 = IsDefined(controller) ? controller.m_cebBufferBonus : 0;
    let links: String;
    if this.CEB_IsNpc() {
      links = "no links (NPC)";
    } else {
      links = IntToString(this.m_cebLinks) + " of " + IntToString(Max(this.m_cebDaemons - 1, 0)) + " linked";
    }
    FTLog("[EasierBreach] " + (this.CEB_IsNpc() ? "NPC" : "device") + " breach" + (this.m_isRemoteBreach ? " (remote)" : "")
      + ", Intelligence " + FloatToStringPrec(CyberslopEasierBreach.Intelligence(this.m_player), 0)
      + ": buffer " + IntToString(this.m_bufferSize) + " (+" + IntToString(bonus) + ")"
      + ", timer " + (timer > 0.0 ? FloatToStringPrec(timer, 0) + " s" : "none")
      + ", " + IntToString(this.m_cebDaemons) + " daemons [" + this.m_cebLengths + "], " + links);
  }
  return result;
}

@wrapMethod(MinigameGenerationRuleScalingPrograms)
public final func DefineLength(combinedPowerLevel: Float, bufferSize: Int32, numPrograms: Int32) -> Int32 {
  let length: Int32 = wrappedMethod(combinedPowerLevel, bufferSize, numPrograms);
  if !CyberslopEasierBreach.IsOn(this.m_player) {
    return length;
  }
  // 0 below Intelligence 12, 1 from 12.
  let step: Int32 = RoundF(CyberslopEasierBreach.Ease(this.m_player));
  if this.CEB_IsNpc() {
    length = Min(length - step, 5 - step);
  } else {
    length = Min(length - 1, 4 - step);
  }
  return Min(Max(length, 2), bufferSize);
}

@wrapMethod(MinigameGenerationRuleScalingPrograms)
public final func GenerateRarities(length: Int32, const overlap: script_ref<array<Overlap>>, id: Int32) -> array<Uint32> {
  if !CyberslopEasierBreach.IsOn(this.m_player) {
    return wrappedMethod(length, overlap, id);
  }
  // Vanilla's overlaps are dropped: NPC daemons stay separate, device daemons get the chain below instead.
  let noOverlap: array<Overlap>;
  let rarities: array<Uint32> = wrappedMethod(length, noOverlap, id);
  let last: Int32 = ArraySize(rarities) - 1;
  if last < 0 {
    return rarities;
  }
  if !this.CEB_IsNpc() {
    if this.m_cebHasPrev && RandRangeF(0.0, 1.0) < 0.7 + 0.3 * CyberslopEasierBreach.Ease(this.m_player) {
      rarities[0] = this.m_cebPrevLast;
      this.m_cebLinks += 1;
    }
    this.m_cebPrevLast = rarities[last];
    this.m_cebHasPrev = true;
  }
  this.m_cebLengths += (this.m_cebDaemons > 0 ? " " : "") + IntToString(ArraySize(rarities));
  this.m_cebDaemons += 1;
  return rarities;
}
