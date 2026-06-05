///|
test "tell delivers messages into mailbox in FIFO order without faults" {
  let sim = SimRuntime::new(1)
  let worker = sim.spawn("worker")
  worker.tell(sim, "one")
  worker.tell(sim, "two")
  sim.run_all(16)
  let inbox = sim.take_mailbox(worker)
  assert_eq(inbox.length(), 2)
  assert_eq(inbox[0].payload, "one")
  assert_eq(inbox[1].payload, "two")
}

///|
test "ask returns delivered envelope before timeout" {
  let sim = SimRuntime::new(2)
  let worker = sim.spawn("worker")
  let result = worker.ask(sim, "ping", 10)
  assert_eq(ask_result_text(result), "ok(ping)")
}

///|
test "virtual timeout wins when fault delays the request" {
  let sim = SimRuntime::new(3)
  sim.set_fault(DelayEvery(1, 20))
  let worker = sim.spawn("worker")
  let result = worker.ask(sim, "slow", 5)
  assert_eq(ask_result_text(result), "err(timeout)")
  assert_eq(sim.now(), 5)
}

///|
test "drop fault keeps delivery out of mailbox" {
  let sim = SimRuntime::new(4)
  sim.set_fault(DropEvery(1))
  let worker = sim.spawn("worker")
  worker.tell(sim, "lost")
  sim.run_all(8)
  let inbox = sim.take_mailbox(worker)
  assert_eq(inbox.length(), 0)
}

///|
test "same seed produces same reordered trace" {
  let left = SimRuntime::new(42)
  let right = SimRuntime::new(42)
  left.set_fault(Reorder)
  right.set_fault(Reorder)
  let left_actor = left.spawn("worker")
  let right_actor = right.spawn("worker")
  left_actor.tell(left, "a")
  left_actor.tell(left, "b")
  left_actor.tell(left, "c")
  right_actor.tell(right, "a")
  right_actor.tell(right, "b")
  right_actor.tell(right, "c")
  left.run_all(16)
  right.run_all(16)
  assert_eq(left.trace_text(), right.trace_text())
}

///|
test "restart clears mailbox and increments generation" {
  let sim = SimRuntime::new(5)
  let worker = sim.spawn("worker")
  worker.tell(sim, "before")
  sim.run_all(8)
  sim.supervise(worker, Restart)
  let inbox = sim.take_mailbox(worker)
  assert_eq(inbox.length(), 0)
  assert_eq(sim.actors[0].generation, 1)
}
