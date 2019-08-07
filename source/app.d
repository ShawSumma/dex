import std.stdio;
import std.file;
import std.algorithm;
import std.conv;
import lib;
import obj;
import vm;
import parse;
import node;
import vm;
import extend;
import std.net.curl;
import std.socket;
import core.stdc.stdlib;

void main(string[] args) {
	string dir = ".dex";
	if (canFind(args, "--fold")) {
		foreach(i; 0..args.length) {
			if (args[i] == "--fold") {
				dir = args[i+1];
				break;
			}
		}
	}
	if (args.length > 1 && args[1][0] != '-') {
		// file mode
		foreach (i; args[1..$]) {
			string text = cast(string) read(i);
			// parse multiple statments into a program
			// multiple expressions are comsumed
			Node n = parses(text);
			Program program = new Program;
			program.walk(n);
			Vm vm = new Vm();
			vm.run(program);
		}
	}
	else {
		string rfread() {
			return cast(string) read(dir ~ "/repl");
		}
		void rfwrite(string c) {
			File f = File(dir ~ "/repl", "wb");
			f.write(c);
		}
		Vm vm = new Vm();
		Obj[string] initlocals = [
			"goto": new Obj(cast(Obj[]) [])
		];
		vm.locals ~= initlocals;
		if (!canFind(args, "--new")) {
			vm.locals = new Vm(cast(ubyte[]) rfread()).locals;
			// vm = new Vm(cast(ubyte[]) rfread());
		}
		vm.ips ~= new ulong(0);
		vm.programs ~= new Program;
		vm.stack ~= [[]];
		ulong rpc = 0;
		Obj[] backs;
		while (true) {
			vm.locals[$-1]["goto"] = new Obj();
			ubyte[] back = vm.write();
			if (exists(dir ~ "repl")) {
				std.file.remove(dir ~ "/repl");
			}
			rfwrite(cast(string) back);
			backs ~= new Obj(cast(string) back);
			rpc ++;
			write("(", rpc, ")> ");
			string text = readln;
			while (count(text, '(') - count(text, ')') != 0) {
				write("... ");
				foreach (i; 0..count(text, '(')-count(text, ')')) {
					write("    ");
				}
				text ~= readln;
			}
			Node node = parses(text);
			Program program = new Program;
			program.walk(node);
			vm.programs[$-1] = program;
			*vm.ips[0] = 0;
			vm.locals = new Vm(cast(ubyte[]) rfread()).locals;
			vm.locals[$-1]["goto"] = new Obj(Func(&libreplback, backs, "repl.goto"));
			Obj got = vm.run!false;
			if (!got.peek!void) {
				writeln(got);
			}
		}
	}
}
