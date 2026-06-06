///|
test "trace json is valid and replayable" {
  let json = kv_cluster_trace_json(41)
  assert_true(@json.valid(json))
  let check = replay_trace_json(json)
  assert_true(check.ok)
  assert_eq(check.seed, 41)
  assert_eq(check.events, 8)
}

///|
test "trace files round trip archive and json formats" {
  let archive_path = "tmp_moonsim_trace_archive.txt"
  let json_path = "tmp_moonsim_trace.json"
  if @fs.path_exists(archive_path) {
    @fs.remove_file(archive_path) catch { _ => () }
  }
  if @fs.path_exists(json_path) {
    @fs.remove_file(json_path) catch { _ => () }
  }
  write_kv_cluster_trace_file(42, archive_path, TraceArchive) catch {
    _ => panic()
  }
  write_kv_cluster_trace_file(43, json_path, TraceJson) catch {
    _ => panic()
  }
  let archive_check = replay_trace_file(archive_path, TraceArchive) catch {
    _ => panic()
  }
  let json_check = replay_trace_file(json_path, TraceJson) catch {
    _ => panic()
  }
  assert_true(archive_check.ok)
  assert_eq(archive_check.seed, 42)
  assert_true(json_check.ok)
  assert_eq(json_check.seed, 43)
  @fs.remove_file(archive_path) catch { _ => () }
  @fs.remove_file(json_path) catch { _ => () }
}
