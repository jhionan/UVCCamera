#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <jpeglib.h>

// Convert YUYV (YUV 4:2:2) raw frame data to JPEG in memory.
// Returns malloc'd JPEG buffer and sets *out_size. Caller must free().
unsigned char *yuyv_to_jpeg(const unsigned char *yuyv, int width, int height,
                            int quality, unsigned long *out_size) {
    // Allocate RGB buffer
    unsigned char *rgb = (unsigned char *)malloc(width * height * 3);
    if (!rgb) return NULL;

    // YUYV to RGB conversion
    int rgb_idx = 0;
    for (int i = 0; i < width * height * 2; i += 4) {
        int y0 = yuyv[i];
        int u  = yuyv[i + 1] - 128;
        int v  = yuyv[i + 3] - 128;
        int y1 = yuyv[i + 2];

        // ITU-R BT.601 conversion
        #define CLAMP(x) ((x) < 0 ? 0 : ((x) > 255 ? 255 : (x)))
        rgb[rgb_idx++] = CLAMP(y0 + (1.402 * v));
        rgb[rgb_idx++] = CLAMP(y0 - (0.344136 * u) - (0.714136 * v));
        rgb[rgb_idx++] = CLAMP(y0 + (1.772 * u));

        rgb[rgb_idx++] = CLAMP(y1 + (1.402 * v));
        rgb[rgb_idx++] = CLAMP(y1 - (0.344136 * u) - (0.714136 * v));
        rgb[rgb_idx++] = CLAMP(y1 + (1.772 * u));
        #undef CLAMP
    }

    // Compress RGB to JPEG using libjpeg
    struct jpeg_compress_struct cinfo;
    struct jpeg_error_mgr jerr;

    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_compress(&cinfo);

    unsigned char *jpeg_buf = NULL;
    unsigned long jpeg_size = 0;
    jpeg_mem_dest(&cinfo, &jpeg_buf, &jpeg_size);

    cinfo.image_width = width;
    cinfo.image_height = height;
    cinfo.input_components = 3;
    cinfo.in_color_space = JCS_RGB;
    jpeg_set_defaults(&cinfo);
    jpeg_set_quality(&cinfo, quality, 1);
    jpeg_start_compress(&cinfo, 1);

    while (cinfo.next_scanline < cinfo.image_height) {
        unsigned char *row = rgb + cinfo.next_scanline * width * 3;
        jpeg_write_scanlines(&cinfo, &row, 1);
    }

    jpeg_finish_compress(&cinfo);
    jpeg_destroy_compress(&cinfo);
    free(rgb);

    *out_size = jpeg_size;
    return jpeg_buf;
}
