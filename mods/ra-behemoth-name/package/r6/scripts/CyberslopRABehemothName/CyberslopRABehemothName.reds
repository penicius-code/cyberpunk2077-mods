// Cyberslop RA Behemoth Name 1.0.0 (2026-11-26)
// Gives the RA Militech Behemoth Mobile Living Conversion truck (Nexus 27754,
// Vehicle.ra_behemoth_border_patrol) its own name, so it can be told apart from the
// other Behemoths in Vanguard Auto and the vehicle call menu.
// The tweak in r6\tweaks\zz_CyberslopRABehemothName points the record at this text.
module CyberslopRABehemothName

import Codeware.Localization.*

public class CRBN_LocalizationProvider extends ModLocalizationProvider {
  public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
    return new CRBN_LanguageEnglish();
  }

  public func GetFallback() -> CName {
    return n"en-us";
  }
}

public class CRBN_LanguageEnglish extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    this.Text("Cyberslop-RA-Behemoth-Name", "RA Behemoth");
  }
}
