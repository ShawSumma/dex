import std.stdio;
import std.algorithm;
import std.string;
import core.stdc.stdlib;
import std.conv;
import std.range;
import app;
import extend;
import errors;

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
    writeln;
    writeln("error: name ", name," not found");
    begin:
    write("(error): ");
    string line = readln[0..$-1];
    string[] split = line.split(":");
    if (split.length == 0) {
        writeln("unknown option: []");
        goto begin;
    }
    if (split[0] == "help" || split[0] == "?" || split[0] == "options") {
        writeln("  help: display help");
        writeln("  change: replace name lookup with value");
        writeln("  name: change name to lookup");
        writeln("  repl: enter an error repl");
        writeln("  kill: exit wish custom status");
        writeln("  exit: exit with status 1");
        goto begin;
    }
    if (split[0] == "name" || split[0] == "lookup") {
        if (split.length == 1) {
            write("(name): ");
            line = readln[0..$-1];
        }
        else {
            line = line[split[0].length+1..$];
        }
        line = line.strip;
        name = line;
        goto redo;
    }
    if (split[0] == "replace" || split[0] == "expr" || split[0] == "change") {
        if (split.length == 1) {
            write("(expr): ");
            line = readln[0..$-1];
        }
        else {
            line = line[split[0].length+1..$];
        }
        ulong index = 0;
        Program program = new Program;
        Node n = parse1(line, &index);
        program.walk(n);
        return vm.run(program);
    }
    if (split[0] == "kill") {
        if (split.length == 1) {
            write("(status): ");
            line = readln[0..$-1];
        }
        else {
            line = line[split[0].length+1..$];
        }
        ulong index = 0;
        Program program = new Program;
        Node n = parse1(split[0], &index);
        program.walk(n);
        exit(to!int(vm.run(program).get!double));
    }
    if (line == "repl"){
        errorRepl(vm);
        goto begin;
    }
    if (line == "exit") {
        exit(1);
    }
    writeln("unknown option: ", line);
    goto begin;
}