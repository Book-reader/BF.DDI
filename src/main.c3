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
	lbos::print("Enter brainfuck file to open (must end in .BFF): ");
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

	File? file = fs::open_file((String)buf[:buf_ptr]);
	if (catch file)
	{
		lbos::print("File not found!\n");
		return 1;
	}

	Instructions program;
	InstructionType prev;
	ushort prev_repeats;
	while (try c = file.read_byte())
	{
		foreach (inst : InstructionType.values) if (c == inst.c)
		{
			if (inst.groupable)
			{
				if (prev == inst)
				{
					if (prev_repeats == MAX_LARGE_GROUP)
					{
						program.@append((InstructionGrouped){prev, true, prev_repeats});
						prev_repeats = 0;
					}
					prev_repeats ++;
				}
				else
				{
					if (prev_repeats > 0) switch
					{
						case prev_repeats <= MAX_SMALL_GROUP:
							program.@append((Instruction){prev, false, prev_repeats});
						default:
							program.@append((InstructionGrouped){prev, true, prev_repeats});
							
					}
					prev_repeats = 1;
				}
			}
			else
			{
				if (prev_repeats > 0) switch
				{
					case prev_repeats <= MAX_SMALL_GROUP:
						program.@append((Instruction){prev, false, prev_repeats});
					default:
						program.@append((InstructionGrouped){prev, true, prev_repeats});
						
				}
				prev_repeats = 0;
				program.@append((Instruction){inst, false, 1});
			}
			prev = inst;
			continue;
		}
	}
	defer if (program.blocks > 0) lbos::free_blocks((MemoryBlock)program.items, program.blocks);

	usz mem_ptr;

	while (program.idx < program.bytes)
	{
		Instruction* curr = program.@curr();

		switch (curr.type)
		{
			case ADD:
				memory[mem_ptr] = (char)(memory[mem_ptr] + curr.repeats());
			case SUB:
				memory[mem_ptr] = (char)(memory[mem_ptr] - curr.repeats());
			case NEXT:
				mem_ptr = (mem_ptr + curr.repeats()) % MEM_SIZE;
			case PREV:
				mem_ptr = (mem_ptr - curr.repeats()) % MEM_SIZE;
			case LOOP_START:
				if (memory[mem_ptr] != 0) break;
				usz num = 1;
				do
				{
					curr = program.@next();
					if (curr.type == LOOP_START) { num++; }
					else if (curr.type == LOOP_END) { num --; }
				} while (num != 0);
			case LOOP_END:
				if (memory[mem_ptr] == 0) break;
				usz num = 1;
				do
				{
					curr = program.@prev();
					if (curr.type == LOOP_END) { num++; }
					else if (curr.type == LOOP_START) { num --; }
				} while (num != 0);
			case READ:
				char c;
				while (lbos::read_input_buf((&c)[:1]) == 0);
				if (c == '\r') { memory[mem_ptr] = '\n'; }
				else { memory[mem_ptr] = c; }
				nextcase;
			case PRINT:
				lbos::printc(memory[mem_ptr]);
		}
		program.@next();
	}
	return 0;
}

const usz MEM_SIZE = 1000;
char[MEM_SIZE] memory;

macro ushort Instruction.repeats(&self) => self.large ? ((InstructionGrouped*)self).count : self.count;

struct Instructions
{
	char* items;
	usz bytes;
	usz idx;
	usz blocks;
}

macro Instructions.@append(#self, #val)
{
	#self.append_bytes($sizeof(#val), (char*)@addr(#val));
}

fn void Instructions.append_bytes(&self, usz len, char* dat)
{
	if (self.blocks == 0)
	{
		self.items = (char*)lbos::alloc_blocks(1);
		self.blocks = 1;
		self.items[:self.blocks * BLOCK_SIZE] = {};
	}
	else if (self.bytes + len >= self.blocks * BLOCK_SIZE)
	{
		usz new_blocks = self.blocks + 1;
		char* new_ptr = (char*)lbos::alloc_blocks(new_blocks);
		new_ptr[:self.blocks * BLOCK_SIZE] = self.items[:self.blocks * BLOCK_SIZE];
		lbos::free_blocks((MemoryBlock)self.items, self.blocks);
		self.items = new_ptr;
		self.blocks = new_blocks;
	}
	(self.items + self.bytes)[:len] = dat[:len];
	self.bytes += len;
}

macro Instruction* Instructions.@next(#self)
{
	#self.idx += /*#self.@curr().type.groupable && */#self.@curr().large ? InstructionGrouped.sizeof : Instruction.sizeof;
	return (Instruction*)(#self.items + #self.idx);
}

macro Instruction* Instructions.@prev(#self)
{
	#self.idx -= /*#self.@curr().type.groupable && */#self.@curr().large ? InstructionGrouped.sizeof : Instruction.sizeof;
	return (Instruction*)(#self.items + #self.idx);
}

macro Instruction* Instructions.@curr(#self)
{
	return (Instruction*)(#self.items + #self.idx);
}

// TODO: this causes the error `undefined reference to .tempglobal` when used
/*
<* @require #idx < #self.@len() *>
macro Instruction* Instructions.@get_ref(#self, usz #idx) @operator(&[]) => #self.items[#idx];
*/


// TODO: making these `@bigendian` causes a compiler assert (with this as char and InstructionGrouped as a ushort)
bitstruct Instruction : char // @bigendian
{
	InstructionType type : 0..2;
	bool large : 3;
	ushort count : 4..7;
}

bitstruct InstructionGrouped : ushort @align(1)
{
	InstructionType type : 0..2;
	bool large : 3;
	ushort count : 4..15;
}
const MAX_SMALL_GROUP = (1 << 4) - 1;
const MAX_LARGE_GROUP = (1 << 12) - 1;
$assert $defined((InstructionGrouped){.count = MAX_LARGE_GROUP}); // && !$defined((InstructionGrouped){.count = MAX_LARGE_GROUP + 1});
$assert $defined((Instruction){.count = MAX_SMALL_GROUP}); // && !$defined((InstructionGrouped){.count = MAX_SMALL_GROUP + 1});

// TODO: this segfaults the compiler:
// $assert ((InstructionGrouped)ushort.max).count == MAX_GROUP;

enum InstructionType : char (char c, bool groupable)
{
	NEXT       = { '>', true  },
	PREV       = { '<', true  },
	ADD        = { '+', true  },
	SUB        = { '-', true  },
	PRINT      = { '.', false }, // TODO: implement repeats for these 2
	READ       = { ',', false },  // ^
	LOOP_START = { '[', false },
	LOOP_END   = { ']', false },
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

/*<*
 @param [&out] dst
*>
fn void memset(char* dst, int c, usz len) @extern("memset") @nostrip
{
	do
	{
		*(dst++) = (char)c;
	} while (--len);
}*/

macro usz usz.div_ceil(self, usz other) => div_ceil(self, other);

macro div_ceil(a, b) => a / b + (a % b == 0 ? 0 : 1);

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
	for (usz j = 0, usz k = len - 1; j < k; j++, k--)
	{
		char temp = buf[j];
		buf[j] = buf[k];
		buf[k] = temp;
	}
	return (String)buf[:len];
}
