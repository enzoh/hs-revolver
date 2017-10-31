/**
 * File       : hs-revolver.c
 * Copyright  : Copyright (c) 2017 DFINITY Stiftung. All rights reserved.
 * License    : GPL-3
 * Maintainer : Enzo Haussecker <enzo@dfinity.org>
 * Stability  : Experimental
 */

#include <hs-revolver.h>
#include <stddef.h>
#include <stdlib.h>

struct P2P_Message * p2p_malloc_message(size_t size) {
  P2P_Message * message = malloc(sizeof(P2P_Message));
  message->data = malloc(size);
  message->data_size = size;
  return message;
}
