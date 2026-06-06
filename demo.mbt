///|
/// Run a stateful KV cluster scenario and return a human-readable report.
pub fn kv_demo_report(seed : Int) -> String {
  let normal = build_kv_cluster(seed)
  let leader = ActorRef::{ id: 1, name: "kv-leader" }
  let follower = ActorRef::{ id: 2, name: "kv-follower" }
  let leader_read = leader.ask(normal, "get user:1", 10)
  let follower_read = follower.ask(normal, "get user:1", 10)
  normal.run_all(64)

  let stale = SimRuntime::new(seed)
  let stale_follower = stale.spawn_actor("kv-follower", KvFollower)
  let stale_before = stale_follower.ask(stale, "get user:1", 10)
  stale_follower.tell(stale, "replicate user:1 bob")
  stale.run_all(64)
  let stale_after = stale_follower.ask(stale, "get user:1", 10)

  "MoonSim Actors KV demo\n" +
  "normal: " +
  normal.summary() +
  "\n" +
  "leader read: " +
  ask_result_text(leader_read) +
  "\n" +
  "follower read: " +
  ask_result_text(follower_read) +
  "\n" +
  "stale before replicate: " +
  ask_result_text(stale_before) +
  "\n" +
  "stale after replicate: " +
  ask_result_text(stale_after) +
  "\n" +
  "normal trace:\n" +
  normal.trace_text()
}

///|
/// Return a versioned trace archive for the KV cluster scenario.
pub fn kv_cluster_trace_archive(seed : Int) -> String {
  build_kv_cluster(seed).trace_archive()
}

///|
/// Return a JSON trace document for the KV cluster scenario.
pub fn kv_cluster_trace_json(seed : Int) -> String {
  build_kv_cluster(seed).trace_json()
}

///|
/// Write the KV cluster scenario trace to a file in the requested format.
pub fn write_kv_cluster_trace_file(
  seed : Int,
  path : String,
  format : TraceFormat,
) -> Unit raise @fs.IOError {
  build_kv_cluster(seed).write_trace_file(path, format)
}

///|
/// Run the normal KV cluster setup without consuming read requests.
fn build_kv_cluster(seed : Int) -> SimRuntime {
  let sim = SimRuntime::new(seed)
  let leader = sim.spawn_actor("kv-leader", KvLeader)
  let follower = sim.spawn_actor("kv-follower", KvFollower)
  leader.tell(sim, "put user:1 alice")
  follower.tell(sim, "replicate user:1 alice")
  sim.run_all(64)
  sim
}

///|
/// Run a timed mailbox benchmark and return structured metrics.
pub fn run_mailbox_bench(messages : Int) -> BenchSummary {
  let total = if messages < 0 { 0 } else { messages }
  let start = @bench.monotonic_clock_start()
  let sim = SimRuntime::new(7)
  let worker = sim.spawn("bench-worker")
  let mut i = 0
  while i < total {
    worker.tell(sim, "msg " + "\{i}")
    i = i + 1
  }
  sim.run_all(total + 16)
  let elapsed_us = @bench.monotonic_clock_end(start)
  BenchSummary::{
    name: "mailbox",
    messages: total,
    delivered: sim.delivered.length(),
    trace_events: sim.trace.length(),
    virtual_time_ms: sim.now(),
    elapsed_us,
  }
}

///|
/// Produce a timed mailbox throughput summary for demos.
pub fn mailbox_bench_report(messages : Int) -> String {
  run_mailbox_bench(messages).to_text()
}

///|
/// Produce a Markdown mailbox benchmark report.
pub fn mailbox_bench_markdown_report(messages : Int) -> String {
  run_mailbox_bench(messages).to_markdown()
}

///|
/// Produce a JSON mailbox benchmark report.
pub fn mailbox_bench_json_report(messages : Int) -> String {
  run_mailbox_bench(messages).to_json()
}

///|
/// Render benchmark metrics as compact human-readable text.
pub fn BenchSummary::to_text(self : BenchSummary) -> String {
  "mailbox benchmark\n" +
  "messages=" +
  "\{self.messages}" +
  "\n" +
  "delivered=" +
  "\{self.delivered}" +
  "\n" +
  "trace_events=" +
  "\{self.trace_events}" +
  "\n" +
  "elapsed_us=" +
  "\{self.elapsed_us}" +
  "\n" +
  "virtual_time_ms=" +
  "\{self.virtual_time_ms}"
}

///|
/// Render benchmark metrics as a Markdown table.
pub fn BenchSummary::to_markdown(self : BenchSummary) -> String {
  "| metric | value |\n" +
  "| --- | --- |\n" +
  "| name | " +
  self.name +
  " |\n" +
  "| messages | " +
  "\{self.messages}" +
  " |\n" +
  "| delivered | " +
  "\{self.delivered}" +
  " |\n" +
  "| trace_events | " +
  "\{self.trace_events}" +
  " |\n" +
  "| virtual_time_ms | " +
  "\{self.virtual_time_ms}" +
  " |\n" +
  "| elapsed_us | " +
  "\{self.elapsed_us}" +
  " |\n"
}

///|
/// Render benchmark metrics as valid JSON for automation.
pub fn BenchSummary::to_json(self : BenchSummary) -> String {
  "{\"name\":\"" +
  self.name +
  "\",\"messages\":" +
  "\{self.messages}" +
  ",\"delivered\":" +
  "\{self.delivered}" +
  ",\"trace_events\":" +
  "\{self.trace_events}" +
  ",\"virtual_time_ms\":" +
  "\{self.virtual_time_ms}" +
  ",\"elapsed_us\":" +
  "\{self.elapsed_us}" +
  "}"
}

///|
/// Render ask results in stable text for tests, demos, and CLI output.
pub fn ask_result_text(result : AskResult) -> String {
  match result {
    AskOk(envelope) => "ok(" + envelope.payload + ")"
    AskErr(error) => "err(" + ask_error_text(error) + ")"
  }
}

///|
/// Convert ask errors to compact stable names.
fn ask_error_text(error : AskError) -> String {
  match error {
    Timeout => "timeout"
    Dropped => "dropped"
    ActorStopped => "actor-stopped"
    ActorMissing => "actor-missing"
  }
}
