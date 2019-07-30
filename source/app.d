import std.stdio;
import std.variant;
import std.ascii;
import std.conv;
import std.algorithm;
import std.range;
import std.functional;
import std.file;
import std.range;
import std.traits;
import lib;
import errors;
import extend;

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
		// static if (is(T == Variant)) {
		// 	return type == Type.OTHER;
		// }
		assert(0);
	}
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
		// static if (is(T == Variant)) {
		// 	return value._other;
		// }
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
		return "(object "~ to!string(type) ~ ")";
	}
}

class FuncLocation {
	ulong place;
	Obj*[string] cap;
	string[] argnames;
	Program owner;
	bool isglob;
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
		return vm.run(owner, place, args);
	}
}

union NodeValue {
	string str;
	double num;
	Node[] nodes;
	this(string a) {
		str = a;
	}
	this(double a) {
		num = a;
	}
	this(Node[] a) {
		nodes = a;
	}
}

enum NodeType {
	LOAD,
	STORE,
	LAMBDA,
	IF,
	NUMBER,
	CALL,
	STRING,
	PROGRAM,
}

enum Require {
	ALWAYS,
	MUTABLE,
	NEVER
}

class Node {
	NodeType type;
	NodeValue value;
	Require[string] requires;
	this() {}
	this(NodeType t, NodeValue v) {
		type = t;
		value = v;
		final switch (t) {
			case NodeType.LOAD: {
				requires[v.str] = Require.ALWAYS;
				break;			
			}
			case NodeType.STORE: {
				requires = null;
				foreach (r; v.nodes[1].requires.byKeyValue){
					requires[r.key] = r.value;
				}
				requires[v.nodes[0].value.str] = Require.NEVER;
				break;
			}
			case NodeType.CALL: goto case;
			case NodeType.IF: goto case;
			case NodeType.PROGRAM: {
				foreach (n; v.nodes) {
					foreach (k; n.requires.byKeyValue) {
						if (k.key in requires) {
							Require cur = requires[k.key];
							if (requires[k.key] == Require.ALWAYS && k.value == Require.NEVER) {
								requires[k.key] = Require.MUTABLE;
							}
							else if (requires[k.key] == Require.ALWAYS && k.value == Require.MUTABLE) {
								requires[k.key] = Require.MUTABLE;
							}
						}
						else {
							requires[k.key] = k.value;
						}
					}
				}
				break;
			}
			case NodeType.LAMBDA: {
				Node[] code = v.nodes[1..$];
				Node args = v.nodes[0];
				string[] names = [];
				if (args.type == NodeType.LOAD) {
					names ~= args.value.str;
				} else {
					foreach(n; args.value.nodes) {
						names ~= n.value.str;
					}
				}
				foreach (n; code) {
					foreach (k; n.requires.byKeyValue) {
						if (k.key in requires) {
							if (requires[k.key] == Require.ALWAYS && k.value == Require.NEVER) {
								requires[k.key] = Require.MUTABLE;
							}
						}
						else {
							requires[k.key] = k.value;
						}
					}
				}
				foreach (name; names) {
					requires[name] = Require.NEVER;
				}
				break;
			}
			case NodeType.STRING: {
				break;
			}
			case NodeType.NUMBER: {
				break;
			}
		}
	}
	this(NodeType t) {
		type = t;
		requires = null;
	}
}

enum OpcodeType {
	INIT,
	NAME,
	SPACE,
	STORE,
	LOAD,
	CONST,
	POP,
	FUNC,
	CALL,
	RET,
	EXIT,
	JUMPF,
	JUMP
}

class Opcode {
	OpcodeType type;
	ulong value;
	this(OpcodeType t, ulong v) {
		type = t;
		value = v;
	}
	override string toString() {
		return "Opcode(" ~ to!string(type) ~ ", " ~ to!string(value) ~ ")";
	}
}

class Program {
	Opcode[] code = [];
	string[] strings;
	Obj[] consts = [];
	ulong[] count = [];
	ulong[] funclocs = [];
	string[][] funccaps = [];
	string[][] funcargnames = [];
	bool[] isglobs = [];
	ulong[2][] initnames = [];
	void emit(OpcodeType type, ulong value) {
		code ~= new Opcode(type, value);
	}
	void emit(OpcodeType type) {
		code ~= new Opcode(type, 0);
	}
	void walk(Node node) {
		NodeType type = node.type;
		if (type == NodeType.PROGRAM) {
			emit(OpcodeType.INIT);
			count ~= 0;
			foreach (r; node.requires.byKeyValue) {
				if (r.value != Require.NEVER) {
					emit(OpcodeType.NAME, strings.length);
					strings ~= r.key;
				}
			}
			foreach (r; node.requires.byKeyValue) {
				if (r.value == Require.NEVER) {
					emit(OpcodeType.SPACE, strings.length);
					strings ~= r.key;
				}
			}
			foreach (n; node.value.nodes) {
				walk(n);
				emit(OpcodeType.POP);
			}
			if (node.value.nodes.length > 0) {
				code[$-1].type = OpcodeType.EXIT;
			}
			else {
				emit(OpcodeType.CONST, consts.length);
				consts ~= Obj(); 
				emit(OpcodeType.EXIT);
			}
		}
		if (type == NodeType.CALL) {
			foreach (arg; node.value.nodes) {
				walk(arg);
			}
			emit(OpcodeType.CALL, node.value.nodes.length-1);
		}
		if (type == NodeType.LOAD) {
			emit(OpcodeType.LOAD, strings.length);
			strings ~= node.value.str;
		}
		if (type == NodeType.NUMBER) {
			emit(OpcodeType.CONST, consts.length);
			consts ~= Obj(node.value.num); 
		}
		if (type == NodeType.STRING) {
			emit(OpcodeType.CONST, consts.length);
			consts ~= Obj(node.value.str); 
		}
		if (type == NodeType.STORE) {
			walk(node.value.nodes[1]);
			emit(OpcodeType.STORE, strings.length);
			strings ~= node.value.nodes[0].value.str;
		}
		if (type == NodeType.IF) {
			walk(node.value.nodes[0]);
			ulong jf = code.length;
			emit(OpcodeType.JUMPF);
			walk(node.value.nodes[1]);
			ulong j = code.length;
			emit(OpcodeType.JUMP);
			walk(node.value.nodes[2]);
			code[jf].value = j;
			code[j].value = code.length-1;
		}
		if (type == NodeType.LAMBDA) {
			bool isglob = node.value.nodes[0].type == NodeType.LOAD;
			string[] funccap = [];
			string[] funcargname;
			if (isglob) {
				funcargname ~= node.value.nodes[0].value.str;
			}
			else {
				foreach (n; node.value.nodes[0].value.nodes) {
					funcargname ~= n.value.str;
				}
			}
			foreach (r; node.requires.byKeyValue) {
				if (r.value != Require.NEVER) {
					funccap ~= r.key;
				}
				if (r.value == Require.NEVER) {
					emit(OpcodeType.SPACE, strings.length);
					strings ~= r.key;
				}
			}
			ulong cp = code.length;
			emit(OpcodeType.FUNC);
			foreach (n; node.value.nodes[1..$]) {
				walk(n);
				emit(OpcodeType.POP);
			}
			code.popBack;
			emit(OpcodeType.RET);
			code[cp].value = funclocs.length;
			funccaps ~= funccap;
			isglobs ~= isglob;
			funcargnames ~= funcargname;
			funclocs ~= code.length-1;
		}
	}
}

Node parseNode(string str, ulong *index) {
	char get() {
		if (str.length == *index) {
			return '\0';
		}
		char ret = str[*index];
		*index += 1;
		return ret;
	}
	char peek() {
		if (str.length == *index) {
			return '\0';
		}
		return str[*index];
	}
	void undo() {
		*index -= 1;
	}
	void strip() {
		while (peek == '\t' || peek == '\r' || peek == ' ' || peek == '\n') {
			get;
		}
	}
	if (peek.isWhite) {
		get;
		return parseNode(str, index);
	}
	if (peek == '(') {
		Node[] ret = [];
		get;
		while (peek != ')') {
			ret ~= parseNode(str, index);
			strip;
		}
		get;
		if (ret.length != 0 && ret[0].type == NodeType.LOAD) {
			switch (ret[0].value.str) {
				case "define": {
					return new Node(NodeType.STORE, NodeValue(ret[1..$]));
				}
				case "lambda": {
					return new Node(NodeType.LAMBDA, NodeValue(ret[1..$]));
				}
				case "if": {
					return new Node(NodeType.IF, NodeValue(ret[1..$]));
				}
				default: {
					break;
				}
			}
		}
		return new Node(NodeType.CALL, NodeValue(ret));
	}
	if (peek == '"' || peek == '\'') {
		get;
		get;
		ulong depth = 1;
		char[] got = [];
		do {
			if (peek == '\0') {
				writeln("unexpeced end of input");
			}
			got ~= get;
			if (peek == '(') {
				depth ++;
			}
			if (peek == ')') {
				depth --;
			}
		} while (depth > 0);
		get;
		Node nv = new Node();
		nv.type = NodeType.STRING;
		nv.value.str = cast(string) got;
		return nv;
	}
	if (peek.isDigit) {
		char[] repr = [];
		while (peek.isDigit || peek == '.') {
			repr ~= get;
		}
		return new Node(NodeType.NUMBER, NodeValue(to!double(repr)));
	}
	char[] name = [];
	while (peek != '(' && peek != ')' && !peek.isWhite && peek != '"' && peek != '\0') {
		name ~= get;
	}
	return new Node(NodeType.LOAD, NodeValue(cast(string) name));
}

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

Node parse1(string code, ulong *index) {
	Node n = parseNode(code, index);
	while (*index != code.length && (code[*index] == '\t' || code[*index] == '\r' || code[*index] == ' ' || code[*index] == '\n')) {
		(*index) ++;
	}
	return new Node(NodeType.PROGRAM, NodeValue([n]));
}

Node parses(string str) {
	ulong index = 0;
	Node[] ret = [];
	while (index != str.length) {
		ret ~= parseNode(str, &index);
		while (index != str.length && (str[index] == '\t' || str[index] == '\r' || str[index] == ' ' || str[index] == '\n')) {
			index ++;
		}
	}
	return new Node(NodeType.PROGRAM, NodeValue(ret));
}

struct Vm {
	// Program program;
	Obj[string] lastlocals;
	Obj[string][] locals;
	void define(string name, Obj value) {
		lastlocals[name] = value;
	}
	void define(T)(string name, T value) {
		lastlocals[name] = Obj(name);
	}
	Obj run(Program program, ulong ip=0, Obj[string] mlocals=null) {
		locals ~= mlocals;
		Obj[] stack = [];
		while (true) {
			redo:
			Opcode op = program.code[ip];
			switch (op.type) {
				case OpcodeType.CALL: {
					Obj[] args = stack[$-op.value..$];
					stack.popBackN(op.value);
					stack[$-1] = call(this, stack[$-1], args);
					break;
				}
				case OpcodeType.LOAD: {
					stack ~= locals[$-1][program.strings[op.value]];
					break;
				}
				case OpcodeType.NAME: {
					if (program.strings[op.value] !in locals[$-1]) {
						locals[$-1][program.strings[op.value]] = get(this, program.strings[op.value]);
					}
					break;
				}
				case OpcodeType.CONST: {
					stack ~= program.consts[op.value];
					break;
				}
				case OpcodeType.STORE: {
					locals[$-1][program.strings[op.value]] = stack[$-1];
					break;
				}
				case OpcodeType.POP: {
					stack.popBack;
					break;
				}
				case OpcodeType.JUMPF: {
					Obj last = stack[$-1];
					stack.popBack;
					if (last.peek!void || (last.peek!bool == true && last.get!bool == false)) {
						ip = op.value;
					}
					break;
				} 
				case OpcodeType.JUMP: {
					ip = op.value;
					break;
				} 
				case OpcodeType.EXIT: {
					lastlocals = locals[$-1];
					locals.popBack;
					return stack[$-1];
				}
				case OpcodeType.FUNC: {
					ulong func = program.funclocs[op.value];
					Obj*[string] cap = null;
					foreach(i; program.funccaps[op.value]) {
						cap[i] = &locals[$-1][i];
					}
					FuncLocation loc = new FuncLocation;
					loc.cap = cap;
					loc.place = ip+1;
					loc.owner = program;
					loc.argnames = program.funcargnames[op.value];
					loc.isglob = program.isglobs[op.value];
					stack ~= Obj(loc);
					ip = func;
					break;
				}
				case OpcodeType.SPACE: {
					locals[$-1][program.strings[op.value]] = Obj();
					break;
				}
				case OpcodeType.RET: {
					locals.popBack;
					return stack[$-1];
				}
				case OpcodeType.INIT: {
					foreach (p; lastlocals.byKeyValue) {
						locals[$-1][p.key] = p.value;
					}
					break;
				}
				default: {
					writeln("unknown instruction ", op.type);
					assert(0);
				}
			}
			ip ++;
		}
	}
}

void main(string[] args) {
	if (args.length > 1) {
		ulong size = getSize(args[1]);
		char[] inp = new char[size+1];
		string text = cast(string) new File(args[1]).rawRead(inp);
		Node n = parses(text);
		Program program = new Program;
		program.walk(n);
		Vm vm = Vm();
		vm.run(program);
	}
	else {
		Vm vm = Vm();
		while (true) {
			Program program = new Program;
			write(">>> ");
			string inp = readln;
			while (count(inp, '(') - count(inp, ')') != 0) {
				write("... ");
				foreach(i; 0..count(inp, '(') - count(inp, ')')) {
					write("    ");
				}
				inp ~= readln;
			}
			Node n = parses(inp);
			program.walk(n);
			Obj got = vm.run(program, 0);
			if (!got.peek!void) {
				writeln(got);
			}
		}
	}
}
