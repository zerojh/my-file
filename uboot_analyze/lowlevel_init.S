/*
 * Memory Setup stuff - taken from blob memsetup.S
 *
 * Copyright (C) 1999 2000 2001 Erik Mouw (J.A.K.Mouw@its.tudelft.nl) and
 *		       Jan-Derk Bakker (J.D.Bakker@its.tudelft.nl)
 *
 * Modified for the Samsung SMDK2410 by
 * (C) Copyright 2002
 * David Mueller, ELSOFT AG, <d.mueller@elsoft.ch>
 *
 * (C) Copyright 2008
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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 * MA 02111-1307 USA
 */
/* 2016.1.13-----------此文件为smdk6400第二阶段代码分析(board\samsung\smdk6400\lowlevel_init.S) 
   2016.1.15-----------从注释33的代码开始分析
   2016.1.17-----------从注释35开始分析MMU的页表.注释35-39
*/

#include <config.h>
#include <version.h>

#include <asm/arch/s3c6400.h>

// 注释1. CONFIG_SERIAL1在smdk6400.h中定义，ELFIN_UART_BASE与ELFIN_UART0_OFFSET在s3c6400.h中定义
//        ELFIN_UART_CONSOLE_BASE = ELFIN_UART_BASE + ELFIN_UART0_OFFSET = 0x7F005000 + 0x0 = 0x7F005000
#ifdef CONFIG_SERIAL1
#define ELFIN_UART_CONSOLE_BASE (ELFIN_UART_BASE + ELFIN_UART0_OFFSET)
#elif defined(CONFIG_SERIAL2)
#define ELFIN_UART_CONSOLE_BASE (ELFIN_UART_BASE + ELFIN_UART1_OFFSET)
#else
#define ELFIN_UART_CONSOLE_BASE (ELFIN_UART_BASE + ELFIN_UART2_OFFSET)
#endif

// 注释2. CONFIG_SYS_TEXT_BASE=0x57e00000，在board/samsung/smdk6400/config.mk中定义
_TEXT_BASE:
	.word	CONFIG_SYS_TEXT_BASE

// 注释3. 声明lowlevel_init在其它文件可使用(start.S)
	.globl lowlevel_init
lowlevel_init:
// 注释4. 保存返回地址
	mov	r12, lr

// 注释5. ELFIN_GPIO_BASE=0x7f008000(GPIO寄存器基地址),GPNCON_OFFSET=0x830(GPN控制寄存器偏移值),
//        GPNPUD_OFFSET=0x838(GPN上下拉寄存器偏移值),GPNDAT_OFFSET=0x834(GPN数据寄存器偏移值)
	/* LED on only #8 */
// 注释6. 设置GPN控制寄存器第9,10,11,12,13,14,15脚为输出
	ldr	r0, =ELFIN_GPIO_BASE
	ldr	r1, =0x55540000
	str	r1, [r0, #GPNCON_OFFSET]
// 注释7. 设置GPN上下拉寄存器引脚下拉
	ldr	r1, =0x55555555
	str	r1, [r0, #GPNPUD_OFFSET]

// 注释8. 设置GPN数据寄存器,第9,10,11脚输出0,第12,13,14,15输出1
	ldr	r1, =0xf000
	str	r1, [r0, #GPNDAT_OFFSET]

// 注释9. 禁止看门狗，看门狗控制寄存器WTCON=0x7e004000，禁止第0,2,5位
	/* Disable Watchdog */
	ldr	r0, =0x7e000000		@0x7e004000
	orr	r0, r0, #0x4000
	mov	r1, #0
	str	r1, [r0]

// 注释10. ELFIN_GPIO_BASE+EINTPEND_OFFSET = 0x7F008924，外部中断挂起寄存器每一位写1清0
	/* External interrupt pending clear */
	ldr	r0, =(ELFIN_GPIO_BASE+EINTPEND_OFFSET)	/*EINTPEND*/
	ldr	r1, [r0]
	str	r1, [r0]

// 注释11. ELFIN_VIC0_BASE_ADDR与ELFIN_VIC1_BASE_ADDR分别为VIC0和VIC2中断寄存器组基地址
	ldr	r0, =ELFIN_VIC0_BASE_ADDR	@0x71200000
	ldr	r1, =ELFIN_VIC1_BASE_ADDR	@0x71300000

// 注释12. oINTMSK=0x14,为中断掩码寄存器偏移值，寄存器各位写1关中断
	/* Disable all interrupts (VIC0 and VIC1) */
	mvn	r3, #0x0
	str	r3, [r0, #oINTMSK]
	str	r3, [r1, #oINTMSK]

// 注释13. oINTMOD=0x0c,为中断方式选择寄存器，设置VIC0,VIC1中断为IRQ普通中断
	/* Set all interrupts as IRQ */
	mov	r3, #0x0
	str	r3, [r0, #oINTMOD]
	str	r3, [r1, #oINTMOD]

// 注释14. oVECTADDR=0xf00,为向量地址寄存器偏移值，清除所有中断位
	/* Pending Interrupt Clear */
	mov	r3, #0x0
	str	r3, [r0, #oVECTADDR]
	str	r3, [r1, #oVECTADDR]

// 注释15. system_clock_init为系统时钟初始化函数，在后面定义
	/* init system clock */
	bl system_clock_init

// 注释27. CONFIG_NAND_SPL未定义，进入
#ifndef CONFIG_NAND_SPL
	/* for UART */
	bl uart_asm_init
#endif

// 注释28. CONFIG_BOOT_NAND在smdk6400.h中定义了，进入
#ifdef CONFIG_BOOT_NAND
	/* simple init for NAND */
	bl nand_asm_init
#endif

// 注释30. ELFIN_MEM_SYS_CFG为内存子系统配置寄存器,S3C64XX_MEM_SYS_CFG_NAND = 0x0008
	/* Memory subsystem address 0x7e00f120 */
	ldr	r0, =ELFIN_MEM_SYS_CFG

// 注释31. 这里很奇怪，0x08 = 01000, 只让Xm0CSn2 = NFCON CS0，没有使Xm0CSn3 = NFCON CS1，虽然tiny6410核心板上Xm0CSn3没接。
//                S3C64XX_MEM_SYS_CFG_NAND中的定义还有第7位设置为0(默认值为1),      
	/* Xm0CSn2 = NFCON CS0, Xm0CSn3 = NFCON CS1 */
	mov	r1, #S3C64XX_MEM_SYS_CFG_NAND
	str	r1, [r0]

// 注释32. mem_ctrl_asm_init 在 arch\arm\cpu\arm1176\s3c64xx\cpu_init.S中
	bl	mem_ctrl_asm_init

/* Wakeup support. Don't know if it's going to be used, untested. */
// 注释33.  ELFIN_CLOCK_POWER_BASE = 0x7e00f000, RST_STAT_OFFSET = 0x904, 复位状态寄存器, 查看是否是从SLEEP模式唤醒的
	ldr	r0, =(ELFIN_CLOCK_POWER_BASE + RST_STAT_OFFSET)
	ldr	r1, [r0]
	bic	r1, r1, #0xfffffff7
	cmp	r1, #0x8
// 注释34. 不是唤醒来的,不会调用wakeup_reset函数, 直接返回
	beq	wakeup_reset

1:
	mov	lr, r12
	mov	pc, lr

wakeup_reset:

	/* Clear wakeup status register */
	ldr	r0, =(ELFIN_CLOCK_POWER_BASE + WAKEUP_STAT_OFFSET)
	ldr	r1, [r0]
	str	r1, [r0]

	/* LED test */
	ldr	r0, =ELFIN_GPIO_BASE
	ldr	r1, =0x3000
	str	r1, [r0, #GPNDAT_OFFSET]

	/* Load return address and jump to kernel */
	ldr	r0, =(ELFIN_CLOCK_POWER_BASE + INF_REG0_OFFSET)
	/* r1 = physical address of s3c6400_cpu_resume function */
	ldr	r1, [r0]
	/* Jump to kernel (sleep-s3c6400.S) */
	mov	pc, r1
	nop
	nop
/*
 * system_clock_init: Initialize core clock and bus clock.
 * void system_clock_init(void)
 */
system_clock_init:
// 注释16. ELFIN_CLOCK_POWER_BASE = 0x7e00f000，为系统时钟寄存器基地址
	ldr	r0, =ELFIN_CLOCK_POWER_BASE	/* 0x7e00f000 */

// 注释17. CONFIG_SYNC_MODE未定义，执行else(异步模式)
#ifdef CONFIG_SYNC_MODE
	ldr	r1, [r0, #OTHERS_OFFSET]
	mov	r2, #0x40
	orr	r1, r1, r2
	str	r1, [r0, #OTHERS_OFFSET]

	nop
	nop
	nop
	nop
	nop

	ldr	r2, =0x80
	orr	r1, r1, r2
	str	r1, [r0, #OTHERS_OFFSET]

check_syncack:
	ldr	r1, [r0, #OTHERS_OFFSET]
	ldr	r2, =0xf00
	and	r1, r1, r2
	cmp	r1, #0xf00
	bne	check_syncack
#else	/* ASYNC Mode */
	nop
	nop
	nop
	nop
	nop

	/*
	 * This was unconditional in original Samsung sources, but it doesn't
	 * seem to make much sense on S3C6400.
	 */
// 注释18. CONFIG_S3C6400在smdk6400.h中定义，不进去
#ifndef CONFIG_S3C6400
	ldr	r1, [r0, #OTHERS_OFFSET]
	bic	r1, r1, #0xC0
	orr	r1, r1, #0x40
	str	r1, [r0, #OTHERS_OFFSET]

wait_for_async:
	ldr	r1, [r0, #OTHERS_OFFSET]
	and	r1, r1, #0xf00
	cmp	r1, #0x0
	bne	wait_for_async
#endif

// 注释19. OTHERS_OFFSET=0x900,为其它功能控制寄存器偏移值,清除寄存器第6位(网友是第7,6位同时置1(同步)或清0(异步))
	ldr	r1, [r0, #OTHERS_OFFSET]
	bic	r1, r1, #0x40
	str	r1, [r0, #OTHERS_OFFSET]
#endif // 注释20. 结束#ifdef CONFIG_SYNC_MODE

// 注释21. APLL_LOCK_OFFSET与MPLL_LOCK_OFFSET分别为APLL,MPLL(没EPLL)锁相环锁定寄存器，配置锁定时间为最大(0xffff/300us)
	mov	r1, #0xff00
	orr	r1, r1, #0xff
	str	r1, [r0, #APLL_LOCK_OFFSET]
	str	r1, [r0, #MPLL_LOCK_OFFSET]
	/*str r1, [r0, #EPLL_LOCK_OFFSET] */

// 注释22. 配置时钟分频寄存器,HCLKX2IN = 533MHz, PCLK = 66.5MHz, HCLKX2 = 266MHz, HCLK = 133MHz, DOUTmpll = 533MHz, ARMCLK = 533MHz
//         CLK_DIV_VAL	= ((STARTUP_PCLKDIV << 12) | (STARTUP_HCLKX2DIV << 9) | (STARTUP_HCLKDIV << 8) | (STARTUP_MPLLDIV<<4) | STARTUP_APLLDIV)
	/* Set Clock Divider */
	ldr	r1, [r0, #CLK_DIV0_OFFSET]
	bic	r1, r1, #0x30000
	bic	r1, r1, #0xff00
	bic	r1, r1, #0xff
	ldr	r2, =CLK_DIV_VAL
	orr	r1, r1, r2
	str	r1, [r0, #CLK_DIV0_OFFSET]

//注释23. 配置APLL,MPLL锁相环倍频寄存器
//        CONFIG_CLK_533_133_66 已定义，选定STARTUP_AMDIV=533, STARTUP_MDIV=533, STARTUP_PDIV=6, STARTUP_SDIV=1
//        APLL_VAL = ((1 << 31) | (STARTUP_AMDIV << 16) | (STARTUP_PDIV << 8) | STARTUP_SDIV)
//        MPLL_VAL = ((1 << 31) | (STARTUP_MDIV << 16) | (STARTUP_PDIV << 8) | STARTUP_SDIV) 
//		  APLL,MPLL频率设为533MHz
	ldr	r1, =APLL_VAL
	str	r1, [r0, #APLL_CON_OFFSET]
	ldr	r1, =MPLL_VAL
	str	r1, [r0, #MPLL_CON_OFFSET]

// 注释24. 配置EPLL锁相环变频寄存器(不使能)
//          0x200203 = ((0 << 31)禁止EPLL | (32 << 16)M值 | (2 << 8)P值 | (3 << 0)S值), K = 0，
//			这里很奇怪，这样配置EPLL输出频率是24MHz, 芯片手册写需配置M=32,P=1,S=2,K=0
	/* FOUT of EPLL is 96MHz */
	ldr	r1, =0x200203
	str	r1, [r0, #EPLL_CON0_OFFSET]
	ldr	r1, =0x0
	str	r1, [r0, #EPLL_CON1_OFFSET]

// 注释25. 控制APLL,MPLL,EPLL输出频率	
	/* APLL, MPLL, EPLL select to Fout */
	ldr	r1, [r0, #CLK_SRC_OFFSET]
	orr	r1, r1, #0x7
	str	r1, [r0, #CLK_SRC_OFFSET]

	/* wait at least 200us to stablize all clock */
	mov	r1, #0x10000
1:	subs	r1, r1, #1
	bne	1b

// 注释26. CONFIG_SYNC_MODE未定义，CONFIG_S3C6400已定义，直接跳过
	/* Synchronization for VIC port */
#if defined(CONFIG_SYNC_MODE)
	ldr	r1, [r0, #OTHERS_OFFSET]
	orr	r1, r1, #0x20
	str	r1, [r0, #OTHERS_OFFSET]
#elif !defined(CONFIG_S3C6400)
	/* According to 661558um_S3C6400X_rev10.pdf 0x20 is reserved */
	ldr	r1, [r0, #OTHERS_OFFSET]
	bic	r1, r1, #0x20
	str	r1, [r0, #OTHERS_OFFSET]
#endif
	mov	pc, lr


#ifndef CONFIG_NAND_SPL
/*
 * uart_asm_init: Initialize UART's pins
 */
uart_asm_init:
	/* set GPIO to enable UART */
// 注释28. 	配置串口0,1的RXD,TXD对应的GPIO引脚(GPA0,1,4,5)
	ldr	r0, =ELFIN_GPIO_BASE
	ldr	r1, =0x220022
	str	r1, [r0, #GPACON_OFFSET]
	mov	pc, lr
#endif

#ifdef CONFIG_BOOT_NAND
/*
 * NAND Interface init for SMDK6400
 */
// 注释29. ELFIN_NAND_BASE为nand flash寄存器基地址.根据外接的nand flash芯片手册配置参数，最后使能nand flash
nand_asm_init:
	ldr	r0, =ELFIN_NAND_BASE
	ldr	r1, [r0, #NFCONF_OFFSET]
	orr	r1, r1, #0x70
	orr	r1, r1, #0x7700
	str	r1, [r0, #NFCONF_OFFSET]

	ldr	r1, [r0, #NFCONT_OFFSET]
	orr	r1, r1, #0x07
	str	r1, [r0, #NFCONT_OFFSET]

	mov	pc, lr
#endif

#ifdef CONFIG_ENABLE_MMU
/*
 * MMU Table for SMDK6400
 */

	/* form a first-level section entry */
.macro FL_SECTION_ENTRY base,ap,d,c,b
	.word (\base << 20) | (\ap << 10) | \
	      (\d << 5) | (1<<4) | (\c << 3) | (\b << 2) | (1<<1)
.endm

.section .mmudata, "a"
	.align 14
	/* the following alignment creates the mmu table at address 0x4000. */
	.globl mmu_table
mmu_table:
// 注释35. MMU页表, 令__base = 0         
	.set __base, 0
	/* 1:1 mapping for debugging */
// 注释36. 重复0xA00次, 这里是将内存虚拟地址0x00000000-0x9FFFFFFF映射到物理地址0x00000000-0x9FFFFFFF
	.rept 0xA00
	FL_SECTION_ENTRY __base, 3, 0, 0, 0
	.set __base, __base + 1
	.endr

	/* access is not allowed. */
// 注释37. 重复0x200次, 这里是将虚拟地址0xA0000000-0xBFFFFFFF空间映射到物理地址0x0处, 这部分空间不允许使用
	.rept 0xC00 - 0xA00
	.word 0x00000000
	.endr

	/* 128MB for SDRAM 0xC0000000 -> 0x50000000 */
// 注释38. 重复0x80次, 这里是将虚拟地址0xC0000000-0xC7FFFFFF空间映射到物理地址0x50000000-0x57FFFFFF,
	.set __base, 0x500
	.rept 0xC80 - 0xC00
	FL_SECTION_ENTRY __base, 3, 0, 1, 1
	.set __base, __base + 1
	.endr

// 注释39. 重复0x380次, 这里是将虚拟地址0xC8000000-0xFFFFFFFF空间映射到物理地址0x0处, 这部分空间不允许使用
	/* access is not allowed. */
	.rept 0x1000 - 0xc80
	.word 0x00000000
	.endr
#endif
