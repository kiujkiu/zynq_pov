/*
 * pov3d_lwip.h — lwIP RAW-API TCP *client* that streams from the host.
 *
 * Topology:
 *      PC (python server.py)  <---------  Zynq (this code)
 *                 listens                 connects
 *
 * Zynq boots, connects to the PC server, and pipes every received byte
 * through the decoder.  On disconnect, the decoder resets and a retry
 * timer schedules a reconnect every POV3D_RECONNECT_MS.
 *
 * Drop these files into a Xilinx Vitis bare-metal project that links
 * lwIP (typically created from the "LwIP Echo Server" template).
 *
 *   #include "pov3d_lwip.h"
 *
 *   int main(void) {
 *       // ... MAC/PHY init, lwIP init (same as the echo template) ...
 *       pov3d_callbacks_t cb = { ... };
 *       ip_addr_t host; IP4_ADDR(&host, 192,168,1,100);
 *       pov3d_lwip_start(&host, 9000, &cb);
 *       while (1) {
 *           xemacif_input(echo_netif);
 *           pov3d_lwip_tick();   // drive reconnect timer
 *           // app work
 *       }
 *   }
 */

#ifndef POV3D_LWIP_H
#define POV3D_LWIP_H

#include "pov3d_decoder.h"
#include "lwip/ip_addr.h"

#ifdef __cplusplus
extern "C" {
#endif

/* Reconnect delay between failed attempts (milliseconds). */
#ifndef POV3D_RECONNECT_MS
#define POV3D_RECONNECT_MS 1000u
#endif

/* Configure the host to connect to and start trying immediately. */
int  pov3d_lwip_start(const ip_addr_t *host, uint16_t port,
                      const pov3d_callbacks_t *cb);

/* Must be called periodically from the main loop (every ms-ish is fine).
 * Drives reconnect when disconnected.  Uses sys_now() from lwIP. */
void pov3d_lwip_tick(void);

/* True while the TCP session is established. */
int  pov3d_lwip_connected(void);

#ifdef __cplusplus
}
#endif

#endif /* POV3D_LWIP_H */
