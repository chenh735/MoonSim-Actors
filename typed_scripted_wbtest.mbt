enum CacheCommand {
  CachePut(String, String)
  CacheGet(String)
}

///|
/// Encode a typed cache command into the runtime payload protocol.
fn encode_cache_command(command : CacheCommand) -> String {
  match command {
    CachePut(key, value) => "set " + key + " " + value
    CacheGet(key) => "get " + key
  }
}

///|
test "typed actor ref encodes custom cache messages" {
  let sim = SimRuntime::new(21)
  let cache = sim.spawn_scripted_actor("cache", [
    HandlerRule::{ matcher: MatchPrefix("set "), action: PutFromParts(1, 2) },
    HandlerRule::{ matcher: MatchPrefix("get "), action: GetFromParts(1) },
  ])
  let typed : TypedActorRef[CacheCommand] = cache.typed()
  typed.tell(sim, CachePut("token", "abc"), encode_cache_command)
  sim.run_all(16)
  let result = typed.ask(sim, CacheGet("token"), encode_cache_command, 10)
  assert_eq(ask_result_text(result), "ok(value token abc)")
}

///|
test "scripted actor rules can reply with payload" {
  let sim = SimRuntime::new(22)
  let service = sim.spawn_scripted_actor("service", [
    HandlerRule::{ matcher: MatchAny, action: ReplyWithPayload("handled:") },
  ])
  let result = service.ask(sim, "work 1", 10)
  assert_eq(ask_result_text(result), "ok(handled:work 1)")
  assert_true(sim.trace_text().contains("scripted reply-payload"))
}
