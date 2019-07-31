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
		// file mode
		// read file into exactly sized buffer
		ulong size = getSize(args[1]);
		char[] inp = new char[size+1];
		string text = cast(string) new File(args[1]).rawRead(inp);
		// parse multiple statments into a program
		// multiple expressions are comsumed
		Node n = parses(text);
		Program program = new Program;
		program.walk(n);
		Vm vm = Vm();
		vm.run(program);
	}
	else {
		// repl mode
		// use only one vm
		Vm vm = Vm();
		// dont exit until interuped
		while (true) {
			Program program = new Program;
			// the repl prompt is ">>> " because its 4 chars long
			write(">>> ");
			// read until all parenthesis are closed
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
			// run the bginning of the new program on the same vm
			Obj got = vm.run(program, 0);
			// if the obj has a value show it
			if (!got.peek!void) {
				writeln(got);
			}
		}
	}
}
