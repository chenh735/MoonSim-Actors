///|
test "benchmark summary renders text markdown and json" {
  let summary = run_mailbox_bench(3)
  assert_eq(summary.name, "mailbox")
  assert_eq(summary.messages, 3)
  assert_eq(summary.delivered, 3)
  assert_true(summary.elapsed_us >= 0.0)
  assert_true(summary.to_text().contains("elapsed_us="))
  assert_true(summary.to_markdown().contains("| messages | 3 |"))
  let json = summary.to_json()
  assert_true(@json.valid(json))
  assert_true(json.contains("\"delivered\":3"))
}

///|
test "cli bench supports markdown and json formats" {
  let markdown = cli_report([
    "moonsim", "bench", "mailbox", "--messages", "2", "--format", "markdown",
  ])
  assert_true(markdown.contains("| messages | 2 |"))
  let json = cli_report([
    "moonsim", "bench", "mailbox", "--messages", "2", "--format", "json",
  ])
  assert_true(@json.valid(json))
  assert_true(json.contains("\"messages\":2"))
}

///|
test "cli trace writes json and replay file reads it" {
  let path = "tmp_moonsim_cli_trace.json"
  if @fs.path_exists(path) {
    @fs.remove_file(path) catch { _ => () }
  }
  let written = cli_report([
    "moonsim", "trace", "kv_cluster", "--seed", "44", "--out", path,
    "--format", "json",
  ])
  assert_true(written.contains("trace written"))
  let replay = cli_report(["moonsim", "replay", "file", path, "--format", "json"])
  assert_true(replay.contains("replay ok"))
  assert_true(replay.contains("seed=44"))
  @fs.remove_file(path) catch { _ => () }
}
