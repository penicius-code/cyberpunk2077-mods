// Cyberslop Cashflow 1.1.1 (2026-11-26; 1.1.1: a change handled after the player detached is booked at
// once, a pre-game attach drops the old listener, the open menu is filled in before it is marked open. 1.1.0: thread-safe booking. Money changes and source tags arrive as requests and
// only the book's own handlers touch its lists; the item-removed events of bodies / containers run on parallel job
// threads and pushing from there could corrupt a list (CTD exe+0x270242 class). 1.0.3: nothing booked in the main menu pre-game session; 1.0.2: reward tags only for rewards that carry money, bounty tag from the paid event; 1.0.1: buffered file writes; one-shot source tags, oldest
// first, before the open menu; loot tags ignored in trade screens; NCF callbacks kept)
// Where V's eddies come from and where they go, in real numbers.
//   1. A vanilla inventory listener on V reports every change of eddies (signed amount, new
//      balance), whoever moved them: game code, redscript or CET mods.
//   2. Each change is booked under a source. Hooks around the vanilla code that moves money tag
//      it: trade screens (sales / shopping), the ripperdoc chair, job and gig rewards, NCPD
//      bounties, looted cash, vending machines, car purchases, Delamain cabs, Night City Finance
//      taxes and fixer cuts. Untagged changes are "other". Wallet swaps in cinematics and
//      braindances are booked as "scene" and left out of the statements.
//   3. A statement each game morning (Mod Settings hour, default 07:00): money in and out by
//      source for the last game day, net and balance, as a HUD line. Kept in the save.
//   4. Every change also goes to r6\storages\CyberslopCashflow\cashflow.txt (CSV text, RedFileSystem)
//      with game day, clock, real session seconds, amount, balance, source and detail, plus a
//      5-minute heartbeat; tools\cashflow_report.py turns it into eddies per real hour and per game day.
// Read-only: it never changes an amount. Other mods tag a source with
// CashflowBook.TagNow(gi, CashflowCat.X(), "detail", seconds) right before they move money.
module CyberslopCashflow

import RedFileSystem.*

// ---------------------------------------------------------------- categories

public abstract class CashflowCat {
  public static func Other() -> Int32 = 0
  public static func Vendor() -> Int32 = 1
  public static func Ripperdoc() -> Int32 = 2
  public static func Loot() -> Int32 = 3
  public static func Jobs() -> Int32 = 4
  public static func Bounty() -> Int32 = 5
  public static func Medical() -> Int32 = 6
  public static func Bills() -> Int32 = 7
  public static func Vehicle() -> Int32 = 8
  public static func Fines() -> Int32 = 9
  public static func Materials() -> Int32 = 10
  public static func Transfer() -> Int32 = 11
  public static func Gambling() -> Int32 = 12
  public static func Chrome() -> Int32 = 13
  public static func Scene() -> Int32 = 14
  public static func Count() -> Int32 = 15

  public static func Key(c: Int32) -> String {
    switch c {
      case 1: return "vendor";
      case 2: return "ripperdoc";
      case 3: return "loot";
      case 4: return "jobs";
      case 5: return "bounty";
      case 6: return "medical";
      case 7: return "bills";
      case 8: return "vehicle";
      case 9: return "fines";
      case 10: return "materials";
      case 11: return "transfer";
      case 12: return "gambling";
      case 13: return "chrome";
      case 14: return "scene";
    };
    return "other";
  }

  public static func InLabel(c: Int32) -> String {
    switch c {
      case 1: return "sales";
      case 2: return "chrome sold";
      case 3: return "looted";
      case 4: return "jobs";
      case 5: return "NCPD";
      case 8: return "vehicle sales";
      case 11: return "transfers";
      case 12: return "winnings";
    };
    return "other";
  }

  public static func OutLabel(c: Int32) -> String {
    switch c {
      case 1: return "shopping";
      case 2: return "ripperdoc";
      case 6: return "medical";
      case 7: return "taxes and bills";
      case 8: return "transport";
      case 9: return "fines";
      case 10: return "materials";
      case 11: return "transfers";
      case 12: return "gambling";
      case 13: return "chrome care";
    };
    return "other";
  }
}

// ---------------------------------------------------------------- settings

public class CashflowSettings extends ScriptableSystem {

  @runtimeProperty("ModSettings.mod", "Cyberslop Cashflow")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.displayName", "Enabled")
  @runtimeProperty("ModSettings.description", "Book every change of V's eddies with its source. Read-only, never changes an amount.")
  public let enabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Cyberslop Cashflow")
  @runtimeProperty("ModSettings.category", "Statement")
  @runtimeProperty("ModSettings.displayName", "Morning statement")
  @runtimeProperty("ModSettings.description", "HUD line once a game day: money in and out by source, net, balance.")
  @runtimeProperty("ModSettings.dependency", "enabled")
  public let statement: Bool = true;

  @runtimeProperty("ModSettings.mod", "Cyberslop Cashflow")
  @runtimeProperty("ModSettings.category", "Statement")
  @runtimeProperty("ModSettings.displayName", "Statement hour")
  @runtimeProperty("ModSettings.description", "Game hour the day's statement closes (07 = covers 07:00 yesterday to 07:00 today).")
  @runtimeProperty("ModSettings.step", "1")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "23")
  @runtimeProperty("ModSettings.dependency", "enabled")
  public let statementHour: Int32 = 7;

  @runtimeProperty("ModSettings.mod", "Cyberslop Cashflow")
  @runtimeProperty("ModSettings.category", "Statement")
  @runtimeProperty("ModSettings.displayName", "Transaction lines")
  @runtimeProperty("ModSettings.description", "Small HUD line for each booked change of at least the amount below (the file has them all).")
  @runtimeProperty("ModSettings.dependency", "enabled")
  public let transactionLines: Bool = false;

  @runtimeProperty("ModSettings.mod", "Cyberslop Cashflow")
  @runtimeProperty("ModSettings.category", "Statement")
  @runtimeProperty("ModSettings.displayName", "Transaction line minimum (eddies)")
  @runtimeProperty("ModSettings.step", "50")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "10000")
  @runtimeProperty("ModSettings.dependency", "transactionLines")
  public let transactionMin: Int32 = 500;

  @runtimeProperty("ModSettings.mod", "Cyberslop Cashflow")
  @runtimeProperty("ModSettings.category", "Records")
  @runtimeProperty("ModSettings.displayName", "Write cashflow.txt")
  @runtimeProperty("ModSettings.description", "r6\\storages\\CyberslopCashflow\\cashflow.txt (CSV), one line per change plus a 5-minute heartbeat for eddies per real hour.")
  @runtimeProperty("ModSettings.dependency", "enabled")
  public let writeFile: Bool = true;

  @runtimeProperty("ModSettings.mod", "Cyberslop Cashflow")
  @runtimeProperty("ModSettings.category", "Records")
  @runtimeProperty("ModSettings.displayName", "Log to CET gamelog")
  @runtimeProperty("ModSettings.description", "[Cashflow] line per booked change (FTLog).")
  @runtimeProperty("ModSettings.dependency", "enabled")
  public let debugLog: Bool = false;

  private func OnAttach() -> Void {
    ModSettings.RegisterListenerToClass(this);
  }

  private func OnDetach() -> Void {
    ModSettings.UnregisterListenerToClass(this);
  }

  public static func Get(gi: GameInstance) -> ref<CashflowSettings> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"CyberslopCashflow.CashflowSettings") as CashflowSettings;
  }
}

// ---------------------------------------------------------------- file (RedFileSystem: one storage per process)

public class CashflowFile extends ScriptableService {
  private let m_ready: Bool;
  private let m_launch: Int32;
  private let m_file: ref<File>;
  private let m_buffer: String;
  private let m_lines: Int32;

  private cb func OnLoad() -> Void {
    let storage: ref<FileSystemStorage> = FileSystem.GetStorage("CyberslopCashflow");
    let fresh: Bool;
    this.m_launch = RandRange(100000, 999999);
    if !IsDefined(storage) {
      return;
    };
    fresh = Equals(storage.Exists("cashflow.txt"), FileSystemStatus.False);
    this.m_file = storage.GetFile("cashflow.txt");
    if IsDefined(this.m_file) && fresh {
      this.m_file.WriteText("launch,session_s,game_day,game_clock,delta,balance,source,detail\n", FileSystemWriteMode.Truncate);
    };
    this.m_ready = IsDefined(this.m_file);
  }

  public static func Get() -> ref<CashflowFile> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"CyberslopCashflow.CashflowFile") as CashflowFile;
  }

  public func Launch() -> Int32 = this.m_launch

  // Rows are buffered and written once a second (the book's tick) or every 50 rows, so a
  // "sell all junk" burst is one write, not fifty.
  public func Append(line: String) -> Void {
    if this.m_ready {
      this.m_buffer += line + "\n";
      this.m_lines += 1;
      if this.m_lines >= 50 {
        this.Flush();
      };
    };
  }

  public func Flush() -> Void {
    if this.m_ready && this.m_lines > 0 {
      this.m_file.WriteText(this.m_buffer, FileSystemWriteMode.Append);
      this.m_buffer = "";
      this.m_lines = 0;
    };
  }

  private cb func OnUninitialize() -> Void {
    this.Flush();
  }
}

// ---------------------------------------------------------------- requests (1.1.0)

// Every caller (inventory listener, entity events, other mods) only queues these; the book handles them on its
// own thread. Times are taken when the money moves or the tag is set, so the order of handling does not matter.
public class CashflowTagRequest extends ScriptableSystemRequest {
  public let cat: Int32;
  public let detail: String;
  public let from: Float;
  public let to: Float;
}

public class CashflowMoneyRequest extends ScriptableSystemRequest {
  public let time: Float;
  public let diff: Int32;
  public let total: Int32;
  public let menu: Int32;
  public let menuDetail: String;
  public let scene: Bool;
}

// ---------------------------------------------------------------- listener and timer

public class CashflowInventoryCallback extends InventoryScriptCallback {
  public let book: wref<CashflowBook>;

  public func OnItemQuantityChanged(item: ItemID, diff: Int32, total: Uint32, flaggedAsSilent: Bool) -> Void {
    if diff != 0 && item == MarketSystem.Money() && IsDefined(this.book) {
      this.book.OnMoney(diff, Cast<Int32>(total));
    };
  }
}

public class CashflowTick extends DelayCallback {
  public let book: wref<CashflowBook>;
  public let gen: Int32;

  public func Call() -> Void {
    if IsDefined(this.book) {
      this.book.Tick(this.gen);
    };
  }
}

// ---------------------------------------------------------------- the book

public class CashflowBook extends ScriptableSystem {

  // Statement period (kept in the save).
  public persistent let periodStarted: Bool;
  public persistent let periodDay: Int32;
  public persistent let periodIn: array<Int32>;
  public persistent let periodOut: array<Int32>;
  public persistent let periodOpenBalance: Int32;
  public persistent let lifetimeIn: Int32;
  public persistent let lifetimeOut: Int32;

  private let m_player: wref<PlayerPuppet>;
  private let m_callback: ref<CashflowInventoryCallback>;
  private let m_listener: ref<InventoryScriptListener>;
  private let m_gen: Int32;
  private let m_lastHeartbeat: Float;
  // Changes waiting 0.5 s for their source (tags can arrive a frame after the money).
  private let m_pTime: array<Float>;
  private let m_pDiff: array<Int32>;
  private let m_pTotal: array<Int32>;
  private let m_pMenu: array<Int32>;
  private let m_pMenuDetail: array<String>;
  private let m_pScene: array<Bool>;
  // Open menu (vendor, ripperdoc) owns every change while open and 2 s after.
  private let m_menuOpen: Bool;
  private let m_menuCat: Int32;
  private let m_menuDetail: String;
  private let m_menuGraceUntil: Float;
  // Recent tags with a time window.
  private let m_tCat: array<Int32>;
  private let m_tDetail: array<String>;
  private let m_tFrom: array<Float>;
  private let m_tTo: array<Float>;
  private let m_tUsed: array<Bool>;

  public static func Get(gi: GameInstance) -> ref<CashflowBook> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"CyberslopCashflow.CashflowBook") as CashflowBook;
  }

  // --- public tagging API

  // A change in [now - before, now + after] belongs to this source.
  public static func TagWindow(gi: GameInstance, cat: Int32, detail: String, before: Float, after: Float) -> Void {
    let b: ref<CashflowBook> = CashflowBook.Get(gi);
    let now: Float;
    let req: ref<CashflowTagRequest>;
    if !IsDefined(b) {
      return;
    };
    now = b.RealNow();
    req = new CashflowTagRequest();
    req.cat = cat >= 0 && cat < CashflowCat.Count() ? cat : CashflowCat.Other();
    req.detail = detail;
    req.from = now - before;
    req.to = now + after;
    b.QueueRequest(req);
  }

  private final func OnCashflowTagRequest(request: ref<CashflowTagRequest>) -> Void {
    if !IsDefined(request) {
      return;
    };
    ArrayPush(this.m_tCat, request.cat);
    ArrayPush(this.m_tDetail, request.detail);
    ArrayPush(this.m_tFrom, request.from);
    ArrayPush(this.m_tTo, request.to);
    ArrayPush(this.m_tUsed, false);
    while ArraySize(this.m_tCat) > 16 {
      ArrayErase(this.m_tCat, 0);
      ArrayErase(this.m_tDetail, 0);
      ArrayErase(this.m_tFrom, 0);
      ArrayErase(this.m_tTo, 0);
      ArrayErase(this.m_tUsed, 0);
    };
  }

  // Call right before moving money: the next `seconds` belong to this source.
  public static func TagNow(gi: GameInstance, cat: Int32, detail: String, seconds: Float) -> Void {
    CashflowBook.TagWindow(gi, cat, detail, 0.05, seconds);
  }

  public static func OpenMenu(gi: GameInstance, cat: Int32, detail: String) -> Void {
    let b: ref<CashflowBook> = CashflowBook.Get(gi);
    if IsDefined(b) {
      // 1.1.1: the money callback runs on job threads and reads cat / detail once m_menuOpen
      // is true, so close first, fill in, then open (a vendor opened inside the 2 s grace of the last one)
      b.m_menuOpen = false;
      b.m_menuCat = cat;
      b.m_menuDetail = detail;
      b.m_menuGraceUntil = 0.0;
      b.m_menuOpen = true;
    };
  }

  public final func MenuOpen() -> Bool = this.m_menuOpen

  public static func CloseMenu(gi: GameInstance) -> Void {
    let b: ref<CashflowBook> = CashflowBook.Get(gi);
    if IsDefined(b) && b.m_menuOpen {
      b.m_menuGraceUntil = b.RealNow() + 2.0;
    };
  }

  // --- lifecycle

  private func OnAttach() -> Void {
    this.RegisterNCF();
  }

  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    let player: ref<PlayerPuppet> = GameInstance.GetPlayerSystem(request.owner.GetGame()).GetLocalPlayerMainGameObject() as PlayerPuppet;
    this.m_menuOpen = false;
    ArrayClear(this.m_pTime);
    ArrayClear(this.m_pDiff);
    ArrayClear(this.m_pTotal);
    ArrayClear(this.m_pMenu);
    ArrayClear(this.m_pMenuDetail);
    ArrayClear(this.m_pScene);
    ArrayClear(this.m_tCat);
    ArrayClear(this.m_tDetail);
    ArrayClear(this.m_tFrom);
    ArrayClear(this.m_tTo);
    ArrayClear(this.m_tUsed);
    this.EnsureArrays();
    // 1.1.1: unregister an old listener before either branch; the pre-game return used to null
    // m_player with the listener still registered, so the next real attach could no longer unregister it
    if IsDefined(this.m_player) && IsDefined(this.m_listener) {
      GameInstance.GetTransactionSystem(this.GetGameInstance()).UnregisterInventoryListener(this.m_player, this.m_listener);
    };
    this.m_listener = null;
    this.m_callback = null;
    // 1.0.3: the main menu's pre-game session attaches a throwaway player; booking it wrote a fake
    // "+<balance> other" row (day 0, 12:00) on every launch
    if GameInstance.GetSystemRequestsHandler().IsPreGame() {
      this.m_player = null;
      this.m_gen += 1;
      return;
    };
    if IsDefined(player) {
      // 1.1.0: a second attach without a detach in between must not leave the old listener booking twice
      // (1.1.1: now done above the pre-game check)
      this.m_player = player;
      this.m_callback = new CashflowInventoryCallback();
      this.m_callback.book = this;
      this.m_listener = GameInstance.GetTransactionSystem(player.GetGame()).RegisterInventoryListener(player, this.m_callback);
    };
    this.m_lastHeartbeat = this.RealNow();
    this.m_gen += 1;
    this.Schedule(2.0);
  }

  private func OnPlayerDetach(request: ref<PlayerDetachRequest>) -> Void {
    let player: ref<PlayerPuppet> = this.m_player;
    let f: ref<CashflowFile> = CashflowFile.Get();
    this.Flush(true);
    if IsDefined(f) {
      f.Flush();
    };
    this.m_gen += 1;
    if IsDefined(player) && IsDefined(this.m_listener) {
      GameInstance.GetTransactionSystem(player.GetGame()).UnregisterInventoryListener(player, this.m_listener);
    };
    this.m_listener = null;
    this.m_callback = null;
  }

  private final func EnsureArrays() -> Void {
    while ArraySize(this.periodIn) < CashflowCat.Count() {
      ArrayPush(this.periodIn, 0);
    };
    while ArraySize(this.periodOut) < CashflowCat.Count() {
      ArrayPush(this.periodOut, 0);
    };
  }

  private final func Settings() -> ref<CashflowSettings> {
    return CashflowSettings.Get(this.GetGameInstance());
  }

  public final func RealNow() -> Float {
    return EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
  }

  private final func GameNow() -> Float {
    return GameInstance.GetTimeSystem(this.GetGameInstance()).GetGameTimeStamp();
  }

  public final func Balance() -> Int32 {
    let player: ref<PlayerPuppet> = this.m_player;
    if !IsDefined(player) {
      return 0;
    };
    return GameInstance.GetTransactionSystem(this.GetGameInstance()).GetItemQuantity(player, MarketSystem.Money());
  }

  private final func Schedule(delay: Float) -> Void {
    let cb: ref<CashflowTick> = new CashflowTick();
    cb.book = this;
    cb.gen = this.m_gen;
    GameInstance.GetDelaySystem(this.GetGameInstance()).DelayCallback(cb, delay, false);
  }

  public final func Tick(gen: Int32) -> Void {
    let s: ref<CashflowSettings>;
    let now: Float;
    let f: ref<CashflowFile>;
    if gen != this.m_gen {
      return;
    };
    s = this.Settings();
    now = this.RealNow();
    this.Flush(false);
    f = CashflowFile.Get();
    if IsDefined(f) {
      f.Flush();
    };
    if IsDefined(s) && s.enabled {
      if !this.periodStarted {
        this.StartPeriod(this.Balance());
      };
      if now - this.m_lastHeartbeat >= 300.0 {
        this.m_lastHeartbeat = now;
        this.Csv(0, this.Balance(), "heartbeat", "");
      };
      this.CheckStatement();
    };
    this.Schedule(ArraySize(this.m_pTime) > 0 ? 0.25 : 1.0);
  }

  // Cinematics, lore animations and braindances move the whole wallet out and back.
  private final func InScene() -> Bool {
    let bb: ref<IBlackboard>;
    if !IsDefined(this.m_player) {
      return false;
    };
    bb = this.m_player.GetPlayerStateMachineBlackboard();
    if !IsDefined(bb) {
      return false;
    };
    return bb.GetInt(GetAllBlackboardDefs().PlayerStateMachine.SceneTier) >= 4 || bb.GetBool(GetAllBlackboardDefs().PlayerStateMachine.IsInLoreAnimationScene) || bb.GetBool(GetAllBlackboardDefs().PlayerStateMachine.IsInMinigame);
  }

  // --- booking

  // Inventory listener: runs on whichever thread moved the money, so it only reads and queues.
  public final func OnMoney(diff: Int32, total: Int32) -> Void {
    let s: ref<CashflowSettings> = this.Settings();
    let req: ref<CashflowMoneyRequest>;
    if !IsDefined(s) || !s.enabled {
      return;
    };
    req = new CashflowMoneyRequest();
    req.time = this.RealNow();
    req.diff = diff;
    req.total = total;
    req.menu = -1;
    if this.m_menuOpen && (this.m_menuGraceUntil <= 0.0 || req.time <= this.m_menuGraceUntil) {
      req.menu = this.m_menuCat;
      req.menuDetail = this.m_menuDetail;
    };
    // read now, as 1.0.3 did: a cutscene that hands the wallet back may end within the frame
    req.scene = this.InScene();
    this.QueueRequest(req);
  }

  private final func OnCashflowMoneyRequest(request: ref<CashflowMoneyRequest>) -> Void {
    let f: ref<CashflowFile>;
    if !IsDefined(request) {
      return;
    };
    ArrayPush(this.m_pTime, request.time);
    ArrayPush(this.m_pDiff, request.diff);
    ArrayPush(this.m_pTotal, request.total);
    ArrayPush(this.m_pMenu, request.menu);
    ArrayPush(this.m_pMenuDetail, request.menuDetail);
    ArrayPush(this.m_pScene, request.scene);
    if ArraySize(this.m_pTime) > 256 {
      this.Flush(true);
    };
    // 1.1.1: queued before OnPlayerDetach unregistered the listener but handled after it, so
    // no tick will flush it (the next attach clears the list): book and write it now
    if !IsDefined(this.m_listener) {
      this.Flush(true);
      f = CashflowFile.Get();
      if IsDefined(f) {
        f.Flush();
      };
    };
  }

  private final func Flush(all: Bool) -> Void {
    let now: Float = this.RealNow();
    let cat: Int32;
    let detail: String;
    let t: Float;
    let j: Int32;
    let found: Bool;
    while ArraySize(this.m_pTime) > 0 && (all || now - this.m_pTime[0] >= 0.5) {
      t = this.m_pTime[0];
      cat = CashflowCat.Other();
      detail = "";
      // One tag per change, oldest first (a clinic bill of trauma care then service is two
      // changes in one frame); a tag beats the open menu (sales tax inside a trade screen),
      // and the scene check comes last (a ripperdoc chair may run at a high scene tier).
      found = false;
      j = 0;
      while j < ArraySize(this.m_tCat) {
        if !this.m_tUsed[j] && t >= this.m_tFrom[j] && t <= this.m_tTo[j] {
          cat = this.m_tCat[j];
          detail = this.m_tDetail[j];
          this.m_tUsed[j] = true;
          found = true;
          break;
        };
        j += 1;
      };
      if !found {
        if this.m_pMenu[0] >= 0 {
          cat = this.m_pMenu[0];
          detail = this.m_pMenuDetail[0];
        } else {
          if this.m_pScene[0] {
            cat = CashflowCat.Scene();
          };
        };
      };
      this.Book(this.m_pDiff[0], this.m_pTotal[0], cat, detail);
      ArrayErase(this.m_pTime, 0);
      ArrayErase(this.m_pDiff, 0);
      ArrayErase(this.m_pTotal, 0);
      ArrayErase(this.m_pMenu, 0);
      ArrayErase(this.m_pMenuDetail, 0);
      ArrayErase(this.m_pScene, 0);
    };
    if this.m_menuOpen && this.m_menuGraceUntil > 0.0 && now > this.m_menuGraceUntil {
      this.m_menuOpen = false;
    };
  }

  private final func Book(delta: Int32, bal: Int32, cat: Int32, detail: String) -> Void {
    let s: ref<CashflowSettings> = this.Settings();
    this.EnsureArrays();
    if cat != CashflowCat.Scene() {
      if delta > 0 {
        this.periodIn[cat] += delta;
        this.lifetimeIn += delta;
      } else {
        this.periodOut[cat] -= delta;
        this.lifetimeOut -= delta;
      };
    };
    this.Csv(delta, bal, CashflowCat.Key(cat), detail);
    if !IsDefined(s) {
      return;
    };
    if s.debugLog {
      FTLog("[Cashflow] " + (delta > 0 ? "+" : "") + IntToString(delta) + " " + CashflowCat.Key(cat) + (StrLen(detail) > 0 ? " (" + detail + ")" : "") + " | balance " + IntToString(bal));
    };
    if s.transactionLines && cat != CashflowCat.Scene() && Abs(delta) >= s.transactionMin {
      this.Hud((delta > 0 ? "+" : "-") + CashflowBook.Eddies(Abs(delta)) + "  " + (delta > 0 ? CashflowCat.InLabel(cat) : CashflowCat.OutLabel(cat)) + (StrLen(detail) > 0 ? " · " + detail : ""), 3.0);
    };
  }

  private final func Csv(delta: Int32, bal: Int32, source: String, detail: String) -> Void {
    let s: ref<CashflowSettings> = this.Settings();
    let f: ref<CashflowFile>;
    let ts: Float;
    let day: Int32;
    let sec: Int32;
    if !IsDefined(s) || !s.writeFile {
      return;
    };
    f = CashflowFile.Get();
    if !IsDefined(f) {
      return;
    };
    ts = this.GameNow();
    day = Cast<Int32>(ts / 86400.0);
    sec = Cast<Int32>(ts - Cast<Float>(day) * 86400.0);
    f.Append(IntToString(f.Launch()) + "," + IntToString(Cast<Int32>(this.RealNow())) + "," + IntToString(day) + "," + CashflowBook.Clock(sec) + "," + IntToString(delta) + "," + IntToString(bal) + "," + source + "," + StrReplaceAll(StrReplaceAll(detail, ",", ";"), "\n", " "));
  }

  // --- statement

  private final func StartPeriod(bal: Int32) -> Void {
    let s: ref<CashflowSettings> = this.Settings();
    let ts: Float = this.GameNow();
    let day: Int32 = Cast<Int32>(ts / 86400.0);
    let hour: Int32 = Cast<Int32>((ts - Cast<Float>(day) * 86400.0) / 3600.0);
    let i: Int32 = 0;
    if !IsDefined(s) {
      return;
    };
    this.EnsureArrays();
    while i < CashflowCat.Count() {
      this.periodIn[i] = 0;
      this.periodOut[i] = 0;
      i += 1;
    };
    this.periodDay = hour >= s.statementHour ? day : day - 1;
    this.periodOpenBalance = bal;
    this.periodStarted = true;
  }

  private final func CheckStatement() -> Void {
    let s: ref<CashflowSettings> = this.Settings();
    let closeAt: Float;
    let bal: Int32;
    let text: String;
    if !IsDefined(s) {
      return;
    };
    closeAt = Cast<Float>(this.periodDay + 1) * 86400.0 + Cast<Float>(s.statementHour) * 3600.0;
    if this.GameNow() < closeAt {
      return;
    };
    bal = this.Balance();
    text = this.StatementText(bal);
    if s.statement {
      this.Hud(text, 10.0);
    };
    this.Csv(0, bal, "statement", text);
    if s.debugLog {
      FTLog("[Cashflow] " + text);
    };
    this.StartPeriod(bal);
  }

  public final func StatementText(bal: Int32) -> String {
    let totalIn: Int32 = this.PeriodTotal(true);
    let totalOut: Int32 = this.PeriodTotal(false);
    let net: Int32 = totalIn - totalOut;
    return "Day " + IntToString(this.periodDay) + " statement · in +" + CashflowBook.Eddies(totalIn) + this.Top(this.periodIn, true) + " · out -" + CashflowBook.Eddies(totalOut) + this.Top(this.periodOut, false) + " · net " + (net >= 0 ? "+" : "-") + CashflowBook.Eddies(Abs(net)) + " · balance " + CashflowBook.Eddies(bal);
  }

  // The three biggest sources: " (jobs 2,000, sales 1,350, NCPD 900)".
  private final func Top(arr: array<Int32>, incoming: Bool) -> String {
    let used: array<Int32>;
    let out: String = "";
    let n: Int32 = 0;
    let best: Int32;
    let bestVal: Int32;
    let i: Int32;
    while n < 3 {
      best = -1;
      bestVal = 0;
      i = 0;
      while i < ArraySize(arr) {
        if i != CashflowCat.Scene() && arr[i] > bestVal && !ArrayContains(used, i) {
          best = i;
          bestVal = arr[i];
        };
        i += 1;
      };
      if best < 0 {
        break;
      };
      ArrayPush(used, best);
      out += (n == 0 ? " (" : ", ") + (incoming ? CashflowCat.InLabel(best) : CashflowCat.OutLabel(best)) + " " + CashflowBook.Eddies(bestVal);
      n += 1;
    };
    if n > 0 {
      out += ")";
    };
    return out;
  }

  // Running totals of the open period (Biomonitor window, CET console).
  public final func PeriodSummary() -> String {
    return this.StatementText(this.Balance());
  }

  public final func PeriodTotal(incoming: Bool) -> Int32 {
    let t: Int32 = 0;
    let i: Int32 = 0;
    this.EnsureArrays();
    while i < CashflowCat.Count() {
      if i != CashflowCat.Scene() {
        t += incoming ? this.periodIn[i] : this.periodOut[i];
      };
      i += 1;
    };
    return t;
  }

  // --- Night City Finance deductions (tax, fixer cut, garnishment) and sales tax

  @if(ModuleExists("NightCityFinance.Main"))
  private final func RegisterNCF() -> Void {
    GameInstance.GetCallbackSystem().RegisterCallback(n"NightCityFinance.Main.NCFDeductionEvent", this, n"OnNCFDeduction", true).SetLifetime(CallbackLifetime.Forever);
    GameInstance.GetCallbackSystem().RegisterCallback(n"NightCityFinance.Main.NCFSalesTaxEvent", this, n"OnNCFSalesTax", true).SetLifetime(CallbackLifetime.Forever);
  }

  @if(!ModuleExists("NightCityFinance.Main"))
  private final func RegisterNCF() -> Void {}

  protected cb func OnNCFDeduction(evt: ref<CallbackSystemEvent>) -> Void {
    CashflowBook.TagWindow(this.GetGameInstance(), CashflowCat.Bills(), "NCF tax / fixer cut", 1.5, 1.0);
  }

  protected cb func OnNCFSalesTax(evt: ref<CallbackSystemEvent>) -> Void {
    CashflowBook.TagWindow(this.GetGameInstance(), CashflowCat.Bills(), "NCF sales tax", 1.5, 1.0);
  }

  // --- formatting / HUD

  public final static func Eddies(v: Int32) -> String {
    let s: String = IntToString(v);
    let n: Int32 = StrLen(s);
    let out: String = "";
    let i: Int32 = 0;
    while i < n {
      if i > 0 && (n - i) % 3 == 0 {
        out += ",";
      };
      out += StrMid(s, i, 1);
      i += 1;
    };
    return out;
  }

  public final static func Clock(sec: Int32) -> String {
    let h: Int32 = sec / 3600;
    let m: Int32 = (sec % 3600) / 60;
    return (h < 10 ? "0" : "") + IntToString(h) + ":" + (m < 10 ? "0" : "") + IntToString(m);
  }

  private final func Hud(text: String, seconds: Float) -> Void {
    let msg: SimpleScreenMessage;
    msg.isShown = true;
    msg.duration = seconds;
    msg.message = text;
    msg.isInstant = true;
    msg.type = SimpleMessageType.Money;
    GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_Notifications).SetVariant(GetAllBlackboardDefs().UI_Notifications.WarningMessage, ToVariant(msg), true);
  }
}

// ---------------------------------------------------------------- source hooks (all call through)

// Trade screen: vendors and drop points (the stash uses the same screen without a vendor).
@wrapMethod(FullscreenVendorGameController)
protected cb func OnSetUserData(userData: ref<IScriptable>) -> Bool {
  let r: Bool = wrappedMethod(userData);
  if IsDefined(this.m_vendorUserData) && IsDefined(this.m_VendorDataManager) {
    CashflowBook.OpenMenu(GetGameInstance(), CashflowCat.Vendor(), this.m_VendorDataManager.GetVendorName());
  };
  return r;
}

@wrapMethod(FullscreenVendorGameController)
protected cb func OnUninitialize() -> Bool {
  CashflowBook.CloseMenu(GetGameInstance());
  return wrappedMethod();
}

// Ripperdoc chair: cyberware bought or sold, service fees, other mods' clinic bills.
@wrapMethod(RipperDocGameController)
protected cb func OnInitialize() -> Bool {
  let r: Bool = wrappedMethod();
  if IsDefined(this.m_vendorUserData) && IsDefined(this.m_VendorDataManager) {
    CashflowBook.OpenMenu(GetGameInstance(), CashflowCat.Ripperdoc(), this.m_VendorDataManager.GetVendorName());
  };
  return r;
}

@wrapMethod(RipperDocGameController)
protected cb func OnUninitialize() -> Bool {
  CashflowBook.CloseMenu(GetGameInstance());
  return wrappedMethod();
}

// Quest, gig and NCPD-activity rewards; the reward record names the job. 1.0.2: only rewards that
// carry a currency package tag (every neutralized enemy runs GiveReward for XP only, and its 3 s
// tag used to catch the eddies looted from the body).
@wrapMethod(RPGManager)
public final static func GiveReward(gi: GameInstance, rewardID: TweakDBID, amount: Int32, opt target: StatsObjectID, opt moneyMultiplier: Float) -> Void {
  let rec: ref<RewardBase_Record> = TweakDBInterface.GetRewardBaseRecord(rewardID);
  let currency: array<wref<CurrencyReward_Record>>;
  let name: String;
  if IsDefined(rec) {
    rec.CurrencyPackage(currency);
  };
  if ArraySize(currency) > 0 {
    name = StrReplaceAll(TDBID.ToStringDEBUG(rewardID), "RewardBase.", "");
    CashflowBook.TagNow(gi, StrBeginsWith(name, "ma_") ? CashflowCat.Bounty() : CashflowCat.Jobs(), name, 3.0);
  };
  wrappedMethod(gi, rewardID, amount, target, moneyMultiplier);
}

// NCPD bounty paid on the spot (vanilla chain). 1.0.2: tagged from the completion event, which only
// carries money when some was paid; a CompleteBounty wrap also fired for every claim the Bounty Ledger
// zeroes, for already-awarded and non-bounty targets, and its tag caught the body's loot. The
// event is queued after the transfer, so the window reaches back over the pending changes (they wait
// 0.5 s for a tag). A Ledger payout tags itself first; its older tag wins and this one expires.
@wrapMethod(BountyCollectedNotificationQueue)
protected cb func OnBountyCompletionEvent(evt: ref<BountyCompletionEvent>) -> Bool {
  if IsDefined(evt) && evt.moneyAwarded > 0 {
    CashflowBook.TagWindow(GetGameInstance(), CashflowCat.Bounty(), "NCPD bounty", 0.75, 0.1);
  };
  return wrappedMethod(evt);
}

// Cash leaving a body, container, loot bag or dropped item (can land a frame before V's wallet moves).
public abstract class CashflowLoot {
  public static func Removed(evt: ref<ItemBeingRemovedEvent>, what: String) -> Void {
    let b: ref<CashflowBook>;
    if IsDefined(evt) && evt.itemID == MarketSystem.Money() {
      // A vendor paying for V's goods also loses money: that is a sale, not loot.
      b = CashflowBook.Get(GetGameInstance());
      if IsDefined(b) && b.MenuOpen() {
        return;
      };
      CashflowBook.TagWindow(GetGameInstance(), CashflowCat.Loot(), what, 1.0, 1.0);
    };
  }
}

@wrapMethod(ScriptedPuppet)
protected cb func OnItemRemovedEvent(evt: ref<ItemBeingRemovedEvent>) -> Bool {
  let r: Bool = wrappedMethod(evt);
  if IsDefined(evt) && evt.itemID == MarketSystem.Money() && !this.IsPlayer() {
    CashflowLoot.Removed(evt, "body");
  };
  return r;
}

@wrapMethod(gameLootContainerBase)
protected cb func OnItemRemoveddEvent(evt: ref<ItemBeingRemovedEvent>) -> Bool {
  let r: Bool = wrappedMethod(evt);
  CashflowLoot.Removed(evt, "container");
  return r;
}

@wrapMethod(gameLootBag)
protected cb func OnItemRemoveddEvent(evt: ref<ItemBeingRemovedEvent>) -> Bool {
  let r: Bool = wrappedMethod(evt);
  CashflowLoot.Removed(evt, "loot bag");
  return r;
}

@wrapMethod(gameItemDropObject)
protected final cb func OnItemRemoveddEvent(evt: ref<ItemBeingRemovedEvent>) -> Bool {
  let r: Bool = wrappedMethod(evt);
  CashflowLoot.Removed(evt, "dropped");
  return r;
}

// Vending machines (paid dispense outside a trade screen).
@wrapMethod(MarketSystem)
public func OnDispenseRequest(request: ref<DispenseRequest>) -> Void {
  if IsDefined(request) && request.shouldPay {
    CashflowBook.TagNow(GetGameInstance(), CashflowCat.Vendor(), "vending machine", 3.0);
  };
  wrappedMethod(request);
}

// Car bought on the autofixer site.
@wrapMethod(gameuiVehicleShopGameController)
protected cb func OnVehicleShopPurchaseEventEvent(evt: ref<VehicleShopPurchaseEvent>) -> Bool {
  CashflowBook.TagNow(GetGameInstance(), CashflowCat.Vehicle(), "car purchase", 3.0);
  return wrappedMethod(evt);
}

// Delamain cab fare.
@wrapMethod(DelamainTaxiSystem)
private final func OnPayTravelRequest(request: ref<PayTravelRequest>) -> Void {
  CashflowBook.TagNow(this.GetGameInstance(), CashflowCat.Vehicle(), "Delamain cab", 3.0);
  wrappedMethod(request);
}
