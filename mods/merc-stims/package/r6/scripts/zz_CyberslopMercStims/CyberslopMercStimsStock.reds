// Cyberslop Merc Stims - one-time stock top-up for medics opened before the stims were added
// (same approach as Cyberslop Clinic Meds). A vendor saves its stock on first open and rebuilds it only
// after 3 game days without a visit, so a medic V already used would never show the new items. On the next open of
// each vendor whose TweakDB stock lists them, missing stims are added to the saved stock once.
module CyberslopMercStims

// 1.2.1: a new seeding round (m_seeded121) so medics seeded by 1.1.x also get the 1.2.0 items (Tether, Lumen ...),
// and every open strips drone-only items (all Legendary Merc Stims, Clinic Meds ReGen-9 / Clean Slate) from a
// medic's saved stock: they are sold only by the Pharm Courier now.
public class CyberslopMercStimsStock extends ScriptableSystem {
  private persistent let m_seeded: array<TweakDBID>;      // 1.0.0 - 1.2.0 round, no longer read
  private persistent let m_seeded121: array<TweakDBID>;

  public static func Get(gi: GameInstance) -> ref<CyberslopMercStimsStock> {
    return GameInstance.GetScriptableSystemsContainer(gi).Get(n"CyberslopMercStims.CyberslopMercStimsStock") as CyberslopMercStimsStock;
  }

  public final func IsSeeded(id: TweakDBID) -> Bool {
    return ArrayContains(this.m_seeded121, id);
  }

  public final func MarkSeeded(id: TweakDBID) -> Void {
    if !ArrayContains(this.m_seeded121, id) {
      ArrayPush(this.m_seeded121, id);
    }
  }

  public final static func IsOurs(itemID: TweakDBID) -> Bool {
    let rec: ref<Item_Record> = TweakDBInterface.GetItemRecord(itemID);
    return IsDefined(rec) && rec.TagsContains(n"CyberslopStims.Item") && !CyberslopMercStimsStock.IsDroneOnly(itemID);
  }

  public final static func IsDroneOnly(itemID: TweakDBID) -> Bool {
    let rec: ref<Item_Record>;
    if itemID == t"CyberslopMeds.ReGen9" || itemID == t"CyberslopMeds.CleanSlate" { return true; }
    rec = TweakDBInterface.GetItemRecord(itemID);
    return IsDefined(rec) && rec.TagsContains(n"CyberslopStims.Item") && IsDefined(rec.Quality())
      && Equals(rec.Quality().Type(), gamedataQuality.Legendary);
  }
}

@wrapMethod(Vendor)
public final func OnVendorMenuOpen() -> Void {
  this.CyberslopMercStimsStrip();
  this.CyberslopMercStimsSeed();
  wrappedMethod();
}

@addMethod(Vendor)
private final func CyberslopMercStimsStrip() -> Void {
  let i: Int32;
  let removed: Int32 = 0;
  if !this.m_stockInit { return; }
  i = ArraySize(this.m_stock) - 1;
  while i >= 0 {
    if CyberslopMercStimsStock.IsDroneOnly(ItemID.GetTDBID(this.m_stock[i].itemID)) {
      ArrayErase(this.m_stock, i);
      removed += 1;
    }
    i -= 1;
  }
  if removed > 0 {
    this.m_inventoryInit = false;
    FTLog(s"[MercStims] drone-only items taken out of \(TDBID.ToStringDEBUG(this.m_tweakID)) stock: \(removed)");
  }
}

@addMethod(Vendor)
private final func CyberslopMercStimsSeed() -> Void {
  let sys: ref<CyberslopMercStimsStock> = CyberslopMercStimsStock.Get(this.m_gameInstance);
  if !IsDefined(sys) || !IsDefined(this.m_vendorRecord) || sys.IsSeeded(this.m_tweakID) {
    return;
  }
  let pool: array<wref<VendorItem_Record>>;
  let ours: array<wref<VendorItem_Record>>;
  this.m_vendorRecord.ItemStock(pool);
  let i: Int32 = 0;
  while i < ArraySize(pool) {
    if IsDefined(pool[i]) && IsDefined(pool[i].Item()) && CyberslopMercStimsStock.IsOurs(pool[i].Item().GetID()) {
      ArrayPush(ours, pool[i]);
    }
    i += 1;
  }
  if ArraySize(ours) == 0 {
    return;
  }
  sys.MarkSeeded(this.m_tweakID);
  if !this.m_stockInit {
    return;   // stock not built yet: the game's own InitializeStock includes everything
  }
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
      }
      j += 1;
    }
    if !present {
      this.CreateStacksFromVendorItem(this.m_stock, ours[i], player);
      if !ArrayContains(this.m_newItems, itemID) {
        ArrayPush(this.m_newItems, itemID);
      }
      added += 1;
    }
    i += 1;
  }
  if added > 0 {
    this.m_inventoryInit = false;
  }
  FTLog(s"[MercStims] stock top-up \(TDBID.ToStringDEBUG(this.m_tweakID)): \(added) of \(ArraySize(ours)) items added");
}
