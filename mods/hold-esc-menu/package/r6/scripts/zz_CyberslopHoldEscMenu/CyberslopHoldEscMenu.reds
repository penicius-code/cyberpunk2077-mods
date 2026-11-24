// Cyberslop Hold Esc Menu 1.0.0 (patch 2.5)
// The pause menu opens only when Esc was held for at least 0.5 s; a shorter tap does nothing.
// Vanilla opens it on the release of OpenPauseMenu (gameuiInGameMenuGameController.OnAction), so the menu still opens
// on release: opening it while Esc is still down would let the release reach the menu's own Back (OnPostOnRelease) and
// close it again. Keyboard / mouse only: the pad's View button is left to vanilla and Overlay Map's hold handling.
module CyberslopHoldEscMenu

@addField(gameuiInGameMenuGameController)
private let cyHoldEscDown: Bool;

@addField(gameuiInGameMenuGameController)
private let cyHoldEscPressedAt: Float;

@wrapMethod(gameuiInGameMenuGameController)
protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
    if Equals(ListenerAction.GetName(action), n"OpenPauseMenu") {
        let player: ref<GameObject> = this.GetPlayerControlledObject();
        if IsDefined(player) && player.PlayerLastUsedKBM() {
            let actionType: gameinputActionType = ListenerAction.GetType(action);
            let now: Float = EngineTime.ToFloat(GameInstance.GetEngineTime(player.GetGame()));
            if Equals(actionType, gameinputActionType.BUTTON_PRESSED) {
                if !this.cyHoldEscDown {
                    this.cyHoldEscDown = true;
                    this.cyHoldEscPressedAt = now;
                }
            } else {
                if Equals(actionType, gameinputActionType.BUTTON_RELEASED) {
                    let held: Bool = this.cyHoldEscDown && now - this.cyHoldEscPressedAt >= 0.5;
                    this.cyHoldEscDown = false;
                    if !held {
                        // Short tap (or a release without a press seen here): swallow it like vanilla does, no menu.
                        ListenerActionConsumer.Consume(consumer);
                        return false;
                    }
                }
            }
        }
    }
    return wrappedMethod(action, consumer);
}
