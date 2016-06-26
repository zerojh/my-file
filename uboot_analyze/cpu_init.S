/*
 * Originates from Samsung's u-boot 1.1.6 port to S3C6400 / SMDK6400
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
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston,
 * MA 02111-1307 USA
 */

/* 此文件为smdk6400启动代码汇编文件cpu_init.S(arch\arm\cpu\s3c64xx)的分析 -------------2016.1.14*/
 
#include <config.h>
#include <asm/arch/s3c6400.h>

// 注释1. 声明mem_ctrl_asm_init在其它文件可使用，mem_ctrl_asm_init函数是根据DRAM控制器控制方法操作寄存器，具体看DRAMC 5.4节DRAM初始化顺序
	.globl mem_ctrl_asm_init
mem_ctrl_asm_init:
	/* DMC1 base address 0x7e001000 */
// 注释2. ELFIN_DMC1_BASE是DRAM控制寄存器基地址
	ldr	r0, =ELFIN_DMC1_BASE
	
// 注释3. INDEX_DMC_MEMC_CMD = 0x04, 设置MEMCCMD寄存器为configure状态
	ldr	r1, =0x4
	str	r1, [r0, #INDEX_DMC_MEMC_CMD]

// 注释4. DMC_DDR_REFRESH_PRD= NS_TO_CLK(7800ns), INDEX_DMC_REFRESH_PRD=0x10, 设置DRAM刷新周期
	ldr	r1, =DMC_DDR_REFRESH_PRD
	str	r1, [r0, #INDEX_DMC_REFRESH_PRD]

// 注释5. DMC_DDR_CAS_LATENCY = (3 << 1), INDEX_DMC_CAS_LATENCY = 0x14, 设置CAS(列地址选通脉冲延迟时间)
	ldr	r1, =DMC_DDR_CAS_LATENCY
	str	r1, [r0, #INDEX_DMC_CAS_LATENCY]

// 注释6. DMC_DDR_t_DQSS = 1, INDEX_DMC_T_DQSS = 0x18, 设置t_DQSS
	ldr	r1, =DMC_DDR_t_DQSS
	str	r1, [r0, #INDEX_DMC_T_DQSS]

// 注释7. DMC_DDR_t_MRD = 2, INDEX_DMC_T_MRD = 0x1C, 设置t_MRD
	ldr	r1, =DMC_DDR_t_MRD
	str	r1, [r0, #INDEX_DMC_T_MRD]

// 注释8. DMC_DDR_t_RAS = NS_TO_CLK(最小45ns) + 1, INDEX_DMC_T_RAS = 0x20, 设置t_RAS
	ldr	r1, =DMC_DDR_t_RAS
	str	r1, [r0, #INDEX_DMC_T_RAS]

// 注释9. DMC_DDR_t_RC = NS_TO_CLK(最小68ns) + 1, INDEX_DMC_T_RC = 0x24, 设置t_RC
	ldr	r1, =DMC_DDR_t_RC
	str	r1, [r0, #INDEX_DMC_T_RC]

// 注释10. DMC_DDR_t_RCD = NS_TO_CLK(最小23ns) + 1, DMC_DDR_schedule_RCD = ((DMC_DDR_t_RCD - 3) << 3), INDEX_DMC_T_RCD = 0x28, 设置t_RCD(RAS-CAS最小延迟)
	ldr	r1, =DMC_DDR_t_RCD
	ldr	r2, =DMC_DDR_schedule_RCD
	orr	r1, r1, r2
	str	r1, [r0, #INDEX_DMC_T_RCD]

// 注释11. DMC_DDR_t_RFC = (NS_TO_CLK(最小80ns) + 1), DMC_DDR_schedule_RFC = ((DMC_DDR_t_RFC - 3) << 5), INDEX_DMC_T_RFC = 0x2C, 设置t_RFC
	ldr	r1, =DMC_DDR_t_RFC
	ldr	r2, =DMC_DDR_schedule_RFC
	orr	r1, r1, r2
	str	r1, [r0, #INDEX_DMC_T_RFC]

// 注释12. = DMC_DDR_t_RP = NS_TO_CLK(最小23ns) + 1, DMC_DDR_schedule_RP = ((DMC_DDR_t_RP - 3) << 3), INDEX_DMC_T_RP = 0x30, 设置t_RP
	ldr	r1, =DMC_DDR_t_RP
	ldr	r2, =DMC_DDR_schedule_RP
	orr	r1, r1, r2
	str	r1, [r0, #INDEX_DMC_T_RP]

// 注释13. DMC_DDR_t_RRD = NS_TO_CLK(最小15ns) + 1, INDEX_DMC_T_RRD = 0x34, 设置t_RRD
	ldr	r1, =DMC_DDR_t_RRD
	str	r1, [r0, #INDEX_DMC_T_RRD]

// 注释14. DMC_DDR_t_WR = NS_TO_CLK(最小15ns) + 1, INDEX_DMC_T_WR = 0x38, 设置t_WR
	ldr	r1, =DMC_DDR_t_WR
	str	r1, [r0, #INDEX_DMC_T_WR]

// 注释15. DMC_DDR_t_WTR = 2, INDEX_DMC_T_WTR = 0x3C, 设置t_WTR
	ldr	r1, =DMC_DDR_t_WTR
	str	r1, [r0, #INDEX_DMC_T_WTR]

// 注释16. DMC_DDR_t_XP = 2, INDEX_DMC_T_XP = 0x40, 设置t_XP
	ldr	r1, =DMC_DDR_t_XP
	str	r1, [r0, #INDEX_DMC_T_XP]

// 注释17. DMC_DDR_t_XSR = NS_TO_CLK(最小120ns) + 1, INDEX_DMC_T_XSR = 0x44, 设置t_XSR
	ldr	r1, =DMC_DDR_t_XSR
	str	r1, [r0, #INDEX_DMC_T_XSR]

// 注释18. DMC_DDR_t_ESR = DMC_DDR_t_XSR = NS_TO_CLK(最小120ns) + 1,INDEX_DMC_T_ESR = 0x48, 设置t_ESR
	ldr	r1, =DMC_DDR_t_ESR
	str	r1, [r0, #INDEX_DMC_T_ESR]

// 注释19. DMC1_MEM_CFG = 0x00010012(2 << 15 | 2 << 3 | 2 << 0), INDEX_DMC_MEMORY_CFG = 0x0C, 配置DRAM行属性(13行)、列属性(10列)
	ldr	r1, =DMC1_MEM_CFG
	str	r1, [r0, #INDEX_DMC_MEMORY_CFG]

// 注释20. DMC1_MEM_CFG2 = 0xB45(1<<11|3<<8|1<<6|1<<3|0<<2|0<<1|1<<0),INDEX_DMC_MEMORY_CFG2 = 0x4C, 配置DRAM读延迟,内存类型,内存宽度等属性
	ldr	r1, =DMC1_MEM_CFG2
	str	r1, [r0, #INDEX_DMC_MEMORY_CFG2]

// 注释21. DMC1_CHIP0_CFG = 0x150F8(1 << 16 | 0x50 << 8 | 0xF8 << 0), INDEX_DMC_CHIP_0_CFG = 0x200
//         设置BRC, 0x50为设置50000000为内存寻址基地址, 0xF8为高5位不能变化, 所有只能128MB可寻址, tiny6410配的是256MB内存(需要改为0xF0)
	ldr	r1, =DMC1_CHIP0_CFG
	str	r1, [r0, #INDEX_DMC_CHIP_0_CFG]

// 注释22. DMC_DDR_32_CFG = 0, INDEX_DMC_USER_CONFIG = 0x304, 设置4个DQS为0
	ldr	r1, =DMC_DDR_32_CFG
	str	r1, [r0, #INDEX_DMC_USER_CONFIG]

// 注释23. INDEX_DMC_DIRECT_CMD = 0x08, DMC_NOP0 = 0 << 22 | 3 << 16, 让DRAM控制器执行NOP命令
	/* DMC0 DDR Chip 0 configuration direct command reg */
	ldr	r1, =DMC_NOP0
	str	r1, [r0, #INDEX_DMC_DIRECT_CMD]

// 注释24. DMC_PA0 = 0 <<22 | 0 << 16, 执行预充电命令
	/* Precharge All */
	ldr	r1, =DMC_PA0
	str	r1, [r0, #INDEX_DMC_DIRECT_CMD]

// 注释25. DMC_AR0 = 0 << 22 | 1 << 16, 执行2此自动刷新命令
	/* Auto Refresh 2 time */
	ldr	r1, =DMC_AR0
	str	r1, [r0, #INDEX_DMC_DIRECT_CMD]
	str	r1, [r0, #INDEX_DMC_DIRECT_CMD]

// 注释26. DMC_mDDR_EMR0 = 0 << 22 | 2 << 18 | 2 << 16, 设置MRS
	/* MRS */
	ldr	r1, =DMC_mDDR_EMR0
	str	r1, [r0, #INDEX_DMC_DIRECT_CMD]

// 注释27. DMC_mDDR_MR0 = 0x80032(0 << 22 | 2 << 18 | 32 << 0), 设置EMRS
	/* Mode Reg */
	ldr	r1, =DMC_mDDR_MR0
	str	r1, [r0, #INDEX_DMC_DIRECT_CMD]

// 注释28. INDEX_DMC_MEMC_CMD = 0x04, 设置DRAM控制器开始运行
	/* Enable DMC1 */
	mov	r1, #0x0
	str	r1, [r0, #INDEX_DMC_MEMC_CMD]

check_dmc1_ready:
// 注释29. INDEX_DMC_MEMC_STATUS = 0x0, DRAM状态寄存器, 不断检查DRAM寄存器是否准备好
	ldr	r1, [r0, #INDEX_DMC_MEMC_STATUS]
	mov	r2, #0x3
	and	r1, r1, r2
	cmp	r1, #0x1
	bne	check_dmc1_ready
	nop

	mov	pc, lr

// 注释30. 伪指令ltorg, 
	.ltorg
