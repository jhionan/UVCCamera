#include <libuvc/libuvc.h>

extern void goButtonCallback(int button, int state, void *user_ptr);

static void cButtonCallback(int button, int state, void *user_ptr) {
    goButtonCallback(button, state, user_ptr);
}

void registerButtonCallback(uvc_device_handle_t *devh) {
    uvc_set_button_callback(devh, cButtonCallback, NULL);
}

// Wrapper to call uvc_get_stream_ctrl_format_size with an int format
// (avoids CGo enum type issues)
uvc_error_t negotiate_format(uvc_device_handle_t *devh, uvc_stream_ctrl_t *ctrl,
                              int format, int width, int height, int fps) {
    return uvc_get_stream_ctrl_format_size(devh, ctrl,
        (enum uvc_frame_format)format, width, height, fps);
}
