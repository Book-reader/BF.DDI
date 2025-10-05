module brainfuck;
import liblbos;

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
		if (buf_ptr >= lbos::MAX_FILENAME)
		{
			lbos::print(@sprintf("\nFilename too long! max %s chars\n", lbos::MAX_FILENAME));
			return 1;
		}
	}

	lbos::printlns("\nOpening file '", (String)buf[:buf_ptr], "'\n");
	File? file = fs::open_file((String)buf[:buf_ptr]);
	if (catch file)
	{
		lbos::print("File not found!\n");
		return 1;
	}
	return 0;
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

module std::core::builtin;
import std::math;
import liblbos;

macro xtoa(char[] buf, num) @builtin
{
	// liblbos::print("\nStarting xtoa\n");
	if (num == 0)
	{
		buf[0] = '0';
		return (String)buf[:1];
	}
	usz len = 0;

	// TODO: it could be a bug that `neg = num < 0` is both allowed & crashes(?) when passing an unsigned integer
	bool neg = $kindof(num) == SIGNED_INT ???  num < 0 : false;// num < 0;
	num = math::abs(num);

	while (num > 0)
	{
		buf[len++] = (char)(num % 10) + '0';
		num /= 10;
	}
	if (neg) buf[len++] = '-';
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
