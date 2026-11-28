// Cyberslop Pharm Courier 1.0.4 (2026-11-26). 1.0.1: Street Cred -1 % per 2 cred, -25 % at 50.
// 1.0.2: Merc Stims 1.2.0 humanity items appended (index 29-33): Anchor, Tether, Lumen, Circuit Breaker, Kill Switch.
// 1.0.3: Cyberslop Clinic Meds appended (index 34-40, full record ids); every Legendary item is drone-only now;
//        neuroblockers (41-44), Dark Future meds (45-49), Injuries treatments (50-52): the whole pharmacy.
// Afterhours Pharm's wholesale desk: bulk orders of the Cyberslop Merc Stims consumables, delivered by drone.
// The CET window (mods\CyberslopPharmCourier) only shows and asks; prices, payment, orders and delivery live here,
// saved with the game (a reloaded save has exactly the orders and eddies it had).
//   Price: list price x quantity, bulk discount per line (10+ -6 %, 20+ -10 %, 30+ -14 %, 50+ -18 %), then the
//   Street Cred rate (-1 % per 2 cred, -25 % at 50). Drone fee per drone (40 units each): clinic locker 250,
//   apartment drop 600. Grey-market lines (Kagami, Hardline, Ghostline, Crank, Synthcoke) need Street Cred 20.
//   Delivery: clinic locker 2:00-2:30 game hours, apartment 2:30-3:00 (sleep and waiting count).
//   Pickup: clinic orders at any medpoint or ripperdoc (a medical / ripperdoc vendor within 7 m), apartment orders
//   at any of V's places (within 20 m of a stash; every vanilla apartment and the Dogtown safehouse has one).
module CyberslopPharmCourier

@if(ModuleExists("CyberslopCashflow"))
import CyberslopCashflow.*

public class PharmCourierStashSeen extends ScriptableSystemRequest {
  public let stash: wref<GameObject>;
}

public class PharmCourier extends ScriptableSystem {
  // orders (one entry per order)
  private persistent let oId: array<Int32>;
  private persistent let oDue: array<Float>;     // game time the drone lands
  private persistent let oDest: array<Int32>;    // 0 clinic locker, 1 apartment
  private persistent let oPaid: array<Int32>;
  private persistent let oFee: array<Int32>;
  private persistent let oUnits: array<Int32>;
  private persistent let oNoticed: array<Int32>; // 1 = arrival message shown
  // order lines
  private persistent let lOrder: array<Int32>;
  private persistent let lItem: array<Int32>;    // catalog index (append-only list below)
  private persistent let lQty: array<Int32>;
  private persistent let nextId: Int32;

  private let m_ids: array<String>;
  private let m_price: array<Int32>;
  private let m_group: array<String>;
  private let m_grey: array<Bool>;
  private let m_cart: array<Int32>;
  private let m_carried: array<Int32>;
  private let m_stashes: array<wref<GameObject>>;
  private let m_at: Int32;
  private let m_atName: String;
  // last quote (CET reads getters, never fields)
  private let q_units: Int32;
  private let q_drones: Int32;
  private let q_list: Int32;
  private let q_bulk: Int32;
  private let q_cred: Int32;
  private let q_goods: Int32;
  private let q_fee: Int32;
  private let q_total: Int32;

  public static func Get(gi: GameInstance) -> ref<PharmCourier> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"CyberslopPharmCourier.PharmCourier") as PharmCourier;
  }

  public static func StashSeen(gi: GameInstance, stash: ref<GameObject>) -> Void {
    let sys: ref<PharmCourier> = PharmCourier.Get(gi);
    if !IsDefined(sys) || !IsDefined(stash) { return; }
    sys.AddStash(stash);
  }

  private func OnAttach() -> Void {
    this.BuildCatalog();
    this.m_at = -1;
  }

  // Index = position in this list. Append only: saved orders keep the index.
  private final func Add(id: String, price: Int32, group: String, grey: Bool) -> Void {
    ArrayPush(this.m_ids, id);
    ArrayPush(this.m_price, price);
    ArrayPush(this.m_group, group);
    ArrayPush(this.m_grey, grey);
    ArrayPush(this.m_cart, 0);
    ArrayPush(this.m_carried, 0);
  }

  private final func BuildCatalog() -> Void {
    if ArraySize(this.m_ids) > 0 { return; }
    this.Add("Vigil", 3200, "Wake and sleep", false);
    this.Add("HoldFast", 1400, "Wake and sleep", false);
    this.Add("Surge", 180, "Wake and sleep", false);
    this.Add("Lull", 250, "Wake and sleep", false);
    this.Add("Kagami", 6500, "Combat", true);
    this.Add("Hardline", 5500, "Combat", true);
    this.Add("Boost", 4000, "Combat", false);
    this.Add("Antitox", 1200, "Detox", false);
    this.Add("Rapidetox", 600, "Detox", false);
    this.Add("Steady", 1800, "Nerve", false);
    this.Add("Serene", 2400, "Nerve", false);
    this.Add("ZeroPoint", 4800, "Nerve", false);
    this.Add("Emberline", 6000, "Nerve", false);
    this.Add("Respirocyte", 5000, "Oxygen", false);
    this.Add("Bronchodilator", 350, "Oxygen", false);
    this.Add("ProteoMax", 650, "Field rations", false);
    this.Add("Electra", 120, "Field rations", false);
    this.Add("CorpoDaily", 300, "Field rations", false);
    this.Add("Ketone", 450, "Field rations", false);
    this.Add("ColdBrew", 180, "Field rations", false);
    this.Add("HydraSalt", 60, "Field rations", false);
    this.Add("NutriGel", 90, "Field rations", false);
    this.Add("NeuroSync", 2800, "Chrome care", false);
    this.Add("OsteoCal", 900, "Chrome care", false);
    this.Add("BioCoolant", 1600, "Chrome care", false);
    this.Add("Rejectol", 1100, "Chrome care", false);
    this.Add("Ghostline", 2500, "Grey market", true);
    this.Add("Crank", 90, "Grey market", true);
    this.Add("Synthcoke", 400, "Grey market", true);
    // 1.0.2 (append only: saved orders keep their index)
    this.Add("Anchor", 16000, "Humanity", false);
    this.Add("Tether", 1600, "Humanity", false);
    this.Add("Lumen", 3500, "Humanity", false);
    this.Add("CircuitBreaker", 6500, "Humanity", false);
    this.Add("KillSwitch", 12000, "Humanity", true);
    // 1.0.3: Cyberslop Clinic Meds (an id with a dot is a full record id)
    this.Add("CyberslopNeuroMend.Ampoule", 12000, "Clinic cures", false);
    this.Add("CyberslopMeds.HemoSeal", 6500, "Clinic cures", false);
    this.Add("CyberslopMeds.OsteoWeld", 9500, "Clinic cures", false);
    this.Add("CyberslopMeds.ReGen9", 38000, "Clinic cures", false);
    this.Add("CyberslopMeds.Quell", 3500, "Clinic cures", false);
    this.Add("CyberslopMeds.CleanSlate", 28000, "Clinic cures", false);
    this.Add("CyberslopMeds.ChelaTox", 900, "Clinic cures", false);
    this.Add("Items.ripperdoc_med_common", 1500, "Neuroblockers", false);
    this.Add("Items.ripperdoc_med_uncommon", 2800, "Neuroblockers", false);
    this.Add("Items.ripperdoc_med", 5000, "Neuroblockers", false);
    this.Add("Items.ripperdoc_med_milspec", 8500, "Neuroblockers", false);
    this.Add("DarkFutureItem.ImmunosuppressantDrug", 750, "Dark Future meds", false);
    this.Add("DarkFutureItem.EndotrisineDrug", 800, "Dark Future meds", false);
    this.Add("DarkFutureItem.AddictionTreatmentDrug", 250, "Dark Future meds", false);
    this.Add("DarkFutureItem.NerveRestoreDrug", 600, "Dark Future meds", false);
    this.Add("DarkFutureItem.HangoverTreatmentDrug", 150, "Dark Future meds", false);
    this.Add("Injuries.MedKit", 250, "Injury care", false);
    this.Add("Injuries.ConcussionPill", 300, "Injury care", false);
    this.Add("Injuries.Painkiller", 400, "Injury care", false);
  }

  // ---------------------------------------------------------------- helpers

  private final func Player() -> ref<PlayerPuppet> = GetPlayer(this.GetGameInstance())
  private final func Now() -> Float = GameInstance.GetTimeSystem(this.GetGameInstance()).GetGameTimeStamp()

  private final func Log(msg: String) -> Void {
    FTLog("[PharmCourier] " + msg);
  }

  private final func Notice(text: String) -> Void {
    let msg: SimpleScreenMessage;
    msg.isShown = true;
    msg.isInstant = true;
    msg.duration = 7.0;
    msg.type = SimpleMessageType.Undefined;
    msg.message = text;
    GameInstance.GetBlackboardSystem(this.GetGameInstance()).Get(GetAllBlackboardDefs().UI_Notifications)
      .SetVariant(GetAllBlackboardDefs().UI_Notifications.OnscreenMessage, ToVariant(msg), true);
  }

  private final func Valid(i: Int32) -> Bool = i >= 0 && i < ArraySize(this.m_ids)

  private final func Record(i: Int32) -> TweakDBID = StrContains(this.m_ids[i], ".") ? TDBID.Create(this.m_ids[i]) : TDBID.Create("CyberslopStims." + this.m_ids[i])

  public final func Eddies(n: Int32) -> String {
    let s: String = IntToString(Abs(n));
    let out: String = "";
    while StrLen(s) > 3 {
      out = "," + StrRight(s, 3) + out;
      s = StrLeft(s, StrLen(s) - 3);
    }
    return (n < 0 ? "-" : "") + s + out;
  }

  // ---------------------------------------------------------------- catalog getters

  public final func Size() -> Int32 {
    this.BuildCatalog();
    return ArraySize(this.m_ids);
  }
  public final func ItemId(i: Int32) -> String = this.Valid(i) ? this.m_ids[i] : ""
  public final func ItemGroup(i: Int32) -> String = this.Valid(i) ? this.m_group[i] : ""
  public final func ItemPrice(i: Int32) -> Int32 = this.Valid(i) ? this.m_price[i] : 0
  public final func ItemGrey(i: Int32) -> Bool = this.Valid(i) && this.m_grey[i]
  public final func ItemName(i: Int32) -> String {
    let s: String;
    if !this.Valid(i) { return ""; }
    if StrContains(this.m_ids[i], ".") {
      let rec: wref<Item_Record> = TweakDBInterface.GetItemRecord(this.Record(i));
      s = IsDefined(rec) ? GetLocalizedTextByKey(rec.DisplayName()) : "";   // 1.0.4: was LocKeyToString (= the key)
      return StrLen(s) > 0 ? s : this.m_ids[i];
    }
    s = GetLocalizedTextByKey(StringToName("CyberslopStims-" + this.m_ids[i] + "-Name"));
    return StrLen(s) > 0 ? s : this.m_ids[i];
  }
  // false when Merc Stims (its TweakXL records) is missing
  public final func ItemExists(i: Int32) -> Bool = this.Valid(i) && IsDefined(TweakDBInterface.GetItemRecord(this.Record(i)))

  public final func Money() -> Int32 {
    let player: ref<PlayerPuppet> = this.Player();
    if !IsDefined(player) { return 0; }
    return GameInstance.GetTransactionSystem(this.GetGameInstance()).GetItemQuantity(player, MarketSystem.Money());
  }

  public final func StreetCred() -> Int32 {
    let player: ref<PlayerPuppet> = this.Player();
    if !IsDefined(player) { return 0; }
    return RoundF(GameInstance.GetStatsSystem(this.GetGameInstance()).GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.StreetCred));
  }

  public final func GreyCred() -> Int32 = 20
  public final func GreyOk() -> Bool = this.StreetCred() >= this.GreyCred()

  // what V carries, refreshed by RefreshCarried() (the window calls it once a second while open)
  public final func RefreshCarried() -> Void {
    let player: ref<PlayerPuppet> = this.Player();
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
    let i: Int32 = 0;
    this.BuildCatalog();
    while i < ArraySize(this.m_ids) {
      this.m_carried[i] = IsDefined(player) ? ts.GetItemQuantity(player, ItemID.FromTDBID(this.Record(i))) : 0;
      i += 1;
    }
  }
  public final func Carried(i: Int32) -> Int32 = this.Valid(i) ? this.m_carried[i] : 0

  // ---------------------------------------------------------------- pricing

  public final func BulkPct(qty: Int32) -> Int32 {
    if qty >= 50 { return 18; }
    if qty >= 30 { return 14; }
    if qty >= 20 { return 10; }
    if qty >= 10 { return 6; }
    return 0;
  }

  public final func CredPct() -> Int32 = Min(25, Max(0, this.StreetCred()) / 2)

  public final func UnitsPerDrone() -> Int32 = 40
  public final func FeePerDrone(dest: Int32) -> Int32 = dest == 1 ? 600 : 250
  public final func EtaMinMinutes(dest: Int32) -> Int32 = dest == 1 ? 150 : 120
  public final func EtaMaxMinutes(dest: Int32) -> Int32 = dest == 1 ? 180 : 150

  // list x qty, less the bulk rate, less the Street Cred rate
  public final func LineTotal(i: Int32, qty: Int32) -> Int32 {
    let f: Float;
    if !this.Valid(i) || qty <= 0 { return 0; }
    f = Cast<Float>(this.m_price[i] * qty) * (1.0 - Cast<Float>(this.BulkPct(qty)) / 100.0);
    f = f * (1.0 - Cast<Float>(this.CredPct()) / 100.0);
    return RoundF(f);
  }

  // ---------------------------------------------------------------- cart

  public final func CartSet(i: Int32, qty: Int32) -> Int32 {
    if !this.Valid(i) { return 0; }
    this.m_cart[i] = Min(99, Max(0, qty));
    return this.m_cart[i];
  }
  public final func CartQty(i: Int32) -> Int32 = this.Valid(i) ? this.m_cart[i] : 0
  public final func CartClear() -> Void {
    let i: Int32 = 0;
    while i < ArraySize(this.m_cart) {
      this.m_cart[i] = 0;
      i += 1;
    }
  }

  // Fills the quote getters below and returns the total.
  public final func Quote(dest: Int32) -> Int32 {
    let i: Int32 = 0;
    let q: Int32;
    let afterBulk: Float;
    this.BuildCatalog();
    this.q_units = 0;
    this.q_list = 0;
    this.q_goods = 0;
    afterBulk = 0.0;
    while i < ArraySize(this.m_cart) {
      q = this.m_cart[i];
      if q > 0 {
        this.q_units += q;
        this.q_list += this.m_price[i] * q;
        afterBulk += Cast<Float>(this.m_price[i] * q) * (1.0 - Cast<Float>(this.BulkPct(q)) / 100.0);
        this.q_goods += this.LineTotal(i, q);
      };
      i += 1;
    }
    this.q_bulk = this.q_list - RoundF(afterBulk);
    this.q_cred = RoundF(afterBulk) - this.q_goods;
    this.q_drones = this.q_units > 0 ? (this.q_units + this.UnitsPerDrone() - 1) / this.UnitsPerDrone() : 0;
    this.q_fee = this.q_drones * this.FeePerDrone(dest);
    this.q_total = this.q_goods + this.q_fee;
    return this.q_total;
  }
  public final func QUnits() -> Int32 = this.q_units
  public final func QDrones() -> Int32 = this.q_drones
  public final func QList() -> Int32 = this.q_list
  public final func QBulk() -> Int32 = this.q_bulk
  public final func QCred() -> Int32 = this.q_cred
  public final func QGoods() -> Int32 = this.q_goods
  public final func QFee() -> Int32 = this.q_fee
  public final func QTotal() -> Int32 = this.q_total

  // "" when the cart can be ordered, else why not
  public final func CartBlocked() -> String {
    let i: Int32 = 0;
    let any: Bool = false;
    while i < ArraySize(this.m_cart) {
      if this.m_cart[i] > 0 {
        any = true;
        if !this.ItemExists(i) {
          return this.m_ids[i] + " is not in the game (Cyberslop Merc Stims missing?).";
        };
        if this.m_grey[i] && !this.GreyOk() {
          return "The grey-market desk only fills " + this.ItemName(i) + " for names with Street Cred " + IntToString(this.GreyCred()) + "+.";
        };
      };
      i += 1;
    }
    return any ? "" : "The cart is empty.";
  }

  public final func PlaceOrder(dest: Int32) -> String {
    let gi: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = this.Player();
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(gi);
    let why: String = this.CartBlocked();
    let total: Int32;
    let id: Int32;
    let minutes: Float;
    let i: Int32 = 0;
    let msg: String;
    if !IsDefined(player) { return "No player."; }
    if StrLen(why) > 0 { return why; }
    dest = dest == 1 ? 1 : 0;
    total = this.Quote(dest);
    if ts.GetItemQuantity(player, MarketSystem.Money()) < total {
      return "The order comes to " + this.Eddies(total) + " eddies, you have " + this.Eddies(this.Money()) + ".";
    };
    PC_Tag(gi, "Afterhours Pharm drone order");
    if !ts.RemoveItem(player, MarketSystem.Money(), total) {
      return "Payment failed.";
    };
    this.nextId += 1;
    id = this.nextId;
    minutes = RandRangeF(Cast<Float>(this.EtaMinMinutes(dest)), Cast<Float>(this.EtaMaxMinutes(dest)));
    ArrayPush(this.oId, id);
    ArrayPush(this.oDue, this.Now() + minutes * 60.0);
    ArrayPush(this.oDest, dest);
    ArrayPush(this.oPaid, total);
    ArrayPush(this.oFee, this.q_fee);
    ArrayPush(this.oUnits, this.q_units);
    ArrayPush(this.oNoticed, 0);
    while i < ArraySize(this.m_cart) {
      if this.m_cart[i] > 0 {
        ArrayPush(this.lOrder, id);
        ArrayPush(this.lItem, i);
        ArrayPush(this.lQty, this.m_cart[i]);
      };
      i += 1;
    }
    msg = "Afterhours Pharm: order #" + IntToString(id) + " paid, " + this.Eddies(total) + " eddies. " + IntToString(this.q_units)
      + (this.q_units == 1 ? " unit" : " units") + " on " + IntToString(this.q_drones) + (this.q_drones == 1 ? " drone" : " drones")
      + (dest == 1 ? " to your apartment" : " to the clinic lockers") + ", ETA " + this.Clock(minutes) + ".";
    this.Log(msg + " " + this.OrderSummary(ArraySize(this.oId) - 1));
    this.CartClear();
    this.Notice(msg);
    return msg;
  }

  public final func Clock(minutes: Float) -> String {
    let m: Int32 = Max(0, CeilF(minutes));
    if m < 60 { return IntToString(m) + " min"; }
    return IntToString(m / 60) + "h " + (m % 60 < 10 ? "0" : "") + IntToString(m % 60) + "m";
  }

  // ---------------------------------------------------------------- orders (k = 0 .. OrderCount()-1)

  public final func OrderCount() -> Int32 = ArraySize(this.oId)
  public final func OrderId(k: Int32) -> Int32 = this.oId[k]
  public final func OrderDest(k: Int32) -> Int32 = this.oDest[k]
  public final func OrderPaid(k: Int32) -> Int32 = this.oPaid[k]
  public final func OrderUnits(k: Int32) -> Int32 = this.oUnits[k]
  public final func OrderMinutesLeft(k: Int32) -> Float = MaxF(0.0, (this.oDue[k] - this.Now()) / 60.0)
  public final func OrderArrived(k: Int32) -> Bool = this.Now() >= this.oDue[k]

  public final func OrderSummary(k: Int32) -> String {
    let id: Int32 = this.oId[k];
    let s: String = "";
    let i: Int32 = 0;
    while i < ArraySize(this.lOrder) {
      if this.lOrder[i] == id {
        s += (StrLen(s) > 0 ? ", " : "") + IntToString(this.lQty[i]) + "x " + this.ItemName(this.lItem[i]);
      };
      i += 1;
    }
    return s;
  }

  private final func DropOrder(k: Int32) -> Void {
    let id: Int32 = this.oId[k];
    let i: Int32 = ArraySize(this.lOrder) - 1;
    while i >= 0 {
      if this.lOrder[i] == id {
        ArrayErase(this.lOrder, i);
        ArrayErase(this.lItem, i);
        ArrayErase(this.lQty, i);
      };
      i -= 1;
    }
    ArrayErase(this.oId, k);
    ArrayErase(this.oDue, k);
    ArrayErase(this.oDest, k);
    ArrayErase(this.oPaid, k);
    ArrayErase(this.oFee, k);
    ArrayErase(this.oUnits, k);
    ArrayErase(this.oNoticed, k);
  }

  // A drone in the air can be recalled: the goods are refunded, the drone fee is not.
  public final func Cancel(id: Int32) -> String {
    let player: ref<PlayerPuppet> = this.Player();
    let k: Int32 = 0;
    let refund: Int32;
    while k < ArraySize(this.oId) {
      if this.oId[k] == id {
        if this.OrderArrived(k) { return "Order #" + IntToString(id) + " has landed already: collect it."; }
        refund = Max(0, this.oPaid[k] - this.oFee[k]);
        if IsDefined(player) && refund > 0 {
          GameInstance.GetTransactionSystem(this.GetGameInstance()).GiveItem(player, MarketSystem.Money(), refund);
        };
        this.DropOrder(k);
        this.Log("order #" + IntToString(id) + " recalled, refund " + IntToString(refund));
        return "Order #" + IntToString(id) + " recalled: " + this.Eddies(refund) + " eddies back, the drone fee is kept.";
      };
      k += 1;
    }
    return "No order #" + IntToString(id) + ".";
  }

  // ---------------------------------------------------------------- where V is (Poll, once a second from CET)

  // -1 nowhere to pick up, 0 at a clinic (medpoint / ripperdoc), 1 at one of V's places
  public final func At() -> Int32 = this.m_at
  public final func AtName() -> String = this.m_atName

  private final func FindClinic(player: ref<PlayerPuppet>) -> Bool {
    let npcs: array<ref<NPCPuppet>> = player.GetNPCsAroundObject(7.0);
    let t: gamedataVendorType;
    let name: String;
    for npc in npcs {
      if IsDefined(npc) && !npc.IsDead() && npc.IsVendor() && !npc.IsHostile() {
        t = npc.GetVendorType();
        if Equals(t, gamedataVendorType.Medical) || Equals(t, gamedataVendorType.RipperDoc) {
          name = npc.GetDisplayName();
          this.m_atName = StrLen(name) > 0 ? name : (Equals(t, gamedataVendorType.RipperDoc) ? "Ripperdoc" : "Medpoint");
          return true;
        };
      };
    }
    return false;
  }

  private final func FindHome(player: ref<PlayerPuppet>) -> Bool {
    let p: Vector4 = player.GetWorldPosition();
    let s: Vector4;
    let dx: Float;
    let dy: Float;
    let i: Int32 = ArraySize(this.m_stashes) - 1;
    while i >= 0 {
      if !IsDefined(this.m_stashes[i]) {
        ArrayErase(this.m_stashes, i);
      } else {
        s = this.m_stashes[i].GetWorldPosition();
        dx = s.X - p.X;
        dy = s.Y - p.Y;
        if dx * dx + dy * dy < 400.0 && AbsF(s.Z - p.Z) < 4.5 {
          this.m_atName = "your place";
          return true;
        };
      };
      i -= 1;
    }
    if this.InApartmentDistrict() {
      this.m_atName = "your place";
      return true;
    };
    return false;
  }

  // V's own places are their own districts (H10 = LittleChina_VApartment). Walks up the parent districts.
  private final func InApartmentDistrict() -> Bool {
    let ps: ref<PreventionSystem> = GameInstance.GetScriptableSystemsContainer(this.GetGameInstance()).Get(n"PreventionSystem") as PreventionSystem;
    let d: wref<District>;
    let r: wref<District_Record>;
    let t: gamedataDistrict;
    let n: Int32 = 0;
    if !IsDefined(ps) { return false; }
    d = ps.GetCurrentDistrict();
    if !IsDefined(d) { return false; }
    r = d.GetDistrictRecord();
    while IsDefined(r) && n < 6 {
      t = r.Type();
      if Equals(t, gamedataDistrict.LittleChina_VApartment) || Equals(t, gamedataDistrict.Northside_Apartment)
        || Equals(t, gamedataDistrict.JapanTown_Apartment) || Equals(t, gamedataDistrict.Glen_Apartment)
        || Equals(t, gamedataDistrict.CorpoPlaza_Apartment) || Equals(t, gamedataDistrict.Dogtown_Hideout) {
        return true;
      };
      r = r.ParentDistrict();
      n += 1;
    }
    return false;
  }

  // Called straight from the Device.OnGameAttached wrap: a ScriptableSystemRequest declared in a module never
  // reached its On<Name> handler, so no stash was ever remembered (fixed 2026-11-26).
  public final func AddStash(stash: ref<GameObject>) -> Void {
    let i: Int32 = ArraySize(this.m_stashes) - 1;
    let pos: Vector4;
    if !IsDefined(stash) { return; }
    while i >= 0 {
      if !IsDefined(this.m_stashes[i]) || Equals(this.m_stashes[i].GetEntityID(), stash.GetEntityID()) {
        ArrayErase(this.m_stashes, i);
      };
      i -= 1;
    }
    ArrayPush(this.m_stashes, stash);
    if ArraySize(this.m_stashes) > 8 { ArrayErase(this.m_stashes, 0); }
    pos = stash.GetWorldPosition();
    this.Log("stash seen at " + FloatToStringPrec(pos.X, 1) + ", " + FloatToStringPrec(pos.Y, 1) + ", "
      + FloatToStringPrec(pos.Z, 1) + " (" + IntToString(ArraySize(this.m_stashes)) + " known)");
  }

  // Location, arrivals and their messages. Returns At().
  public final func Poll() -> Int32 {
    let player: ref<PlayerPuppet> = this.Player();
    let k: Int32 = 0;
    this.m_at = -1;
    this.m_atName = "";
    if !IsDefined(player) { return -1; }
    if this.FindHome(player) {
      this.m_at = 1;
    } else {
      if this.FindClinic(player) { this.m_at = 0; }
    };
    while k < ArraySize(this.oId) {
      if this.oNoticed[k] == 0 && this.OrderArrived(k) {
        this.oNoticed[k] = 1;
        if this.oDest[k] == 1 {
          this.Notice("Afterhours Pharm: order #" + IntToString(this.oId[k]) + " landed in your drop box. Collect it at any of your places.");
        } else {
          this.Notice("Afterhours Pharm: order #" + IntToString(this.oId[k]) + " is in the clinic lockers. Collect it at any medpoint or ripperdoc.");
        };
        this.Log("order #" + IntToString(this.oId[k]) + " arrived");
      };
      k += 1;
    }
    return this.m_at;
  }

  // landed orders that can be picked up where V stands
  public final func ReadyHere() -> Int32 {
    let n: Int32 = 0;
    let k: Int32 = 0;
    if this.m_at < 0 { return 0; }
    while k < ArraySize(this.oId) {
      if this.oDest[k] == this.m_at && this.OrderArrived(k) { n += 1; }
      k += 1;
    }
    return n;
  }

  public final func ReadyAnywhere() -> Int32 {
    let n: Int32 = 0;
    let k: Int32 = 0;
    while k < ArraySize(this.oId) {
      if this.OrderArrived(k) { n += 1; }
      k += 1;
    }
    return n;
  }

  public final func Collect() -> String {
    let player: ref<PlayerPuppet> = this.Player();
    let ts: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGameInstance());
    let k: Int32;
    let i: Int32;
    let id: Int32;
    let orders: Int32 = 0;
    let units: Int32 = 0;
    if !IsDefined(player) { return "No player."; }
    this.Poll();
    if this.m_at < 0 { return "Pick-ups happen at a medpoint or ripperdoc (clinic orders) or at one of your places (apartment orders)."; }
    k = ArraySize(this.oId) - 1;
    while k >= 0 {
      if this.oDest[k] == this.m_at && this.OrderArrived(k) {
        id = this.oId[k];
        i = 0;
        while i < ArraySize(this.lOrder) {
          if this.lOrder[i] == id && this.Valid(this.lItem[i]) && this.lQty[i] > 0 {
            ts.GiveItem(player, ItemID.FromTDBID(this.Record(this.lItem[i])), this.lQty[i]);
            units += this.lQty[i];
          };
          i += 1;
        }
        this.Log("order #" + IntToString(id) + " collected at " + this.m_atName);
        this.DropOrder(k);
        orders += 1;
      };
      k -= 1;
    }
    if orders == 0 {
      return this.m_at == 1 ? "Nothing in your drop box yet." : "Nothing for you in the clinic lockers yet.";
    };
    this.RefreshCarried();
    return (this.m_at == 1 ? "Drop box opened: " : "Locker opened at " + this.m_atName + ": ") + IntToString(units)
      + (units == 1 ? " unit" : " units") + " from " + IntToString(orders) + (orders == 1 ? " order." : " orders.");
  }
}

@if(ModuleExists("CyberslopCashflow"))
func PC_Tag(gi: GameInstance, detail: String) -> Void {
  CashflowBook.TagNow(gi, CashflowCat.Medical(), detail, 3.0);
}
@if(!ModuleExists("CyberslopCashflow"))
func PC_Tag(gi: GameInstance, detail: String) -> Void {}

// Every stash that streams in is remembered (weakly) as one of V's places. Attach can run off the game thread, so
// this only queues a request; the system keeps the list.
@wrapMethod(Device)
protected cb func OnGameAttached() -> Bool {
  let r: Bool = wrappedMethod();
  if IsDefined(this as Stash) {
    PharmCourier.StashSeen(this.GetGame(), this);
  };
  return r;
}
