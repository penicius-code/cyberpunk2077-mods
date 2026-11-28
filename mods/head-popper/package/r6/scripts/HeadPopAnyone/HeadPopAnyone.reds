// HeadPopAnyone.reds
// REDscript helper for the HeadPopAnyone CET mod.
// Install: Drop into r6/scripts/HeadPopAnyone/
// 1.4.1: Mod Settings > Head Popper > Debug > Debug log (default off): FTLog lines to CET gamelog.log, Lua lines via HeadPopHelper.LogOn().
// 1.4: flat RAM cost per pop (Mod Settings > Head Popper, default 20), paid by HeadPopHelper.PayRam().

public class HeadPopSettings extends ScriptableSystem {
    @runtimeProperty("ModSettings.mod", "Head Popper")
    @runtimeProperty("ModSettings.category", "Cost")
    @runtimeProperty("ModSettings.displayName", "RAM cost")
    @runtimeProperty("ModSettings.description", "Flat RAM taken from V for every head pop (hold N 3 s). Not enough RAM = no pop. 0 = free.")
    @runtimeProperty("ModSettings.step", "1")
    @runtimeProperty("ModSettings.min", "0")
    @runtimeProperty("ModSettings.max", "100")
    public let ramCost: Int32 = 20;

    @runtimeProperty("ModSettings.mod", "Head Popper")
    @runtimeProperty("ModSettings.category", "Debug")
    @runtimeProperty("ModSettings.displayName", "Debug log")
    @runtimeProperty("ModSettings.description", "On: every hold, target pick, RAM check and pop is written to the CET log (scripting.log, HeadPopAnyone.log, gamelog.log). For testing.")
    public let debugLog: Bool = false;

    @if(ModuleExists("ModSettingsModule"))
    private func OnAttach() -> Void {
        ModSettings.RegisterListenerToClass(this);
    }

    @if(ModuleExists("ModSettingsModule"))
    private func OnDetach() -> Void {
        ModSettings.UnregisterListenerToClass(this);
    }
}

public class HeadPopHelper {
    public static func LogOn() -> Bool {
        let settings: ref<HeadPopSettings> = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"HeadPopSettings") as HeadPopSettings;
        return IsDefined(settings) && settings.debugLog;
    }

    public static func Log(msg: String) -> Void {
        if HeadPopHelper.LogOn() {
            FTLog("[HeadPopAnyone] " + msg);
        }
    }

    public static func RamCost() -> Int32 {
        let settings: ref<HeadPopSettings> = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"HeadPopSettings") as HeadPopSettings;
        if !IsDefined(settings) {
            return 20;
        }
        return Max(settings.ramCost, 0);
    }

    // Takes the flat RAM cost from the player. False (nothing taken) if the player has less RAM than the cost.
    public static func PayRam() -> Bool {
        let cost: Int32 = HeadPopHelper.RamCost();
        if cost <= 0 {
            return true;
        }
        let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
        if !IsDefined(player) {
            return false;
        }
        let pools: ref<StatPoolsSystem> = GameInstance.GetStatPoolsSystem(GetGameInstance());
        let id: StatsObjectID = Cast<StatsObjectID>(player.GetEntityID());
        let ram: Float = pools.GetStatPoolValue(id, gamedataStatPoolType.Memory, false);
        if ram < Cast<Float>(cost) {
            HeadPopHelper.Log("PayRam: not enough RAM, have " + FloatToString(ram) + ", cost " + IntToString(cost));
            return false;
        }
        HeadPopHelper.Log("PayRam: paid " + IntToString(cost) + " of " + FloatToString(ram));
        pools.RequestChangingStatPoolValue(id, gamedataStatPoolType.Memory, -Cast<Float>(cost), player, false, false);
        return true;
    }

    public static func PopHead(target: ref<GameObject>) -> Bool {
        let puppet: ref<ScriptedPuppet> = target as ScriptedPuppet;
        if !IsDefined(puppet) {
            HeadPopHelper.Log("PopHead: target is not a ScriptedPuppet");
            return false;
        }
        HeadPopHelper.Log("PopHead: " + NameToString(puppet.GetClassName()) + " alive " + ToString(ScriptedPuppet.IsAlive(puppet)) + " defeated " + ToString(ScriptedPuppet.IsDefeated(puppet)) + " record " + TDBID.ToStringDEBUG(puppet.GetRecordID()));

        // Kill if still alive or defeated
        if ScriptedPuppet.IsAlive(puppet) || ScriptedPuppet.IsDefeated(puppet) {
            StatusEffectHelper.ApplyStatusEffect(puppet, t"BaseStatusEffect.ForceKill");
        }

        // Apply our custom status effect that contains the ForceDismembermentEffector
        // (defined in HeadPopAnyone.yaml via TweakXL)
        StatusEffectHelper.ApplyStatusEffect(puppet, t"BaseStatusEffect.HeadPopAnyone_Pop");

        return true;
    }
}
