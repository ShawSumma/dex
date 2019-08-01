import std.conv;
import std.range;
import std.stdio;
import obj;
import node;
import lib;
import extend;

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


struct Vm {
	Obj[string] lastlocals;
	Obj[string][] locals;
	Obj[][] stack = [];
	ulong*[] ips = [];
	Program[] programs = [];
	void define(string name, Obj value) {
		lastlocals[name] = value;
	}
	void define(T)(string name, T value) {
		lastlocals[name] = Obj(name);
	}
	Obj run(Program program, ulong ip=0, Obj[string] mlocals=null) {
		return run!true(program, ip, mlocals);
	}
	Obj run(bool init)(Program program, ulong ipv=0, Obj[string] mlocals=null) {
		ulong *ip = new ulong(ipv);
		static if (init) {
			locals ~= mlocals;
			Obj[] nex = [];
			stack ~= nex;
			ips ~= ip;
			programs ~= program;
		}
		while (true) {
			Opcode op = program.code[*ip];
			// writeln(op);
			final switch (op.type) {
				case OpcodeType.CALL: {
					Obj[] args = stack[$-1][$-op.value..$];
					stack[$-1].popBackN(op.value);
					Obj last = stack[$-1][$-1];
					stack[$-1].popBack;
					stack[$-1] ~= call(this, last, args);
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
					break;
				}
				case OpcodeType.POP: {
					stack[$-1].popBack;
					break;
				}
				case OpcodeType.JUMPF: {
					Obj last = stack[$-1][$-1];
					stack[$-1].popBack;
					if (last.peek!void || (last.peek!bool == true && last.get!bool == false)) {
						*ip = op.value;
					}
					break;
				} 
				case OpcodeType.JUMP: {
					*ip = op.value;
					break;
				} 
				case OpcodeType.EXIT: {
					Obj[] last = stack[$-1];
					static if (init) {
						lastlocals = locals[$-1];
						locals.popBack;
						stack.popBack;
						ips.popBack;
						programs.popBack;
					}
					return last[$-1];
				}
				case OpcodeType.FUNC: {
					ulong func = program.funclocs[op.value];
					Obj*[string] cap = null;
					foreach(i; program.funccaps[op.value]) {
						cap[i] = &locals[$-1][i];
					}
					FuncLocation loc;
					loc.cap = cap;
					loc.place = *ip+1;
					loc.owner = program;
					loc.argnames = program.funcargnames[op.value];
					loc.isglob = program.isglobs[op.value];
					stack[$-1] ~= Obj(loc);
					*ip = func;
					break;
				}
				case OpcodeType.SPACE: {
					locals[$-1][program.strings[op.value]] = Obj();
					break;
				}
				case OpcodeType.RET: {
					Obj[] last = stack[$-1];
					static if (init) {
						stack.popBack;
						locals.popBack;
						ips.popBack;
						programs.popBack;
					}
					return last[$-1];
				}
				case OpcodeType.INIT: {
					foreach (p; lastlocals.byKeyValue) {
						locals[$-1][p.key] = p.value;
					}
					break;
				}
			}
			(*ip) ++;
		}
	}
	Obj state() {
		Obj[string] ll = lastlocals.dup;
		Obj[string][] l = locals.dup;
		Obj[][] s = stack.dup;
		ulong*[] i = [];
		foreach (v; ips) {
			i ~= new ulong(*v);
		}
		Program[] p = programs.dup;
		Obj function(Vm, Obj[], Obj[]) ret = &saveStateVm;
		(*i[$-1]) ++;
		Obj[] args = [
			Obj(),
			Obj(ll),
			Obj(l),
			Obj(i),
			Obj(p),
			Obj(s)
		];
		args[0] = Obj(Func(ret, args, "vm.state"));
		return args[0];
	}
}