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
	lbos::print("Enter file to open: ");
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
			lbos::print(@sprintf("\nFilename too long! max %s chars\n", fs::MAX_FILENAME));
			return 1;
		}
	}

	// lbos::printlns("\nOpening file '", (String)buf[:buf_ptr], "'\n");
	File? file = fs::open_file((String)buf[:buf_ptr]);
	if (catch file)
	{
		lbos::print("File not found!\n");
		return 1;
	}
	lbos::printlns("File size is: ", xtoa((char[10]){}, file.total_size_bytes), " bytes");
	usz block_count = div_ceil(file.total_size_bytes, BLOCK_SIZE);
	// lbos::println(xtoa((char[4]){}, block_count));
	char* data_buf = (char*)lbos::alloc_blocks(block_count);
	defer lbos::free_blocks((MemoryBlock)data_buf, block_count);

	// char prev_prev;
	Instructions program;
	char prev;
	while (try c = file.read_byte())
	{
		foreach (inst : InstructionType.values) if (inst.c == c)
		{
			if (inst.groupable && prev == c)
			{
				program.items[program.count - 1].count ++;
			}
			else
			{
				@da_append(program, {inst, 1});
			}
			// lbos::printc(c);
			prev = c;
			break;
		}
	}


	const MEM_SIZE = 200;
	char[MEM_SIZE] memory;
	usz prog_ptr, mem_ptr;
/*
	switch (InstructionType.NEXT)
	{
		case NEXT:
			
	}*/
	while (prog_ptr < program.count)
	{
		Instruction curr = program.items[prog_ptr];
		// lbos::printlns("\nexecuting ", curr.type.nameof, " count ", xtoa((char[10]){}, curr.count));
		switch (curr.type)
		{
			case ADD:
				memory[mem_ptr] = (char)(memory[mem_ptr] + curr.count);
			case SUB:
				memory[mem_ptr] = (char)(memory[mem_ptr] - curr.count);
			case NEXT:
				mem_ptr = (mem_ptr + curr.count) % MEM_SIZE;
			case PREV:
				mem_ptr = (mem_ptr - curr.count) % MEM_SIZE;
			case LOOP_START:
				if (memory[mem_ptr] != 0) break;
				usz num = 1;
				do
				{
					prog_ptr ++;
					if (program.items[prog_ptr].type == LOOP_START) { num++; }
					else if (program.items[prog_ptr].type == LOOP_END) { num --; }
				} while (num != 0);
			case LOOP_END:
				if (memory[mem_ptr] == 0) break;
				usz num = 1;
				do
				{
					prog_ptr --;
					if (program.items[prog_ptr].type == LOOP_END) { num++; }
					else if (program.items[prog_ptr].type == LOOP_START) { num --; }
				} while (num != 0);
			case READ:
				break;
			case PRINT:
				// lbos::print(xtoa((char[3]){}, memory[mem_ptr]));
				lbos::printc(memory[mem_ptr]);
		}
		prog_ptr ++;
	}
	return 0;
}

macro void @da_append(#da, #item)
{
	if (#da.items.len == 0)
	{
		// lbos::print("initialising!\n");
		#da.items = (($typeof(#da.items.ptr))lbos::alloc_blocks(1))[:BLOCK_SIZE / $typeof(#da.items.ptr).inner.sizeof];
		// lbos::printlns("initial len: ", xtoa((char[5]){}, #da.items.len));
	}
	else if (#da.count == #da.items.len)
	{
		// lbos::print("resizing!\n");
		usz new_capacity = #da.items.len * 2;
		usz new_block_count = new_capacity.div_ceil(BLOCK_SIZE);
		var new_ptr = ($typeof(#da.items.ptr))lbos::alloc_blocks(new_block_count);
		@noalias_copy(new_ptr, #da.items.ptr, #da.items.len);
		char[20] buf;
		// lbos::printlns("Old len: ", xtoa(&buf, #da.items.len), ", New len: ", xtoa(&buf, new_capacity));

		lbos::free_blocks((MemoryBlock)#da.items.ptr, #da.items.len.div_ceil(BLOCK_SIZE));
		#da.items = new_ptr[:new_capacity];
	}
	// lbos::print("appending!\n");
	#da.items[#da.count++] = #item;
}

// TODO: this is an awful hack, maybe @noalias doesn't work correctly on slices? if so that's probably a bug
macro void @noalias_copy(#a @noalias, #b @noalias, #len) => memcpy((char*)#a, (char*)#b, #len * $typeof(#a).inner.sizeof) @noinline;// #a[:#len] = #b[:#len];

struct Instructions
{
	Instruction[] items;
	usz count;
}

// epic
struct Instruction @packed
{
	InstructionType type;
	bitstruct : char[3]
	{
		uint count : 0..23;
	}
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
