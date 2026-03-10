// UVC Camera Button Helper — bridges USB camera video + button events to the browser.
//
// Uses libuvc to capture MJPEG video and button events from UVC cameras,
// then serves them over HTTP (MJPEG stream) and WebSocket (button events).
// The browser does NOT use getUserMedia — it gets everything from this helper,
// avoiding USB driver conflicts.
//
// Endpoints:
//
//	GET  /video     — MJPEG video stream
//	GET  /snapshot  — Single JPEG frame (latest)
//	GET  /devices   — JSON device list
//	GET  /ws        — WebSocket (button events + hello message)
//	POST /start     — Start camera streaming (turns LED on)
//	POST /stop      — Stop camera streaming (turns LED off)
//	GET  /status    — JSON streaming status
//
// Usage:
//
//	./uvc-button-helper [--vid 0x0C45] [--pid 0x64AB] [--port 8765]
//
// Prerequisites:
//
//	macOS:   brew install libuvc
//	Windows: libuvc.dll + libusb-1.0.dll in same directory
//	Linux:   apt install libuvc-dev
package main

/*
#cgo pkg-config: libusb-1.0
#cgo LDFLAGS: -luvc -ljpeg
#cgo CFLAGS: -I/opt/homebrew/include
#cgo LDFLAGS: -L/opt/homebrew/lib
#include <libuvc/libuvc.h>
#include <stdlib.h>

// Defined in callbacks.c
extern void registerButtonCallback(uvc_device_handle_t *devh);
extern uvc_error_t negotiate_format(uvc_device_handle_t *devh, uvc_stream_ctrl_t *ctrl,
                                     int format, int width, int height, int fps);

// Defined in convert.c
extern unsigned char *yuyv_to_jpeg(const unsigned char *yuyv, int width, int height,
                                    int quality, unsigned long *out_size);
*/
import "C"

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
	"unsafe"

	"github.com/gorilla/websocket"
)

// ---------- Data types ----------

type ButtonEvent struct {
	Type     string `json:"type"`
	CameraID int    `json:"cameraId"`
	Button   int    `json:"button"`
	State    int    `json:"state"`
}

type DeviceInfo struct {
	CameraID  int    `json:"cameraId"`
	VendorID  int    `json:"vendorId"`
	ProductID int    `json:"productId"`
	Name      string `json:"name"`
	Width     int    `json:"width"`
	Height    int    `json:"height"`
	Fps       int    `json:"fps"`
}

type HelloMessage struct {
	Type    string       `json:"type"`
	Version int          `json:"version"`
	Devices []DeviceInfo `json:"devices"`
}

// ---------- Frame buffer (thread-safe) ----------

type FrameBuffer struct {
	data []byte
	seq  uint64
	mu   sync.RWMutex
	cond *sync.Cond
}

func NewFrameBuffer() *FrameBuffer {
	fb := &FrameBuffer{}
	fb.cond = sync.NewCond(&fb.mu)
	return fb
}

func (fb *FrameBuffer) Put(data []byte) {
	fb.mu.Lock()
	fb.data = make([]byte, len(data))
	copy(fb.data, data)
	fb.seq++
	fb.mu.Unlock()
	fb.cond.Broadcast()
}

func (fb *FrameBuffer) WaitNext(prevSeq uint64) ([]byte, uint64) {
	fb.mu.Lock()
	for fb.seq == prevSeq {
		fb.cond.Wait()
	}
	data := fb.data
	seq := fb.seq
	fb.mu.Unlock()
	return data, seq
}

func (fb *FrameBuffer) Latest() []byte {
	fb.mu.RLock()
	defer fb.mu.RUnlock()
	return fb.data
}

// ---------- Camera manager (handles start/stop streaming) ----------

type CameraManager struct {
	mu        sync.Mutex
	uvcCtx    *C.uvc_context_t
	dev       *C.uvc_device_t
	devh      *C.uvc_device_handle_t
	strmh     *C.uvc_stream_handle_t
	ctrl      C.uvc_stream_ctrl_t
	info      DeviceInfo
	isMJPEG   bool // true=MJPEG, false=YUYV
	streaming bool
	frameDone chan struct{}   // signals frame reader goroutine to stop
	frameExit chan struct{}   // frame reader signals it has exited
}

func (cm *CameraManager) IsStreaming() bool {
	cm.mu.Lock()
	defer cm.mu.Unlock()
	return cm.streaming
}

func (cm *CameraManager) Start() error {
	cm.mu.Lock()
	defer cm.mu.Unlock()

	if cm.streaming {
		return nil // already streaming
	}

	// Open device if not already open (first start keeps the probe handle)
	if cm.devh == nil {
		rc := C.uvc_open(cm.dev, &cm.devh)
		if rc < 0 {
			return fmt.Errorf("uvc_open: %s", C.GoString(C.uvc_strerror(rc)))
		}
		log.Printf("  Device re-opened")
	}

	// Register button callback
	C.registerButtonCallback(cm.devh)

	// Negotiate format using the actual format type
	formatInt := C.int(C.UVC_FRAME_FORMAT_YUYV)
	if cm.isMJPEG {
		formatInt = C.int(C.UVC_FRAME_FORMAT_MJPEG)
	}
	rc := C.negotiate_format(
		cm.devh, &cm.ctrl,
		formatInt,
		C.int(cm.info.Width), C.int(cm.info.Height), C.int(cm.info.Fps),
	)
	if rc < 0 {
		C.uvc_close(cm.devh)
		cm.devh = nil
		return fmt.Errorf("format negotiation: %s", C.GoString(C.uvc_strerror(rc)))
	}

	// Start streaming
	rc = C.uvc_stream_open_ctrl(cm.devh, &cm.strmh, &cm.ctrl)
	if rc < 0 {
		C.uvc_close(cm.devh)
		cm.devh = nil
		return fmt.Errorf("stream_open: %s", C.GoString(C.uvc_strerror(rc)))
	}

	rc = C.uvc_stream_start(cm.strmh, nil, nil, 0)
	if rc < 0 {
		C.uvc_stream_close(cm.strmh)
		cm.strmh = nil
		C.uvc_close(cm.devh)
		cm.devh = nil
		return fmt.Errorf("stream_start: %s", C.GoString(C.uvc_strerror(rc)))
	}

	// Start frame reader
	cm.frameDone = make(chan struct{})
	cm.frameExit = make(chan struct{})
	go cm.readFrames()

	cm.streaming = true
	fmtName := "YUYV"
	if cm.isMJPEG {
		fmtName = "MJPEG"
	}
	log.Printf("  Camera started (%s %dx%d)", fmtName, cm.info.Width, cm.info.Height)
	return nil
}

func (cm *CameraManager) Stop() {
	cm.mu.Lock()

	if !cm.streaming {
		cm.mu.Unlock()
		return
	}

	// Signal frame reader to stop
	frameDone := cm.frameDone
	frameExit := cm.frameExit
	cm.frameDone = nil

	if frameDone != nil {
		close(frameDone)
	}

	// Release lock so readFrames can finish its current iteration
	cm.mu.Unlock()

	// Wait for frame reader to exit with a timeout
	if frameExit != nil {
		select {
		case <-frameExit:
			// Frame reader exited cleanly
		case <-time.After(2 * time.Second):
			log.Printf("  Warning: frame reader did not exit within 2s, proceeding with stop")
		}
	}

	cm.mu.Lock()
	defer cm.mu.Unlock()

	// Stop streaming — this turns the LED off
	if cm.strmh != nil {
		C.uvc_stream_stop(cm.strmh)
		C.uvc_stream_close(cm.strmh)
		cm.strmh = nil
	}

	// Close device handle
	if cm.devh != nil {
		C.uvc_close(cm.devh)
		cm.devh = nil
	}

	cm.streaming = false
	log.Printf("  Camera stopped")
}

func (cm *CameraManager) Close() {
	cm.Stop()
	// dev and uvcCtx are cleaned up by caller
}

func (cm *CameraManager) readFrames() {
	defer close(cm.frameExit)

	frameCount := 0
	for {
		select {
		case <-cm.frameDone:
			return
		default:
		}

		cm.mu.Lock()
		strmh := cm.strmh
		isMJPEG := cm.isMJPEG
		cm.mu.Unlock()

		if strmh == nil {
			return
		}

		var frame *C.uvc_frame_t
		// Short timeout (200ms) so we can check frameDone frequently
		rc := C.uvc_stream_get_frame(strmh, &frame, C.int32_t(200000))
		if rc < 0 || frame == nil || frame.data == nil || frame.data_bytes == 0 {
			continue
		}

		frameCount++
		if frameCount == 1 {
			log.Printf("  First frame received: %d bytes (MJPEG=%v)", int(frame.data_bytes), isMJPEG)
		} else if frameCount%300 == 0 {
			log.Printf("  Frame #%d: %d bytes", frameCount, int(frame.data_bytes))
		}

		if isMJPEG {
			// MJPEG frames are already JPEG — use directly
			data := C.GoBytes(frame.data, C.int(frame.data_bytes))
			frameBuffer.Put(data)
		} else {
			// YUYV frames need conversion to JPEG
			var jpegSize C.ulong
			jpegData := C.yuyv_to_jpeg(
				(*C.uchar)(frame.data),
				C.int(cm.info.Width), C.int(cm.info.Height),
				C.int(85), &jpegSize,
			)
			if jpegData != nil {
				data := C.GoBytes(unsafe.Pointer(jpegData), C.int(jpegSize))
				C.free(unsafe.Pointer(jpegData))
				frameBuffer.Put(data)
			}
		}
	}
}

// ---------- Global state ----------

var (
	frameBuffer = NewFrameBuffer()
	wsServer    *Server
	camera      *CameraManager
)

// ---------- WebSocket server ----------

type Server struct {
	clients      map[*websocket.Conn]struct{}
	mu           sync.Mutex
	upgrader     websocket.Upgrader
	helloJSON    []byte
	stopTimer    *time.Timer // auto-stop camera when no clients remain
}

func NewServer(devices []DeviceInfo) *Server {
	hello := HelloMessage{
		Type:    "hello",
		Version: 2,
		Devices: devices,
	}
	helloJSON, _ := json.Marshal(hello)

	return &Server{
		clients:   make(map[*websocket.Conn]struct{}),
		helloJSON: helloJSON,
		upgrader: websocket.Upgrader{
			CheckOrigin: func(r *http.Request) bool { return true },
		},
	}
}

func (s *Server) HandleWS(w http.ResponseWriter, r *http.Request) {
	conn, err := s.upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}

	s.mu.Lock()
	s.clients[conn] = struct{}{}
	count := len(s.clients)
	// Cancel pending auto-stop — a client is here
	if s.stopTimer != nil {
		s.stopTimer.Stop()
		s.stopTimer = nil
	}
	// Auto-start camera when first client connects
	if count == 1 && !camera.IsStreaming() {
		go func() {
			if err := camera.Start(); err != nil {
				log.Printf("Auto-start failed: %v", err)
			}
		}()
	}
	s.mu.Unlock()

	log.Printf("WS client connected (%d total)", count)
	_ = conn.WriteMessage(websocket.TextMessage, s.helloJSON)

	for {
		if _, _, err := conn.ReadMessage(); err != nil {
			break
		}
	}

	s.mu.Lock()
	delete(s.clients, conn)
	count = len(s.clients)
	// Schedule auto-stop when no clients remain (grace period for reconnects)
	if count == 0 && camera.IsStreaming() {
		if s.stopTimer != nil {
			s.stopTimer.Stop()
		}
		s.stopTimer = time.AfterFunc(5*time.Second, func() {
			s.mu.Lock()
			stillEmpty := len(s.clients) == 0
			s.stopTimer = nil
			s.mu.Unlock()
			if stillEmpty {
				log.Printf("No clients for 5s — auto-stopping camera")
				camera.Stop()
			}
		})
	}
	s.mu.Unlock()
	conn.Close()
	log.Printf("WS client disconnected (%d total)", count)
}

func (s *Server) Broadcast(event ButtonEvent) {
	data, err := json.Marshal(event)
	if err != nil {
		return
	}

	s.mu.Lock()
	defer s.mu.Unlock()

	for conn := range s.clients {
		if err := conn.WriteMessage(websocket.TextMessage, data); err != nil {
			conn.Close()
			delete(s.clients, conn)
		}
	}
}

// ---------- HTTP handlers ----------

func corsHeaders(w http.ResponseWriter) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
}

func handleVideo(w http.ResponseWriter, r *http.Request) {
	corsHeaders(w)
	w.Header().Set("Content-Type", "multipart/x-mixed-replace; boundary=frame")
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
	w.Header().Set("Connection", "keep-alive")

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "Streaming not supported", http.StatusInternalServerError)
		return
	}

	log.Printf("MJPEG client connected")
	var seq uint64

	for {
		data, newSeq := frameBuffer.WaitNext(seq)
		seq = newSeq

		if data == nil {
			continue
		}

		_, err := fmt.Fprintf(w, "--frame\r\nContent-Type: image/jpeg\r\nContent-Length: %d\r\n\r\n", len(data))
		if err != nil {
			break
		}
		if _, err := w.Write(data); err != nil {
			break
		}
		if _, err := fmt.Fprint(w, "\r\n"); err != nil {
			break
		}
		flusher.Flush()
	}

	log.Printf("MJPEG client disconnected")
}

func handleSnapshot(w http.ResponseWriter, r *http.Request) {
	corsHeaders(w)
	data := frameBuffer.Latest()
	if data == nil {
		http.Error(w, "No frame available", http.StatusServiceUnavailable)
		return
	}
	w.Header().Set("Content-Type", "image/jpeg")
	w.Header().Set("Content-Length", fmt.Sprintf("%d", len(data)))
	w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
	w.Write(data)
}

func handleDebug(w http.ResponseWriter, r *http.Request) {
	corsHeaders(w)
	w.Header().Set("Content-Type", "application/json")
	data := frameBuffer.Latest()
	info := map[string]interface{}{
		"streaming":  camera.IsStreaming(),
		"isMJPEG":    camera.isMJPEG,
		"width":      camera.info.Width,
		"height":     camera.info.Height,
		"bufferSize": 0,
		"bufferSeq":  frameBuffer.seq,
		"isJPEG":     false,
	}
	if data != nil {
		info["bufferSize"] = len(data)
		if len(data) >= 2 {
			info["isJPEG"] = data[0] == 0xFF && data[1] == 0xD8
			info["firstBytes"] = fmt.Sprintf("%02X %02X %02X %02X", data[0], data[1], data[2], data[3])
		}
	}
	json.NewEncoder(w).Encode(info)
}

func handleDevices(w http.ResponseWriter, r *http.Request) {
	corsHeaders(w)
	w.Header().Set("Content-Type", "application/json")
	w.Write(wsServer.helloJSON)
}

func handleStart(w http.ResponseWriter, r *http.Request) {
	corsHeaders(w)
	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	if err := camera.Start(); err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"streaming"}`))
}

func handleStop(w http.ResponseWriter, r *http.Request) {
	corsHeaders(w)
	if r.Method == "OPTIONS" {
		w.WriteHeader(http.StatusOK)
		return
	}

	camera.Stop()
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte(`{"status":"stopped"}`))
}

func handleStatus(w http.ResponseWriter, r *http.Request) {
	corsHeaders(w)
	w.Header().Set("Content-Type", "application/json")
	status := "stopped"
	if camera.IsStreaming() {
		status = "streaming"
	}
	json.NewEncoder(w).Encode(map[string]string{"status": status})
}

// ---------- UVC camera ----------

func tryFormats(devh *C.uvc_device_handle_t, ctrl *C.uvc_stream_ctrl_t) (width, height, fps int, isMJPEG bool, err error) {
	formats := [][3]int{
		{1920, 1080, 30},
		{1280, 720, 30},
		{1024, 768, 30},
		{800, 600, 30},
		{640, 480, 30},
		{320, 240, 30},
	}

	for _, f := range formats {
		rc := C.negotiate_format(
			devh, ctrl,
			C.int(C.UVC_FRAME_FORMAT_MJPEG),
			C.int(f[0]), C.int(f[1]), C.int(f[2]),
		)
		if rc == 0 {
			return f[0], f[1], f[2], true, nil
		}
	}

	// Fallback: try YUYV at common resolutions
	for _, f := range formats {
		rc := C.negotiate_format(
			devh, ctrl,
			C.int(C.UVC_FRAME_FORMAT_YUYV),
			C.int(f[0]), C.int(f[1]), C.int(f[2]),
		)
		if rc == 0 {
			return f[0], f[1], f[2], false, nil
		}
	}

	return 0, 0, 0, false, fmt.Errorf("no supported format found")
}

func parseHexID(s string) int {
	s = strings.TrimPrefix(s, "0x")
	s = strings.TrimPrefix(s, "0X")
	val, err := strconv.ParseUint(s, 16, 16)
	if err != nil {
		log.Fatalf("Invalid hex ID %q: %v", s, err)
	}
	return int(val)
}

func main() {
	vidStr := flag.String("vid", "0x0C45", "USB Vendor ID")
	pidStr := flag.String("pid", "0x64AB", "USB Product ID (0 = any)")
	port := flag.Int("port", 8765, "WebSocket server port")
	flag.Parse()

	vid := parseHexID(*vidStr)
	pid := parseHexID(*pidStr)

	log.Printf("UVC Button Helper v2.0 — VID=0x%04X PID=0x%04X", vid, pid)

	// Initialize libuvc
	var uvcCtx *C.uvc_context_t
	rc := C.uvc_init(&uvcCtx, nil)
	if rc < 0 {
		log.Fatalf("uvc_init: %s", C.GoString(C.uvc_strerror(rc)))
	}
	defer C.uvc_exit(uvcCtx)

	// Find device
	var dev *C.uvc_device_t
	rc = C.uvc_find_device(uvcCtx, &dev, C.int(vid), C.int(pid), nil)
	if rc < 0 {
		log.Fatalf("Camera not found (VID=0x%04X PID=0x%04X): %s", vid, pid, C.GoString(C.uvc_strerror(rc)))
	}

	// Open device to probe name and formats
	var devh *C.uvc_device_handle_t
	rc = C.uvc_open(dev, &devh)
	if rc < 0 {
		log.Fatalf("uvc_open: %s", C.GoString(C.uvc_strerror(rc)))
	}

	// Get device name
	var devDesc *C.uvc_device_descriptor_t
	name := fmt.Sprintf("%04x:%04x", vid, pid)
	if C.uvc_get_device_descriptor(dev, &devDesc) == 0 {
		if devDesc.product != nil {
			name = C.GoString(devDesc.product)
		}
		C.uvc_free_device_descriptor(devDesc)
	}

	// Negotiate stream format
	var ctrl C.uvc_stream_ctrl_t
	width, height, fps, isMJPEG, err := tryFormats(devh, &ctrl)
	if err != nil {
		log.Fatalf("Format negotiation failed: %v", err)
	}
	fmtStr := "YUYV"
	if isMJPEG {
		fmtStr = "MJPEG"
	}
	log.Printf("  Camera: %s — %dx%d @ %dfps %s", name, width, height, fps, fmtStr)

	// Don't close the probe handle — pass it directly to CameraManager
	// to avoid close-reopen issues

	info := DeviceInfo{
		CameraID:  0,
		VendorID:  vid,
		ProductID: pid,
		Name:      name,
		Width:     width,
		Height:    height,
		Fps:       fps,
	}

	// Create camera manager — pass the already-open device handle
	camera = &CameraManager{
		uvcCtx:  uvcCtx,
		dev:     dev,
		devh:    devh,
		info:    info,
		isMJPEG: isMJPEG,
	}
	defer camera.Close()

	// Start streaming immediately
	if err := camera.Start(); err != nil {
		log.Fatalf("Initial start failed: %v", err)
	}

	// Set up WebSocket + HTTP server
	wsServer = NewServer([]DeviceInfo{info})

	mux := http.NewServeMux()
	mux.HandleFunc("/ws", wsServer.HandleWS)
	mux.HandleFunc("/video", handleVideo)
	mux.HandleFunc("/snapshot", handleSnapshot)
	mux.HandleFunc("/devices", handleDevices)
	mux.HandleFunc("/start", handleStart)
	mux.HandleFunc("/stop", handleStop)
	mux.HandleFunc("/status", handleStatus)
	mux.HandleFunc("/debug", handleDebug)
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		corsHeaders(w)
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		handleDevices(w, r)
	})

	addr := fmt.Sprintf("localhost:%d", *port)
	httpServer := &http.Server{Addr: addr, Handler: mux}

	go func() {
		log.Printf("HTTP server on http://%s", addr)
		log.Printf("  Video:    http://%s/video", addr)
		log.Printf("  Snapshot: http://%s/snapshot", addr)
		log.Printf("  Start:    POST http://%s/start", addr)
		log.Printf("  Stop:     POST http://%s/stop", addr)
		log.Printf("  WS:       ws://%s/ws", addr)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("HTTP server: %v", err)
		}
	}()

	// Wait for signal
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	<-sigCh

	log.Println("Shutting down...")

	// Force exit on second signal (in case Stop() blocks on a C call)
	go func() {
		<-sigCh
		log.Println("Force exit")
		os.Exit(1)
	}()

	httpServer.Close()
}
