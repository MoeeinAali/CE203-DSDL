#!/usr/bin/env python3
"""Generate Logisim-evolution sequential test vectors for the Waiting Room
Controller (waiting_room.circ).

The reference model below mirrors exactly the hardware built in the .circ:

    U       = IN                                   (count-direction signal)
    Enable  = IN xor OUT                            (counter enabled only when
                                                      exactly one sensor fires)
    NCLR    = not(Clr)                              (active-low Clr -> active-
                                                      high synchronous? no,
                                                      asynchronous Register
                                                      clear)
    count   : 4-bit up/down counter, D_i chain built from XOR/AND toggle logic
    LT15    = count != 15                           (combinational, *before*
                                                      the clock edge)
    EntValid= LT15 and Ent and T
    Dopen   = (EntValid or Open) and (not IN)        (SR-latch-like D input)
    Open    : D-FF sampling Dopen on every rising edge (always enabled),
              asynchronously cleared by Clr
    Close   = (count == 15)                          (pure combinational)

Each logical clock cycle is emitted as two vector rows sharing the same
<Set>/<Seq> pair sequence:
    * Clk=0 row  -> inputs for the upcoming edge are set up; outputs must
                    still show the *old* state (nothing has happened yet).
    * Clk=1 row  -> the rising edge is captured; outputs must show the state
                    *after* the edge (new count / new Open), while Close is
                    recomputed live from the new count.

An asynchronous reset (Clr=0) is modelled as taking effect immediately,
independent of the clock value, matching the Register's asynchronous clear.
"""
from __future__ import annotations

from dataclasses import dataclass


@dataclass
class State:
    count: int = 0
    open_q: int = 0


def close_of(count: int) -> int:
    return 1 if count == 15 else 0


def combinational_dopen(count: int, open_q: int, ent: int, t: int, in_: int) -> int:
    lt15 = 1 if count != 15 else 0
    ent_valid = 1 if (lt15 and ent and t) else 0
    orr = 1 if (ent_valid or open_q) else 0
    n_in = 1 if not in_ else 0
    return 1 if (orr and n_in) else 0


def apply_edge(state: State, in_: int, out_: int, ent: int, t: int, clr: int) -> State:
    """Return the new state after one rising edge (or async reset)."""
    if clr == 0:
        return State(count=0, open_q=0)

    dopen = combinational_dopen(state.count, state.open_q, ent, t, in_)

    enable = in_ ^ out_
    new_count = state.count
    if enable:
        new_count = (state.count + 1) % 16 if in_ else (state.count - 1) % 16

    return State(count=new_count, open_q=dopen)


class VectorBuilder:
    def __init__(self):
        self.rows: list[tuple] = []
        self.set_id = 0
        self.seq = 0

    def new_sequence(self):
        self.set_id += 1
        self.seq = 0

    def row(self, in_, out_, ent, t, clk, clr, state: State):
        self.seq += 1
        q = state.count
        q0 = q & 1
        q1 = (q >> 1) & 1
        q2 = (q >> 2) & 1
        q3 = (q >> 3) & 1
        close = close_of(q)
        self.rows.append(
            (in_, out_, ent, t, clk, clr, state.open_q, close, q0, q1, q2, q3,
             self.set_id, self.seq)
        )

    def cycle(self, state: State, in_=0, out_=0, ent=0, t=1, clr=1) -> State:
        """Emit the Clk=0 (setup) then Clk=1 (edge) row pair for one clock
        cycle and return the resulting state."""
        # Clk=0: nothing has happened yet, outputs reflect the *old* state.
        self.row(in_, out_, ent, t, 0, clr, state)
        # Rising edge -> compute and commit new state.
        new_state = apply_edge(state, in_, out_, ent, t, clr)
        self.row(in_, out_, ent, t, 1, clr, new_state)
        return new_state

    def reset_row(self, state_before: State) -> State:
        """Emit a single asynchronous-reset row (Clr=0). Works regardless of
        clock level; we use Clk=0 for it."""
        new_state = State(count=0, open_q=0)
        self.row(0, 0, 0, 0, 0, 0, new_state)
        return new_state

    def dump(self, path: str):
        header = "IN OUT Ent T Clk Clr Open Close Q0 Q1 Q2 Q3 <Set> <Seq>"
        with open(path, "w") as f:
            f.write(header + "\n")
            for r in self.rows:
                f.write(" ".join(str(v) for v in r) + "\n")


def scenario_reset_and_basic():
    vb = VectorBuilder()
    vb.new_sequence()
    st = State()
    st = vb.reset_row(st)
    # Idle cycles: nothing happening, state must stay at 0.
    for _ in range(3):
        st = vb.cycle(st, in_=0, out_=0, ent=0, t=1)
    return vb


def scenario_up_counting_full():
    """Count all the way up from 0 to 15 using Ent-gated entries, then verify
    the 16th entry attempt is blocked (Close=1, LT15=0)."""
    vb = VectorBuilder()
    vb.new_sequence()
    st = State()
    st = vb.reset_row(st)
    for i in range(15):
        # Person presses Ent (T=1, room not full) -> Open should latch on
        st = vb.cycle(st, in_=0, out_=0, ent=1, t=1)
        assert st.open_q == 1, f"Open should latch after Ent #{i}"
        # Person walks through -> IN pulses for one cycle, closing Open again
        st = vb.cycle(st, in_=1, out_=0, ent=0, t=1)
        assert st.open_q == 0, f"Open should clear after IN pulse #{i}"
    assert st.count == 15
    assert close_of(st.count) == 1
    # Room is now full: pressing Ent again must NOT open the door.
    st = vb.cycle(st, in_=0, out_=0, ent=1, t=1)
    assert st.open_q == 0, "Open must stay low when room is full"
    return vb


def scenario_out_of_hours_blocked():
    """Ent pressed while T=0 (outside allowed hours) must never open the
    door, even though the room has capacity."""
    vb = VectorBuilder()
    vb.new_sequence()
    st = State()
    st = vb.reset_row(st)
    st = vb.cycle(st, in_=0, out_=0, ent=1, t=0)
    assert st.open_q == 0
    st = vb.cycle(st, in_=0, out_=0, ent=1, t=0)
    assert st.open_q == 0
    # Hour becomes valid again -> now it should open.
    st = vb.cycle(st, in_=0, out_=0, ent=1, t=1)
    assert st.open_q == 1
    return vb


def scenario_exit_and_reentry():
    """Bring the room to full capacity (15), verify Close, then let one
    person leave (OUT pulse) and verify Close drops and a new entry is
    accepted."""
    vb = VectorBuilder()
    vb.new_sequence()
    st = State()
    st = vb.reset_row(st)
    for _ in range(15):
        st = vb.cycle(st, in_=0, out_=0, ent=1, t=1)
        st = vb.cycle(st, in_=1, out_=0, ent=0, t=1)
    assert st.count == 15 and close_of(st.count) == 1
    # Blocked while full.
    st = vb.cycle(st, in_=0, out_=0, ent=1, t=1)
    assert st.open_q == 0
    # One person leaves.
    st = vb.cycle(st, in_=0, out_=1, ent=0, t=1)
    assert st.count == 14
    assert close_of(st.count) == 0
    # Now entry is allowed again.
    st = vb.cycle(st, in_=0, out_=0, ent=1, t=1)
    assert st.open_q == 1
    st = vb.cycle(st, in_=1, out_=0, ent=0, t=1)
    assert st.count == 15
    return vb


def scenario_simultaneous_in_out():
    """A person enters and a person leaves on the very same clock edge
    (IN=OUT=1): Enable = IN xor OUT = 0, so the count must not change."""
    vb = VectorBuilder()
    vb.new_sequence()
    st = State()
    st = vb.reset_row(st)
    # Get to a mid-range count first (count = 3).
    for _ in range(3):
        st = vb.cycle(st, in_=1, out_=0, ent=0, t=1)
    before = st.count
    st = vb.cycle(st, in_=1, out_=1, ent=0, t=1)
    assert st.count == before, "simultaneous IN & OUT must hold the count"
    return vb


def scenario_open_holds_until_in():
    """Once Open latches, it must stay asserted across multiple clock cycles
    until the IN pulse actually arrives (Ent released early doesn't matter,
    and additional Ent presses while already open don't break anything)."""
    vb = VectorBuilder()
    vb.new_sequence()
    st = State()
    st = vb.reset_row(st)
    st = vb.cycle(st, in_=0, out_=0, ent=1, t=1)
    assert st.open_q == 1
    # Ent released, person still hasn't stepped through yet -> Open must hold.
    for _ in range(3):
        st = vb.cycle(st, in_=0, out_=0, ent=0, t=1)
        assert st.open_q == 1, "Open must stay latched while waiting for IN"
    # Person finally walks through.
    st = vb.cycle(st, in_=1, out_=0, ent=0, t=1)
    assert st.open_q == 0
    assert st.count == 1
    return vb


def scenario_down_counting():
    """From a mid-range count, walk all the way down to 0 via OUT pulses."""
    vb = VectorBuilder()
    vb.new_sequence()
    st = State()
    st = vb.reset_row(st)
    for _ in range(5):
        st = vb.cycle(st, in_=1, out_=0, ent=0, t=1)
    assert st.count == 5
    for _ in range(5):
        st = vb.cycle(st, in_=0, out_=1, ent=0, t=1)
    assert st.count == 0
    return vb


def scenario_reset_mid_operation():
    """Assert Clr in the middle of activity: count and Open must drop to 0
    immediately (asynchronous), regardless of clock phase."""
    vb = VectorBuilder()
    vb.new_sequence()
    st = State()
    st = vb.reset_row(st)
    for _ in range(4):
        st = vb.cycle(st, in_=1, out_=0, ent=0, t=1)
    assert st.count == 4
    st = vb.cycle(st, in_=0, out_=0, ent=1, t=1)
    assert st.open_q == 1
    st = vb.reset_row(st)
    assert st.count == 0 and st.open_q == 0
    st = vb.cycle(st, in_=0, out_=0, ent=0, t=1)
    assert st.count == 0 and st.open_q == 0
    return vb


def main():
    scenarios = [
        scenario_reset_and_basic(),
        scenario_up_counting_full(),
        scenario_out_of_hours_blocked(),
        scenario_exit_and_reentry(),
        scenario_simultaneous_in_out(),
        scenario_open_holds_until_in(),
        scenario_down_counting(),
        scenario_reset_mid_operation(),
    ]

    combined = VectorBuilder()
    combined.set_id = 0
    for sc in scenarios:
        combined.set_id += 1
        for row in sc.rows:
            # Renumber <Set> so every scenario becomes its own isolated
            # sequence once concatenated into a single vector file (each
            # scenario internally uses set id 1, since it builds a fresh
            # VectorBuilder).
            new_row = row[:-2] + (combined.set_id, row[-1])
            combined.rows.append(new_row)

    combined.dump("tests_waiting_room.vec")
    print(f"Wrote tests_waiting_room.vec with {len(combined.rows)} rows "
          f"across {len(scenarios)} scenarios")


if __name__ == "__main__":
    main()
