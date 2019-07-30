import std.ascii;
import std.stdio;
import std.conv;
import node;
import obj;
import vm;
import node;

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