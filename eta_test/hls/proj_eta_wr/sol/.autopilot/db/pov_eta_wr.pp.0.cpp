# 1 "pov_eta_wr.cpp"
# 1 "<built-in>" 1
# 1 "<built-in>" 3
# 389 "<built-in>" 3
# 1 "<command line>" 1
# 1 "<built-in>" 2
# 1 "C:/Xilinx/Vitis/2024.2/common/technology/autopilot\\etc/autopilot_ssdm_op.h" 1
# 105 "C:/Xilinx/Vitis/2024.2/common/technology/autopilot\\etc/autopilot_ssdm_op.h"
extern "C" {






    void _ssdm_op_IfRead(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_IfWrite(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    unsigned int __attribute__ ((bitwidth(1))) _ssdm_op_IfNbRead(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    unsigned int __attribute__ ((bitwidth(1))) _ssdm_op_IfNbWrite(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    unsigned int __attribute__ ((bitwidth(1))) _ssdm_op_IfCanRead(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    unsigned int __attribute__ ((bitwidth(1))) _ssdm_op_IfCanWrite(...) __attribute__ ((nothrow)) __attribute__((overloadable));


    void _ssdm_StreamRead(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_StreamWrite(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    unsigned int __attribute__ ((bitwidth(1))) _ssdm_StreamNbRead(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    unsigned int __attribute__ ((bitwidth(1))) _ssdm_StreamNbWrite(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    unsigned int __attribute__ ((bitwidth(1))) _ssdm_StreamCanRead(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    unsigned int __attribute__ ((bitwidth(1))) _ssdm_StreamCanWrite(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    unsigned _ssdm_StreamSize(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_ReadReq(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_Read(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_WriteReq(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_Write(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    unsigned int __attribute__ ((bitwidth(1))) _ssdm_op_NbReadReq(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    unsigned int __attribute__ ((bitwidth(1))) _ssdm_op_CanReadReq(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    unsigned int __attribute__ ((bitwidth(1))) _ssdm_op_NbWriteReq(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    unsigned int __attribute__ ((bitwidth(1))) _ssdm_op_CanWriteReq(...) __attribute__ ((nothrow)) __attribute__((overloadable));




    void _ssdm_op_MemShiftRead(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_op_PrintNone(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_PrintInt(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_PrintDouble(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_op_Wait(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_Poll(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_op_Return(...) __attribute__ ((nothrow)) __attribute__((overloadable));


    void _ssdm_op_SpecSynModule(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecTopModule(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecProcessDecl(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecProcessDef(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecPort(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecConnection(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecChannel(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecSensitive(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecModuleInst(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecPortMap(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_op_SpecReset(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_op_SpecPlatform(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecClockDomain(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecPowerDomain(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    int _ssdm_op_SpecRegionBegin(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    int _ssdm_op_SpecRegionEnd(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_op_SpecLoopName(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_op_SpecLoopTripCount(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    int _ssdm_op_SpecStateBegin(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    int _ssdm_op_SpecStateEnd(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_op_SpecInterface(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_op_SpecPipeline(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecDataflowPipeline(...) __attribute__ ((nothrow)) __attribute__((overloadable));


    void _ssdm_op_SpecLatency(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecParallel(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecProtocol(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecOccurrence(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_op_SpecResource(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecResourceLimit(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecCHCore(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecFUCore(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecIFCore(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecIPCore(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecMemCore(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_op_SpecExt(...) __attribute__ ((nothrow)) __attribute__((overloadable));




    void _ssdm_SpecArrayDimSize(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_RegionBegin(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_RegionEnd(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_InlineAll(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_InlineLoop(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_Inline(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_InlineSelf(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_InlineRegion(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_SpecArrayMap(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_SpecArrayPartition(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_SpecArrayReshape(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_SpecStream(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_op_SpecStable(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecStableContent(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_op_SpecBindPort(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_op_SpecPipoDepth(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_SpecExpr(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_SpecExprBalance(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_SpecDependence(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_SpecLoopMerge(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_SpecLoopFlatten(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_SpecLoopRewind(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_SpecFuncInstantiation(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_SpecFuncBuffer(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_SpecFuncExtract(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_SpecConstant(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_DataPack(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_SpecDataPack(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void _ssdm_op_SpecBitsMap(...) __attribute__ ((nothrow)) __attribute__((overloadable));
    void _ssdm_op_SpecLicense(...) __attribute__ ((nothrow)) __attribute__((overloadable));

    void __xilinx_ip_top(...) __attribute__ ((nothrow)) __attribute__((overloadable));


}
# 2 "<built-in>" 2
# 1 "pov_eta_wr.cpp" 2
# 11 "pov_eta_wr.cpp"
# 1 "D:/claude_workspace/pov3d/zynq_pov/hls_proj\\pov_slice_v2.h" 1
# 34 "D:/claude_workspace/pov3d/zynq_pov/hls_proj\\pov_slice_v2.h"
# 1 "C:\\Xilinx\\Vitis\\2024.2\\win64\\tools\\clang-3.9-csynth\\lib\\clang\\7.0.0\\include\\stdint.h" 1 3
# 63 "C:\\Xilinx\\Vitis\\2024.2\\win64\\tools\\clang-3.9-csynth\\lib\\clang\\7.0.0\\include\\stdint.h" 3
# 1 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\stdint.h" 1 3
# 28 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\stdint.h" 3
# 1 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\crtdefs.h" 1 3
# 10 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\crtdefs.h" 3
# 1 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\_mingw.h" 1 3
# 12 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\_mingw.h" 3
# 1 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include/_mingw_mac.h" 1 3
# 13 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\_mingw.h" 2 3
# 1 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include/_mingw_secapi.h" 1 3
# 44 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include/_mingw_secapi.h" 3
extern "C++" {
template <bool __test, typename __dsttype>
  struct __if_array;
template <typename __dsttype>
  struct __if_array <true, __dsttype> {
    typedef __dsttype __type;
};
}
# 14 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\_mingw.h" 2 3
# 282 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\_mingw.h" 3
# 1 "C:\\Xilinx\\Vitis\\2024.2\\win64\\tools\\clang-3.9-csynth\\lib\\clang\\7.0.0\\include\\vadefs.h" 1 3
# 26 "C:\\Xilinx\\Vitis\\2024.2\\win64\\tools\\clang-3.9-csynth\\lib\\clang\\7.0.0\\include\\vadefs.h" 3
# 1 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\vadefs.h" 1 3








# 1 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\_mingw.h" 1 3
# 595 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\_mingw.h" 3
# 1 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include/sdks/_mingw_directx.h" 1 3
# 596 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\_mingw.h" 2 3
# 1 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include/sdks/_mingw_ddk.h" 1 3
# 597 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\_mingw.h" 2 3
# 10 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\vadefs.h" 2 3




#pragma pack(push,_CRT_PACKING)



extern "C" {





  typedef __builtin_va_list __gnuc_va_list;






  typedef __gnuc_va_list va_list;
# 99 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\vadefs.h" 3
}



#pragma pack(pop)
# 27 "C:\\Xilinx\\Vitis\\2024.2\\win64\\tools\\clang-3.9-csynth\\lib\\clang\\7.0.0\\include\\vadefs.h" 2 3
# 283 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\_mingw.h" 2 3
# 558 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\_mingw.h" 3
extern "C" {
# 569 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\_mingw.h" 3
void __attribute__((__cdecl__)) __debugbreak(void);
extern __inline__ __attribute__((__always_inline__,__gnu_inline__)) void __attribute__((__cdecl__)) __debugbreak(void)
{
  __asm__ __volatile__("int {$}3":);
}




const char *__mingw_get_crt_info (void);


}
# 11 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\crtdefs.h" 2 3




#pragma pack(push,_CRT_PACKING)
# 35 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\crtdefs.h" 3
__extension__ typedef unsigned long size_t;
# 45 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\crtdefs.h" 3
__extension__ typedef long ssize_t;






typedef size_t rsize_t;
# 62 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\crtdefs.h" 3
__extension__ typedef long intptr_t;
# 75 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\crtdefs.h" 3
__extension__ typedef unsigned long uintptr_t;
# 88 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\crtdefs.h" 3
__extension__ typedef long ptrdiff_t;
# 106 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\crtdefs.h" 3
typedef unsigned short wint_t;
typedef unsigned short wctype_t;





typedef int errno_t;




typedef long __time32_t;




__extension__ typedef long __time64_t;
# 138 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\crtdefs.h" 3
typedef __time64_t time_t;
# 422 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\crtdefs.h" 3
struct threadlocaleinfostruct;
struct threadmbcinfostruct;
typedef struct threadlocaleinfostruct *pthreadlocinfo;
typedef struct threadmbcinfostruct *pthreadmbcinfo;
struct __lc_time_data;

typedef struct localeinfo_struct {
  pthreadlocinfo locinfo;
  pthreadmbcinfo mbcinfo;
} _locale_tstruct,*_locale_t;



typedef struct tagLC_ID {
  unsigned short wLanguage;
  unsigned short wCountry;
  unsigned short wCodePage;
} LC_ID,*LPLC_ID;




typedef struct threadlocaleinfostruct {
  int refcount;
  unsigned int lc_codepage;
  unsigned int lc_collate_cp;
  unsigned long lc_handle[6];
  LC_ID lc_id[6];
  struct {
    char *locale;
    wchar_t *wlocale;
    int *refcount;
    int *wrefcount;
  } lc_category[6];
  int lc_clike;
  int mb_cur_max;
  int *lconv_intl_refcount;
  int *lconv_num_refcount;
  int *lconv_mon_refcount;
  struct lconv *lconv;
  int *ctype1_refcount;
  unsigned short *ctype1;
  const unsigned short *pctype;
  const unsigned char *pclmap;
  const unsigned char *pcumap;
  struct __lc_time_data *lc_time_curr;
} threadlocinfo;







#pragma pack(pop)
# 29 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\stdint.h" 2 3



# 1 "C:\\Xilinx\\Vitis\\2024.2\\win64\\tools\\clang-3.9-csynth\\lib\\clang\\7.0.0\\include\\stddef.h" 1 3
# 33 "C:/Xilinx/Vitis/2024.2/tps/mingw/8.3.0/win64.o/nt\\x86_64-w64-mingw32\\include\\stdint.h" 2 3


typedef signed char int8_t;
typedef unsigned char uint8_t;
typedef short int16_t;
typedef unsigned short uint16_t;
typedef int int32_t;
typedef unsigned uint32_t;
__extension__ typedef long long int64_t;
__extension__ typedef unsigned long long uint64_t;


typedef signed char int_least8_t;
typedef unsigned char uint_least8_t;
typedef short int_least16_t;
typedef unsigned short uint_least16_t;
typedef int int_least32_t;
typedef unsigned uint_least32_t;
__extension__ typedef long long int_least64_t;
__extension__ typedef unsigned long long uint_least64_t;





typedef signed char int_fast8_t;
typedef unsigned char uint_fast8_t;
typedef short int_fast16_t;
typedef unsigned short uint_fast16_t;
typedef int int_fast32_t;
typedef unsigned int uint_fast32_t;
__extension__ typedef long long int_fast64_t;
__extension__ typedef unsigned long long uint_fast64_t;


__extension__ typedef long long intmax_t;
__extension__ typedef unsigned long long uintmax_t;
# 64 "C:\\Xilinx\\Vitis\\2024.2\\win64\\tools\\clang-3.9-csynth\\lib\\clang\\7.0.0\\include\\stdint.h" 2 3
# 35 "D:/claude_workspace/pov3d/zynq_pov/hls_proj\\pov_slice_v2.h" 2
# 94 "D:/claude_workspace/pov3d/zynq_pov/hls_proj\\pov_slice_v2.h"
void pov_slice_v2(
    const uint64_t *voxel,
    uint64_t *slot_base,
    int phase,
    int slot_start,
    int n_slots,
    int axis_off_q8,
    int mirror_u
);
# 12 "pov_eta_wr.cpp" 2
# 1 "D:/claude_workspace/pov3d/zynq_pov/hls_proj\\pov_slice_v2_lut.h" 1








# 1 "D:/claude_workspace/pov3d/zynq_pov/hls_proj/pov_slice_v2_lut_603.h" 1






static const int16_t PV2_COS8[603] = {
      256, 256, 256, 256, 256, 256, 255, 255, 255, 255, 255, 254,
      254, 254, 253, 253, 252, 252, 252, 251, 250, 250, 249, 249,
      248, 247, 247, 246, 245, 244, 244, 243, 242, 241, 240, 239,
      238, 237, 236, 235, 234, 233, 232, 231, 230, 228, 227, 226,
      225, 223, 222, 221, 219, 218, 217, 215, 214, 212, 211, 209,
      208, 206, 204, 203, 201, 199, 198, 196, 194, 193, 191, 189,
      187, 185, 184, 182, 180, 178, 176, 174, 172, 170, 168, 166,
      164, 162, 160, 158, 156, 154, 151, 149, 147, 145, 143, 140,
      138, 136, 134, 131, 129, 127, 125, 122, 120, 117, 115, 113,
      110, 108, 105, 103, 101, 98, 96, 93, 91, 88, 86, 83,
       81, 78, 76, 73, 70, 68, 65, 63, 60, 58, 55, 52,
       50, 47, 44, 42, 39, 37, 34, 31, 29, 26, 23, 21,
       18, 15, 13, 10, 7, 5, 2, -1, -3, -6, -9, -11,
      -14, -17, -19, -22, -25, -27, -30, -33, -35, -38, -41, -43,
      -46, -48, -51, -54, -56, -59, -61, -64, -67, -69, -72, -74,
      -77, -79, -82, -84, -87, -89, -92, -94, -97, -99, -102, -104,
     -107, -109, -112, -114, -116, -119, -121, -123, -126, -128, -130, -133,
     -135, -137, -139, -142, -144, -146, -148, -150, -153, -155, -157, -159,
     -161, -163, -165, -167, -169, -171, -173, -175, -177, -179, -181, -183,
     -185, -186, -188, -190, -192, -194, -195, -197, -199, -200, -202, -204,
     -205, -207, -208, -210, -211, -213, -214, -216, -217, -219, -220, -221,
     -223, -224, -225, -227, -228, -229, -230, -231, -232, -234, -235, -236,
     -237, -238, -239, -240, -241, -241, -242, -243, -244, -245, -246, -246,
     -247, -248, -248, -249, -250, -250, -251, -251, -252, -252, -253, -253,
     -253, -254, -254, -254, -255, -255, -255, -255, -256, -256, -256, -256,
     -256, -256, -256, -256, -256, -256, -256, -256, -255, -255, -255, -255,
     -254, -254, -254, -253, -253, -253, -252, -252, -251, -251, -250, -250,
     -249, -248, -248, -247, -246, -246, -245, -244, -243, -242, -241, -241,
     -240, -239, -238, -237, -236, -235, -234, -232, -231, -230, -229, -228,
     -227, -225, -224, -223, -221, -220, -219, -217, -216, -214, -213, -211,
     -210, -208, -207, -205, -204, -202, -200, -199, -197, -195, -194, -192,
     -190, -188, -186, -185, -183, -181, -179, -177, -175, -173, -171, -169,
     -167, -165, -163, -161, -159, -157, -155, -153, -150, -148, -146, -144,
     -142, -139, -137, -135, -133, -130, -128, -126, -123, -121, -119, -116,
     -114, -112, -109, -107, -104, -102, -99, -97, -94, -92, -89, -87,
      -84, -82, -79, -77, -74, -72, -69, -67, -64, -61, -59, -56,
      -54, -51, -48, -46, -43, -41, -38, -35, -33, -30, -27, -25,
      -22, -19, -17, -14, -11, -9, -6, -3, -1, 2, 5, 7,
       10, 13, 15, 18, 21, 23, 26, 29, 31, 34, 37, 39,
       42, 44, 47, 50, 52, 55, 58, 60, 63, 65, 68, 70,
       73, 76, 78, 81, 83, 86, 88, 91, 93, 96, 98, 101,
      103, 105, 108, 110, 113, 115, 117, 120, 122, 125, 127, 129,
      131, 134, 136, 138, 140, 143, 145, 147, 149, 151, 154, 156,
      158, 160, 162, 164, 166, 168, 170, 172, 174, 176, 178, 180,
      182, 184, 185, 187, 189, 191, 193, 194, 196, 198, 199, 201,
      203, 204, 206, 208, 209, 211, 212, 214, 215, 217, 218, 219,
      221, 222, 223, 225, 226, 227, 228, 230, 231, 232, 233, 234,
      235, 236, 237, 238, 239, 240, 241, 242, 243, 244, 244, 245,
      246, 247, 247, 248, 249, 249, 250, 250, 251, 252, 252, 252,
      253, 253, 254, 254, 254, 255, 255, 255, 255, 255, 256, 256,
      256, 256, 256,
};

static const int16_t PV2_SIN8[603] = {
        0, 3, 5, 8, 11, 13, 16, 19, 21, 24, 27, 29,
       32, 35, 37, 40, 42, 45, 48, 50, 53, 56, 58, 61,
       63, 66, 69, 71, 74, 76, 79, 81, 84, 86, 89, 91,
       94, 96, 99, 101, 104, 106, 108, 111, 113, 116, 118, 120,
      123, 125, 127, 130, 132, 134, 137, 139, 141, 143, 145, 148,
      150, 152, 154, 156, 158, 160, 163, 165, 167, 169, 171, 173,
      175, 176, 178, 180, 182, 184, 186, 188, 190, 191, 193, 195,
      197, 198, 200, 202, 203, 205, 206, 208, 210, 211, 213, 214,
      215, 217, 218, 220, 221, 222, 224, 225, 226, 227, 229, 230,
      231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242,
      243, 244, 245, 245, 246, 247, 248, 248, 249, 249, 250, 251,
      251, 252, 252, 253, 253, 253, 254, 254, 254, 255, 255, 255,
      255, 256, 256, 256, 256, 256, 256, 256, 256, 256, 256, 256,
      256, 255, 255, 255, 255, 255, 254, 254, 254, 253, 253, 252,
      252, 251, 251, 250, 250, 249, 249, 248, 247, 246, 246, 245,
      244, 243, 243, 242, 241, 240, 239, 238, 237, 236, 235, 234,
      233, 232, 230, 229, 228, 227, 226, 224, 223, 222, 220, 219,
      218, 216, 215, 213, 212, 210, 209, 207, 206, 204, 202, 201,
      199, 197, 196, 194, 192, 190, 189, 187, 185, 183, 181, 179,
      177, 176, 174, 172, 170, 168, 166, 164, 161, 159, 157, 155,
      153, 151, 149, 147, 144, 142, 140, 138, 135, 133, 131, 129,
      126, 124, 122, 119, 117, 114, 112, 110, 107, 105, 102, 100,
       98, 95, 93, 90, 88, 85, 83, 80, 77, 75, 72, 70,
       67, 65, 62, 59, 57, 54, 52, 49, 46, 44, 41, 39,
       36, 33, 31, 28, 25, 23, 20, 17, 15, 12, 9, 7,
        4, 1, -1, -4, -7, -9, -12, -15, -17, -20, -23, -25,
      -28, -31, -33, -36, -39, -41, -44, -46, -49, -52, -54, -57,
      -59, -62, -65, -67, -70, -72, -75, -77, -80, -83, -85, -88,
      -90, -93, -95, -98, -100, -102, -105, -107, -110, -112, -114, -117,
     -119, -122, -124, -126, -129, -131, -133, -135, -138, -140, -142, -144,
     -147, -149, -151, -153, -155, -157, -159, -161, -164, -166, -168, -170,
     -172, -174, -176, -177, -179, -181, -183, -185, -187, -189, -190, -192,
     -194, -196, -197, -199, -201, -202, -204, -206, -207, -209, -210, -212,
     -213, -215, -216, -218, -219, -220, -222, -223, -224, -226, -227, -228,
     -229, -230, -232, -233, -234, -235, -236, -237, -238, -239, -240, -241,
     -242, -243, -243, -244, -245, -246, -246, -247, -248, -249, -249, -250,
     -250, -251, -251, -252, -252, -253, -253, -254, -254, -254, -255, -255,
     -255, -255, -255, -256, -256, -256, -256, -256, -256, -256, -256, -256,
     -256, -256, -256, -255, -255, -255, -255, -254, -254, -254, -253, -253,
     -253, -252, -252, -251, -251, -250, -249, -249, -248, -248, -247, -246,
     -245, -245, -244, -243, -242, -241, -240, -239, -238, -237, -236, -235,
     -234, -233, -232, -231, -230, -229, -227, -226, -225, -224, -222, -221,
     -220, -218, -217, -215, -214, -213, -211, -210, -208, -206, -205, -203,
     -202, -200, -198, -197, -195, -193, -191, -190, -188, -186, -184, -182,
     -180, -178, -176, -175, -173, -171, -169, -167, -165, -163, -160, -158,
     -156, -154, -152, -150, -148, -145, -143, -141, -139, -137, -134, -132,
     -130, -127, -125, -123, -120, -118, -116, -113, -111, -108, -106, -104,
     -101, -99, -96, -94, -91, -89, -86, -84, -81, -79, -76, -74,
      -71, -69, -66, -63, -61, -58, -56, -53, -50, -48, -45, -42,
      -40, -37, -35, -32, -29, -27, -24, -21, -19, -16, -13, -11,
       -8, -5, -3,
};
# 10 "D:/claude_workspace/pov3d/zynq_pov/hls_proj\\pov_slice_v2_lut.h" 2
# 13 "pov_eta_wr.cpp" 2

__attribute__((sdx_kernel("pov_eta_wr", 0))) void pov_eta_wr(
    const uint64_t *voxel,
    uint64_t *slot_base,
    int phase,
    int slot_start,
    int n_slots,
    int axis_off_q8,
    int mirror_u
) {
#line 35 "D:/claude_workspace/pov3d/zynq_pov/eta_test/hls/run_eta_hls.tcl"
#pragma HLSDIRECTIVE TOP name=pov_eta_wr
# 22 "pov_eta_wr.cpp"







#pragma HLS INTERFACE m_axi port=voxel offset=slave bundle=vox depth=1990656 max_read_burst_length=64 num_read_outstanding=16

#pragma HLS INTERFACE m_axi port=slot_base offset=slave bundle=out depth=6251904 max_write_burst_length=64 num_write_outstanding=16

#pragma HLS INTERFACE s_axilite port=voxel bundle=control
#pragma HLS INTERFACE s_axilite port=slot_base bundle=control
#pragma HLS INTERFACE s_axilite port=phase bundle=control
#pragma HLS INTERFACE s_axilite port=slot_start bundle=control
#pragma HLS INTERFACE s_axilite port=n_slots bundle=control
#pragma HLS INTERFACE s_axilite port=axis_off_q8 bundle=control
#pragma HLS INTERFACE s_axilite port=mirror_u bundle=control
#pragma HLS INTERFACE ap_ctrl_hs port=return

 if (n_slots < 0) n_slots = 0;
    if (slot_start < 0) slot_start = 0;

SLICES:
    for (int s = 0; s < n_slots; s++) {
#pragma HLS LOOP_TRIPCOUNT min=151 max=603

 const int g = slot_start + s;
        int angle = (phase + g) % 603;
        if (angle < 0) angle += 603;

        const int cs = (int)PV2_COS8[angle];
        const int sn = (int)PV2_SIN8[angle];
# 65 "pov_eta_wr.cpp"
        const int off_x_q8 = -((axis_off_q8 * sn) >> 8);
        const int off_z_q8 = ((axis_off_q8 * cs) >> 8);

        uint64_t *slot = slot_base + (long)g * ((192 * 216) / 4);

COLUMNS:
        for (int px = 0; px < 192; px++) {
#pragma HLS LOOP_TRIPCOUNT min=192 max=192

 int u = px - (192 / 2);
            if (mirror_u) u = -u;


            const int rx = ((u * cs + off_x_q8 + 128) >> 8) + (192 / 2);
            const int rz = ((u * sn + off_z_q8 + 128) >> 8) + (192 / 2);

            const bool inside = (rx >= 0) && (rx < 192)
                             && (rz >= 0) && (rz < 192);




            const int vx = inside ? rx : 0;
            const int vz = inside ? rz : 0;


            const long src = ((long)vz * 192 + vx) * (216 / 4);
            const long dst = (long)px * (216 / 4);

COPY_COLUMN:
            for (int b = 0; b < (216 / 4); b++) {
#pragma HLS LOOP_TRIPCOUNT min=54 max=54
#pragma HLS PIPELINE II=1
 const uint64_t v = voxel[src + b];
                slot[dst + b] = inside ? v : (uint64_t)0;
            }
        }
    }
}
