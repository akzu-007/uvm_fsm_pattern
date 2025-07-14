While the provided sources discuss how to model Finite-State Machines (FSMs) in a verification environment using software design patterns and introduce main UVM concepts, they do not provide a complete, executable UVM sample code for a 3-state FSM. However, the sources offer detailed SystemVerilog class implementations for the FSM model itself and describe how various components (like sequences, checkers, and coverage) would fit into a UVM-based verification process.

Below, I will provide sample SystemVerilog code for a 3-state FSM using the recommended "loosely coupled" approach with the **State design pattern**, and then explain how these components are integrated within a UVM framework, drawing directly from the concepts and snippets in your sources.

### Core FSM Model using State Design Pattern (SystemVerilog)

The sources advocate for a **loosely coupled FSM implementation** using the State design pattern to create a **reusable and modifiable solution**. This approach decouples state machines from the rest of the system and provides a simple interface. For a 3-state FSM, we will define three concrete states (e.g., `InitState`, `RunState`, `IdleState`).

#### 1. Input Definition

An `Input` class is needed to carry the stimuli that trigger state transitions and potentially contain observed values. The `Input` class might include a virtual interface for driving or observing signals. For this example, we'll use an enumeration for commands.

```systemverilog
// Based on the concept that Context class is provided with observed input signals
// And concrete states might interact with input/output interfaces
class Input;
    typedef enum { CMD_START, CMD_STOP, CMD_RESET } Command_t;
    Command_t cmd;
    // virtual interface some_interface vif0; // Hypothetical, as per source
endclass
```

#### 2. FSMContext Class

The `FSMContext` class acts as the interface to the FSM model. It communicates with the rest of the verification environment and holds the `currentState`. It delegates the `doAction` call to the current state.

```systemverilog
// Loosely coupled FSM implementation Context class
class FSMContext;
    local State currentState; // Holds the current state

    function new(State initialState);
        currentState = initialState;
    endfunction

    function void setState(State s);
        currentState = s; // Allows changing the current state
    endfunction

    function void doAction(Input inputs);
        currentState.doAction(this, inputs); // Delegates action to the current state
    endfunction
endclass
```

#### 3. Abstract State Base Class

The `State` class is an abstract base class that defines **features and actions common to every state** of the state machine. It models its main behavior using the **Template method design pattern**, which includes `doSpecificSeqAction` (sequential) and `doSpecificCombAction` (combinational) pure virtual functions.

```systemverilog
// Loosely coupled FSM implementation Abstract State class
virtual class State;
    // StateId for functional coverage considerations
    typedef enum { INIT, RUN, IDLE, ERROR_STATE } StateId_t;
    virtual function StateId_t getStateId(); return ERROR_STATE; endfunction // Default, overridden by concrete states

    function void doAction(FSMContext cntxt, Input inputs);
        State nextState;
        doSpecificSeqAction(cntxt, inputs); // Perform state-specific sequential action
        nextState = StateTransitionUtil::calculate(this, inputs); // Calculate next state using Mediator
        cntxt.setState(nextState); // Update context with the new state
        nextState.doSpecificCombAction(cntxt, inputs); // Perform combinational action of the *new* state
    endfunction

    pure virtual function void doSpecificCombAction(FSMContext cntxt, Input inputs);
    pure virtual function void doSpecificSeqAction (FSMContext cntxt, Input inputs);
endclass
```

#### 4. Concrete State Classes (3 States)

Each concrete state class **defines its state-specific behavior** and is modeled using the **Singleton design pattern** to ensure only one instance of each state exists. Here are three example states for your FSM: `InitState`, `RunState`, and `IdleState`.

```systemverilog
// Concrete State classes defining state-specific behavior
// Modeled using Singleton design pattern

class InitState extends State;
    local static InitState inst = null;
    protected function new(); endfunction // Protected constructor for Singleton
    static function InitState Instance();
        if (inst == null) inst = new();
        return inst;
    endfunction
    virtual function StateId_t getStateId(); return INIT; endfunction

    virtual function void doSpecificCombAction(FSMContext cntxt, Input inputs);
        $display("[%0t] %s: Performing combinational action.", $time, getStateId().name());
        // Example: inputs.vif0.iso_expected <= 0; // As seen in source
    endfunction
    virtual function void doSpecificSeqAction (FSMContext cntxt, Input inputs);
        $display("[%0t] %s: Performing sequential action.", $time, getStateId().name());
    endfunction
endclass

class RunState extends State;
    local static RunState inst = null;
    protected function new(); endfunction
    static function RunState Instance();
        if (inst == null) inst = new();
        return inst;
    endfunction
    virtual function StateId_t getStateId(); return RUN; endfunction

    virtual function void doSpecificCombAction(FSMContext cntxt, Input inputs);
        $display("[%0t] %s: Performing combinational action.", $time, getStateId().name());
        // Example from source: inputs.vif0.iso_expected <= 0;
    endfunction
    virtual function void doSpecificSeqAction (FSMContext cntxt, Input inputs);
        $display("[%0t] %s: Performing sequential action.", $time, getStateId().name());
    endfunction
endclass

class IdleState extends State;
    local static IdleState inst = null;
    protected function new(); endfunction
    static function IdleState Instance();
        if (inst == null) inst = new();
        return inst;
    endfunction
    virtual function StateId_t getStateId(); return IDLE; endfunction

    virtual function void doSpecificCombAction(FSMContext cntxt, Input inputs);
        $display("[%0t] %s: Performing combinational action.", $time, getStateId().name());
    endfunction
    virtual function void doSpecificSeqAction (FSMContext cntxt, Input inputs);
        $display("[%0t] %s: Performing sequential action.", $time, getStateId().name());
    endfunction
endclass
```

#### 5. State Transition Logic (Mediator Design Pattern)

The `StateTransitionUtil` class handles the **state transition logic**, modeled using the **Mediator design pattern**. This approach centralizes the transition logic, providing localization, decoupling, and improved code maintainability. It calculates the `nextState` and can check whether the transition is valid.

```systemverilog
// Loosely coupled FSM implementation Mediator class
class StateTransitionUtil;
    local static State validStateTransitions[State][$]; // Map of current state to list of valid next states

    static function void init();
        // Initialize valid state transitions for our 3-state FSM
        validStateTransitions[InitState::Instance()] = { RunState::Instance() };
        validStateTransitions[RunState::Instance()] = { IdleState::Instance(), InitState::Instance() };
        validStateTransitions[IdleState::Instance()] = { RunState::Instance() };
        // Example from source: validStateTransitions[ResetState::Instance()] = { ResetState::Instance(), InitState::Instance()};
    endfunction

    static function State calculate(State currentState, Input inputs);
        State nextState = currentState; // Default: stay in current state

        // Hypothetical transition logic based on input commands
        case (currentState.getStateId())
            State::INIT: begin
                if (inputs.cmd == Input::CMD_START) nextState = RunState::Instance();
            end
            State::RUN: begin
                if (inputs.cmd == Input::CMD_STOP) nextState = IdleState::Instance();
                else if (inputs.cmd == Input::CMD_RESET) nextState = InitState::Instance();
            end
            State::IDLE: begin
                if (inputs.cmd == Input::CMD_START) nextState = RunState::Instance();
            end
        endcase

        // Check whether the transition is valid
        if (validStateTransitions.exists(currentState) && validStateTransitions[currentState].find_first(s) with (s == nextState) != null) begin
             $display("[%0t] Valid transition from %s to %s.", $time, currentState.getStateId().name(), nextState.getStateId().name());
        end else if (nextState != currentState) begin // If a transition was attempted but is not valid
             $display("[%0t] WARNING: Invalid transition attempted from %s to %s. Staying in %s.",
                      $time, currentState.getStateId().name(), nextState.getStateId().name(), currentState.getStateId().name());
             nextState = currentState; // Revert to current state if transition is invalid
        end

        return nextState;
    endfunction
endclass
```

### UVM Integration Concepts

The sources highlight how these FSM modeling elements fit into a UVM verification environment, particularly concerning **stimulus generation, checking, and coverage collection**.

#### 1. Generation Side with UVM Sequences

The generation of state transitions can be driven by a **dedicated `uvm_sequence` associated with each state transition** or by a graph traversing algorithm to generate random scenarios. These sequences can be reused across testcases.

```systemverilog
// UVM sequence for driving FSM inputs
`include "uvm_pkg.sv"
import uvm_pkg::*;

// This is a UVM sequence which would generate 'Input' items for a UVM driver
// to apply to the DUT, which in turn influences the FSM model's state.
class my_fsm_sequence extends uvm_sequence #(Input); // Assuming 'Input' is the sequence item type
    `uvm_object_utils(my_fsm_sequence)

    function new(string name = "my_fsm_sequence");
        super.new(name);
    endfunction

    virtual task body();
        Input req;

        // Example of driving inputs to achieve specific state transitions
        `uvm_create(req)
        req.cmd = Input::CMD_START;
        `uvm_send(req) // This sends the item to the sequencer, then to the driver
        $display("[%0t] Sequence: Sent CMD_START (Init -> Run).", $time);

        #10; // Add some delay for the FSM to process

        `uvm_create(req)
        req.cmd = Input::CMD_STOP;
        `uvm_send(req)
        $display("[%0t] Sequence: Sent CMD_STOP (Run -> Idle).", $time);

        #10;

        `uvm_create(req)
        req.cmd = Input::CMD_START;
        `uvm_send(req)
        $display("[%0t] Sequence: Sent CMD_START (Idle -> Run).", $time);

        #10;

        `uvm_create(req)
        req.cmd = Input::CMD_RESET;
        `uvm_send(req)
        $display("[%0t] Sequence: Sent CMD_RESET (Run -> Init).", $time);
    endtask
endclass
```

**Note:** A complete UVM testbench would include a `uvm_driver` to consume `Input` items from `my_fsm_sequence` and apply them to the Device Under Test (DUT), a `uvm_monitor` to observe the DUT's inputs and outputs, and a `uvm_agent`, `uvm_env`, and `uvm_test` to orchestrate these components. The `FSMContext` instance would typically reside in the `uvm_env` or a dedicated FSM reference model component, and its `doAction` method would be called by the monitor based on observed inputs from the DUT. The sources do not provide full UVM testbench boilerplate code but focus on the FSM modeling and verification aspects.

#### 2. Checkers Implementation

The sources demonstrate using **SystemVerilog `property` assertions** to check that the FSM's output signals are properly driven. This involves comparing observed outputs from the DUT against expected outputs from the FSM reference model.

```systemverilog
// Checkers implementation - these would typically be in an interface or clocking block
// associated with the DUT and monitored by the UVM environment.
logic iso_observed, iso_expected;
logic clkg_observed, clkg_expected; // Example signals from source

// Property to check observed vs. expected ISO signal
property iso;
    @(posedge clock) iso_observed == iso_expected;
endproperty
// assert property (iso); // This would be asserted in a module/interface connected to the DUT

// Property to check observed vs. expected clock gating signal
property clkg;
    @(posedge clock) clkg_observed == clkg_expected;
endproperty
// assert property (clkg);
```
**Explanation:** In a UVM environment, the `iso_expected` and `clkg_expected` signals would be driven by the `FSMContext` instance within the reference model based on the FSM's current state and actions, while `iso_observed` and `clkg_observed` would come from the DUT via a monitor.

#### 3. Functional Coverage Considerations

Functional coverage is collected on states, state transitions, and higher-level scenarios. The sources provide `covergroup` examples for `currentStateId`, `nextStateId`, and `cross` coverage.

```systemverilog
// Functional coverage considerations
// This covergroup would be instantiated in a UVM monitor or environment component
// that has access to the FSMContext's current and next state IDs.
covergroup state_cg(State::StateId_t currentStateId, State::StateId_t nextStateId);
    // Coverpoint for current state
    coverpoint currentStateId {
        ignore_bins ignore_val = { State::ERROR_STATE }; // Ignore error state for coverage
    }

    // Coverpoint for next state
    coverpoint nextStateId {
        ignore_bins ignore_val = { State::ERROR_STATE }; // Ignore error state for coverage
    }

    // Cross coverage for state transitions
    cross currentStateId, nextStateId {
        // Example of ignoring specific transition bins
        // You would define actual valid transitions here, or ignore invalid ones.
        ignore_bins init_to_invalid = binsof(currentStateId) intersect {State::INIT} &&
                                      !binsof(nextStateId) intersect {State::RUN};
        ignore_bins run_to_invalid = binsof(currentStateId) intersect {State::RUN} &&
                                     !binsof(nextStateId) intersect {State::IDLE, State::INIT};
        ignore_bins idle_to_invalid = binsof(currentStateId) intersect {State::IDLE} &&
                                      !binsof(nextStateId) intersect {State::RUN};
    }
endgroup
```
**Explanation:** An instance of this `covergroup` would be created, for example, in a UVM monitor or environment, and its `sample()` method would be called whenever the FSM's state changes, passing the current and next state IDs from the FSM reference model.

### Summary of UVM Integration

The provided solution is beneficial for both the active (generation) and passive (checking and coverage collection) sides of verification. It improves code quality and offers a more scalable solution compared to other common approaches like large "case enum" statements.

To summarize, while the direct "UVM sample code" for a complete testbench is not provided, the sources furnish the essential SystemVerilog building blocks for the FSM reference model using robust design patterns, along with clear conceptual guidance on how these models, sequences, checkers, and functional coverage elements are integrated into a UVM verification flow.

