/**
 * File       : hs-revolver.go
 * Copyright  : Copyright (c) 2017 DFINITY Stiftung. All rights reserved.
 * License    : GPL-3
 * Maintainer : Enzo Haussecker <enzo@dfinity.org>
 * Stability  : Experimental
 */

package main

import (
	"os"
	"sync"
	"time"
	"unsafe"

	"github.com/enzoh/go-logging"

	"gx/ipfs/QmXY77cVe7rVRQXZZQRioukUM7aRW3BTcAgJe12MCtb3Ji/go-multiaddr"
	"gx/ipfs/QmXz8gebptKTDCWForTFiwWyzzTQ6GfH4EH39q7X9TiYao/go-revolver-p2p"
)

//#include <hs-revolver.h>
//#include <memory.h>
//#include <stdlib.h>
import "C"

var db []*struct {
	client  p2p.Client
	release func()
}

var lock *sync.Mutex = &sync.Mutex{}

//export p2p_addresses
func p2p_addresses(ref C.int) *C.struct_P2P_Message {

	addresses := db[int(ref)].client.Addresses()

	var data []byte
	for i := range addresses {
		data = append(data, []byte(addresses[i].String())...)
		data = append(data, 0x00)
	}
	size := C.size_t(len(data)) - 1

	// Copy the addresses to the C-heap.
	message := C.p2p_malloc_message(size)
	if size > 0 {
		C.memcpy(
			unsafe.Pointer(message.data),
			unsafe.Pointer(&data[0]),
			size,
		)
	}

	// Return a reference to the addresses.
	return message

}

//export p2p_id
func p2p_id(ref C.int) *C.char {
	return C.CString(db[int(ref)].client.ID())
}

//export p2p_new
func p2p_new(c_cfg *C.struct_P2P_Config) C.int {

	var (
		addrs   []multiaddr.Multiaddr
		err     error
		handle  *os.File
		level   logging.Level
		release func()
	)

	// Set the log file.
	file := C.GoString(c_cfg.log_file)
	if file != "" {
		handle, err = os.OpenFile(file, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
		if err != nil {
			panic(err)
		}
	} else {
		handle = os.Stdout
	}

	// Set the log level.
	switch C.GoString(c_cfg.log_level) {
	case "CRITICAL":
		level = logging.CRITICAL
	case "ERROR":
		level = logging.ERROR
	case "WARNING":
		level = logging.WARNING
	case "NOTICE":
		level = logging.NOTICE
	case "INFO":
		level = logging.INFO
	default:
		level = logging.DEBUG
	}

	// Set the seed nodes.
	n := int(c_cfg.seed_nodes_size)
	nodes := (*[1 << 30]*C.char)(unsafe.Pointer(c_cfg.seed_nodes))[:n:n]
	for i := range nodes {
		addr, err := multiaddr.NewMultiaddr(C.GoString(nodes[i]))
		if err != nil {
			panic(err)
		}
		addrs = append(addrs, addr)
	}

	// Create a configuration.
	cfg := &p2p.Config{
		AnalyticsInterval:      time.Second * time.Duration(int64(c_cfg.analytics_interval)),
		AnalyticsURL:           C.GoString(c_cfg.analytics_url),
		AnalyticsUserData:      C.GoString(c_cfg.analytics_user_data),
		ArtifactCacheSize:      int(c_cfg.artifact_cache_size),
		ArtifactChunkSize:      uint32(c_cfg.artifact_chunk_size),
		ArtifactMaxBufferSize:  uint32(c_cfg.artifact_max_buffer_size),
		ArtifactQueueSize:      int(c_cfg.artifact_queue_size),
		ClusterID:              int(c_cfg.cluster_id),
		DisableAnalytics:       bool(c_cfg.disable_analytics),
		DisableBroadcast:       bool(c_cfg.disable_broadcast),
		DisableNATPortMap:      bool(c_cfg.disable_nat_port_map),
		DisablePeerDiscovery:   bool(c_cfg.disable_peer_discovery),
		DisableStreamDiscovery: bool(c_cfg.disable_stream_discovery),
		IP:                     C.GoString(c_cfg.ip),
		KBucketSize:            int(c_cfg.k_bucket_size),
		LatencyTolerance:       time.Second * time.Duration(int64(c_cfg.latency_tolerance)),
		LogFile:                handle,
		LogLevel:               level,
		NATMonitorInterval:     time.Second * time.Duration(int64(c_cfg.nat_monitor_interval)),
		NATMonitorTimeout:      time.Second * time.Duration(int64(c_cfg.nat_monitor_timeout)),
		Network:                C.GoString(c_cfg.network),
		PingBufferSize:         uint32(c_cfg.ping_buffer_size),
		Port:                   uint16(c_cfg.port),
		ProcessID:              int(c_cfg.process_id),
		RandomSeed:             C.GoString(c_cfg.random_seed),
		SampleMaxBufferSize:    uint32(c_cfg.sample_max_buffer_size),
		SampleSize:             int(c_cfg.sample_size),
		SeedNodes:              addrs,
		StreamstoreCapacity:    int(c_cfg.streamstore_capacity),
		StreamstoreQueueSize:   int(c_cfg.streamstore_queue_size),
		Timeout:                time.Second * time.Duration(int64(c_cfg.timeout)),
		Version:                C.GoString(c_cfg.version),
		WitnessCacheSize:       int(c_cfg.witness_cache_size),
	}

	// Create a client.
	client, shutdown, err := cfg.New()
	if err != nil {
		panic(err)
	}

	// Prepare to release all resources associated with the client.
	if file != "" {
		release = func() {
			shutdown()
			handle.Close()
		}
	} else {
		release = shutdown
	}

	// Save the client and its release function.
	lock.Lock()
	ref := len(db)
	db = append(db, &struct {
		client  p2p.Client
		release func()
	}{client, release})
	lock.Unlock()

	// Return a reference to the client.
	return C.int(ref)

}

//export p2p_peer_count
func p2p_peer_count(ref C.int) C.int {
	return C.int(db[int(ref)].client.PeerCount())
}

//export p2p_receive
func p2p_receive(ref C.int) *C.struct_P2P_Message {

	data := <-db[int(ref)].client.Receive()
	size := C.size_t(len(data))

	// Copy the message to the C-heap.
	message := C.p2p_malloc_message(size)
	if size > 0 {
		C.memcpy(
			unsafe.Pointer(message.data),
			unsafe.Pointer(&data[0]),
			size,
		)
	}

	// Return a reference to the message.
	return message

}

//export p2p_send
func p2p_send(ref C.int, msg *C.struct_P2P_Message) {
	db[int(ref)].client.Send() <- C.GoBytes(unsafe.Pointer(msg.data), C.int(msg.data_size))
}

//export p2p_shutdown
func p2p_shutdown(ref C.int) {
	db[int(ref)].release()
}

//export p2p_stream_count
func p2p_stream_count(ref C.int) C.int {
	return C.int(db[int(ref)].client.StreamCount())
}

func main() {}
