///|
/// Create a deterministic simulation runtime with a stable non-zero seed.
pub fn SimRuntime::new(seed : Int) -> SimRuntime {
  let normalized_seed = if seed == 0 { 1 } else { seed }
  SimRuntime::{
    seed: normalized_seed,
    rng: normalized_seed,
    clock_ms: 0,
    step: 0,
    next_actor_id: 1,
    next_request_id: 1,
    next_seq: 1,
    actors: [],
    events: [],
    trace: [],
    delivered: [],
    replies: [],
    fault_rule: NoFault,
  }
}

///|
/// Set the active fault rule used when new messages enter the event queue.
pub fn SimRuntime::set_fault(self : SimRuntime, rule : FaultRule) -> Unit {
  self.fault_rule = rule
}

///|
/// Return the virtual clock value in milliseconds.
pub fn SimRuntime::now(self : SimRuntime) -> Int {
  self.clock_ms
}

///|
/// Spawn a mailbox-only actor; this preserves the original low-level API.
pub fn SimRuntime::spawn(self : SimRuntime, name : String) -> ActorRef {
  self.spawn_actor(name, Sink)
}

///|
/// Spawn an actor with a built-in handler kind for demos and tests.
pub fn SimRuntime::spawn_actor(
  self : SimRuntime,
  name : String,
  kind : ActorKind,
) -> ActorRef {
  self.spawn_actor_with_parent_and_rules(name, kind, 0, [])
}

///|
/// Spawn a child actor and link it into the parent's supervision tree.
pub fn SimRuntime::spawn_child(
  self : SimRuntime,
  parent : ActorRef,
  name : String,
  kind : ActorKind,
) -> ActorRef {
  self.spawn_actor_with_parent_and_rules(name, kind, parent.id, [])
}

///|
/// Spawn a custom actor whose receive behavior is described by ordered rules.
pub fn SimRuntime::spawn_scripted_actor(
  self : SimRuntime,
  name : String,
  rules : Array[HandlerRule],
) -> ActorRef {
  self.spawn_actor_with_parent_and_rules(name, Scripted, 0, rules)
}

///|
/// Spawn a scripted child actor under a parent supervisor.
pub fn SimRuntime::spawn_scripted_child(
  self : SimRuntime,
  parent : ActorRef,
  name : String,
  rules : Array[HandlerRule],
) -> ActorRef {
  self.spawn_actor_with_parent_and_rules(name, Scripted, parent.id, rules)
}

///|
/// Return current direct children of an actor as public references.
pub fn SimRuntime::children_of(
  self : SimRuntime,
  actor : ActorRef,
) -> Array[ActorRef] {
  let out : Array[ActorRef] = []
  let index = self.find_actor_index(actor.id)
  if index >= 0 {
    let children = self.actors[index].children
    let mut i = 0
    while i < children.length() {
      let child_index = self.find_actor_index(children[i])
      if child_index >= 0 {
        let child = self.actors[child_index]
        out.push(ActorRef::{ id: child.id, name: child.name })
      }
      i = i + 1
    }
  }
  out
}

///|
/// Return the parent actor reference for a child actor when one exists.
pub fn SimRuntime::parent_of(
  self : SimRuntime,
  actor : ActorRef,
) -> ActorRef? {
  let index = self.find_actor_index(actor.id)
  if index < 0 {
    None
  } else {
    let parent_id = self.actors[index].parent
    if parent_id == 0 {
      None
    } else {
      let parent_index = self.find_actor_index(parent_id)
      if parent_index < 0 {
        None
      } else {
        let parent = self.actors[parent_index]
        Some(ActorRef::{ id: parent.id, name: parent.name })
      }
    }
  }
}

///|
/// Internal actor constructor shared by built-in and scripted actors.
fn SimRuntime::spawn_actor_with_parent_and_rules(
  self : SimRuntime,
  name : String,
  kind : ActorKind,
  parent : Int,
  rules : Array[HandlerRule],
) -> ActorRef {
  let id = self.next_actor_id
  self.next_actor_id = id + 1
  let cell = ActorCell::{
    id,
    name,
    kind,
    parent,
    children: [],
    strategy: Restart,
    restart_limit: -1,
    restart_count: 0,
    alive: true,
    paused: false,
    generation: 0,
    mailbox: [],
    kv: {},
    rules: rules.copy(),
  }
  self.actors.push(cell)
  let actor = ActorRef::{ id, name }
  self.attach_child(parent, id)
  self.record("ActorSpawned", actor_label(actor))
  actor
}

///|
/// Stop an actor so future deliveries to it are rejected.
pub fn SimRuntime::stop(self : SimRuntime, actor : ActorRef) -> Unit {
  self.stop_actor_tree(actor.id)
}

///|
/// Restart an actor by clearing volatile state and bumping its generation.
pub fn SimRuntime::restart(self : SimRuntime, actor : ActorRef) -> Unit {
  self.restart_actor_tree(actor.id)
}

///|
/// Apply a minimal supervision strategy after a simulated actor failure.
pub fn SimRuntime::supervise(
  self : SimRuntime,
  actor : ActorRef,
  strategy : SupervisionStrategy,
) -> Unit {
  self.supervise_with_limit(actor, strategy, -1)
}

///|
/// Apply a supervision strategy with an optional restart limit.
pub fn SimRuntime::supervise_with_limit(
  self : SimRuntime,
  actor : ActorRef,
  strategy : SupervisionStrategy,
  restart_limit : Int,
) -> Unit {
  self.record("ActorFailed", actor_label(actor))
  match strategy {
    Stop => self.stop(actor)
    Restart => {
      let index = self.find_actor_index(actor.id)
      if index >= 0 {
        let cell = self.actors[index]
        cell.strategy = strategy
        cell.restart_limit = restart_limit
        if restart_limit >= 0 && cell.restart_count >= restart_limit {
          self.actors[index] = cell
          self.record("RestartLimitExceeded", actor_label(actor))
          self.stop(actor)
        } else {
          cell.restart_count = cell.restart_count + 1
          self.actors[index] = cell
          self.restart(actor)
        }
      }
    }
  }
}

///|
/// Pause an actor; deliveries are rescheduled until it is resumed.
pub fn SimRuntime::pause(self : SimRuntime, actor : ActorRef) -> Unit {
  let index = self.find_actor_index(actor.id)
  if index >= 0 {
    let cell = self.actors[index]
    cell.paused = true
    self.actors[index] = cell
    self.record("NodePaused", actor_label(actor))
  }
}

///|
/// Resume a paused actor so delayed messages can be delivered.
pub fn SimRuntime::resume_actor(self : SimRuntime, actor : ActorRef) -> Unit {
  let index = self.find_actor_index(actor.id)
  if index >= 0 {
    let cell = self.actors[index]
    cell.paused = false
    self.actors[index] = cell
    self.record("NodeResumed", actor_label(actor))
  }
}

///|
/// Send a one-way message through the runtime.
pub fn ActorRef::tell(
  self : ActorRef,
  runtime : SimRuntime,
  payload : String,
) -> Unit {
  runtime.tell_to(self, payload)
}

///|
/// Send a request message and wait for a handler reply or virtual timeout.
pub fn ActorRef::ask(
  self : ActorRef,
  runtime : SimRuntime,
  payload : String,
  timeout_ms : Int,
) -> AskResult {
  runtime.ask_to(self, payload, timeout_ms)
}

///|
/// Create a typed view of an actor reference for encoder-based messages.
pub fn[T] ActorRef::typed(self : ActorRef) -> TypedActorRef[T] {
  TypedActorRef::{ inner: self, marker: None }
}

///|
/// Return the untyped actor reference wrapped by a typed actor ref.
pub fn[T] TypedActorRef::raw_ref(self : TypedActorRef[T]) -> ActorRef {
  self.inner
}

///|
/// Encode and send a typed one-way message.
pub fn[T] TypedActorRef::tell(
  self : TypedActorRef[T],
  runtime : SimRuntime,
  message : T,
  encode : (T) -> String,
) -> Unit {
  self.inner.tell(runtime, encode(message))
}

///|
/// Encode and send a typed request message.
pub fn[T] TypedActorRef::ask(
  self : TypedActorRef[T],
  runtime : SimRuntime,
  message : T,
  encode : (T) -> String,
  timeout_ms : Int,
) -> AskResult {
  self.inner.ask(runtime, encode(message), timeout_ms)
}

///|
/// Queue a one-way message to an actor.
pub fn SimRuntime::tell_to(
  self : SimRuntime,
  actor : ActorRef,
  payload : String,
) -> Unit {
  let envelope = Envelope::{
    from: 0,
    to: actor.id,
    payload,
    request_id: 0,
    expect_reply: false,
  }
  self.schedule_message(envelope, 0)
}

///|
/// Queue a request and a timeout, then drive the runtime until one wins.
pub fn SimRuntime::ask_to(
  self : SimRuntime,
  actor : ActorRef,
  payload : String,
  timeout_ms : Int,
) -> AskResult {
  let request_id = self.next_request_id
  self.next_request_id = request_id + 1
  let envelope = Envelope::{
    from: 0,
    to: actor.id,
    payload,
    request_id,
    expect_reply: true,
  }
  self.schedule_message(envelope, 0)
  self.schedule_timeout(request_id, actor.id, timeout_ms)
  self.run_until_request(request_id, 1024)
}

///|
/// Run queued events until the queue is empty or max_steps is reached.
pub fn SimRuntime::run_all(self : SimRuntime, max_steps : Int) -> Unit {
  let mut remaining = max_steps
  while remaining > 0 && self.events.length() > 0 {
    let event = self.take_next_event()
    self.apply_event(event)
    remaining = remaining - 1
  }
}

///|
/// Drain an actor mailbox for white-box inspection and low-level tests.
pub fn SimRuntime::take_mailbox(
  self : SimRuntime,
  actor : ActorRef,
) -> Array[Envelope] {
  let index = self.find_actor_index(actor.id)
  if index < 0 {
    []
  } else {
    let cell = self.actors[index]
    let messages = cell.mailbox
    cell.mailbox = []
    self.actors[index] = cell
    messages
  }
}

///|
/// Render a compact human-readable trace of all recorded runtime events.
pub fn SimRuntime::trace_text(self : SimRuntime) -> String {
  let mut out = ""
  let mut i = 0
  while i < self.trace.length() {
    let item = self.trace[i]
    out = out +
      "#" +
      "\{item.step}" +
      " t=" +
      "\{item.time_ms}" +
      " " +
      item.kind +
      " " +
      item.detail +
      "\n"
    i = i + 1
  }
  out
}

///|
/// Render trace text with a versioned header for replay checks.
pub fn SimRuntime::trace_archive(self : SimRuntime) -> String {
  "moonsim-trace/v1 seed=" + "\{self.seed}" + "\n" + self.trace_text()
}

///|
/// Render trace events as a valid JSON document for tools and reports.
pub fn SimRuntime::trace_json(self : SimRuntime) -> String {
  let mut out = "{\"version\":\"moonsim-trace/v1\",\"seed\":" +
    "\{self.seed}" +
    ",\"events\":["
  let mut i = 0
  while i < self.trace.length() {
    if i > 0 {
      out = out + ","
    }
    let item = self.trace[i]
    out = out +
      "{\"step\":" +
      "\{item.step}" +
      ",\"time_ms\":" +
      "\{item.time_ms}" +
      ",\"kind\":\"" +
      json_escape(item.kind) +
      "\",\"detail\":\"" +
      json_escape(item.detail) +
      "\"}"
    i = i + 1
  }
  out + "]}"
}

///|
/// Write the runtime trace to a file in archive or JSON format.
pub fn SimRuntime::write_trace_file(
  self : SimRuntime,
  path : String,
  format : TraceFormat,
) -> Unit raise @fs.IOError {
  let content = match format {
    TraceArchive => self.trace_archive()
    TraceJson => self.trace_json()
  }
  @fs.write_string_to_file(path, content)
}

///|
/// Write the runtime trace archive text to a file.
pub fn SimRuntime::write_trace_archive_file(
  self : SimRuntime,
  path : String,
) -> Unit raise @fs.IOError {
  self.write_trace_file(path, TraceArchive)
}

///|
/// Write the runtime trace JSON document to a file.
pub fn SimRuntime::write_trace_json_file(
  self : SimRuntime,
  path : String,
) -> Unit raise @fs.IOError {
  self.write_trace_file(path, TraceJson)
}

///|
/// Read a trace file as raw text for caller-selected replay handling.
pub fn read_trace_file(path : String) -> String raise @fs.IOError {
  @fs.read_file_to_string(path)
}

///|
/// Read and replay-check a text trace archive file.
pub fn replay_trace_archive_file(path : String) -> ReplayCheck raise @fs.IOError {
  replay_trace_archive(read_trace_file(path))
}

///|
/// Read and replay-check a JSON trace file.
pub fn replay_trace_json_file(path : String) -> ReplayCheck raise @fs.IOError {
  replay_trace_json(read_trace_file(path))
}

///|
/// Read and replay-check a trace file in the requested format.
pub fn replay_trace_file(
  path : String,
  format : TraceFormat,
) -> ReplayCheck raise @fs.IOError {
  match format {
    TraceArchive => replay_trace_archive_file(path)
    TraceJson => replay_trace_json_file(path)
  }
}

///|
/// Render one-line runtime metrics for CLI and demo reports.
pub fn SimRuntime::summary(self : SimRuntime) -> String {
  "seed=" +
  "\{self.seed}" +
  ", time_ms=" +
  "\{self.clock_ms}" +
  ", actors=" +
  "\{self.actors.length()}" +
  ", pending=" +
  "\{self.events.length()}" +
  ", delivered=" +
  "\{self.delivered.length()}" +
  ", replies=" +
  "\{self.replies.length()}" +
  ", trace=" +
  "\{self.trace.length()}"
}

///|
/// Drive events until a request gets a reply or its timeout fires.
fn SimRuntime::run_until_request(
  self : SimRuntime,
  request_id : Int,
  max_steps : Int,
) -> AskResult {
  let mut remaining = max_steps
  while remaining > 0 && self.events.length() > 0 {
    let event = self.take_next_event()
    match event.kind {
      Deliver(envelope) => {
        let delivered = self.apply_deliver(envelope, event.due_ms)
        if delivered {
          let reply = self.take_reply(request_id)
          match reply {
            Some(response) => {
              self.cancel_timeout(request_id)
              return AskOk(response)
            }
            None =>
              if envelope.request_id == request_id && self.is_sink(envelope.to) {
                self.cancel_timeout(request_id)
                return AskOk(envelope)
              }
          }
        }
      }
      FireTimeout(timeout_request_id, actor_id) => {
        self.advance_to(event.due_ms)
        self.record(
          "TimerFired",
          "request=" + "\{timeout_request_id}" + " actor=" + "\{actor_id}",
        )
        if timeout_request_id == request_id {
          return AskErr(Timeout)
        }
      }
    }
    remaining = remaining - 1
  }
  AskErr(Timeout)
}

///|
/// Remove a pending timeout once its request has completed.
fn SimRuntime::cancel_timeout(self : SimRuntime, request_id : Int) -> Unit {
  let kept : Array[ScheduledEvent] = []
  let mut i = 0
  while i < self.events.length() {
    let event = self.events[i]
    match event.kind {
      FireTimeout(timeout_request_id, _) =>
        if timeout_request_id != request_id {
          kept.push(event)
        }
      _ => kept.push(event)
    }
    i = i + 1
  }
  self.events = kept
}

///|
/// Schedule a virtual timeout event for a request.
fn SimRuntime::schedule_timeout(
  self : SimRuntime,
  request_id : Int,
  actor_id : Int,
  delay_ms : Int,
) -> Unit {
  let safe_delay = if delay_ms < 0 { 0 } else { delay_ms }
  let seq = self.next_seq
  self.next_seq = seq + 1
  self.events.push(ScheduledEvent::{
    due_ms: self.clock_ms + safe_delay,
    seq,
    kind: FireTimeout(request_id, actor_id),
  })
  self.record(
    "TimerScheduled",
    "request=" + "\{request_id}" + " delay_ms=" + "\{safe_delay}",
  )
}

///|
/// Apply the active fault rule before a message is queued.
fn SimRuntime::schedule_message(
  self : SimRuntime,
  envelope : Envelope,
  base_delay_ms : Int,
) -> Unit {
  let seq = self.next_seq
  self.next_seq = seq + 1
  let safe_base_delay = if base_delay_ms < 0 { 0 } else { base_delay_ms }
  match self.fault_rule {
    NoFault => self.schedule_message_raw(envelope, safe_base_delay, seq)
    DelayEvery(every, delay_ms) =>
      if every > 0 && seq % every == 0 {
        self.schedule_message_raw(envelope, safe_base_delay + delay_ms, seq)
        self.record(
          "MessageDelayed",
          message_label(envelope) + " by=" + "\{delay_ms}",
        )
      } else {
        self.schedule_message_raw(envelope, safe_base_delay, seq)
      }
    DropEvery(every) =>
      if every > 0 && seq % every == 0 {
        self.record("MessageDropped", message_label(envelope))
      } else {
        self.schedule_message_raw(envelope, safe_base_delay, seq)
      }
    Reorder => self.schedule_message_raw(envelope, safe_base_delay, seq)
  }
}

///|
/// Push a message event into the deterministic queue.
fn SimRuntime::schedule_message_raw(
  self : SimRuntime,
  envelope : Envelope,
  delay_ms : Int,
  seq : Int,
) -> Unit {
  let safe_delay = if delay_ms < 0 { 0 } else { delay_ms }
  self.events.push(ScheduledEvent::{
    due_ms: self.clock_ms + safe_delay,
    seq,
    kind: Deliver(envelope),
  })
  self.record("MessageSent", message_label(envelope))
}

///|
/// Apply a scheduled event by delivering a message or firing a timer.
fn SimRuntime::apply_event(self : SimRuntime, event : ScheduledEvent) -> Unit {
  match event.kind {
    Deliver(envelope) => {
      let _ = self.apply_deliver(envelope, event.due_ms)
    }
    FireTimeout(request_id, actor_id) => {
      self.advance_to(event.due_ms)
      self.record(
        "TimerFired",
        "request=" + "\{request_id}" + " actor=" + "\{actor_id}",
      )
    }
  }
}

///|
/// Deliver a message to an actor, then run its built-in handler if any.
fn SimRuntime::apply_deliver(
  self : SimRuntime,
  envelope : Envelope,
  due_ms : Int,
) -> Bool {
  self.advance_to(due_ms)
  let index = self.find_actor_index(envelope.to)
  if index < 0 {
    self.record("ActorMissing", message_label(envelope))
    false
  } else {
    let cell = self.actors[index]
    if !cell.alive {
      self.record("ActorStopped", message_label(envelope))
      false
    } else if cell.paused {
      self.record("MessageDelayed", message_label(envelope) + " paused")
      self.schedule_message_raw(envelope, 1, self.next_seq)
      self.next_seq = self.next_seq + 1
      false
    } else {
      cell.mailbox.push(envelope)
      self.actors[index] = cell
      self.delivered.push(envelope)
      self.record("MessageDelivered", message_label(envelope))
      self.handle_message(index, envelope)
      true
    }
  }
}

///|
/// Remove and return a generated reply for a request id.
fn SimRuntime::take_reply(self : SimRuntime, request_id : Int) -> Envelope? {
  let mut found = -1
  let mut i = 0
  while i < self.replies.length() {
    if self.replies[i].request_id == request_id {
      found = i
      break
    }
    i = i + 1
  }
  if found < 0 {
    None
  } else {
    let reply = self.replies[found].response
    let _ = self.replies.remove(found)
    Some(reply)
  }
}

///|
/// Tell whether an actor uses the mailbox-only compatibility behavior.
fn SimRuntime::is_sink(self : SimRuntime, actor_id : Int) -> Bool {
  let index = self.find_actor_index(actor_id)
  if index < 0 {
    false
  } else {
    self.actors[index].kind == Sink
  }
}

///|
/// Dispatch a delivered envelope to the selected built-in actor handler.
fn SimRuntime::handle_message(
  self : SimRuntime,
  actor_index : Int,
  envelope : Envelope,
) -> Unit {
  let cell = self.actors[actor_index]
  match cell.kind {
    Sink => ()
    Echo => self.handle_echo(cell, envelope)
    KvLeader => self.handle_kv(actor_index, envelope, "leader")
    KvFollower => self.handle_kv(actor_index, envelope, "follower")
    Scripted => self.handle_scripted(actor_index, envelope)
  }
}

///|
/// Generate a deterministic echo response for request messages.
fn SimRuntime::handle_echo(
  self : SimRuntime,
  cell : ActorCell,
  envelope : Envelope,
) -> Unit {
  if envelope.expect_reply {
    self.reply(cell, envelope, "echo:" + envelope.payload)
  }
}

///|
/// Apply simple KV commands and reply to ask requests.
fn SimRuntime::handle_kv(
  self : SimRuntime,
  actor_index : Int,
  envelope : Envelope,
  role : String,
) -> Unit {
  let parts = envelope.payload.split(" ").to_array()
  if parts.length() == 2 && parts[0] == "get" {
    let key = parts[1].to_owned()
    let cell = self.actors[actor_index]
    let response = match cell.kv.get(key) {
      Some(value) => "value " + key + " " + value
      None => "missing " + key
    }
    if envelope.expect_reply {
      self.reply(cell, envelope, response)
    }
  } else if parts.length() >= 3 && parts[0] == "put" {
    let key = parts[1].to_owned()
    let value = join_parts(parts, 2)
    let cell = self.actors[actor_index]
    cell.kv[key] = value
    self.actors[actor_index] = cell
    self.record("ActorHandled", role + " put " + key)
    if envelope.expect_reply {
      self.reply(cell, envelope, "ok put " + key)
    }
  } else if parts.length() >= 3 && parts[0] == "replicate" {
    let key = parts[1].to_owned()
    let value = join_parts(parts, 2)
    let cell = self.actors[actor_index]
    cell.kv[key] = value
    self.actors[actor_index] = cell
    self.record("ActorHandled", role + " replicate " + key)
    if envelope.expect_reply {
      self.reply(cell, envelope, "ok replicate " + key)
    }
  } else if envelope.expect_reply {
    let cell = self.actors[actor_index]
    self.reply(cell, envelope, "error unsupported " + envelope.payload)
  }
}

///|
/// Run ordered custom receive rules for a scripted actor.
fn SimRuntime::handle_scripted(
  self : SimRuntime,
  actor_index : Int,
  envelope : Envelope,
) -> Unit {
  let cell = self.actors[actor_index]
  let mut i = 0
  while i < cell.rules.length() {
    let rule = cell.rules[i]
    if handler_matches(rule.matcher, envelope.payload) {
      self.apply_handler_action(actor_index, envelope, rule.action)
      return
    }
    i = i + 1
  }
  self.record("ActorUnhandled", "scripted " + envelope.payload)
  if envelope.expect_reply {
    let latest = self.actors[actor_index]
    self.reply(latest, envelope, "error unhandled " + envelope.payload)
  }
}

///|
/// Apply a matched scripted action to actor state and optional replies.
fn SimRuntime::apply_handler_action(
  self : SimRuntime,
  actor_index : Int,
  envelope : Envelope,
  action : HandlerAction,
) -> Unit {
  match action {
    NoAction => self.record("ActorHandled", "scripted no-action")
    ReplyText(text) => {
      let cell = self.actors[actor_index]
      self.record("ActorHandled", "scripted reply")
      if envelope.expect_reply {
        self.reply(cell, envelope, text)
      }
    }
    ReplyWithPayload(prefix) => {
      let cell = self.actors[actor_index]
      self.record("ActorHandled", "scripted reply-payload")
      if envelope.expect_reply {
        self.reply(cell, envelope, prefix + envelope.payload)
      }
    }
    PutFromParts(key_index, value_start) =>
      self.apply_scripted_put(actor_index, envelope, key_index, value_start)
    GetFromParts(key_index) =>
      self.apply_scripted_get(actor_index, envelope, key_index)
  }
}

///|
/// Store a key/value pair from whitespace-separated payload parts.
fn SimRuntime::apply_scripted_put(
  self : SimRuntime,
  actor_index : Int,
  envelope : Envelope,
  key_index : Int,
  value_start : Int,
) -> Unit {
  let parts = envelope.payload.split(" ").to_array()
  if key_index >= 0 && value_start >= 0 && parts.length() > key_index &&
    parts.length() > value_start {
    let key = parts[key_index].to_owned()
    let value = join_parts(parts, value_start)
    let cell = self.actors[actor_index]
    cell.kv[key] = value
    self.actors[actor_index] = cell
    self.record("ActorHandled", "scripted put " + key)
    if envelope.expect_reply {
      self.reply(cell, envelope, "ok put " + key)
    }
  } else if envelope.expect_reply {
    let cell = self.actors[actor_index]
    self.reply(cell, envelope, "error bad-put " + envelope.payload)
  }
}

///|
/// Load a key from scripted actor state and reply with value or missing.
fn SimRuntime::apply_scripted_get(
  self : SimRuntime,
  actor_index : Int,
  envelope : Envelope,
  key_index : Int,
) -> Unit {
  let parts = envelope.payload.split(" ").to_array()
  if key_index >= 0 && parts.length() > key_index {
    let key = parts[key_index].to_owned()
    let cell = self.actors[actor_index]
    let response = match cell.kv.get(key) {
      Some(value) => "value " + key + " " + value
      None => "missing " + key
    }
    self.record("ActorHandled", "scripted get " + key)
    if envelope.expect_reply {
      self.reply(cell, envelope, response)
    }
  } else if envelope.expect_reply {
    let cell = self.actors[actor_index]
    self.reply(cell, envelope, "error bad-get " + envelope.payload)
  }
}

///|
/// Check whether a scripted rule matcher accepts a payload.
fn handler_matches(matcher : HandlerMatch, payload : String) -> Bool {
  match matcher {
    MatchAny => true
    MatchExact(text) => payload == text
    MatchPrefix(prefix) => payload.has_prefix(prefix)
  }
}

///|
/// Store a reply envelope so ask can complete without exposing internals.
fn SimRuntime::reply(
  self : SimRuntime,
  cell : ActorCell,
  request : Envelope,
  payload : String,
) -> Unit {
  let response = Envelope::{
    from: cell.id,
    to: request.from,
    payload,
    request_id: request.request_id,
    expect_reply: false,
  }
  self.replies.push(AskReply::{ request_id: request.request_id, response })
  self.record(
    "MessageReplied",
    "from=" +
    "\{cell.id}" +
    " request=" +
    "\{request.request_id}" +
    " payload=" +
    payload,
  )
}

///|
/// Join payload tokens after a command prefix into one value string.
fn join_parts(parts : Array[StringView], start : Int) -> String {
  let mut out = ""
  let mut i = start
  while i < parts.length() {
    if i > start {
      out = out + " "
    }
    out = out + parts[i].to_owned()
    i = i + 1
  }
  out
}

///|
/// Validate a trace archive header and count replayable trace events.
pub fn replay_trace_archive(archive : String) -> ReplayCheck {
  let lines = archive.split("\n").to_array()
  if lines.length() == 0 {
    ReplayCheck::{ ok: false, seed: 0, events: 0, error: "empty trace" }
  } else {
    let parsed_seed = parse_trace_header(lines[0])
    match parsed_seed {
      None =>
        ReplayCheck::{
          ok: false,
          seed: 0,
          events: 0,
          error: "missing trace header",
        }
      Some(seed) => {
        let mut events = 0
        let mut i = 1
        while i < lines.length() {
          if lines[i].has_prefix("#") {
            events = events + 1
          }
          i = i + 1
        }
        ReplayCheck::{ ok: true, seed, events, error: "" }
      }
    }
  }
}

///|
/// Validate a JSON trace document and count replayable trace events.
pub fn replay_trace_json(json : String) -> ReplayCheck {
  if !@json.valid(json) {
    ReplayCheck::{ ok: false, seed: 0, events: 0, error: "invalid json trace" }
  } else {
    match parse_json_int_field(json, "seed") {
      None =>
        ReplayCheck::{ ok: false, seed: 0, events: 0, error: "missing seed" }
      Some(seed) => {
        let events = count_json_events(json)
        ReplayCheck::{ ok: true, seed, events, error: "" }
      }
    }
  }
}

///|
/// Extract the numeric seed from a versioned trace archive header.
fn parse_trace_header(header : StringView) -> Int? {
  let prefix = "moonsim-trace/v1 seed="
  match header.strip_prefix(prefix) {
    None => None
    Some(seed_text) => Some(parse_positive_int_view(seed_text))
  }
}

///|
/// Parse a non-negative integer from ASCII digits, stopping at first non-digit.
fn parse_positive_int_view(text : StringView) -> Int {
  let mut value = 0
  let mut i = 0
  while i < text.length() {
    let code = text.unsafe_get(i).to_int()
    if code < 48 || code > 57 {
      return value
    }
    value = value * 10 + (code - 48)
    i = i + 1
  }
  value
}

///|
/// Extract an integer field from compact trace JSON generated by trace_json.
fn parse_json_int_field(json : String, field : String) -> Int? {
  let needle = "\"" + field + "\":"
  match json.find(needle) {
    None => None
    Some(start) => Some(parse_positive_int_at(json, start + needle.length()))
  }
}

///|
/// Parse a non-negative integer from a string offset after optional whitespace.
fn parse_positive_int_at(text : String, start : Int) -> Int {
  let mut value = 0
  let mut i = start
  while i < text.length() {
    let code = text.unsafe_get(i).to_int()
    if code == 32 || code == 9 || code == 10 || code == 13 {
      i = i + 1
    } else {
      break
    }
  }
  while i < text.length() {
    let code = text.unsafe_get(i).to_int()
    if code < 48 || code > 57 {
      return value
    }
    value = value * 10 + (code - 48)
    i = i + 1
  }
  value
}

///|
/// Count trace event objects in a JSON trace document.
fn count_json_events(json : String) -> Int {
  let parts = json.split("\"step\":").to_array()
  if parts.length() == 0 {
    0
  } else {
    parts.length() - 1
  }
}

///|
/// Escape trace text so it can be embedded in a JSON string value.
fn json_escape(text : String) -> String {
  let mut out = ""
  let mut i = 0
  while i < text.length() {
    let ch = text.unsafe_get(i)
    let code = ch.to_int()
    if code == 34 {
      out = out + "\\\""
    } else if code == 92 {
      out = out + "\\\\"
    } else if code == 10 {
      out = out + "\\n"
    } else if code == 13 {
      out = out + "\\r"
    } else if code == 9 {
      out = out + "\\t"
    } else {
      out = out + text[i:i + 1].to_owned()
    }
    i = i + 1
  }
  out
}

///|
/// Link a child actor id into a parent actor when the parent exists.
fn SimRuntime::attach_child(
  self : SimRuntime,
  parent_id : Int,
  child_id : Int,
) -> Unit {
  if parent_id != 0 {
    let parent_index = self.find_actor_index(parent_id)
    let child_index = self.find_actor_index(child_id)
    if parent_index >= 0 && child_index >= 0 {
      let parent = self.actors[parent_index]
      parent.children.push(child_id)
      self.actors[parent_index] = parent
      self.record(
        "ActorLinked",
        "parent=" + "\{parent_id}" + " child=" + "\{child_id}",
      )
    }
  }
}

///|
/// Stop an actor and all descendants in its supervision subtree.
fn SimRuntime::stop_actor_tree(self : SimRuntime, actor_id : Int) -> Unit {
  let index = self.find_actor_index(actor_id)
  if index >= 0 {
    let cell = self.actors[index]
    cell.alive = false
    self.actors[index] = cell
    self.record(
      "ActorStopped",
      actor_label(ActorRef::{ id: cell.id, name: cell.name }),
    )
    let children = cell.children
    let mut i = 0
    while i < children.length() {
      self.stop_actor_tree(children[i])
      i = i + 1
    }
  }
}

///|
/// Restart an actor and descendants while preserving tree metadata.
fn SimRuntime::restart_actor_tree(self : SimRuntime, actor_id : Int) -> Unit {
  let index = self.find_actor_index(actor_id)
  if index >= 0 {
    let cell = self.actors[index]
    cell.alive = true
    cell.paused = false
    cell.generation = cell.generation + 1
    cell.mailbox = []
    cell.kv = {}
    self.actors[index] = cell
    self.record(
      "ActorRestarted",
      actor_label(ActorRef::{ id: cell.id, name: cell.name }),
    )
    let children = cell.children
    let mut i = 0
    while i < children.length() {
      self.restart_actor_tree(children[i])
      i = i + 1
    }
  }
}

///|
/// Remove the next scheduled event selected by the deterministic scheduler.
fn SimRuntime::take_next_event(self : SimRuntime) -> ScheduledEvent {
  let index = self.pick_event_index()
  let chosen = self.events[index]
  let kept : Array[ScheduledEvent] = []
  let mut i = 0
  while i < self.events.length() {
    if i != index {
      kept.push(self.events[i])
    }
    i = i + 1
  }
  self.events = kept
  chosen
}

///|
/// Pick FIFO-by-time events, or seed-driven events under Reorder.
fn SimRuntime::pick_event_index(self : SimRuntime) -> Int {
  let len = self.events.length()
  if len <= 1 {
    return 0
  }
  match self.fault_rule {
    Reorder => {
      self.rng = lcg(self.rng)
      positive_mod(self.rng, len)
    }
    _ => {
      let mut best = 0
      let mut i = 1
      while i < len {
        let current = self.events[i]
        let selected = self.events[best]
        if current.due_ms < selected.due_ms ||
          (current.due_ms == selected.due_ms && current.seq < selected.seq) {
          best = i
        }
        i = i + 1
      }
      best
    }
  }
}

///|
/// Advance virtual time monotonically.
fn SimRuntime::advance_to(self : SimRuntime, due_ms : Int) -> Unit {
  if due_ms > self.clock_ms {
    self.clock_ms = due_ms
  }
}

///|
/// Locate an actor in the registry by id.
fn SimRuntime::find_actor_index(self : SimRuntime, id : Int) -> Int {
  let mut i = 0
  while i < self.actors.length() {
    if self.actors[i].id == id {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// Append a trace event at the current virtual time.
fn SimRuntime::record(
  self : SimRuntime,
  kind : String,
  detail : String,
) -> Unit {
  self.step = self.step + 1
  self.trace.push(TraceEvent::{
    step: self.step,
    time_ms: self.clock_ms,
    kind,
    detail,
  })
}

///|
/// Small deterministic PRNG step for replayable reordering.
fn lcg(value : Int) -> Int {
  value * 1103515245 + 12345
}

///|
/// Compute a non-negative modulo for PRNG indexes.
fn positive_mod(value : Int, divisor : Int) -> Int {
  if divisor <= 0 {
    0
  } else {
    let result = value % divisor
    if result < 0 {
      result + divisor
    } else {
      result
    }
  }
}

///|
/// Render a stable actor label for trace details.
fn actor_label(actor : ActorRef) -> String {
  actor.name + "#" + "\{actor.id}"
}

///|
/// Render a stable message label for trace details.
fn message_label(envelope : Envelope) -> String {
  "to=" +
  "\{envelope.to}" +
  " request=" +
  "\{envelope.request_id}" +
  " payload=" +
  envelope.payload
}
