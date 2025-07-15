#---------------------------------------------------------------
Base class
#---------------------------------------------------------------
class base_class extends ..
state_class state_cls; //the current state 
state_cls = state_class::type_id::create("",this);

  virtual function void set_fsm_state(string state_name,string prev_state);     //task to change states
    $cast(state_cls,factory.create_object_by_name(state_name,get_full_name())); //allow dynamic instantiation and switching of states at runtime
   state_cls.prev_state = prev_state; 
endfunction 

task run_fsm();
  forever 
    state_cls.do_action(this);  //forever call do action of current state
endtask
endclass

#---------------------------------------------------------------
State class
#---------------------------------------------------------------
class state_class extends ..           //current state
  virtual task do_action(base_class cls);
    cls.set_fsm_state("transit_state",get_type_name())
  endtask:do_action
endclass

class transit_state extends state_class; //transit_state is a concrete state 
virtual task do_action(base_class cls);
    ....
  endtask:do_action
endclass
  
