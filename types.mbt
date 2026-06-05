///|
pub(all) struct ActorRef {
  id : Int
  name : String
} derive(Debug, Eq)

///|
pub(all) struct Envelope {
  from : Int
  to : Int
  payload : String
  request_id : Int
  expect_reply : Bool
} derive(Debug, Eq)

///|
pub(all) struct TraceEvent {
  step : Int
  time_ms : Int
  kind : String
  detail : String
} derive(Debug, Eq)

///|
pub(all) enum AskError {
  Timeout
  Dropped
  ActorStopped
  ActorMissing
} derive(Debug, Eq)

///|
pub(all) enum AskResult {
  AskOk(Envelope)
  AskErr(AskError)
} derive(Debug, Eq)

///|
pub(all) enum FaultRule {
  NoFault
  DelayEvery(Int, Int)
  DropEvery(Int)
  Reorder
} derive(Debug, Eq)

///|
pub(all) enum SupervisionStrategy {
  Stop
  Restart
} derive(Debug, Eq)

///|
pub(all) struct ActorCell {
  id : Int
  name : String
  mut alive : Bool
  mut paused : Bool
  mut generation : Int
  mut mailbox : Array[Envelope]
} derive(Debug, Eq)

///|
pub(all) enum ScheduledKind {
  Deliver(Envelope)
  FireTimeout(Int, Int)
} derive(Debug, Eq)

///|
pub(all) struct ScheduledEvent {
  due_ms : Int
  seq : Int
  kind : ScheduledKind
} derive(Debug, Eq)

///|
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
  mut fault_rule : FaultRule
}
