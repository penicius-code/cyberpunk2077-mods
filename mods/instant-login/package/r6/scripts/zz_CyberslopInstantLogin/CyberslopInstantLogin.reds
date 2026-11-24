// Cyberslop Instant Login 1.0.0 (2026-11-04)
// Add-on for NewBrowser (Nexus 32851 by L3LY, file "NewBrowser-login screen"): skips its typed login
// (NC-USR-xxxxx typed at 0.12 s per character, 8-12 password stars, 6 "Connecting..." pulses at 0.15 s =
// about 3.5 s) on every in-game computer. NewBrowser's redesigned screens stay as they are.
//
// How: NewBrowser's @wrapMethod(ComputerInkGameController) TurnOn plays the sequence once per controller, while
// its field m_hasShownLoginSequence is false. SetupWidgets runs in OnInitialize (DeviceInkGameControllerBase),
// before any Refresh/TurnOn, so setting the flag there works whatever the wrap order. A computer still asleep
// shows NewBrowser's idle screensaver labels; waking it (zoom in) goes straight to the desktop.
// Needs NewBrowser installed (the field is NewBrowser's): without it this file fails to compile, remove it.

@wrapMethod(ComputerInkGameController)
protected func SetupWidgets() -> Void {
  this.m_hasShownLoginSequence = true;
  wrappedMethod();
}
