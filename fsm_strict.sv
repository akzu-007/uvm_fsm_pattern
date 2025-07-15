// ----------------------------------------------------------------
// strict_fsm.sv
//
// An example of a "Tightly Coupled" FSM using the State Design Pattern.
// In this pattern, each state is responsible for its own transition logic,
// creating dependencies between concrete state classes. This is in contrast
// to using a Mediator, which decouples the states from each other.
// ----------------------------------------------------------------

// ----------------------------------------------------------------
// -- Tightly Coupled FSM Package
// ----------------------------------------------------------------
package strict_fsm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.sv"

    // Sequence item to carry FSM stimuli
    class fsm_item extends uvm_sequence_item;
        `uvm_object_utils(fsm_item)

        typedef enum { CMD_START, CMD_STOP, CMD_RESET } Command_t;
        rand Command_t cmd;

        function new(string name = "fsm_item");
            super.new(name);
        endfunction
    endclass: fsm_item

    // Forward declaration for FSMContext and State
    typedef class FSMContext;
    typedef class State;

    // Abstract State class (Template Method Pattern)
    virtual class State;
        typedef enum { INIT, RUN, IDLE, ERROR_STATE } StateId_t;
        virtual function StateId_t getStateId(); return ERROR_STATE; endfunction

        // This function now determines the next state internally
        pure virtual function State calculateNextState(fsm_item inputs);

        // Template method for state actions
        function void doAction(FSMContext cntxt, fsm_item inputs);
            State nextState;
            doSpecificSeqAction(cntxt, inputs);
            nextState = this.calculateNextState(inputs); // Call internal method
            cntxt.setState(nextState);
            nextState.doSpecificCombAction(cntxt, inputs);
        endfunction

        pure virtual function void doSpecificCombAction(FSMContext cntxt, fsm_item inputs);
        pure virtual function void doSpecificSeqAction (FSMContext cntxt, fsm_item inputs);
        pure virtual function string get_name();
    endclass: State

    // FSMContext class (largely unchanged)
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

    // Forward declarations for concrete states to resolve circular dependencies
    typedef class InitState;
    typedef class RunState;
    typedef class IdleState;

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

        // --- TIGHTLY COUPLED TRANSITION LOGIC ---
        virtual function State calculateNextState(fsm_item inputs);
            if (inputs.cmd == fsm_item::CMD_START) begin
                return RunState::Instance(); // Knows about RunState
            end
            return this; // Default: stay in the current state
        endfunction

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

        // --- TIGHTLY COUPLED TRANSITION LOGIC ---
        virtual function State calculateNextState(fsm_item inputs);
            if (inputs.cmd == fsm_item::CMD_STOP)
                return IdleState::Instance(); // Knows about IdleState
            else if (inputs.cmd == fsm_item::CMD_RESET)
                return InitState::Instance(); // Knows about InitState
            return this;
        endfunction

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

        // --- TIGHTLY COUPLED TRANSITION LOGIC ---
        virtual function State calculateNextState(fsm_item inputs);
            if (inputs.cmd == fsm_item::CMD_START)
                return RunState::Instance(); // Knows about RunState
            return this;
        endfunction

        virtual function void doSpecificCombAction(FSMContext cntxt, fsm_item inputs);
            `uvm_info(get_name(), "Performing combinational action.", UVM_MEDIUM);
        endfunction
        virtual function void doSpecificSeqAction (FSMContext cntxt, fsm_item inputs);
            `uvm_info(get_name(), "Performing sequential action.", UVM_MEDIUM);
        endfunction
    endclass: IdleState

endpackage: strict_fsm_pkg

// Import UVM package to the global scope
import uvm_pkg::*;
`include "uvm_macros.sv"

// ----------------------------------------------------------------
// -- UVM Components (Sequence, Driver, Monitor, etc.)
// -- These are adapted to use the strict_fsm_pkg
// ----------------------------------------------------------------

class strict_fsm_sequence extends uvm_sequence #(strict_fsm_pkg::fsm_item);
    `uvm_object_utils(strict_fsm_sequence)

    function new(string name = "strict_fsm_sequence");
        super.new(name);
    endfunction

    virtual task body();
        strict_fsm_pkg::fsm_item req;

        `uvm_info(get_name(), "Sending CMD_START (Init -> Run)", UVM_LOW)
        `uvm_do_with(req, { cmd == strict_fsm_pkg::fsm_item::CMD_START; })
        #10ns;
        `uvm_info(get_name(), "Sending CMD_STOP (Run -> Idle)", UVM_LOW)
        `uvm_do_with(req, { cmd == strict_fsm_pkg::fsm_item::CMD_STOP; })
        #10ns;
        `uvm_info(get_name(), "Sending CMD_START (Idle -> Run)", UVM_LOW)
        `uvm_do_with(req, { cmd == strict_fsm_pkg::fsm_item::CMD_START; })
        #10ns;
        `uvm_info(get_name(), "Sending CMD_RESET (Run -> Init)", UVM_LOW)
        `uvm_do_with(req, { cmd == strict_fsm_pkg::fsm_item::CMD_RESET; })
    endtask
endclass

interface fsm_if(input bit clk);
    logic rst;
    strict_fsm_pkg::fsm_item::Command_t cmd;
endinterface

class fsm_driver extends uvm_driver #(strict_fsm_pkg::fsm_item);
    `uvm_component_utils(fsm_driver)
    virtual fsm_if vif;
    function new(string name = "fsm_driver", uvm_component parent = null); super.new(name, parent); endfunction
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual fsm_if)::get(this, "", "vif", vif)) `uvm_fatal("NOVIF",{"vif not set"})
    endfunction
    virtual task run_phase(uvm_phase phase);
        forever begin
            seq_item_port.get_next_item(req);
            @(posedge vif.clk);
            vif.cmd <= req.cmd;
            seq_item_port.item_done();
        end
    endtask
endclass

class fsm_monitor extends uvm_monitor;
    `uvm_component_utils(fsm_monitor)
    virtual fsm_if vif;
    uvm_analysis_port #(strict_fsm_pkg::fsm_item) item_collected_port;
    function new(string name = "fsm_monitor", uvm_component parent = null);
        super.new(name, parent);
        item_collected_port = new("item_collected_port", this);
    endfunction
    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(!uvm_config_db#(virtual fsm_if)::get(this, "", "vif", vif)) `uvm_fatal("NOVIF",{"vif not set"})
    endfunction
    virtual task run_phase(uvm_phase phase);
        strict_fsm_pkg::fsm_item item;
        forever begin
            @(posedge vif.clk);
            item = strict_fsm_pkg::fsm_item::type_id::create("item");
            item.cmd = vif.cmd;
            item_collected_port.write(item);
        end
    endtask
endclass

class fsm_ref_model extends uvm_subscriber #(strict_fsm_pkg::fsm_item);
    `uvm_component_utils(fsm_ref_model)
    strict_fsm_pkg::FSMContext fsm;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        fsm = new(strict_fsm_pkg::InitState::Instance());
    endfunction
    virtual function void write(strict_fsm_pkg::fsm_item t);
        fsm.doAction(t);
    endfunction
endclass

class fsm_agent extends uvm_agent;
    `uvm_component_utils(fsm_agent)
    fsm_driver driver;
    fsm_monitor monitor;
    uvm_sequencer #(strict_fsm_pkg::fsm_item) sequencer;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        monitor = fsm_monitor::type_id::create("monitor", this);
        if(get_is_active() == UVM_ACTIVE) begin
            driver = fsm_driver::type_id::create("driver", this);
            sequencer = uvm_sequencer #(strict_fsm_pkg::fsm_item)::type_id::create("sequencer", this);
        end
    endfunction
    function void connect_phase(uvm_phase phase);
        if(get_is_active() == UVM_ACTIVE) begin
            driver.seq_item_port.connect(sequencer.seq_item_export);
        end
    endfunction
endclass

class fsm_env extends uvm_env;
    `uvm_component_utils(fsm_env)
    fsm_agent agent;
    fsm_ref_model ref_model;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = fsm_agent::type_id::create("agent", this);
        ref_model = fsm_ref_model::type_id::create("ref_model", this);
    endfunction
    function void connect_phase(uvm_phase phase);
        agent.monitor.item_collected_port.connect(ref_model.analysis_export);
    endfunction
endclass

class base_test extends uvm_test;
    `uvm_component_utils(base_test)
    fsm_env env;
    function new(string name, uvm_component parent); super.new(name, parent); endfunction
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = fsm_env::type_id::create("env", this);
    endfunction
    task run_phase(uvm_phase phase);
        strict_fsm_sequence seq = strict_fsm_sequence::type_id::create("seq");
        phase.raise_objection(this);
        seq.start(env.agent.sequencer);
        #50ns;
        phase.drop_objection(this);
    endtask
endclass

// ----------------------------------------------------------------
// -- Top Module
// ----------------------------------------------------------------
module top;
    import uvm_pkg::*;
    import strict_fsm_pkg::*;

    bit clk;
    always #5ns clk = ~clk;

    fsm_if vif(clk);

    initial begin
        uvm_config_db#(virtual fsm_if)::set(null, "uvm_test_top.env.agent*", "vif", vif);
        run_test("base_test");
    end
endmodule
