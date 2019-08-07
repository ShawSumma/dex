import std.conv;
import std.range;
import std.stdio;
import obj;
import node;
import lib;
import extend;
import swrite;
import sread;

enum OpcodeType {
	NAME,
	SPACE,
	STORE,
	LOAD,
	CONST,
	DUP,
	POP,
	FUNC,
	CALL,
	RET,
	JUMPF,
	JUMPT,
	JUMP,
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
	void emit(OpcodeType type, ulong value) {
		code ~= new Opcode(type, value);
	}
	void emit(OpcodeType type) {
		code ~= new Opcode(type, 0);
	}
	void walk(Node node) {
		NodeType type = node.type;
		if (type == NodeType.PROGRAM) {
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
				code[$-1].type = OpcodeType.RET;
			}
			else {
				emit(OpcodeType.CONST, consts.length);
				consts ~= new Obj(); 
				emit(OpcodeType.RET);
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
			consts ~= new Obj(node.value.num); 
		}
		if (type == NodeType.STRING) {
			emit(OpcodeType.CONST, consts.length);
			consts ~= new Obj(node.value.str); 
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
			if (node.value.nodes.length == 3) {
				walk(node.value.nodes[2]);
			}
			else {
				emit(OpcodeType.CONST, consts.length);
				consts ~= new Obj(); 
				emit(OpcodeType.RET);
			}
			code[jf].value = j;
			code[j].value = code.length-1;
		}
		if (type == NodeType.AND) {
			ulong[] jfp = [];
			foreach (i; node.value.nodes[0..$-1]) {
				walk(i);
				emit(OpcodeType.DUP);
				jfp ~= code.length;
				emit(OpcodeType.JUMPF);
				emit(OpcodeType.POP);
			}
			walk(node.value.nodes[$-1]);
			foreach (i; jfp) {
				code[i].value = code.length-1;
			}
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


class Vm {
	Obj[string][] locals;
	Obj[][] stack;
	ulong*[] ips;
	ulong*[] noreturns;
	Program[] programs;
	void define(string name, Obj value) {
		locals[$-1][name] = value;
	}
	void define(T)(string name, T value) {
		locals[$-1][name] = new Obj(name);
	}
	Obj run(Program program, ulong ip=0, Obj[string] mlocals=null) {
		return run!true(program, ip, mlocals, 0);
	}
	Obj run(bool init)(Program program=null, ulong ipv=0, Obj[string] mlocals=null, ulong noreturn=0) {
		noreturns ~= new ulong(noreturn);
		static if (init) {
			locals ~= mlocals;
			stack ~= cast(Obj[]) [];
			ips ~= new ulong(ipv);
			programs ~= program;
		}
		program = programs[$-1];
		while (true) {
			Opcode op = program.code[*ips[$-1]];
			writeln(stack[$-1]);
			writeln(op);
			final switch (op.type) {
				case OpcodeType.CALL: {
					Obj[] args = stack[$-1][$-op.value..$];
					stack[$-1].popBackN(op.value);
					Obj last = stack[$-1][$-1];
					stack[$-1].popBack;
					Obj got = call(this, last, args);
					stack[$-1] ~= got;
					break;
				}
				case OpcodeType.LOAD: {
					stack[$-1] ~= locals[$-1][program.strings[op.value]];
					break;
				}
				case OpcodeType.NAME: {
					if (program.strings[op.value] !in locals[$-1]) {
						locals[$-1][program.strings[op.value]] = get(this, program.strings[op.value]);
					}
					break;
				}
				case OpcodeType.CONST: {
					stack[$-1] ~= program.consts[op.value];
					break;
				}
				case OpcodeType.STORE: {
					locals[$-1][program.strings[op.value]] = stack[$-1][$-1];
					// stack[$-1][$-1] = new Obj();
					break;
				}
				case OpcodeType.POP: {
					stack[$-1].popBack;
					break;
				}
				case OpcodeType.DUP: {
					stack[$-1] ~= stack[$-1][$-1];
					break;
				}
				case OpcodeType.JUMPF: {
					Obj last = stack[$-1][$-1];
					stack[$-1].popBack;
					if (last.peek!void || (last.peek!bool && last.get!bool == false)) {
						*ips[$-1] = op.value;
					}
					break;
				}
				case OpcodeType.JUMPT: {
					Obj last = stack[$-1][$-1];
					stack[$-1].popBack;
					if (!last.peek!void || (last.peek!bool && last.get!bool == true)) {
						*ips[$-1] = op.value;
					}
					break;
				} 
				case OpcodeType.JUMP: {
					*ips[$-1] = op.value;
					break;
				} 
				case OpcodeType.FUNC: {
					ulong func = program.funclocs[op.value];
					Obj*[string] cap = null;
					foreach(i; program.funccaps[op.value]) {
						cap[i] = &locals[$-1][i];
					}
					FuncLocation loc;
					loc.cap = cap;
					loc.place = *ips[$-1]+1;
					loc.owner = program;
					loc.argnames = program.funcargnames[op.value];
					loc.isglob = program.isglobs[op.value];
					stack[$-1] ~= new Obj(loc);
					*ips[$-1] = func;
					break;
				}
				case OpcodeType.SPACE: {
					locals[$-1][program.strings[op.value]] = new Obj();
					break;
				}
				case OpcodeType.RET: {
					Obj last = stack[$-1][$-1];
					if (init || *noreturns[$-1] != 0) {
						stack.popBack;
						locals.popBack;
						ips.popBack;
						program = programs[$-1];
						programs.popBack;
					}
					if (*noreturns[$-1] == 0) {
						noreturns.popBack;
						return last;
					} 
					stack[$-1] ~= last;
					(*noreturns[$-1]) --;
					break;
				}
			}
			(*ips[$-1]) ++;
		}
	}
	ubyte[] write() {
		Serial s = new Serial();
		new Obj(locals).write(s);
		new Obj(stack).write(s);
		new Obj(ips).write(s);
		new Obj(programs).write(s);
		new Obj(noreturns).write(s);
		return s.refs;
	}
	this() {}
	this(ubyte[] bytes) {
		InputSerial s = InputSerial(bytes);
		locals = s.read().value._str_map_list;
		stack = s.read().value._list_list;
		ips = s.read().value._ulong_ptr_list;
		programs = s.read().value._program_list;
		noreturns = s.read().value._ulong_ptr_list;
		(*ips[$-1]) ++;
		stack[$-1] ~= new Obj(false);
	}
}