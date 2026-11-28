// Cyberslop Clinic Meds - one-time stock top-up for medics opened before the meds were added.
// A vendor saves its stock list on first open and only rebuilds it after InGameTimeToRestock (default 3 game days)
// without a visit; every visit restarts that wait. So a medic V already used would never show the new items.
// On the next open of each medic whose TweakDB stock lists them, missing Clinic Meds + Injuries items are added to
// the saved stock once (persistent list of seeded vendors), and the shelf is refilled. Bought-out items are not
// re-added here: after that, the vendor's normal restock handles them.
module CyberslopClinicMeds

public class CyberslopClinicMedsStock extends ScriptableSystem {
  private persistent let m_seeded: array<TweakDBID>;

  public static func Get(gi: GameInstance) -> ref<CyberslopClinicMedsStock> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"CyberslopClinicMeds.CyberslopClinicMedsStock") as CyberslopClinicMedsStock;
  }

  public final func IsSeeded(id: TweakDBID) -> Bool {
    return ArrayContains(this.m_seeded, id);
  }

  public final func MarkSeeded(id: TweakDBID) -> Void {
    if !ArrayContains(this.m_seeded, id) {
      ArrayPush(this.m_seeded, id);
    };
  }

  public final static func IsOurs(itemID: TweakDBID) -> Bool {
    if itemID == t"Injuries.MedKit" || itemID == t"Injuries.ConcussionPill" || itemID == t"Injuries.Painkiller" {
      return true;
    };
    let rec: ref<Item_Record> = TweakDBInterface.GetItemRecord(itemID);
    return IsDefined(rec) && rec.TagsContains(n"CyberslopMeds.Item");
  }
}

@wrapMethod(Vendor)
public final func OnVendorMenuOpen() -> Void {
  this.CyberslopClinicMedsSeed();
  wrappedMethod();
}

@addMethod(Vendor)
private final func CyberslopClinicMedsSeed() -> Void {
  let sys: ref<CyberslopClinicMedsStock> = CyberslopClinicMedsStock.Get(this.m_gameInstance);
  if !IsDefined(sys) || !IsDefined(this.m_vendorRecord) || sys.IsSeeded(this.m_tweakID) {
    return;
  };
  let pool: array<wref<VendorItem_Record>>;
  let ours: array<wref<VendorItem_Record>>;
  this.m_vendorRecord.ItemStock(pool);
  let i: Int32 = 0;
  while i < ArraySize(pool) {
    if IsDefined(pool[i]) && IsDefined(pool[i].Item()) && CyberslopClinicMedsStock.IsOurs(pool[i].Item().GetID()) {
      ArrayPush(ours, pool[i]);
    };
    i += 1;
  };
  if ArraySize(ours) == 0 {
    return;   // not a medic carrying the meds: leave it alone, keep the seeded list short
  };
  sys.MarkSeeded(this.m_tweakID);
  if !this.m_stockInit {
    return;   // stock not built yet: the game's own InitializeStock will include everything
  };
  let player: ref<PlayerPuppet> = GetPlayer(this.m_gameInstance);
  let added: Int32 = 0;
  let j: Int32;
  let present: Bool;
  let itemID: TweakDBID;
  i = 0;
  while i < ArraySize(ours) {
    itemID = ours[i].Item().GetID();
    present = false;
    j = 0;
    while j < ArraySize(this.m_stock) {
      if ItemID.GetTDBID(this.m_stock[j].itemID) == itemID {
        present = true;
        break;
      };
      j += 1;
    };
    if !present {
      this.CreateStacksFromVendorItem(this.m_stock, ours[i], player);
      if !ArrayContains(this.m_newItems, itemID) {
        ArrayPush(this.m_newItems, itemID);
      };
      added += 1;
    };
    i += 1;
  };
  if added > 0 {
    this.m_inventoryInit = false;   // FillVendorInventory refills the shelf from m_stock
  };
  FTLog(s"[ClinicMeds] stock top-up \(TDBID.ToStringDEBUG(this.m_tweakID)): \(added) of \(ArraySize(ours)) items added");
}
