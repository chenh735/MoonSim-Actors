///|
test "trace archive replays with seed and event count" {
  let archive = kv_cluster_trace_archive(42)
  let check = replay_trace_archive(archive)
  assert_true(check.ok)
  assert_eq(check.seed, 42)
  assert_eq(check.events, 8)
}

///|
test "replay rejects missing trace header" {
  let check = replay_trace_archive("#1 t=0 MessageSent bogus")
  assert_false(check.ok)
  assert_eq(check.error, "missing trace header")
}
