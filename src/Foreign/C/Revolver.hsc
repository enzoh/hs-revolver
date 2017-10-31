-- |
-- Module     : Foreign.C.Revolver
-- Copyright  : Copyright (c) 2017 DFINITY Stiftung. All rights reserved.
-- License    : GPL-3
-- Maintainer : Enzo Haussecker <enzo@dfinity.org>
-- Stability  : Experimental

{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE InterruptibleFFI           #-}
{-# LANGUAGE MagicHash                  #-}
{-# LANGUAGE RecordWildCards            #-}
{-# LANGUAGE ViewPatterns               #-}

{-# OPTIONS -fno-warn-unused-top-binds #-}

module Foreign.C.Revolver
  ( Config(..)
  , RevolverId
  , addresses
  , identity
  , new
  , peers
  , receive
  , send
  , shutdown
  , streams
  ) where

import Control.Arrow          ((***))
import Control.Exception      (bracket)
import Data.ByteString.Char8  (ByteString, split, unpack)
import Data.ByteString.Unsafe (unsafePackAddressLen, unsafeUseAsCStringLen)
import Data.Default.Class     (Default(..))
import Data.Int               (Int64)
import Data.Word              (Word16, Word32, Word8)
import Foreign.C.String       (CString, CStringLen, newCString, peekCString, withCString)
import Foreign.C.Types        (CBool, CInt(..), CSize)
import Foreign.Marshal.Alloc  (free)
import Foreign.Marshal.Array  (withArray)
import Foreign.Marshal.Utils  (fromBool, with)
import Foreign.Storable       (Storable(..))
import GHC.Ptr                (FunPtr, Ptr(..), castPtr, plusPtr)

#include <bindings.dsl.h>
#include <hs-revolver.h>

#starttype struct P2P_Config
#field analytics_interval, Int64
#field analytics_url, CString
#field analytics_user_data, CString
#field artifact_cache_size, CSize
#field artifact_chunk_size, Word32
#field artifact_max_buffer_size, Word32
#field artifact_queue_size, CSize
#field cluster_id, CInt
#field disable_analytics, CBool
#field disable_broadcast, CBool
#field disable_nat_port_map, CBool
#field disable_peer_discovery, CBool
#field disable_stream_discovery, CBool
#field ip, CString
#field k_bucket_size, CSize
#field latency_tolerance, Int64
#field log_file, CString
#field log_level, CString
#field nat_monitor_interval, Int64
#field nat_monitor_timeout, Int64
#field network, CString
#field ping_buffer_size, Word32
#field port, Word16
#field process_id, CInt
#field random_seed, CString
#field sample_max_buffer_size, Word32
#field sample_size, CSize
#field seed_nodes, Ptr CString
#field seed_nodes_size, CSize
#field streamstore_capacity, CSize
#field streamstore_queue_size, CSize
#field timeout, Int64
#field version, CString
#field witness_cache_size, CSize
#stoptype

#starttype struct P2P_Message
#field data, Ptr Word8
#field data_size, CSize
#stoptype

#ccall p2p_addresses, CInt -> IO (Ptr <P2P_Message>)
#ccall p2p_id, CInt -> IO CString
#ccall p2p_new, Ptr <P2P_Config> -> IO CInt
#ccall p2p_peer_count, CInt -> IO CInt
#ccall p2p_send, CInt -> Ptr <P2P_Message> -> IO ()
#ccall p2p_shutdown, CInt -> IO ()
#ccall p2p_stream_count, CInt -> IO CInt

foreign import ccall interruptible "p2p_receive"
  c'p2p_receive :: CInt -> IO (Ptr C'P2P_Message)

data Config =
  Config
  { cfgAnalyticsInterval      :: Int64
  , cfgAnalyticsURL           :: String
  , cfgAnalyticsUserData      :: String
  , cfgArtifactCacheSize      :: Word
  , cfgArtifactChunkSize      :: Word32
  , cfgArtifactMaxBufferSize  :: Word32
  , cfgArtifactQueueSize      :: Word
  , cfgClusterID              :: Int
  , cfgDisableAnalytics       :: Bool
  , cfgDisableBroadcast       :: Bool
  , cfgDisableNATPortMap      :: Bool
  , cfgDisablePeerDiscovery   :: Bool
  , cfgDisableStreamDiscovery :: Bool
  , cfgIP                     :: String
  , cfgKBucketSize            :: Word
  , cfgLatencyTolerance       :: Int64
  , cfgLogFile                :: String
  , cfgLogLevel               :: String
  , cfgNATMonitorInterval     :: Int64
  , cfgNATMonitorTimeout      :: Int64
  , cfgNetwork                :: String
  , cfgPingBufferSize         :: Word32
  , cfgPort                   :: Word16
  , cfgProcessID              :: Int
  , cfgRandomSeed             :: String
  , cfgSampleMaxBufferSize    :: Word32
  , cfgSampleSize             :: Word
  , cfgSeedNodes              :: [String]
  , cfgStreamstoreCapacity    :: Word
  , cfgStreamstoreQueueSize   :: Word
  , cfgTimeout                :: Int64
  , cfgVersion                :: String
  , cfgWitnessCacheSize       :: Word
  }

instance Default Config where
  def =
    Config
    { cfgAnalyticsInterval      = 60
    , cfgAnalyticsURL           = ""
    , cfgAnalyticsUserData      = ""
    , cfgArtifactCacheSize      = 65536
    , cfgArtifactChunkSize      = 65536
    , cfgArtifactMaxBufferSize  = 16777216
    , cfgArtifactQueueSize      = 8192
    , cfgClusterID              = 0
    , cfgDisableAnalytics       = True
    , cfgDisableBroadcast       = False
    , cfgDisableNATPortMap      = False
    , cfgDisablePeerDiscovery   = False
    , cfgDisableStreamDiscovery = False
    , cfgIP                     = "0.0.0.0"
    , cfgKBucketSize            = 32
    , cfgLatencyTolerance       = 60
    , cfgLogFile                = ""
    , cfgLogLevel               = "INFO"
    , cfgNATMonitorInterval     = 5
    , cfgNATMonitorTimeout      = 60
    , cfgNetwork                = "revolver"
    , cfgPingBufferSize         = 32
    , cfgPort                   = 0
    , cfgProcessID              = 0
    , cfgRandomSeed             = "0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF"
    , cfgSampleMaxBufferSize    = 8192
    , cfgSampleSize             = 5
    , cfgSeedNodes              = []
    , cfgStreamstoreCapacity    = 8
    , cfgStreamstoreQueueSize   = 8192
    , cfgTimeout                = 10
    , cfgVersion                = "0.1.0"
    , cfgWitnessCacheSize       = 65536
    }

newtype RevolverId = RevolverId { ref :: CInt } deriving (Eq, Num, Ord)

instance Show RevolverId where
  show = show . ref

addresses :: RevolverId -> IO [String]
addresses RevolverId {..} =
  bracket (c'p2p_addresses ref) free $ \ msg -> do
    C'P2P_Message (Ptr addr##) (fromIntegral -> size) <- peek msg
    map unpack . split '\NUL' <$> unsafePackAddressLen size addr##

identity :: RevolverId -> IO String
identity RevolverId {..} =
  bracket (c'p2p_id ref) free peekCString

new :: Config -> IO RevolverId
new Config {..} =
  withCString cfgAnalyticsURL $ \ arg01 ->
    withCString cfgAnalyticsUserData $ \ arg02 ->
      withCString cfgIP $ \ arg13 ->
        withCString cfgLogFile $ \ arg16 ->
          withCString cfgLogLevel $ \ arg17 ->
            withCString cfgNetwork $ \ arg20 ->
              withCString cfgRandomSeed $ \ arg24 ->
                bracket (mapM newCString cfgSeedNodes) (mapM_ free) $ \ addrs ->
                  withArray addrs $ \ arg27 ->
                    withCString cfgVersion $ \ arg32 -> do
                      let cfg = C'P2P_Config arg00 arg01 arg02 arg03 arg04 arg05 arg06 arg07 arg08 arg09 arg10 arg11 arg12 arg13 arg14 arg15 arg16 arg17 arg18 arg19 arg20 arg21 arg22 arg23 arg24 arg25 arg26 arg27 arg28 arg29 arg30 arg31 arg32 arg33
                      RevolverId <$> with cfg c'p2p_new
  where
  arg00 = cfgAnalyticsInterval
  arg03 = fromIntegral cfgArtifactCacheSize
  arg04 = cfgArtifactChunkSize
  arg05 = cfgArtifactMaxBufferSize
  arg06 = fromIntegral cfgArtifactQueueSize
  arg07 = fromIntegral cfgClusterID
  arg08 = fromBool cfgDisableAnalytics
  arg09 = fromBool cfgDisableBroadcast
  arg10 = fromBool cfgDisableNATPortMap
  arg11 = fromBool cfgDisablePeerDiscovery
  arg12 = fromBool cfgDisableStreamDiscovery
  arg14 = fromIntegral cfgKBucketSize
  arg15 = cfgLatencyTolerance
  arg18 = cfgNATMonitorInterval
  arg19 = cfgNATMonitorTimeout
  arg21 = cfgPingBufferSize
  arg22 = cfgPort
  arg23 = fromIntegral cfgProcessID
  arg25 = cfgSampleMaxBufferSize
  arg26 = fromIntegral cfgSampleSize
  arg28 = fromIntegral $ length cfgSeedNodes
  arg29 = fromIntegral cfgStreamstoreCapacity
  arg30 = fromIntegral cfgStreamstoreQueueSize
  arg31 = cfgTimeout
  arg33 = fromIntegral cfgWitnessCacheSize

peers :: RevolverId -> IO Int
peers RevolverId {..} = fromIntegral <$> c'p2p_peer_count ref

receive :: RevolverId -> IO ByteString
receive RevolverId {..} =
  bracket (c'p2p_receive ref) free $ \ msg -> do
    C'P2P_Message (Ptr addr##) (fromIntegral -> size) <- peek msg
    unsafePackAddressLen size addr##

send :: RevolverId -> ByteString -> IO ()
send RevolverId {..} =
  flip unsafeUseAsCStringLen (flip with (c'p2p_send ref) . convert)

shutdown :: RevolverId -> IO ()
shutdown RevolverId {..} = c'p2p_shutdown ref

streams :: RevolverId -> IO Int
streams RevolverId {..} = fromIntegral <$> c'p2p_stream_count ref

convert :: CStringLen -> C'P2P_Message
convert = uncurry C'P2P_Message . (castPtr *** fromIntegral)
