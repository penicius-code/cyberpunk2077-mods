// Cyberslop Gore Probe 1.1.0 (2026-11-02): passive build for normal play
// Diagnostic: why dismemberment and gore wounds stop at range. Logs V's ranged hits on NPCs through the
// hit-reaction / dismemberment pipeline with distance, camera FOV (scope zoom), hit shapes and each gate, every cut
// request, the native cut call and the limb count 3 s later, which shows whether the engine really cut.
// 1.1.0 for normal play: lines are buffered and written every 5 s (or 40 lines) instead of per hit; melee hits are
// not logged; ranged hits under 25 m are logged only when they kill or request a cut (others, incl. near corpse shots, only
// counted); automatic A/B engine test: ranged kill shots from 30 m on that got no cut alternate between untouched
// (exp=ab-control) and a forced cut of the hit head / limb (exp=ab-forced), so a normal session answers both
// "which gate stops it" and "can the engine cut that far". CET can switch A/B off.
// Log: r6\storages\CyberslopGoreProbe\gore-N.txt, one new file per launch, tab separated: kind, then key=value.
// Report: python -I -X utf8 "<release>\tools\gore_probe_report.py"
// The folder is zz_zz_ (redscript sorts by upper case, so zzz_ would load BEFORE zz_) so its wraps are the outermost
// ones: they see the final decisions of every other gore mod.
// Remove: delete r6\scripts\zz_zz_CyberslopGoreProbe and bin\x64\plugins\cyber_engine_tweaks\mods\CyberslopGoreProbe.

import RedFileSystem.*

@addField(NPCPuppet)
public let cgpHits: Int32;

@addField(NPCPuppet)
public let cgpForced: Bool;

public class CGPCutCheck extends DelayCallback {
  public let npc: wref<NPCPuppet>;
  public let req: Int32;
  public let idText: String;
  public let part: String;
  public let wound: String;
  public let src: String;
  public let flesh: Int32;
  public let cyber: Int32;
  public let dist: Float;

  public func Call() -> Void {
    let log: ref<CGPLog> = CGPLog.Get();
    if IsDefined(log) {
      log.CheckCut(this);
    };
  }
}

public class CGPFlushTick extends DelayCallback {
  public func Call() -> Void {
    let log: ref<CGPLog> = CGPLog.Get();
    if IsDefined(log) {
      log.FlushTimer();
    };
  }
}

public class CGPLog extends ScriptableService {
  private let file: ref<File>;
  private let fileName: String;
  private let buffer: String;
  private let bufLines: Int32;
  private let flushScheduled: Bool;
  private let game: GameInstance;
  private let hasGame: Bool;
  private let seq: Int32;
  private let reqSeq: Int32;
  // Context of the hit being evaluated. EvaluateHit runs synchronously, and ProcessWoundsAndDismemberment,
  // DismembermentConditions and RequestDismemberment run inside it, so they can be tied to the hit row.
  private let ctxActive: Bool;
  private let ctxId: EntityID;
  private let ctxSeq: Int32;
  private let ctxDetail: Bool;
  private let ctxPwd: String;
  private let ctxDc: String;
  private let ctxReq: String;
  private let ctxReqCount: Int32;
  private let ctxNative: Int32;
  private let ctxSrc: String;
  private let toolSrc: String;
  // Counts of hits not written (denominators for the report)
  private let skippedNear: Int32;
  private let skippedMelee: Int32;
  private let tallyDirty: Bool;
  private let abCount: Int32;
  // State for the CET tools
  public let lastNpc: wref<NPCPuppet>;
  public let lastSeq: Int32;
  public let lastText: String;
  public let lastCut: String;
  public let experiment: Bool;
  public let autoAB: Bool;
  private let sessions: Int32;

  public static func FarDistance() -> Float {
    return 25.00;
  }

  public static func ABDistance() -> Float {
    return 30.00;
  }

  private cb func OnLoad() -> Void {
    this.autoAB = true;
    let storage: ref<FileSystemStorage> = FileSystem.GetStorage("CyberslopGoreProbe");
    if !IsDefined(storage) {
      return;
    };
    let number: Int32 = ArraySize(storage.GetFiles()) + 1;
    while Equals(storage.Exists(s"gore-\(number).txt"), FileSystemStatus.True) {
      number += 1;
    };
    this.fileName = s"gore-\(number).txt";
    this.file = storage.GetFile(this.fileName);
    this.file.WriteText("probe\tversion=1.1.0\tfile=" + this.fileName + "\tfar=" + CGPLog.Num(CGPLog.FarDistance()) + "\tab=" + CGPLog.Num(CGPLog.ABDistance()) + "\n", FileSystemWriteMode.Append);
  }

  public static func Get() -> ref<CGPLog> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"CGPLog") as CGPLog;
  }

  public final func SetGame(game: GameInstance) -> Void {
    this.game = game;
    this.hasGame = true;
  }

  // Buffered: one file write every 5 s or 40 lines instead of one per line
  public final func Write(line: String) -> Void {
    if !IsDefined(this.file) {
      return;
    };
    this.buffer += line + "\n";
    this.bufLines += 1;
    if this.bufLines >= 40 || !this.hasGame {
      this.Flush();
      return;
    };
    if !this.flushScheduled {
      this.flushScheduled = true;
      GameInstance.GetDelaySystem(this.game).DelayCallback(new CGPFlushTick(), 5.00, false);
    };
  }

  public final func FlushTimer() -> Void {
    this.flushScheduled = false;
    this.Flush();
  }

  public final func Flush() -> Void {
    if !IsDefined(this.file) {
      return;
    };
    if this.tallyDirty {
      this.tallyDirty = false;
      this.buffer += s"tally\tskippedNear=\(this.skippedNear)\tskippedMelee=\(this.skippedMelee)\thits=\(this.seq)\treqs=\(this.reqSeq)\n";
    };
    if this.bufLines > 0 || StrLen(this.buffer) > 0 {
      this.file.WriteText(this.buffer, FileSystemWriteMode.Append);
    };
    this.buffer = "";
    this.bufLines = 0;
  }

  // A load can drop pending delay callbacks: flush and allow a new timer
  public final func Reset(game: GameInstance) -> Void {
    this.SetGame(game);
    this.flushScheduled = false;
    this.Flush();
  }

  public final func FileName() -> String {
    return this.fileName;
  }

  public final func CountSkip(melee: Bool) -> Void {
    if melee {
      this.skippedMelee += 1;
    } else {
      this.skippedNear += 1;
    };
    this.tallyDirty = true;
  }

  public final func NextAB() -> Bool {
    this.abCount += 1;
    return this.abCount % 2 == 1;
  }

  public static func Num(value: Float) -> String {
    return FloatToStringPrec(value, 2);
  }

  public static func Flag(value: Bool) -> String {
    return value ? "1" : "0";
  }

  public static func Now(game: GameInstance) -> Float {
    return EngineTime.ToFloat(GameInstance.GetSimTime(game));
  }

  public static func FromPlayer(data: ref<AttackData>) -> Bool {
    if !IsDefined(data) {
      return false;
    };
    let instigator: wref<GameObject> = data.GetInstigator();
    return IsDefined(instigator) && instigator.IsPlayer();
  }

  public static func Distance(npc: ref<GameObject>) -> Float {
    let player: ref<PlayerPuppet> = GetPlayer(npc.GetGame());
    if !IsDefined(player) {
      return -1.00;
    };
    return Vector4.Distance(player.GetWorldPosition(), npc.GetWorldPosition());
  }

  // FOV of the active camera: smaller while aiming down a scope; frustum = NPC inside the view cone
  public static func View(npc: ref<GameObject>) -> String {
    let cameras: ref<CameraSystem> = GameInstance.GetCameraSystem(npc.GetGame());
    if !IsDefined(cameras) {
      return "fov=-1\tfrustum=-";
    };
    return "fov=" + CGPLog.Num(cameras.GetActiveCameraFOV()) + "\tfrustum=" + CGPLog.Flag(cameras.IsInCameraFrustum(npc, 1.80, 0.50));
  }

  public static func Limbs(npc: ref<NPCPuppet>, out flesh: Int32, out cyber: Int32) -> Bool {
    let dism: ref<DismembermentComponent> = npc.GetDismembermentComponent();
    if !IsDefined(dism) {
      flesh = -1;
      cyber = -1;
      return false;
    };
    let count: DismemberedLimbCount = dism.GetDismemberedLimbCount();
    flesh = Cast<Int32>(count.fleshDismemberments);
    cyber = Cast<Int32>(count.cyberDismemberments);
    return true;
  }

  public static func Who(npc: ref<NPCPuppet>) -> String {
    let line: String = "id=" + EntityID.ToDebugString(npc.GetEntityID()) + "\tnpc=" + TDBID.ToStringDEBUG(npc.GetRecordID());
    line += s"\trarity=\(npc.GetNPCRarity())\tcrowd=" + CGPLog.Flag(npc.IsCrowd()) + "\tandroid=" + CGPLog.Flag(npc.IsAndroid());
    line += "\tboss=" + CGPLog.Flag(npc.IsBoss()) + "\tapp=" + NameToString(npc.GetCurrentAppearanceName());
    return line;
  }

  public static func Weapon(data: ref<AttackData>) -> String {
    let weapon: ref<WeaponObject> = data.GetWeapon();
    if !IsDefined(weapon) {
      return "wpn=none\twtype=none\tdismFactor=-";
    };
    let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(weapon.GetGame());
    let factor: Float = stats.GetStatValue(Cast<StatsObjectID>(weapon.GetEntityID()), gamedataStatType.HitDismembermentFactor);
    let range: Float = stats.GetStatValue(Cast<StatsObjectID>(weapon.GetEntityID()), gamedataStatType.EffectiveRange);
    return "wpn=" + TDBID.ToStringDEBUG(ItemID.GetTDBID(weapon.GetItemID())) + s"\twtype=\(RPGManager.GetItemType(weapon.GetItemID()))" + "\tdismFactor=" + CGPLog.Num(factor) + "\teffRange=" + CGPLog.Num(range);
  }

  public static func Flags(data: ref<AttackData>) -> String {
    let flags: String = "";
    if data.HasFlag(hitFlag.Nonlethal) {
      flags += "nonlethal,";
    };
    if data.HasFlag(hitFlag.WasKillingBlow) {
      flags += "killing,";
    };
    if data.HasFlag(hitFlag.CriticalHit) {
      flags += "crit,";
    };
    if data.HasFlag(hitFlag.WeakspotHit) {
      flags += "weakspot,";
    };
    if data.HasFlag(hitFlag.ForceDismember) {
      flags += "forceDismember,";
    };
    if data.HasFlag(hitFlag.FragmentationSplinter) {
      flags += "splinter,";
    };
    return flags;
  }

  // Hit shapes as the engine resolved them: a hit without any shape never reaches the dismemberment code
  public static func Shapes(hit: ref<gameHitEvent>, out part: gameDismBodyPart, out hasPart: Bool) -> String {
    let shapes: array<HitShapeData> = hit.hitRepresentationResult.hitShapes;
    hasPart = false;
    if ArraySize(shapes) == 0 {
      return "shapes=0\tzone=none\tshape=none\tpart=none";
    };
    let data: ref<HitShapeUserDataBase> = DamageSystemHelper.GetHitShapeUserDataBase(shapes[0]);
    if !IsDefined(data) {
      return s"shapes=\(ArraySize(shapes))\tzone=nodata\tshape=nodata\tpart=none";
    };
    part = HitShapeUserDataBase.GetDismembermentBodyPart(data);
    hasPart = true;
    return s"shapes=\(ArraySize(shapes))\tzone=\(HitShapeUserDataBase.GetHitReactionZone(data))\tshape=\(DamageSystemHelper.GetHitShapeTypeFromData(DamageSystemHelper.GetHitShape(hit)))\tpart=\(part)";
  }

  // NPCPuppet.OnHitAnimation, before the gate that decides whether a hit reaction (and so any gore) is requested.
  // Written only when the gate blocks the hit or the hit is far; near passing hits show up as hit rows.
  public final func Raw(npc: ref<NPCPuppet>, hit: ref<gameHitEvent>, requested: Bool, dist: Float) -> Void {
    let line: String = "raw\tt=" + CGPLog.Num(CGPLog.Now(npc.GetGame())) + "\tdist=" + CGPLog.Num(dist);
    line += "\treaction=" + CGPLog.Flag(requested) + s"\tatk=\(hit.attackData.GetAttackType())";
    if IsDefined(hit.attackComputed) {
      line += "\ttotal=" + CGPLog.Num(hit.attackComputed.GetTotalAttackValue(gamedataStatPoolType.Health));
    };
    line += "\tid=" + EntityID.ToDebugString(npc.GetEntityID());
    this.Write(line);
  }

  public final func BeginHit(npc: ref<NPCPuppet>, detail: Bool) -> Int32 {
    this.SetGame(npc.GetGame());
    this.seq += 1;
    this.ctxActive = true;
    this.ctxId = npc.GetEntityID();
    this.ctxSeq = this.seq;
    this.ctxDetail = detail;
    this.ctxPwd = "pwd=0";
    this.ctxDc = "";
    this.ctxReq = "";
    this.ctxReqCount = 0;
    this.ctxNative = 0;
    this.ctxSrc = "hit";
    return this.seq;
  }

  public final func InHit(owner: ref<GameObject>) -> Bool {
    return this.ctxActive && IsDefined(owner) && Equals(owner.GetEntityID(), this.ctxId);
  }

  // Full gate snapshot only for hits that will likely be written (far, or the NPC is dead / dying)
  public final func WantsDetail(dead: Bool) -> Bool {
    return this.ctxDetail || dead;
  }

  public final func SetPwd(text: String) -> Void {
    this.ctxPwd = StrLen(text) > 0 ? "pwd=1\t" + text : "pwd=1";
  }

  public final func AddDc(result: Bool) -> Void {
    this.ctxDc += CGPLog.Flag(result);
  }

  public final func ReqCount() -> Int32 {
    return this.ctxReqCount;
  }

  public final func SetSource(src: String) -> Void {
    this.ctxSrc = src;
    this.toolSrc = src;
  }

  public final func SkipHit() -> Void {
    this.ctxActive = false;
    this.CountSkip(false);
  }

  public final func EndHit(npc: ref<NPCPuppet>, hit: ref<gameHitEvent>, seq: Int32, dist: Float, state: String, exp: String) -> Void {
    let game: GameInstance = npc.GetGame();
    let data: ref<AttackData> = hit.attackData;
    let part: gameDismBodyPart;
    let hasPart: Bool;
    npc.cgpHits += 1;
    let atkDist: Float = Vector4.Distance(data.GetAttackPosition(), hit.hitPosition);
    let total: Float = IsDefined(hit.attackComputed) ? hit.attackComputed.GetTotalAttackValue(gamedataStatPoolType.Health) : -1.00;
    let hp: Float = GameInstance.GetStatPoolsSystem(game).GetStatPoolValue(Cast<StatsObjectID>(npc.GetEntityID()), gamedataStatPoolType.Health, true);
    let shapes: String = CGPLog.Shapes(hit, part, hasPart);
    let line: String = s"hit\tseq=\(seq)\tt=" + CGPLog.Num(CGPLog.Now(game)) + "\tdist=" + CGPLog.Num(dist) + "\tatkDist=" + CGPLog.Num(atkDist);
    line += "\t" + CGPLog.View(npc) + s"\tatk=\(data.GetAttackType())\t" + CGPLog.Weapon(data);
    line += "\ttotal=" + CGPLog.Num(total) + "\thp=" + CGPLog.Num(hp) + "\t" + shapes + "\tflags=" + CGPLog.Flags(data);
    line += "\t" + state + "\t" + this.ctxPwd + "\tdc=" + this.ctxDc + "\treq=" + this.ctxReq + s"\tnative=\(this.ctxNative)\texp=" + exp;
    line += s"\tnpcHit=\(npc.cgpHits)\t" + CGPLog.Who(npc);
    this.Write(line);
    this.ctxActive = false;
    this.lastNpc = npc;
    this.lastSeq = seq;
    this.lastCut = this.ctxReqCount > 0 ? "requested " + this.ctxReq : "none requested";
    this.lastText = s"#\(seq) " + CGPLog.Num(dist) + " m, " + (hasPart ? s"\(part)" : "no shape") + ", " + this.lastCut;
  }

  public final func OnRequest(npc: ref<NPCPuppet>, bodyPart: gameDismBodyPart, woundType: gameDismWoundType, hitPosition: Vector4, isCritical: Bool, debrisPath: String) -> Void {
    let flesh: Int32;
    let cyber: Int32;
    this.SetGame(npc.GetGame());
    this.reqSeq += 1;
    let inHit: Bool = this.InHit(npc);
    let src: String = inHit ? this.ctxSrc : (StrLen(this.toolSrc) > 0 ? this.toolSrc : "other");
    if inHit {
      this.ctxReq += s"\(bodyPart):\(woundType),";
      this.ctxReqCount += 1;
    };
    CGPLog.Limbs(npc, flesh, cyber);
    let dist: Float = CGPLog.Distance(npc);
    let line: String = s"req\treq=\(this.reqSeq)\tseq=" + (inHit ? ToString(this.ctxSeq) : "-") + "\tsrc=" + src + "\tt=" + CGPLog.Num(CGPLog.Now(npc.GetGame()));
    line += "\tdist=" + CGPLog.Num(dist) + "\t" + CGPLog.View(npc) + s"\tpart=\(bodyPart)\twound=\(woundType)\tcrit=" + CGPLog.Flag(isCritical);
    line += "\tposZero=" + CGPLog.Flag(Vector4.IsZero(hitPosition)) + "\tdebris=" + debrisPath + s"\tlimbsBefore=\(flesh)/\(cyber)";
    line += "\tdeadStat=" + CGPLog.Flag(npc.IsDead()) + "\tragdoll=" + CGPLog.Flag(npc.IsRagdolling()) + "\t" + CGPLog.Who(npc);
    this.Write(line);
    let check: ref<CGPCutCheck> = new CGPCutCheck();
    check.npc = npc;
    check.req = this.reqSeq;
    check.idText = EntityID.ToDebugString(npc.GetEntityID());
    check.part = s"\(bodyPart)";
    check.wound = s"\(woundType)";
    check.src = src;
    check.flesh = flesh;
    check.cyber = cyber;
    check.dist = dist;
    GameInstance.GetDelaySystem(npc.GetGame()).DelayCallback(check, 3.00, false);
  }

  public final func CheckCut(check: ref<CGPCutCheck>) -> Void {
    let flesh: Int32;
    let cyber: Int32;
    let npc: ref<NPCPuppet> = check.npc;
    let line: String = s"cut\treq=\(check.req)\tafter=3s\tsrc=" + check.src + "\tdist=" + CGPLog.Num(check.dist) + "\tpart=" + check.part + "\twound=" + check.wound;
    if !IsDefined(npc) || !npc.IsAttached() {
      this.Write(line + "\tverdict=gone\tid=" + check.idText);
      return;
    };
    if !CGPLog.Limbs(npc, flesh, cyber) {
      this.Write(line + "\tverdict=nocomponent\tid=" + check.idText);
      return;
    };
    let delta: Int32 = (flesh - check.flesh) + (cyber - check.cyber);
    let verdict: String = delta > 0 ? "cut" : "nochange";
    line += s"\tlimbsBefore=\(check.flesh)/\(check.cyber)\tlimbsAfter=\(flesh)/\(cyber)\tverdict=" + verdict + "\tid=" + check.idText;
    this.Write(line);
    if IsDefined(this.lastNpc) && Equals(this.lastNpc.GetEntityID(), npc.GetEntityID()) {
      this.lastCut = check.part + " " + verdict + " at 3 s";
    };
  }

  public final func OnNative(npc: ref<NPCPuppet>, evt: ref<DismembermentEvent>) -> Void {
    let flesh: Int32;
    let cyber: Int32;
    if this.InHit(npc) {
      this.ctxNative += 1;
    };
    CGPLog.Limbs(npc, flesh, cyber);
    let line: String = "native\tt=" + CGPLog.Num(CGPLog.Now(npc.GetGame())) + "\tdist=" + CGPLog.Num(CGPLog.Distance(npc));
    line += s"\tpart=\(evt.m_bodyPart)\twound=\(evt.m_woundType)\tstrength=" + CGPLog.Num(evt.m_strength) + "\tcrit=" + CGPLog.Flag(evt.m_isCritical);
    line += s"\tlimbsNow=\(flesh)/\(cyber)\tid=" + EntityID.ToDebugString(npc.GetEntityID());
    this.Write(line);
  }

  public final func Session(game: GameInstance) -> Void {
    this.Reset(game);
    this.sessions += 1;
    let line: String = s"session\tn=\(this.sessions)\tt=" + CGPLog.Num(CGPLog.Now(game)) + "\texperiment=" + CGPLog.Flag(this.experiment) + "\tautoAB=" + CGPLog.Flag(this.autoAB);
    line += s"\tdifficulty=\(GameInstance.GetStatsDataSystem(game).GetDifficulty())";
    this.Write(line);
  }
}

// Tools for the CET half: Game.GetScriptableSystemsContainer():Get("CyberslopGoreProbeSystem")
public class CyberslopGoreProbeSystem extends ScriptableSystem {
  private func OnAttach() -> Void {
    let log: ref<CGPLog> = CGPLog.Get();
    if IsDefined(log) {
      log.Session(this.GetGameInstance());
    };
  }

  private func OnDetach() -> Void {
    let log: ref<CGPLog> = CGPLog.Get();
    if IsDefined(log) {
      log.Flush();
    };
  }

  private final func Target(out how: String) -> ref<NPCPuppet> {
    let game: GameInstance = this.GetGameInstance();
    let player: ref<PlayerPuppet> = GetPlayer(game);
    let log: ref<CGPLog> = CGPLog.Get();
    if IsDefined(player) {
      let look: ref<NPCPuppet> = GameInstance.GetTargetingSystem(game).GetLookAtObject(player, false, false) as NPCPuppet;
      if IsDefined(look) {
        how = "crosshair";
        return look;
      };
    };
    if IsDefined(log) && IsDefined(log.lastNpc) {
      how = "last hit";
      return log.lastNpc;
    };
    how = "none";
    return null;
  }

  // part: 0 LEFT_ARM, 1 RIGHT_ARM, 2 LEFT_LEG, 3 RIGHT_LEG, 4 HEAD, 5 BODY (gameDismBodyPart)
  public final func ForceCut(part: Int32) -> String {
    let how: String;
    let log: ref<CGPLog> = CGPLog.Get();
    let npc: ref<NPCPuppet> = this.Target(how);
    if !IsDefined(npc) || !IsDefined(log) {
      return "Gore Probe: no NPC under the crosshair and none hit yet";
    };
    let bodyPart: gameDismBodyPart = IntEnum<gameDismBodyPart>(part);
    let pos: Vector4 = npc.GetWorldPosition();
    pos.Z += 1.00;
    log.Write("force\ttarget=" + how + "\tdist=" + CGPLog.Num(CGPLog.Distance(npc)) + "\t" + CGPLog.View(npc) + s"\tpart=\(bodyPart)\talive=" + CGPLog.Flag(ScriptedPuppet.IsAlive(npc)) + "\t" + CGPLog.Who(npc));
    log.SetSource("force");
    DismembermentComponent.RequestDismemberment(npc, bodyPart, gameDismWoundType.COARSE, pos);
    log.SetSource("");
    return s"Gore Probe: cut \(bodyPart) requested on " + how + " NPC at " + CGPLog.Num(CGPLog.Distance(npc)) + " m, result in 3 s";
  }

  // What V saw on the last NPC hit: 1 gore, 0 no gore
  public final func Seen(gore: Bool) -> String {
    let log: ref<CGPLog> = CGPLog.Get();
    if !IsDefined(log) || !IsDefined(log.lastNpc) {
      return "Gore Probe: no hit yet";
    };
    let npc: ref<NPCPuppet> = log.lastNpc;
    log.Write(s"seen\tseq=\(log.lastSeq)\tgore=" + CGPLog.Flag(gore) + "\tdist=" + CGPLog.Num(CGPLog.Distance(npc)) + "\t" + CGPLog.View(npc) + "\tid=" + EntityID.ToDebugString(npc.GetEntityID()));
    return s"Gore Probe: hit #\(log.lastSeq) marked " + (gore ? "GORE SEEN" : "NO GORE");
  }

  public final func Mark() -> String {
    let how: String;
    let log: ref<CGPLog> = CGPLog.Get();
    let npc: ref<NPCPuppet> = this.Target(how);
    if !IsDefined(log) {
      return "Gore Probe: log not ready";
    };
    if !IsDefined(npc) {
      log.Write("mark\ttarget=none");
      return "Gore Probe: mark written (no target)";
    };
    log.Write("mark\ttarget=" + how + "\tdist=" + CGPLog.Num(CGPLog.Distance(npc)) + "\t" + CGPLog.View(npc) + "\t" + CGPLog.Who(npc));
    return "Gore Probe: mark at " + CGPLog.Num(CGPLog.Distance(npc)) + " m";
  }

  public final func ToggleExperiment() -> Bool {
    let log: ref<CGPLog> = CGPLog.Get();
    if !IsDefined(log) {
      return false;
    };
    log.experiment = !log.experiment;
    log.Write("experiment\ton=" + CGPLog.Flag(log.experiment) + "\tt=" + CGPLog.Num(CGPLog.Now(this.GetGameInstance())));
    return log.experiment;
  }

  public final func ToggleAB() -> Bool {
    let log: ref<CGPLog> = CGPLog.Get();
    if !IsDefined(log) {
      return false;
    };
    log.autoAB = !log.autoAB;
    log.Write("autoAB\ton=" + CGPLog.Flag(log.autoAB) + "\tt=" + CGPLog.Num(CGPLog.Now(this.GetGameInstance())));
    return log.autoAB;
  }

  public final func Hud() -> String {
    let how: String;
    let log: ref<CGPLog> = CGPLog.Get();
    if !IsDefined(log) {
      return "Gore Probe: RedFileSystem log not ready";
    };
    let line: String = "Gore Probe " + log.FileName() + (log.experiment ? "  [far-cut experiment ON]" : "") + (log.autoAB ? "  [A/B on]" : "  [A/B off]");
    let npc: ref<NPCPuppet> = this.Target(how);
    if IsDefined(npc) && Equals(how, "crosshair") {
      line += "\ncrosshair NPC: " + CGPLog.Num(CGPLog.Distance(npc)) + " m";
    };
    if StrLen(log.lastText) > 0 {
      line += "\nlast hit " + log.lastText + "\nresult: " + log.lastCut;
    };
    return line;
  }
}

@wrapMethod(NPCPuppet)
private final func OnHitAnimation(hitEvent: ref<gameHitEvent>) -> Void {
  if IsDefined(hitEvent) && CGPLog.FromPlayer(hitEvent.attackData) && AttackData.IsRangedOrDirect(hitEvent.attackData.GetAttackType()) {
    let log: ref<CGPLog> = CGPLog.Get();
    if IsDefined(log) {
      let requested: Bool = this.ShouldRequestHitReaction(hitEvent);
      let dist: Float = CGPLog.Distance(this);
      if !requested || dist >= CGPLog.FarDistance() {
        log.Raw(this, hitEvent, requested, dist);
      };
    };
  };
  wrappedMethod(hitEvent);
}

@wrapMethod(HitReactionComponent)
public func EvaluateHit(newHitEvent: ref<gameHitEvent>) -> Void {
  let log: ref<CGPLog> = CGPLog.Get();
  let npc: ref<NPCPuppet> = this.GetOwner() as NPCPuppet;
  if !IsDefined(log) || !IsDefined(npc) || !IsDefined(newHitEvent) || !CGPLog.FromPlayer(newHitEvent.attackData) {
    wrappedMethod(newHitEvent);
    return;
  };
  if !AttackData.IsRangedOrDirect(newHitEvent.attackData.GetAttackType()) {
    log.CountSkip(true);
    wrappedMethod(newHitEvent);
    return;
  };
  let dist: Float = CGPLog.Distance(npc);
  let alivePre: Bool = ScriptedPuppet.IsAlive(npc);
  let deathPlayedPre: Bool = this.m_deathHasBeenPlayed;
  let seq: Int32 = log.BeginHit(npc, dist >= CGPLog.FarDistance() || !alivePre);
  wrappedMethod(newHitEvent);
  let aliveNow: Bool = ScriptedPuppet.IsAlive(npc);
  let killed: Bool = alivePre && !aliveNow;
  let exp: String = "-";
  // Forced cut: manual experiment (any distance) or automatic A/B (kill shots from 30 m, every second one)
  if !aliveNow && log.ReqCount() == 0 && !npc.cgpForced && ArraySize(newHitEvent.hitRepresentationResult.hitShapes) > 0 {
    let ab: Bool = log.autoAB && killed && dist >= CGPLog.ABDistance();
    if log.experiment || ab {
      let data: ref<HitShapeUserDataBase> = DamageSystemHelper.GetHitShapeUserDataBase(newHitEvent.hitRepresentationResult.hitShapes[0]);
      if IsDefined(data) {
        let part: gameDismBodyPart = HitShapeUserDataBase.GetDismembermentBodyPart(data);
        if Equals(part, gameDismBodyPart.BODY) {
          exp = "skip:torso";
        } else {
          if log.experiment || log.NextAB() {
            npc.cgpForced = true;
            exp = log.experiment ? s"forced:\(part)" : s"ab-forced:\(part)";
            log.SetSource(log.experiment ? "exp" : "ab");
            DismembermentComponent.RequestDismemberment(npc, part, this.GetDismembermentWoundType(), newHitEvent.hitRepresentationResult.hitShapes[0].result.hitPositionEnter);
            log.SetSource("");
          } else {
            exp = s"ab-control:\(part)";
          };
        };
      };
    };
  };
  // Near hits that neither kill nor request a cut (incl. shots into near corpses) are only counted
  if dist < CGPLog.FarDistance() && !killed && log.ReqCount() == 0 {
    log.SkipHit();
    return;
  };
  let state: String = "alivePre=" + CGPLog.Flag(alivePre) + "\taliveNow=" + CGPLog.Flag(aliveNow) + "\tcompAlive=" + CGPLog.Flag(this.m_isAlive);
  state += "\tdeathPlayedPre=" + CGPLog.Flag(deathPlayedPre) + "\tdeadStat=" + CGPLog.Flag(npc.IsDead()) + "\tdefeated=" + CGPLog.Flag(ScriptedPuppet.IsDefeated(npc));
  state += s"\treactNow=\(this.m_reactionType)\tmounted=" + CGPLog.Flag(VehicleComponent.IsMountedToVehicle(npc.GetGame(), npc.GetEntityID()));
  log.EndHit(npc, newHitEvent, seq, dist, state, exp);
}

// Entry snapshot of every gate the vanilla function checks, read before any other wrap runs
@wrapMethod(HitReactionComponent)
protected final func ProcessWoundsAndDismemberment() -> Void {
  let log: ref<CGPLog> = CGPLog.Get();
  if IsDefined(log) && log.InHit(this.GetOwner()) {
    let line: String = "";
    if log.WantsDetail(!ScriptedPuppet.IsAlive(this.m_ownerNPC)) {
      line = "canDie=" + CGPLog.Flag(this.CanDieCondition()) + "\talive=" + CGPLog.Flag(this.m_isAlive);
      line += "\taboutToDie=" + CGPLog.Flag(this.m_ownerNPC.IsAboutToDie()) + "\taboutToBeDefeated=" + CGPLog.Flag(this.m_ownerNPC.IsAboutToBeDefeated());
      line += s"\treact=\(this.m_reactionType)\tinstant=" + CGPLog.Flag(this.CheckInstantDismembermentOnDeath());
      let moves: ref<MovePoliciesComponent> = this.m_ownerNPC.GetMovePolicesComponent();
      line += "\toffMesh=" + CGPLog.Flag(IsDefined(moves) && moves.IsOnOffMeshLink()) + "\tmassive=" + CGPLog.Flag(this.m_ownerIsMassive);
      line += "\tinCover=" + CGPLog.Flag(this.m_inCover) + "\tworkspot=" + CGPLog.Flag(this.m_inWorkspot) + "\tguts=" + CGPLog.Flag(this.m_scatteredGuts);
      let data: ref<HitShapeUserDataBase> = this.GetHitShapeUserData();
      if IsDefined(data) {
        let i: Int32 = EnumInt(HitShapeUserDataBase.GetHitReactionZone(data));
        if i >= 0 && i < ArraySize(this.m_bodyPartDismemberCumulatedDamages) && i < ArraySize(this.m_dismembermentBodyPartDamageThreshold) {
          line += "\tcum=" + CGPLog.Num(this.m_bodyPartDismemberCumulatedDamages[i]) + "\tthr=" + CGPLog.Num(this.m_dismembermentBodyPartDamageThreshold[i]);
        };
      };
    };
    log.SetPwd(line);
  };
  wrappedMethod();
}

@wrapMethod(HitReactionComponent)
protected final func DismembermentConditions() -> Bool {
  let result: Bool = wrappedMethod();
  let log: ref<CGPLog> = CGPLog.Get();
  if IsDefined(log) && log.InHit(this.GetOwner()) {
    log.AddDc(result);
  };
  return result;
}

@wrapMethod(DismembermentComponent)
public final static func RequestDismemberment(obj: ref<GameObject>, bodyPart: gameDismBodyPart, woundType: gameDismWoundType, opt hitPosition: Vector4, opt isCritical: Bool, opt debrisPath: String, opt debrisStrength: Float) -> Void {
  let npc: ref<NPCPuppet> = obj as NPCPuppet;
  let log: ref<CGPLog> = CGPLog.Get();
  if IsDefined(npc) && IsDefined(log) {
    log.OnRequest(npc, bodyPart, woundType, hitPosition, isCritical, debrisPath);
  };
  wrappedMethod(obj, bodyPart, woundType, hitPosition, isCritical, debrisPath, debrisStrength);
}

// The event handler that calls the native DoDismemberment
@wrapMethod(DismembermentComponent)
protected cb func OnDismemberment(evt: ref<DismembermentEvent>) -> Bool {
  let result: Bool = wrappedMethod(evt);
  let npc: ref<NPCPuppet> = this.GetEntity() as NPCPuppet;
  let log: ref<CGPLog> = CGPLog.Get();
  if IsDefined(npc) && IsDefined(log) {
    log.OnNative(npc, evt);
  };
  return result;
}
