///|
/// Dispatch CLI-style arguments to demo, benchmark, or replay reports.
pub fn cli_report(args : Array[String]) -> String {
  let command_index = first_command_index(args)
  if command_index >= args.length() {
    cli_help()
  } else {
    match args[command_index] {
      "run" => cli_run(args, command_index + 1)
      "bench" => cli_bench(args, command_index + 1)
      "replay" => cli_replay(args, command_index + 1)
      "trace" => cli_trace(args, command_index + 1)
      "help" => cli_help()
      "--help" => cli_help()
      _ => "unknown command: " + args[command_index] + "\n" + cli_help()
    }
  }
}

///|
/// Return a short command summary for users and smoke tests.
pub fn cli_help() -> String {
  "MoonSim Actors CLI\n" +
  "commands:\n" +
  "  run kv_cluster --seed <n>\n" +
  "  bench mailbox --messages <n> [--format text|markdown|json]\n" +
  "  replay kv_cluster --seed <n>\n" +
  "  replay file <path> [--format archive|json]\n" +
  "  trace kv_cluster --seed <n> --out <path> [--format archive|json]\n"
}

///|
/// Skip the executable path when args come from @env.args().
fn first_command_index(args : Array[String]) -> Int {
  if args.length() == 0 {
    0
  } else if args[0].contains("moonsim") || args[0].contains("moonrun") {
    1
  } else {
    0
  }
}

///|
/// Handle `run` commands for the built-in scenarios.
fn cli_run(args : Array[String], start : Int) -> String {
  let target = arg_or(args, start, "kv_cluster")
  let seed = parse_option_int(args, "--seed", 42)
  match target {
    "kv_cluster" => kv_demo_report(seed)
    "kv" => kv_demo_report(seed)
    _ => "unknown run target: " + target
  }
}

///|
/// Handle benchmark commands without coupling benchmark logic to the CLI.
fn cli_bench(args : Array[String], start : Int) -> String {
  let target = arg_or(args, start, "mailbox")
  let messages = parse_option_int(args, "--messages", 1000)
  let format = parse_option_string(args, "--format", "text")
  match target {
    "mailbox" =>
      match format {
        "json" => mailbox_bench_json_report(messages)
        "markdown" => mailbox_bench_markdown_report(messages)
        "md" => mailbox_bench_markdown_report(messages)
        _ => mailbox_bench_report(messages)
      }
    _ => "unknown bench target: " + target
  }
}

///|
/// Handle replay checks over deterministic built-in scenario traces.
fn cli_replay(args : Array[String], start : Int) -> String {
  let target = arg_or(args, start, "kv_cluster")
  let seed = parse_option_int(args, "--seed", 42)
  match target {
    "kv_cluster" => replay_report(kv_cluster_trace_archive(seed))
    "kv" => replay_report(kv_cluster_trace_archive(seed))
    "file" => {
      let path = arg_or(args, start + 1, "")
      if path == "" {
        "replay failed\nmissing trace file path"
      } else {
        let format = parse_trace_format(parse_option_string(args, "--format", "archive"))
        let check = replay_trace_file(path, format) catch {
          _ => return "replay failed\nfile read error: " + path
        }
        render_replay_check(check)
      }
    }
    _ => "unknown replay target: " + target
  }
}

///|
/// Handle trace file generation commands for built-in scenarios.
fn cli_trace(args : Array[String], start : Int) -> String {
  let target = arg_or(args, start, "kv_cluster")
  let seed = parse_option_int(args, "--seed", 42)
  let path = parse_option_string(args, "--out", "")
  let format = parse_trace_format(parse_option_string(args, "--format", "archive"))
  if path == "" {
    "trace failed\nmissing --out <path>"
  } else {
    match target {
      "kv_cluster" | "kv" => {
        write_kv_cluster_trace_file(seed, path, format) catch {
          _ => return "trace failed\nfile write error: " + path
        }
        "trace written\npath=" +
        path +
        "\nformat=" +
        trace_format_text(format) +
        "\nseed=" +
        "\{seed}"
      }
      _ => "unknown trace target: " + target
    }
  }
}

///|
/// Render replay validation results for CLI output.
fn replay_report(archive : String) -> String {
  let check = replay_trace_archive(archive)
  render_replay_check(check)
}

///|
/// Render replay validation results from any trace format.
fn render_replay_check(check : ReplayCheck) -> String {
  if check.ok {
    "replay ok\nseed=" + "\{check.seed}" + "\nevents=" + "\{check.events}"
  } else {
    "replay failed\n" + check.error
  }
}

///|
/// Return an argument or a default when the position is absent.
fn arg_or(args : Array[String], index : Int, default : String) -> String {
  if index >= 0 && index < args.length() {
    args[index]
  } else {
    default
  }
}

///|
/// Parse a string option from `--name value` pairs.
fn parse_option_string(
  args : Array[String],
  name : String,
  default : String,
) -> String {
  let mut i = 0
  while i < args.length() - 1 {
    if args[i] == name {
      return args[i + 1]
    }
    i = i + 1
  }
  default
}

///|
/// Parse a positive integer option from `--name value` pairs.
fn parse_option_int(args : Array[String], name : String, default : Int) -> Int {
  let mut i = 0
  while i < args.length() - 1 {
    if args[i] == name {
      return parse_positive_int_string(args[i + 1], default)
    }
    i = i + 1
  }
  default
}

///|
/// Parse ASCII digits for CLI options, falling back on invalid input.
fn parse_positive_int_string(text : String, default : Int) -> Int {
  if text.length() == 0 {
    return default
  }
  let mut value = 0
  let mut i = 0
  while i < text.length() {
    let code = text.unsafe_get(i).to_int()
    if code < 48 || code > 57 {
      return default
    }
    value = value * 10 + (code - 48)
    i = i + 1
  }
  value
}

///|
/// Convert CLI trace format text to the internal trace format enum.
fn parse_trace_format(text : String) -> TraceFormat {
  match text {
    "json" => TraceJson
    "archive" => TraceArchive
    "text" => TraceArchive
    _ => TraceArchive
  }
}

///|
/// Render trace format for stable CLI output.
fn trace_format_text(format : TraceFormat) -> String {
  match format {
    TraceArchive => "archive"
    TraceJson => "json"
  }
}
