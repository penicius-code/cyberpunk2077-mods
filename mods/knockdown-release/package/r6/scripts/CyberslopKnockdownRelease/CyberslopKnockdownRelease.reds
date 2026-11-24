// Cyberslop Knockdown Release 1.1.1 (2026-11-06: storage renamed to CyberslopKnockdown, RedFileSystem refuses names over
// 24 letters, so 1.1.0 never wrote its log; 1.1.0 2026-11-03: smart logging for normal play, see the log section)
// Car hits (and Explosion Knockback's facing blast) put V in the "vehicleKnockdown" locomotion state. That state
// (vanilla StatusEffectDecisions.ToStand) only lets V move once the VehicleKnockdown status effect has run out:
// 4.1 s vanilla, 3 s with "Not as much Faster Vehicle Knockback Animation", 2 s for ExplosionKnockdown. The first
// person get-up can finish before that, and V then stands frozen until the timer ends.
// This mod watches the first person camera during that state and ends the effect as soon as the camera is back at
// the height it had before the hit (V is on his feet again), or after 1 s if the camera never went down (no fall
// animation played). Third person (camera far from the body at the hit, e.g. Immersive Third Person) is left alone.
// One buffered line per vehicle-type knockdown (first 40 per launch, then counts only) goes to r6\storages\CyberslopKnockdown\knockdowns.txt (timings in s
// from the hit, heights in m above V's feet).
// Remove: delete r6\scripts\CyberslopKnockdownRelease (game closed).

import RedFileSystem.*

// ---------------------------------------------------------------- settings

// false = log only, never shorten the knockdown
func CKRReleaseOn() -> Bool {
  return true;
}

// the camera counts as "down" once it is this far below its height at the hit
func CKRDipDepth() -> Float {
  return 0.30;
}

// back "up" when within this distance of the height at the hit ...
func CKRUpTolerance() -> Float {
  return 0.15;
}

// ... for this long
func CKRUpHold() -> Float {
  return 0.10;
}

// no dip by then = no fall animation is playing: release
func CKRNoDipTimeout() -> Float {
  return 1.00;
}

// camera within this horizontal distance of V's feet at the hit = first person
func CKRFppMaxHoriz() -> Float {
  return 0.60;
}

// false = no log at all (the release still works)
func CKRLogOn() -> Bool {
  return true;
}

// full "knockdown" lines per launch; after that only the tally counts
func CKRDetailLines() -> Int32 {
  return 40;
}

// buffered lines are written at most this long after the first one (or at 10 lines, or on quit)
func CKRFlushDelay() -> Float {
  return 30.00;
}

// ---------------------------------------------------------------- log
// Smart logging for normal play: nothing is written in a launch without a vehicle-type knockdown (not even the
// session line). Lines are kept in memory and written in one go 30 s after the first one, at 10 lines, or when
// the game quits. Only the first 40 knockdowns of a launch get a full line; all of them are counted in the "tally"
// line written with each flush. The per-frame work (one camera query) runs only during a knockdown.

public class CKRFlushTick extends DelayCallback {
  public func Call() -> Void {
    let log: ref<CKRLog> = CKRLog.Get();
    if IsDefined(log) {
      log.FlushTimer();
    };
  }
}

public class CKRLog extends ScriptableService {
  private let file: ref<File>;
  private let ready: Bool;
  private let headerDone: Bool;
  private let buffer: String;
  private let bufLines: Int32;
  private let flushScheduled: Bool;
  private let scheduledAt: Float;
  private let tallyDirty: Bool;
  // tally for this launch
  private let n: Int32;
  private let nUp: Int32;
  private let nNoDip: Int32;
  private let nTimer: Int32;
  private let nTpp: Int32;
  private let nNoCam: Int32;
  private let detail: Int32;
  private let saved: Float;
  private let upSum: Float;
  private let nUpSeen: Int32;

  private cb func OnLoad() -> Void {
    if !CKRLogOn() {
      return;
    };
    let storage: ref<FileSystemStorage> = FileSystem.GetStorage("CyberslopKnockdown");
    if !IsDefined(storage) {
      return;
    };
    this.file = storage.GetFile("knockdowns.txt");
    this.ready = IsDefined(this.file);
  }

  private cb func OnUninitialize() -> Void {
    this.Flush();
  }

  public static func Get() -> ref<CKRLog> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"CKRLog") as CKRLog;
  }

  // one finished knockdown: count it, keep a full line while under the cap
  public final func Record(game: GameInstance, reason: String, total: Float, release: Float, up: Float, line: String) -> Void {
    if !this.ready {
      return;
    };
    this.n += 1;
    if Equals(reason, "up") {
      this.nUp += 1;
    } else {
      if Equals(reason, "nodip") {
        this.nNoDip += 1;
      } else {
        if Equals(reason, "tpp") {
          this.nTpp += 1;
        } else {
          if Equals(reason, "nocam") {
            this.nNoCam += 1;
          } else {
            this.nTimer += 1;
          };
        };
      };
    };
    if release >= 0.0 {
      this.saved += MaxF(total - release, 0.0);
    };
    if up >= 0.0 {
      this.upSum += up;
      this.nUpSeen += 1;
    };
    this.tallyDirty = true;
    if this.detail < CKRDetailLines() {
      this.detail += 1;
      this.buffer += line + "\n";
      this.bufLines += 1;
    };
    if this.bufLines >= 10 {
      this.Flush();
      return;
    };
    this.Schedule(game);
  }

  private final func Schedule(game: GameInstance) -> Void {
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(game));
    // a load can drop a pending callback (sim time then jumps back or the timer is long overdue): flush now
    if this.flushScheduled && (now < this.scheduledAt || now - this.scheduledAt > CKRFlushDelay() * 2.0) {
      this.flushScheduled = false;
      this.Flush();
    };
    if !this.flushScheduled {
      this.flushScheduled = true;
      this.scheduledAt = now;
      GameInstance.GetDelaySystem(game).DelayCallback(new CKRFlushTick(), CKRFlushDelay(), false);
    };
  }

  public final func FlushTimer() -> Void {
    this.flushScheduled = false;
    this.Flush();
  }

  public final func Flush() -> Void {
    if !this.ready || (!this.tallyDirty && this.bufLines == 0) {
      return;
    };
    let text: String = "";
    if !this.headerDone {
      this.headerDone = true;
      text = "session\tversion=1.1.1\trelease=" + CKRLog.Flag(CKRReleaseOn()) + "\tdetailCap=" + IntToString(CKRDetailLines()) + "\n";
    };
    text += this.buffer;
    if this.tallyDirty {
      let avgUp: Float = this.nUpSeen > 0 ? this.upSum / Cast<Float>(this.nUpSeen) : -1.0;
      text += "tally\tn=" + IntToString(this.n) + "\tup=" + IntToString(this.nUp) + "\tnodip=" + IntToString(this.nNoDip)
        + "\ttimer=" + IntToString(this.nTimer) + "\ttpp=" + IntToString(this.nTpp) + "\tnocam=" + IntToString(this.nNoCam)
        + "\tsaved=" + CKRLog.Num(this.saved) + "\tavgUp=" + CKRLog.Num(avgUp)
        + "\tdetail=" + IntToString(this.detail) + "\tcountedOnly=" + IntToString(this.n - this.detail) + "\n";
    };
    this.file.WriteText(text, FileSystemWriteMode.Append);
    this.buffer = "";
    this.bufLines = 0;
    this.tallyDirty = false;
  }

  public static func Num(value: Float) -> String {
    return FloatToStringPrec(value, 2);
  }

  public static func Flag(value: Bool) -> String {
    return value ? "1" : "0";
  }
}

// ---------------------------------------------------------------- helpers

func CKRIsVehicleKnockdown(rec: wref<StatusEffect_Record>) -> Bool {
  return IsDefined(rec) && IsDefined(rec.StatusEffectType()) && Equals(rec.StatusEffectType().Type(), gamedataStatusEffectType.VehicleKnockdown);
}

// Active camera position relative to V's feet: height and horizontal distance
func CKRCameraOffset(scriptInterface: ref<StateGameScriptInterface>, out height: Float, out horiz: Float) -> Bool {
  let t: Transform;
  if !GameInstance.GetCameraSystem(scriptInterface.GetGame()).GetActiveCameraWorldTransform(t) {
    return false;
  };
  let cam: Vector4 = Transform.GetPosition(t);
  let feet: Vector4 = scriptInterface.owner.GetWorldPosition();
  let dx: Float = cam.X - feet.X;
  let dy: Float = cam.Y - feet.Y;
  height = cam.Z - feet.Z;
  horiz = SqrtF((dx * dx) + (dy * dy));
  return true;
}

func CKRMoveInput(scriptInterface: ref<StateGameScriptInterface>) -> Bool {
  return AbsF(scriptInterface.GetActionValue(n"MoveX")) >= 0.30 || AbsF(scriptInterface.GetActionValue(n"MoveY")) >= 0.30;
}

// ---------------------------------------------------------------- state

@addField(StatusEffectEvents)
let ckrLive: Bool;

@addField(StatusEffectEvents)
let ckrCam: Bool;

@addField(StatusEffectEvents)
let ckrFpp: Bool;

@addField(StatusEffectEvents)
let ckrEffect: String;

@addField(StatusEffectEvents)
let ckrTotal: Float;

@addField(StatusEffectEvents)
let ckrT: Float;

@addField(StatusEffectEvents)
let ckrH0: Float;

@addField(StatusEffectEvents)
let ckrHoriz: Float;

@addField(StatusEffectEvents)
let ckrHMin: Float;

@addField(StatusEffectEvents)
let ckrTMin: Float;

@addField(StatusEffectEvents)
let ckrTDip: Float;

@addField(StatusEffectEvents)
let ckrTUp: Float;

@addField(StatusEffectEvents)
let ckrUpRun: Float;

@addField(StatusEffectEvents)
let ckrTMove: Float;

@addField(StatusEffectEvents)
let ckrTMoveUp: Float;

@addField(StatusEffectEvents)
let ckrTRelease: Float;

@addField(StatusEffectEvents)
let ckrReason: String;

@wrapMethod(StatusEffectEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(stateContext, scriptInterface);
  this.ckrLive = false;
  if !CKRIsVehicleKnockdown(this.m_statusEffectRecord) {
    return;
  };
  this.ckrLive = true;
  this.ckrEffect = TDBID.ToStringDEBUG(this.m_statusEffectRecord.GetID());
  this.ckrTotal = this.GetStatusEffectRemainingDuration(scriptInterface, stateContext);
  this.ckrT = 0.0;
  this.ckrTMin = 0.0;
  this.ckrTDip = -1.0;
  this.ckrTUp = -1.0;
  this.ckrUpRun = 0.0;
  this.ckrTMove = -1.0;
  this.ckrTMoveUp = -1.0;
  this.ckrTRelease = -1.0;
  this.ckrReason = "timer";
  let h: Float;
  let horiz: Float;
  this.ckrCam = CKRCameraOffset(scriptInterface, h, horiz);
  this.ckrH0 = h;
  this.ckrHMin = h;
  this.ckrHoriz = horiz;
  this.ckrFpp = this.ckrCam && horiz <= CKRFppMaxHoriz();
  if !this.ckrCam {
    this.ckrReason = "nocam";
  } else {
    if !this.ckrFpp {
      this.ckrReason = "tpp";
    };
  };
}

@wrapMethod(StatusEffectEvents)
protected func OnUpdate(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  wrappedMethod(timeDelta, stateContext, scriptInterface);
  if this.ckrLive {
    this.CKRStep(timeDelta, scriptInterface);
  };
}

@addMethod(StatusEffectEvents)
private final func CKRStep(timeDelta: Float, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  let step: Float = MaxF(timeDelta, 0.0);
  this.ckrT += step;
  let t: Float = this.ckrT;
  let moving: Bool = CKRMoveInput(scriptInterface);
  if moving && this.ckrTMove < 0.0 {
    this.ckrTMove = t;
  };
  if moving && this.ckrTUp >= 0.0 && this.ckrTMoveUp < 0.0 {
    this.ckrTMoveUp = t;
  };
  if this.ckrTRelease >= 0.0 || !this.ckrCam {
    return;
  };
  let h: Float;
  let horiz: Float;
  if !CKRCameraOffset(scriptInterface, h, horiz) {
    return;
  };
  if h < this.ckrHMin {
    this.ckrHMin = h;
    this.ckrTMin = t;
  };
  if this.ckrTDip < 0.0 {
    if h < this.ckrH0 - CKRDipDepth() {
      this.ckrTDip = t;
    } else {
      if t >= CKRNoDipTimeout() && this.ckrFpp && CKRReleaseOn() {
        this.CKRRelease(scriptInterface, "nodip");
      };
    };
    return;
  };
  if h >= this.ckrH0 - CKRUpTolerance() {
    if this.ckrTUp < 0.0 {
      this.ckrTUp = t;
    };
    this.ckrUpRun += step;
    if this.ckrUpRun >= CKRUpHold() && this.ckrFpp && CKRReleaseOn() {
      this.CKRRelease(scriptInterface, "up");
    };
  } else {
    this.ckrTUp = -1.0;
    this.ckrUpRun = 0.0;
  };
}

@addMethod(StatusEffectEvents)
private final func CKRRelease(scriptInterface: ref<StateGameScriptInterface>, reason: String) -> Void {
  this.ckrTRelease = this.ckrT;
  this.ckrReason = reason;
  if IsDefined(this.m_statusEffectRecord) {
    // StatusEffectDecisions.ToStand is "no movement status effect left": the state ends on the next update
    StatusEffectHelper.RemoveStatusEffect(scriptInterface.owner, this.m_statusEffectRecord.GetID());
  };
}

@addMethod(StatusEffectEvents)
private final func CKRFinish(scriptInterface: ref<StateGameScriptInterface>, forced: Bool) -> Void {
  if !this.ckrLive {
    return;
  };
  this.ckrLive = false;
  if !CKRLogOn() {
    return;
  };
  let log: ref<CKRLog> = CKRLog.Get();
  if !IsDefined(log) {
    return;
  };
  log.Record(scriptInterface.GetGame(), this.ckrReason, this.ckrTotal, this.ckrTRelease, this.ckrTUp, "knockdown\teffect=" + this.ckrEffect
    + "\ttotal=" + CKRLog.Num(this.ckrTotal)
    + "\tfpp=" + CKRLog.Flag(this.ckrFpp)
    + "\th0=" + CKRLog.Num(this.ckrH0)
    + "\thoriz=" + CKRLog.Num(this.ckrHoriz)
    + "\thmin=" + CKRLog.Num(this.ckrHMin)
    + "\ttmin=" + CKRLog.Num(this.ckrTMin)
    + "\tdip=" + CKRLog.Num(this.ckrTDip)
    + "\tup=" + CKRLog.Num(this.ckrTUp)
    + "\tmove=" + CKRLog.Num(this.ckrTMove)
    + "\tmoveUp=" + CKRLog.Num(this.ckrTMoveUp)
    + "\trelease=" + CKRLog.Num(this.ckrTRelease)
    + "\treason=" + this.ckrReason
    + "\texit=" + CKRLog.Num(this.ckrT)
    + "\tforced=" + CKRLog.Flag(forced));
}

@wrapMethod(StatusEffectEvents)
public func OnExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  this.CKRFinish(scriptInterface, false);
  wrappedMethod(stateContext, scriptInterface);
}

@wrapMethod(StatusEffectEvents)
public func OnForcedExit(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
  this.CKRFinish(scriptInterface, true);
  wrappedMethod(stateContext, scriptInterface);
}
