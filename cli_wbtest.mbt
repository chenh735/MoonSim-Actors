///|
test "cli run executes kv cluster scenario with seed" {
  let report = cli_report(["moonsim", "run", "kv_cluster", "--seed", "9"])
  assert_true(report.contains("MoonSim Actors KV demo"))
  assert_true(report.contains("leader read: ok(value user:1 alice)"))
}

///|
test "cli bench renders mailbox metrics" {
  let report = cli_report(["moonsim", "bench", "mailbox", "--messages", "5"])
  assert_true(report.contains("mailbox benchmark"))
  assert_true(report.contains("messages=5"))
  assert_true(report.contains("delivered=5"))
}

///|
test "cli replay validates deterministic kv trace" {
  let report = cli_report(["moonsim", "replay", "kv_cluster", "--seed", "9"])
  assert_true(report.contains("replay ok"))
  assert_true(report.contains("seed=9"))
}
