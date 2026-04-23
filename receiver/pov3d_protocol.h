/*
 * pov3d_protocol.h — wire format between the POV3D host server and the
 * Zynq-side receiver.  Mirrors host/protocol.py (protocol version 2).
 *
 * All fields are little-endian.  Zynq-7000 ARM Cortex-A9 is little-endian
 * by default, so these packed structs map directly to the wire bytes.
 *
 * Typical lifetime:
 *   Host  -> Zynq :  MODEL_DEF (once, ~150 KB for a skinned character)
 *   Host  -> Zynq :  FRAME     (60 Hz, ~1 KB with compact flags)
 *   Host  -> Zynq :  BYE       (on server shutdown)
 */

#ifndef POV3D_PROTOCOL_H
#define POV3D_PROTOCOL_H

#include <stdint.h>

#define POV3D_MAGIC     0x44335650u   /* 'P''V''3''D' little-endian */
#define POV3D_VERSION   2u

/* msg_type values */
#define POV3D_MSG_MODEL_DEF  0x0001u
#define POV3D_MSG_FRAME      0x0002u
#define POV3D_MSG_BYE        0x0003u

/* vertex_attrs bitfield */
#define POV3D_ATTR_POSITION  0x01u
#define POV3D_ATTR_COLOR     0x02u
#define POV3D_ATTR_NORMAL    0x04u
#define POV3D_ATTR_UV        0x08u
#define POV3D_ATTR_BONE      0x10u

/* MODEL_DEF flags bitfield */
#define POV3D_FLAG_POS_INT16   0x0001u  /* positions are 3 x uint16 */
#define POV3D_FLAG_SKIN_MAT34  0x0002u  /* skin matrices are 12 floats (rows 0..2) */


#if defined(__GNUC__) || defined(__clang__)
#  define POV3D_PACKED __attribute__((packed))
#else
#  pragma pack(push, 1)
#  define POV3D_PACKED
#endif


/* Outer packet header, 12 bytes, always present */
typedef struct POV3D_PACKED {
    uint32_t magic;         /* must equal POV3D_MAGIC */
    uint16_t msg_type;
    uint16_t version;       /* POV3D_VERSION */
    uint32_t payload_len;   /* bytes after this header */
} pov3d_header_t;

/* MODEL_DEF payload header, 44 bytes.
 * Followed by: vertex_count * vertex_stride bytes of vertex data,
 * then index_count * 4 bytes of uint32 indices.
 */
typedef struct POV3D_PACKED {
    uint16_t model_id;
    uint16_t flags;          /* POV3D_FLAG_* */
    uint32_t vertex_count;
    uint32_t index_count;
    uint16_t vertex_stride;  /* bytes per vertex (varies with flags) */
    uint16_t vertex_attrs;   /* POV3D_ATTR_* */
    uint16_t bone_count;
    uint16_t _pad;
    float    pos_scale[3];   /* only meaningful with FLAG_POS_INT16 */
    float    pos_offset[3];  /* decoded_pos = raw * pos_scale + pos_offset */
} pov3d_model_def_t;

/* FRAME payload header, 12 bytes. */
typedef struct POV3D_PACKED {
    uint32_t frame_id;
    uint32_t timestamp_ms;
    uint16_t object_count;
    uint16_t _pad;
} pov3d_frame_hdr_t;

/* Per-object preamble inside a FRAME, 68 bytes (4 + 64). */
typedef struct POV3D_PACKED {
    uint16_t model_id;
    uint16_t bone_count;
    float    model_matrix[16];   /* row-major */
    /* Followed by bone_count * floats_per_bone * 4 bytes, where
     * floats_per_bone = (flags & FLAG_SKIN_MAT34) ? 12 : 16.  The
     * receiver must look up flags from the MODEL_DEF with matching
     * model_id to size this correctly. */
} pov3d_frame_object_t;


#if !defined(__GNUC__) && !defined(__clang__)
#  pragma pack(pop)
#endif


/* Helpers - inline so they have no link-time cost. */

static inline uint32_t pov3d_floats_per_bone(uint16_t flags) {
    return (flags & POV3D_FLAG_SKIN_MAT34) ? 12u : 16u;
}

static inline uint32_t pov3d_vertex_stride_expected(uint16_t attrs, uint16_t flags) {
    uint32_t s = 0;
    if (attrs & POV3D_ATTR_POSITION)
        s += (flags & POV3D_FLAG_POS_INT16) ? 6u : 12u;
    if (attrs & POV3D_ATTR_COLOR)    s += 4u;
    if (attrs & POV3D_ATTR_NORMAL)   s += 12u;
    if (attrs & POV3D_ATTR_UV)       s += 8u;
    if (attrs & POV3D_ATTR_BONE)     s += 4u + 16u;
    return s;
}

/* Decode a quantized vertex position back to float.
 * raw is the 3 uint16 values read from the vertex stream. */
static inline void pov3d_decode_position_i16(
    const uint16_t raw[3], const float scale[3], const float offset[3],
    float out[3])
{
    out[0] = (float)raw[0] * scale[0] + offset[0];
    out[1] = (float)raw[1] * scale[1] + offset[1];
    out[2] = (float)raw[2] * scale[2] + offset[2];
}


#endif /* POV3D_PROTOCOL_H */
