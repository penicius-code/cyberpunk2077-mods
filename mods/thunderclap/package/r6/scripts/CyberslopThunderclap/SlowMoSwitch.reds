// Cyberslop Thunderclap 1.2.1 (2026-11-23): slow-motion switch for the CET window mods\CyberslopThunderclap.
// 1.2.0 sent the switch through the TweakDB flat CyberslopThunderclap.Settings.value, but CET's TweakDB:SetFlat
// failed on every 2.5 launch, so "off" never applied. CET now calls SetSlowMo() on this service (CET 1.38.1 can
// call script methods, not read fields). No module, so CET finds it as "CyberslopThunderclapSlowMo".
// The value lives for the game process; CET sets it again at every launch from its config.json. Default: on.
public class CyberslopThunderclapSlowMo extends ScriptableService {
  private let m_on: Bool = true;
  private let m_set: Bool = false;

  public func SetSlowMo(on: Bool) -> Bool {
    this.m_on = on;
    this.m_set = true;
    FTLog("[CyberslopThunderclap] slow motion on cast set to " + (on ? "on" : "off") + " by the CET window");
    return this.m_on;
  }

  public func IsSlowMoOn() -> Bool {
    return this.m_on;
  }

  public func WasSet() -> Bool {
    return this.m_set;
  }

  public static func Get() -> ref<CyberslopThunderclapSlowMo> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"CyberslopThunderclapSlowMo") as CyberslopThunderclapSlowMo;
  }
}
