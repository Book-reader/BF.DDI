module liblbos::fs;
import liblbos::ktask;

const MAX_FILE_NAME = 12;

faultdef FILE_NOT_FOUND, NOT_FILE, UNKNOWN_ERR;

enum RecordType : const char
{
	NONE,
	DIRECTORY,
	FILE,
	UNKNOWN,
}

typedef FileSystem = char[32];
typedef DirectoryReader = char[32];
typedef FileReader = char[32];

struct Record
{
	char[MAX_FILE_NAME] name;
	RecordType type;
	// depends on FS implementation, shouldn't rely on
	uint target;
	uint total_size_bytes;
}

macro String Record.get_name(&self)
{
	// liblbos::print("get name");
	String n = (String)&self.name;
	usz? idx = index_of_char(n, '\0');// n.index_of_char('\0');

	if (try i = idx)
	{
		// liblbos::print("found idx\n");
		return (String)self.name[:i];
	}
	// liblbos::print("could not find '\\0'\n");
	return (String)&self.name;
//	(String)self.name[:((String)&self.name).index_of_char('\0') ?? self.name.len];
}

fn usz? index_of_char(String str, char c)
{
	foreach (i, ch : str)
	{
		if (ch == c) return i;
	}
	return NOT_FOUND?;
}

/*tlocal*/ FileSystem fs;

fn /*FileSystem*/void? init()
{
	// FileSystem fs;
	ktask::fs_open(&fs)!;
	// return fs;
}

alias File = FileReader;

<*
 @require name.len > 0
*>
fn File? open_file(String name)
{
	if (name[0] == '/')
	{
		liblbos::abort("TODO: absolute paths");
	}

	DirectoryReader dir;
	// Environment* env = liblbos::get_env_ptr();

	ktask::fs_open_dir(&fs, &dir, /*env.current_directory_path*/"/")!;
	Record file_record;
	do
	{
		if (catch err = ktask::fs_read_dir(&fs, &dir, &file_record)) switch (err)
		{
			case ktask::EOF:
				liblbos::print("EOF\n");
				return FILE_NOT_FOUND?;
			default:
				liblbos::print("ERR\n");
				return UNKNOWN_ERR?;
		}
	} while (file_record.get_name() != name);
	if (file_record.type != FILE) return NOT_FILE?;

	File reader;
	ktask::fs_open_file(&fs, &file_record, &reader)!;
	return reader;
}

/*fn String utoa(char[] a, usz b) @noinline
{
	liblbos::print("\nf\n");
	return xtoa(a, b);
}*/
