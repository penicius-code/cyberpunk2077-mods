module CyberslopThunderclap.Localization
import Codeware.Localization.*

public class LocalizationProvider extends ModLocalizationProvider {
  public func GetPackage(language: CName) -> ref<ModLocalizationPackage> {
    switch language {
      case n"en-us": return new English();
      default: return null;
    }
  }

  public func GetFallback() -> CName {
    return n"en-us";
  }
}

public class English extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    this.Text("CyberslopThunderclap-Name", "Thunderclap");
    this.Text("CyberslopThunderclap-Desc", "Overloads the target's nervous system with an electric burst that throws them back. The target is knocked out cold. The discharge arcs to up to three nearby enemies. Nobody dies from it.");
    this.Text("CyberslopThunderclap-Tooltip", "Target: knocked out and thrown. Impacts can't kill. Arcs to 3 hostiles within 12 m: -25% health and electrocuted, knocked out if left at 25% health or less. Never drops health below 5%. Bosses and MaxTac: stunned. Machines: EMP.");
  }
}
