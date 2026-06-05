///|
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
    fault_rule: NoFault,
  }
}

///|
pub fn SimRuntime::set_fault(self : SimRuntime, rule : FaultRule) -> Unit {
  self.fault_rule = rule
}

///|
pub fn SimRuntime::now(self : SimRuntime) -> Int {
  self.clock_ms
}

///|
pub fn SimRuntime::spawn(self : SimRuntime, name : String) -> ActorRef {
  let id = self.next_actor_id
  self.next_actor_id = id + 1
  let cell = ActorCell::{
    id,
    name,
    alive: true,
    paused: false,
    generation: 0,
    mailbox: [],
  }
  self.actors.push(cell)
  let actor = ActorRef::{ id, name }
  self.record("ActorSpawned", actor_label(actor))
  actor
}

///|
pub fn SimRuntime::stop(self : SimRuntime, actor : ActorRef) -> Unit {
  let index = self.find_actor_index(actor.id)
  if index >= 0 {
    let cell = self.actors[index]
    cell.alive = false
    self.actors[index] = cell
    self.record("ActorStopped", actor_label(actor))
  }
}

///|
pub fn SimRuntime::restart(self : SimRuntime, actor : ActorRef) -> Unit {
  let index = self.find_actor_index(actor.id)
  if index >= 0 {
    let cell = self.actors[index]
    cell.alive = true
    cell.paused = false
    cell.generation = cell.generation + 1
    cell.mailbox = []
    self.actors[index] = cell
    self.record("ActorRestarted", actor_label(actor))
  }
}

///|
pub fn SimRuntime::supervise(
  self : SimRuntime,
  actor : ActorRef,
  strategy : SupervisionStrategy,
) -> Unit {
  self.record("ActorFailed", actor_label(actor))
  match strategy {
    Stop => self.stop(actor)
    Restart => self.restart(actor)
  }
}

///|
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
pub fn ActorRef::tell(
  self : ActorRef,
  runtime : SimRuntime,
  payload : String,
) -> Unit {
  runtime.tell_to(self, payload)
}

///|
pub fn ActorRef::ask(
  self : ActorRef,
  runtime : SimRuntime,
  payload : String,
  timeout_ms : Int,
) -> AskResult {
  runtime.ask_to(self, payload, timeout_ms)
}

///|
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
pub fn SimRuntime::run_all(self : SimRuntime, max_steps : Int) -> Unit {
  let mut remaining = max_steps
  while remaining > 0 && self.events.length() > 0 {
    let event = self.take_next_event()
    self.apply_event(event)
    remaining = remaining - 1
  }
}

///|
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
  ", trace=" +
  "\{self.trace.length()}"
}

///|
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
        if envelope.request_id == request_id && delivered {
          self.cancel_timeout(request_id)
          return AskOk(envelope)
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
      true
    }
  }
}

///|
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
fn SimRuntime::advance_to(self : SimRuntime, due_ms : Int) -> Unit {
  if due_ms > self.clock_ms {
    self.clock_ms = due_ms
  }
}

///|
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
fn lcg(value : Int) -> Int {
  value * 1103515245 + 12345
}

///|
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
fn actor_label(actor : ActorRef) -> String {
  actor.name + "#" + "\{actor.id}"
}

///|
fn message_label(envelope : Envelope) -> String {
  "to=" +
  "\{envelope.to}" +
  " request=" +
  "\{envelope.request_id}" +
  " payload=" +
  envelope.payload
}
