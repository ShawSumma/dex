import std.stdio;
import std.algorithm;
import std.algorithm.mutation;
import std.string;
import core.stdc.stdlib;
import std.conv;
import std.range;
import app;
import extend;
import errors;
import namecheck;
import obj;
import vm;
import node;
import parse;

// get a name, loads all names each time
// likely able to be much more optimized
Obj get(Vm vm, string name) {
    // get standard fuctions
    Obj [string] xfn = xfuncs;
    redo:
    if (name in xfn) {
        return xfn[name];
    }
    // if the name does not exist look down the stack incase repl mode
    foreach_reverse (layer; vm.locals) {
        if (name in layer) {
            return layer[name];
        }
    }
    // if it does not exist there is error
    writeln("error: name ", name," not found");
    // do not repeat the one time error message
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
        writeln("  repl: enter an error repl");
        writeln("  auto: suggest and change a name");
        writeln("  kill: exit wish custom status");
        writeln("  exit: exit with status 1");
        goto begin;
    }
    // when auto! is chosen it automatically finds a name
    // this is not the smartest algorythm
    if (split[0] == "auto" || split[0] == "auto!") {
        string[] options = xfn.keys;
        foreach(layer; vm.locals) {
            options ~= layer.keys;
        }
        check:
        string possible = nameCheck(name, options);
        if (possible != "") {
            if (split[0] == "auto") {
                write("try ", possible, ": ");
            }
        }
        else {
            writeln("auto cant find a name");
            goto begin;
        }
        if (split[0] == "auto") {
            string ch = readln[0..$-1];
            if (ch == "yes" || ch == "y") {
                name = possible;
            }
            else if (ch == "no" || ch == "n") {
                options[$-find(options, possible).length] = "";
                goto check;
            }
            else {
                goto begin;
            }
        }
        else {
            name = possible;
        }
        goto redo;
    }
    // evalueates expression
    // if the expression is a name it does a new lookup
    if (split[0] == "replace" || split[0] == "expr" || split[0] == "change") {
        if (split.length == 1) {
            write("(expr): ");
            line = readln[0..$-1];
        }
        else {
            line = line[split[0].length+1..$];
        }
        Info info = new Info;
        Program program = new Program;
        Node n = parse1(line, info);
        program.walk(n);
        return vm.run(program);
    }
    // exit with value
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
        Info info = new Info;
        Node n = parse1(line, info);
        program.walk(n);
        exit(to!int(vm.run(program).get!double));
    }
    // enter an error repl
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