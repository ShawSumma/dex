import std.traits;
import std.stdio;
import obj;
import extend;
import vm;

struct InputSerial {
    ubyte[] code;
    ulong ind;
    Obj[ulong] objs;
    this(ubyte[] c) {
        code = c;
        // writeln(code);
        ind = 0;
    }
    U reint(U)() {
        ubyte[U.sizeof] val = code[ind..ind+U.sizeof];
        U ret = *cast(U*) &val;
        ind += U.sizeof;
        return ret;
    }
    Program readprog () {
        Opcode[] codes;
        foreach (i; 0..reint!ulong) {
            codes ~= new Opcode(cast(OpcodeType) reint!ubyte, reint!ulong);
        }
        Obj[] consts;
        foreach (i; 0..reint!ulong) {
            consts ~= read;
        }
        ulong[] count;
        foreach (i; 0..reint!ulong) {
            count ~= reint!ulong;
        }
        string[][] funcargnames;
        foreach (i; 0..reint!ulong) {
            string[] lvl;
            foreach (j; 0..reint!ulong) {
                char[] name;
                foreach (k; 0..reint!ulong) {
                    name ~= code[ind];
                    ind++;
                }
                lvl ~= cast(string) name;
            }
            funcargnames ~= lvl;
        }
        string[][] funccaps;
        foreach (i; 0..reint!ulong) {
            string[] lvl;
            foreach (j; 0..reint!ulong) {
                char[] name;
                foreach (k; 0..reint!ulong) {
                    name ~= code[ind];
                    ind++;
                }
                lvl ~= cast(string) name;
            }
            funccaps ~= lvl;
        }
        ulong[] funclocs;
        foreach (i; 0..reint!ulong) {
            funclocs ~= reint!ulong;
        }
        bool[] isglobs;
        foreach (i; 0..reint!ulong) {
            isglobs ~= code[ind] != 0;
            ind ++;
        }
        string[] strings;
        foreach (i; 0..reint!ulong) {
            char[] str;
            foreach (j; 0..reint!ulong) {
                str ~= code[ind];
                ind++;
            }
            strings ~= cast(string) str;
        }
        Program ret = new Program;
        ret.code = codes;
        ret.strings = strings;
        ret.consts = consts;
        ret.count = count;
        ret.funclocs = funclocs;
        ret.funccaps = funccaps;
        ret.funcargnames = funcargnames;
        ret.isglobs = isglobs;
        return ret;
    }
    Obj read() {
        ulong begin = code.length;
        Obj ret = reads;
        objs[begin] = ret;
        return ret;
    }
    Obj reads() {
        if (code[ind] == 0) {
            ind ++;
            return objs[reint!ulong];
        }
        alias Type = Obj.Type;
		Type got = cast(Type) code[ind];
        ind ++;
		final switch (got) {
            case Type.BOOL: {
                bool ret = code[ind] != 0;
                ind ++;
                return Obj(ret);
			}
			case Type.NUMBER: {
                return Obj(cast(double) reint!double);
			}
			case Type.LIST: {
                Obj[] list;
                foreach (i; 0..reint!ulong) {
                    list ~= read; 
                }
                return Obj(list);
			}
			case Type.FUNCTION: {
                Func.Type ty = cast(Func.Type) code[ind];
                ind ++;
                final switch (ty) {
                    case Func.Type.FUNCTION: {
                        ubyte[] str;
                        foreach (i; 0..reint!ulong) {
                            str ~= code[ind]; 
                            ind ++;
                        }
                        return readFetch(cast(string) str);
                    }
                    case Func.Type.DELEGATE: {
                        ubyte[] str;
                        foreach (i; 0..reint!ulong) {
                            str ~= code[ind]; 
                            ind ++;
                        }
                        Obj[] cap;
                        foreach (i; 0..reint!ulong) {
                            cap ~= read;
                        }
                        return readFetchDel(cast(string) str, cap);
                    }
                    case Func.Type.LOCATION: {
                        ulong place = reint!ulong;
                        bool isglob = code[ind] != 0;
                        ind ++;
                        string[] argnames;
                        foreach (n; 0..reint!ulong) {
                            ubyte[] str;
                            foreach (i; 0..reint!ulong) {
                                str ~= code[ind];
                                ind ++;
                            }
                            argnames ~= cast(string) str;
                        }
                        Obj*[string] cap;
                        foreach (n; 0..reint!ulong) {
                            ubyte[] str;
                            foreach (i; 0..reint!ulong) {
                                str ~= code[ind];
                                ind ++;
                            }
                            Obj *val = new Obj;
                            *val = read;
                            cap[cast(string) str] = val;
                        }
                        Program owner = readprog;
                        Func f;
                        f.type = Func.Type.LOCATION;
                        f.value.loc.place = place;
                        f.value.loc.isglob = isglob;
                        f.value.loc.argnames = argnames;
                        f.value.loc.cap = cap;
                        f.value.loc.owner = owner;
                        return Obj(f);
                    }
                }
			}
			case Type.STRING: {
                ubyte[] str;
                foreach (i; 0..reint!ulong) {
                    str ~= code[ind]; 
                    ind ++;
                }
                return Obj(cast(string) str);
			}
			case Type.VOID: {
                return Obj();
			}
			case Type.STR_MAP: {
                Obj[string] mapping;
                foreach (n; 0..reint!ulong) {
                    ubyte[] str;
                    foreach (i; 0..reint!ulong) {
                        str ~= code[ind];
                        ind ++;
                    }
                    mapping[cast(string) str] = read;
                }
                return Obj(mapping);
			}
			case Type.STR_MAP_LIST: {
                Obj[string][] maplist;
                foreach (m; 0..reint!ulong) {
                    Obj[string] mapping;
                    foreach (n; 0..reint!ulong) {
                        ubyte[] str;
                        foreach (i; 0..reint!ulong) {
                            str ~= code[ind];
                            ind ++;
                        }
                        mapping[cast(string) str] = read;
                    }
                    maplist ~= mapping;
                }
                return Obj(maplist);
			}
			case Type.LIST_LIST: {
                Obj[] llist;
                foreach (j; 0..reint!ulong) {
                    Obj[] list;
                    foreach (i; 0..reint!ulong) {
                        list ~= read; 
                    }
                }
                return Obj(llist);
			}
			case Type.ULONG_PTR_LIST: {
                ulong*[] ret;
                foreach (i; 0..reint!ulong) {
                    ret ~= new ulong(reint!ulong);
                }
                return Obj(ret);
			}
			case Type.PROGRAM_LIST: {
                Program[] ret;
                foreach (i; 0..reint!ulong) {
                    ret ~= readprog;
                }
                return Obj(ret);
			}
        }
        assert(0);
    }
}