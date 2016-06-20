import std.stdio;
import std.experimental.logger;
import std.algorithm.comparison;
import std.string;
import std.getopt;

struct GlsEntry {
	string key;
	string shortForm;
	string longForm;
	string longPlural;
}

GlsEntry[string] parseGls(string filename) {
	import std.uni;
	import std.file : readText;

	GlsEntry[string] ret;

	string str = readText(filename);
	while(!str.empty) {
		if(isWhite(str[0])) {
			str = str[1 .. $];
		} else if(str.startsWith("\\newacronym")) {
			GlsEntry newEntry;
			enum lp = "[longplural={";
			auto idx = str.indexOf(lp);
			if(idx != -1) {
				auto end = str.indexOf("}]", idx);
				newEntry.longPlural = str[idx + lp.length .. end];
				str = str[end+2 .. $];
			}

			idx = str.indexOf("{");
			assert(idx != -1);
			auto end = str.indexOf("}", idx);
			assert(end != -1);

			newEntry.key = str[idx + 1 .. end];
			str = str[end .. $];

			idx = str.indexOf("{");
			assert(idx != -1);
			end = str.indexOf("}", idx);
			assert(end != -1);

			newEntry.shortForm = str[idx + 1 .. end];
			str = str[end .. $];

			idx = str.indexOf("{");
			assert(idx != -1);
			end = str.indexOf("}", idx);
			assert(end != -1);

			newEntry.longForm = str[idx + 1 .. end];
			str = str[end+1 .. $];

			ret[newEntry.key] = newEntry;
		} else {
			assert(false, str);
		}
	}

	return ret;
}

void main(string[] args) {
	string input;
	string output;
	string glsfile;

	auto hw = getopt(args, 
		"input|i", "The file to detex", &input, 
		//"output|o", "The output file to write the detex text to", &output, 
		"gls|g", "The glossary file to use", &glsfile
	);

	if(hw.helpWanted) {
		defaultGetoptPrinter(
			"Some information about the program.",
			hw.options
		);
		return;
	}

	if(input.empty) {
		log("No file to process passed.");
		return;
	}

	GlsEntry[string] glsEntries;
	if(!glsfile.empty) {
		glsEntries = parseGls(glsfile);
		log(glsEntries);
	}

	string beginEndState;

	bool documentHasBegan = false;
	auto file = File(input);
	foreach(line; file.byLineCopy(KeepTerminator.no)) {
		if(!documentHasBegan) {
			documentHasBegan = beginDocument(line);
			writeln();
			continue;
		}

		if(!beginEndState.empty) {
			string tmp = end(line);
			if(tmp == beginEndState) {
				beginEndState = "";
			}
			writeln();
			continue;
		} else {
			string tmp = begin(line);
			if(!tmp.empty) {
				beginEndState = tmp;
				writeln();
				continue;
			}
		}
		//writef("%s\n", line);
		processLine(line, glsEntries);
	}
}

void processLine(string line, GlsEntry[string] glsEntries) {
	long slice = 0;
	long sliceNew = 0;
	do {
		slice = sliceNew;
		sliceNew = surround!"\\Section{"(line, sliceNew);
		sliceNew = surround!"\\Subsection{"(line, sliceNew);
		sliceNew = surround!"\\Paragraph{"(line, sliceNew);
		sliceNew = surround!"\\emph{"(line, sliceNew);
		sliceNew = surround!"\\texttt{"(line, sliceNew);
		sliceNew = surround!"\\textbf{"(line, sliceNew);
		sliceNew = reference!"\\Rl{"(line, sliceNew);
		sliceNew = reference!"\\ref{"(line, sliceNew);
		sliceNew = math!("\\(","\\)")(line, sliceNew);
		sliceNew = math!("$","$")(line, sliceNew);
		sliceNew = glossar!("\\g{",false,false)(line, sliceNew, glsEntries);
		sliceNew = glossar!("\\gls{",false,false)(line, sliceNew, glsEntries);
		sliceNew = glossar!("\\glsfirst{",false,false)(line, sliceNew, glsEntries);
		sliceNew = glossar!("\\G{",false,true)(line, sliceNew, glsEntries);
		sliceNew = glossar!("\\Gls{",false,true)(line, sliceNew, glsEntries);
		sliceNew = glossar!("\\Gp{",true,true)(line, sliceNew, glsEntries);
		sliceNew = glossar!("\\Glspl{",true,true)(line, sliceNew, glsEntries);
		sliceNew = glossar!("\\gp{",true,false)(line, sliceNew, glsEntries);
		sliceNew = glossar!("\\glspl{",true,false)(line, sliceNew, glsEntries);
	} while(sliceNew > slice);
	writef("%s\n", line[slice .. $]);
}

long glossar(string skip,bool plural,bool cap)(string line, long start, 
		GlsEntry[string] glsEntries) 
{
	auto begin = line.indexOf(skip, start);
	if(begin != -1) {
		auto end = line.indexOf("}", begin + skip.length);
		if(end != -1) {
			writef("%s", line[0 .. begin]);
			line = line[begin + skip.length .. end];
			if(line in glsEntries) {
				static if(plural) {
					static if(cap) {
						writef("%s", 
							toUpper(glsEntries[line].longPlural.empty ?
								(glsEntries[line].longForm ~ "s") :
								glsEntries[line].longPlural
							)
						);
					} else {
						writef("%s", 
							glsEntries[line].longPlural.empty ?
								(glsEntries[line].longForm ~ "s") :
								glsEntries[line].longPlural
						);
					}
				} else {
					static if(cap) {
						writef("%s", 
							toUpper(glsEntries[line].longForm)
						);
					} else {
						writef("%s", 
							glsEntries[line].longForm
						);
					}
				}
			} else {
				writef("Undefined GLSENTRY");
			}
			print(' ', 1);
			return end + 1;
		}
	}

	return start;
}

void print(dchar c, long cnt) {
	for(uint i = 0; i < cnt; ++i) {
		writef("%s", c);
	}
}

long math(string beginT, string endT)(string line, long start) {
	auto begin = line.indexOf(beginT, start);
	if(begin != -1) {
		auto end = line.indexOf(endT, begin + beginT.length);
		if(end != -1) {
			writef("%s", line[0 .. begin]);
			print(' ', end - begin);
			write("M");
			return end + endT.length;
		}
	}

	return start;
}

long reference(string skip)(string line, long start) {
	void printRef(string line) {
		auto colonIdx = line.indexOf(':');
		if(colonIdx != -1) {
			if(line[0 .. colonIdx] == "sec") {
				write("Section A");
			} else if(line[0 .. colonIdx] == "fig") {
				write("Figure A");
			} else if(line[0 .. colonIdx] == "tab") {
				write("Table A");
			} else if(line[0 .. colonIdx] == "alg") {
				write("Algorithm A");
			}
		}
	}

	auto begin = line.indexOf(skip, start);
	if(begin != -1) {
		auto end = line.indexOf("}", begin + skip.length);
		if(end != -1) {
			writef("%s", line[0 .. begin]);
			line = line[begin + skip.length .. end];
			print(' ', skip.length);
			printRef(line);
			print(' ', 1);
			return end + 1;
		}
	}

	return start;
}

long surround(string skip)(string line, long start) {
	auto begin = line.indexOf(skip, start);
	if(begin != -1) {
		auto end = line.indexOf("}", begin + skip.length);
		if(end != -1) {
			writef("%s", line[0 .. begin]);
			line = line[begin + skip.length .. end];
			print(' ', skip.length);
			writef("%s", line);
			print(' ', 1);
			return end + 1;
		}
	}

	return start;
}

string begin(string line) {
	return beginEndImpl!"\\begin{"(line);
}

string end(string line) {
	return beginEndImpl!"\\end{"(line);
}

private string beginEndImpl(string be)(string line) {
	auto start = line.indexOf(be);
	if(start != -1) {
		auto end = line.indexOf("}", start);
		if(end != -1) {
			return line[start + be.length .. end];
		}
	}

	return "";
}

bool beginDocument(string line) {
	return line.indexOf("\\begin{document}") != -1;
}
