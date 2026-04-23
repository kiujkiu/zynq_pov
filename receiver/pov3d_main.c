/*
 * pov3d_main.c — skeleton main() for the Zynq-7020 bare-metal receiver.
 *
 * Based on Xilinx's "lwIP Echo Server" template.  Replace platform_*
 * calls and network-init with your BSP's flavor if they differ.
 *
 * What this shows:
 *   - pov3d_lwip_start() wires the TCP port to the decoder
 *   - on_model_def() stashes the latest model (static, one-shot)
 *   - on_frame()     stashes the latest pose so the render loop can use it
 *   - the main loop pumps xemacif_input() (required) and calls your
 *     render_one_frame() whenever new data is available
 *
 * TODO for you:
 *   - copy MODEL_DEF's vertex/index buffers into a permanent location
 *     (view pointers become invalid as soon as the next packet arrives)
 *   - apply skinning in your render_one_frame(): either on ARM Cortex-A9
 *     or via an AXI DMA to a PL voxelizer.
 */

#include "pov3d_lwip.h"
#include <stdio.h>
#include <string.h>

/* Platform glue from Xilinx standalone BSP / echo example */
extern void platform_enable_interrupts(void);
extern void init_platform(void);
extern void cleanup_platform(void);

/* lwIP / xemacps */
#include "lwip/init.h"
#include "lwip/inet.h"
#include "netif/xadapter.h"
#if defined(__MICROBLAZE__)
#  include "platform_config.h"
#endif
extern struct netif *echo_netif;
extern void lwip_init(void);
extern struct netif *xemac_add(struct netif *, ip_addr_t *, ip_addr_t *,
                               ip_addr_t *, unsigned char *, unsigned);


#define POV3D_PORT 9000u


/* ---------- application state: decoded model + latest frame ---------- */

#define MAX_VERTEX_BYTES  (256u * 1024u)
#define MAX_INDEX_BYTES   (128u * 1024u)
#define MAX_BONES         64u

static struct {
    int       have;
    uint16_t  model_id;
    uint16_t  flags;
    uint32_t  vertex_count;
    uint32_t  index_count;
    uint16_t  vertex_stride;
    uint16_t  vertex_attrs;
    uint16_t  bone_count;
    float     pos_scale[3];
    float     pos_offset[3];
    uint8_t   vertex_buf[MAX_VERTEX_BYTES];
    uint8_t   index_buf[MAX_INDEX_BYTES];
} g_model;

static struct {
    int       have;
    uint32_t  frame_id;
    uint32_t  timestamp_ms;
    float     model_matrix[16];
    uint16_t  bone_count;
    uint32_t  floats_per_bone;
    float     bones[MAX_BONES * 16];
} g_latest_frame;


static void on_model_def(void *user, const pov3d_model_def_view_t *m)
{
    (void)user;
    uint32_t vb = m->vertex_count * m->vertex_stride;
    uint32_t ib = m->index_count * 4u;
    if (vb > MAX_VERTEX_BYTES || ib > MAX_INDEX_BYTES) {
        xil_printf("[pov3d] model too large, rejecting\r\n");
        return;
    }
    g_model.model_id       = m->model_id;
    g_model.flags          = m->flags;
    g_model.vertex_count   = m->vertex_count;
    g_model.index_count    = m->index_count;
    g_model.vertex_stride  = m->vertex_stride;
    g_model.vertex_attrs   = m->vertex_attrs;
    g_model.bone_count     = m->bone_count;
    memcpy(g_model.pos_scale,  m->pos_scale,  sizeof(g_model.pos_scale));
    memcpy(g_model.pos_offset, m->pos_offset, sizeof(g_model.pos_offset));
    memcpy(g_model.vertex_buf, m->vertex_bytes, vb);
    memcpy(g_model.index_buf,  m->index_bytes,  ib);
    g_model.have = 1;
    xil_printf("[pov3d] MODEL_DEF id=%u flags=0x%04x verts=%u tris=%u "
               "bones=%u\r\n",
               m->model_id, m->flags, m->vertex_count,
               m->index_count / 3u, m->bone_count);
}


static void on_frame(void *user, pov3d_frame_view_t *f)
{
    (void)user;
    pov3d_frame_object_view_t obj;
    if (!pov3d_frame_next_object(f, &obj)) return;

    uint32_t n = (uint32_t)obj.bone_count * obj.floats_per_bone;
    if (obj.bone_count > MAX_BONES) return;

    g_latest_frame.frame_id        = f->frame_id;
    g_latest_frame.timestamp_ms    = f->timestamp_ms;
    memcpy(g_latest_frame.model_matrix, obj.model_matrix, 16 * 4);
    g_latest_frame.bone_count      = obj.bone_count;
    g_latest_frame.floats_per_bone = obj.floats_per_bone;
    if (n) memcpy(g_latest_frame.bones, obj.bone_matrices, n * 4);
    g_latest_frame.have = 1;

    /* drain additional objects (not used in this skeleton) */
    while (pov3d_frame_next_object(f, &obj)) { /* ignore */ }
}


static void on_bye(void *user) {
    (void)user;
    xil_printf("[pov3d] server sent BYE\r\n");
}
static void on_error(void *user, const char *msg) {
    (void)user;
    xil_printf("[pov3d] decoder error: %s\r\n", msg);
}


/* Stand-in for your real renderer; called at whatever rate you need. */
static void render_one_frame(void)
{
    if (!g_model.have || !g_latest_frame.have) return;
    /* TODO: CPU skinning or kick off AXI DMA to PL voxelizer. */
    g_latest_frame.have = 0;  /* ready for next */
}


int main(void)
{
    init_platform();

    ip_addr_t ipaddr, netmask, gw;
    unsigned char mac_ethernet_address[] = {0x00, 0x0a, 0x35, 0x00, 0x01, 0x02};

    /* adjust these to match your network */
    IP4_ADDR(&ipaddr,  192, 168,   1, 10);
    IP4_ADDR(&netmask, 255, 255, 255,  0);
    IP4_ADDR(&gw,      192, 168,   1,  1);

    lwip_init();

    echo_netif = xemac_add(echo_netif, &ipaddr, &netmask, &gw,
                           mac_ethernet_address, 0);
    if (!echo_netif) { xil_printf("xemac_add failed\r\n"); return -1; }

    netif_set_default(echo_netif);
    platform_enable_interrupts();
    netif_set_up(echo_netif);

    /* PC running python server.py.  Change to match your LAN. */
    ip_addr_t host_ip;
    IP4_ADDR(&host_ip, 192, 168, 1, 100);

    pov3d_callbacks_t cb = {
        .on_model_def = on_model_def,
        .on_frame     = on_frame,
        .on_bye       = on_bye,
        .on_error     = on_error,
        .user         = NULL,
    };
    if (pov3d_lwip_start(&host_ip, POV3D_PORT, &cb) != 0) {
        xil_printf("pov3d_lwip_start failed\r\n");
        return -1;
    }
    xil_printf("[pov3d] connecting to host :%u ...\r\n",
               (unsigned)POV3D_PORT);

    while (1) {
        xemacif_input(echo_netif);   /* required by Xilinx lwIP port */
        pov3d_lwip_tick();           /* drive reconnect */
        render_one_frame();
    }

    /* unreachable */
    cleanup_platform();
    return 0;
}
