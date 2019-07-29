import std.stdio;
import std.conv;
import std.functional;
import std.algorithm;
import std.range;
import std.numeric;
import core.stdc.stdlib;
import lib;
import app;
import errors;

Obj libprint(Vm vm, Obj[] args) {
    foreach(arg; args) {
        write(arg);
    }
    return Obj();
}

Obj libprintln(Vm vm, Obj[] args) {
    foreach(arg; args) {
        write(arg);
    }
    writeln;
    return Obj();
}

Obj libnewline(Vm vm, Obj[] args) {
    writeln;
    return Obj();
}

Obj libadd(Vm vm, Obj[] args) {
    double ret = 0;
    foreach (arg; args) {
        ret += arg.get!double;
    }
    return Obj(ret);
}

Obj libmul(Vm vm, Obj[] args) {
    double ret = 1;
    foreach (arg; args) {
        ret *= arg.get!double;
    }
    return Obj(ret);
}

Obj libsub(Vm vm, Obj[] args) {
    if (args.length == 1) {
        return Obj(-args[0].get!double);
    }
    double ret = args[0].get!double;
    foreach (arg; args[1..$]) {
        ret -= arg.get!double;
    }
    return Obj(ret);
}

Obj libdiv(Vm vm, Obj[] args) {
    if (args.length == 1) {
        return Obj(1/args[0].get!double);
    }
    double ret = args[0].get!double;
    foreach (arg; args[1..$]) {
        ret /= arg.get!double;
    }
    return Obj(ret);
}

Obj liblt(Vm vm, Obj[] args) {
    double val = args[0].get!double;
    foreach (arg; args[1..$]) {
        double next = arg.get!double;
        if (val < next) {
            val = next;
        }
        else {
            return Obj(false);
        }
    }
    return Obj(true);
}


Obj libgt(Vm vm, Obj[] args) {
    double val = args[0].get!double;
    foreach (arg; args[1..$]) {
        double next = arg.get!double;
        if (val > next) {
            val = next;
        }
        else {
            return Obj(false);
        }
    }
    return Obj(true);
}

Obj liblte(Vm vm, Obj[] args) {
    double val = args[0].get!double;
    foreach (arg; args[1..$]) {
        double next = arg.get!double;
        if (val <= next) {
            val = next;
        }
        else {
            return Obj(false);
        }
    }
    return Obj(true);
}

Obj libgte(Vm vm, Obj[] args) {
    double val = args[0].get!double;
    foreach (arg; args[1..$]) {
        double next = arg.get!double;
        if (val >= next) {
            val = next;
        }
        else {
            return Obj(false);
        }
    }
    return Obj(true);
}

Obj libapply(Vm vm, Obj[] args) {
    Obj func = args[0];
    Obj[] funcargs = [];
    foreach (i; args[1..$]) {
        funcargs ~= i.get!(Obj[]);
    }
    return call(vm, func, funcargs);
}

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
    return Obj(ret);
}

Obj libdo(Vm vm, Obj[] args) {
    return args[$-1];
}

Obj liblist(Vm vm, Obj[] args) {
    return Obj(args);
}

Obj librange(Vm vm, Obj[] args) {
    Obj[] ret = [];
    if (args.length == 1) {
        double begin = 0;
        double end = args[0].get!double;
        foreach (i; begin..end) {
            ret ~= Obj(i);
        }
    }
    if (args.length == 2) {
        double begin = args[0].get!double;
        double end = args[1].get!double;
        foreach (i; begin..end) {
            ret ~= Obj(i);
        }
    }
    return Obj(ret);
}

Obj libtimes(Vm vm, Obj[] args) {
    Obj[] ret;
    foreach (i; 0..args[0].get!double) {
        ret ~= args[1];
    }
    return Obj(ret);
}

Obj liblength(Vm vm, Obj[] args) {
    if (args[0].peek!string) {
        return Obj(args[0].get!string.length);
    }
    else {
        return Obj(args[0].get!(Obj[]).length);
    }
}

Obj libref(Vm vm, Obj[] args) {
    return args[0].get!(Obj[])[cast(ulong) args[1].get!double];
}

Obj libvars(Vm vm, Obj[] args) {
    Obj[] ret = [];
    foreach(k; vm.locals[$-1].keys) {
        ret ~= Obj(k);
    }
    return Obj(ret);
}

Obj[string] xfuncs() {
    return [
        "vars": funcObj!"{}"(&libvars),
        "print": funcObj!"{(*a)}"(&libprint),
        "println": funcObj!"{(*a)}"(&libprintln),
        "newline": funcObj!"{}"(&libnewline),
        "range": funcObj!"{(+n)}"(&librange),
        "apply": funcObj!"{f(*l)}"(&libapply),
        "map": funcObj!"{f(+l)}"(&libmap),
        "list": funcObj!"{(*a)}"(&liblist),
        "times": funcObj!"{na}"(&libtimes),
        "length": funcObj!"{[sl]}"(&liblength),
        "ref": funcObj!"{ln}"(&liblength),
        "do": funcObj!"{(+a)}"(&libdo),
        "+": funcObj!"{(*n)}"(&libadd),
        "-": funcObj!"{(+n)}"(&libsub),
        "*": funcObj!"{(*n)}"(&libmul),
        "/": funcObj!"{(+n)}"(&libdiv),
        "<": funcObj!"{(+n)}"(&liblt),
        ">": funcObj!"{(+n)}"(&libgt),
        "<=": funcObj!"{(+n)}"(&liblte),
        ">=": funcObj!"{(+n)}"(&libgte),
        "true": Obj(true),
        "false": Obj(false),
    ];
}