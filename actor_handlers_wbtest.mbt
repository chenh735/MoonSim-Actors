///|
test "echo actor replies through handler" {
  let sim = SimRuntime::new(11)
  let echo = sim.spawn_actor("echo", Echo)
  let result = echo.ask(sim, "ping", 10)
  assert_eq(ask_result_text(result), "ok(echo:ping)")
  assert_true(sim.trace_text().contains("MessageReplied"))
}

///|
test "kv actor handles put and get with state" {
  let sim = SimRuntime::new(12)
  let leader = sim.spawn_actor("kv-leader", KvLeader)
  leader.tell(sim, "put user:1 alice")
  sim.run_all(16)
  let result = leader.ask(sim, "get user:1", 10)
  assert_eq(ask_result_text(result), "ok(value user:1 alice)")
}

///|
test "kv follower shows stale read before replication and value after" {
  let sim = SimRuntime::new(13)
  let follower = sim.spawn_actor("kv-follower", KvFollower)
  let before = follower.ask(sim, "get user:1", 10)
  follower.tell(sim, "replicate user:1 bob")
  sim.run_all(16)
  let after = follower.ask(sim, "get user:1", 10)
  assert_eq(ask_result_text(before), "ok(missing user:1)")
  assert_eq(ask_result_text(after), "ok(value user:1 bob)")
}
