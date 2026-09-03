; ModuleID = 'D:/claude_workspace/pov3d/zynq_pov/eta_test/hls/proj_eta_wr/sol/.autopilot/db/a.g.ld.5.gdce.bc'
source_filename = "llvm-link"
target datalayout = "e-m:e-i64:64-i128:128-i256:256-i512:512-i1024:1024-i2048:2048-i4096:4096-n8:16:32:64-S128-v16:16-v24:32-v32:32-v48:64-v96:128-v192:256-v256:256-v512:512-v1024:1024"
target triple = "fpga64-xilinx-none"

; Function Attrs: noinline
define void @apatb_pov_eta_wr_ir(i64* noalias nocapture nonnull readonly "maxi" %voxel, i64* noalias nocapture nonnull "maxi" %slot_base, i32 %phase, i32 %slot_start, i32 %n_slots, i32 %axis_off_q8, i32 %mirror_u) local_unnamed_addr #0 {
entry:
  %0 = bitcast i64* %voxel to [1990656 x i64]*
  %1 = call i8* @malloc(i64 15925248)
  %voxel_copy = bitcast i8* %1 to [1990656 x i64]*
  %2 = bitcast i64* %slot_base to [6251904 x i64]*
  %3 = call i8* @malloc(i64 50015232)
  %slot_base_copy = bitcast i8* %3 to [6251904 x i64]*
  call fastcc void @copy_in([1990656 x i64]* nonnull %0, [1990656 x i64]* %voxel_copy, [6251904 x i64]* nonnull %2, [6251904 x i64]* %slot_base_copy)
  call void @apatb_pov_eta_wr_hw([1990656 x i64]* %voxel_copy, [6251904 x i64]* %slot_base_copy, i32 %phase, i32 %slot_start, i32 %n_slots, i32 %axis_off_q8, i32 %mirror_u)
  call void @copy_back([1990656 x i64]* %0, [1990656 x i64]* %voxel_copy, [6251904 x i64]* %2, [6251904 x i64]* %slot_base_copy)
  tail call void @free(i8* %1)
  tail call void @free(i8* %3)
  ret void
}

; Function Attrs: argmemonly noinline norecurse willreturn
define internal fastcc void @copy_in([1990656 x i64]* readonly, [1990656 x i64]*, [6251904 x i64]* readonly, [6251904 x i64]*) unnamed_addr #1 {
entry:
  call fastcc void @onebyonecpy_hls.p0a1990656i64([1990656 x i64]* %1, [1990656 x i64]* %0)
  call fastcc void @onebyonecpy_hls.p0a6251904i64([6251904 x i64]* %3, [6251904 x i64]* %2)
  ret void
}

; Function Attrs: argmemonly noinline norecurse willreturn
define internal fastcc void @onebyonecpy_hls.p0a1990656i64([1990656 x i64]* %dst, [1990656 x i64]* readonly %src) unnamed_addr #2 {
entry:
  %0 = icmp eq [1990656 x i64]* %dst, null
  %1 = icmp eq [1990656 x i64]* %src, null
  %2 = or i1 %0, %1
  br i1 %2, label %ret, label %copy

copy:                                             ; preds = %entry
  call void @arraycpy_hls.p0a1990656i64([1990656 x i64]* nonnull %dst, [1990656 x i64]* nonnull %src, i64 1990656)
  br label %ret

ret:                                              ; preds = %copy, %entry
  ret void
}

; Function Attrs: argmemonly noinline norecurse willreturn
define void @arraycpy_hls.p0a1990656i64([1990656 x i64]* %dst, [1990656 x i64]* readonly %src, i64 %num) local_unnamed_addr #3 {
entry:
  %0 = icmp eq [1990656 x i64]* %src, null
  %1 = icmp eq [1990656 x i64]* %dst, null
  %2 = or i1 %1, %0
  br i1 %2, label %ret, label %copy

copy:                                             ; preds = %entry
  %for.loop.cond1 = icmp sgt i64 %num, 0
  br i1 %for.loop.cond1, label %for.loop.lr.ph, label %copy.split

for.loop.lr.ph:                                   ; preds = %copy
  br label %for.loop

for.loop:                                         ; preds = %for.loop, %for.loop.lr.ph
  %for.loop.idx2 = phi i64 [ 0, %for.loop.lr.ph ], [ %for.loop.idx.next, %for.loop ]
  %dst.addr = getelementptr [1990656 x i64], [1990656 x i64]* %dst, i64 0, i64 %for.loop.idx2
  %src.addr = getelementptr [1990656 x i64], [1990656 x i64]* %src, i64 0, i64 %for.loop.idx2
  %3 = load i64, i64* %src.addr, align 8
  store i64 %3, i64* %dst.addr, align 8
  %for.loop.idx.next = add nuw nsw i64 %for.loop.idx2, 1
  %exitcond = icmp ne i64 %for.loop.idx.next, %num
  br i1 %exitcond, label %for.loop, label %copy.split

copy.split:                                       ; preds = %for.loop, %copy
  br label %ret

ret:                                              ; preds = %copy.split, %entry
  ret void
}

; Function Attrs: argmemonly noinline norecurse willreturn
define internal fastcc void @onebyonecpy_hls.p0a6251904i64([6251904 x i64]* %dst, [6251904 x i64]* readonly %src) unnamed_addr #2 {
entry:
  %0 = icmp eq [6251904 x i64]* %dst, null
  %1 = icmp eq [6251904 x i64]* %src, null
  %2 = or i1 %0, %1
  br i1 %2, label %ret, label %copy

copy:                                             ; preds = %entry
  call void @arraycpy_hls.p0a6251904i64([6251904 x i64]* nonnull %dst, [6251904 x i64]* nonnull %src, i64 6251904)
  br label %ret

ret:                                              ; preds = %copy, %entry
  ret void
}

; Function Attrs: argmemonly noinline norecurse willreturn
define void @arraycpy_hls.p0a6251904i64([6251904 x i64]* %dst, [6251904 x i64]* readonly %src, i64 %num) local_unnamed_addr #3 {
entry:
  %0 = icmp eq [6251904 x i64]* %src, null
  %1 = icmp eq [6251904 x i64]* %dst, null
  %2 = or i1 %1, %0
  br i1 %2, label %ret, label %copy

copy:                                             ; preds = %entry
  %for.loop.cond1 = icmp sgt i64 %num, 0
  br i1 %for.loop.cond1, label %for.loop.lr.ph, label %copy.split

for.loop.lr.ph:                                   ; preds = %copy
  br label %for.loop

for.loop:                                         ; preds = %for.loop, %for.loop.lr.ph
  %for.loop.idx2 = phi i64 [ 0, %for.loop.lr.ph ], [ %for.loop.idx.next, %for.loop ]
  %dst.addr = getelementptr [6251904 x i64], [6251904 x i64]* %dst, i64 0, i64 %for.loop.idx2
  %src.addr = getelementptr [6251904 x i64], [6251904 x i64]* %src, i64 0, i64 %for.loop.idx2
  %3 = load i64, i64* %src.addr, align 8
  store i64 %3, i64* %dst.addr, align 8
  %for.loop.idx.next = add nuw nsw i64 %for.loop.idx2, 1
  %exitcond = icmp ne i64 %for.loop.idx.next, %num
  br i1 %exitcond, label %for.loop, label %copy.split

copy.split:                                       ; preds = %for.loop, %copy
  br label %ret

ret:                                              ; preds = %copy.split, %entry
  ret void
}

; Function Attrs: argmemonly noinline norecurse willreturn
define internal fastcc void @copy_out([1990656 x i64]*, [1990656 x i64]* readonly, [6251904 x i64]*, [6251904 x i64]* readonly) unnamed_addr #4 {
entry:
  call fastcc void @onebyonecpy_hls.p0a1990656i64([1990656 x i64]* %0, [1990656 x i64]* %1)
  call fastcc void @onebyonecpy_hls.p0a6251904i64([6251904 x i64]* %2, [6251904 x i64]* %3)
  ret void
}

declare i8* @malloc(i64) local_unnamed_addr

declare void @free(i8*) local_unnamed_addr

declare void @apatb_pov_eta_wr_hw([1990656 x i64]*, [6251904 x i64]*, i32, i32, i32, i32, i32)

; Function Attrs: argmemonly noinline norecurse willreturn
define internal fastcc void @copy_back([1990656 x i64]*, [1990656 x i64]* readonly, [6251904 x i64]*, [6251904 x i64]* readonly) unnamed_addr #4 {
entry:
  call fastcc void @onebyonecpy_hls.p0a6251904i64([6251904 x i64]* %2, [6251904 x i64]* %3)
  ret void
}

declare void @pov_eta_wr_hw_stub(i64* noalias nocapture nonnull readonly, i64* noalias nocapture nonnull, i32, i32, i32, i32, i32)

define void @pov_eta_wr_hw_stub_wrapper([1990656 x i64]*, [6251904 x i64]*, i32, i32, i32, i32, i32) #5 {
entry:
  call void @copy_out([1990656 x i64]* null, [1990656 x i64]* %0, [6251904 x i64]* null, [6251904 x i64]* %1)
  %7 = bitcast [1990656 x i64]* %0 to i64*
  %8 = bitcast [6251904 x i64]* %1 to i64*
  call void @pov_eta_wr_hw_stub(i64* %7, i64* %8, i32 %2, i32 %3, i32 %4, i32 %5, i32 %6)
  call void @copy_in([1990656 x i64]* null, [1990656 x i64]* %0, [6251904 x i64]* null, [6251904 x i64]* %1)
  ret void
}

attributes #0 = { noinline "fpga.wrapper.func"="wrapper" }
attributes #1 = { argmemonly noinline norecurse willreturn "fpga.wrapper.func"="copyin" }
attributes #2 = { argmemonly noinline norecurse willreturn "fpga.wrapper.func"="onebyonecpy_hls" }
attributes #3 = { argmemonly noinline norecurse willreturn "fpga.wrapper.func"="arraycpy_hls" }
attributes #4 = { argmemonly noinline norecurse willreturn "fpga.wrapper.func"="copyout" }
attributes #5 = { "fpga.wrapper.func"="stub" }

!llvm.dbg.cu = !{}
!llvm.ident = !{!0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0, !0}
!llvm.module.flags = !{!1, !2, !3}
!blackbox_cfg = !{!4}

!0 = !{!"clang version 7.0.0 "}
!1 = !{i32 2, !"Dwarf Version", i32 4}
!2 = !{i32 2, !"Debug Info Version", i32 3}
!3 = !{i32 1, !"wchar_size", i32 4}
!4 = !{}
