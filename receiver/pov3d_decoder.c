/*
 * pov3d_decoder.c — byte-stream state machine.
 *
 * No heap, no blocking, no threading assumptions.  Can be unit-tested on
 * the host by compiling with any C99 compiler.
 */

#include "pov3d_decoder.h"
#include <string.h>


static void _error(pov3d_decoder_t *d, const char *msg) {
    d->state = POV3D_STATE_ERROR;
    if (d->cb.on_error) d->cb.on_error(d->cb.user, msg);
}

/* Remember the flags for a given model_id so later FRAMEs can size
 * bone data correctly.  Overwrites if slot exists, else adds new. */
static void _remember_model(pov3d_decoder_t *d, uint16_t id, uint16_t flags) {
    for (uint32_t i = 0; i < POV3D_MAX_MODELS; i++) {
        if (d->models[i].model_id == id || d->models[i].model_id == 0) {
            d->models[i].model_id = id;
            d->models[i].flags = flags;
            return;
        }
    }
    /* table full - we silently keep using prior flags (or default). */
}

static uint16_t _lookup_flags(const pov3d_decoder_t *d, uint16_t id) {
    for (uint32_t i = 0; i < POV3D_MAX_MODELS; i++) {
        if (d->models[i].model_id == id) return d->models[i].flags;
    }
    return 0;  /* assume full float32, full 4x4 */
}


void pov3d_decoder_init(pov3d_decoder_t *d, const pov3d_callbacks_t *cb) {
    memset(d, 0, sizeof(*d));
    d->cb = *cb;
    d->state = POV3D_STATE_HEADER;
    d->need = sizeof(pov3d_header_t);
    d->fill = 0;
}

void pov3d_decoder_reset(pov3d_decoder_t *d) {
    d->state = POV3D_STATE_HEADER;
    d->need  = sizeof(pov3d_header_t);
    d->fill  = 0;
    /* model flag table is preserved across reset intentionally.  If the
     * application wants a hard reset, it can memset the struct. */
}


static void _dispatch_packet(pov3d_decoder_t *d) {
    const pov3d_header_t *h = &d->hdr;
    const uint8_t *payload = d->buf;   /* header is NOT in buf, only payload */

    if (h->msg_type == POV3D_MSG_MODEL_DEF) {
        if (h->payload_len < sizeof(pov3d_model_def_t)) {
            _error(d, "model_def: payload too small");
            return;
        }
        const pov3d_model_def_t *m = (const pov3d_model_def_t *)payload;
        uint32_t vb_size = m->vertex_count * m->vertex_stride;
        uint32_t ib_size = m->index_count * 4u;
        if ((uint64_t)sizeof(*m) + vb_size + ib_size != h->payload_len) {
            _error(d, "model_def: inconsistent sizes");
            return;
        }
        _remember_model(d, m->model_id, m->flags);
        if (d->cb.on_model_def) {
            pov3d_model_def_view_t view = {
                .model_id      = m->model_id,
                .flags         = m->flags,
                .vertex_count  = m->vertex_count,
                .index_count   = m->index_count,
                .vertex_stride = m->vertex_stride,
                .vertex_attrs  = m->vertex_attrs,
                .bone_count    = m->bone_count,
                .vertex_bytes  = payload + sizeof(*m),
                .index_bytes   = payload + sizeof(*m) + vb_size,
            };
            memcpy(view.pos_scale,  m->pos_scale,  sizeof(view.pos_scale));
            memcpy(view.pos_offset, m->pos_offset, sizeof(view.pos_offset));
            d->cb.on_model_def(d->cb.user, &view);
        }
    }
    else if (h->msg_type == POV3D_MSG_FRAME) {
        if (h->payload_len < sizeof(pov3d_frame_hdr_t)) {
            _error(d, "frame: payload too small");
            return;
        }
        const pov3d_frame_hdr_t *fh = (const pov3d_frame_hdr_t *)payload;
        if (d->cb.on_frame) {
            pov3d_frame_view_t view = {
                .frame_id     = fh->frame_id,
                .timestamp_ms = fh->timestamp_ms,
                .object_count = fh->object_count,
                .cursor       = payload + sizeof(*fh),
                .end          = payload + h->payload_len,
                ._remaining   = fh->object_count,
                ._owner       = d,
            };
            d->cb.on_frame(d->cb.user, &view);
        }
    }
    else if (h->msg_type == POV3D_MSG_BYE) {
        if (d->cb.on_bye) d->cb.on_bye(d->cb.user);
    }
    /* unknown msg types are silently dropped */
}


int pov3d_decoder_feed(pov3d_decoder_t *d, const uint8_t *data, size_t n) {
    if (d->state == POV3D_STATE_ERROR) return -1;

    while (n > 0) {
        if (d->state == POV3D_STATE_HEADER) {
            /* header is copied into &d->hdr directly */
            uint8_t *hdr_bytes = (uint8_t *)&d->hdr;
            uint32_t take = d->need;
            if ((size_t)take > n) take = (uint32_t)n;
            memcpy(hdr_bytes + (sizeof(pov3d_header_t) - d->need),
                   data, take);
            data += take;
            n    -= take;
            d->need -= take;
            if (d->need == 0) {
                if (d->hdr.magic != POV3D_MAGIC) {
                    _error(d, "bad magic"); return -1;
                }
                if (d->hdr.payload_len > POV3D_MAX_PACKET) {
                    _error(d, "payload too large for buffer"); return -1;
                }
                if (d->hdr.payload_len == 0) {
                    _dispatch_packet(d);
                    d->state = POV3D_STATE_HEADER;
                    d->need  = sizeof(pov3d_header_t);
                } else {
                    d->state = POV3D_STATE_PAYLOAD;
                    d->need  = d->hdr.payload_len;
                    d->fill  = 0;
                }
            }
        }
        else if (d->state == POV3D_STATE_PAYLOAD) {
            uint32_t take = d->need;
            if ((size_t)take > n) take = (uint32_t)n;
            memcpy(d->buf + d->fill, data, take);
            data += take;
            n    -= take;
            d->fill += take;
            d->need -= take;
            if (d->need == 0) {
                _dispatch_packet(d);
                if (d->state == POV3D_STATE_ERROR) return -1;
                d->state = POV3D_STATE_HEADER;
                d->need  = sizeof(pov3d_header_t);
            }
        }
    }
    return 0;
}


int pov3d_frame_next_object(pov3d_frame_view_t *f,
                            pov3d_frame_object_view_t *out)
{
    if (f->_remaining == 0) return 0;

    /* minimum per-object size = header(4) + model_matrix(64) = 68 */
    if ((size_t)(f->end - f->cursor) < 4 + 64) return 0;

    uint16_t model_id, bone_count;
    memcpy(&model_id,   f->cursor + 0, 2);
    memcpy(&bone_count, f->cursor + 2, 2);
    const float *mm = (const float *)(f->cursor + 4);

    uint16_t flags = _lookup_flags(f->_owner, model_id);
    uint32_t fpb = pov3d_floats_per_bone(flags);
    uint32_t bones_bytes = (uint32_t)bone_count * fpb * 4u;

    if ((size_t)(f->end - f->cursor) < 4 + 64 + bones_bytes) return 0;

    out->model_id        = model_id;
    out->bone_count      = bone_count;
    out->model_matrix    = mm;
    out->bone_matrices   = bone_count ? (const float *)(f->cursor + 4 + 64) : 0;
    out->floats_per_bone = fpb;

    f->cursor += 4 + 64 + bones_bytes;
    f->_remaining--;
    return 1;
}
