`timescale 1ns/1ps
module eta_mon_tb;
  reg clk=0, rstn=0; always #3.333 clk=~clk;
  reg done0=0, idle0=1, ready0=0, done1=0, idle1=1, ready1=0;
  reg [31:0] ctrl=0; wire start0, start1; wire [31:0] dout;
  eta_mon dut(.clk(clk),.rstn(rstn),.done0(done0),.idle0(idle0),.ready0(ready0),.done1(done1),.idle1(idle1),.ready1(ready1),.ctrl(ctrl),.start0(start0),.start1(start1),.dout(dout));
  integer errs=0, i;
  task rd(input [3:0] s, output [31:0] v); begin ctrl[7:4]=s; @(posedge clk); #1 v=dout; end endtask
  task chk(input [3:0] s, input [31:0] exp, input [127:0] name); reg [31:0] v; begin rd(s,v); if (v!==exp) begin errs=errs+1; $display("FAIL %0s sel=%0d got=%h exp=%h",name,s,v,exp); end else $display("ok   %0s = %h",name,v); end endtask
  initial begin
    repeat(3) @(posedge clk); rstn=1; repeat(2) @(posedge clk);
    chk(6, 32'hE7A00001, "magic");
    ctrl[1]=1; ctrl[2]=1; @(posedge clk); #1; if (start0!==1 || start1!==1) begin errs=errs+1; $display("FAIL start fanout"); end
    // clear
    ctrl[3]=1; @(posedge clk); ctrl[3]=0; @(posedge clk);
    // ip0 busy for 100 cycles with 2 done pulses, ip1 busy for 60 cycles overlapping
    idle0=0; idle1=0;
    for (i=0;i<100;i=i+1) begin @(posedge clk); if (i==49||i==99) done0<=1; else done0<=0; if (i==59) idle1<=1; if (i==29) done1<=1; else done1<=0; end
    idle0=1; done0=0; @(posedge clk);
    // snapshot
    ctrl[0]=1; @(posedge clk); @(posedge clk);
    chk(1, 2, "done0"); chk(2, 1, "done1"); chk(10, 1, "snap_cnt");
    chk(11, 50, "per0 (done at i=49 and i=99 -> 50 cycles)"); chk(12, 1, "pcnt0"); chk(13, 0, "per1"); chk(14, 0, "pcnt1");
    begin : b reg [31:0] v0,v1,v3,v4,v5; rd(3,v3); rd(4,v4); rd(5,v5); rd(0,v0);
      $display("busy0=%0d busy1=%0d both=%0d cyc=%0d", v3, v4, v5, v0);
      if (v3<99||v3>102) begin errs=errs+1; $display("FAIL busy0 %0d",v3); end
      if (v4<59||v4>62) begin errs=errs+1; $display("FAIL busy1 %0d",v4); end
      if (v5!==v4) begin errs=errs+1; $display("FAIL both!=busy1"); end
      if (v0 < v3) begin errs=errs+1; $display("FAIL cyc<busy0"); end
    end
    // live counter moves; echo works
    begin : c reg [31:0] a,b2; rd(8,a); repeat(5) @(posedge clk); rd(8,b2); if (b2-a<5) begin errs=errs+1; $display("FAIL live cyc"); end
      rd(7,a); if (a!==ctrl) begin errs=errs+1; $display("FAIL echo"); end end
    ctrl[0]=0; ctrl[7:4]=9; @(posedge clk); #1 $display("status=%b", dout[5:0]);
    if (errs==0) $display("ETA_MON_TB_PASS"); else $display("ETA_MON_TB_FAIL errs=%0d",errs);
    $finish;
  end
endmodule
