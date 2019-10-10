/*
 *  armboot - Startup Code for ARM1176 CPU-core
 *
 * Copyright (c) 2007	Samsung Electronics
 *
 * Copyright (C) 2008
 * Guennadi Liakhovetki, DENX Software Engineering, <lg@denx.de>
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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 * MA 02111-1307 USA
 *
 * 2007-09-21 - Restructured codes by jsgood (jsgood.yang@samsung.com)
 * 2007-09-21 - Added MoviNAND and OneNAND boot codes by
 * jsgood (jsgood.yang@samsung.com)
 * Base codes by scsuh (sc.suh)
 */
/* 2016.1.13------------此文件为arm1176启动代码分析(arch/arm/cpu/arm1176/start.S)
   2016.1.15------------从注释23开始分析, 进行到注释24
   2016.1.16------------从注释25开始, 分析relocate_code函数, 到注释28
   2016.1.17------------从注释29开始, 中间还分析了如何开启MMU(虽然没开启, 注释34-38), 到注释45结束.
*/
#include <asm-offsets.h>
#include <config.h>
#include <version.h>
#ifdef CONFIG_ENABLE_MMU
#include <asm/proc/domain.h>
#endif
//注释1. 默认不开MMU，CONFIG_ENABLE_MMU未定义，
//       有定义CONFIG_SYS_PHY_UBOOT_BASE = CONFIG_SYS_SDRAM_BASE + 0x07e00000 = 0x50000000 + 0x07e00000 = 0x57e00000，与定义程序入口地址一样
#if !defined(CONFIG_ENABLE_MMU) && !defined(CONFIG_SYS_PHY_UBOOT_BASE)
#define CONFIG_SYS_PHY_UBOOT_BASE	CONFIG_SYS_UBOOT_BASE
#endif

/*
 *************************************************************************
 *
 * Jump vector table as in table 3.1 in [1]
 *
 *************************************************************************
 */

//注释2. uboot程序入口地址(加载地址0x57e00000，运行地址0x0)，
//       在u-boot.lds中_start为程序开始位置，并声明_start在其它文件可使用
.globl _start
//注释3. 默认不是SPL模式，并在入口地址0-1c处定义异常向量地址。
_start: b	reset
#ifndef CONFIG_NAND_SPL
	ldr	pc, _undefined_instruction
	ldr	pc, _software_interrupt
	ldr	pc, _prefetch_abort
	ldr	pc, _data_abort
	ldr	pc, _not_used
	ldr	pc, _irq
	ldr	pc, _fiq

_undefined_instruction:
	.word undefined_instruction
_software_interrupt:
	.word software_interrupt
_prefetch_abort:
	.word prefetch_abort
_data_abort:
	.word data_abort
_not_used:
	.word not_used
_irq:
	.word irq
_fiq:
	.word fiq
_pad:
	.word 0x12345678 /* now 16*4=64  */
//注释4. 前面占了64字节空间
#else
	. = _start + 64
#endif

//注释5：.balignl 16,0xdeadbeef 是为了让后面开始的地址是16的倍数，用0xdeadbeef来填充
//       并声明_end_vect在其它文件可使用
.global _end_vect
_end_vect:
	.balignl 16,0xdeadbeef
/*
 *************************************************************************
 *
 * Startup Code (reset vector)
 *
 * do important init only if we don't start from memory!
 * setup Memory and board specific bits prior to relocation.
 * relocate armboot to ram
 * setup stack
 *
 *************************************************************************
 */
// 注释6. CONFIG_SYS_TEXT_BASE=0x57e00000，在board/samsung/smdk6400/config.mk中定义
//        并声明_TEXT_BASE在其它文件可使用
.globl _TEXT_BASE
_TEXT_BASE:
	.word	CONFIG_SYS_TEXT_BASE

/*
 * Below variable is very important because we use MMU in U-Boot.
 * Without it, we cannot run code correctly before MMU is ON.
 * by scsuh.
 */
// 注释7. CONFIG_SYS_PHY_UBOOT_BASE = 0x57e00000
_TEXT_PHY_BASE:
	.word	CONFIG_SYS_PHY_UBOOT_BASE

/*
 * These are defined in the board-specific linker script.
 * Subtracting _start from them lets the linker put their
 * relative position in the executable instead of leaving
 * them null.
 */

// 注释8. 声明_bss_start_ofs在其它文件可使用，__bss_start在u-boot.lds中定义为bss段开始位置
.globl _bss_start_ofs
_bss_start_ofs:
	.word __bss_start - _start

// 注释9. 声明_bss_end_ofs在其它文件可使用，__bss_end__在u-boot.lds中定义为bbs段结束位置	
.globl _bss_end_ofs
_bss_end_ofs:
	.word __bss_end__ - _start

// 注释10. 声明_end_ofs在其它文件可使用，_end在u-boot.lds中定义，_end与__bss_start应该是同一个位置
.globl _end_ofs
_end_ofs:
	.word _end - _start

/* IRQ stack memory (calculated at run-time) + 8 bytes */
// 注释11. 声明IRQ_STACK_START_IN在其它文件可使用
.globl IRQ_STACK_START_IN
IRQ_STACK_START_IN:
	.word	0x0badc0de

/*
 * the actual reset code
 */
reset:
// 注释12.PSR状态寄存器各位含义     31 30 29 28 27 26-25 24 23-20 19-16 15-10  9  8  7  6  5  4-0
//                                    N  Z  C  V  Q  DNM   J  DNM   GE    DNM   E  A  I  F  T   M
	/*
	 * set the cpu to SVC32 mode
	 */
	mrs	r0, cpsr
	bic	r0, r0, #0x3f    //注释13. 0-5位清0
	orr	r0, r0, #0xd3    //注释14. I=1(IRQ普通中断禁止)，F=1(FIQ快速中断禁止)，M=10011(SVC模式)
	msr	cpsr, r0

/*
 *************************************************************************
 *
 * CPU_init_critical registers
 *
 * setup important registers
 * setup memory timing
 *
 *************************************************************************
 */
	/*
	 * we do sys-critical inits only at reboot,
	 * not when booting from ram!
	 */
cpu_init_crit:
	/*
	 * When booting from NAND - it has definitely been a reset, so, no need
	 * to flush caches and disable the MMU
	 */
// 注释15. 未定义CONFIG_NAND_SPL
#ifndef CONFIG_NAND_SPL
	/*
	 * flush v4 I/D caches
	 */
// 注释16. mcr mrc命令都是操作协处理器，具体操作看arm处理器手册
	mov	r0, #0
// 注释17. 刷新icache,dcache,undefined TLB(传输后备缓存器)
	mcr	p15, 0, r0, c7, c7, 0	/* flush v3/v4 cache */
	mcr	p15, 0, r0, c8, c7, 0	/* flush v4 TLB */

	/*
	 * disable MMU stuff and caches
	 */
// 注释18. 取出c1控制寄存器的值到r0寄存器中
//         V=0(异常向量表在低地址),R=0(关闭ROM保护),S=0(MMU保护禁止)
//         B=0(小端地址),C=0(dcache禁止),A=0(禁止检查对齐),M=0(MMU禁止)
//         A=1(使能检查对齐),I=1(icashe使能)
	mrc	p15, 0, r0, c1, c0, 0
	bic	r0, r0, #0x00002300	@ clear bits 13, 9:8 (--V- --RS)
	bic	r0, r0, #0x00000087	@ clear bits 7, 2:0 (B--- -CAM)
	orr	r0, r0, #0x00000002	@ set bit 2 (A) Align
	orr	r0, r0, #0x00001000	@ set bit 12 (I) I-Cache

	/* Prepare to disable the MMU */
	adr	r2, mmu_disable_phys
	sub	r2, r2, #(CONFIG_SYS_PHY_UBOOT_BASE - CONFIG_SYS_TEXT_BASE)
	b	mmu_disable

	.align 5
	/* Run in a single cache-line */
mmu_disable:
// 注释19. 将r0寄存器的值保存到c1控制寄存器中
	mcr	p15, 0, r0, c1, c0, 0
	nop
	nop
	mov	pc, r2
mmu_disable_phys:

// 注释20. CONFIG_DISABLE_TCM未定义，不进去
#ifdef CONFIG_DISABLE_TCM
	/*
	 * Disable the TCMs
	 */
	mrc	p15, 0, r0, c0, c0, 2	/* Return TCM details */
	cmp	r0, #0
	beq	skip_tcmdisable
	mov	r1, #0
	mov	r2, #1
	tst	r0, r2
	mcrne	p15, 0, r1, c9, c1, 1	/* Disable Instruction TCM if present*/
	tst	r0, r2, LSL #16
	mcrne	p15, 0, r1, c9, c1, 0	/* Disable Data TCM if present*/
skip_tcmdisable:
#endif 
#endif

// 注释21. CONFIG_PERIPORT_REMAP有定义，进去设置外设寄存器基地址与大小(0x70000000-0x7fffffff)
           CONFIG_PERIPORT_BASE = 0x70000000,CONFIG_PERIPORT_SIZE = 0x13,都在include/configs/smdk6400.h中定义
#ifdef CONFIG_PERIPORT_REMAP
	/* Peri port setup */
	ldr	r0, =CONFIG_PERIPORT_BASE
	orr	r0, r0, #CONFIG_PERIPORT_SIZE
	mcr	p15,0,r0,c15,c2,4
#endif

	/*
	 * Go setup Memory and board specific bits prior to relocation.
	 */
// 注释22. lowlevel_init在board/samsung/smdk6400/lowlevel_init.S中
	bl	lowlevel_init		/* go setup pll,mux,memory */

/* Set stackpointer in internal RAM to call board_init_f */
call_board_init_f:
// 注释23. CONFIG_SYS_INIT_SP_ADDR  = (CONFIG_SYS_IRAM_END - GENERATED_GBL_DATA_SIZE), 
//         CONFIG_SYS_IRAM_END = (CONFIG_SYS_IRAM_BASE + CONFIG_SYS_IRAM_SIZE) = 0x0c000000 + 0x2000(8K) = 0xc002000
//		   0x00000000-0x0bffffff是IROM范围(实际只有32KB),0xc000000-0x10000000是IRAM范围(芯片上说实际只有4KB, 网上说是错的, 是8K)
//         GENERATED_GBL_DATA_SIZE = 128, 这128字节用来存放这struct global_data结构体
//         也就是8K IRAM,倒数的128字节用来存放struct global_data结构体, 其它做为栈, 用CONFIG_SYS_INIT_SP_ADDR作为栈顶指针
	ldr	sp, =(CONFIG_SYS_INIT_SP_ADDR)
	bic	sp, sp, #7 /* 8-byte alignment for ABI compliance */
	
	ldr	r0,=0x00000000
// 注释24. board_init_f在arch/arm/lib/board.c中
	bl	board_init_f

/*------------------------------------------------------------------------------*/

/*
 * void relocate_code (addr_sp, gd, addr_moni)
 *
 * This "function" does not return, instead it continues in RAM
 * after relocating the monitor code.
 *
 */
// 注释25. 声明relocate_code在其它文件可使用
	.globl	relocate_code
relocate_code:
// 注释26. 保存输入参数, 见内存分布图, r4 = gd->start_addr_sp, r5 = id, r6 = gd->relocaddr
	mov	r4, r0	/* save addr_sp */
	mov	r5, r1	/* save addr of gd */
	mov	r6, r2	/* save addr of destination */

	/* Set up the stack						    */
stack_setup:
// 注释27. sp栈指针指向gd->start_addr_sp
	mov	sp, r4

// 注释28. r0 = 0x0, r1 = gd->relocaddr, r3为BSS段开始处相对于0x57e00000的偏移值, r2 为0x0 + r3里的偏移值.
//         这部分是将低地址的uboot拷贝到DRAM的uboot区域, 但是在tiny6410中不可以这样子, 因为低地址中只有uboot的前4K代码
//         这4K代码中需要将uboot从nand flash拷贝到DRAM的uboot才对, 而且拷贝应该在程序最开始初始化系统配置就开始.
	adr	r0, _start
	cmp	r0, r6
	moveq	r9, #0		/* no relocation. relocation offset(r9) = 0 */
	beq	clear_bss		/* skip relocation */
	mov	r1, r6			/* r1 <- scratch for copy_loop */
	ldr	r3, _bss_start_ofs
	add	r2, r0, r3		/* r2 <- source end address	    */

copy_loop:
	ldmia	r0!, {r9-r10}		/* copy from source address [r0]    */
	stmia	r1!, {r9-r10}		/* copy to   target address [r1]    */
	cmp	r0, r2			/* until source end address [r2]    */
	blo	copy_loop

// 注释29. CONFIG_SPL_BUILD未定义, 进入
#ifndef CONFIG_SPL_BUILD
	/*
	 * fix .rel.dyn relocations
	 */
// 注释30. r0 = 0x57e00000, r6 = gd->relocaddr,  r9 = 内存中uboot区域偏移值, 
//         r10 = _dynsym_start_ofs(见u-boot.lds), r10 = r10 + r0 = 0x57e00000 + _dynsym_start_ofs, 里面存储的是__dynsym_start - _start, 
//         r2 = _rel_dyn_start_ofs(见u-boot.lds), r2 =  r2 +  r0 = 0x57e00000 + _rel_dyn_start_ofs, 里面存储的是__rel_dyn_start - _start,
//         r3 = _rel_dyn_end_ofs(见u-boot.lds),   r3 =  r3 +  r0 = 0x57e00000 + _rel_dyn_end_ofs = 里面存储的是__rel_dyn_end - _start,
	ldr	r0, _TEXT_BASE		/* r0 <- Text base */
	sub	r9, r6, r0		/* r9 <- relocation offset */
	ldr	r10, _dynsym_start_ofs	/* r10 <- sym table ofs */
	add	r10, r10, r0		/* r10 <- sym table in FLASH */
	ldr	r2, _rel_dyn_start_ofs	/* r2 <- rel dyn start ofs */
	add	r2, r2, r0		/* r2 <- rel dyn start in FLASH */
	ldr	r3, _rel_dyn_end_ofs	/* r3 <- rel dyn end ofs */
	add	r3, r3, r0		/* r3 <- rel dyn end in FLASH */
fixloop:
// 注释31. r0 = __dynsym_start - _start, r0 = r0 + r9 = __dynsym_start - 0x57e00000 + 内存中uboot区域偏移值, 这是相对于0x57e00000的__dynsym_start真正偏移值
//         r1 = [r2+4] = 0x00036638(反汇编得到), r7 = r1 & 0xff = 0x38, 直接跳转到fixnext
	ldr	r0, [r2]		/* r0 <- location to fix up, IN FLASH! */
	add	r0, r0, r9		/* r0 <- location to fix up in RAM */
	ldr	r1, [r2, #4]
	and	r7, r1, #0xff
	cmp	r7, #23			/* relative fixup? */
	beq	fixrel
	cmp	r7, #2			/* absolute fixup? */
	beq	fixabs
	/* ignore unknown type of fixup */
	b	fixnext
fixabs:
	/* absolute fix: set location to (offset) symbol value */
	mov	r1, r1, LSR #4		/* r1 <- symbol index in .dynsym */
	add	r1, r10, r1		/* r1 <- address of symbol in table */
	ldr	r1, [r1, #4]		/* r1 <- symbol value */
	add	r1, r1, r9		/* r1 <- relocated sym addr */
	b	fixnext
fixrel:
	/* relative fix: increase location by offset */
	ldr	r1, [r0]
	add	r1, r1, r9
fixnext:
// 注释32. 将__dynsym_start真正偏移值(__dynsym_start - 0x57e00000 + 内存中uboot区域偏移值)保存到0x57e00000+ _dynsym_start_ofs中
//          r2 = r2 + 8 = 0x57e00000 + _rel_dyn_start_ofs + 8 , r3 = 0x57e00000 + _rel_dyn_end_ofs, r2 - r3 = 4, 
//          blo判断是小于(无符号)才跳转, 这里不跳转到fixloop,
	str	r1, [r0]
	add	r2, r2, #8		/* each rel.dyn entry is 8 bytes */
	cmp	r2, r3
	blo	fixloop
#endif

// 注释33. 这里CONFIG_ENABLE_MMU未定义, 不进去, 也分析一下怎么开启MMU
#ifdef CONFIG_ENABLE_MMU
enable_mmu:
	/* enable domain access */
// 注释34. 对D0-D7 区域访问设置不检查使用权限, 对D8-D15区域没有权限访问
	ldr	r5, =0x0000ffff
	mcr	p15, 0, r5, c3, c0, 0	/* load domain access register */

	/* Set the TTB register */
// 注释35. r0 = mmu_table(board/samsung/smdk6400/lowlevel_init.S), r1 = 0x57e00000, r1 = (mmu_table & 0x000fffff) | 0x57e00000
//         将页表地址放入TTB寄存器0中, 
	ldr	r0, _mmu_table_base
	ldr	r1, =CONFIG_SYS_PHY_UBOOT_BASE
	ldr	r2, =0xfff00000
	bic	r0, r0, r2
	orr	r1, r0, r1
	mcr	p15, 0, r1, c2, c0, 0

// 注释36. 准备使能MMU, 参考注释18
	/* Enable the MMU */
	mrc	p15, 0, r0, c1, c0, 0
	orr	r0, r0, #1		/* Set CR_M to enable MMU */

// 注释37. 找出使能MMU后执行的函数在内存的uboot处的地址, 保存r2中
	/* Prepare to enable the MMU */
	adr	r1, skip_hw_init
	and	r1, r1, #0x3fc
	ldr	r2, _TEXT_BASE
	ldr	r3, =0xfff00000
	and	r2, r2, r3
	orr	r2, r2, r1
	b	mmu_enable

	.align 5
	/* Run in a single cache-line */
mmu_enable:
// 注释38. 使能MMU, 将PC指针指向r2, 此时PC已经在高处地址执行了, r2在0x00000000-0x9FFFFFFF内, 开启MMU后虚拟地址与物理地址是一样的
	mcr	p15, 0, r0, c1, c0, 0
	nop
	nop
	mov	pc, r2
skip_hw_init:
#endif

clear_bss:
// 注释39. CONFIG_SPL_BUILD 未定义, 进入
#ifndef CONFIG_SPL_BUILD
// 注释40. r0 = __bss_start - 0x57e00000, r1 = __bss_end - 0x57e00000, r4 = gd->relocaddr
           r0 = r0 + r4 = 拷贝后的uboot代码的__bss_start地址, r1 = r1 + r4 = 拷贝后的uboot代码的__bss_end地址
		   r2 = 0
	ldr	r0, _bss_start_ofs
	ldr	r1, _bss_end_ofs
	mov	r4, r6			/* reloc addr */
	add	r0, r0, r4
	add	r1, r1, r4
	mov	r2, #0x00000000		/* clear			    */

clbss_l:cmp	r0, r1			/* clear loop... */
// 注释41. 清除BSS段
	bhs	clbss_e			/* if reached end of bss, exit */
	str	r2, [r0]
	add	r0, r0, #4
	b	clbss_l
clbss_e:
// 注释42. CONFIG_NAND_SPL 未定义, 进入
#ifndef CONFIG_NAND_SPL
// 注释43. 调用coloured_LED_init函数(arch/arm/lib/board.c)和red_led_on函数(arch/arm/lib/board.c), 都是弱函数, 得自己写, 这里不执行任何操作
	bl coloured_LED_init
	bl red_led_on
#endif
#endif

/*
 * We are done. Do not return, instead branch to second part of board
 * initialization, now running from RAM.
 */
// 注释44. CONFIG_NAND_SPL 未定义, 执行else
#ifdef CONFIG_NAND_SPL
	ldr     pc, _nand_boot

_nand_boot: .word nand_boot
#else
// 注释45. r0 = board_init_r - 0x57e00000, r1 = 0x57e00000, lr = r0 + r1 = board_init_r
//         lr = lr + r9 = board_init_r - 0x57e00000 + 内存中uboot区域相对0x57e0000000偏移值
//         r0 = gd->irq_sp, r1 = gd->relocaddr, 跳转到内存中ubboot的board_init_r函数
	ldr	r0, _board_init_r_ofs
	adr	r1, _start
	add	lr, r0, r1
	add     lr, lr, r9
	/* setup parameters for board_init_r */
	mov	r0, r5		/* gd_t */
	mov	r1, r6		/* dest_addr */
	/* jump to it ... */
	mov	pc, lr

_board_init_r_ofs:
	.word board_init_r - _start
#endif

_rel_dyn_start_ofs:
	.word __rel_dyn_start - _start
_rel_dyn_end_ofs:
	.word __rel_dyn_end - _start
_dynsym_start_ofs:
	.word __dynsym_start - _start

#ifdef CONFIG_ENABLE_MMU
_mmu_table_base:
	.word mmu_table
#endif

#ifndef CONFIG_NAND_SPL
/*
 * we assume that cache operation is done before. (eg. cleanup_before_linux())
 * actually, we don't need to do anything about cache if not use d-cache in
 * U-Boot. So, in this function we clean only MMU. by scsuh
 *
 * void	theLastJump(void *kernel, int arch_num, uint boot_params);
 */
#ifdef CONFIG_ENABLE_MMU
	.globl theLastJump
theLastJump:
	mov	r9, r0
	ldr	r3, =0xfff00000
	ldr	r4, _TEXT_PHY_BASE
	adr	r5, phy_last_jump
	bic	r5, r5, r3
	orr	r5, r5, r4
	mov	pc, r5
phy_last_jump:
	/*
	 * disable MMU stuff
	 */
	mrc	p15, 0, r0, c1, c0, 0
	bic	r0, r0, #0x00002300	/* clear bits 13, 9:8 (--V- --RS) */
	bic	r0, r0, #0x00000087	/* clear bits 7, 2:0 (B--- -CAM) */
	orr	r0, r0, #0x00000002	/* set bit 2 (A) Align */
	orr	r0, r0, #0x00001000	/* set bit 12 (I) I-Cache */
	mcr	p15, 0, r0, c1, c0, 0

	mcr	p15, 0, r0, c8, c7, 0	/* flush v4 TLB */

	mov	r0, #0
	mov	pc, r9
#endif


/*
 *************************************************************************
 *
 * Interrupt handling
 *
 *************************************************************************
 */
@
@ IRQ stack frame.
@
#define S_FRAME_SIZE	72

#define S_OLD_R0	68
#define S_PSR		64
#define S_PC		60
#define S_LR		56
#define S_SP		52

#define S_IP		48
#define S_FP		44
#define S_R10		40
#define S_R9		36
#define S_R8		32
#define S_R7		28
#define S_R6		24
#define S_R5		20
#define S_R4		16
#define S_R3		12
#define S_R2		8
#define S_R1		4
#define S_R0		0

#define MODE_SVC 0x13
#define I_BIT	 0x80

/*
 * use bad_save_user_regs for abort/prefetch/undef/swi ...
 */

	.macro	bad_save_user_regs
	/* carve out a frame on current user stack */
	sub	sp, sp, #S_FRAME_SIZE
	/* Save user registers (now in svc mode) r0-r12 */
	stmia	sp, {r0 - r12}

	ldr	r2, IRQ_STACK_START_IN
	/* get values for "aborted" pc and cpsr (into parm regs) */
	ldmia	r2, {r2 - r3}
	/* grab pointer to old stack */
	add	r0, sp, #S_FRAME_SIZE

	add	r5, sp, #S_SP
	mov	r1, lr
	/* save sp_SVC, lr_SVC, pc, cpsr */
	stmia	r5, {r0 - r3}
	/* save current stack into r0 (param register) */
	mov	r0, sp
	.endm

	.macro get_bad_stack
	ldr	r13, IRQ_STACK_START_IN		@ setup our mode stack

	/* save caller lr in position 0 of saved stack */
	str	lr, [r13]
	/* get the spsr */
	mrs	lr, spsr
	/* save spsr in position 1 of saved stack */
	str	lr, [r13, #4]

	/* prepare SVC-Mode */
	mov	r13, #MODE_SVC
	@ msr	spsr_c, r13
	/* switch modes, make sure moves will execute */
	msr	spsr, r13
	/* capture return pc */
	mov	lr, pc
	/* jump to next instruction & switch modes. */
	movs	pc, lr
	.endm

	.macro get_bad_stack_swi
	/* space on current stack for scratch reg. */
	sub	r13, r13, #4
	/* save R0's value. */
	str	r0, [r13]
	ldr	r13, IRQ_STACK_START_IN		@ setup our mode stack
	/* save caller lr in position 0 of saved stack */
	str	lr, [r0]
	/* get the spsr */
	mrs	r0, spsr
	/* save spsr in position 1 of saved stack */
	str	lr, [r0, #4]
	/* restore r0 */
	ldr	r0, [r13]
	/* pop stack entry */
	add	r13, r13, #4
	.endm

/*
 * exception handlers
 */
	.align	5
undefined_instruction:
	get_bad_stack
	bad_save_user_regs
	bl	do_undefined_instruction

	.align	5
software_interrupt:
	get_bad_stack_swi
	bad_save_user_regs
	bl	do_software_interrupt

	.align	5
prefetch_abort:
	get_bad_stack
	bad_save_user_regs
	bl	do_prefetch_abort

	.align	5
data_abort:
	get_bad_stack
	bad_save_user_regs
	bl	do_data_abort

	.align	5
not_used:
	get_bad_stack
	bad_save_user_regs
	bl	do_not_used

	.align	5
irq:
	get_bad_stack
	bad_save_user_regs
	bl	do_irq

	.align	5
fiq:
	get_bad_stack
	bad_save_user_regs
	bl	do_fiq
#endif /* CONFIG_NAND_SPL */
