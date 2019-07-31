import std.conv;
import std.range;
import std.stdio;
import vm;

// a function can be one of three things
// a location in bytecode know as a FuncLocation
// a delegate
// a function
struct Func {
	enum Type {
		LOCATION,
		DELEGATE,
		FUNCTION,
	}
	union Value {
		FuncLocation loc;
		Obj delegate(Vm, Obj[]) del;
		Obj function(Vm, Obj[]) fun;
	}
	Type type;
	Value value;
	this(FuncLocation loc) {
		type = Type.LOCATION;
		value.loc = loc;
	}
	this(Obj delegate(Vm, Obj[]) del) {
		type = Type.DELEGATE;
		value.del = del;
	}
	this(Obj function(Vm, Obj[]) fun) {
		type = Type.FUNCTION;
		value.fun = fun;
	}
}

// object types represented by the enum Type and Type type
struct Obj {
	enum Type {
		BOOL,
		NUMBER,
		LIST,
		FUNCTION,
		STRING,
		VOID,
	}
	Type type = Type.VOID;
	union Value {
		bool _bool;
		string _string;
		Obj[] _list;
		Func _func;
		double _number;
	}
	Value value;
	Obj clear() {
		type = Type.VOID;
		return this;
	}
	// these construct an object
	this(bool v) {
		type = Type.BOOL;
		value._bool = v; 
	}
	this(string v) {
		type = Type.STRING;
		value._string = v; 
	}
	this(double v) {
		type = Type.NUMBER;
		value._number = v; 
	}
	this(Obj[] v) {
		type = Type.LIST;
		value._list = v; 
	}
	this(Func v) {
		type = Type.FUNCTION;
		value._func = v; 
	}
	this(FuncLocation v) {
		type = Type.FUNCTION;
		value._func = v; 
	}
	this(Obj delegate(Vm, Obj[]) v) {
		type = Type.FUNCTION;
		value._func = Func(v); 
	}
	this(Obj function(Vm, Obj[]) v) {
		type = Type.FUNCTION;
		value._func = Func(v); 
	}
	// peek returns true if the type is what the template is given
	bool peek(T)() {
		static if (is(T == bool)) {
			return type == Type.BOOL;
		}
		static if (is(T == string)) {
			return type == Type.STRING;
		}
		static if (is(T == double)) {
			return type == Type.NUMBER;
		}
		static if (is(T == Obj[])) {
			return type == Type.LIST;
		}
		static if (is(T == Func)) {
			return type == Type.FUNCTION;
		}
		static if (is(T == void)) {
			return type == Type.VOID;
		}
		assert(0);
	}
	// get is used with peek mostly
	// it reads the value from Value value
	T get(T)() {
		static if (is(T == bool)) {
			return value._bool;
		}
		static if (is(T == string)) {
			return value._string;
		}
		static if (is(T == double)) {
			return value._number;
		}
		static if (is(T == Obj[])) {
			return value._list;
		}
		static if (is(T == Func)) {
			return value._func;
		}
		static if (is(T == FuncLocation)) {
			return value._func.value.loc;
		}
		static if (is(T == Obj delegate(Vm, Obj[]))) {
			return value._func.value.del;
		}
		static if (is(T == Obj function(Vm, Obj[]))) {
			return value._func.value.fun;
		}
	}
	// does not do recursivly to prevent stack overflow
	string toString() {
		if (peek!double) {
			return to!string(get!double);
		}
		if (peek!string) {
			return to!string(get!string);
		}
		if (peek!(Obj[])) {
			return to!string(get!(Obj[]));
		}
		if (peek!Func) {
			return "(function)";
		}
		if (peek!bool) {
			return to!string(get!bool);
		}
		return "(object "~ to!string(type) ~ ")";
	}
}

// used only from Func
class FuncLocation {
	ulong place;
	Obj*[string] cap;
	string[] argnames;
	Program owner;
	bool isglob;
	Obj[string] olocals = null;
	Obj opCall(Vm vm, Obj[] argind) {
		Obj[string] args;
		if (isglob) {
			args[argnames[0]] = Obj(argind);
		}
		else {
			foreach (t; zip(argind, argnames)) {
				args[t[1]] = t[0];
			}
		}
		foreach (c; cap.byKeyValue) {
			args[c.key] = *c.value;
		}
		if (olocals == null) {
			olocals = args;
		}
		return vm.run!true(owner, place, args);
	}
}

// calls an object with args
// handes all three function types
Obj call(Vm vm, Obj fn, Obj[] args) {
	Func func = fn.get!Func;
	if (func.type == Func.Type.LOCATION) {
		FuncLocation callable = func.value.loc;
		return callable(vm, args);
	}
	else if (func.type == Func.Type.DELEGATE) {
		Obj delegate(Vm vm, Obj[]) callable = func.value.del;
		return callable(vm, args);
	}
	else {
		Obj function(Vm vm, Obj[]) callable = func.value.fun;
		return callable(vm, args);
	}
}
