module brainfuck;
import liblbos;
import common;

alias lbos = module liblbos;

fn isz _start() @extern("_start") @nostrip
{
	// Enable floats
	asm
	{
		li $t0, 1 << 13;
		csrrs $zero, $mstatus, $t0;
	}
	return main() @noinline;
}

fn isz main()
{
	fs::init()!!;

	char[lbos::INPUT_BUF_LEN] buf;
	usz buf_ptr = 0;
	// lbos::print("Enter file to open: ");
	while OUTER: (true)
	{
		usz diff = lbos::read_input_buf(buf[buf_ptr..]);
		foreach (c : buf[buf_ptr:diff])
		{
			if (c == '\r')
			{
				lbos::print("\n");
				break OUTER;
			}
			else if (c == lbos::KEY_BACKSPACE)
			{
				if (buf_ptr > 0)
				{
					lbos::print("\x08 \x08");
					buf_ptr --;
				}
				diff --;
			}
			else { lbos::printc(c); }
		}
		buf_ptr += diff;
		if (buf_ptr > fs::MAX_FILENAME)
		{
			//lbos::print(@sprintf("\nFilename too long! max %s chars\n", fs::MAX_FILENAME));
			return 1;
		}
	}

	// lbos::printlns("\nOpening file '", (String)buf[:buf_ptr], "'\n");
	File? file = fs::open_file((String)buf[:buf_ptr]);
	if (catch file)
	{
		//lbos::print("File not found!\n");
		return 1;
	}
	// lbos::printlns("File size is: ", xtoa((char[10]){}, file.total_size_bytes), " bytes");
	usz block_count = div_ceil(file.total_size_bytes, BLOCK_SIZE);
	// lbos::println(xtoa((char[4]){}, block_count));
	char* data_buf = (char*)lbos::alloc_blocks(block_count);
	defer lbos::free_blocks((MemoryBlock)data_buf, block_count);

	// char prev_prev;
	Instructions program;
	char prev;
	while (try c = file.read_byte())
	{
		foreach (inst : InstructionType.values) if (c == inst.c)
		{
			if (inst.groupable && prev == c && program.items[program.count - 1].count < $typeof((Instruction){}.count).max)
			{
				program[^1].count ++;
			}
			else
			{
				@da_append(program, {inst, 1});
			}
			prev = c;
			// lbos::printc(c);
			break;
		}
	}
	// lbos::print("\n");


	usz prog_ptr, mem_ptr;
/*
	switch (InstructionType.NEXT)
	{
		case NEXT:
			
	}*/
	while (prog_ptr < program.count)
	{
		Instruction curr = program[prog_ptr];
		// lbos::printlns((String){curr.type.c}, ":", xtoa((char[10]){}, curr.count));
		// lbos::printc(curr.type.c); lbos::print(":"); lbos::print(xtoa((char[3]){}, curr.count)); lbos::print(";");
		switch (curr.type)
		{
			case ADD:
				memory[mem_ptr] = (char)(memory[mem_ptr] + curr.count);
			case SUB:
				memory[mem_ptr] = (char)(memory[mem_ptr] - curr.count);
			case NEXT:
				/*if (curr.count + mem_ptr >= MEM_SIZE)
				{
					lbos::printlns("overflow, adding ", xtoa((char[10]){}, curr.count), " to ", xtoa((char[5]){}, mem_ptr), " at idx ", xtoa((char[10]){}, prog_ptr), " len is ", xtoa((char[10]){}, program.count));
					mem_ptr = (mem_ptr + curr.count) % (MEM_SIZE - 1);
					// lbos::printlns("result ", xtoa(&buf1, mem_ptr));
				}
				else*/
				{
					mem_ptr = (mem_ptr + curr.count) % (MEM_SIZE - 1);
				}
				// if (mem_ptr >= MEM_SIZE - 30) lbos::printlns("ptr: ", xtoa((char[8]){}, mem_ptr));
			case PREV:
				//if (curr.count > mem_ptr) lbos::print("underflow\n");
				mem_ptr = (mem_ptr - curr.count) % (MEM_SIZE - 1);
				// if (mem_ptr >= MEM_SIZE - 30) lbos::printlns("ptr: ", xtoa((char[8]){}, mem_ptr));
			case LOOP_START:
				if (memory[mem_ptr] != 0) break;
				usz num = 1;
				do
				{
					prog_ptr ++;
					if (program[prog_ptr].type == LOOP_START) { num++; }
					else if (program[prog_ptr].type == LOOP_END) { num --; }
				} while (num != 0);
			case LOOP_END:
				if (memory[mem_ptr] == 0) break;
				usz num = 1;
				do
				{
					prog_ptr --;
					if (program[prog_ptr].type == LOOP_END) { num++; }
					else if (program[prog_ptr].type == LOOP_START) { num --; }
				} while (num != 0);
			case READ:
				break;
			case PRINT:
				// lbos::print(xtoa((char[3]){}, memory[mem_ptr]));
				/*if (memory[mem_ptr] < 127) */lbos::printc(memory[mem_ptr]);
		}
		prog_ptr ++;
	}
	return 0;
}

const usz MEM_SIZE = 200;
char[MEM_SIZE] memory;

macro void @da_append(#da, #item)
{
	var $Type = $typeof(#da.items);
	const ITEM_SIZE = $Type.inner.sizeof;
	if (#da.blocks == 0)
	{
		#da.items = ($Type)lbos::alloc_blocks(1);
		#da.blocks = 1;
		//#da.capacity = BLOCK_SIZE / ITEM_SIZE;
		#da.items[:#da.blocks * BLOCK_SIZE / ITEM_SIZE] = {};
	}
/*	else if (#da.count >= #da.capacity)
	{
		usz new_blocks = #da.blocks * 2;
		usz new_capacity = #da.blocks * BLOCK_SIZE / ITEM_SIZE;
		new_ptr[:#da.blocks * BLOCK_SIZE / ITEM_SIZE] = #da.items[:#da.blocks * BLOCK_SIZE / ITEM_SIZE];
	}*/
	else if (#da.count * ITEM_SIZE > #da.blocks * BLOCK_SIZE / ITEM_SIZE)
	{
		usz new_blocks = #da.blocks + 1;
		var new_ptr = ($Type)lbos::alloc_blocks(new_blocks);
		new_ptr[:#da.blocks * BLOCK_SIZE / ITEM_SIZE] = #da.items[:#da.blocks * BLOCK_SIZE / ITEM_SIZE];

		lbos::free_blocks((MemoryBlock)#da.items, #da.blocks);
		// lbos::printlns("Old len: ", xtoa((char[7]){}, #da.blocks * BLOCK_SIZE / ITEM_SIZE), ", New len: ", xtoa((char[7]){}, new_blocks * BLOCK_SIZE / ITEM_SIZE));

		#da.items = new_ptr;
		#da.blocks = new_blocks;

/*		foreach (item : #da)
		{
			lbos::printc(item.type.c);
			lbos::print(" ");
			lbos::println(xtoa((char[10]){}, item.count));
		}*/
	}
	#da.items[#da.count++] = #item;

/*	if (#da.capacity == 0)
	{
		// lbos::print("initialising!\n");
		#da.items = ($Type)lbos::alloc_blocks(1);
		#da.capacity = BLOCK_SIZE / ITEM_SIZE;
		// #da.blocks = 1;
		#da.items[:#da.capacity] = {};
		// lbos::printlns("initial len: ", xtoa((char[5]){}, #da.items.len));
	}
	else if (#da.count == #da.capacity)
	{
		// lbos::printlns("resizing at idx ", xtoa((char[5]){}, #da.count));
		usz new_capacity = #da.capacity * 2; // #da.capacity + #da.capacity / 2; // * 1.5
		usz new_block_count = (new_capacity * ITEM_SIZE).div_ceil(BLOCK_SIZE);
		var new_ptr = ($Type)lbos::alloc_blocks(new_block_count);
		new_ptr[:new_capacity] = {};
		new_ptr[:#da.count] = #da.items[:#da.count];

		// lbos::printlns("Old len: ", xtoa((char[7]){}, #da.capacity), ", New len: ", xtoa((char[7]){}, new_capacity));

		defer lbos::free_blocks((MemoryBlock)#da.items, (#da.capacity * ITEM_SIZE).div_ceil(BLOCK_SIZE));
		#da.items = new_ptr;
		#da.capacity = new_capacity;

		foreach (item : #da)
		{
			lbos::printc(item.type.c);
			lbos::print(" ");
			lbos::println(xtoa((char[10]){}, item.count));
//			lbos::printlns();
		}
	}
	#da.items[#da.count++] = #item;*/
}

// TODO: this is an awful hack, maybe @noalias doesn't work correctly on slices? if so that's probably a bug
// macro void @noalias_copy(#a @noalias, #b @noalias, #len) => memcpy((char*)#a, (char*)#b, #len * $typeof(#a).inner.sizeof) @noinline;// #a[:#len] = #b[:#len];

struct Instructions
{
	Instruction*/*[]*/ items;
	usz count;
	// usz capacity;
	usz blocks;
}

macro usz Instructions.@len(#self) @operator(len) => #self.count;
<* @require #idx < #self.@len() *>
macro Instruction Instructions.@get(#self, usz #idx) @operator([]) => #self.items[#idx];
<* @require #idx < self.@len() *>
macro Instruction* Instructions.@get_ref(&self, usz #idx) @operator(&[]) => &self.items[#idx];
<* @require #idx < #self.@len() *>
macro void Instructions.@set(#self, usz #idx, Instruction #val) @operator([]=) => #self.items[#idx] = #val;

// TODO: this causes the error `undefined reference to .tempglobal`
/*
<* @require #idx < #self.@len() *>
macro Instruction* Instructions.@get_ref(#self, usz #idx) @operator(&[]) => #self.items[#idx];
*/


// epic
struct Instruction // @packed
{
	InstructionType type;
	// ushort count;
	// char count;
	/*bitstruct : char[3]
	{
		uint count : 0..23;
	}*/
}

enum InstructionType : char (char c, bool groupable)
{
	NEXT = { '>', true },
	PREV = { '<', true },
	ADD = { '+', true },
	SUB = { '-', true },
	PRINT = { '.', false }, // TODO: implement repeats for these 2
	READ = { ',', false },  // ^
	LOOP_START = { '[', false },
	LOOP_END = { ']', false },
	// NEXT = { 0xff, false },
}

fn void memcpy(char* dst, char* src, usz len) @extern("memcpy") @nostrip
{
	// this probably works
	do
	{
		*(dst++) = *(src++);
	} while (--len);
}

// Safety :)
fn void memmove(char* dst @noalias, char* src @noalias, usz len) @extern("memmove") @nostrip => memcpy(dst, src, len);

<*
 @param [&out] dst
*>
fn void memset(char* dst, int c, usz len) @extern("memset") @nostrip
{
	do
	{
		*(dst++) = (char)c;
	} while (--len);
}

fn usz usz.div_ceil(self, usz other) => div_ceil(self, other);

macro div_ceil(a, b) => a / b + (a % b == 0 ? 0 : 1);

// module std::core::builtin;
module common; // I cannot use std::core::builtin because with `--emit-stdlib=no` it deletes the function impls
import std::math;
import liblbos;

fn String xtoa(char[] buf, usz num) @builtin
{
	// liblbos::print("\nStarting xtoa\n");
	if (num == 0)
	{
		buf[0] = '0';
		return (String)buf[:1];
	}
	usz len = 0;

	// TODO: it could be a bug that `neg = num < 0` is both allowed & crashes(?) when passing an unsigned integer
	// bool neg = $kindof(num) == SIGNED_INT ???  num < 0 : false;// num < 0;
	// num = math::abs(num);

	while (num > 0)
	{
		buf[len++] = (char)(num % 10) + '0';
		num /= 10;
	}
	// if (neg) buf[len++] = '-';
	/*foreach (i, c : buf[:len / 2])
	{
		buf[i] = buf[len - i - 1];
		buf[len - i - 1] = c;
	}*/
	for (usz j = 0, usz k = len - 1; j < k; j++, k--)
	{
		char temp = buf[j];
		buf[j] = buf[k];
		buf[k] = temp;
	}
	return (String)buf[:len];
}
