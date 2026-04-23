/*
 * test_decoder.c — host-side smoke test for the POV3D C decoder.
 *
 * Connects to the Python host server at 127.0.0.1:9000, pumps received
 * bytes through the decoder, and prints a summary of each packet.
 * Output is formatted so it can be diffed against receiver.py output.
 *
 * Build (WSL / Linux / MSYS2):
 *     gcc -Wall -O2 -std=c99 test_decoder.c pov3d_decoder.c -o test_decoder
 * Run:
 *     ./test_decoder [--host 127.0.0.1] [--port 9000] [--max-frames 120]
 */

#include "pov3d_decoder.h"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>


typedef struct {
    int max_frames;
    int frames_seen;
    int should_stop;
} app_state_t;


static void on_model_def(void *user, const pov3d_model_def_view_t *m) {
    (void)user;
    printf("[c] MODEL_DEF id=%u flags=0x%04x verts=%u tris=%u "
           "stride=%u attrs=0x%02x bones=%u floats/bone=%u\n",
           m->model_id, m->flags, m->vertex_count, m->index_count / 3u,
           m->vertex_stride, m->vertex_attrs, m->bone_count,
           pov3d_floats_per_bone(m->flags));

    /* decode first vertex to verify byte layout is understood */
    if (m->vertex_count > 0 && (m->vertex_attrs & POV3D_ATTR_POSITION)) {
        const uint8_t *v0 = m->vertex_bytes;
        float px, py, pz;
        if (m->flags & POV3D_FLAG_POS_INT16) {
            uint16_t raw[3];
            memcpy(raw, v0, 6);
            pov3d_decode_position_i16(raw, m->pos_scale, m->pos_offset,
                                      (float[3]){0});
            px = (float)raw[0] * m->pos_scale[0] + m->pos_offset[0];
            py = (float)raw[1] * m->pos_scale[1] + m->pos_offset[1];
            pz = (float)raw[2] * m->pos_scale[2] + m->pos_offset[2];
            printf("    v0: pos_q=(%u,%u,%u) -> (%+.2f,%+.2f,%+.2f)\n",
                   raw[0], raw[1], raw[2], px, py, pz);
        } else {
            memcpy(&px, v0 + 0, 4);
            memcpy(&py, v0 + 4, 4);
            memcpy(&pz, v0 + 8, 4);
            printf("    v0: pos=(%+.2f,%+.2f,%+.2f)\n", px, py, pz);
        }
    }
}


static void on_frame(void *user, pov3d_frame_view_t *f) {
    app_state_t *s = (app_state_t *)user;
    s->frames_seen++;

    int verbose = (s->frames_seen <= 3 || s->frames_seen % 60 == 0);

    pov3d_frame_object_view_t obj;
    int got = pov3d_frame_next_object(f, &obj);

    if (verbose && got) {
        /* bone0 translation = last column of first bone matrix */
        float tx = 0, ty = 0, tz = 0;
        if (obj.bone_count > 0 && obj.bone_matrices) {
            tx = obj.bone_matrices[3];
            ty = obj.bone_matrices[7];
            tz = obj.bone_matrices[11];
        }
        printf("[c] FRAME #%u t=%ums objs=%u bones=%u fpb=%u "
               "bone0_t=(%+.3f,%+.3f,%+.3f)\n",
               f->frame_id, f->timestamp_ms, f->object_count,
               obj.bone_count, obj.floats_per_bone, tx, ty, tz);
    }

    /* drain remaining objects */
    while (pov3d_frame_next_object(f, &obj)) { /* nothing */ }

    if (s->max_frames && s->frames_seen >= s->max_frames) s->should_stop = 1;
}


static void on_bye(void *user) {
    (void)user;
    printf("[c] BYE\n");
}


static void on_error(void *user, const char *msg) {
    (void)user;
    fprintf(stderr, "[c] decoder error: %s\n", msg);
}


int main(int argc, char **argv) {
    const char *host = "127.0.0.1";
    int port = 9000;
    int max_frames = 120;

    for (int i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--host") && i + 1 < argc)        host = argv[++i];
        else if (!strcmp(argv[i], "--port") && i + 1 < argc)   port = atoi(argv[++i]);
        else if (!strcmp(argv[i], "--max-frames") && i + 1 < argc)
            max_frames = atoi(argv[++i]);
    }

    int s = socket(AF_INET, SOCK_STREAM, 0);
    if (s < 0) { perror("socket"); return 1; }
    struct sockaddr_in sa = {0};
    sa.sin_family = AF_INET;
    sa.sin_port = htons(port);
    inet_pton(AF_INET, host, &sa.sin_addr);
    if (connect(s, (struct sockaddr *)&sa, sizeof(sa)) < 0) {
        perror("connect"); close(s); return 1;
    }
    printf("[c] connected to %s:%d\n", host, port);

    /* pov3d_decoder_t has a 512KB buffer inside - too big for a normal
     * stack frame.  Heap-allocate for the test; on Zynq put it in BSS
     * or an explicit DDR section. */
    pov3d_decoder_t *dec = calloc(1, sizeof(*dec));
    if (!dec) { perror("calloc"); close(s); return 1; }

    app_state_t app = {.max_frames = max_frames};
    pov3d_callbacks_t cb = {
        .on_model_def = on_model_def,
        .on_frame     = on_frame,
        .on_bye       = on_bye,
        .on_error     = on_error,
        .user         = &app,
    };
    pov3d_decoder_init(dec, &cb);

    uint8_t buf[4096];
    while (!app.should_stop) {
        ssize_t got = recv(s, buf, sizeof(buf), 0);
        if (got <= 0) { printf("[c] socket closed\n"); break; }
        if (pov3d_decoder_feed(dec, buf, (size_t)got) < 0) {
            fprintf(stderr, "[c] decoder failed, aborting\n");
            break;
        }
    }

    printf("[c] max-frames reached or peer closed, exiting\n");
    free(dec);
    close(s);
    return 0;
}
