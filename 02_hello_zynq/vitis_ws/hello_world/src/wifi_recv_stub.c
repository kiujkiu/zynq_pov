/* wifi_recv_stub.c — Phase 9 framework, NOT compiled into helloworld.elf yet.
 *
 * Goal: when lwIP / Ethernet path is up (rotate from UART RX), this file
 * holds the recv loop that eats PWFR sessions and feeds the existing PMSH /
 * PPCL state machines in helloworld.c.
 *
 * Today (2026-05-07) this file is a STUB:
 *   - Does not link with lwIP (no <lwip/tcp.h> include guarded by HAVE_LWIP).
 *   - Provides a thin abstraction `wifi_rx_byte()` / `wifi_rx_has()` that
 *     mirrors `uart_rx_byte()` / `uart_rx_has()` so the existing
 *     uart_poll_frame() body in helloworld.c can be reused near-verbatim.
 *   - PWFR header parsing is implemented and unit-testable on host
 *     (compile with `gcc -DSTANDALONE_TEST wifi_recv_stub.c`).
 *
 * Wire format and msg_type table: docs/wifi_protocol.md
 *
 * Integration plan (Phase 9-C, after lwIP BSP add):
 *   1. Vitis BSP settings → enable lwip213 (raw API, no thread).
 *   2. Replace this stub's `wifi_rx_byte()` body with reads from a ring
 *      buffer fed by `tcp_recv` / `udp_recv` callbacks.
 *   3. Rename helloworld.c::uart_poll_frame() → recv_poll_frame() and
 *      add a dispatch on PWFR magic at the head of the byte stream.
 */

#include <stdint.h>
#include <stddef.h>
#include <string.h>

#ifndef STANDALONE_TEST
/* xil_printf only available in Vitis builds */
#include "xil_printf.h"
#else
#include <stdio.h>
#define xil_printf printf
#endif

/* ------------------------------------------------------------------ */
/* PWFR header — must match host/wifi_stream.py                       */
/* ------------------------------------------------------------------ */
#define PWFR_MAGIC   0x52465750u   /* 'PWFR' little-endian */
#define PWFR_VER     1
#define PWFR_HDR_SZ  24

#pragma pack(push, 1)
typedef struct {
    uint32_t magic;       /* 0..3   PWFR_MAGIC */
    uint16_t ver;         /* 4..5 */
    uint16_t msg_type;    /* 6..7 */
    uint32_t seq;         /* 8..11 */
    uint32_t payload_len; /* 12..15 */
    uint32_t payload_crc; /* 16..19 */
    uint16_t ack_seq;     /* 20..21 */
    uint16_t reserved;    /* 22..23 */
} pwfr_hdr_t;
#pragma pack(pop)

_Static_assert(sizeof(pwfr_hdr_t) == PWFR_HDR_SZ, "pwfr_hdr size");

/* msg_type values (host/wifi_stream.py) */
enum {
    MSG_PING        = 0x0001,
    MSG_PONG        = 0x0002,
    MSG_FULL_PMSH   = 0x0010,
    MSG_FULL_PPCL   = 0x0011,
    MSG_FULL_VOXEL  = 0x0012,
    MSG_DELTA_VOXEL = 0x0020,
    MSG_PHASE       = 0x0030,
    MSG_MODE        = 0x0040,
    MSG_ACK         = 0x0080,
    MSG_NAK         = 0x0081,
    MSG_FPS         = 0x0090,
};

/* ------------------------------------------------------------------ */
/* CRC32 (zlib variant) — needed to verify payload                    */
/* ------------------------------------------------------------------ */
static uint32_t crc32_table[256];
static int      crc32_table_built;

static void crc32_build(void) {
    for (uint32_t i = 0; i < 256; ++i) {
        uint32_t c = i;
        for (int k = 0; k < 8; ++k)
            c = (c & 1) ? (0xEDB88320u ^ (c >> 1)) : (c >> 1);
        crc32_table[i] = c;
    }
    crc32_table_built = 1;
}

uint32_t pwfr_crc32(const uint8_t *buf, size_t n) {
    if (!crc32_table_built) crc32_build();
    uint32_t c = 0xFFFFFFFFu;
    for (size_t i = 0; i < n; ++i)
        c = crc32_table[(c ^ buf[i]) & 0xFF] ^ (c >> 8);
    return c ^ 0xFFFFFFFFu;
}

/* ------------------------------------------------------------------ */
/* Receive ring buffer (filled by lwIP callback in production build)  */
/* ------------------------------------------------------------------ */
#define WIFI_RX_RING_SZ  (1 << 16)   /* 64 KB, ample for 30 Hz delta */
static volatile uint8_t  wifi_rx_ring[WIFI_RX_RING_SZ];
static volatile uint32_t wifi_rx_head;     /* write idx (lwIP cb) */
static volatile uint32_t wifi_rx_tail;     /* read idx (recv_poll) */

int wifi_rx_has(void) {
    return wifi_rx_head != wifi_rx_tail;
}

uint8_t wifi_rx_byte(void) {
    /* Caller must check wifi_rx_has() first. Single-consumer assumption. */
    uint32_t t = wifi_rx_tail;
    uint8_t b = wifi_rx_ring[t & (WIFI_RX_RING_SZ - 1)];
    wifi_rx_tail = t + 1;
    return b;
}

/* Called from lwIP TCP / UDP recv callback (Phase 9-C). For Phase 9-A
 * stub, exposed for unit test. */
int wifi_rx_push(const uint8_t *buf, size_t n) {
    uint32_t h = wifi_rx_head;
    uint32_t t = wifi_rx_tail;
    uint32_t free = WIFI_RX_RING_SZ - (h - t);
    if (n > free) return -1;
    for (size_t i = 0; i < n; ++i)
        wifi_rx_ring[(h + i) & (WIFI_RX_RING_SZ - 1)] = buf[i];
    wifi_rx_head = h + n;
    return 0;
}

/* ------------------------------------------------------------------ */
/* PWFR session parser                                                */
/* ------------------------------------------------------------------ */
typedef enum {
    WS_HDR,        /* collecting 24 byte header */
    WS_PAYLOAD,    /* collecting payload bytes  */
} wifi_state_t;

static wifi_state_t  ws_state;
static pwfr_hdr_t    ws_hdr;
static uint32_t      ws_hdr_got;
static uint8_t       ws_payload[1 << 16];  /* 64 KB max single message */
static uint32_t      ws_payload_got;

/* Statistics — exposed for diagnostics over xil_printf */
typedef struct {
    uint32_t frames_ok;
    uint32_t frames_bad_magic;
    uint32_t frames_bad_crc;
    uint32_t frames_oversize;
    uint32_t bytes_recv;
    uint32_t last_seq;
} wifi_stats_t;

static wifi_stats_t ws_stats;

/* Forward declarations to existing helloworld.c handlers — Phase 9-C will
 * actually wire these. For Phase 9-A they are weak stubs (linker overridable).
 *
 * Under STANDALONE_TEST we instead expect the test harness at the bottom of
 * this file to provide strong definitions, so we omit the weak fallbacks.
 */
#ifndef STANDALONE_TEST
__attribute__((weak)) void board_handle_pmsh(const uint8_t *buf, uint32_t n) {
    (void)buf;
    xil_printf("[wifi-stub] PMSH n=%u (no handler)\r\n", (unsigned)n);
}
__attribute__((weak)) void board_handle_ppcl(const uint8_t *buf, uint32_t n) {
    (void)buf;
    xil_printf("[wifi-stub] PPCL n=%u (no handler)\r\n", (unsigned)n);
}
__attribute__((weak)) void board_handle_voxel_full(const uint8_t *buf, uint32_t n) {
    (void)buf;
    xil_printf("[wifi-stub] FULL_VOXEL n=%u (no handler)\r\n", (unsigned)n);
}
__attribute__((weak)) void board_handle_voxel_delta(const uint8_t *buf, uint32_t n) {
    (void)buf;
    xil_printf("[wifi-stub] DELTA n=%u (no handler)\r\n", (unsigned)n);
}
__attribute__((weak)) void board_handle_phase(uint32_t phase_q16_16, uint32_t fid) {
    (void)phase_q16_16; (void)fid;
}
__attribute__((weak)) void board_send_ack(uint32_t seq, uint8_t status) {
    (void)seq; (void)status;
}
__attribute__((weak)) void board_send_nak(uint32_t missing_seq, uint32_t reason) {
    (void)missing_seq; (void)reason;
}
#else
/* STANDALONE_TEST: forward decls only — strong definitions live in main(). */
void board_handle_pmsh(const uint8_t *, uint32_t);
void board_handle_ppcl(const uint8_t *, uint32_t);
void board_handle_voxel_full(const uint8_t *, uint32_t);
void board_handle_voxel_delta(const uint8_t *, uint32_t);
void board_handle_phase(uint32_t, uint32_t);
void board_send_ack(uint32_t, uint8_t);
void board_send_nak(uint32_t, uint32_t);
/* Provide trivial defaults for the handlers the test doesn't override. */
void board_handle_voxel_full(const uint8_t *b, uint32_t n)  { (void)b; (void)n; }
void board_handle_voxel_delta(const uint8_t *b, uint32_t n) { (void)b; (void)n; }
void board_send_ack(uint32_t s, uint8_t st)  { (void)s; (void)st; }
void board_send_nak(uint32_t s, uint32_t r)  { (void)s; (void)r; }
#endif

/* dispatch one fully-received PWFR message */
static void wifi_dispatch(void) {
    const pwfr_hdr_t *h = &ws_hdr;
    uint32_t crc = pwfr_crc32(ws_payload, h->payload_len);
    if (crc != h->payload_crc) {
        ws_stats.frames_bad_crc++;
        board_send_nak(h->seq, /*reason=CRC_FAIL*/ 1);
        return;
    }
    ws_stats.frames_ok++;
    ws_stats.last_seq = h->seq;

    switch (h->msg_type) {
    case MSG_FULL_PMSH:
        board_handle_pmsh(ws_payload, h->payload_len);
        break;
    case MSG_FULL_PPCL:
        board_handle_ppcl(ws_payload, h->payload_len);
        break;
    case MSG_FULL_VOXEL:
        board_handle_voxel_full(ws_payload, h->payload_len);
        break;
    case MSG_DELTA_VOXEL:
        board_handle_voxel_delta(ws_payload, h->payload_len);
        break;
    case MSG_PHASE:
        if (h->payload_len >= 8) {
            uint32_t phase, fid;
            memcpy(&phase, ws_payload + 0, 4);
            memcpy(&fid,   ws_payload + 4, 4);
            board_handle_phase(phase, fid);
        }
        break;
    case MSG_PING:
        /* TODO Phase 9-C: send_msg(MSG_PONG, ws_payload, h->payload_len) */
        break;
    case MSG_MODE:
        /* TODO: switch board_mode = payload[0] */
        break;
    default:
        xil_printf("[wifi] unknown msg_type=0x%x\r\n", h->msg_type);
        break;
    }

    /* periodic ack */
    if ((ws_stats.frames_ok & 0x7) == 0)
        board_send_ack(h->seq, /*status=OK*/ 0);
}

/* Drain ring → state machine. Returns count of full PWFR frames decoded
 * this call. Cap iterations so we never block render loop (mirror of
 * uart_poll_frame()'s 256-byte guard).
 */
int wifi_poll_frame(void) {
    int frames = 0;
    int guard  = 4096;
    while (guard-- > 0 && wifi_rx_has()) {
        uint8_t b = wifi_rx_byte();
        ws_stats.bytes_recv++;

        if (ws_state == WS_HDR) {
            ((uint8_t *)&ws_hdr)[ws_hdr_got++] = b;
            if (ws_hdr_got == 4) {
                if (ws_hdr.magic != PWFR_MAGIC) {
                    /* slide window 1 byte */
                    ws_stats.frames_bad_magic++;
                    memmove(&ws_hdr, ((uint8_t *)&ws_hdr) + 1, 3);
                    ws_hdr_got = 3;
                    continue;
                }
            }
            if (ws_hdr_got == PWFR_HDR_SZ) {
                if (ws_hdr.payload_len > sizeof(ws_payload)) {
                    ws_stats.frames_oversize++;
                    /* skip this message — drain payload_len bytes silently */
                    /* simplest: reset, hope to resync on next magic */
                    ws_hdr_got = 0;
                    ws_state = WS_HDR;
                    continue;
                }
                ws_payload_got = 0;
                ws_state = (ws_hdr.payload_len == 0) ? WS_HDR : WS_PAYLOAD;
                if (ws_state == WS_HDR) {
                    /* zero-payload msg, dispatch immediately */
                    wifi_dispatch();
                    ws_hdr_got = 0;
                    frames++;
                }
            }
        } else { /* WS_PAYLOAD */
            ws_payload[ws_payload_got++] = b;
            if (ws_payload_got == ws_hdr.payload_len) {
                wifi_dispatch();
                ws_state = WS_HDR;
                ws_hdr_got = 0;
                ws_payload_got = 0;
                frames++;
            }
        }
    }
    return frames;
}

void wifi_recv_init(void) {
    crc32_build();
    ws_state = WS_HDR;
    ws_hdr_got = 0;
    ws_payload_got = 0;
    memset((void *)&ws_stats, 0, sizeof(ws_stats));
    wifi_rx_head = wifi_rx_tail = 0;
    xil_printf("[wifi] recv stub ready (PWFR ver=%d, ring=%d KB)\r\n",
               PWFR_VER, WIFI_RX_RING_SZ / 1024);
}

void wifi_print_stats(void) {
    xil_printf("[wifi] ok=%u badmagic=%u badcrc=%u oversize=%u bytes=%u lastseq=%u\r\n",
               (unsigned)ws_stats.frames_ok,
               (unsigned)ws_stats.frames_bad_magic,
               (unsigned)ws_stats.frames_bad_crc,
               (unsigned)ws_stats.frames_oversize,
               (unsigned)ws_stats.bytes_recv,
               (unsigned)ws_stats.last_seq);
}

/* ------------------------------------------------------------------ */
/* STANDALONE_TEST: gcc -DSTANDALONE_TEST wifi_recv_stub.c -o wt && ./wt
 * ------------------------------------------------------------------ */
#ifdef STANDALONE_TEST

static void pack_and_push(uint16_t mtype, const uint8_t *payload,
                          uint32_t plen, uint32_t seq) {
    pwfr_hdr_t h = {
        .magic = PWFR_MAGIC, .ver = PWFR_VER, .msg_type = mtype,
        .seq = seq, .payload_len = plen, .payload_crc = pwfr_crc32(payload, plen),
        .ack_seq = 0, .reserved = 0,
    };
    wifi_rx_push((uint8_t *)&h, sizeof(h));
    if (plen) wifi_rx_push(payload, plen);
}

static int phase_seen, pmsh_seen, ppcl_seen;

void board_handle_phase(uint32_t phase, uint32_t fid) {
    (void)phase; (void)fid; phase_seen++;
}
void board_handle_pmsh(const uint8_t *b, uint32_t n) { (void)b; (void)n; pmsh_seen++; }
void board_handle_ppcl(const uint8_t *b, uint32_t n) { (void)b; (void)n; ppcl_seen++; }

int main(void) {
    wifi_recv_init();
    /* Push 3 valid frames, then one with bad magic byte injected first */
    uint8_t phase_payload[8] = {0x12,0x34,0x56,0x78, 0x07,0,0,0};
    pack_and_push(MSG_PHASE, phase_payload, sizeof(phase_payload), 1);
    uint8_t mesh_payload[64];
    for (int i = 0; i < 64; i++) mesh_payload[i] = (uint8_t)i;
    pack_and_push(MSG_FULL_PMSH, mesh_payload, sizeof(mesh_payload), 2);
    pack_and_push(MSG_FULL_PPCL, mesh_payload, sizeof(mesh_payload), 3);
    /* a stray byte to test magic resync */
    uint8_t junk = 0xAA;
    wifi_rx_push(&junk, 1);
    pack_and_push(MSG_PHASE, phase_payload, sizeof(phase_payload), 4);

    int n = wifi_poll_frame();
    printf("decoded %d frames\n", n);
    wifi_print_stats();
    printf("phase=%d pmsh=%d ppcl=%d\n", phase_seen, pmsh_seen, ppcl_seen);
    return (n == 4 && phase_seen == 2 && pmsh_seen == 1 && ppcl_seen == 1) ? 0 : 1;
}
#endif /* STANDALONE_TEST */
