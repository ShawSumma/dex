import std.range;
import std.stdio;
import std.algorithm;
import obj;
import vm;

class Serial {
    ulong[Obj] objs;
    ubyte[] refs;
    bool add(Obj o) {
        bool ret = !objs.keys.canFind(o);
        if (ret) {
            objs[o] = refs.length;
        }
        return ret;
    }
}

ubyte[] reint(U)(U t) {
    ubyte[] val = *cast(ubyte[U.sizeof]*) new U(t);
    return val;
}

void serial(Serial state, double s) {
    state.refs ~= reint(s);
}

void serial(Serial state, ulong s) {
    state.refs ~= reint(s);
}

void serial(T)(Serial state, T[] arr) {
    state.refs ~= reint(arr.length);
    foreach (n; arr) {
        serial(state, n);
    }
}

void serial(Serial state, string str) {
    state.refs ~= reint(str.length);
    foreach (n; str) {
        state.refs ~= cast(ubyte) n;
    }
}

void serial(Serial state, Obj v) {
    v.write(state);
}

void serial(K, V)(Serial state, V[K] aarr) {
    state.refs ~= reint(aarr.length);
    foreach (n; aarr.byKeyValue) {
        static if (is(K == Obj)) {
            n.key.write(state);
        }
        static if (!is(K == Obj)) {
            serial(state, n.key);            
        }
        static if (is(V == Obj)) {
            n.value.write(state);
        }
        static if (!is(V == Obj)) {
            serial(state, n.value);            
        }
    }
}

void serial(Serial state, Opcode op) {
    state.refs ~= cast(ubyte) op.type;
    serial(state, op.value);
}

void serial(Serial state, Program p) {
    serial(state, p.code);
    serial(state, p.consts);
    serial(state, p.count);
    serial(state, p.funcargnames);
    serial(state, p.funccaps);
    serial(state, p.funclocs);
    serial(state, p.isglobs);
    serial(state, p.strings);
}

void serial(Serial state, Vm vm) {
    serial(state, vm.lastlocals);
    serial(state, vm.locals);
    serial(state, vm.programs);
    serial(state, vm.stack);
}

void serial(T)(Serial state, T *v) {
    ulong bind = state.refs.length;
    static if (is(T == Obj)) {
        v.write(state);
    }
    static if (!is(T == Obj)) {
        serial(state, *v);
    }
}

void serial(Serial state, bool v) {
    state.refs ~= cast(ubyte) v;
}