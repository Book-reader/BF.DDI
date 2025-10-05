module liblbos::fs;
import liblbos::ktask;

const MAX_FILENAME = 12;

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
	char[MAX_FILENAME] name;
	RecordType type;
	// depends on FS implementation, shouldn't rely on
	uint target;
	uint total_size_bytes;
}

fn String Record.get_name(&self)
{
	// liblbos::print("get name");
	usz? idx = index_of_char(&self.name, 0);// n.index_of_char('\0');

	if (try i = idx)
	{
		liblbos::printlns("found idx ", xtoa((char[3]){}, i));
		return (String)self.name[:i];
	}
	liblbos::print("could not find '\\0'\n");
	return (String)self.name[..];
//	(String)self.name[:((String)&self.name).index_of_char('\0') ?? self.name.len];
}

fn usz? index_of_char(char[] str, char c)
{
	foreach (i, ch : str)
	{
		// liblbos::printc(ch);
		// liblbos::print(" : ");
		// liblbos::println(xtoa((char[3]){}, ch));
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
	liblbos::printlns("Opening file ", name);
	Record file_record;
	do
	{
		if (catch err = ktask::fs_read_dir(&fs, &dir, &file_record)) switch (err)
		{
			case ktask::EOF:
				//liblbos::print("EOF\n");
				return FILE_NOT_FOUND?;
			default:
				//liblbos::print("ERR\n");
				return UNKNOWN_ERR?;
		}
		liblbos::printlns("File name: '", file_record.get_name(), "'");
	} while (file_record.get_name() != name);
	if (file_record.type != FILE) return NOT_FILE?;

	File file;
	file.total_size_bytes = file_record.total_size_bytes;
	ktask::fs_open_file(&fs, &file_record, &file.reader)!;
	return file;
}

struct File
{
	FileReader reader;
	usz total_size_bytes;
}

fn char? File.read_byte(&self)
{
	char c;
	ktask::fs_read_file(&fs, &self.reader, (&c)[:1])!;
	return c;
}
