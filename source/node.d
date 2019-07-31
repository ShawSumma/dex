
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
	// the value is always needed
	ALWAYS,
	// the value is needed but may be changed
	MUTABLE,
	// the value is nil and will be changed
	NEVER
}

class Node {
	NodeType type;
	NodeValue value;
	// this is what the node requires
	Require[string] requires;
	this() {}
	this(NodeType t, NodeValue v) {
		type = t;
		value = v;
		final switch (t) {
			// loads always start as always needed
			case NodeType.LOAD: {
				requires[v.str] = Require.ALWAYS;
				break;			
			}
			// stores make it not needed
			case NodeType.STORE: {
				requires = null;
				foreach (r; v.nodes[1].requires.byKeyValue){
					requires[r.key] = r.value;
				}
				requires[v.nodes[0].value.str] = Require.NEVER;
				break;
			}
			// call if and program are all similar
			// they merge all nodes' requires
			case NodeType.CALL: goto case;
			case NodeType.IF: goto case;
			case NodeType.PROGRAM: {
				foreach (n; v.nodes) {
					foreach (k; n.requires.byKeyValue) {
						if (k.key in requires) {
							Require cur = requires[k.key];
							// if anything overlaps
							// if always and never overlap they make mutable
							if (requires[k.key] == Require.ALWAYS && k.value == Require.NEVER) {
								requires[k.key] = Require.MUTABLE;
							}
							// if always and mutable overlap they make mutable
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
			// lambdas do alot of what if call and program do
			// lambdas are also defines for their own arguemnts
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
			// string does not interact with names ever
			case NodeType.STRING: {
				break;
			}
			// number does not interact with names
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
