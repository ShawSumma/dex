import std.stdio;
import core.stdc.stdlib;
import std.conv;
import app;
import extend;

Obj[] toList(P...) (P rest) {
    Obj[] ret = [];
    foreach (v; rest) {
        static if (is(v == Obj)) {
            ret ~= v;
        }
        else {
            ret ~= Obj(v);
        }
    }
    return ret;
}

Obj get(Vm vm, string name) {
    Obj [string] xfn = xfuncs;
    redo:
    if (name in xfn) {
        return xfn[name];
    }
    foreach_reverse (layer; vm.locals) {
        if (name in layer) {
            return layer[name];
        }
    }
    writeln("error: name ", name," not found");
    options:
    writeln("options:");
    writeln("  0 = exit and return 1");
    writeln("  1 = exit type return value");
    writeln("  2 = type new name");
    write("choice: ");
    string ln = readln[0..$-1];
    if (ln == "0") {
        exit(0);
    }
    else if (ln == "1") {
        write("return value: ");
        string input = readln[0..$-1];
        exit(parse!int(input));
    }
    else if (ln == "2") {
        write("name: ");
        name = readln[0..$-1];
        goto redo;
    }
    else {
        writeln("not understood: ", ln);
        goto options;
    }
    assert(0);
}