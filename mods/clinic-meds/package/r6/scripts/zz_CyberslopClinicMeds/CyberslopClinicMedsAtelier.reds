// Cyberslop Clinic Meds - Virtual Atelier store.
// Biotechnica Clinical Supply: Biotechnica's licensed distribution net, the same channel that stocks the city's
// medic counters, ordering by courier (VirtualAtelierDelivery drop point when installed).
// Lists 5 Clinic Meds and the 3 Injuries treatments (1.0.1: ReGen-9 and Clean Slate are drone-only, Pharm Courier). Price 0 = Virtual Atelier charges the game's own buy price,
// the same as at a medic counter. Compiled only when Virtual Atelier is installed.
module CyberslopClinicMeds

@if(ModuleExists("VirtualAtelier.Core"))
@addMethod(gameuiInGameMenuGameController)
protected cb func RegisterCyberslopClinicMedsStore(event: ref<VirtualShopRegistration>) -> Bool {
  event.AddStore(
    n"CYBERSLOPCLINICMEDS",
    "Biotechnica Clinical Supply",
    ["CyberslopNeuroMend.Ampoule", "CyberslopMeds.HemoSeal", "CyberslopMeds.OsteoWeld",
     "CyberslopMeds.Quell", "CyberslopMeds.ChelaTox",
     "Injuries.MedKit", "Injuries.ConcussionPill", "Injuries.Painkiller"],
    [0, 0, 0, 0, 0, 0, 0, 0],
    r"base/gameplay/gui/world/adverts/biotechnica/biotechnica.inkatlas",
    n"logo",
    ["Epic", "Rare", "Epic", "Uncommon", "Common", "Common", "Common", "Common"],
    [1, 1, 1, 1, 1, 1, 1, 1]
  );
}
