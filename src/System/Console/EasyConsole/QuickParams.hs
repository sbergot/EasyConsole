{- |
Module      :  $Header$
Copyright   :  (c) Simon Bergot
License     :  BSD3

Maintainer  :  simon.bergot@gmail.com
Stability   :  unstable
Portability :  portable

Collection of functions which are basically shortcuts
of "System.Console.EasyConsole.Params" versions.
-}

module System.Console.EasyConsole.QuickParams (
  -- * Parameters without args
    boolFlag
  -- * Parameters with one arg
  -- ** Flags
  , reqFlag
  , optFlag
  -- ** Positional
  , reqPos
  , optPos 
  -- * Parameters with multiple args
  -- ** Flags
  , reqFlagArgs
  , optFlagArgs
  -- ** Positionnal
  , posArgs
  ) where

import System.Console.EasyConsole.BaseType
import System.Console.EasyConsole.Params
import Text.Read (readMaybe)
import Data.Either (partitionEithers)

readArg
  :: Read a
  => Key
  -> Arg
  -> ParseResult a
readArg key arg = case readMaybe arg of
  Just val -> Right val
  Nothing -> Left $ "Could not parse parameter " ++ key ++ "."
    ++ "Unable to convert " ++ arg


-- | A simple command line flag.
--   The parsing function will return True
--   if the flag is present, if the flag is provided to
--   the command line, and False otherwise.
--   For a key @foo@, the flag can either be @--foo@ or @-f@
boolFlag
  :: Key            -- ^ flag key
  -> FlagParam Bool
boolFlag key = FlagParam key id 

-- | A mandatory positional argument parameter
reqPos
  :: Read a
  => Key         -- ^ Param name
  -> StdArgParam Arg a
reqPos key = StdArgParam Mandatory Pos key (readArg key)

-- | An optional positional argument parameter
optPos
  :: Read a
  => a                  -- ^ Default value
  -> Key                -- ^ Param name
  -> StdArgParam Arg a
optPos val key = StdArgParam (Optional val) Pos key (readArg key)

-- | A mandatory flag argument parameter
reqFlag
  :: Read a
  => Key         -- ^ Flag name
  -> StdArgParam Arg a
reqFlag key = StdArgParam Mandatory Flag key (readArg key)

-- | An optional flag argument parameter
optFlag
  :: Read a
  => a                  -- ^ Default value
  -> Key                -- ^ Flag name
  -> StdArgParam Arg a
optFlag val key = StdArgParam (Optional val) Flag key (readArg key)

readArgs
  :: Read a
  => Key
  -> b
  -> (b -> a -> b)
  -> Args
  -> ParseResult b
readArgs key initval accum args = case errors of
  [] -> Right $ foldl accum initval values
  _  -> Left $ unlines errors
 where
  (errors, values) = partitionEithers $ map (readArg key) args

-- | A parameter consuming all the remaining positional parameters
posArgs
  :: Read a
  => Key                -- ^ Param name
  -> b                  -- ^ Initial value
  -> (b -> a -> b)      -- ^ Accumulation function
  -> StdArgParam Args b
posArgs key initval accum = StdArgParam
  Mandatory Pos key (readArgs key initval accum)

-- | A mandatory flag argument parameter taking multiple arguments
reqFlagArgs
  :: Read a
  => Key                -- ^ Flag name
  -> b                  -- ^ Initial value
  -> (b -> a -> b)      -- ^ Accumulation function
  -> StdArgParam Args b
reqFlagArgs key initval accum = StdArgParam
  Mandatory Flag key (readArgs key initval accum)

-- | An optional flag argument parameter taking multiple arguments
optFlagArgs
  :: Read a
  => b                  -- ^ Default value
  -> Key                -- ^ Flag name
  -> b                  -- ^ Initial value
  -> (b -> a -> b)      -- ^ Accumulation function
  -> StdArgParam Args b
optFlagArgs val key initval accum = StdArgParam
  (Optional val) Flag key (readArgs key initval accum)