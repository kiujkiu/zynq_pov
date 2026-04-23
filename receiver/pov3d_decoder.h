/*
 * pov3d_decoder.h — transport-agnostic packet decoder.
 *
 * Feed arbitrary-sized byte chunks in with pov3d_decoder_feed().  When a
 * full packet is assembled, the corresponding user callback fires.  The
 * decoder is purely reactive: it never allocates, never blocks, and does
 * not know about lwIP.  A separate lwIP glue file (pov3d_lwip.c) pumps
 * TCP receive callbacks into pov3d_decoder_feed().
 */

#ifndef POV3D_DECODER_H
#define POV3D_DECODER_H

#include <stddef.h>
#include <stdint.h>
#include "pov3d_protocol.h"

/* Size the scratch buffer here.  Must be >= worst-case packet size.
 * MODEL_DEF for CesiumMan is ~155 KB; a 512 KB buffer leaves plenty of
 * headroom for denser models.  Lives in BSS - allocate in DDR via linker
 * script if you want to keep OCM free. */
#ifndef POV3D_MAX_PACKET
#define POV3D_MAX_PACKET (512u * 1024u)
#endif

/* Max number of distinct models the decoder remembers (for per-model
 * flags lookup when parsing FRAME bone data). */
#ifndef POV3D_MAX_MODELS
#define POV3D_MAX_MODELS 8u
#endif


/* Parsed view of a MODEL_DEF.  Pointers alias into the decoder's scratch
 * buffer - stable only until the next packet is fed.  If the application
 * needs to keep the vertex/index data, it must copy it elsewhere. */
typedef struct {
    uint16_t        model_id;
    uint16_t        flags;
    uint32_t        vertex_count;
    uint32_t        index_count;
    uint16_t        vertex_stride;
    uint16_t        vertex_attrs;
    uint16_t        bone_count;
    float           pos_scale[3];
    float           pos_offset[3];
    const uint8_t  *vertex_bytes;   /* vertex_count * vertex_stride bytes */
    const uint8_t  *index_bytes;    /* index_count * 4 bytes (uint32) */
} pov3d_model_def_view_t;

/* Parsed view of one object inside a FRAME. */
typedef struct {
    uint16_t       model_id;
    uint16_t       bone_count;
    const float   *model_matrix;    /* 16 floats, row-major */
    const float   *bone_matrices;   /* bone_count * floats_per_bone floats */
    uint32_t       floats_per_bone; /* 12 or 16 */
} pov3d_frame_object_view_t;

typedef struct {
    uint32_t frame_id;
    uint32_t timestamp_ms;
    uint16_t object_count;
    /* iterate via pov3d_frame_object() */
    const uint8_t *cursor;          /* internal */
    const uint8_t *end;             /* internal */
    uint16_t       _remaining;      /* internal */
    /* decoder needs access to model-flag table during iteration */
    struct pov3d_decoder *_owner;
} pov3d_frame_view_t;


struct pov3d_decoder;   /* opaque */

typedef void (*pov3d_on_model_def_fn)(void *user,
                                      const pov3d_model_def_view_t *m);
typedef void (*pov3d_on_frame_fn)(void *user,
                                  pov3d_frame_view_t *f);
typedef void (*pov3d_on_bye_fn)(void *user);
typedef void (*pov3d_on_error_fn)(void *user, const char *msg);

typedef struct {
    pov3d_on_model_def_fn on_model_def;
    pov3d_on_frame_fn     on_frame;
    pov3d_on_bye_fn       on_bye;
    pov3d_on_error_fn     on_error;
    void                 *user;
} pov3d_callbacks_t;


/* Opaque state.  Allocate one in BSS or on the stack. */
typedef struct pov3d_decoder {
    pov3d_callbacks_t cb;

    /* stream state */
    enum {
        POV3D_STATE_HEADER,
        POV3D_STATE_PAYLOAD,
        POV3D_STATE_ERROR
    } state;
    uint32_t need;          /* bytes still needed to complete current phase */
    uint32_t fill;          /* bytes currently in buf */

    /* current packet being assembled */
    pov3d_header_t hdr;

    /* per-model flag table: maps model_id -> flags.  model_id 0 is
     * treated as "unused slot". */
    struct {
        uint16_t model_id;
        uint16_t flags;
    } models[POV3D_MAX_MODELS];

    /* scratch buffer holding header + payload of one packet in flight.
     * Declared last so users can override the sizing by providing their
     * own struct layout with a larger trailing buffer. */
    uint8_t buf[POV3D_MAX_PACKET];
} pov3d_decoder_t;


void pov3d_decoder_init(pov3d_decoder_t *d, const pov3d_callbacks_t *cb);

/* Feed up to n bytes from the TCP stream.  Returns 0 on success, -1 if
 * the stream has been put into an unrecoverable error state.  Call
 * pov3d_decoder_reset() to recover after a connection restart. */
int  pov3d_decoder_feed(pov3d_decoder_t *d, const uint8_t *data, size_t n);

void pov3d_decoder_reset(pov3d_decoder_t *d);

/* Iterate the objects inside a FRAME.  Returns 1 when 'out' is filled,
 * 0 when iteration is done.  The returned pointers alias into the
 * decoder's scratch buffer (stable for the duration of the callback). */
int  pov3d_frame_next_object(pov3d_frame_view_t *f,
                             pov3d_frame_object_view_t *out);


#endif /* POV3D_DECODER_H */
