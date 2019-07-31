import std.stdio;
import std.conv;
import std.numeric;
import core.stdc.stdlib;
import std.algorithm;
import std.range;
import lib;
import app;
import obj;
import vm;
import node;
import parse;

// a repl for use from errors
// exit does not actually call anything
void errorRepl(Vm vm) {
    Obj[string] ll = vm.lastlocals;
    vm.lastlocals = vm.locals[$-1];
    vm.locals.popBack;
    while (true) {
        write(">>> ");
        string inp = readln[0..$-1];
        // if the input is exit stop the repl and cleanup
        if (inp == "(exit)") {
            break;
        }
        // read until all parens are closed
        while (count(inp, '(') - count(inp, ')') != 0) {
            write("... ");
            foreach(i; 0..count(inp, '(') - count(inp, ')')) {
                write("    ");
            }
            inp ~= readln;
        }
        Program program = new Program;
        Node n = parses(inp);
        program.walk(n);
        Obj got = vm.run(program, 0);
        // if the obj has a value show it
        if (!got.peek!void) {
            writeln(got);
        }
    }
    vm.locals ~= vm.lastlocals;
    vm.lastlocals = ll;
}

// argument type checker node
struct Argexp {
    alias ArgType = char;
    enum Type {
        TYPE,
        CALL
    }
    Type type;
    union Value {
        Argexp[] calls;
        ArgType type;
    }
    Value value;
    // return true if there is no error
    // if there is an error rewind the ind
    bool okay(Obj[] args, ulong* ind) {
        if (type == Type.TYPE) {
            // if there is no arguments left it is an error
            if (*ind >= args.length) {
                return false;
            }
            // for numbers n or i works
            switch (value.type) {
                case 'i': goto case;
                case 'n': return args[*ind].peek!double;
                case 'b': return args[*ind].peek!bool;
                case 's': return args[*ind].peek!string;
                case 'l': return args[*ind].peek!(Obj[]);
                case 'f': return args[*ind].peek!Func;
                case 'a': return true;
                default: assert(0);
            }
        }
        else {
            Argexp[] exps = value.calls[1..$];
            ArgType fn = value.calls[0].value.type;
            // commands are
            // command '|' means any of
            // command '>' means in order of
            // command '*' means any number of
            // command '+' means nonzero number of
            // aliases are
            // alias {} means in order of
            // alias [] means any of
            switch (fn) {
                case '|': {
                    foreach (e; exps) {
                        if (e.okay(args, ind)) {
                            return true;
                        }
                    }
                    return false;
                }
                case '>': {
                    ulong bind = *ind;
                    foreach (e; exps) {
                        if (!e.okay(args, ind)) {
                            *ind = bind;
                            return false;
                        }
                        (*ind) ++;
                    }
                    return true;
                }
                case '*': {
                    ulong bind = *ind;
                    while (true) {
                        foreach(i; 0..exps.length) {
                            if (!exps[i].okay(args, ind)) {
                                if (i == 0) {
                                    (*ind) --;
                                    return true;
                                }
                                else {
                                    *ind = bind;
                                    return false;
                                }
                            }
                            (*ind) ++;
                        }
                    }
                }
                case '+': {
                    ulong bind = *ind;
                    ulong count = 0;
                    while (true) {
                        foreach(i; 0..exps.length) {
                            if (!exps[i].okay(args, ind)) {
                                if (i == 0 && count != 0) {
                                    (*ind) --;
                                    return true;
                                }
                                else {
                                    *ind = bind;
                                    return false;
                                }
                            }
                            (*ind) ++;
                        }
                        count ++;
                    }
                }
                default: {
                    assert(0);
                }
            }
            assert(0);
        }
    }
}

// parse string from index to end into an argexp command
Argexp parseStr(string str, ulong* index) {
    Argexp ret;
    // command is the first letter
    if (str[*index] == '(') {
        (*index) ++;
        Argexp[] arr;
        while (str[*index] != ')') {
            arr ~= parseStr(str, index);
        }
        (*index) ++;
        ret.type = Argexp.Type.CALL;
        ret.value.calls = arr;
    }
    // command is |
    else if (str[*index] == '[') {
        (*index) ++;
        Argexp or;
        or.type = Argexp.Type.TYPE;
        or.value.type = '|';
        Argexp[] arr = [or];
        while (str[*index] != ']') {
            arr ~= parseStr(str, index);
        }
        (*index) ++;
        ret.type = Argexp.Type.CALL;
        ret.value.calls = arr;
    }
    // command  is >>
    else if (str[*index] == '{') {
        (*index) ++;
        Argexp fwd;
        fwd.type = Argexp.Type.TYPE;
        fwd.value.type = '>';
        Argexp[] arr = [fwd];
        while (str[*index] != '}') {
            arr ~= parseStr(str, index);
        }
        (*index) ++;
        ret.type = Argexp.Type.CALL;
        ret.value.calls = arr;
    }
    // value is a type to use
    else {
        ret.type = Argexp.Type.TYPE;
        ret.value.type = str[*index];
        (*index) ++;
    }
    return ret;
}

// parse entire string
Argexp parseStr(string str) {
    // val must be a pointer
    ulong val = 0;
    return parseStr(str, &val);
}

// check a function call and handle errors
// the template string S is the argument types
Obj funcCheck(string S)(Vm vm, Obj func, Obj[] args) {
    Argexp exp = parseStr(S);
    ulong ind = 0;
    redo:
    bool isokay = exp.okay(args, &ind) && ind == args.length;
    if (!isokay) {
        // functions dont carry a name as they come from lambdas
        // does not show function name
        writeln("error: bad args to a func");
        begin:
        write("(error): ");
        string line = readln[0..$-1];
        string[] split = line.split(":");
        if (line == "help" || line == "?" || line == "options") {
            writeln("options: ");
            writeln("  help: display help");
            writeln("  return: dont call function, return value instead");
            writeln("  args: replace args with values");
            writeln("  show: show bad args");
            writeln("  repl: enter an error repl");
            writeln("  kill: exit wish custom status");
            writeln("  exit: exit with status 1");
            goto begin;
        }
        if (split.length == 0) {
            writeln("unknown option: []");
            goto begin;
        }
        if (split[0] == "kill") {
            if (split.length == 1) {
                write("(return): ");
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
        if (split[0] == "show") {
            writeln(args);
            goto begin;
        }
        if (split[0] == "args") {
            if (split.length == 1) {
                write("(args): ");
                line = readln[0..$-1];
            }
            else {
                line = line[split[0].length+1..$];
            }
            args = [];
            ulong index = 0;
            while (index < line.length) {
                Node n = parse1(line, &index);
                Program program = new Program;
                program.walk(n);
                args ~= vm.run(program);
            }
            goto redo;
        }
        if (split[0] == "return" || split[0] == "replace") {
            if (split.length == 1) {
                write("(args): ");
                line = readln[0..$-1];
            }
            else {
                line = line[split[0].length+1..$];
            }
            ulong index = 0;
            Node n = parse1(line, &index);
            Program program = new Program;
            program.walk(n);
            return vm.run(program);
        }
        if (line == "repl"){
            errorRepl(vm);
            goto begin;
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
            Node n = parse1(line, &index);
            program.walk(n);
            exit(to!int(vm.run(program).get!double));
        }
        if (split[0] == "exit") {
            exit(1);
        }
        writeln("unknown option: ", line);
        goto begin;
    }
    return call(vm, func, args);
}

// convert function to delegate that is checked
Obj delegate(Vm vm, Obj[] args) funcConv(string S)(Obj function(Vm vm, Obj[] args) func) {
    return (Vm vm, Obj[] args) => funcCheck!S(vm, Obj(Func(func)), args);
}

// make an object out of a function
// template string S is the argument check
Obj funcObj(string S)(Obj function(Vm vm, Obj[] args) f) {
    return Obj(Func(funcConv!S(f)));
}
