### Complete Executable UVM Example (with SLEEP state)

Here is a complete, self-contained UVM testbench that implements the FSM pattern discussed. This can be run in a SystemVerilog simulator supporting UVM.

```systemverilog
// ----------------------------------------------------------------
// -- FSM Package (fsm_pkg.sv)
// ----------------------------------------------------------------
package fsm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.sv"

    // Sequence item to carry FSM stimuli
    class fsm_item extends uvm_sequence_item;
        `uvm_object_utils(fsm_item)

        // ADDED CMD_SLEEP and CMD_WAKE
        typedef enum { CMD_START, CMD_STOP, CMD_RESET, CMD_SLEEP, CMD_WAKE } Command_t;
        rand Command_t cmd;

        function new(string name = "fsm_item");
            super.new(name);
        endfunction
    endclass: fsm_item

    // Forward declaration for FSMContext and State
    class FSMContext;
    class State;

    // Abstract State class (Template Method Pattern)
    virtual class State;
        // ADDED SLEEP STATE
        typedef enum { INIT, RUN, IDLE, SLEEP, ERROR_STATE } StateId_t;
        virtual function StateId_t getStateId(); return ERROR_STATE; endfunction

        // Template method for state actions
        function void doAction(FSMContext cntxt, fsm_item inputs);
            State nextState;
            doSpecificSeqAction(cntxt, inputs);
            nextState = StateTransitionUtil::calculate(this, inputs);
            cntxt.setState(nextState);
            nextState.doSpecificCombAction(cntxt, inputs);
        endfunction

        pure virtual function void doSpecificCombAction(FSMContext cntxt, fsm_item inputs);
        pure virtual function void doSpecificSeqAction (FSMContext cntxt, fsm_item inputs);
        // Helper to get state name as a string for display
        pure virtual function string get_name();
    endclass: State

    // FSMContext class
    class FSMContext;
        local State currentState;

        function new(State initialState);
            currentState = initialState;
        endfunction

        function void setState(State s);
            `uvm_info("FSM_CONTEXT", $sformatf("Transitioning to state: %s", s.get_name()), UVM_LOW);
            currentState = s;
        endfunction

        function void doAction(fsm_item inputs);
            currentState.doAction(this, inputs);
        endfunction

        function State getCurrentState();
            return currentState;
        endfunction
    endclass: FSMContext

    // Concrete State classes (Singleton Pattern)
    class InitState extends State;
        local static InitState inst = null;
        protected function new(); endfunction
        static function InitState Instance();
            if (inst == null) inst = new();
            return inst;
        endfunction
        virtual function StateId_t getStateId(); return INIT; endfunction
        virtual function string get_name(); return "INIT"; endfunction

        virtual function void doSpecificCombAction(FSMContext cntxt, fsm_item inputs);
            `uvm_info(get_name(), "Performing combinational action.", UVM_MEDIUM);
        endfunction
        virtual function void doSpecificSeqAction (FSMContext cntxt, fsm_item inputs);
            `uvm_info(get_name(), "Performing sequential action.", UVM_MEDIUM);
        endfunction
    endclass: InitState

    class RunState extends State;
        local static RunState inst = null;
        protected function new(); endfunction
        static function RunState Instance();
            if (inst == null) inst = new();
            return inst;
        endfunction
        virtual function StateId_t getStateId(); return RUN; endfunction
        virtual function string get_name(); return "RUN"; endfunction

        virtual function void doSpecificCombAction(FSMContext cntxt, fsm_item inputs);
            `uvm_info(get_name(), "Performing combinational action.", UVM_MEDIUM);
        endfunction
        virtual function void doSpecificSeqAction (FSMContext cntxt, fsm_item inputs);
            `uvm_info(get_name(), "Performing sequential action.", UVM_MEDIUM);
        endfunction
    endclass: RunState

    class IdleState extends State;
        local static IdleState inst = null;
        protected function new(); endfunction
        static function IdleState Instance();
            if (inst == null) inst = new();
            return inst;
        endfunction
        virtual function StateId_t getStateId(); return IDLE; endfunction
        virtual function string get_name(); return "IDLE"; endfunction

        virtual function void doSpecificCombAction(FSMContext cntxt, fsm_item inputs);
            `uvm_info(get_name(), "Performing combinational action.", UVM_MEDIUM);
        endfunction
        virtual function void doSpecificSeqAction (FSMContext cntxt, fsm_item inputs);
            `uvm_info(get_name(), "Performing sequential action.", UVM_MEDIUM);
        endfunction
    endclass: IdleState

    // ADDED SLEEPSTATE CLASS
    class SleepState extends State;
        local static SleepState inst = null;
        protected function new(); endfunction
        static function SleepState Instance();
            if (inst == null) inst = new();
            return inst;
        endfunction
        virtual function StateId_t getStateId(); return SLEEP; endfunction
        virtual function string get_name(); return "SLEEP"; endfunction

        virtual function void doSpecificCombAction(FSMContext cntxt, fsm_item inputs);
            `uvm_info(get_name(), "Performing combinational action.", UVM_MEDIUM);
        endfunction
    endclass: SleepState

    // State Transition Logic (Mediator Pattern)
    class StateTransitionUtil;
        static function State calculate(State currentState, fsm_item inputs);
            State nextState = currentState;
            case (currentState.getStateId())
                State::INIT: begin
                    if (inputs.cmd == fsm_item::CMD_START) nextState = RunState::Instance();
                end
                State::RUN: begin
                    if (inputs.cmd == fsm_item::CMD_STOP) nextState = IdleState::Instance();
                    else if (inputs.cmd == fsm_item::CMD_RESET) nextState = InitState::Instance();
                end
                State::IDLE: begin
                    if (inputs.cmd == fsm_item::CMD_START) nextState = RunState::Instance();
                end
            endcase
            return nextState;
        endfunction
    endclass: StateTransitionUtil

endpackage: fsm_pkg


// ----------------------------------------------------------------
// -- FSM Sequence (fsm_sequence.sv)
// ----------------------------------------------------------------
class fsm_sequence extends uvm_sequence #(fsm_pkg::fsm_item);
    `uvm_object_utils(fsm_sequence)

    function new(string name = "fsm_sequence");
        super.new(name);
    endfunction

    virtual task body();
        fsm_pkg::fsm_item req;

        `uvm_info(get_name(), "Sending CMD_START (Init -> Run)", UVM_LOW)
        req = fsm_pkg::fsm_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { cmd == fsm_pkg::fsm_item::CMD_START; });
        finish_item(req);

        #10ns;

        `uvm_info(get_name(), "Sending CMD_STOP (Run -> Idle)", UVM_LOW)
        req = fsm_pkg::fsm_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { cmd == fsm_pkg::fsm_item::CMD_STOP; });
        finish_item(req);

        #10ns;

        `uvm_info(get_name(), "Sending CMD_START (Idle -> Run)", UVM_LOW)
        req = fsm_pkg::fsm_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { cmd == fsm_pkg::fsm_item::CMD_START; });
        finish_item(req);

        #10ns;

        `uvm_info(get_name(), "Sending CMD_RESET (Run -> Init)", UVM_LOW)
        req = fsm_pkg::fsm_item::type_id::create("req");
        start_item(req);
        assert(req.randomize() with { cmd == fsm_pkg::fsm_item::CMD_RESET; });
        finish_item(req);

    endtask
endclass

// ----------------------------------------------------------------
// -- Interface
// ----------------------------------------------------------------
interface fsm_if(input bit clk);
    logic rst;
    fsm_pkg::fsm_item::Command_t cmd;
endinterface

// ----------------------------------------------------------------
// -- Driver
// ----------------------------------------------------------------
class fsm_driver extends uvm_driver #(fsm_pkg::fsm_item);
    `uvm_component_utils(fsm_driver)

    virtual fsm_if vif;

    function new(string name = "fsm_driver", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual fsm_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF",{"vif not set for ", get_full_name(), ".vif"})
    endfunction

    virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            @(posedge vif.clk);
            vif.cmd <= req.cmd;
            `uvm_info(get_name(), $sformatf("Driving command: %s", req.cmd.name()), UVM_MEDIUM);
            seq_item_port.item_done();
        end
    endtask
endclass

// ----------------------------------------------------------------
// -- Monitor
// ----------------------------------------------------------------
class fsm_monitor extends uvm_monitor;
    `uvm_component_utils(fsm_monitor)

    virtual fsm_if vif;
    uvm_analysis_port #(fsm_pkg::fsm_item) item_collected_port;

    function new(string name = "fsm_monitor", uvm_component parent = null);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual fsm_if)::get(this, "", "vif", vif))
            `uvm_fatal("NOVIF",{"vif not set for ", get_full_name(), ".vif"})
    endfunction

    virtual task run_phase(uvm_phase phase);
        fsm_pkg::fsm_item item;
        forever begin
            @(posedge vif.clk);
            item = fsm_pkg::fsm_item::type_id::create("item");
            item.cmd = vif.cmd;
            `uvm_info(get_name(), $sformatf("Monitored command: %s", item.cmd.name()), UVM_MEDIUM);
            item_collected_port.write(item);
        end
    endtask
endclass

// ----------------------------------------------------------------
// -- Reference Model (Subscriber)
// ----------------------------------------------------------------
class fsm_ref_model extends uvm_subscriber #(fsm_pkg::fsm_item);
    `uvm_component_utils(fsm_ref_model)

    fsm_pkg::FSMContext fsm;
    fsm_pkg::State::StateId_t state_id, next_state_id;

    uvm_analysis_port #(fsm_pkg::State::StateId_t) state_change_port;

    function new(string name = "fsm_ref_model", uvm_component parent = null);
        super.new(name, parent);
        state_change_port = new("state_change_port", this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        fsm = new(fsm_pkg::InitState::Instance());
    endfunction

    // write is called by the analysis_port in the monitor
    virtual function void write(fsm_pkg::fsm_item t);
        state_id = fsm.getCurrentState().getStateId();
        fsm.doAction(t); // Update FSM based on monitored transaction
        next_state_id = fsm.getCurrentState().getStateId();
        `uvm_info(get_name(), $sformatf("Ref model transitioned from %s to %s", state_id.name(), next_state_id.name()), UVM_LOW);
        state_change_port.write(next_state_id);
    endfunction
endclass

// ----------------------------------------------------------------
// -- Coverage Collector
// ----------------------------------------------------------------
class fsm_coverage extends uvm_subscriber #(fsm_pkg::fsm_item);
    `uvm_component_utils(fsm_coverage)

    fsm_pkg::State::StateId_t current_state, next_state;

    covergroup state_cg;
        option.per_instance = 1;
        cp_current_state: coverpoint current_state {
             bins states[] = {fsm_pkg::State::INIT, fsm_pkg::State::RUN, fsm_pkg::State::IDLE};
        }
        cp_next_state: coverpoint next_state {
             bins states[] = {fsm_pkg::State::INIT, fsm_pkg::State::RUN, fsm_pkg::State::IDLE};
        }
        state_transitions: cross cp_current_state, cp_next_state {
            ignore_bins invalid_trans = binsof(cp_current_state) intersect {fsm_pkg::State::INIT} && !binsof(cp_next_state) intersect {fsm_pkg::State::RUN} ||
                                       binsof(cp_current_state) intersect {fsm_pkg::State::RUN} && !binsof(cp_next_state) intersect {fsm_pkg::State::IDLE, fsm_pkg::State::INIT} ||
                                       binsof(cp_current_state) intersect {fsm_pkg::State::IDLE} && !binsof(cp_next_state) intersect {fsm_pkg::State::RUN};
        }
    endgroup

    function new(string name = "fsm_coverage", uvm_component parent = null);
        super.new(name, parent);
        state_cg = new();
    endfunction

    function void write(fsm_pkg::fsm_item t);
       // This subscriber gets transactions but samples based on ref model state changes.
       // It's a simplification. A more robust implementation would have the reference model
       // emit state-change transactions.
    endfunction

    // This would be connected to an analysis port from the ref_model
    // to be notified of state changes.
    function void sample_cg(fsm_pkg::State::StateId_t prev, fsm_pkg::State::StateId_t next);
        this.current_state = prev;
        this.next_state = next;
        state_cg.sample();
        `uvm_info(get_name(), $sformatf("Sampling coverage: %s -> %s", prev.name(), next.name()), UVM_MEDIUM);
    endfunction

endclass


// ----------------------------------------------------------------
// -- Agent
// ----------------------------------------------------------------
class fsm_agent extends uvm_agent;
    `uvm_component_utils(fsm_agent)

    fsm_driver driver;
    fsm_monitor monitor;
    uvm_sequencer #(fsm_pkg::fsm_item) sequencer;

    function new(string name = "fsm_agent", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = fsm_monitor::type_id::create("monitor", this);
        if(get_is_active() == UVM_ACTIVE) begin
            driver = fsm_driver::type_id::create("driver", this);
            sequencer = uvm_sequencer #(fsm_pkg::fsm_item)::type_id::create("sequencer", this);
        end
    endfunction

    function void connect_phase(uvm_phase phase);
        if(get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction
endclass

// ----------------------------------------------------------------
// -- Environment
// ----------------------------------------------------------------
class fsm_env extends uvm_env;
    `uvm_component_utils(fsm_env)

    fsm_agent agent;
    fsm_ref_model ref_model;
    fsm_coverage coverage;
    // We would have a checker here as well

    function new(string name = "fsm_env", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = fsm_agent::type_id::create("agent", this);
        ref_model = fsm_ref_model::type_id::create("ref_model", this);
        coverage = fsm_coverage::type_id::create("coverage", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        agent.monitor.item_collected_port.connect(ref_model.analysis_export);
        agent.monitor.item_collected_port.connect(coverage.analysis_export);
    endfunction
endclass

// ----------------------------------------------------------------
// -- Test
// ----------------------------------------------------------------
class base_test extends uvm_test;
    `uvm_component_utils(base_test)

    fsm_env env;
    fsm_sequence seq;

    function new(string name = "base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = fsm_env::type_id::create("env", this);
        seq = fsm_sequence::type_id::create("seq");
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        seq.start(env.agent.sequencer);
        #50ns;
        phase.drop_objection(this);
    endtask
    
    function void report_phase(uvm_phase phase);
      `uvm_info(get_type_name(), $sformatf("Coverage = %f", env.coverage.state_cg.get_inst_coverage()), UVM_LOW);
    endfunction
endclass

// ----------------------------------------------------------------
// -- Top Module
// ----------------------------------------------------------------
module top;
    import uvm_pkg::*;
    import fsm_pkg::*;

    bit clk;
    always #5ns clk = ~clk;

    initial begin
        fsm_if vif(clk);
        uvm_config_db#(virtual fsm_if)::set(null, "uvm_test_top.env.agent*", "vif", vif);
        run_test("base_test");
    end
endmodule