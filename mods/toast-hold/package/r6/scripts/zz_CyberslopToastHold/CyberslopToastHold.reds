// Cyberslop Toast Hold 1.0.1 (2026-11-27)
//
// On-screen notifications stay longer (Mod Settings > Cyberslop Toast Hold > "Extra seconds on screen", default 6).
//
// Why raising a notification's time alone does nothing: the game's toasts are whole animations stored in the archives
// that fade themselves out at about 5 s (the queue time only decides how long the slot is kept). So each toast is now
// played up to a marker where nothing is mid-fade, held there for the extra seconds, then played on to its end
// (inkAnimOptions toMarker / fromMarker + executionDelay), and its queue time is raised by the same amount.
//   - Quest new / updated / failed / completed, district banner, NCPD job done, new activity, hacking reward, shard
//     picked up (JournalNotification, NewLocationNotification, NCPDJobDoneNotification, ShardCollectedNotification;
//     queue time JournalNotificationQueue.m_showDuration 6 -> 6.5 + hold, kept in step with the setting).
//   - Item received (ItemAddedNotification.OnIconCallback replaced; ItemsNotificationQueue.PushItemNotification
//     replaced, only its 7.5 s changes).
//   - Money gained / spent (CurrencyNotification.OnMainAnimationOver replaced: the outro starts after the hold;
//     RewardNotificationCurrencyDelayed queue time + hold).
//   - Incoming texts (NewHudPhoneGameController.PushSMSNotification replaced, only its 6.7 s changes; the text toast
//     already holds at its outro until the queue time ends).
//   - Mod messages on the OnscreenMessage channel (CyberBane notes, couriers, clinics...): the animation used to cap them
//     at about 4.6 s whatever they asked for; now they get what they asked for plus the hold.
//   - Mod messages on the WarningMessage channel (NC Finance, Cashflow, Dark Future, EDO...): their time plus the hold.
//   - NCPD-style police messages (Bounty Ledger, the game's police-car lines): fixed 7.9 s animation, now paused at
//     3.6 s (nothing mid-fade there) for the extra seconds.
// 1.0.1: hold points moved off running fades (quest toasts at loop_end, police by a pause); the journal slot follows a
// setting change at once and a toast never holds longer than its slot; the money outro waits through executionDelay
// (no timer that a second payment or a menu could leave behind); 0 = the game's own 6 s slot.
// Everything here runs on the UI thread, except the two one-number replaces (item / text queue time), which do
// exactly what the game's own functions do apart from that number: no shared lists, nothing new on job threads.
// Remove: delete r6\scripts\zz_CyberslopToastHold\ (game closed). Saves do not depend on it.

public class CyberslopToastHoldSettings extends ScriptableSystem {
  @runtimeProperty("ModSettings.mod", "Cyberslop Toast Hold")
  @runtimeProperty("ModSettings.displayName", "Extra seconds on screen")
  @runtimeProperty("ModSettings.description", "How much longer notifications stay: quest, district, shard, item, money and text toasts, and mod messages. 0 = the game's own timing (CyberBane's texts keep their own 12.7 s).")
  @runtimeProperty("ModSettings.step", "0.5")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "12.0")
  public let holdSeconds: Float = 6.0;

  // The hold the journal queue's slot (m_showDuration) is sized for right now (valid once queueSized is set).
  public let queueHold: Float;

  public let queueSized: Bool;

  public let queue: wref<JournalNotificationQueue>;

  private func OnAttach() -> Void {
    ModSettings.RegisterListenerToClass(this);
    ModSettings.RegisterListenerToModifications(this);
  }

  private func OnDetach() -> Void {
    ModSettings.UnregisterListenerToClass(this);
    ModSettings.UnregisterListenerToModifications(this);
  }

  // Mod Settings applied a change: the journal queue's slot follows it for the next toasts.
  public func OnModSettingsChange() -> Void {
    if IsDefined(this.queue) {
      this.queue.CSTHResize();
    }
  }
}

public abstract class CyberslopToastHold {
  public static func Settings() -> ref<CyberslopToastHoldSettings> {
    let c = GameInstance.GetScriptableSystemsContainer(GetGameInstance());
    if !IsDefined(c) {
      return null;
    }
    return c.Get(n"CyberslopToastHoldSettings") as CyberslopToastHoldSettings;
  }

  public static func Seconds() -> Float {
    let s = CyberslopToastHold.Settings();
    if !IsDefined(s) {
      return 6.0;
    }
    return ClampF(s.holdSeconds, 0.0, 12.0);
  }

  // Where each quest_update animation is held: the last marker before the outro at which no element is mid-fade
  // (checked against the extracted .inkanim: loop_end for most; for the rest the outro marker itself is clean, or the
  // one fade running there is within 0.05 of its end value). Marker names differ in case and underscore.
  public static func JournalMarker(anim: CName) -> CName {
    if Equals(anim, n"notification_quest_updated") || Equals(anim, n"notification_quest_failed")
        || Equals(anim, n"notification_quest_completed") || Equals(anim, n"notification_LocationAdded")
        || Equals(anim, n"notification_new_activity") || Equals(anim, n"notification_ma_completed") {
      return n"loop_end";
    }
    if Equals(anim, n"notification_shard") {
      return n"Outro_Start";
    }
    if Equals(anim, n"notification_new_quest_added") || Equals(anim, n"notification_hacking_reward")
        || Equals(anim, n"notification_quest_completed_original") {
      return n"OutroStart";
    }
    return n"";
  }

  // The hold an animation can take before its queue slot ends: quest completed has a fixed 12 s slot (animation
  // 8.0 s), the hacking reward a fixed 10 s one (6.24 s). Everything else runs on m_showDuration, which was sized for
  // the queue's hold: never hold longer than that, or the toast is cut off before its fade.
  public static func JournalHold(anim: CName) -> Float {
    let h = CyberslopToastHold.Seconds();
    if Equals(anim, n"notification_quest_completed") {
      return MinF(h, 3.9);
    }
    if Equals(anim, n"notification_hacking_reward") {
      return MinF(h, 3.5);
    }
    let s = CyberslopToastHold.Settings();
    if IsDefined(s) && s.queueSized {
      return MinF(h, s.queueHold);
    }
    return h;
  }

  public static func Timer(root: wref<inkWidget>, secs: Float) -> ref<inkAnimProxy> {
    if !IsDefined(root) {
      return null;
    }
    let def = new inkAnimDef();
    let ip = new inkAnimTransparency();
    ip.SetDuration(secs);
    ip.SetStartTransparency(1.0);
    ip.SetEndTransparency(1.0);
    ip.SetIsAdditive(true);
    def.AddInterpolator(ip);
    return root.PlayAnimation(def);
  }
}

// ---- Quest / district / NCPD / activity toasts ------------------------------------------------------------------------

@wrapMethod(JournalNotificationQueue)
protected cb func OnInitialize() -> Bool {
  let r = wrappedMethod();
  this.CSTHResize();
  let s = CyberslopToastHold.Settings();
  if IsDefined(s) {
    s.queue = this;
  }
  return r;
}

// The slot for toasts pushed from now on: 6.5 s + hold (the longest of these animations is 6.25 s), or the game's own
// 6 s when the hold is off. Toasts already queued keep the slot they were pushed with.
@addMethod(JournalNotificationQueue)
public func CSTHResize() -> Void {
  let h = CyberslopToastHold.Seconds();
  if h < 0.25 {
    h = 0.0;
  }
  this.m_showDuration = h > 0.0 ? 6.5 + h : 6.0;
  let s = CyberslopToastHold.Settings();
  if IsDefined(s) {
    s.queueHold = h;
    s.queueSized = true;
  }
}

@addField(JournalNotification)
public let csthAnim: CName;

@addField(JournalNotification)
public let csthMarker: CName;

@addField(JournalNotification)
public let csthHold: Float;

// Restarts the animation the controller just started: up to the hold marker, then (CSTHIntroDone) the rest after the
// hold. m_animProxy stays the playing proxy, so the game's pause / resume of notifications still works.
@addMethod(JournalNotification)
public func CSTHHold() -> Void {
  if !IsDefined(this.m_questNotificationData) || !IsDefined(this.m_animProxy) {
    return;
  }
  let anim = this.m_questNotificationData.animation;
  let marker = CyberslopToastHold.JournalMarker(anim);
  let hold = CyberslopToastHold.JournalHold(anim);
  if Equals(marker, n"") || hold < 0.25 {
    return;
  }
  // Silently: a subclass (district, NCPD) reaches this twice per toast, the first time through super; a stop that
  // fired CSTHIntroDone could leave a second, early outro running.
  this.m_animProxy.UnregisterFromAllCallbacks(inkanimEventType.OnFinish);
  this.m_animProxy.Stop(true);
  this.csthAnim = anim;
  this.csthMarker = marker;
  this.csthHold = hold;
  let o: inkAnimOptions;
  o.toMarker = marker;
  this.m_animProxy = this.PlayLibraryAnimation(anim, o);
  if IsDefined(this.m_animProxy) {
    this.m_animProxy.RegisterToCallback(inkanimEventType.OnFinish, this, n"CSTHIntroDone");
  }
}

@addMethod(JournalNotification)
protected cb func CSTHIntroDone(proxy: ref<inkAnimProxy>) -> Bool {
  if !IsDefined(proxy) || !proxy.IsFinished() || proxy != this.m_animProxy {
    return false;
  }
  let o: inkAnimOptions;
  o.fromMarker = this.csthMarker;
  o.executionDelay = this.csthHold;
  this.m_animProxy = this.PlayLibraryAnimation(this.csthAnim, o);
  return true;
}

// Before the controller stops its proxy for a new notification, our callback comes off it.
@addMethod(JournalNotification)
public func CSTHDetach() -> Void {
  if IsDefined(this.m_animProxy) {
    this.m_animProxy.UnregisterFromAllCallbacks(inkanimEventType.OnFinish);
  }
}

@wrapMethod(JournalNotification)
public cb func SetNotificationData(notificationData: ref<GenericNotificationViewData>) -> Void {
  this.CSTHDetach();
  wrappedMethod(notificationData);
  this.CSTHHold();
}

// The subclasses stop m_animProxy in their own body before calling super: the detach must come first here too.
@wrapMethod(NewLocationNotification)
public cb func SetNotificationData(notificationData: ref<GenericNotificationViewData>) -> Void {
  this.CSTHDetach();
  wrappedMethod(notificationData);
  this.CSTHHold();
}

@wrapMethod(NCPDJobDoneNotification)
public cb func SetNotificationData(notificationData: ref<GenericNotificationViewData>) -> Void {
  this.CSTHDetach();
  wrappedMethod(notificationData);
  this.CSTHHold();
}

// ---- Shard picked up ----------------------------------------------------------------------------------------------

@addField(ShardCollectedNotification)
public let csthHold: Float;

@wrapMethod(ShardCollectedNotification)
public cb func SetNotificationData(notificationData: ref<GenericNotificationViewData>) -> Void {
  if IsDefined(this.m_animProxy) {
    this.m_animProxy.UnregisterFromAllCallbacks(inkanimEventType.OnFinish);
  }
  wrappedMethod(notificationData);
  let hold = CyberslopToastHold.JournalHold(n"notification_shard");
  if hold < 0.25 || !IsDefined(this.m_animProxy) {
    return;
  }
  this.m_animProxy.Stop(true);
  this.csthHold = hold;
  let o: inkAnimOptions;
  o.toMarker = n"Outro_Start";
  this.m_animProxy = this.PlayLibraryAnimation(n"notification_shard", o);
  if IsDefined(this.m_animProxy) {
    this.m_animProxy.RegisterToCallback(inkanimEventType.OnFinish, this, n"CSTHIntroDone");
  }
}

@addMethod(ShardCollectedNotification)
protected cb func CSTHIntroDone(proxy: ref<inkAnimProxy>) -> Bool {
  if !IsDefined(proxy) || !proxy.IsFinished() || proxy != this.m_animProxy {
    return false;
  }
  let o: inkAnimOptions;
  o.fromMarker = n"Outro_Start";
  o.executionDelay = this.csthHold;
  this.m_animProxy = this.PlayLibraryAnimation(n"notification_shard", o);
  return true;
}

// ---- Item received ------------------------------------------------------------------------------------------------

// Vanilla body, only the 7.50 changed (no installed mod wraps or replaces it).
@replaceMethod(ItemsNotificationQueue)
public final func PushItemNotification(itemID: ItemID, itemRarity: CName) -> Void {
  let currentItemRecordTags: array<CName>;
  let data: ref<ItemAddedNotificationViewData>;
  let isShard: Bool;
  let notificationData: gameuiGenericNotificationData;
  let currentItemRecord: ref<Item_Record> = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(itemID));
  if IsDefined(currentItemRecord) {
    currentItemRecordTags = currentItemRecord.Tags();
  }
  isShard = ArrayContains(currentItemRecordTags, n"Shard");
  if itemID != MarketSystem.Money() && !isShard && !ArrayContains(currentItemRecordTags, n"DontShowLooted") {
    data = new ItemAddedNotificationViewData();
    data.animation = this.m_itemNotification;
    data.itemRarity = itemRarity;
    data.itemID = itemID;
    data.title = GetLocalizedText("Story-base-gameplay-gui-widgets-notifications-quest_update-_localizationString19");
    notificationData.time = 7.50 + CyberslopToastHold.Seconds();
    notificationData.widgetLibraryItemName = this.m_itemNotification;
    notificationData.notificationData = data;
    this.AddNewNotificationData(notificationData);
  }
}

@addField(ItemAddedNotification)
public let csthProxy: ref<inkAnimProxy>;

@addField(ItemAddedNotification)
public let csthHold: Float;

// Vanilla plays the whole animation untracked; Item_Received_SMALL (the loot toast) is now held at OutroStart (its
// three fades there end within 0.05 of their end value).
@replaceMethod(ItemAddedNotification)
protected cb func OnIconCallback(e: ref<iconAtlasCallbackData>) -> Bool {
  inkWidgetRef.SetVisible(this.m_itemImage, Equals(e.loadResult, inkIconResult.Success));
  let hold = CyberslopToastHold.Seconds();
  if Equals(this.m_animationName, n"Item_Received_SMALL") && hold >= 0.25 {
    if IsDefined(this.csthProxy) {
      this.csthProxy.UnregisterFromAllCallbacks(inkanimEventType.OnFinish);
      this.csthProxy.Stop(true);
    }
    this.csthHold = hold;
    let o: inkAnimOptions;
    o.toMarker = n"OutroStart";
    this.csthProxy = this.PlayLibraryAnimation(this.m_animationName, o);
    if IsDefined(this.csthProxy) {
      this.csthProxy.RegisterToCallback(inkanimEventType.OnFinish, this, n"CSTHIntroDone");
    }
  } else {
    this.PlayLibraryAnimation(this.m_animationName);
  }
}

@addMethod(ItemAddedNotification)
protected cb func CSTHIntroDone(proxy: ref<inkAnimProxy>) -> Bool {
  if !IsDefined(proxy) || !proxy.IsFinished() || proxy != this.csthProxy {
    return false;
  }
  let o: inkAnimOptions;
  o.fromMarker = n"OutroStart";
  o.executionDelay = this.csthHold;
  this.csthProxy = this.PlayLibraryAnimation(this.m_animationName, o);
  return true;
}

// ---- Money gained / spent -----------------------------------------------------------------------------------------

@wrapMethod(RewardNotificationCurrencyDelayed)
public func Call() -> Void {
  this.m_notificationData.time = this.m_notificationData.time + CyberslopToastHold.Seconds();
  wrappedMethod();
}

// Vanilla body (2.5) plus the hold: the outro waits (executionDelay) instead of starting at once. A second payment or
// a menu toggle during the wait goes through vanilla UpdateData, which stops this outro (OnOutroOver) and runs the
// counter again, so a new end simply schedules a new outro; nothing is left behind to fire later. NumeralsGetCommas
// wraps this function and puts its comma total in when the counter ends. The null check is new.
@replaceMethod(CurrencyNotification)
protected cb func OnMainAnimationOver(e: ref<inkAnimProxy>) -> Bool {
  let animOptions: inkAnimOptions;
  let hold = CyberslopToastHold.Seconds();
  if IsDefined(this.m_animProxy) {
    this.m_animProxy.Stop();
  }
  animOptions.fromMarker = n"outro_start";
  animOptions.executionDelay = hold >= 0.25 ? hold : 0.0;
  this.m_animProxy = this.PlayLibraryAnimation(this.m_CurrencyUpdateAnimation, animOptions);
  this.m_animProxy.RegisterToCallback(inkanimEventType.OnFinish, this, n"OnOutroOver");
  this.m_animState = CurrencyNotificationAnimState.Outro;
}

// ---- Incoming texts -----------------------------------------------------------------------------------------------

// Vanilla body, only the 6.70 changed (no installed mod wraps or replaces it).
@replaceMethod(NewHudPhoneGameController)
public final func PushSMSNotification(msgEntry: wref<JournalPhoneMessage>, opt action: ref<GenericNotificationBaseAction>) -> Void {
  let notificationData: gameuiGenericNotificationData;
  let msgConversation: wref<JournalPhoneConversation> = this.m_journalMgr.GetParentEntry(msgEntry) as JournalPhoneConversation;
  let msgContact: wref<JournalContact> = this.m_journalMgr.GetParentEntry(msgConversation) as JournalContact;
  let userData: ref<PhoneMessageNotificationViewData> = new PhoneMessageNotificationViewData();
  userData.entryHash = this.m_journalMgr.GetEntryHash(msgEntry);
  userData.threadHash = this.m_journalMgr.GetEntryHash(msgConversation);
  userData.contactHash = this.m_journalMgr.GetEntryHash(msgContact);
  userData.title = msgContact.GetLocalizedName(this.m_journalMgr);
  userData.SMSLocKey = msgEntry.GetText();
  userData.SMSText = GetLocalizedText(msgEntry.GetText());
  userData.action = action;
  userData.animation = n"notification_phone_MSG";
  userData.soundEvent = n"PhoneSmsPopup";
  userData.soundAction = n"OnOpen";
  notificationData.time = 6.70 + CyberslopToastHold.Seconds();
  notificationData.widgetLibraryItemName = n"notification_message";
  notificationData.notificationData = userData;
  this.AddNewNotificationData(notificationData);
}

// ---- OnscreenMessage channel (mod messages) -------------------------------------------------------------------------

@addField(OnscreenMessageGameController)
public let csthPause: ref<inkAnimProxy>;

@addField(OnscreenMessageGameController)
public let csthResume: ref<inkAnimProxy>;

@addField(OnscreenMessageGameController)
public let csthFor: Float;

@addMethod(OnscreenMessageGameController)
private func CSTHCancel() -> Void {
  if IsDefined(this.csthPause) {
    this.csthPause.UnregisterFromAllCallbacks(inkanimEventType.OnFinish);
    this.csthPause.Stop();
    this.csthPause = null;
  }
  if IsDefined(this.csthResume) {
    this.csthResume.UnregisterFromAllCallbacks(inkanimEventType.OnFinish);
    this.csthResume.Stop();
    this.csthResume = null;
  }
}

// The show animation fades the message out from 3.75 s of its 4.6 s. It is paused at 3.6 s and resumed so that it ends
// with the (raised) timeout: visible = what the mod asked for + the hold.
@wrapMethod(OnscreenMessageGameController)
private final func UpdateWidgets() -> Void {
  this.CSTHCancel();
  wrappedMethod();
  let hold = CyberslopToastHold.Seconds();
  if !this.m_screenMessage.isShown || this.m_screenMessage.duration <= 0.0 || hold < 0.25 || !IsDefined(this.m_animProxyShow) {
    return;
  }
  let pauseFor = this.m_screenMessage.duration + hold - 4.6;
  if pauseFor < 0.25 {
    return;
  }
  this.csthFor = pauseFor;
  this.csthPause = CyberslopToastHold.Timer(this.m_root, 3.6);
  if IsDefined(this.csthPause) {
    this.csthPause.RegisterToCallback(inkanimEventType.OnFinish, this, n"CSTHOnscreenPause");
  }
}

@wrapMethod(OnscreenMessageGameController)
private final func SetTimeout(value: Float) -> Void {
  wrappedMethod(value > 0.0 ? value + CyberslopToastHold.Seconds() : value);
}

@addMethod(OnscreenMessageGameController)
protected cb func CSTHOnscreenPause(anim: ref<inkAnimProxy>) -> Bool {
  if !IsDefined(anim) || !anim.IsFinished() || !IsDefined(this.m_animProxyShow) {
    return false;
  }
  this.m_animProxyShow.Pause();
  this.csthResume = CyberslopToastHold.Timer(this.m_root, this.csthFor);
  if IsDefined(this.csthResume) {
    this.csthResume.RegisterToCallback(inkanimEventType.OnFinish, this, n"CSTHOnscreenResume");
  } else {
    this.m_animProxyShow.Resume();
  }
  return true;
}

@addMethod(OnscreenMessageGameController)
protected cb func CSTHOnscreenResume(anim: ref<inkAnimProxy>) -> Bool {
  if IsDefined(anim) && anim.IsFinished() && IsDefined(this.m_animProxyShow) {
    this.m_animProxyShow.Resume();
  }
  return true;
}

// ---- WarningMessage channel (mod messages) --------------------------------------------------------------------------

// This controller already holds its message for the time asked: the hold is simply added.
@wrapMethod(WarningMessageGameController)
private final func SetTimeout(value: Float) -> Void {
  wrappedMethod(value > 0.0 ? value + CyberslopToastHold.Seconds() : value);
}

// ---- Police messages (fixed animation, the asked time was never used) ---------------------------------------------

@addField(PoliceMessageGameController)
public let csthPause: ref<inkAnimProxy>;

@addField(PoliceMessageGameController)
public let csthResume: ref<inkAnimProxy>;

@addField(PoliceMessageGameController)
public let csthAnim: ref<inkAnimProxy>;

@addField(PoliceMessageGameController)
public let csthFor: Float;

@addMethod(PoliceMessageGameController)
private func CSTHCancel() -> Void {
  if IsDefined(this.csthPause) {
    this.csthPause.UnregisterFromAllCallbacks(inkanimEventType.OnFinish);
    this.csthPause.Stop(true);
    this.csthPause = null;
  }
  if IsDefined(this.csthResume) {
    this.csthResume.UnregisterFromAllCallbacks(inkanimEventType.OnFinish);
    this.csthResume.Stop(true);
    this.csthResume = null;
  }
  this.csthAnim = null;
}

// The vanilla animation plays untouched and is paused at 3.6 s for the hold: between 3.04 and 4.26 s only its slow
// 7.9 s drift runs, so nothing is caught mid-flicker (its Intro_end marker at 2.58 s sits inside two flicker fades).
@wrapMethod(PoliceMessageGameController)
private final func UpdateWidgets() -> Void {
  this.CSTHCancel();
  wrappedMethod();
  let hold = CyberslopToastHold.Seconds();
  if hold < 0.25 || !IsDefined(this.m_animProxy) || !IsDefined(this.m_root) || !this.m_root.IsVisible() {
    return;
  }
  this.csthAnim = this.m_animProxy;
  this.csthFor = hold;
  this.csthPause = CyberslopToastHold.Timer(this.m_root, 3.6);
  if IsDefined(this.csthPause) {
    this.csthPause.RegisterToCallback(inkanimEventType.OnFinish, this, n"CSTHPolicePause");
  }
}

@addMethod(PoliceMessageGameController)
protected cb func CSTHPolicePause(anim: ref<inkAnimProxy>) -> Bool {
  if !IsDefined(anim) || !anim.IsFinished() || anim != this.csthPause {
    return false;
  }
  if !IsDefined(this.m_animProxy) || this.m_animProxy != this.csthAnim || !this.m_animProxy.IsPlaying() {
    return false;
  }
  this.m_animProxy.Pause();
  this.csthResume = CyberslopToastHold.Timer(this.m_root, this.csthFor);
  if IsDefined(this.csthResume) {
    this.csthResume.RegisterToCallback(inkanimEventType.OnFinish, this, n"CSTHPoliceResume");
  } else {
    this.m_animProxy.Resume();
  }
  return true;
}

@addMethod(PoliceMessageGameController)
protected cb func CSTHPoliceResume(anim: ref<inkAnimProxy>) -> Bool {
  if !IsDefined(anim) || !anim.IsFinished() || anim != this.csthResume {
    return false;
  }
  if IsDefined(this.m_animProxy) && this.m_animProxy == this.csthAnim && this.m_animProxy.IsPaused() {
    this.m_animProxy.Resume();
  }
  return true;
}
