// Cyberslop Hack Loadouts 1.0.2 (2026-11-28)
// 1.0.2 (the in-game debug log 03:30-04:09): ArraySize() straight on a function's returned array read garbage in game
// (390 / 32766), so every such array goes into a local first; IsBusy checks "target reached" before the timeout.
// Read-only bridge plus a load call for the CET window (mods\CyberslopHackLoadouts).
// Needs Quickhack Loadouts (r6\scripts\QuickhackLoadouts): the saved loadouts live in its
// QuickhackLoadoutSystem and the swap itself is its PlayerPuppet.LoadQuickhackLoadout(index).
// CET reads script fields of systems as nil, so everything CET needs comes through these getters.
// 1.0.1 (review): one swap at a time (busy until the deck holds the target, max 2 s), the active loadout is not
// reloaded, Next / Previous start from the last loaded loadout, no swaps during an upload / open quickhack panel /
// pause, preset-name titles match the menu, invalid program IDs are ignored when matching.
module CyberslopHackLoadouts

import QuickhackLoadouts.*

// Load results for CET (Int32 so CET can read them)
public abstract class CyberslopHackLoadoutsResult {
  public static func Loaded() -> Int32 = 0
  public static func AlreadyActive() -> Int32 = 1
  public static func Busy() -> Int32 = 2
  public static func Empty() -> Int32 = 3
  public static func NoDeck() -> Int32 = 4
  public static func Blocked() -> Int32 = 5
  public static func NoPlayer() -> Int32 = 6
}

// Mod Settings (user.ini section [CyberslopHackLoadouts.CyberslopHackLoadoutsSettings])
public class CyberslopHackLoadoutsSettings extends ScriptableSystem {
  @runtimeProperty("ModSettings.mod", "Cyberslop Hack Loadouts")
  @runtimeProperty("ModSettings.category", "Debug")
  @runtimeProperty("ModSettings.displayName", "Debug log")
  @runtimeProperty("ModSettings.description", "Logs every loadout load, the quickhacks per loadout and why a load was refused (CET game log and the mod's CET log).")
  public let debugLog: Bool = false;

  @if(ModuleExists("ModSettingsModule"))
  private func OnAttach() -> Void {
    ModSettings.RegisterListenerToClass(this);
  }

  @if(ModuleExists("ModSettingsModule"))
  private func OnDetach() -> Void {
    ModSettings.UnregisterListenerToClass(this);
  }
}

public class CyberslopHackLoadoutsSystem extends ScriptableSystem {
  private let m_lastLoaded: Int32;   // loaded index + 1, 0 = none (field initialisers must be constants >= 0)
  private let m_pending: Int32;      // index + 1 of a swap still settling, 0 = none
  private let m_loadTime: Float;     // sim time of the last Load

  // For CET (it reads script fields as nil).
  public final func DebugOn() -> Bool {
    let s: ref<CyberslopHackLoadoutsSettings> = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"CyberslopHackLoadouts.CyberslopHackLoadoutsSettings") as CyberslopHackLoadoutsSettings;
    return IsDefined(s) && s.debugLog;
  }

  private final func Dbg(text: String) -> Void {
    if this.DebugOn() {
      FTLog("[CyberslopHackLoadouts] " + text);
    }
  }

  private final func IdList(ids: array<TweakDBID>) -> String {
    let text: String = "";
    for id in ids {
      if StrLen(text) > 0 {
        text += ", ";
      }
      text += TDBID.ToStringDEBUG(id);
    }
    return "[" + text + "]";
  }

  // One line per loadout: index, saved, title, programs (for the debug log).
  public final func DumpLoadouts() -> Void {
    let i: Int32 = 0;
    let n: Int32 = this.Count();
    let loadout: ref<QuickhackLoadout>;
    let valid: array<TweakDBID>;
    if !this.DebugOn() {
      return;
    }
    this.Dbg(s"loadouts: \(n), equipped \(this.IdList(this.Equipped())), active \(this.ActiveIndex() + 1)");
    while i < n {
      loadout = this.Loadout(i);
      if !IsDefined(loadout) {
        this.Dbg(s"  loadout \(i + 1): missing");
      } else {
        valid = this.ValidPrograms(loadout);
        this.Dbg(s"  loadout \(i + 1) '\(this.Title(i))': saved \(loadout.saved), \(ArraySize(valid))/\(ArraySize(loadout.quickhacks)) valid \(this.IdList(loadout.quickhacks))");
      }
      i += 1;
    }
  }

  private final func Loadouts() -> ref<QuickhackLoadoutSystem> {
    return GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"QuickhackLoadouts.QuickhackLoadoutSystem") as QuickhackLoadoutSystem;
  }

  private final func Loadout(index: Int32) -> ref<QuickhackLoadout> {
    let sys: ref<QuickhackLoadoutSystem> = this.Loadouts();
    if !IsDefined(sys) || index < 0 {
      return null;
    }
    return sys.GetQuickhackLoadout(index);
  }

  private final func Player() -> ref<PlayerPuppet> {
    return GameInstance.GetPlayerSystem(this.GetGameInstance()).GetLocalPlayerMainGameObject() as PlayerPuppet;
  }

  private final func Now() -> Float {
    return EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
  }

  public final func HasSystem() -> Bool {
    return IsDefined(this.Loadouts());
  }

  public final func HasPlayer() -> Bool {
    return IsDefined(this.Player());
  }

  public final func Ready() -> Bool {
    return this.HasSystem() && this.HasPlayer();
  }

  public final func Count() -> Int32 {
    return QuickhackLoadoutConfig.GetNumLoadouts();
  }

  private final func ValidPrograms(loadout: ref<QuickhackLoadout>) -> array<TweakDBID> {
    let out: array<TweakDBID>;
    if IsDefined(loadout) {
      for id in loadout.quickhacks {
        if TDBID.IsValid(id) {
          ArrayPush(out, id);
        }
      }
    }
    return out;
  }

  public final func IsSaved(index: Int32) -> Bool {
    let loadout: ref<QuickhackLoadout> = this.Loadout(index);
    let valid: array<TweakDBID>;
    if !IsDefined(loadout) || !loadout.saved {
      return false;
    }
    valid = this.ValidPrograms(loadout);
    return ArraySize(valid) > 0;
  }

  // Same rule as the inventory menu (GetLoadoutTitle / GetLoadoutLabelText).
  public final func Title(index: Int32) -> String {
    let loadout: ref<QuickhackLoadout> = this.Loadout(index);
    let fallback: String = s"\(GetLocalizedTextByKey(n"Quickhack-Loadout-Loadout")) \(index + 1)";
    if QuickhackLoadoutSettings.UsePresetNames() {
      if !IsDefined(loadout) {
        return fallback;
      }
      switch loadout.label {
        case QuickhackLoadoutLabel.Combat:
          return GetLocalizedTextByKey(n"Quickhack-Loadout-Label-Combat");
        case QuickhackLoadoutLabel.Stealth:
          return GetLocalizedTextByKey(n"Quickhack-Loadout-Label-Stealth");
        case QuickhackLoadoutLabel.Utility:
          return GetLocalizedTextByKey(n"Quickhack-Loadout-Label-Utility");
        case QuickhackLoadoutLabel.Ultimates:
          return GetLocalizedTextByKey(n"Quickhack-Loadout-Label-Ultimates");
        case QuickhackLoadoutLabel.Iconics:
          return GetLocalizedTextByKey(n"Quickhack-Loadout-Label-Iconics");
        default:
          return fallback;
      }
    }
    if IsDefined(loadout) && loadout.saved && IsNameValid(loadout.name) {
      return NameToString(loadout.name);
    }
    return s"Loadout \(index + 1)";   // the menu's own non-preset fallback is plain English too
  }

  public final func HackCount(index: Int32) -> Int32 {
    let valid: array<TweakDBID> = this.ValidPrograms(this.Loadout(index));
    return ArraySize(valid);
  }

  // Localized quickhack names, one per line, for the window tooltip.
  public final func HackList(index: Int32) -> String {
    let text: String = "";
    let record: ref<Item_Record>;
    let name: String;
    for id in this.ValidPrograms(this.Loadout(index)) {
      record = TweakDBInterface.GetItemRecord(id);
      name = IsDefined(record) ? GetLocalizedTextByKey(record.DisplayName()) : "";
      if StrLen(name) == 0 {
        name = TDBID.ToStringDEBUG(id);
      }
      if StrLen(text) > 0 {
        text += "\n";
      }
      text += name;
    }
    return text;
  }

  public final func HasDeck() -> Bool {
    let player: ref<PlayerPuppet> = this.Player();
    if !IsDefined(player) {
      return false;
    }
    return !InventoryItemData.IsEmpty(EquipmentSystem.GetData(player).GetEquippedCyberdeck());
  }

  private final func Equipped() -> array<TweakDBID> {
    let player: ref<PlayerPuppet> = this.Player();
    let out: array<TweakDBID>;
    let id: TweakDBID;
    if !IsDefined(player) || !this.HasDeck() {
      return out;
    }
    for slot in player.GetCyberdeckSlots() {
      id = ItemID.GetTDBID(slot.ItemData.ID);
      if TDBID.IsValid(id) {
        ArrayPush(out, id);
      }
    }
    return out;
  }

  // Same programs in any slot order (a load keeps programs that are already in place where they are).
  private final func Matches(index: Int32, equipped: array<TweakDBID>) -> Bool {
    let loadout: ref<QuickhackLoadout> = this.Loadout(index);
    let want: array<TweakDBID>;
    if !IsDefined(loadout) || !loadout.saved {
      return false;
    }
    want = this.ValidPrograms(loadout);
    if ArraySize(want) == 0 || ArraySize(want) != ArraySize(equipped) {
      return false;
    }
    for id in want {
      if !ArrayContains(equipped, id) {
        return false;
      }
    }
    return true;
  }

  // Index of the saved loadout on the deck, -1 if none. The last loaded one wins when several match.
  public final func ActiveIndex() -> Int32 {
    let equipped: array<TweakDBID> = this.Equipped();
    let i: Int32 = 0;
    let n: Int32 = this.Count();
    if ArraySize(equipped) == 0 {
      return -1;
    }
    if this.m_lastLoaded > 0 && this.Matches(this.m_lastLoaded - 1, equipped) {
      return this.m_lastLoaded - 1;
    }
    while i < n {
      if this.Matches(i, equipped) {
        return i;
      }
      i += 1;
    }
    return -1;
  }

  // True while the last swap has not reached its target yet (gives up after 2 s of sim time).
  public final func IsBusy() -> Bool {
    let age: Float;
    let equipped: array<TweakDBID>;
    if this.m_pending <= 0 {
      return false;
    }
    age = this.Now() - this.m_loadTime;
    equipped = this.Equipped();
    if age >= 0.3 && this.Matches(this.m_pending - 1, equipped) {
      this.Dbg(s"swap to \(this.m_pending) settled (seen after \(age) s)");
      this.m_pending = 0;
      return false;
    }
    if age < 0.0 || age > 2.0 {
      this.Dbg(s"swap to \(this.m_pending) not settled after \(age) s, equipped \(this.IdList(equipped)); busy cleared");
      this.m_pending = 0;
      return false;
    }
    return true;
  }

  // Why a swap must wait: "" = free, else the reason.
  public final func BlockReason() -> String {
    let player: ref<PlayerPuppet> = this.Player();
    let uploading: array<TweakDBID>;
    let bb: ref<IBlackboard>;
    if !IsDefined(player) {
      return "no player";
    }
    if GameInstance.GetTimeSystem(this.GetGameInstance()).IsPausedState() {
      return "game paused";
    }
    bb = GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_QuickSlotsData);
    if IsDefined(bb) && bb.GetBool(GetAllBlackboardDefs().UI_QuickSlotsData.quickhackPanelOpen) {
      return "quickhack panel open";
    }
    bb = player.GetPlayerStateMachineBlackboard();
    if IsDefined(bb) {
      uploading = FromVariant<array<TweakDBID>>(bb.GetVariant(GetAllBlackboardDefs().PlayerStateMachine.UploadingQuickHackIDs));
      if ArraySize(uploading) > 0 {
        return s"uploading \(this.IdList(uploading))";
      }
    }
    return "";
  }

  // Quickhack upload running, scanner quickhack panel open, or game paused.
  public final func IsBlocked() -> Bool {
    return StrLen(this.BlockReason()) > 0;
  }

  // Short on-screen line for hotkey swaps (the window is closed then).
  public final func Notify(text: String) -> Void {
    let msg: SimpleScreenMessage;
    msg.isShown = true;
    msg.duration = 2.0;
    msg.message = text;
    GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_Notifications).SetVariant(GetAllBlackboardDefs().UI_Notifications.WarningMessage, ToVariant(msg), true);
  }

  public final func LastLoaded() -> Int32 {
    return this.m_lastLoaded - 1;
  }

  // Returns a CyberslopHackLoadoutsResult code.
  public final func Load(index: Int32) -> Int32 {
    let player: ref<PlayerPuppet> = this.Player();
    let reason: String;
    let slots: array<ref<InventoryItemAttachments>>;
    if !IsDefined(player) {
      this.Dbg(s"load \(index + 1) failed: no player");
      return CyberslopHackLoadoutsResult.NoPlayer();
    }
    if !this.HasDeck() {
      this.Dbg(s"load \(index + 1) failed: no cyberdeck equipped");
      return CyberslopHackLoadoutsResult.NoDeck();
    }
    if !this.IsSaved(index) {
      this.Dbg(s"load \(index + 1) failed: loadout empty or not saved");
      return CyberslopHackLoadoutsResult.Empty();
    }
    if this.IsBusy() {
      this.Dbg(s"load \(index + 1) refused: swap to \(this.m_pending) still running");
      return CyberslopHackLoadoutsResult.Busy();
    }
    if this.Matches(index, this.Equipped()) {
      this.m_lastLoaded = index + 1;
      this.Dbg(s"load \(index + 1) skipped: already on the deck");
      return CyberslopHackLoadoutsResult.AlreadyActive();
    }
    reason = this.BlockReason();
    if StrLen(reason) > 0 {
      this.Dbg(s"load \(index + 1) refused: \(reason)");
      return CyberslopHackLoadoutsResult.Blocked();
    }
    if this.DebugOn() {
      slots = player.GetCyberdeckSlots();
      this.Dbg(s"load \(index + 1) '\(this.Title(index))': \(this.IdList(this.ValidPrograms(this.Loadout(index)))) over equipped \(this.IdList(this.Equipped())), deck slots \(ArraySize(slots))");
    }
    player.LoadQuickhackLoadout(index);
    this.m_lastLoaded = index + 1;
    this.m_pending = index + 1;
    this.m_loadTime = this.Now();
    return CyberslopHackLoadoutsResult.Loaded();
  }

  // Next saved loadout after the active / last loaded one, wrapping. Returns the target index (or -1 when no
  // other saved loadout exists); the load result goes to LastResult().
  private let m_lastResult: Int32;

  public final func LastResult() -> Int32 {
    return this.m_lastResult;
  }

  public final func LoadNext(step: Int32) -> Int32 {
    let n: Int32 = this.Count();
    let start: Int32;
    let k: Int32 = 1;
    let index: Int32;
    this.m_lastResult = CyberslopHackLoadoutsResult.Empty();
    if n <= 0 {
      return -1;
    }
    if this.IsBusy() {
      this.Dbg(s"next (\(step)) refused: swap to \(this.m_pending) still running");
      this.m_lastResult = CyberslopHackLoadoutsResult.Busy();
      return -1;
    }
    start = this.ActiveIndex();
    if start < 0 {
      start = this.m_lastLoaded - 1;
    }
    if start < 0 {
      start = step > 0 ? -1 : 0;
    }
    while k <= n {
      index = (start + step * k) % n;
      if index < 0 {
        index += n;
      }
      if this.IsSaved(index) {
        this.Dbg(s"next (\(step)) from \(start + 1) -> \(index + 1)");
        this.m_lastResult = this.Load(index);
        return index;
      }
      k += 1;
    }
    this.Dbg(s"next (\(step)) failed: no saved loadout");
    return -1;
  }
}
