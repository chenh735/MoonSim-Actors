///|
test "supervision tree links parent and child" {
  let sim = SimRuntime::new(31)
  let supervisor = sim.spawn_actor("supervisor", Echo)
  let worker = sim.spawn_child(supervisor, "worker", Echo)
  let children = sim.children_of(supervisor)
  assert_eq(children.length(), 1)
  assert_eq(children[0].id, worker.id)
  assert_eq(children[0].name, worker.name)
  match sim.parent_of(worker) {
    Some(parent) => {
      assert_eq(parent.id, supervisor.id)
      assert_eq(parent.name, supervisor.name)
    }
    None => fail("expected parent")
  }
}

///|
test "stopping a supervisor stops descendants" {
  let sim = SimRuntime::new(32)
  let supervisor = sim.spawn_actor("supervisor", Echo)
  let _worker = sim.spawn_child(supervisor, "worker", Echo)
  sim.stop(supervisor)
  assert_false(sim.actors[0].alive)
  assert_false(sim.actors[1].alive)
}

///|
test "restart limit stops actor after allowed restart is consumed" {
  let sim = SimRuntime::new(33)
  let worker = sim.spawn_actor("worker", Echo)
  sim.supervise_with_limit(worker, Restart, 1)
  assert_true(sim.actors[0].alive)
  assert_eq(sim.actors[0].generation, 1)
  assert_eq(sim.actors[0].restart_count, 1)
  sim.supervise_with_limit(worker, Restart, 1)
  assert_false(sim.actors[0].alive)
  assert_true(sim.trace_text().contains("RestartLimitExceeded"))
}
