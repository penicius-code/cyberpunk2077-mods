// Cyberslop Merc Stims (1.2.1: Legendary items are drone-only, Pharm Courier) 1.1.0 - Virtual Atelier store "Afterhours Pharm": a fixer-run courier pharmacy for working
// mercs, licensed stock and black-market stims alike. Price 0 = the game's own buy price. Logo: the Biotechnica atlas
// Clinic Meds already uses. Compiled only when Virtual Atelier is installed.
module CyberslopMercStims

@if(ModuleExists("VirtualAtelier.Core"))
@addMethod(gameuiInGameMenuGameController)
protected cb func RegisterCyberslopMercStimsStore(event: ref<VirtualShopRegistration>) -> Bool {
  event.AddStore(
    n"CYBERSLOPMERCSTIMS",
    "Afterhours Pharm",
    ["CyberslopStims.HoldFast", "CyberslopStims.Surge", "CyberslopStims.Steady", "CyberslopStims.Lull", "CyberslopStims.Rapidetox", "CyberslopStims.Antitox", "CyberslopStims.Serene", "CyberslopStims.Bronchodilator", "CyberslopStims.ProteoMax", "CyberslopStims.Electra", "CyberslopStims.CorpoDaily", "CyberslopStims.Ketone", "CyberslopStims.ColdBrew", "CyberslopStims.HydraSalt", "CyberslopStims.NutriGel", "CyberslopStims.OsteoCal", "CyberslopStims.BioCoolant", "CyberslopStims.Rejectol", "CyberslopStims.Tether", "CyberslopStims.Lumen", "CyberslopStims.Crank", "CyberslopStims.Synthcoke"],
    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
    r"base/gameplay/gui/world/adverts/biotechnica/biotechnica.inkatlas",
    n"logo",
    ["Epic", "Rare", "Epic", "Uncommon", "Rare", "Epic", "Epic", "Rare", "Epic", "Rare", "Rare", "Epic", "Rare", "Common", "Common", "Epic", "Epic", "Epic", "Epic", "Epic", "Uncommon", "Rare"],
    [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
  );
}
