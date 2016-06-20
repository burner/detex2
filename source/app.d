import std.stdio;
import std.experimental.logger;
import std.algorithm.comparison;
import std.string;

struct GlsEntry {
	string key;
	string shortForm;
	string longForm;
}

void main(string[] args) {
	if(args.length < 2) {
		log("No file to process passed.");
		return;
	}

	GlsEntry[string] glsEntries;

	string beginEndState;

	bool documentHasBegan = false;
	auto file = File(args[1]);
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
		processLine(line, null);
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
	} while(sliceNew > slice);
	writef("%s\n", line[slice .. $]);
}

void print(dchar c, uint cnt) {
	for(uint i = 0; i < cnt; ++i) {
		writef("%s", c);
	}
}

long surround(string skip)(string line, long start) {
	auto begin = line.indexOf(skip, start);
	if(begin != -1) {
		auto end = line.indexOf("}", begin + skip.length);
		if(end != -1) {
			writef("%s", line[0 .. begin]);
			line = line[begin + skip.length .. end];
			print(' ', skip.length);
			//writef("%s", line[begin + skip.length .. end]);
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
