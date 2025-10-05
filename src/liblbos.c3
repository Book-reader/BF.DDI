module liblbos;

typedef TaskID = char;
typedef MemoryBlock = void*;

enum Syscall : const usz
{
	DO_NOTHING = 0,
	KERNEL_INFO = 1,
	CURRENT_TASK = 4,
	READ_INPUT_BUF = 5,
	WRITE_TERMINAL = 6,
	ALLOC_BLOCKS = 7,
	FREE_BLOCKS = 8,
	SEND_NOTIFICATION = 10,
	WAIT_FOR_NOTIFICATION = 11,
	PENDING_NOTIFICATIONS = 12,
	WAIT_FOR_NOTIFICATION_ACK = 13,
	ENVIRONMENT_POINTER = 14,
	DISABLE_FB_CONSOLE = 15,
	ENABLE_FB_CONSOLE = 16,
	FB_POINTER = 17,
	FLUSH_FB = 18,
	GET_CURRENT_KEYMAP = 19,
}

const SCREEN_WIDTH @builtin = 320;
const SCREEN_HEIGHT @builtin = 240;
const BLOCK_SIZE @builtin = 512;

struct Environment
{
	String current_directory_path;
}

typedef FrameBuffer = void*;
struct Colour @packed
{
	// Will be RGB888 on the actual hardware
	char a;
	char r;
	char g;
	char b;
}
// macro bool Colour.equals(self, Colour other) @operator(==) => self.a == other.a && self.r == other.r && self.g == other.g && self.b == other.b;

const Colour WHITE @builtin = {255, 255, 255, 255};
const Colour BLACK @builtin = {255, 0, 0, 0};
const Colour RED @builtin = {255, 255, 0, 0};
const Colour GREEN @builtin = {255, 0, 255, 0};
const Colour BLUE @builtin = {255, 0, 0, 255};

const INPUT_BUF_LEN = 32;
const MAX_FILENAME = 11;
const KEY_BACKSPACE = 0x7f;

<*
 @require x + width <= SCREEN_WIDTH
 @require y + height <= SCREEN_HEIGHT
*>
fn void FrameBuffer.fill_rect(self, usz x, usz y, usz width, usz height, Colour col/*, bool flush = false*/)
{
	for (usz ys = y; ys < y + height; ys++)
	{
		((Colour*)self)[ys * SCREEN_WIDTH + x:width] = col;
	}
	// if (flush) self.flush(x, y, width, height);
}
fn void FrameBuffer.trace_rect(self, usz x, usz y, usz width, usz height, Colour col, usz outline_width = 1/*, bool flush = false*/)
{
	// TODO: I could make this a lot more efficient
	self.fill_rect(x, y, width, outline_width, col/*, flush: flush*/); // @inline;
	self.fill_rect(x, y + height, width, outline_width, col/*, flush: flush*/); // @inline;
	self.fill_rect(x, y, outline_width, height + outline_width, col/*, flush: flush*/); // @inline;
	self.fill_rect(x + height, y, outline_width, height + outline_width, col/*, flush: flush*/); // @inline;
}

fn void FrameBuffer.set_pixel(self, ushort x, ushort y, Colour col/*, bool flush = false*/)
{
	((Colour*)self)[y * SCREEN_WIDTH + x] = col;
	// if (flush) self.flush(x, y, 1, 1);
}
// Saves some bytes as macros
macro void FrameBuffer.reset(self) => enable_fb();
macro void FrameBuffer.clear(self, Colour col)
{
	self.fill_rect(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT, col/*, flush: true*/);
	self.flush(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
}
// fn void FrameBuffer.clear_rect(self, usz x, usz y, usz width, usz height, bool flush = false) => self.fill_rect(x, y, width, height, WHITE, flush: flush);

// These are macros because it saves some bytes
<*
 @require x + width <= SCREEN_WIDTH
 @require y + height <= SCREEN_HEIGHT
*>
macro void FrameBuffer.flush(self, usz x, usz y, usz width, usz height) => flush_fb_rect(x, y, width, height);
macro void write_terminal(String str) => syscall(WRITE_TERMINAL, (usz)str.ptr, str.len);
macro MemoryBlock alloc_blocks(usz num_blocks) => (MemoryBlock)syscall(ALLOC_BLOCKS, num_blocks);
macro void free_blocks(MemoryBlock block, usz num_blocks) => syscall(FREE_BLOCKS, (usz)block, num_blocks);
macro void disable_fb() => syscall(DISABLE_FB_CONSOLE);
macro void enable_fb() => syscall(ENABLE_FB_CONSOLE);
<*
 @ensure (void*)return != null : "Failed to get FrameBuffer pointer"
*>
macro FrameBuffer get_fb() => (FrameBuffer)syscall(FB_POINTER);
macro void flush_fb_rect(usz x, usz y, usz w, usz h) => syscall(FLUSH_FB, x, y, w, h);
macro void get_keymap(KeyState* state) => syscall(GET_CURRENT_KEYMAP, (usz)state);
macro void get_kernel_info(KernelInfo* info) => syscall(KERNEL_INFO, (usz)info);
macro usz read_input_buf(char[] buf) => syscall(READ_INPUT_BUF, (usz)buf.ptr, buf.len);
macro usz send_notification(TaskID dst, MemoryBlock blk) => syscall(SEND_NOTIFICATION, (usz)dst, (usz)blk);
macro void wait_for_notif_ack(TaskID task) => syscall(WAIT_FOR_NOTIFICATION_ACK, (usz)task);
macro MemoryBlock wait_for_notification() => (MemoryBlock)syscall(WAIT_FOR_NOTIFICATION);
macro TaskID get_current_task() => (TaskID)syscall(CURRENT_TASK);
macro Environment* get_env_ptr() => (Environment*)syscall(ENVIRONMENT_POINTER);

// Saves ~30 bytes as a macro
macro void print(String str)
{
	write_terminal(str);
}

fn void println(String str)
{
	print(str);
	print("\n");
}

macro void printc(char c) => syscall(WRITE_TERMINAL, (usz)&c, 1);

macro void printlns(String... args)
{
	foreach (arg : args)
	{
		print(arg);
	}
	print("\n");
}

fn usz syscall(Syscall syscall, usz a1 = 0, usz a2 = 0, usz a3 = 0, usz a4 = 0, usz a5 = 0, usz a6 = 0) @naked @noinline
{
	asm
	(`
		ecall
		ret
	`);
}

struct KeyState
{
	bitstruct : ushort
	{
		bool esc;
		bool key1;
		bool key2;
		bool key3;
		bool key4;
		bool key5;
		bool key6;
		bool key7;
		bool key8;
		bool key9;
		bool key0;
		bool minus;
		bool equal;
		bool backspace;
		bool tab;
		bool enter;
	}
	bitstruct : uint
	{
		bool a;
		bool b;
		bool c;
		bool d;
		bool e;
		bool f;
		bool g;
		bool h;
		bool i;
		bool j;
		bool k;
		bool l;
		bool m;
		bool n;
		bool o;
		bool p;
		bool q;
		bool r;
		bool s;
		bool t;
		bool u;
		bool v;
		bool w;
		bool x;
		bool y;
		bool z;
	}
	bitstruct : ushort
	{
		bool left_bracket;
		bool right_bracket;
		bool semicolon;
		bool apostrophe;
		bool grave;
		bool backslash;
		bool comma;
		bool dot;
		bool slash;
		bool space;
		bool control;
		bool shift;
		bool alt;
	}
	bitstruct : ushort
	{
		bool up_arrow;
		bool down_arrow;
		bool left_arrow;
		bool right_arrow;
	}
}
// Saves some bytes as a macro
macro void KeyState.update(&self) => get_keymap(self);

struct KernelInfo
{
	usz current_process_count;
	usz total_mem_blocks;
	usz free_mem_blocks;
}

alias PanicFn = fn void(String, String, String, uint);
PanicFn panic = fn (message, file, function, line)
{
	// lbos::printlns("Panic: \"", message, "\" in \"", file, "\":\"", function, "\"");
	printlns("\nPANIC!: ", message);
	while (true);
};

macro abort(String message) @builtin @noreturn
{
	panic(message, "", "", 0);
}
