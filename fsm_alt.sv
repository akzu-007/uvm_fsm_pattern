`include "uvm_macros.svh"
import uvm_pkg::*;

// Forward typedef for the context class, which is our main FSM class.
class fsm_model;

//---------------------------------------------------------------
// State class
//---------------------------------------------------------------
// This is the base class for all states in our FSM.
// It's a uvm_object so states can be created by the UVM factory.
class state_class extends uvm_object;

  string prev_state;

  function new(string name = "state_class");
    super.new(name);
  endfunction

  `uvm_object_utils(state_class)

  // This virtual task defines the action of a state. It must be
  // implemented by each concrete state.
  virtual task do_action(fsm_model ctx);
    `uvm_fatal("STATE_CLASS", "do_action must be overridden in a concrete state")
  endtask

endclass

//---------------------------------------------------------------
// Base class - The FSM itself
//---------------------------------------------------------------
// This class holds the FSM logic and the current state.
// It's a uvm_component so it can participate in the UVM phasing.
class fsm_model extends uvm_component;

  // Handle to the current state object
  state_class state_cls;

  `uvm_component_utils(fsm_model)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // The build_phase is used to construct components. Here we set up
  // the initial state of the FSM.
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // We must register the state types with the factory so it knows how to build them.
    factory.set_type_override_by_type(state_class::get_type(), init_state::get_type());
    // Create the initial state object.
    $cast(state_cls, factory.create_object_by_name("init_state", get_full_name(), "state_cls"));
    state_cls.prev_state = "NONE";
  endfunction

  // Changes the current state of the FSM by creating a new state object.
  virtual function void set_fsm_state(string state_name, string prev_state_name);
    `uvm_info("FSM", $sformatf("Transitioning from %s to %s", state_cls.get_type_name(), state_name), UVM_MEDIUM)
    $cast(state_cls, factory.create_object_by_name(state_name, get_full_name(), "state_cls"));
    if (state_cls == null) begin
      `uvm_fatal("FSM_STATE_CHANGE", $sformatf("Failed to create state: %s", state_name))
    end
    state_cls.prev_state = prev_state_name;
  endfunction

  // The run_phase is where the main behavior of the component is executed.
  task run_phase(uvm_phase phase);
    run_fsm();
  endtask

  // This task contains the main loop that drives the FSM.
  task run_fsm();
    forever begin
      state_cls.do_action(this);
    end
  endtask

endclass

//---------------------------------------------------------------
// Concrete State Implementations
//---------------------------------------------------------------

// The first state of the FSM.
class init_state extends state_class;
  `uvm_object_utils(init_state)

  function new(string name = "init_state");
    super.new(name);
  endfunction

  virtual task do_action(fsm_model ctx);
    `uvm_info(get_type_name(), "Executing init state.", UVM_MEDIUM);
    #10;
    ctx.set_fsm_state("idle_state", get_type_name());
  endtask
endclass

// A state where the FSM is waiting for some condition.
class idle_state extends state_class;
  `uvm_object_utils(idle_state)

  function new(string name = "idle_state");
    super.new(name);
  endfunction

  virtual task do_action(fsm_model ctx);
    `uvm_info(get_type_name(), "Executing idle state, waiting...", UVM_MEDIUM);
    #20;
    // Randomly transition to one of two states
    if ($urandom_range(0,1)) begin
        ctx.set_fsm_state("proc_state_a", get_type_name());
    end else begin
        ctx.set_fsm_state("proc_state_b", get_type_name());
    end
  endtask
endclass

// An example processing state.
class proc_state_a extends state_class;
  `uvm_object_utils(proc_state_a)

  function new(string name = "proc_state_a");
    super.new(name);
  endfunction

  virtual task do_action(fsm_model ctx);
    `uvm_info(get_type_name(), "Executing processing state A.", UVM_MEDIUM);
    #10;
    ctx.set_fsm_state("idle_state", get_type_name());
  endtask
endclass

// Another example processing state.
class proc_state_b extends state_class;
  `uvm_object_utils(proc_state_b)

  function new(string name = "proc_state_b");
    super.new(name);
  endfunction

  virtual task do_action(fsm_model ctx);
    `uvm_info(get_type_name(), "Executing processing state B.", UVM_MEDIUM);
    #10;
    ctx.set_fsm_state("end_state", get_type_name());
  endtask
endclass

// The final state, which will end the simulation.
class end_state extends state_class;
  `uvm_object_utils(end_state)

  function new(string name = "end_state");
    super.new(name);
  endfunction

  virtual task do_action(fsm_model ctx);
    `uvm_info(get_type_name(), "Executing end state. Simulation will finish.", UVM_MEDIUM);
    #50;
    uvm_root::get().stop_request();
  endtask
endclass

//---------------------------------------------------------------
// UVM Test and Top Module
//---------------------------------------------------------------

// A simple test to instantiate and run our FSM component.
class fsm_test extends uvm_test;
  `uvm_component_utils(fsm_test)

  fsm_model fsm;

  function new(string name = "fsm_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    // Before creating any states, we must register all concrete state
    // classes with the factory. This allows them to be created by name.
    init_state::type_id::create("init_state", this);
    idle_state::type_id::create("idle_state", this);
    proc_state_a::type_id::create("proc_state_a", this);
    proc_state_b::type_id::create("proc_state_b", this);
    end_state::type_id::create("end_state", this);

    fsm = fsm_model::type_id::create("fsm", this);
  endfunction

  task run_phase(uvm_phase phase);
     // We raise an objection to prevent the simulation from ending prematurely.
     // The FSM's end_state will eventually drop the objection via stop_request().
     phase.raise_objection(this);
     #200;
     `uvm_info(get_type_name(), "Timeout reached, ending test.", UVM_MEDIUM)
     phase.drop_objection(this);
  endtask
endclass

// The top-level module that kicks off the UVM test.
module top;
  initial begin
    run_test("fsm_test");
  end
endmodule
  
