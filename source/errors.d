import std.stdio;
import std.conv;
import std.numeric;
import core.stdc.stdlib;
import std.algorithm;
import std.range;
import lib;
import app;

void errorRepl(Vm vm) {
    Obj[string] ll = vm.lastlocals;
    vm.lastlocals = vm.locals[$-1];
    vm.locals.popBack;
    while (true) {
        write(">>> ");
        string inp = readln[0..$-1];
        if (inp == "(exit)") {
            break;
        }
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
        if (!got.peek!void) {
            writeln(got);
        }
    }
    vm.locals ~= vm.lastlocals;
    vm.lastlocals = ll;
}


struct Argexp {
    alias ArgType = char;
    enum Type {
        TYPE,
        CALL
    }
    union Value {
        Argexp[] calls;
        ArgType type;
    }
    Type type;
    Value value;
    bool okay(Obj[] args, ulong* ind) {
        if (type == Type.TYPE) {
            if (*ind >= args.length) {
                return false;
            }
            switch (value.type) {
                case 'n': return args[*ind].peek!double;
                case 'b': return args[*ind].peek!bool;
                case 's': return args[*ind].peek!string;
                case 'l': return args[*ind].peek!(Obj[]);
                case 'a': return true;
                case 'f': return args[*ind].peek!Func;
                default: assert(0);
            }
        }
        else {
            Argexp[] exps = value.calls[1..$];
            ArgType fn = value.calls[0].value.type;
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

Argexp parseStr(string str, ulong* index) {
    Argexp ret;
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
    else {
        ret.type = Argexp.Type.TYPE;
        ret.value.type = str[*index];
        (*index) ++;
    }
    return ret;
}

Argexp parseStr(string str) {
    ulong val = 0;
    return parseStr(str, &val);
}

Obj funcCheck(string S)(Vm vm, Obj func, Obj[] args) {
    Argexp exp = parseStr(S);
    ulong ind = 0;
    redo:
    bool isokay = exp.okay(args, &ind) && ind == args.length;
    if (!isokay) {
        writeln("error: bad arguments to a func");
        begin:
        write("(error): ");
        string line = readln[0..$-1];
        if (line == "help" || line == "?" || line == "options") {
            writeln("options: ");
            writeln("  help: display help");
            writeln("  return: dont call function, return value instead");
            writeln("  args: replace args with values");
            writeln("  kill: exit wish custom status");
            writeln("  exit: exit with status 1");
            goto begin;
        }
        if (line == "return") {
            write("(return): ");
            line = readln[0..$-1];
            ulong index = 0;
            Program program = new Program;
            Node n = parse1(line, &index);
            program.walk(n);
            return vm.run(program);
        }
        if (line == "args") {
            write("(args): ");
            string code = readln[0..$-1];
            args = [];
            ulong index = 0;
            while (index < code.length) {
                Node n = parse1(code, &index);
                Program program = new Program;
                program.walk(n);
                args ~= vm.run(program);
            }
            goto redo;
        }
        if (line == "kill") {
            write("(status): ");
            line = readln[0..$-1];
            ulong index = 0;
            Program program = new Program;
            Node n = parse1(line, &index);
            program.walk(n);
            exit(to!int(vm.run(program).get!double));
        }
        if (line == "exit") {
            exit(1);
        }
        writeln("unknown option: ", line);
        goto begin;
    }
    return call(vm, func, args);
}

Obj delegate(Vm vm, Obj[] args) funcConv(string S)(Obj function(Vm vm, Obj[] args) func) {
    return (Vm vm, Obj[] args) => funcCheck!S(vm, Obj(func), args);
}

Obj funcObj(string S, T)(T f) {
    return Obj(funcConv!S(f));
}
