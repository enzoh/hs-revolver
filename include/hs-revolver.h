/**
 * File       : hs-revolver.h
 * Copyright  : Copyright (c) 2017 DFINITY Stiftung. All rights reserved.
 * License    : GPL-3
 * Maintainer : Enzo Haussecker <enzo@dfinity.org>
 * Stability  : Experimental
 */

#ifndef HS_REVOLVER_H
#define HS_REVOLVER_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct P2P_Config {
  int64_t analytics_interval;
  char * analytics_url;
  char * analytics_user_data;
  size_t artifact_cache_size;
  uint32_t artifact_chunk_size;
  uint32_t artifact_max_buffer_size;
  size_t artifact_queue_size;
  int cluster_id;
  bool disable_analytics;
  bool disable_broadcast;
  bool disable_nat_port_map;
  bool disable_peer_discovery;
  bool disable_stream_discovery;
  char * ip;
  size_t k_bucket_size;
  int64_t latency_tolerance;
  char * log_file;
  char * log_level;
  int64_t nat_monitor_interval;
  int64_t nat_monitor_timeout;
  char * network;
  uint32_t ping_buffer_size;
  uint16_t port;
  int process_id;
  char * random_seed;
  uint32_t sample_max_buffer_size;
  size_t sample_size;
  char * * seed_nodes;
  size_t seed_nodes_size;
  size_t streamstore_capacity;
  size_t streamstore_queue_size;
  int64_t timeout;
  char * version;
  size_t witness_cache_size;
} P2P_Config;

typedef struct P2P_Message {
  uint8_t * data;
  size_t data_size;
} P2P_Message;

struct P2P_Message * p2p_addresses(int);

char * p2p_id(int);

struct P2P_Message * p2p_malloc_message(size_t);

int p2p_new(struct P2P_Config *);

int p2p_peer_count(int);

struct P2P_Message * p2p_receive(int);

void p2p_send(int, struct P2P_Message *);

void p2p_shutdown(int);

int p2p_stream_count(int);

#ifdef __cplusplus
}
#endif

#endif // HS_REVOLVER_H
