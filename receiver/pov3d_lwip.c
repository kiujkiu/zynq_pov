/*
 * pov3d_lwip.c — lwIP RAW-API TCP client that feeds the decoder.
 *
 * Uses only synchronous/callback calls; does not compile on the host
 * (lwIP headers not present on PC).  Compile this file inside the Vitis
 * project only.
 *
 * The decoder state owns a large (>= 512 KB) buffer; we keep one global
 * instance to avoid heap allocation in bare-metal.
 */

#include "pov3d_lwip.h"
#include <string.h>

#include "lwip/tcp.h"
#include "lwip/err.h"
#include "lwip/sys.h"


static pov3d_decoder_t   g_decoder;
static int               g_connected;
static struct tcp_pcb   *g_pcb;

static ip_addr_t         g_host;
static uint16_t          g_port;
static uint32_t          g_next_try_ms;


static err_t pov3d_recv_cb(void *arg, struct tcp_pcb *tpcb,
                           struct pbuf *p, err_t err)
{
    (void)arg;
    if (err != ERR_OK) {
        if (p) pbuf_free(p);
        return err;
    }
    if (!p) {
        /* server closed */
        g_connected = 0;
        tcp_close(tpcb);
        g_pcb = NULL;
        pov3d_decoder_reset(&g_decoder);
        g_next_try_ms = sys_now() + POV3D_RECONNECT_MS;
        return ERR_OK;
    }

    struct pbuf *q = p;
    while (q) {
        if (pov3d_decoder_feed(&g_decoder, q->payload, q->len) < 0) {
            tcp_close(tpcb);
            g_pcb = NULL;
            g_connected = 0;
            pbuf_free(p);
            pov3d_decoder_reset(&g_decoder);
            g_next_try_ms = sys_now() + POV3D_RECONNECT_MS;
            return ERR_ABRT;
        }
        q = q->next;
    }

    tcp_recved(tpcb, p->tot_len);
    pbuf_free(p);
    return ERR_OK;
}


static void pov3d_err_cb(void *arg, err_t err)
{
    (void)arg; (void)err;
    /* pcb is already freed by lwIP on err_cb */
    g_pcb = NULL;
    g_connected = 0;
    pov3d_decoder_reset(&g_decoder);
    g_next_try_ms = sys_now() + POV3D_RECONNECT_MS;
}


static err_t pov3d_connected_cb(void *arg, struct tcp_pcb *tpcb, err_t err)
{
    (void)arg;
    if (err != ERR_OK) {
        tcp_close(tpcb);
        g_pcb = NULL;
        g_next_try_ms = sys_now() + POV3D_RECONNECT_MS;
        return err;
    }
    g_connected = 1;
    pov3d_decoder_reset(&g_decoder);
    return ERR_OK;
}


static void try_connect(void)
{
    if (g_pcb != NULL) return;         /* already trying */
    g_pcb = tcp_new();
    if (!g_pcb) {
        g_next_try_ms = sys_now() + POV3D_RECONNECT_MS;
        return;
    }
    tcp_nagle_disable(g_pcb);
    tcp_err(g_pcb, pov3d_err_cb);
    tcp_recv(g_pcb, pov3d_recv_cb);

    err_t e = tcp_connect(g_pcb, &g_host, g_port, pov3d_connected_cb);
    if (e != ERR_OK) {
        tcp_close(g_pcb);
        g_pcb = NULL;
        g_next_try_ms = sys_now() + POV3D_RECONNECT_MS;
    }
}


int pov3d_lwip_start(const ip_addr_t *host, uint16_t port,
                     const pov3d_callbacks_t *cb)
{
    pov3d_decoder_init(&g_decoder, cb);
    g_connected = 0;
    g_pcb = NULL;
    g_host = *host;
    g_port = port;
    g_next_try_ms = 0;   /* try immediately on first tick */
    return 0;
}


void pov3d_lwip_tick(void)
{
    if (g_connected || g_pcb != NULL) return;
    if (sys_now() < g_next_try_ms)   return;
    try_connect();
}


int pov3d_lwip_connected(void)
{
    return g_connected;
}
