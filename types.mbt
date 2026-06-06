///|
/// Public handle for sending messages to an actor without exposing its state.
pub(all) struct ActorRef {
  id : Int
  name : String
} derive(Debug, Eq)

///|
/// Typed adapter over ActorRef; callers provide an encoder for their message type.
pub(all) struct TypedActorRef[T] {
  inner : ActorRef
  marker : T?
}

///|
/// Message envelope stored in the runtime queue and actor mailbox.
pub(all) struct Envelope {
  from : Int
  to : Int
  payload : String
  request_id : Int
  expect_reply : Bool
} derive(Debug, Eq)

///|
/// Reply produced by a handler and matched back to a pending ask request.
pub(all) struct AskReply {
  request_id : Int
  response : Envelope
} derive(Debug, Eq)

///|
/// Logical event recorded for deterministic debugging and replay checks.
pub(all) struct TraceEvent {
  step : Int
  time_ms : Int
  kind : String
  detail : String
} derive(Debug, Eq)

///|
/// Failure modes that can complete an ask request without a response.
pub(all) enum AskError {
  Timeout
  Dropped
  ActorStopped
  ActorMissing
} derive(Debug, Eq)

///|
/// Result returned by ask: either a response envelope or an ask error.
pub(all) enum AskResult {
  AskOk(Envelope)
  AskErr(AskError)
} derive(Debug, Eq)

///|
/// Fault model applied when messages enter or leave the event queue.
pub(all) enum FaultRule {
  NoFault
  DelayEvery(Int, Int)
  DropEvery(Int)
  Reorder
} derive(Debug, Eq)

///|
/// Minimal strategy used by supervise after a simulated actor failure.
pub(all) enum SupervisionStrategy {
  Stop
  Restart
} derive(Debug, Eq)

///|
/// Match condition used by a scripted custom actor receive rule.
pub(all) enum HandlerMatch {
  MatchAny
  MatchExact(String)
  MatchPrefix(String)
} derive(Debug, Eq)

///|
/// Action performed by a scripted custom actor receive rule.
pub(all) enum HandlerAction {
  NoAction
  ReplyText(String)
  ReplyWithPayload(String)
  PutFromParts(Int, Int)
  GetFromParts(Int)
} derive(Debug, Eq)

///|
/// Data-driven receive rule for custom actors used in simulation scenarios.
pub(all) struct HandlerRule {
  matcher : HandlerMatch
  action : HandlerAction
} derive(Debug, Eq)

///|
/// Built-in or scripted actor behavior selected by the runtime dispatcher.
pub(all) enum ActorKind {
  Sink
  Echo
  KvLeader
  KvFollower
  Scripted
} derive(Debug, Eq)

///|
/// Runtime-owned actor state, lifecycle flags, supervision tree links, and KV state.
pub(all) struct ActorCell {
  id : Int
  name : String
  kind : ActorKind
  parent : Int
  mut children : Array[Int]
  mut strategy : SupervisionStrategy
  mut restart_limit : Int
  mut restart_count : Int
  mut alive : Bool
  mut paused : Bool
  mut generation : Int
  mut mailbox : Array[Envelope]
  mut kv : Map[String, String]
  mut rules : Array[HandlerRule]
} derive(Debug, Eq)

///|
/// Type of scheduled event that the deterministic runtime can execute.
pub(all) enum ScheduledKind {
  Deliver(Envelope)
  FireTimeout(Int, Int)
} derive(Debug, Eq)

///|
/// Timed event in the runtime queue; seq breaks ties deterministically.
pub(all) struct ScheduledEvent {
  due_ms : Int
  seq : Int
  kind : ScheduledKind
} derive(Debug, Eq)

///|
/// Complete mutable state of one deterministic simulation runtime.
pub(all) struct SimRuntime {
  seed : Int
  mut rng : Int
  mut clock_ms : Int
  mut step : Int
  mut next_actor_id : Int
  mut next_request_id : Int
  mut next_seq : Int
  mut actors : Array[ActorCell]
  mut events : Array[ScheduledEvent]
  mut trace : Array[TraceEvent]
  mut delivered : Array[Envelope]
  mut replies : Array[AskReply]
  mut fault_rule : FaultRule
}

///|
/// Summary returned by trace replay validation.
pub(all) struct ReplayCheck {
  ok : Bool
  seed : Int
  events : Int
  error : String
} derive(Debug, Eq)

///|
/// Format used when persisting or replaying traces from files.
pub(all) enum TraceFormat {
  TraceArchive
  TraceJson
} derive(Debug, Eq)

///|
/// Measured mailbox benchmark summary rendered by text, Markdown, or JSON helpers.
pub(all) struct BenchSummary {
  name : String
  messages : Int
  delivered : Int
  trace_events : Int
  virtual_time_ms : Int
  elapsed_us : Double
} derive(Debug)
