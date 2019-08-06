import std.stdio;
import std.conv;
import std.functional;
import std.algorithm;
import std.range;
import std.numeric;
import core.stdc.stdlib;
import std.file;
import std.utf;
import core.stdc.stdlib;
import lib;
import app;
import errors;
import vm;
import obj;
import swrite;
import sread;

// language default loaded library

// loaded as print
// print with no newline
Obj libprint(Vm vm, Obj[] args) {
    foreach(arg; args) {
        write(arg);
    }
    return new Obj();
}

// loaded as println
// print with newline
Obj libprintln(Vm vm, Obj[] args) {
    foreach(arg; args) {
        write(arg);
    }
    writeln;
    return new Obj();
}

// loaded as newline
// print a newline
Obj libnewline(Vm vm, Obj[] args) {
    writeln;
    return new Obj();
}

// loaded as +
// add some variables together
// if there are no args return 0
Obj libadd(Vm vm, Obj[] args) {
    double ret = 0;
    foreach (arg; args) {
        ret += arg.get!double;
    }
    return new Obj(ret);
}

// loaded as *
// multiply some variables together
// if there are no args return 1
Obj libmul(Vm vm, Obj[] args) {
    double ret = 1;
    foreach (arg; args) {
        ret *= arg.get!double;
    }
    return new Obj(ret);
}

// loaded as - 
// if there are 2 or more arguments subtract the sum of the second to the end from the first
// if ther is one argument subtract it from zero
// if there are no arguments error
Obj libsub(Vm vm, Obj[] args) {
    if (args.length == 1) {
        return new Obj(-args[0].get!double);
    }
    double ret = args[0].get!double;
    foreach (arg; args[1..$]) {
        ret -= arg.get!double;
    }
    return new Obj(ret);
}

// loaded as /
// if there are 2 or more arguments devide the first by the product of the second to the end
// if there is one argument devide one by it
// if ther is no arguemnts error
Obj libdiv(Vm vm, Obj[] args) {
    if (args.length == 1) {
        return new Obj(1/args[0].get!double);
    }
    double ret = args[0].get!double;
    foreach (arg; args[1..$]) {
        ret /= arg.get!double;
    }
    return new Obj(ret);
}

// loaded as <
// less than function for one or more arguments
Obj liblt(Vm vm, Obj[] args) {
    double val = args[0].get!double;
    foreach (arg; args[1..$]) {
        double next = arg.get!double;
        if (val < next) {
            val = next;
        }
        else {
            return new Obj(false);
        }
    }
    return new Obj(true);
}

// loaded as >
// greater than function for one or more arguments
Obj libgt(Vm vm, Obj[] args) {
    double val = args[0].get!double;
    foreach (arg; args[1..$]) {
        double next = arg.get!double;
        if (val > next) {
            val = next;
        }
        else {
            return new Obj(false);
        }
    }
    return new Obj(true);
}

// loaded as <=
// less than or equal to function for one or more arguments
Obj liblte(Vm vm, Obj[] args) {
    double val = args[0].get!double;
    foreach (arg; args[1..$]) {
        double next = arg.get!double;
        if (val <= next) {
            val = next;
        }
        else {
            return new Obj(false);
        }
    }
    return new Obj(true);
}

// loaded as >=
// greater than or equal to function for one or more arguments
Obj libgte(Vm vm, Obj[] args) {
    double val = args[0].get!double;
    foreach (arg; args[1..$]) {
        double next = arg.get!double;
        if (val >= next) {
            val = next;
        }
        else {
            return new Obj(false);
        }
    }
    return new Obj(true);
}

// loaded as apply
// the first argument must be a function
// the second through last arguments must all be lists
// the lists are concatenated and passed as arguments to the function
Obj libapply(Vm vm, Obj[] args) {
    Obj func = args[0];
    Obj[] funcargs = [];
    foreach (i; args[1..$]) {
        funcargs ~= i.get!(Obj[]);
    }
    return call(vm, func, funcargs);
}

// loaded as map
// the first argument must be a function
// the second through argument must all be lists of the same length
// the lists are zipped and each of the resulting list is applyed to the function
// to zip here means if given (list 1 2 3) and (list 3 4 5) return (list (list 1 3) (list 2 4) list(3 5))
Obj libmap(Vm vm, Obj[] args) {
    Obj func = args[0];
    Obj[] ret = [];
    Obj[][] funcargs = [];
    ulong length = args.length > 1 ? args[1].get!(Obj[]).length : 0;
    foreach (i; 0..length) {
        Obj[] cur = [];
        foreach (arg; args[1..$]) {
            cur ~= arg.get!(Obj[])[i];
        }
        funcargs ~= cur;
    }
    foreach (arg; funcargs) {
        ret ~= call(vm, func, arg);
    }
    return new Obj(ret);
}

// loaded as do
// return last argument
// used for multiple expressions as one
// (do x y z) is the same as ((lambda () x y z)) but faster
Obj libdo(Vm vm, Obj[] args) {
    return args[$-1];
}

// loaded as list
// returns a list made from all arguements
Obj liblist(Vm vm, Obj[] args) {
    return new Obj(args);
}

// loaded as range
// if there is one argument it returns a list from zero up to but not including the first argument's value
// if there are two argument it returns a list from the first to the last arguments not including the last argume's value
Obj librange(Vm vm, Obj[] args) {
    Obj[] ret = [];
    if (args.length == 1) {
        double begin = 0;
        double end = args[0].get!double;
        foreach (i; begin..end) {
            ret ~= new Obj(i);
        }
    }
    if (args.length == 2) {
        double begin = args[0].get!double;
        double end = args[1].get!double;
        foreach (i; begin..end) {
            ret ~= new Obj(i);
        }
    }
    return new Obj(ret);
}

// loaded as times
// not the same as mul or *
// duplicates the second argument by the number of the first arguemnt 
Obj libtimes(Vm vm, Obj[] args) {
    Obj[] ret;
    foreach (i; 0..args[0].get!double) {
        ret ~= args[1];
    }
    return new Obj(ret);
}

// loaded as length
// gets the length of a string or list
Obj liblength(Vm vm, Obj[] args) {
    if (args[0].peek!string) {
        return new Obj(args[0].get!string.length);
    }
    else {
        return new Obj(args[0].get!(Obj[]).length);
    }
}

// loaded as ref
// get index of item in list
Obj libref(Vm vm, Obj[] args) {
    return args[0].get!(Obj[])[cast(ulong) args[1].get!double];
}

Obj libsaveto(Vm vm, Obj[] args) {
    File f = File(args[0].get!string, "w");
    f.write(args[1].get!string);
    return new Obj();
}

Obj libreadto(Vm vm, Obj[] args) {
    return new Obj(cast(string) read(args[0].get!string));
}

Obj libexport(Vm vm, Obj[] args) {
    Serial state = new Serial;
    args[0].write(state);
    return new Obj(cast(string) state.refs);
}

Obj libimport(Vm vm, Obj[] args) {
    ubyte[] codes = cast(ubyte[]) args[0].get!string;
    InputSerial ser = InputSerial(codes);
    return ser.read;
}

Obj libexit(Vm vm, Obj[] args) {
    exit(0);
    assert(0);
}

Obj libpause(Vm vm, Obj[] args) {
    return new Obj(cast(string) vm.write());
}

Obj libresume(Vm vm, Obj[] args) {
    Vm v = new Vm(cast(ubyte[]) read(args[0].get!string));
    return v.run!false;   
}

Obj libreplback(Vm vm, Obj[] args, Obj[] cap) {
    Vm v = new Vm(cast(ubyte[]) cap[cast(ulong) args[0].get!double].get!string);
    vm.locals = v.locals;
    return new Obj();
}

string newFuncObj(string argt, string name, string as)() {
    string ret = "ret[\"" ~ as  ~ "\"] = " ~ "funcObj!(\"" ~ argt ~ "\", \"" ~ as ~ "\")(&lib" ~ name ~ ");";
    ret ~= "ret[\"unsafe:" ~ as  ~ "\"] = " ~ "new Obj(&lib" ~ name ~ ", \"unsafe:" ~ as ~ "\");";
    return ret;
}

string newFuncObj(string argt, string name)() {
    return newFuncObj!(argt, name, name);
}

Obj readFetch(string str) {
    Obj[string] funcs = xfuncs;
    return funcs[str];
}

Obj readFetchDel(string str, Obj[] cap) {
    Obj[string] funcs = xfuncs;
    funcs["repl.goto"] = new Obj(Func(&libreplback, cap, "repl.goto"));
    return funcs[str];
}

// load every function
Obj[string] xfuncs() {
    Obj[string] ret = [
        "true": new Obj(true),
        "false": new Obj(false),
    ];
    mixin(newFuncObj!("{}", "exit"));
    mixin(newFuncObj!("{(*a)}", "print"));
    mixin(newFuncObj!("{(*a)}", "println"));
    mixin(newFuncObj!("{}", "newline"));
    mixin(newFuncObj!("{(+n)}", "range"));
    mixin(newFuncObj!("{f(*l)}", "apply"));
    mixin(newFuncObj!("{f(+l)}", "map"));
    mixin(newFuncObj!("{(*a)}", "list"));
    mixin(newFuncObj!("{na}", "times"));
    mixin(newFuncObj!("{[sl]}", "length"));
    mixin(newFuncObj!("{ln}", "ref"));
    mixin(newFuncObj!("{(+a)}", "do"));
    mixin(newFuncObj!("{(*n)}", "add", "+"));
    mixin(newFuncObj!("{(+n)}", "sub", "-"));
    mixin(newFuncObj!("{(*n)}", "mul", "*"));
    mixin(newFuncObj!("{(+n)}", "div", "/"));
    mixin(newFuncObj!("{(+n)}", "lt", "<"));
    mixin(newFuncObj!("{(+n)}", "gt", ">"));
    mixin(newFuncObj!("{(+n)}", "lte", "<="));
    mixin(newFuncObj!("{(+n)}", "gte", ">="));
    mixin(newFuncObj!("{a}", "export"));
    mixin(newFuncObj!("{ss}", "saveto", "file-save"));
    mixin(newFuncObj!("{s}", "readto", "file-read"));
    mixin(newFuncObj!("{a}", "import"));
    mixin(newFuncObj!("{}", "pause", "vm-save"));
    mixin(newFuncObj!("{s}", "resume", "vm-resume"));
    return ret;
}