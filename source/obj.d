import std.conv;
import std.range;
import std.stdio;
import std.algorithm;
import vm;
import swrite;

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
		FuncDelegate del;
		Obj function(Vm, Obj[]) fun;
	}
	Type type;
	Value value;
	string name;
	this(FuncLocation loc) {
		type = Type.LOCATION;
		value.loc = loc;
		name = "";
	}
	this(Obj function(Vm, Obj[], Obj[]) del, Obj[] o, string n) {
		type = Type.DELEGATE;
		value.del = FuncDelegate(del, o);
		name = n;
	}
	this(Obj function(Vm, Obj[]) fun, string n) {
		type = Type.FUNCTION;
		value.fun = fun;
		name = n;
	}
}

// object types represented by the enum Type and Type type
struct Obj {
	enum Type {
		VOID = 1,
		BOOL,
		NUMBER,
		LIST,
		FUNCTION,
		STRING,
		// other
		STR_MAP,
		STR_MAP_LIST,
		LIST_LIST,
		ULONG_PTR_LIST,
		PROGRAM_LIST,
	}
	Type type = Type.VOID;
	union Value {
		bool _bool;
		string _string;
		Obj[] _list;
		Func _func;
		double _number;
		// others
		Obj[string][] _str_map_list;
		Obj[string] _str_map;
		Obj[][] _list_list;
		ulong*[] _ulong_ptr_list;
		Program[] _program_list;
	}
	Value value;
	Obj clear() {
		type = Type.VOID;
		return this;
	}
	// these construct an object
	this(Obj[string][] v) {
		type = Type.STR_MAP_LIST;
		value._str_map_list = v; 
	}
	this(Obj[string] v) {
		type = Type.STR_MAP;
		value._str_map = v; 
	}
	this(Obj[][] v) {
		type = Type.LIST_LIST;
		value._list_list = v; 
	}
	this(ulong *[] v) {
		type = Type.ULONG_PTR_LIST;
		value._ulong_ptr_list = v; 
	}
	this(Program[] v) {
		type = Type.PROGRAM_LIST;
		value._program_list = v; 
	}
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
		value._func = Func(v); 
	}
	this(Obj function(Vm, Obj[], Obj[]) v, Obj[] c, string n) {
		type = Type.FUNCTION;
		value._func = Func(v, c, n); 
	}
	this(Obj function(Vm, Obj[]) v, string n) {
		type = Type.FUNCTION;
		value._func = Func(v, n); 
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
		static if (is(T == FuncDelegate)) {
			return value._func.value.del;
		}
		static if (is(T == Obj function(Vm, Obj[]))) {
			return value._func.value.fun;
		}
		assert(0);
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
	void write(Serial state) {
		void o(T)(T v) {
			serial(state, v);
		}
		if (!state.add(this)) {
			o(cast(ulong) 0);
			o(state.objs[this]);
			return;
		}
		state.refs ~= cast(ubyte) type;
		final switch (type) {
			case Type.BOOL: {
				o(value._bool);
				break;
			}
			case Type.NUMBER: {
				o(value._number);
				break;
			}
			case Type.LIST: {
				o(value._list);
				break;
			}
			case Type.FUNCTION: {
				state.refs ~= cast(ubyte) value._func.type;
				final switch (value._func.type) {
					case Func.Type.LOCATION: {
						FuncLocation loc = value._func.value.loc;
						o(loc.place);
						o(loc.isglob);
						o(loc.argnames);
						o(loc.cap);
						o(loc.owner);
						break;
					}
					case Func.Type.FUNCTION: {
						o(value._func.name);
						break;
					}
					case Func.Type.DELEGATE: {
						FuncDelegate del = value._func.value.del;
						o(value._func.name);
						o(del.farg);
						break;
					}
				}
				break;
			}
			case Type.STRING: {
				o(value._string);
				break;
			}
			case Type.VOID: {
				break;
			}
			case Type.STR_MAP: {
				o(value._str_map);
				break;
			}
			case Type.STR_MAP_LIST: {
				o(value._str_map_list);
				break;
			}
			case Type.LIST_LIST: {
				o(value._list_list);
				break;
			}
			case Type.ULONG_PTR_LIST: {
				o(value._ulong_ptr_list);
				break;
			}
			case Type.PROGRAM_LIST: {
				o(value._program_list);
				break;
			}
		}
	}
}

struct FuncDelegate {
	Obj function(Vm, Obj[], Obj[]) del;
	Obj[] farg;
	this(Obj function(Vm, Obj[], Obj[]) f, Obj[] o) {
		del = f;
		farg = o;
	}
	Obj opCall(Vm vm, Obj[] args) {
		return del(vm, args, farg);
	}
}

// used only from Func
struct FuncLocation {
	bool isglob;
	ulong place;
	string[] argnames;
	Program owner;
	Obj*[string] cap;
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
		FuncDelegate callable = func.value.del;
		return callable(vm, args);
	}
	else {
		Obj function(Vm vm, Obj[]) callable = func.value.fun;
		return callable(vm, args);
	}
}
