#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ICND2260 mini-LVDS 供应商抓包 —— 整帧解剖 / 复现脚本
抓包: /mnt/c/Users/wanqi.liu/Desktop/2026-09-01_17-15-39.bin
      裸数据, 每样本 <u2 = 16 通道, 282,422,840 样本

通道: ch0/ch1 = mLVDS 第一差分对 (ch0 = P, 空闲 0)
      ch2     = 转发时钟, 半周期恒 16 样本 (1 "格"=1 个时钟沿=16 样本, 1 clk=2 格=32 样本)
      ch3     = I_SYNC (每帧跳变一次)
      ch4/ch5 = 供应商板上的 2bit "字段状态" 标记, 每个协议字段边界翻转一次(与数据对齐 ±1 格)

用法: python3 tools_wq_vendor_frame_dissect.py [帧号...]      # 默认 0 41 83
"""
import numpy as np, sys, collections

CAP = "/mnt/c/Users/wanqi.liu/Desktop/2026-09-01_17-15-39.bin"
A   = np.memmap(CAP, dtype='<u2', mode='r')

def isync_edges():
    ed=[]; prev=None; N=len(A); step=20_000_000
    for s in range(0,N,step):
        b=((np.asarray(A[s:s+step])>>3)&1).astype(np.uint8)
        if prev is not None and b[0]!=prev: ed.append(s)
        ed += (np.flatnonzero(np.diff(b))+1+s).tolist(); prev=b[-1]
    return np.array(ed,dtype=np.int64)

def crc16(bits, init=0xFFFF):                    # CRC-16/CCITT-FALSE, 线上顺序 MSB first
    r=init
    for b in bits:
        t=((r>>15)&1)^b; r=(r<<1)&0xFFFF
        if t: r^=0x1021
    return r

def cells(E, pre=1200, span=3_345_000):
    """把窗口切成"格": 每个时钟沿一格, 取格中点采样"""
    s0=E-pre
    seg=np.asarray(A[s0:s0+span]).astype(np.uint16)
    e=np.flatnonzero(np.diff((seg>>2)&1))+1
    mid=(e[:-1]+e[1:])//2
    u={c:((seg[mid]>>c)&1).astype(np.uint8) for c in (0,1,3,4,5)}
    return u, e[:-1]+s0

def val(bits):
    v=0
    for x in bits: v=(v<<1)|x
    return v

def dissect(E):
    u,cs = cells(E); s=''.join(map(str,u[0]))
    iE = int(np.searchsorted(cs,E))                  # I_SYNC 沿所在格
    c0 = s.find('0'*8+'1'*16, iE)+8                  # RSYNC 图样第一个 '1' 格  => 格号原点
    B4 = lambda o,n: [int(s[c0+o+4*i+1]) for i in range(n)]   # 4 格/位, 取组内第 2 格
    B1 = lambda o,n: [int(s[c0+o+i])     for i in range(n)]   # 1 格/位
    seg=[]; add=lambda nm,o,l,cpb,txt: seg.append((nm,o,l,cpb,txt))

    add("帧首 IDLE", iE-c0, c0-iE, 0, "全 0, I_SYNC 沿 -> RSYNC")
    add("RSYNC", 0, 56, 4, "格串 0xFFFF0F0F0F0F0F = "+s[c0:c0+56])
    hdr = B4(56,4)+B4(72,4)+B4(88,8)+B4(120,8)
    CMD,DEV,OFF,LEN = val(hdr[0:4]),val(hdr[4:8]),val(hdr[8:16]),val(hdr[16:24])
    N   = LEN+1                                      # 寄存器个数 = LENGTH+1
    add("CMD",     56,16,4, f"0b{CMD:04b} ({'写所有设备' if CMD==5 else CMD})")
    add("DEVICE",  72,16,4, f"{DEV}")
    add("OFFSET",  88,32,4, f"0x{OFF:02X}")
    add("LENGTH", 120,32,4, f"{LEN} => {N} 个寄存器")
    dat = B4(152,16*N)
    add("D0..D%d"%(N-1), 152, 64*N, 4, " ".join("%04X"%val(dat[16*i:16*i+16]) for i in range(N)))
    o=152+64*N
    chk=val(B4(o,16)); ok=crc16(hdr+dat)==chk
    add("CHKSUM", o, 64, 4, "0x%04X  CRC-16/CCITT-FALSE(CMD..D%d) %s"%(chk,N-1,"OK" if ok else "BAD"))
    o+=64;  add("IDLE", o, 192, 0, "全 0 (配置包 <-> VHEAD)")
    o+=192; vh=B1(o,48)
    add("VHEAD", o, 48, 1, "0x%012X  (A5A5|%04X|%04X, CRC(%04X)=%04X %s)"%
        (val(vh),val(vh[16:32]),val(vh[32:48]),val(vh[16:32]),crc16(vh[16:32]),
         "OK" if crc16(vh[16:32])==val(vh[32:48]) else "BAD"))
    o+=48;  vd=B1(o,6400); words=[val(vd[16*i:16*i+16]) for i in range(400)]
    add("Video Data", o, 6400, 1, "400 word x 16bit = 40 pixel/行 x 10 行; 取值 %s"%
        dict(collections.Counter(words).most_common(4)))
    o+=6400; vck=val(B1(o,16))
    add("Video CHECKSUM", o, 16, 1, "0x%04X  CRC-16/CCITT-FALSE(400 word) = 0x%04X %s  [注: 最后一格被发送端截短到 ~10/16 样本, 采样点偏后会读成 0x%04X]"%
        (vck, crc16(vd), "OK" if crc16(vd)==vck else "≈", crc16(vd)&~1))
    o+=16
    add("帧尾 IDLE", o, 208332-(o-(iE-c0))-0, 0, "全 0, 直到下一帧 I_SYNC 沿")
    return dict(E=E,c0=c0,iE=iE,seg=seg,active_end=o,CMD=CMD,DEV=DEV,OFF=OFF,LEN=LEN,
                REGS=[val(dat[16*i:16*i+16]) for i in range(N)],ok=ok)

if __name__=="__main__":
    ED=isync_edges()
    ks=[int(x) for x in sys.argv[1:]] or [0,41,83]
    print("I_SYNC 沿(=帧)总数: %d, 平均帧周期 %.1f 样本 = %.2f mLVDS_CLK"%
          (len(ED), np.diff(ED).mean(), np.diff(ED).mean()/32))
    for k in ks:
        r=dissect(int(ED[k]))
        print("\n===== 帧 %d  I_SYNC 沿 @样本 %d  (格号原点 c0 = RSYNC 第一个 '1' 格) ====="%(k,r['E']))
        print("%-14s %9s %9s %8s %6s  %s"%("段","起始格","结束格","长度格","clk","说明"))
        for nm,o,l,cpb,txt in r['seg']:
            print("%-14s %9d %9d %8d %6d  %s"%(nm,o,o+l-1,l,l//2,txt[:150]))
        act=r['active_end']-(r['iE']-r['c0'])
        print("一帧 = 208332 格 (104166 mLVDS_CLK); 有效(I_SYNC沿->Video CHECKSUM 末) = %d 格 (%d clk, %.2f%%); 空闲 %.2f%%"
              %(act,act//2,100*act/208332,100*(1-act/208332)))
