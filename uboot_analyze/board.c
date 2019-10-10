/*
 * (C) Copyright 2002-2006
 * Wolfgang Denk, DENX Software Engineering, wd@denx.de.
 *
 * (C) Copyright 2002
 * Sysgo Real-Time Solutions, GmbH <www.elinos.com>
 * Marius Groeger <mgroeger@sysgo.de>
 *
 * See file CREDITS for list of people who contributed to this
 * project.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 * MA 02111-1307 USA
 */

/*
 * To match the U-Boot user interface on ARM platforms to the U-Boot
 * standard (as on PPC platforms), some messages with debug character
 * are removed from the default U-Boot build.
 *
 * Define DEBUG here if you want additional info as shown below
 * printed upon startup:
 *
 * U-Boot code: 00F00000 -> 00F3C774  BSS: -> 00FC3274
 * IRQ Stack: 00ebff7c
 * FIQ Stack: 00ebef7c
 */
/*
   2016.1.15---------------------------此文件为arch/arm/lib/board.c,分析board_init_f函数
   2016.1.16---------------------------从注释27继续分析board_init_f函数, 进行到注释52
   2016.1.17---------------------------从注释53开始分析board_init_r函数, 进行到注释67
   2016.1.18---------------------------从注释68继续分析board_init_r函数, 进行到注释75
   2016.1.19---------------------------从注释76继续分析board_init_r函数, 进行到注释
*/
 
#include <common.h>
#include <command.h>
#include <malloc.h>
#include <stdio_dev.h>
#include <version.h>
#include <net.h>
#include <serial.h>
#include <nand.h>
#include <onenand_uboot.h>
#include <mmc.h>
#include <libfdt.h>
#include <fdtdec.h>
#include <post.h>
#include <logbuff.h>

#ifdef CONFIG_BITBANGMII
#include <miiphy.h>
#endif

#ifdef CONFIG_DRIVER_SMC91111
#include "../drivers/net/smc91111.h"
#endif
#ifdef CONFIG_DRIVER_LAN91C96
#include "../drivers/net/lan91c96.h"
#endif

DECLARE_GLOBAL_DATA_PTR;

ulong monitor_flash_len;

#ifdef CONFIG_HAS_DATAFLASH
extern int  AT91F_DataflashInit(void);
extern void dataflash_print_info(void);
#endif

#if defined(CONFIG_HARD_I2C) || \
    defined(CONFIG_SOFT_I2C)
#include <i2c.h>
#endif

/************************************************************************
 * Coloured LED functionality
 ************************************************************************
 * May be supplied by boards if desired
 */
inline void __coloured_LED_init(void) {}
void coloured_LED_init(void)
	__attribute__((weak, alias("__coloured_LED_init")));
inline void __red_led_on(void) {}
void red_led_on(void) __attribute__((weak, alias("__red_led_on")));
inline void __red_led_off(void) {}
void red_led_off(void) __attribute__((weak, alias("__red_led_off")));
inline void __green_led_on(void) {}
void green_led_on(void) __attribute__((weak, alias("__green_led_on")));
inline void __green_led_off(void) {}
void green_led_off(void) __attribute__((weak, alias("__green_led_off")));
inline void __yellow_led_on(void) {}
void yellow_led_on(void) __attribute__((weak, alias("__yellow_led_on")));
inline void __yellow_led_off(void) {}
void yellow_led_off(void) __attribute__((weak, alias("__yellow_led_off")));
inline void __blue_led_on(void) {}
void blue_led_on(void) __attribute__((weak, alias("__blue_led_on")));
inline void __blue_led_off(void) {}
void blue_led_off(void) __attribute__((weak, alias("__blue_led_off")));

/*
 ************************************************************************
 * Init Utilities							*
 ************************************************************************
 * Some of this code should be moved into the core functions,
 * or dropped completely,
 * but let's get it working (again) first...
 */

#if defined(CONFIG_ARM_DCC) && !defined(CONFIG_BAUDRATE)
#define CONFIG_BAUDRATE 115200
#endif

static int init_baudrate(void)
{
	gd->baudrate = getenv_ulong("baudrate", 10, CONFIG_BAUDRATE);
	return 0;
}

static int display_banner(void)
{
	printf("\n\n%s\n\n", version_string);
	debug("U-Boot code: %08lX -> %08lX  BSS: -> %08lX\n",
	       _TEXT_BASE,
	       _bss_start_ofs + _TEXT_BASE, _bss_end_ofs + _TEXT_BASE);
#ifdef CONFIG_MODEM_SUPPORT
	debug("Modem Support enabled\n");
#endif
#ifdef CONFIG_USE_IRQ
	debug("IRQ Stack: %08lx\n", IRQ_STACK_START);
	debug("FIQ Stack: %08lx\n", FIQ_STACK_START);
#endif

	return (0);
}

/*
 * WARNING: this code looks "cleaner" than the PowerPC version, but
 * has the disadvantage that you either get nothing, or everything.
 * On PowerPC, you might see "DRAM: " before the system hangs - which
 * gives a simple yet clear indication which part of the
 * initialization if failing.
 */
static int display_dram_config(void)
{
	int i;

#ifdef DEBUG
	puts("RAM Configuration:\n");

	for (i = 0; i < CONFIG_NR_DRAM_BANKS; i++) {
		printf("Bank #%d: %08lx ", i, gd->bd->bi_dram[i].start);
		print_size(gd->bd->bi_dram[i].size, "\n");
	}
#else
	ulong size = 0;

	for (i = 0; i < CONFIG_NR_DRAM_BANKS; i++)
		size += gd->bd->bi_dram[i].size;

	puts("DRAM:  ");
	print_size(size, "\n");
#endif

	return (0);
}

#if defined(CONFIG_HARD_I2C) || defined(CONFIG_SOFT_I2C)
static int init_func_i2c(void)
{
	puts("I2C:   ");
	i2c_init(CONFIG_SYS_I2C_SPEED, CONFIG_SYS_I2C_SLAVE);
	puts("ready\n");
	return (0);
}
#endif

#if defined(CONFIG_CMD_PCI) || defined (CONFIG_PCI)
#include <pci.h>
static int arm_pci_init(void)
{
	pci_init();
	return 0;
}
#endif /* CONFIG_CMD_PCI || CONFIG_PCI */

/*
 * Breathe some life into the board...
 *
 * Initialize a serial port as console, and carry out some hardware
 * tests.
 *
 * The first part of initialization is running from Flash memory;
 * its main purpose is to initialize the RAM so that we
 * can relocate the monitor code to RAM.
 */

/*
 * All attempts to come up with a "common" initialization sequence
 * that works for all boards and architectures failed: some of the
 * requirements are just _too_ different. To get rid of the resulting
 * mess of board dependent #ifdef'ed code we now make the whole
 * initialization sequence configurable to the user.
 *
 * The requirements for any new initalization function is simple: it
 * receives a pointer to the "global data" structure as it's only
 * argument, and returns an integer return code, where 0 means
 * "continue" and != 0 means "fatal error, hang the system".
 */
typedef int (init_fnc_t) (void);

int print_cpuinfo(void);

void __dram_init_banksize(void)
{
	gd->bd->bi_dram[0].start = CONFIG_SYS_SDRAM_BASE;
	gd->bd->bi_dram[0].size =  gd->ram_size;
}
void dram_init_banksize(void)
	__attribute__((weak, alias("__dram_init_banksize")));

int __arch_cpu_init(void)
{
	return 0;
}
int arch_cpu_init(void)
	__attribute__((weak, alias("__arch_cpu_init")));

// 注释11. 函数指针数组init_sequence
init_fnc_t *init_sequence[] = {
// 注释12. arch_cpu_init函数没有单独写, 所以用了调用了弱函数(arch/arm/lib/board.c), 直接返回0
	arch_cpu_init,		/* basic arch cpu dependent setup */
// 注释13. CONFIG_BOARD_EARLY_INIT_F未定义, 不调用board_early_init_f函数
#if defined(CONFIG_BOARD_EARLY_INIT_F)
	board_early_init_f,
#endif
// 注释14. CONFIG_OF_CONTROL未定义, 不调用fdtdec_check_fdt函数
#ifdef CONFIG_OF_CONTROL
	fdtdec_check_fdt,
#endif
// 注释15. 调用timer_init函数(在arch/arm/cpu/arm1176/s3c64xx/time.c中)，初始化定时器4为10ms循环一次, 用定时器4是因为它没输出
	timer_init,		/* initialize timer */
// 注释16. CONFIG_BOARD_POSTCLK_INIT 未定义，不调用board_postclk_init函数
#ifdef CONFIG_BOARD_POSTCLK_INIT
	board_postclk_init,
#endif
// 注释17. CONFIG_FSL_ESDHC未定义, 不调用get_clocks函数
#ifdef CONFIG_FSL_ESDHC
	get_clocks,
#endif
// 注释18. 调用env_init函数(common/env_nand.c), 查找环境变量, 填充gd结构体里的env_valid与env_addr
	env_init,		/* initialize environment */
// 注释19. 调用init_baudrate函数(arch/arm/lib/board.c), 从环境变量数组中找到波特率(115200), 并填充gd->baudrate
	init_baudrate,		/* initialze baudrate settings */
// 注释20. 调用serial_init函数(在drivers/serial/s3c64xx.c中), 初始化UART0
	serial_init,		/* serial communications setup */
// 注释21. 调用console_init_f函数(common/console.c), 填充gd->have_console
	console_init_f,		/* stage 1 init of console */
// 注释22. 调用display_banner函数(arch/arm/lib/board.c, 有调试部分), 向UART0输出uboot版本等信息, 没有定义DEBUG这个宏定义, 没有输出调试信息
	display_banner,		/* say that we are here */
// 注释23. CONFIG_DISPLAY_CPUINFO 在smdk6400.h中定义, 调用print_cpuinfo函数(arch/arm/cpu/arm1176/s3c64xx/speed.c), 
//         输出CPU频率(532MHz), FCLK(266MHz),HCLK(133MHz),PCLK(66MHz),异步模式(OTHERS寄存器)
#if defined(CONFIG_DISPLAY_CPUINFO)
	print_cpuinfo,		/* display cpu info (and speed) */
#endif
// 注释24. CONFIG_DISPLAY_BOARDINFO 在smdk6400.h中定义, 调用checkboard函数(board/samsung/smdk6400/smdk6400.c), 输出板级信息
#if defined(CONFIG_DISPLAY_BOARDINFO)
	checkboard,		/* display board info */
#endif
// 注释25. CONFIG_HARD_I2C与CONFIG_SOFT_I2C 没有定义, 不调用init_func_i2c函数
#if defined(CONFIG_HARD_I2C) || defined(CONFIG_SOFT_I2C)
	init_func_i2c,
#endif
// 注释26. 调用dram_init函数(board/samsung/smdk6400/smdk6400.c), 从DRAM中获取内存大小, 并填充到gd->ram_size
//          获取内存大小方法是先向DRAM填充一堆数据再取出来, 对比之前的数据, 数据一样的地址代表可以存取
	dram_init,		/* configure available RAM banks */
	NULL,
};

// 注释1. 由start.S进入此函数, 参数bootflag = 0x00000000
void board_init_f(ulong bootflag)
{
	bd_t *bd;
	init_fnc_t **init_fnc_ptr;
	gd_t *id;
	ulong addr, addr_sp;
// 注释2. 未定义reg变量
#ifdef CONFIG_PRAM
	ulong reg;
#endif

// 注释3. bootstage_mark_name函数在common/bootstage.c中定义, 这里是填充结构体struct bootstage_record record[BOOTSTAGE_ID_START_UBOOT_F]
	bootstage_mark_name(BOOTSTAGE_ID_START_UBOOT_F, "board_init_f");

	/* Pointer is writable since we allocated a register for it */
// 注释4. 将CONFIG_SYS_INIT_SP_ADDR赋给gd, 就是用来填充IRAM里128字节里的结构体struct global_data,
	gd = (gd_t *) ((CONFIG_SYS_INIT_SP_ADDR) & ~0x07);
	/* compiler optimization barrier needed for GCC >= 3.4 */
	__asm__ __volatile__("": : :"memory");

// 注释5. memset是在lib/string.c中定义, 为global_data结构体清0
	memset((void *)gd, 0, sizeof(gd_t));

// 注释6. _bbs_end_ofs 在arch/arm/cpu/arm1176/start.S中定义的
	gd->mon_len = _bss_end_ofs;
// 注释7. CONFIG_OF_EMBED未定义, CONFIG_OF_SEPARATE未定义, 直接过去
#ifdef CONFIG_OF_EMBED
	/* Get a pointer to the FDT */
	gd->fdt_blob = _binary_dt_dtb_start;
#elif defined CONFIG_OF_SEPARATE
	/* FDT is at end of image */
	gd->fdt_blob = (void *)(_end_ofs + _TEXT_BASE);
#endif
// 注释8. getenv_ulong函数是寻找uboot环境变量组(common/env_common.c的default_environment)里的参数, 
//        如果找到则赋给fdt_blob, 但是没找到fdtcontroladdr这个参数
	/* Allow the early environment to override the fdt address */
	gd->fdt_blob = (void *)getenv_ulong("fdtcontroladdr", 16,
						(uintptr_t)gd->fdt_blob);
// 注释9. 这里是调用函数指针数组init_sequence中的每个指针指向的函数, 如果函数没返回0, 则调用hang(), 这个函数会用串口提示错误, 并陷入死循环
	for (init_fnc_ptr = init_sequence; *init_fnc_ptr; ++init_fnc_ptr) {
		// 注释10. 分析函数指针数组init_sequence, 就在本源文件里
		if ((*init_fnc_ptr)() != 0) {
			hang ();
		}
	}

// 注释27. CONFIG_OF_CONTROL 未定义, 不进去
#ifdef CONFIG_OF_CONTROL
	/* For now, put this check after the console is ready */
	if (fdtdec_prepare_fdt()) {
		panic("** CONFIG_OF_CONTROL defined but no FDT - please see "
			"doc/README.fdt-control");
	}
#endif

// 注释28. 因为没有定义DEBUG这个宏定义, 所以debug函数不输出任何信息
	debug("monitor len: %08lX\n", gd->mon_len);
	/*
	 * Ram is setup, size stored in gd !!
	 */
	debug("ramsize: %08lX\n", gd->ram_size);
// 注释29. CONFIG_SYS_MEM_TOP_HIDE 未定义, 不进入
#if defined(CONFIG_SYS_MEM_TOP_HIDE)
	/*
	 * Subtract specified amount of memory to hide so that it won't
	 * get "touched" at all by U-Boot. By fixing up gd->ram_size
	 * the Linux kernel should now get passed the now "corrected"
	 * memory size and won't touch it either. This should work
	 * for arch/ppc and arch/powerpc. Only Linux board ports in
	 * arch/powerpc with bootwrapper support, that recalculate the
	 * memory size from the SDRAM controller setup will have to
	 * get fixed.
	 */
	gd->ram_size -= CONFIG_SYS_MEM_TOP_HIDE;
#endif

// 注释30. addr = CONFIG_SYS_SDRAM_BASE + gd->ram_size = 0x50000000 + 0x10000000 = 0x60000000
	addr = CONFIG_SYS_SDRAM_BASE + gd->ram_size;

// 注释31. CONFIG_LOGBUFFER 未定义, 不进入
#ifdef CONFIG_LOGBUFFER
#ifndef CONFIG_ALT_LB_ADDR
	/* reserve kernel log buffer */
	addr -= (LOGBUFF_RESERVE);
	debug("Reserving %dk for kernel logbuffer at %08lx\n", LOGBUFF_LEN,
		addr);
#endif
#endif

// 注释32. CONFIG_PRAM未定义, 不进入
#ifdef CONFIG_PRAM
	/*
	 * reserve protected RAM
	 */
	reg = getenv_ulong("pram", 10, CONFIG_PRAM);
	addr -= (reg << 10);		/* size is in kB */
	debug("Reserving %ldk for protected RAM at %08lx\n", reg, addr);
#endif /* CONFIG_PRAM */

// 注释33. CONFIG_SYS_ICACHE_OFF与CONFIG_SYS_DCACHE_OFF都没定义, 进入
#if !(defined(CONFIG_SYS_ICACHE_OFF) && defined(CONFIG_SYS_DCACHE_OFF))
	/* reserve TLB table */
// 注释34. addr -= (4096 * 4) = 0x60000000 - 0x4000 = 0x5fffc000
	addr -= (4096 * 4);

// 注释35. addr &= ~(0x10000 - 1) = 0x5fffc000 & 0xffff0000 = 0x5fff0000
	/* round down to next 64 kB limit */
	addr &= ~(0x10000 - 1);

// 注释36. 填充gd->tlb_addr, 拿64KB空间来存储TLB(传输旁路缓冲器), debug函数因没定义DEBUG不输出任何信息
	gd->tlb_addr = addr;
	debug("TLB table at: %08lx\n", addr);
#endif

// 注释37. addr &= ~(4096 - 1) = 0x5fff0000 & 0xfffff000 = 0x5fff0000, 还不知道要来干嘛的, debug函数因没定义DEBUG不输出任何信息
	/* round down to next 4 kB limit */
	addr &= ~(4096 - 1);
	debug("Top of RAM usable for U-Boot at: %08lx\n", addr);

// 注释38. CONFIG_LCD未定义, 不进入
#ifdef CONFIG_LCD
#ifdef CONFIG_FB_ADDR
	gd->fb_base = CONFIG_FB_ADDR;
#else
	/* reserve memory for LCD display (always full pages) */
	addr = lcd_setmem(addr);
	gd->fb_base = addr;
#endif /* CONFIG_FB_ADDR */
#endif /* CONFIG_LCD */

	/*
	 * reserve memory for U-Boot code, data & bss
	 * round down to next 4 kB limit
	 */
// 注释39. addr = (0x5fff0000 - _bss_end_ofs) & (fffff000), 应该是为将uboot拷贝到addr而腾出的空间吧, debug函数因没定义DEBUG不输出任何信息
	addr -= gd->mon_len;
	addr &= ~(4096 - 1);

	debug("Reserving %ldk for U-Boot at: %08lx\n", gd->mon_len >> 10, addr);

// 注释40. CONFIG_SPL_BUILD 未定义, 进入
#ifndef CONFIG_SPL_BUILD
	/*
	 * reserve memory for malloc() arena
	 */
// 注释41. addr_sp = addr - TOTAL_MALLOC_LEN = addr - 0x108000, 这0x108000大小的空间是用来以后malloc函数用的, debug函数因没定义DEBUG不输出任何信息
	addr_sp = addr - TOTAL_MALLOC_LEN;
	debug("Reserving %dk for malloc() at: %08lx\n",
			TOTAL_MALLOC_LEN >> 10, addr_sp);
	/*
	 * (permanently) allocate a Board Info struct
	 * and a permanent copy of the "global" data
	 */
// 注释42. addr_sp -= sizeof (bd_t) = addr_sp - 0x8, 这8*4字节空间存储gd->bd的板级信息(struct bd_info), debug函数因没定义DEBUG不输出任何信息
	addr_sp -= sizeof (bd_t);
	bd = (bd_t *) addr_sp;
	gd->bd = bd;
	debug("Reserving %zu Bytes for Board Info at: %08lx\n",
			sizeof (bd_t), addr_sp);

// 注释43. CONFIG_MACH_TYPE 有定义, 填充gd->bd->bi_arch_number
#ifdef CONFIG_MACH_TYPE
	gd->bd->bi_arch_number = CONFIG_MACH_TYPE; /* board id for Linux */
#endif

// 注释44. addr_sp -= sizeof (gd_t) = addr_sp - 152(反汇编查出来的)
//         这152字节存放struct global_data结构体, 就跟在struct bd_info下面, debug函数因没定义DEBUG不输出任何信息
	addr_sp -= sizeof (gd_t);
	id = (gd_t *) addr_sp;
	debug("Reserving %zu Bytes for Global Data at: %08lx\n",
			sizeof (gd_t), addr_sp);

// 注释45. 填充gd->irq_sp
	/* setup stackpointer for exeptions */
	gd->irq_sp = addr_sp;
#ifdef CONFIG_USE_IRQ
	addr_sp -= (CONFIG_STACKSIZE_IRQ+CONFIG_STACKSIZE_FIQ);
	debug("Reserving %zu Bytes for IRQ stack at: %08lx\n",
		CONFIG_STACKSIZE_IRQ+CONFIG_STACKSIZE_FIQ, addr_sp);
#endif
// 注释46. addr_sp = (addr_sp - 12) & (fffffff8) = addr_sp - 16, 不知道用来干嘛
	/* leave 3 words for abort-stack    */
	addr_sp -= 12;

	/* 8-byte alignment for ABI compliance */
	addr_sp &= ~0x07;
#else
	addr_sp += 128;	/* leave 32 words for abort-stack   */
	gd->irq_sp = addr_sp;
#endif // 注释47. #ifndef CONFIG_SPL_BUILD

	debug("New Stack Pointer is: %08lx\n", addr_sp);

// 注释48. CONFIG_POST 未定义, 不进入
#ifdef CONFIG_POST
	post_bootmode_init();
	post_run(NULL, POST_ROM | post_bootmode_get(0));
#endif

// 注释49.填充gd->bd->bi_baudrate
	gd->bd->bi_baudrate = gd->baudrate;
	/* Ram ist board specific, so move it to board code ... */
// 注释50. 调用dram_init_banksize函数(board/samsung/smdk6400/smdk6400.c)和display_dram_config函数(arch/arm/lib/board.c)
//          dram_init_banksize函数填充gd->bd->bi_dram[0].start与gd->bd->bi_dram[0].size
//          display_dram_config函数用于输出配置的DRAM内存大小
	dram_init_banksize();
	display_dram_config();	/* and display it */

// 注释51. 填充gd->relocaddr, gd->start_addr_sp, gd->reloc_off, 并将struct global_data结构体从IRAM拷贝到DRAM中
	gd->relocaddr = addr;
	gd->start_addr_sp = addr_sp;
	gd->reloc_off = addr - _TEXT_BASE;
	debug("relocation Offset is: %08lx\n", gd->reloc_off);
	memcpy(id, (void *)gd, sizeof(gd_t));

// 注释52. 调用relocate_code函数(arch/arm/cpu/arm1176/start.S), 这个函数会将pc指向DRAM的uboot处继续运行
	relocate_code(addr_sp, id, addr);

	/* NOTREACHED - relocate_code() does not return */
}

#if !defined(CONFIG_SYS_NO_FLASH)
static char *failed = "*** failed ***\n";
#endif

/*
 ************************************************************************
 *
 * This is the next part if the initialization sequence: we are now
 * running from RAM and have a "normal" C environment, i. e. global
 * data can be written, BSS has been cleared, the stack size in not
 * that critical any more, etc.
 *
 ************************************************************************
 */

void board_init_r(gd_t *id, ulong dest_addr)
{
	ulong malloc_start;
// 注释53. CONFIG_SYS_NO_FLASH 未定义, 不进入
#if !defined(CONFIG_SYS_NO_FLASH)
	ulong flash_size;
#endif

// 注释54. gd指向struct global_data结构体
	gd = id;

// 注释55. 填充gd->flags, bootstage_mark_name函数在common/bootstage.c中定义, 这里是填充结构体struct bootstage_record record[BOOTSTAGE_ID_START_UBOOT_R]
	gd->flags |= GD_FLG_RELOC;	/* tell others: relocation done */
	bootstage_mark_name(BOOTSTAGE_ID_START_UBOOT_R, "board_init_r");

// 注释56. monitor_flash_len = _end - _start字节
	monitor_flash_len = _end_ofs;

	/* Enable caches */
// 注释57. 调用enable_caches函数(arch/arm/lib/board.c), 是个弱函数, 需要自己写, 这里输出不能使能cache的信息, 
	enable_caches();

// 注释58. debug函数因没定义DEBUG不输出任何信息, 调用board_init函数(board/samsung/smdk6400/smdk6400.c),初始化CS8900需要用到的SROM BANK1
//         填充gd->bd->bi_boot_params
	debug("monitor flash len: %08lX\n", monitor_flash_len);
	board_init();	/* Setup chipselects */
	/*
	 * TODO: printing of the clock inforamtion of the board is now
	 * implemented as part of bdinfo command. Currently only support for
	 * davinci SOC's is added. Remove this check once all the board
	 * implement this.
	 */
// 注释59. CONFIG_CLOCKS 未定义, 不进入
#ifdef CONFIG_CLOCKS
	set_cpu_clk_info(); /* Setup clock information */
#endif
// 注释60. CONFIG_SERIAL_MULTI 未定义, 不进入
#ifdef CONFIG_SERIAL_MULTI
	serial_initialize();
#endif
// 注释61. debug函数因没定义DEBUG不输出任何信息
	debug("Now running in RAM - U-Boot at: %08lx\n", dest_addr);
	
// 注释62. CONFIG_LOGBUFFER未定义, 不进入
#ifdef CONFIG_LOGBUFFER
	logbuff_init_ptrs();
#endif
// 注释63. CONFIG_POST未定义, 不进入
#ifdef CONFIG_POST
	post_output_backlog();
#endif

	/* The Malloc area is immediately below the monitor copy in DRAM */
// 注释64. malloc_start = dest_addr - TOTAL_MALLOC_LEN = gd->relocaddr - 0x108000,
//         调用mem_malloc_init函数, 給mem_malloc_start, mem_malloc_end, mem_malloc_brk赋值, 将malloc分配区域清0
	malloc_start = dest_addr - TOTAL_MALLOC_LEN;
	mem_malloc_init (malloc_start, TOTAL_MALLOC_LEN);

// 注释65. CONFIG_ARCH_EARLY_INIT_R 未定义, 不进入
#ifdef CONFIG_ARCH_EARLY_INIT_R
	arch_early_init_r();
#endif

// 注释66. CONFIG_SYS_NO_FLASH 未定义, 进入
#if !defined(CONFIG_SYS_NO_FLASH)
// 注释67. 输出字符串, 调用flash_init函数(drivers/mtd/cfi_flash.c), 
//         flash_init函数将nand flash初始化为mtd设备,有点复杂, 以后分析, flash_size = 256MB
	puts("Flash: ");
	
	flash_size = flash_init();
// 注释68(这部分代码有问题, 这里是初始化nor flash, 但tiny6410的是nand flash, 不分析). 有检测到nand flash, flash_size肯定大于0, 所以进入, CONFIG_SYS_FLASH_CHECKSUM 未定义, 进入后执行else
	if (flash_size > 0) {
# ifdef CONFIG_SYS_FLASH_CHECKSUM
		char *s = getenv("flashchecksum");

		print_size(flash_size, "");
		/*
		 * Compute and print flash CRC if flashchecksum is set to 'y'
		 *
		 * NOTE: Maybe we should add some WATCHDOG_RESET()? XXX
		 */
		if (s && (*s == 'y')) {
			printf("  CRC: %08X", crc32(0,
				(const unsigned char *) CONFIG_SYS_FLASH_BASE,
				flash_size));
		}
		putc('\n');
# else	/* !CONFIG_SYS_FLASH_CHECKSUM */
		print_size(flash_size, "\n");
# endif /* CONFIG_SYS_FLASH_CHECKSUM */
	} else {
		puts(failed);
		hang();
	}
#endif

// 注释69. CONFIG_CMD_NAND 在smdk6400.h中定义, 进入, 调用nand_init函数, 初始化NAND FLASH, 暂不分析
#if defined(CONFIG_CMD_NAND)
	puts("NAND:  ");
	nand_init();		/* go init the NAND */
#endif

// 注释70. CONFIG_CMD_ONENAND 未定义, 不进入
#if defined(CONFIG_CMD_ONENAND)
	onenand_init();
#endif

// 注释71. CONFIG_GENERIC_MMC 未定义, 不进入
#ifdef CONFIG_GENERIC_MMC
       puts("MMC:   ");
       mmc_initialize(gd->bd);
#endif

// 注释72. CONFIG_HAS_DATAFLASH 未定义, 不进入
#ifdef CONFIG_HAS_DATAFLASH
	AT91F_DataflashInit();
	dataflash_print_info();
#endif

	/* initialize environment */
// 注释73. 调用env_relocate函数(common/env_common.c), 建立环境变量哈希表
	env_relocate();

// 注释74. CONFIG_CMD_PCI与CONFIG_PCI没定义, 不进入
#if defined(CONFIG_CMD_PCI) || defined(CONFIG_PCI)
	arm_pci_init();
#endif

// 注释75. 调用stdio_init函数(common/stdio.c), 初始化相应驱动设备
	stdio_init();	/* get the devices list going. */
// 注释76. 调用jumptable_init函数(common/exports.c), 建立跳转表, 填充到gd->jt
	jumptable_init();

// 注释77. CONFIG_API未定义, 不进入
#if defined(CONFIG_API)
	/* Initialize API */
	api_init();
#endif

// 注释78. 调用console_init_r函数(common/console.c), 初始化控制台(串口)
	console_init_r();	/* fully init console as a device */

// 注释79. CONFIG_ARCH_MISC_INIT与CONFIG_MISC_INIT_R未定义, 都不进入
#if defined(CONFIG_ARCH_MISC_INIT)
	/* miscellaneous arch dependent initialisations */
	arch_misc_init();
#endif
#if defined(CONFIG_MISC_INIT_R)
	/* miscellaneous platform dependent initialisations */
	misc_init_r();
#endif

	 /* set up exceptions */
// 注释80. 调用interrupt_init函数与enable_interrupts函数(都在arch/arm/lib/interrupts.c), 
	interrupt_init();
	/* enable exceptions */
	enable_interrupts();

	/* Perform network card initialisation if necessary */
// 注释81. CONFIG_DRIVER_SMC91111与CONFIG_DRIVER_LAN91C96没定义, 不进入
#if defined(CONFIG_DRIVER_SMC91111) || defined (CONFIG_DRIVER_LAN91C96)
	/* XXX: this needs to be moved to board init */
	if (getenv("ethaddr")) {
		uchar enetaddr[6];
		eth_getenv_enetaddr("ethaddr", enetaddr);
		smc_set_mac_addr(enetaddr);
	}
#endif /* CONFIG_DRIVER_SMC91111 || CONFIG_DRIVER_LAN91C96 */

	/* Initialize from environment */
// 注释82. 从环境变量表中寻找"loadaddr"参数, 这里没找到, 使用原来的参数load_addr = 
	load_addr = getenv_ulong("loadaddr", 16, load_addr);

// 注释83. CONFIG_BOARD_LATE_INIT未定义, 不进入
#ifdef CONFIG_BOARD_LATE_INIT
	board_late_init();
#endif

// 注释84. CONFIG_BITBANGMII未定义, 不进入
#ifdef CONFIG_BITBANGMII
	bb_miiphy_init();
#endif
// 注释85. CONFIG_CMD_NET在include/config_cmd_defaults.h中定义, 进入
#if defined(CONFIG_CMD_NET)
	puts("Net:   ");
// 注释86. 调用eth_initialize函数(net/eth.c), 
	eth_initialize(gd->bd);
// 注释87. CONFIG_RESET_PHY_R未定义, 不进入
#if defined(CONFIG_RESET_PHY_R)
	debug("Reset Ethernet PHY\n");
	reset_phy();
#endif
#endif

// 注释88. CONFIG_POST未定义, 不进入
#ifdef CONFIG_POST
	post_run(NULL, POST_RAM | post_bootmode_get(0));
#endif

// 注释89. CONFIG_PRAM与CONFIG_LOGBUFFER 未定义, 不进入
#if defined(CONFIG_PRAM) || defined(CONFIG_LOGBUFFER)
	/*
	 * Export available size of memory for Linux,
	 * taking into account the protected RAM at top of memory
	 */
	{
		ulong pram = 0;
		uchar memsz[32];

#ifdef CONFIG_PRAM
		pram = getenv_ulong("pram", 10, CONFIG_PRAM);
#endif
#ifdef CONFIG_LOGBUFFER
#ifndef CONFIG_ALT_LB_ADDR
		/* Also take the logbuffer into account (pram is in kB) */
		pram += (LOGBUFF_LEN + LOGBUFF_OVERHEAD) / 1024;
#endif
#endif
		sprintf((char *)memsz, "%ldk", (gd->ram_size / 1024) - pram);
		setenv("mem", (char *)memsz);
	}
#endif // #if defined(CONFIG_PRAM) || defined(CONFIG_LOGBUFFER)

	/* main_loop() can return to retry autoboot, if so just run it again. */
	
	for (;;) {
// 注释90. 死循环调用main_loop函数(common/main.c),
		main_loop();
	}

	/* NOTREACHED - no way out of command loop except booting */
}

void hang(void)
{
	puts("### ERROR ### Please RESET the board ###\n");
	for (;;);
}
