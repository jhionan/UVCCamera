package main

import "C"
import (
	"log"
	"unsafe"
)

//export goButtonCallback
func goButtonCallback(button C.int, state C.int, _ unsafe.Pointer) {
	event := ButtonEvent{
		Type:     "button",
		CameraID: 0,
		Button:   int(button),
		State:    int(state),
	}
	log.Printf("  Button event: button=%d state=%d", event.Button, event.State)
	if wsServer != nil {
		wsServer.Broadcast(event)
	}
}
