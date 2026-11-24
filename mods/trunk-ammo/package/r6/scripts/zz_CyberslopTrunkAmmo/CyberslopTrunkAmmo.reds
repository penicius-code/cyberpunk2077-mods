// Cyberslop Trunk Ammo 1.1.1
// 1.1.1 (2026-11-23): the playthrough log keeps the newest 30 launch files (trunk-N.txt, N keeps counting up from the
//   highest number); older ones are deleted at launch (was: one more file every launch, 263 files by 11-23).
// 1.1.0 (2026-11-02): playthrough log. One file per game launch, r6\storages\CyberslopTrunkAmmo\trunk-N.txt,
//   tab-separated rows (launch, load, session, open, cal, done, oldmod, skip, bench, warn). Written only when a
//   trunk / hood opens or ammo is crafted at the bench (one file append per event, nothing per frame).
//   Off: Logging() = false.
// 1.0.0: opening the trunk (or hood) of V's own car tops V's ammo up to the carry cap, as Vehicle Ammo Refill did,
//   but every round is pressed from crafting components at the bench price (same recipe, same
//   CraftingCostReduction, same material-refund perk). A pressed batch V can't carry stays in the trunk as loose
//   rounds, free next time. Recipes (tiered by caliber) in r6\tweaks\zz_CyberslopTrunkAmmo\ammo_recipes.yaml.
// Replaces Vehicle Ammo Refill (disable that one in Vortex). Needs redscript, TweakXL, RedFileSystem.

module CyberslopTrunkAmmo

import RedFileSystem.*

// ---------------------------------------------------------------- log file

public class TrunkLog extends ScriptableService {
  private let file: ref<File>;

  public static func Logging() -> Bool = true

  // RedFileSystem grants a storage only once per process, so the service holds it.
  private cb func OnLoad() -> Void {
    let storage: ref<FileSystemStorage>;
    let number: Int32;
    if !TrunkLog.Logging() { return; };
    storage = FileSystem.GetStorage("CyberslopTrunkAmmo");
    if !IsDefined(storage) { return; };
    number = TrunkLog.HighestNumber(storage) + 1;
    while Equals(storage.Exists("trunk-" + IntToString(number) + ".txt"), FileSystemStatus.True) {
      number += 1;
    };
    TrunkLog.Prune(storage, number - TrunkLog.KeepFiles());
    this.file = storage.GetFile("trunk-" + IntToString(number) + ".txt");
    this.Write("launch\tversion=1.1.1\tfile=trunk-" + IntToString(number) + ".txt\n");
  }

  // 1.1.1: launch files kept (the new one included)
  public static func KeepFiles() -> Int32 = 30

  private static func FileNumber(name: String) -> Int32 {
    if !StrBeginsWith(name, "trunk-") || !StrEndsWith(name, ".txt") || StrLen(name) < 11 {
      return -1;
    };
    return StringToInt(StrMid(name, 6, StrLen(name) - 10), -1);
  }

  private static func HighestNumber(storage: ref<FileSystemStorage>) -> Int32 {
    let top: Int32 = 0;
    for f in storage.GetFiles() {
      top = Max(top, TrunkLog.FileNumber(f.GetFilename()));
    };
    return top;
  }

  // deletes trunk-N.txt with N <= upTo
  private static func Prune(storage: ref<FileSystemStorage>, upTo: Int32) -> Void {
    let n: Int32;
    for f in storage.GetFiles() {
      n = TrunkLog.FileNumber(f.GetFilename());
      if n >= 0 && n <= upTo {
        storage.DeleteFile(f.GetFilename());
      };
    };
  }

  public static func Get() -> ref<TrunkLog> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"CyberslopTrunkAmmo.TrunkLog") as TrunkLog;
  }

  // text = one or more finished lines ("...\n"); one append per event.
  public final func Write(text: String) -> Void {
    if IsDefined(this.file) && StrLen(text) > 0 {
      this.file.WriteText(text, FileSystemWriteMode.Append);
    };
  }

  public static func Out(text: String) -> Void {
    let log: ref<TrunkLog>;
    if !TrunkLog.Logging() { return; };
    log = TrunkLog.Get();
    if IsDefined(log) { log.Write(text); };
  }
}

// ---------------------------------------------------------------- the trunk

// Caliber index: 0 pistol, 1 rifle, 2 shells, 3 sniper.
public class TrunkAmmo extends ScriptableSystem {

  // Loose rounds per caliber left in the trunk from a pressed batch (already paid for).
  public persistent let loosePistol: Int32;
  public persistent let looseRifle: Int32;
  public persistent let looseShotgun: Int32;
  public persistent let looseSniper: Int32;

  // Per call: components spent by quality (Common..Legendary), rounds given, shortfalls.
  private let m_spent: array<Int32>;
  private let m_given: array<Int32>;
  private let m_short: String;
  private let m_fromLooseOnly: Bool;
  private let m_warnedOldMod: Bool;

  // Log state: event buffer, per-caliber counters, session row once per load.
  private let m_log: String;
  private let m_sessionLogged: Bool;
  private let m_cLooseUsed: Int32;
  private let m_cBatches: Int32;
  private let m_cCharged: Int32;
  private let m_cPressed: Int32;
  private let m_cShort: Int32;
  private let m_cCost: String;
  private let m_cPer: Int32;
  private let m_pendingMsg: String;
  private let m_pendingBefore: array<Int32>;

  public static func Get(gi: GameInstance) -> ref<TrunkAmmo> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"CyberslopTrunkAmmo.TrunkAmmo") as TrunkAmmo;
  }

  private func OnPlayerAttach(request: ref<PlayerAttachRequest>) -> Void {
    this.m_sessionLogged = false;
    this.m_warnedOldMod = false;
    TrunkLog.Out("load\t" + this.Clock() + "\tloose=" + this.LooseText() + "\n");
  }

  // --- calibers

  public final func AmmoID(i: Int32) -> TweakDBID {
    if i == 0 { return t"Ammo.HandgunAmmo"; };
    if i == 1 { return t"Ammo.RifleAmmo"; };
    if i == 2 { return t"Ammo.ShotgunAmmo"; };
    return t"Ammo.SniperRifleAmmo";
  }

  private final func Label(i: Int32) -> String {
    if i == 0 { return "pistol"; };
    if i == 1 { return "rifle"; };
    if i == 2 { return "shells"; };
    return "sniper";
  }

  public final func IndexOf(ammo: TweakDBID) -> Int32 {
    let i: Int32 = 0;
    while i < 4 {
      if ammo == this.AmmoID(i) { return i; };
      i += 1;
    };
    return -1;
  }

  private final func GetLoose(i: Int32) -> Int32 {
    if i == 0 { return this.loosePistol; };
    if i == 1 { return this.looseRifle; };
    if i == 2 { return this.looseShotgun; };
    return this.looseSniper;
  }

  private final func SetLoose(i: Int32, n: Int32) -> Void {
    n = Max(n, 0);
    if i == 0 { this.loosePistol = n; return; };
    if i == 1 { this.looseRifle = n; return; };
    if i == 2 { this.looseShotgun = n; return; };
    this.looseSniper = n;
  }

  private final func QualityIndex(record: wref<Item_Record>) -> Int32 {
    let q: gamedataQuality = RPGManager.GetItemQualityFromRecord(record);
    if Equals(q, gamedataQuality.Uncommon) { return 1; };
    if Equals(q, gamedataQuality.Rare) { return 2; };
    if Equals(q, gamedataQuality.Epic) { return 3; };
    if Equals(q, gamedataQuality.Legendary) { return 4; };
    return 0;
  }

  private final func QualityName(q: Int32) -> String {
    if q == 1 { return "Uncommon"; };
    if q == 2 { return "Rare"; };
    if q == 3 { return "Epic"; };
    if q == 4 { return "Legendary"; };
    return "Common";
  }

  private final func MaterialID(q: Int32) -> TweakDBID {
    if q == 1 { return t"Items.UncommonMaterial1"; };
    if q == 2 { return t"Items.RareMaterial1"; };
    if q == 3 { return t"Items.EpicMaterial1"; };
    if q == 4 { return t"Items.LegendaryMaterial1"; };
    return t"Items.CommonMaterial1";
  }

  // Calibers of the equipped weapons first, then rifle, pistol, shells, sniper.
  private final func Order(player: ref<PlayerPuppet>) -> array<Int32> {
    let order: array<Int32>;
    let fallback: array<Int32> = [1, 0, 2, 3];
    let eq: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    let weaponID: ItemID;
    let weaponRec: ref<WeaponItem_Record>;
    let ammoRec: wref<Item_Record>;
    let idx: Int32;
    let s: Int32 = 0;
    if IsDefined(eq) {
      while s < 3 {
        weaponID = eq.GetItemInEquipSlot(gamedataEquipmentArea.WeaponWheel, s);
        if ItemID.IsValid(weaponID) {
          weaponRec = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(weaponID));
          if IsDefined(weaponRec) {
            ammoRec = weaponRec.Ammo();
            if IsDefined(ammoRec) {
              idx = this.IndexOf(ammoRec.GetID());
              if idx >= 0 && !ArrayContains(order, idx) { ArrayPush(order, idx); };
            };
          };
        };
        s += 1;
      };
    };
    s = 0;
    while s < 4 {
      if !ArrayContains(order, fallback[s]) { ArrayPush(order, fallback[s]); };
      s += 1;
    };
    return order;
  }

  // Live carry cap (Custom Max Ammo, Dark Future...), read like the crafting bench does.
  // Needs at least one round in the inventory; -1 when there is none.
  private final func Cap(player: ref<PlayerPuppet>, itemID: ItemID) -> Int32 {
    let data: wref<gameItemData> = GameInstance.GetTransactionSystem(player.GetGame()).GetItemData(player, itemID);
    if !IsDefined(data) { return -1; };
    return Cast<Int32>(data.GetStatValueByType(gamedataStatType.Quantity) + 0.01);
  }

  // Bench recipe in text: "1 Uncommon / 12".
  private final func RecipeText(i: Int32) -> String {
    let crafting: ref<CraftingSystem> = CraftingSystem.GetInstance(this.GetGameInstance());
    let cost: array<IngredientData> = crafting.GetItemCraftingCost(TweakDBInterface.GetItemRecord(this.AmmoID(i)));
    let txt: String = "";
    let k: Int32 = 0;
    while k < ArraySize(cost) {
      txt += (k > 0 ? " + " : "") + IntToString(cost[k].quantity) + " " + this.QualityName(this.QualityIndex(cost[k].id));
      k += 1;
    };
    return txt + " / " + IntToString(CraftingSystem.GetAmmoBulletAmount(this.AmmoID(i)));
  }

  // --- log text helpers (only built when logging is on)

  private final func Clock() -> String {
    let t: GameTime = GameInstance.GetTimeSystem(this.GetGameInstance()).GetGameTime();
    let m: Int32 = GameTime.Minutes(t);
    return "day=" + IntToString(GameTime.Days(t)) + "\ttime=" + IntToString(GameTime.Hours(t)) + ":" + (m < 10 ? "0" : "") + IntToString(m)
      + "\tsim=" + FloatToStringPrec(EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance())), 1);
  }

  private final func LooseText() -> String {
    return IntToString(this.loosePistol) + "/" + IntToString(this.looseRifle) + "/" + IntToString(this.looseShotgun) + "/" + IntToString(this.looseSniper);
  }

  public final func AmmoText(player: ref<PlayerPuppet>) -> String {
    let q: array<Int32> = this.Quantities(player);
    return IntToString(q[0]) + "/" + IntToString(q[1]) + "/" + IntToString(q[2]) + "/" + IntToString(q[3]);
  }

  private final func CapText(player: ref<PlayerPuppet>) -> String {
    let txt: String = "";
    let i: Int32 = 0;
    while i < 4 {
      txt += (i > 0 ? "/" : "") + IntToString(this.Cap(player, ItemID.FromTDBID(this.AmmoID(i))));
      i += 1;
    };
    return txt;
  }

  // Components carried, Common/Uncommon/Rare/Epic/Legendary.
  public final func MatsText(player: ref<PlayerPuppet>) -> String {
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
    let txt: String = "";
    let q: Int32 = 0;
    while q < 5 {
      txt += (q > 0 ? "/" : "") + IntToString(ts.GetItemQuantityWithDuplicates(player, ItemID.CreateQuery(this.MaterialID(q))));
      q += 1;
    };
    return txt;
  }

  private final func IntsText(a: array<Int32>) -> String {
    let txt: String = "";
    let i: Int32 = 0;
    while i < ArraySize(a) {
      txt += (i > 0 ? "/" : "") + IntToString(a[i]);
      i += 1;
    };
    return txt;
  }

  private final func OrderText(order: array<Int32>) -> String {
    let txt: String = "";
    let i: Int32 = 0;
    while i < ArraySize(order) {
      txt += (i > 0 ? "," : "") + this.Label(order[i]);
      i += 1;
    };
    return txt;
  }

  // Once per load, at the first event: recipes, perks, caps, so tunings can be told apart later.
  private final func LogSession(player: ref<PlayerPuppet>) -> Void {
    let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(this.GetGameInstance());
    let id: StatsObjectID = Cast<StatsObjectID>(player.GetEntityID());
    let recipes: String = "";
    let i: Int32 = 0;
    if this.m_sessionLogged || !TrunkLog.Logging() { return; };
    this.m_sessionLogged = true;
    while i < 4 {
      recipes += (i > 0 ? "," : "") + this.Label(i) + ":" + this.RecipeText(i);
      i += 1;
    };
    this.m_log += "session\t" + this.Clock() + "\trecipes=" + recipes
      + "\tcostcut=" + FloatToStringPrec(stats.GetStatValue(id, gamedataStatType.CraftingCostReduction), 2)
      + "\trefund=" + FloatToStringPrec(stats.GetStatValue(id, gamedataStatType.CraftingMaterialRetrieveChance), 2)
      + "\tcaps=" + this.CapText(player) + "\n";
  }

  // --- pressing

  // Serves n rounds of caliber i: loose trunk rounds first, then whole pressed batches as far
  // as the components last. Returns the rounds served; the rest of a batch stays loose.
  private final func Supply(player: ref<PlayerPuppet>, i: Int32, n: Int32, probe: Bool) -> Int32 {
    let gi: GameInstance = this.GetGameInstance();
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gi);
    let crafting: ref<CraftingSystem> = CraftingSystem.GetInstance(gi);
    let ammoID: TweakDBID = this.AmmoID(i);
    let loose: Int32 = this.GetLoose(i);
    let fromLoose: Int32 = Min(loose, n);
    let rest: Int32 = n - fromLoose;
    let perBatch: Int32;
    let cost: array<IngredientData>;
    let batches: Int32;
    let charged: Int32;
    let chance: Float;
    let pressed: Int32;
    let used: Int32;
    let q: Int32;
    let k: Int32;
    loose -= fromLoose;
    this.m_cLooseUsed += fromLoose;
    if rest > 0 {
      perBatch = CraftingSystem.GetAmmoBulletAmount(ammoID);
      cost = crafting.GetItemCraftingCost(TweakDBInterface.GetItemRecord(ammoID));
      this.m_cPer = perBatch;
      this.m_cCost = "";
      k = 0;
      while k < ArraySize(cost) {
        this.m_cCost += (k > 0 ? "+" : "") + IntToString(cost[k].quantity) + "x" + this.QualityName(this.QualityIndex(cost[k].id));
        k += 1;
      };
      if perBatch <= 0 || ArraySize(cost) == 0 {
        this.m_log += "warn\tcal=" + this.Label(i) + "\tno usable recipe (per=" + IntToString(perBatch) + " ingredients=" + IntToString(ArraySize(cost)) + ")\n";
      };
      if perBatch > 0 && ArraySize(cost) > 0 {
        batches = (rest + perBatch - 1) / perBatch;
        k = 0;
        while k < ArraySize(cost) {
          if cost[k].quantity > 0 {
            batches = Min(batches, ts.GetItemQuantityWithDuplicates(player, ItemID.CreateQuery(cost[k].id.GetID())) / cost[k].quantity);
          };
          k += 1;
        };
        if batches > 0 {
          // Same refund perk roll as CraftingSystem.CraftItem, once per batch.
          chance = GameInstance.GetStatsSystem(gi).GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.CraftingMaterialRetrieveChance);
          charged = batches;
          if chance > 0.0 {
            k = 0;
            while k < batches {
              if RandF() < chance { charged -= 1; };
              k += 1;
            };
          };
          k = 0;
          while k < ArraySize(cost) {
            if cost[k].quantity * charged > 0 {
              ts.RemoveItemByTDBID(player, cost[k].id.GetID(), cost[k].quantity * charged, true);
              q = this.QualityIndex(cost[k].id);
              this.m_spent[q] += cost[k].quantity * charged;
            };
            k += 1;
          };
          this.m_fromLooseOnly = false;
          pressed = batches * perBatch;
          used = Min(pressed, rest);
          loose += pressed - used;
          rest -= used;
          this.m_cBatches += batches;
          this.m_cCharged += charged;
          this.m_cPressed += pressed;
        };
      };
      if rest > 0 {
        this.m_cShort += rest;
        // probe = first round into empty pockets (cap unknown yet): report the caliber as empty.
        this.m_short += (StrLen(this.m_short) > 0 ? ", " : "") + (probe ? this.Label(i) + " empty" : IntToString(rest) + " " + this.Label(i)) + " (" + this.RecipeText(i) + ")";
      };
    };
    this.SetLoose(i, loose);
    return n - rest;
  }

  // One caliber: up to the live cap.
  private final func TopUp(player: ref<PlayerPuppet>, i: Int32) -> Void {
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
    let itemID: ItemID = ItemID.FromTDBID(this.AmmoID(i));
    let have: Int32 = ts.GetItemQuantity(player, itemID);
    let haveBefore: Int32 = have;
    let looseBefore: Int32 = this.GetLoose(i);
    let cap: Int32 = -1;
    let got: Int32;
    let probeFailed: Bool = false;
    this.m_cLooseUsed = 0;
    this.m_cBatches = 0;
    this.m_cCharged = 0;
    this.m_cPressed = 0;
    this.m_cShort = 0;
    this.m_cCost = "";
    this.m_cPer = 0;
    if have <= 0 {
      // The cap stat only exists on an owned stack: serve the first round alone.
      if this.Supply(player, i, 1, true) < 1 {
        probeFailed = true;
      } else {
        ts.GiveItem(player, itemID, 1);
        this.m_given[i] += 1;
        have = 1;
      };
    };
    if !probeFailed {
      cap = this.Cap(player, itemID);
      if cap < 0 {
        this.m_log += "warn\tcal=" + this.Label(i) + "\tno cap stat on the ammo stack (have=" + IntToString(have) + ")\n";
      };
      cap = Min(cap, have + 999);
      if cap > have {
        got = this.Supply(player, i, cap - have, false);
        if got > 0 {
          ts.GiveItem(player, itemID, got);
          this.m_given[i] += got;
        };
      };
    };
    // One row per caliber that was not already full.
    if TrunkLog.Logging() && (probeFailed || cap > haveBefore) {
      this.m_log += "cal\tcal=" + this.Label(i) + "\thave=" + IntToString(haveBefore) + "\tcap=" + IntToString(cap)
        + "\tneed=" + (probeFailed ? "?" : IntToString(cap - haveBefore)) + "\tloose_before=" + IntToString(looseBefore)
        + "\tloose_used=" + IntToString(this.m_cLooseUsed) + "\trecipe=" + this.m_cCost + "/" + IntToString(this.m_cPer)
        + "\tbatches=" + IntToString(this.m_cBatches) + "\tcharged=" + IntToString(this.m_cCharged)
        + "\trefunded=" + IntToString(this.m_cBatches - this.m_cCharged) + "\tpressed=" + IntToString(this.m_cPressed)
        + "\tgiven=" + IntToString(this.m_given[i]) + "\tloose_after=" + IntToString(this.GetLoose(i))
        + "\tshort=" + (probeFailed ? "empty" : IntToString(this.m_cShort)) + "\n";
    };
  }

  public final func Quantities(player: ref<PlayerPuppet>) -> array<Int32> {
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(player.GetGame());
    let out: array<Int32>;
    let i: Int32 = 0;
    while i < 4 {
      ArrayPush(out, ts.GetItemQuantity(player, ItemID.FromTDBID(this.AmmoID(i))));
      i += 1;
    };
    return out;
  }

  // Returns the trunk message ("" when V was already full and nothing is short).
  public final func Restock(player: ref<PlayerPuppet>, door: String, vehicle: ref<VehicleObject>) -> String {
    let order: array<Int32> = this.Order(player);
    let msg: String = "";
    let parts: String = "";
    let i: Int32 = 0;
    let logging: Bool = TrunkLog.Logging();
    ArrayClear(this.m_spent);
    ArrayClear(this.m_given);
    while i < 5 { ArrayPush(this.m_spent, 0); i += 1; };
    i = 0;
    while i < 4 { ArrayPush(this.m_given, 0); i += 1; };
    this.m_short = "";
    this.m_fromLooseOnly = true;
    this.m_log = "";
    if logging {
      this.LogSession(player);
      this.m_log += "open\t" + this.Clock() + "\tdoor=" + door + "\tveh=" + this.VehicleName(vehicle)
        + "\torder=" + this.OrderText(order) + "\tammo=" + this.AmmoText(player) + "\tcaps=" + this.CapText(player)
        + "\tloose=" + this.LooseText() + "\tmats=" + this.MatsText(player) + "\n";
    };
    i = 0;
    while i < ArraySize(order) {
      this.TopUp(player, order[i]);
      i += 1;
    };
    i = 0;
    while i < 4 {
      if this.m_given[i] > 0 {
        msg += (StrLen(msg) > 0 ? ", " : "") + "+" + IntToString(this.m_given[i]) + " " + this.Label(i);
      };
      i += 1;
    };
    i = 0;
    while i < 5 {
      if this.m_spent[i] > 0 {
        parts += (StrLen(parts) > 0 ? ", " : "") + IntToString(this.m_spent[i]) + " " + this.QualityName(i);
      };
      i += 1;
    };
    if StrLen(msg) > 0 {
      msg = "Trunk ammo: " + msg + (StrLen(parts) > 0 ? "  |  pressed from " + parts : (this.m_fromLooseOnly ? "  |  loose rounds" : ""));
    };
    if StrLen(this.m_short) > 0 {
      msg += (StrLen(msg) > 0 ? "  |  " : "") + "Out of parts: " + this.m_short;
    };
    if logging {
      this.m_log += "done\tgiven=" + this.IntsText(this.m_given) + "\tspent=" + this.IntsText(this.m_spent)
        + "\tammo=" + this.AmmoText(player) + "\tloose=" + this.LooseText() + "\tmats=" + this.MatsText(player)
        + "\tshort=" + (StrLen(this.m_short) > 0 ? this.m_short : "-") + "\tmsg=" + (StrLen(msg) > 0 ? msg : "-") + "\n";
    };
    return msg;
  }

  public final func VehicleName(vehicle: ref<VehicleObject>) -> String {
    let rec: wref<Vehicle_Record>;
    if !IsDefined(vehicle) { return "-"; };
    rec = vehicle.GetRecord();
    if !IsDefined(rec) { return "-"; };
    return TDBID.ToStringDEBUG(rec.GetID());
  }

  public final func HasShort() -> Bool {
    return StrLen(this.m_short) > 0;
  }

  // Vehicle Ammo Refill still deployed: it fills anything left over for free.
  public final func CheckOldMod(before: array<Int32>, after: array<Int32>) -> String {
    let i: Int32 = 0;
    while i < 4 {
      if after[i] > before[i] {
        this.m_log += "oldmod\tbefore=" + this.IntsText(before) + "\tafter=" + this.IntsText(after) + "\tnote=another mod added free ammo after the restock (Vehicle Ammo Refill still deployed?)\n";
        if !this.m_warnedOldMod {
          this.m_warnedOldMod = true;
          return "Vehicle Ammo Refill is still on and hands out free ammo: disable it in Vortex.";
        };
        return "";
      };
      i += 1;
    };
    return "";
  }

  // Writes the event's rows in one append.
  public final func FlushLog() -> Void {
    TrunkLog.Out(this.m_log);
    this.m_log = "";
  }

  public final func LogLine(line: String) -> Void {
    TrunkLog.Out(line + "\n");
  }

  public final func LogClock() -> String {
    return this.Clock();
  }

  public final func SetPending(msg: String, before: array<Int32>) -> Void {
    this.m_pendingMsg = msg;
    this.m_pendingBefore = before;
  }

  public final func FinishPending(player: ref<PlayerPuppet>) -> Void {
    let warn: String;
    let msg: String = this.m_pendingMsg;
    if ArraySize(this.m_pendingBefore) != 4 { return; };
    warn = this.CheckOldMod(this.m_pendingBefore, this.Quantities(player));
    ArrayClear(this.m_pendingBefore);
    this.m_pendingMsg = "";
    if StrLen(warn) > 0 {
      msg = warn + (StrLen(msg) > 0 ? "  |  " + msg : "");
    };
    if StrLen(msg) > 0 {
      player.SetWarningMessage(msg, (this.HasShort() || StrLen(warn) > 0) ? SimpleMessageType.Negative : SimpleMessageType.Neutral);
    };
    this.FlushLog();
  }
}

// ---------------------------------------------------------------- hooks

public func CyberslopTrunkAmmoOpen(vehicle: ref<VehicleObject>, door: String) -> Void {
  let player: ref<PlayerPuppet>;
  let sys: ref<TrunkAmmo>;
  let before: array<Int32>;
  let msg: String;
  if !IsDefined(vehicle) { return; };
  sys = TrunkAmmo.Get(vehicle.GetGame());
  if !IsDefined(sys) { return; };
  if !vehicle.IsPlayerVehicle() {
    if TrunkLog.Logging() {
      sys.LogLine("skip\t" + sys.LogClock() + "\tdoor=" + door + "\tveh=" + sys.VehicleName(vehicle) + "\treason=not_player_vehicle");
    };
    return;
  };
  player = GameInstance.GetPlayerSystem(vehicle.GetGame()).GetLocalPlayerMainGameObject() as PlayerPuppet;
  if !IsDefined(player) { return; };
  msg = sys.Restock(player, door, vehicle);
  before = sys.Quantities(player);
  // Store the pre-wrap state on the system; the after-check runs once the other wraps are done.
  sys.SetPending(msg, before);
}

public func CyberslopTrunkAmmoAfter(vehicle: ref<VehicleObject>) -> Void {
  let player: ref<PlayerPuppet>;
  let sys: ref<TrunkAmmo>;
  if !IsDefined(vehicle) || !vehicle.IsPlayerVehicle() { return; };
  player = GameInstance.GetPlayerSystem(vehicle.GetGame()).GetLocalPlayerMainGameObject() as PlayerPuppet;
  sys = TrunkAmmo.Get(vehicle.GetGame());
  if !IsDefined(player) || !IsDefined(sys) { return; };
  sys.FinishPending(player);
}

@wrapMethod(VehicleComponent)
protected cb func OnOpenTrunk(evt: ref<VehicleOpenTrunk>) -> Bool {
  let vehicle: ref<VehicleObject> = this.GetVehicle();
  let result: Bool;
  CyberslopTrunkAmmoOpen(vehicle, "trunk");
  result = wrappedMethod(evt);
  CyberslopTrunkAmmoAfter(vehicle);
  return result;
}

@wrapMethod(VehicleComponent)
protected cb func OnOpenHood(evt: ref<VehicleOpenHood>) -> Bool {
  let vehicle: ref<VehicleObject> = this.GetVehicle();
  let result: Bool;
  CyberslopTrunkAmmoOpen(vehicle, "hood");
  result = wrappedMethod(evt);
  CyberslopTrunkAmmoAfter(vehicle);
  return result;
}

// Bench crafting of ammo (EnhancedCraft also wraps CraftItem; wraps chain).
@wrapMethod(CraftingSystem)
private final func CraftItem(target: wref<GameObject>, itemRecord: ref<Item_Record>, amount: Int32, opt ammoBulletAmount: Int32) -> wref<gameItemData> {
  let player: ref<PlayerPuppet>;
  let sys: ref<TrunkAmmo>;
  let idx: Int32 = -1;
  let ammoBefore: String;
  let matsBefore: String;
  let result: wref<gameItemData>;
  if TrunkLog.Logging() && IsDefined(itemRecord) {
    sys = TrunkAmmo.Get(this.GetGameInstance());
    player = target as PlayerPuppet;
    if IsDefined(sys) && IsDefined(player) {
      idx = sys.IndexOf(itemRecord.GetID());
      if idx >= 0 {
        ammoBefore = sys.AmmoText(player);
        matsBefore = sys.MatsText(player);
      };
    };
  };
  result = wrappedMethod(target, itemRecord, amount, ammoBulletAmount);
  if idx >= 0 {
    sys.LogLine("bench\t" + sys.LogClock() + "\tammo=" + TDBID.ToStringDEBUG(itemRecord.GetID()) + "\tbatches=" + IntToString(amount)
      + "\tper=" + IntToString(ammoBulletAmount) + "\tammo_before=" + ammoBefore + "\tammo_after=" + sys.AmmoText(player)
      + "\tmats_before=" + matsBefore + "\tmats_after=" + sys.MatsText(player));
  };
  return result;
}
