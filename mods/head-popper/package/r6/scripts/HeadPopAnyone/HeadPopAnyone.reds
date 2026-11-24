// HeadPopAnyone.reds
// REDscript helper for the HeadPopAnyone CET mod.
// Install: Drop into r6/scripts/HeadPopAnyone/

public class HeadPopHelper {
    public static func PopHead(target: ref<GameObject>) -> Bool {
        let puppet: ref<ScriptedPuppet> = target as ScriptedPuppet;
        if !IsDefined(puppet) {
            return false;
        }

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

