///|
pub fn kv_demo_report(seed : Int) -> String {
  let normal = SimRuntime::new(seed)
  let leader = normal.spawn("kv-leader")
  let follower = normal.spawn("kv-follower")
  leader.tell(normal, "put user:1 alice")
  follower.tell(normal, "replicate user:1 alice")
  let read_result = leader.ask(normal, "get user:1", 10)
  normal.run_all(64)

  let timeout = SimRuntime::new(seed)
  timeout.set_fault(DelayEvery(1, 20))
  let slow_actor = timeout.spawn("slow-worker")
  let timeout_result = slow_actor.ask(timeout, "work item:42", 5)
  timeout.run_all(64)

  "MoonSim Actors KV demo\n" +
  "normal: " +
  normal.summary() +
  "\n" +
  "normal ask: " +
  ask_result_text(read_result) +
  "\n" +
  "timeout: " +
  timeout.summary() +
  "\n" +
  "timeout ask: " +
  ask_result_text(timeout_result) +
  "\n" +
  "normal trace:\n" +
  normal.trace_text()
}

///|
pub fn mailbox_bench_report(messages : Int) -> String {
  let total = if messages < 0 { 0 } else { messages }
  let sim = SimRuntime::new(7)
  let worker = sim.spawn("bench-worker")
  let mut i = 0
  while i < total {
    worker.tell(sim, "msg " + "\{i}")
    i = i + 1
  }
  sim.run_all(total + 16)
  "mailbox benchmark\nmessages=" + "\{total}" + "\n" + sim.summary()
}

///|
pub fn ask_result_text(result : AskResult) -> String {
  match result {
    AskOk(envelope) => "ok(" + envelope.payload + ")"
    AskErr(error) => "err(" + ask_error_text(error) + ")"
  }
}

///|
fn ask_error_text(error : AskError) -> String {
  match error {
    Timeout => "timeout"
    Dropped => "dropped"
    ActorStopped => "actor-stopped"
    ActorMissing => "actor-missing"
  }
}
