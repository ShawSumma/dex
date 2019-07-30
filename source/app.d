import std.stdio;
import std.file;
import std.algorithm;
import lib;
import obj;
import vm;
import parse;
import node;
import vm;

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
