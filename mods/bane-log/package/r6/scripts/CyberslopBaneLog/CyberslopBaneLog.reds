// Cyberslop Bane Log 1.0.1 (2026-11-27) - redscript half of the CET window "Bane Log".
// 1.0.1: Session() (a number per game session) for the CET side's duplicate check.
//
// Cyberbane's map pins, read straight off the map and tracked with one click. No reference to Cyberbane's code: its
// pins are found by their caption, which Cyberbane always starts with "CB_RIVAL|" (UI/RivalPin.reds), plus pins of
// Cyberbane's own map variant (CPO_PingLootVariant, UI/MapPins.reds) that an add-on placed without the tag. A
// Cyberbane rename can therefore never break the redscript compile; the window would just find no pins.
//
// Refresh() snapshots the pins (only when the CET side asks: every few seconds, never on an engine event or job
// thread). Track(i) tracks pin i of the snapshot the way the world map does, through Overlay Map's native plugin
// (OverlayMapNative_TrackMappin, the call Overlay Map's own TRACK button uses). Without that plugin it compiles to a
// stub and the window says tracking is unavailable.

public class CyberslopBaneLogSystem extends ScriptableSystem {
  private let m_ids: array<NewMappinID>;
  private let m_caps: array<String>;
  private let m_pos: array<Vector4>;
  private let m_dist: array<Float>;
  private let m_session: Int32;

  // A new number for every game session (each load makes a new system): the CET side uses it to tell a fresh session
  // (Cyberbane's phone starts empty, so every text in it is new) from a CET reload inside the same one.
  private func OnAttach() -> Void {
    this.m_session = RandRange(1, 2000000000);
  }

  public static func Get(game: GameInstance) -> ref<CyberslopBaneLogSystem> {
    return GameInstance.GetScriptableSystemsContainer(game).Get(n"CyberslopBaneLogSystem") as CyberslopBaneLogSystem;
  }

  public func Version() -> String = "1.0.1"

  public func Session() -> Int32 {
    return this.m_session;
  }

  public func Tag() -> String = "CB_RIVAL|"

  // Re-reads Cyberbane's pins from the map. Returns how many there are.
  public func Refresh() -> Int32 {
    ArrayClear(this.m_ids);
    ArrayClear(this.m_caps);
    ArrayClear(this.m_pos);
    ArrayClear(this.m_dist);
    let game = this.GetGameInstance();
    let ms = GameInstance.GetMappinSystem(game);
    let player = GetPlayer(game);
    if !IsDefined(ms) || !IsDefined(player) {
      return 0;
    }
    let here = player.GetWorldPosition();
    let all: array<ref<IMappin>>;
    ms.GetMappins(gamemappinsMappinTargetType.Map, all);
    let tag = this.Tag();
    for m in all {
      if IsDefined(m) {
        let cap = m.GetDisplayName();
        let ours = StrBeginsWith(cap, tag);
        if !ours && Equals(m.GetVariant(), gamedataMappinVariant.CPO_PingLootVariant) {
          ours = true;
        }
        if ours {
          let id = m.GetNewMappinID();   // bound to a local first: a field read off the call's temporary is garbage
          let pos = m.GetWorldPosition();
          ArrayPush(this.m_ids, id);
          ArrayPush(this.m_caps, cap);
          ArrayPush(this.m_pos, pos);
          ArrayPush(this.m_dist, Vector4.Distance(here, pos));
        }
      }
    }
    return ArraySize(this.m_ids);
  }

  public func Count() -> Int32 {
    return ArraySize(this.m_ids);
  }

  public func Caption(i: Int32) -> String {
    return i >= 0 && i < ArraySize(this.m_caps) ? this.m_caps[i] : "";
  }

  public func X(i: Int32) -> Float {
    return i >= 0 && i < ArraySize(this.m_pos) ? this.m_pos[i].X : 0.0;
  }

  public func Y(i: Int32) -> Float {
    return i >= 0 && i < ArraySize(this.m_pos) ? this.m_pos[i].Y : 0.0;
  }

  public func Z(i: Int32) -> Float {
    return i >= 0 && i < ArraySize(this.m_pos) ? this.m_pos[i].Z : 0.0;
  }

  public func Dist(i: Int32) -> Float {
    return i >= 0 && i < ArraySize(this.m_dist) ? this.m_dist[i] : -1.0;
  }

  // Index of the pin the player tracks right now, -1 when it is none of the snapshot's.
  public func TrackedIndex() -> Int32 {
    let ms = GameInstance.GetMappinSystem(this.GetGameInstance());
    if !IsDefined(ms) {
      return -1;
    }
    let tracked = ms.GetManuallyTrackedMappinID();
    if tracked.value == 0ul {
      return -1;
    }
    let i = 0;
    while i < ArraySize(this.m_ids) {
      if this.m_ids[i].value == tracked.value {
        return i;
      }
      i += 1;
    }
    return -1;
  }

  public func CanTrack() -> Bool {
    return CyberslopBaneLogTrack.Available();
  }

  public func TrackWhy() -> String {
    return CyberslopBaneLogTrack.Why();
  }

  // Tracks pin i of the last snapshot (GPS route + objective), as the world map's TRACK does.
  public func Track(i: Int32) -> Bool {
    if i < 0 || i >= ArraySize(this.m_ids) {
      return false;
    }
    let ms = GameInstance.GetMappinSystem(this.GetGameInstance());
    if !IsDefined(ms) {
      return false;
    }
    let id = this.m_ids[i];
    if id.value == 0ul || !IsDefined(ms.GetMappin(id)) {
      return false;   // gone since the snapshot
    }
    // Vanilla TrackMappin drops a custom waypoint first (UntrackCustomPositionMappin); so does Overlay Map.
    let cur = ms.GetManuallyTrackedMappinID();
    if cur.value != 0ul {
      let cm = ms.GetMappin(cur);
      if IsDefined(cm) && Equals(cm.GetVariant(), gamedataMappinVariant.CustomPositionVariant) {
        ms.UnregisterMappin(cur);
      }
    }
    return CyberslopBaneLogTrack.Track(ms, id);
  }

  // Stops tracking, but only one of Cyberbane's pins: a quest or a waypoint of the player's own stays.
  public func Untrack() -> Bool {
    if this.TrackedIndex() < 0 {
      return false;
    }
    let ms = GameInstance.GetMappinSystem(this.GetGameInstance());
    if !IsDefined(ms) {
      return false;
    }
    ms.UntrackMappin();
    return true;
  }
}

@if(ModuleExists("OverlayMapNative"))
public abstract class CyberslopBaneLogTrack {
  public static func Available() -> Bool { return OverlayMapNative_Available(); }
  // Never reach the native on a build the plugin did not recognise: it could not consume its parameters.
  public static func Track(ms: ref<MappinSystem>, id: NewMappinID) -> Bool {
    if !OverlayMapNative_Available() { return false; }
    return OverlayMapNative_TrackMappin(ms, id);
  }
  public static func Why() -> String { return OverlayMapNative_Why(); }
}

@if(!ModuleExists("OverlayMapNative"))
public abstract class CyberslopBaneLogTrack {
  public static func Available() -> Bool { return false; }
  public static func Track(ms: ref<MappinSystem>, id: NewMappinID) -> Bool { return false; }
  public static func Why() -> String { return "Overlay Map's native plugin is not installed"; }
}
