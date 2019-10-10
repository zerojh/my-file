
/*
 *  2016.1.30------------------------------分析phy_read(1)、phy_write(1)、dm9000_halt(2-3)、dm9000_reset(4-7)、
 *                                      dm9000_probe(8)、dm9000_init(9-14)
 *  2016.1.31------------------------------分析dm9000_send(15-21)、dm9000_rx(22-31),dm9000发送、接收方法芯片手册有写
 */

#include <common.h>
#include <command.h>
#include <net.h>
#include <asm/io.h>
#include <dm9000.h>

#include "dm9000x.h"

/* Board/System/Debug information/definition ---------------- */
#define CONFIG_DM9000_DEBUG

#ifdef CONFIG_DM9000_DEBUG
#define DM9000_DBG(fmt,args...) printf(fmt, ##args)
#define DM9000_DMP_PACKET(func,packet,length)  \
	do { \
		int i; 							\
		printf(func ": length: %d\n", length);			\
		for (i = 0; i < length; i++) {				\
			if (i % 8 == 0)					\
				printf("\n%s: %02x: ", func, i);	\
			printf("%02x ", ((unsigned char *) packet)[i]);	\
		} printf("\n");						\
	} while(0)
#else
#define DM9000_DBG(fmt,args...)
#define DM9000_DMP_PACKET(func,packet,length)
#endif

/* Structure/enum declaration ------------------------------- */
typedef struct board_info {
	u32 runt_length_counter;	/* counter: RX length < 64byte */
	u32 long_length_counter;	/* counter: RX length > 1514byte */
	u32 reset_counter;	/* counter: RESET */
	u32 reset_tx_timeout;	/* RESET caused by TX Timeout */
	u32 reset_rx_status;	/* RESET caused by RX Statsus wrong */
	u16 tx_pkt_cnt;
	u16 queue_start_addr;
	u16 dbug_cnt;
	u8 phy_addr;
	u8 device_wait_reset;	/* device state */
	unsigned char srom[128];
	void (*outblk)(volatile void *data_ptr, int count);
	void (*inblk)(void *data_ptr, int count);
	void (*rx_status)(u16 *RxStatus, u16 *RxLen);
	struct eth_device netdev;
} board_info_t;
static board_info_t dm9000_info;


/* function declaration ------------------------------------- */
static int dm9000_probe(void);
static u16 phy_read(int);
static void phy_write(int, u16);
static u8 DM9000_ior(int);
static void DM9000_iow(int reg, u8 value);

/* DM9000 network board routine ---------------------------- */

#define DM9000_outb(d,r) ( *(volatile u8 *)r = d )
#define DM9000_outw(d,r) ( *(volatile u16 *)r = d )
#define DM9000_outl(d,r) ( *(volatile u32 *)r = d )
#define DM9000_inb(r) (*(volatile u8 *)r)
#define DM9000_inw(r) (*(volatile u16 *)r)
#define DM9000_inl(r) (*(volatile u32 *)r)

#ifdef CONFIG_DM9000_DEBUG
static void
dump_regs(void)
{
	DM9000_DBG("\n");
	DM9000_DBG("NCR   (0x00): %02x\n", DM9000_ior(0));
	DM9000_DBG("NSR   (0x01): %02x\n", DM9000_ior(1));
	DM9000_DBG("TCR   (0x02): %02x\n", DM9000_ior(2));
	DM9000_DBG("TSRI  (0x03): %02x\n", DM9000_ior(3));
	DM9000_DBG("TSRII (0x04): %02x\n", DM9000_ior(4));
	DM9000_DBG("RCR   (0x05): %02x\n", DM9000_ior(5));
	DM9000_DBG("RSR   (0x06): %02x\n", DM9000_ior(6));
	DM9000_DBG("ISR   (0xFE): %02x\n", DM9000_ior(DM9000_ISR));
	DM9000_DBG("\n");
}
#endif

static void dm9000_outblk_8bit(volatile void *data_ptr, int count)
{
	int i;
	for (i = 0; i < count; i++)
		DM9000_outb((((u8 *) data_ptr)[i] & 0xff), DM9000_DATA);
}

static void dm9000_outblk_16bit(volatile void *data_ptr, int count)
{
	int i;
	u32 tmplen = (count + 1) / 2;

	for (i = 0; i < tmplen; i++)
		DM9000_outw(((u16 *) data_ptr)[i], DM9000_DATA);
}
static void dm9000_outblk_32bit(volatile void *data_ptr, int count)
{
	int i;
	u32 tmplen = (count + 3) / 4;

	for (i = 0; i < tmplen; i++)
		DM9000_outl(((u32 *) data_ptr)[i], DM9000_DATA);
}

static void dm9000_inblk_8bit(void *data_ptr, int count)
{
	int i;
	for (i = 0; i < count; i++)
		((u8 *) data_ptr)[i] = DM9000_inb(DM9000_DATA);
}

static void dm9000_inblk_16bit(void *data_ptr, int count)
{
	int i;
	u32 tmplen = (count + 1) / 2;

	for (i = 0; i < tmplen; i++)
		((u16 *) data_ptr)[i] = DM9000_inw(DM9000_DATA);
}
static void dm9000_inblk_32bit(void *data_ptr, int count)
{
	int i;
	u32 tmplen = (count + 3) / 4;

	for (i = 0; i < tmplen; i++)
		((u32 *) data_ptr)[i] = DM9000_inl(DM9000_DATA);
}

static void dm9000_rx_status_32bit(u16 *RxStatus, u16 *RxLen)
{
	u32 tmpdata;

	DM9000_outb(DM9000_MRCMD, DM9000_IO);

	tmpdata = DM9000_inl(DM9000_DATA);
	*RxStatus = __le16_to_cpu(tmpdata);
	*RxLen = __le16_to_cpu(tmpdata >> 16);
}

static void dm9000_rx_status_16bit(u16 *RxStatus, u16 *RxLen)
{
	DM9000_outb(DM9000_MRCMD, DM9000_IO);

	*RxStatus = __le16_to_cpu(DM9000_inw(DM9000_DATA));
	*RxLen = __le16_to_cpu(DM9000_inw(DM9000_DATA));
}

static void dm9000_rx_status_8bit(u16 *RxStatus, u16 *RxLen)
{
	DM9000_outb(DM9000_MRCMD, DM9000_IO);

	*RxStatus =
	    __le16_to_cpu(DM9000_inb(DM9000_DATA) +
			  (DM9000_inb(DM9000_DATA) << 8));
	*RxLen =
	    __le16_to_cpu(DM9000_inb(DM9000_DATA) +
			  (DM9000_inb(DM9000_DATA) << 8));
}

/*
  Search DM9000 board, allocate space and register it
*/
int
dm9000_probe(void)
{
	u32 id_val;
// 注释8. DM9000_VIDL = 0x28, DM9000_VIDH = 0x29, DM9000_PIDL = 0x2A, DM9000_PIDH = 0x2B, DM9000_ID = 0x90000A46
//        CONFIG_DM9000_BASE = 0x18000000, 看从寄存器读出来的厂商ID和产品ID是否与DM9000_ID一致,
//        不一致会让dm9000_probe返回-1, 继而让dm9000_init返回-1
	id_val = DM9000_ior(DM9000_VIDL);
	id_val |= DM9000_ior(DM9000_VIDH) << 8;
	id_val |= DM9000_ior(DM9000_PIDL) << 16;
	id_val |= DM9000_ior(DM9000_PIDH) << 24;
	if (id_val == DM9000_ID) {
		printf("dm9000 i/o: 0x%x, id: 0x%x \n", CONFIG_DM9000_BASE,
		       id_val);
		return 0;
	} else {
		printf("dm9000 not found at 0x%08x id: 0x%08x\n",
		       CONFIG_DM9000_BASE, id_val);
		return -1;
	}
}

/* General Purpose dm9000 reset routine */
static void
dm9000_reset(void)
{
	DM9000_DBG("resetting DM9000\n");

	/* Reset DM9000,
	   see DM9000 Application Notes V1.22 Jun 11, 2004 page 29 */

	/* DEBUG: Make all GPIO0 outputs, all others inputs */
	//DM9000_iow(DM9000_GPCR, GPCR_GPIO0_OUT);
	/* Step 1: Power internal PHY by writing 0 to GPIO0 pin */
// 注释4. DM9000_GPR = 0x1F, 给第0位写0开启PHY层
//        DM9000_NCR = 0x00, NCR_LBK_INT_MAC = 1<<1, NCR_RST = 1, 设置内部回环模式, 第一次重置MAC层
	DM9000_iow(DM9000_GPR, 0);
	/* Step 2: Software reset */
	DM9000_iow(DM9000_NCR, (NCR_LBK_INT_MAC | NCR_RST));

// 注释5. 重置MAC层需要至少10us, 重置完毕会使DM9000_NCR第0位清0
	do {
		DM9000_DBG("resetting the DM9000, 1st reset\n");
		udelay(15); /* Wait at least 10 us */
	} while (DM9000_ior(DM9000_NCR) & 1);

// 注释6. 与第一次重置一样, 再进行一次重置
	DM9000_iow(DM9000_NCR, 0);
	DM9000_iow(DM9000_NCR, (NCR_LBK_INT_MAC | NCR_RST)); /* Issue a second reset */

	do {
		DM9000_DBG("resetting the DM9000, 2nd reset\n");
		udelay(15); /* Wait at least 10 us */
	} while (DM9000_ior(DM9000_NCR) & 1);

	/* Check whether the ethernet controller is present */
// 注释7. DM9000_PIDL = 0x2A, DM9000_PIDH = 0x2B, 确认DM9000芯片Product id是否为9000
	if ((DM9000_ior(DM9000_PIDL) != 0x0) ||
	    (DM9000_ior(DM9000_PIDH) != 0x90))
		printf("ERROR: resetting DM9000 -> not responding\n");
}

/* Initialize dm9000 board
*/
static int dm9000_init(struct eth_device *dev, bd_t *bd)
{
	int i, oft, lnk;
	u8 io_mode;
	struct board_info *db = &dm9000_info;

	DM9000_DBG("%s\n", __func__);

	/* RESET device , 看注释4-7*/
	dm9000_reset();

	if (dm9000_probe() < 0) /* 看注释8*/
		return -1;

	/* Auto-detect 8/16/32 bit mode, ISR Bit 6+7 indicate bus width */
// 注释9. DM9000_ISR = 0xFE, 查看DM9000的位模式, 这里用的芯片是16位模式的
	io_mode = DM9000_ior(DM9000_ISR) >> 6;

	switch (io_mode) {
	case 0x0:  /* 16-bit mode */
		printf("DM9000: running in 16 bit mode\n");
		db->outblk    = dm9000_outblk_16bit;
		db->inblk     = dm9000_inblk_16bit;
		db->rx_status = dm9000_rx_status_16bit;
		break;
	case 0x01:  /* 32-bit mode */
		printf("DM9000: running in 32 bit mode\n");
		db->outblk    = dm9000_outblk_32bit;
		db->inblk     = dm9000_inblk_32bit;
		db->rx_status = dm9000_rx_status_32bit;
		break;
	case 0x02: /* 8 bit mode */
		printf("DM9000: running in 8 bit mode\n");
		db->outblk    = dm9000_outblk_8bit;
		db->inblk     = dm9000_inblk_8bit;
		db->rx_status = dm9000_rx_status_8bit;
		break;
	default:
		/* Assume 8 bit mode, will probably not work anyway */
		printf("DM9000: Undefined IO-mode:0x%x\n", io_mode);
		db->outblk    = dm9000_outblk_8bit;
		db->inblk     = dm9000_inblk_8bit;
		db->rx_status = dm9000_rx_status_8bit;
		break;
	}

// 注释10. DM9000_NCR = 0x0, 设置为正常模式, 
//         DM9000_TCR = 0x2, TX控制寄存器
//         DM9000_BPTR = 0x8, BPTR_BPHW(3) = 3 << 4, BPTR_JPT_600US = 0x0f, 设置RX RAM空间不足3KB时, 发送JAM信号,
//    持续600us.
//         DM9000_FCTR = 0x9, FCTR_HWOT(3) = 3 << 4, FCTR_LWOT(8)) = 0x8, 设置RX RAM空间不足3KB时, 发送一个暂停
//    包, 让发送方暂停发送; RX RAM空间超过8KB时, 发送一个暂停包, 让发送方继续发送
//         DM9000_FCR = 0xA, 禁止流量控制
//         DM9000_SMCR = 0x2F, 禁止特定模式
//         DM9000_NSR = 0x1, 清除状态位(唤醒时间、包1发送完毕、包2发送完毕)
//         DM9000_ISR= 0xFE, 清除状态位(水流溢出、水流溢出计数、传输完成、接收数据包)
	/* Program operating register, only internal phy supported */
	DM9000_iow(DM9000_NCR, 0x0);
	/* TX Polling clear */
	DM9000_iow(DM9000_TCR, 0);
	/* Less 3Kb, 200us */
	DM9000_iow(DM9000_BPTR, BPTR_BPHW(3) | BPTR_JPT_600US);
	/* Flow Control : High/Low Water */
	DM9000_iow(DM9000_FCTR, FCTR_HWOT(3) | FCTR_LWOT(8));
	/* SH FIXME: This looks strange! Flow Control */
	DM9000_iow(DM9000_FCR, 0x0);
	/* Special Mode */
	DM9000_iow(DM9000_SMCR, 0);
	/* clear TX status */
	DM9000_iow(DM9000_NSR, NSR_WAKEST | NSR_TX2END | NSR_TX1END);
	/* Clear interrupt status */
	DM9000_iow(DM9000_ISR, ISR_ROOS | ISR_ROS | ISR_PTS | ISR_PRS);

	printf("MAC: %pM\n", dev->enetaddr);

	/* fill device MAC address registers */
// 注释11. DM9000_PAR = 0x10, 往MAC地址寄存器写MAC地址
//         0x16~0x1D是组播地址寄存器, 将组播地址写入寄存器
	for (i = 0, oft = DM9000_PAR; i < 6; i++, oft++)
		DM9000_iow(oft, dev->enetaddr[i]);
	for (i = 0, oft = 0x16; i < 8; i++, oft++)
		DM9000_iow(oft, 0xff);

	/* read back mac, just to be sure */
	for (i = 0, oft = 0x10; i < 6; i++, oft++)
		DM9000_DBG("%02x:", DM9000_ior(oft));
	DM9000_DBG("\n");

	/* Activate DM9000 */
	/* RX enable */
// 注释12. DM9000_RCR = 0x05, 设置使能RX, 接收时丢掉数据大于1522字节的包和CRC检验错误的包
//         DM9000_IMR = 0xFF, 使能SRAM读写指针在超出SRAM大小时自动返回开始位置, 继续屏蔽所有中断
	DM9000_iow(DM9000_RCR, RCR_DIS_LONG | RCR_DIS_CRC | RCR_RXEN);
	/* Enable TX/RX interrupt mask */
	DM9000_iow(DM9000_IMR, IMR_PAR);

// 注释13. 判断是否具备自动协调功能, 具备并判断自动协调是否完成
	if (phy_read(1) & 0x8) {
		i = 0;
		while (!(phy_read(1) & 0x20)) {	/* autonegation complete bit */
			udelay(1000);
			i++;
			if (i == 10000) {
				printf("could not establish link\n");
				return 0;
			}
		}
	}

// 注释14. 读取PHY传输模式, 这个网卡是100M全双工模式的
	/* see what we've got */
	lnk = phy_read(17) >> 12;
	printf("operating at ");
	switch (lnk) {
	case 1:
		printf("10M half duplex ");
		break;
	case 2:
		printf("10M full duplex ");
		break;
	case 4:
		printf("100M half duplex ");
		break;
	case 8:
		printf("100M full duplex ");
		break;
	default:
		printf("unknown: %d ", lnk);
		break;
	}
	printf("mode\n");
	return 0;
}

/*
  Hardware start transmission.
  Send a packet to media from the upper layer.
*/
static int dm9000_send(struct eth_device *netdev, volatile void *packet,
		     int length)
{
	int tmo;
	struct board_info *db = &dm9000_info;

	DM9000_DMP_PACKET("dm9000_send" , packet, length);

// 注释15. DM9000_ISR = 0xFE, IMR_PTM = 1 << 1, 清除包传输完毕状态位
	DM9000_iow(DM9000_ISR, IMR_PTM); /* Clear Tx bit in ISR */

// 注释16. DM9000_MWCMD = 0xF8, DM9000_IO = 0x18000000, 准备为TX RAM写数据
	/* Move data to DM9000 TX RAM */
	DM9000_outb(DM9000_MWCMD, DM9000_IO); /* Prepare for TX-data */

	/* push the data to the TX-fifo */
// 注释17. 将以太网包放入TX RAM中
	(db->outblk)(packet, length);

	/* Set TX length to DM9000 */
// 注释18. DM9000_TXPLL = 0xFC, DM9000_TXPLH = 0xFD, 设置发送的以太网包大小
	DM9000_iow(DM9000_TXPLL, length & 0xff);
	DM9000_iow(DM9000_TXPLH, (length >> 8) & 0xff);

	/* Issue TX polling command */
// 注释19. DM9000_TCR = 0x02, TCR_TXREQ = 1 << 0, 请求发送数据, 发送完毕自动将第0位清0
	DM9000_iow(DM9000_TCR, TCR_TXREQ); /* Cleared after TX complete */

	/* wait for end of transmission */
// 注释20. 等5秒, 判断两条发送通道是否已结束或者DM9000_ISR寄存器的IMR_PTM标志位是否1(即发送完毕)
	tmo = get_timer(0) + 5 * CONFIG_SYS_HZ;
	while ( !(DM9000_ior(DM9000_NSR) & (NSR_TX1END | NSR_TX2END)) ||
		!(DM9000_ior(DM9000_ISR) & IMR_PTM) ) {
		if (get_timer(0) >= tmo) {
			printf("transmission timeout\n");
			break;
		}
	}
// 注释21. DM9000_ISR = 0xFE, 请除IMR_PTM标志位, 发送完成
	DM9000_iow(DM9000_ISR, IMR_PTM); /* Clear Tx bit in ISR */

	DM9000_DBG("transmit done\n\n");
	return 0;
}

/*
  Stop the interface.
  The interface is stopped when it is brought.
*/
static void dm9000_halt(struct eth_device *netdev)
{
	DM9000_DBG("%s\n", __func__);

	/* RESET devie */
// 注释2. 给PHY层通过软件复位
	phy_write(0, 0x8000);	/* PHY RESET */
// 注释3. DM9000_GPR = 0x1F, 关闭PHY层
//        DM9000_IMR = 0xFF, 关闭所有中断
//        DM9000_RCR = 0x05, 关闭RX
	DM9000_iow(DM9000_GPR, 0x01);	/* Power-Down PHY */
	DM9000_iow(DM9000_IMR, 0x80);	/* Disable all interrupt */
	DM9000_iow(DM9000_RCR, 0x00);	/* Disable RX */
}

/*
  Received a packet and pass to upper layer
*/
static int dm9000_rx(struct eth_device *netdev)
{
	u8 rxbyte, *rdptr = (u8 *) NetRxPackets[0];
	u16 RxStatus, RxLen = 0;
	struct board_info *db = &dm9000_info;

	/* Check packet ready or not, we must check
	   the ISR status first for DM9000A */
// 注释22. DM9000_ISR = 0xFE, 判断是否接收以太网包完毕(第0位)
	if (!(DM9000_ior(DM9000_ISR) & 0x01)) /* Rx-ISR bit must be set. */
		return 0;
		
// 注释23. 如果接收完毕则写第0位清0
	DM9000_iow(DM9000_ISR, 0x01); /* clear PR status latched in bit 0 */

	/* There is _at least_ 1 package in the fifo, read them all */
	for (;;) {
// 注释24. DM9000_MRCMDX = 0xF0, 空读一字节, 但SRAM指针没有偏移, 让dm9000开始sram内接收的数据预读到data缓冲区
		DM9000_ior(DM9000_MRCMDX);	/* Dummy read */

		/* Get most updated data,
		   only look at bits 0:1, See application notes DM9000 */
// 注释25. 从DM9000芯片手册中知道, 在接收数据包的时候, 还加上4Byte的首部,
//        4字节中分别是0x01, 状态, 以太网包大小的低8位, 以太网包大小的高8位
//        现在读取第一字节的低2位, 就是01
		rxbyte = DM9000_inb(DM9000_DATA) & 0x03;

		/* Status check: this byte must be 0 or 1 */
// 注释26. DM9000_PKT_RDY = 0x01, 如果读出来的比1大, 则关闭设备且关中断请求, 输出错误
		if (rxbyte > DM9000_PKT_RDY) {
			DM9000_iow(DM9000_RCR, 0x00);	/* Stop Device */
			DM9000_iow(DM9000_ISR, 0x80);	/* Stop INT request */
			printf("DM9000 error: status check fail: 0x%x\n",
				rxbyte);
			return 0;
		}

// 注释27. 如果rxbyte = 0, 则证明数据包还没被接收
		if (rxbyte != DM9000_PKT_RDY)
			return 0; /* No packet received, ignore */

		DM9000_DBG("receiving packet\n");

// 注释28. 将4字节头部的前2字节读到RxStatus中, 后2字节读到RxLen中, 这里读取完毕SRAM指针会偏移4字节
		/* A packet ready now  & Get status/length */
		(db->rx_status)(&RxStatus, &RxLen);

		DM9000_DBG("rx status: 0x%04x rx len: %d\n", RxStatus, RxLen);

		/* Move data from DM9000 */
		/* Read received packet from RX SRAM */
// 注释29.开始读取RxLen长度的以太网包
		(db->inblk)(rdptr, RxLen);

// 注释30. 检查以太网包状态与长度
		if ((RxStatus & 0xbf00) || (RxLen < 0x40)
			|| (RxLen > DM9000_PKT_MAX)) {
			if (RxStatus & 0x100) {
				printf("rx fifo error\n");
			}
			if (RxStatus & 0x200) {
				printf("rx crc error\n");
			}
			if (RxStatus & 0x8000) {
				printf("rx length error\n");
			}
			if (RxLen > DM9000_PKT_MAX) {
				printf("rx length too big\n");
				dm9000_reset();
			}
		} else {
			DM9000_DMP_PACKET("dm9000_rx" , rdptr, RxLen);

			DM9000_DBG("passing packet to upper layer\n");
// 注释31. 将以太网包传到上层进行解析
			NetReceive(NetRxPackets[0], RxLen);
		}
	}
	return 0;
}

/*
  Read a word data from SROM
*/
#if !defined(CONFIG_DM9000_NO_SROM)
void dm9000_read_srom_word(int offset, u8 *to)
{
	DM9000_iow(DM9000_EPAR, offset);
	DM9000_iow(DM9000_EPCR, 0x4);
	udelay(8000);
	DM9000_iow(DM9000_EPCR, 0x0);
	to[0] = DM9000_ior(DM9000_EPDRL);
	to[1] = DM9000_ior(DM9000_EPDRH);
}

void dm9000_write_srom_word(int offset, u16 val)
{
	DM9000_iow(DM9000_EPAR, offset);
	DM9000_iow(DM9000_EPDRH, ((val >> 8) & 0xff));
	DM9000_iow(DM9000_EPDRL, (val & 0xff));
	DM9000_iow(DM9000_EPCR, 0x12);
	udelay(8000);
	DM9000_iow(DM9000_EPCR, 0);
}
#endif

static void dm9000_get_enetaddr(struct eth_device *dev)
{
#if !defined(CONFIG_DM9000_NO_SROM)
	int i;
	for (i = 0; i < 3; i++)
		dm9000_read_srom_word(i, dev->enetaddr + (2 * i));
#else
	int i;
	char *s, *e;
	s = getenv("ethaddr");
	for (i = 0; i < 6; i++) {
		dev->enetaddr[i] = s ? simple_strtoul(s, &e, 16) : 0;
		if (s)
			s = (*e) ? e + 1 : e;
	}
#endif
}

/*
   Read a byte from I/O port
*/
static u8
DM9000_ior(int reg)
{
	DM9000_outb(reg, DM9000_IO);
	return DM9000_inb(DM9000_DATA);
}

/*
   Write a byte to I/O port
*/
static void
DM9000_iow(int reg, u8 value)
{
	DM9000_outb(reg, DM9000_IO);
	DM9000_outb(value, DM9000_DATA);
}

/*
   Read a word from phyxcer
*/

// 注释1. phy_read, phy_write分别是读, 写PHY寄存器或者接在dm9000的EEPROM(有接的情况), 其中
//        DM9000_EPAR = 0x0C, DM9000_EPCR = 0x0B, DM9000_EPDRH = 0x0E, DM9000_EPDRL = 0x0D, 
//        DM9000_PHY = 0x1 << 6, 芯片规定的
//        读操作: 向DM9000_EPAR写需读的地址, 写DM9000_EPCR使能读命令, 这样需读的数据就会读到DM9000_EPDRH与
//                 DM9000_EPDRL中(16位数据), 然后写DM9000_EPCR清除读命令
//        写操作: 向向DM9000_EPAR写需写的地址, 将写的数据放入DM9000_EPDRH与DM9000_EPDRL, 然后写DM9000_EPCR
//                使能写命令, 最后写DM9000_EPCR清除写命令
static u16
phy_read(int reg)
{
	u16 val;

	/* Fill the phyxcer register into REG_0C */
	DM9000_iow(DM9000_EPAR, DM9000_PHY | reg);
	DM9000_iow(DM9000_EPCR, 0xc);	/* Issue phyxcer read command */
	udelay(100);			/* Wait read complete */
	DM9000_iow(DM9000_EPCR, 0x0);	/* Clear phyxcer read command */
	val = (DM9000_ior(DM9000_EPDRH) << 8) | DM9000_ior(DM9000_EPDRL);

	/* The read data keeps on REG_0D & REG_0E */
	DM9000_DBG("phy_read(0x%x): 0x%x\n", reg, val);
	return val;
}

/*
   Write a word to phyxcer
*/
static void
phy_write(int reg, u16 value)
{

	/* Fill the phyxcer register into REG_0C */
	DM9000_iow(DM9000_EPAR, DM9000_PHY | reg);

	/* Fill the written data into REG_0D & REG_0E */
	DM9000_iow(DM9000_EPDRL, (value & 0xff));
	DM9000_iow(DM9000_EPDRH, ((value >> 8) & 0xff));
	DM9000_iow(DM9000_EPCR, 0xa);	/* Issue phyxcer write command */
	udelay(500);			/* Wait write complete */
	DM9000_iow(DM9000_EPCR, 0x0);	/* Clear phyxcer write command */
	DM9000_DBG("phy_write(reg:0x%x, value:0x%x)\n", reg, value);
}

int dm9000_initialize(bd_t *bis)
{
	struct eth_device *dev = &(dm9000_info.netdev);

	/* Load MAC address from EEPROM  or Envirment*/
	dm9000_get_enetaddr(dev);

	dev->init = dm9000_init;
	dev->halt = dm9000_halt;
	dev->send = dm9000_send;
	dev->recv = dm9000_rx;
	sprintf(dev->name, "dm9000");

	eth_register(dev);

	return 0;
}
