import std.ascii;
import std.stdio;
import std.conv;
import core.stdc.stdlib;
import node;
import obj;
import vm;
import node;

class Info {
	ulong lineno = 1;
	ulong colno = 1;
	ulong index = 0;
	void got(char c) {
		if (c == '\n') {
			lineno ++;
			colno = 1;
		}
		else if (c == '\r') {
			colno = 1;
		}
		else {
			colno ++;
		}
		index ++;
	} 
}

// parser does not use tokens
Node parseNode(string str, Info info) {
	// get char and move forward
	char get() {
		if (str.length == info.index) {
			return '\0';
		}
		char ret = str[info.index];
		info.got(ret);
		return ret;
	}
	// get char and dont move forward
	char peek() {
		if (str.length == info.index) {
			return '\0';
		}
		return str[info.index];
	}
	// remove spaces
	void strip() {
		while (peek.isWhite) {
			get;
		}
	}
	strip;
	if (peek == ')') {
		writeln("error: syntax no opening item");
		exit(1);
	}
	// calls start with ( or [ and end with ] or )
	if (peek == '(' || peek == '[') {
		Node[] ret = [];
		get;
		while (peek != ')' && peek != ']') {
			if (peek == '\0') {
				writeln("error: syntax no closing item");
				exit(1);
			}
			ret ~= parseNode(str, info);
			strip;
		}
		get;
		if (ret.length != 0 && ret[0].type == NodeType.LOAD) {
			switch (ret[0].value.str) {
				case "define": {
					if (ret[1].type == NodeType.CALL) {
						Node name = ret[1].value.nodes[0];
						Node[] args = ret[1].value.nodes[1..$];
						Node[] code = ret[2..$];
						Node argv = new Node(NodeType.CALL, NodeValue(args));
						Node lambda = new Node(NodeType.LAMBDA, NodeValue([argv] ~ code));
						Node define = new Node(NodeType.STORE, NodeValue([name, lambda]));
						return define;
					}
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
	// strings are 
	if (peek == '"' || peek == '\'') {
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
		nv.value.str = cast(string) got[1..$];
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

Node parse1(string code, Info info) {
	Node n = parseNode(code, info);
	while (info.index != code.length && code[info.index].isWhite) {
		info.got(code[info.index]);
	}
	return new Node(NodeType.PROGRAM, NodeValue([n]));
}

Node parses(string str) {
	Info info = new Info();
	Node[] ret = [];
	while (info.index != str.length) {
		ret ~= parseNode(str, info);
		while (info.index != str.length && str[info.index].isWhite) {
			info.got(str[info.index]);
		}
	}
	return new Node(NodeType.PROGRAM, NodeValue(ret));
}