---
name: HDMI VDMA framebuffer byte order = GBR (not BGR)
description: PL HDMI pipeline reads framebuffer bytes as (G,B,R) per pixel — firmware must write that order, not BGR.
type: project
originSessionId: bafc105a-a8db-471f-ae33-42571927b4da
---
PL HDMI VDMA on this Vivado BD reads framebuffer bytes as (byte0=G, byte1=B, byte2=R), not the usual BGR888. This is presumably a wire crossing somewhere between v_axi4s_vid_out and the DVI TX in the BD. Discovered 2026-04-27 by anime test: yellow source (255,212,151) was displaying as pink (255,151,212) and blue source (66,113,165) as cyan-green (66,165,113) — both consistent with G↔B swap.

**Why:** Without this knowledge, every framebuffer write to `helloworld.c` looks "obviously BGR" but produces wrong colors.

**How to apply:** When writing a 24-bit pixel at `u8 *p`, use `p[0]=g; p[1]=b; p[2]=r;`. All 4 FB-write sites in helloworld.c (put_pixel_fb, voxel-panel border, point-cloud panel, voxel slice render) use this order. If the BD is ever rebuilt and HDMI wires fixed, revert to standard BGR.
