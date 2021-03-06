{- |
Module      :  $Header$
Copyright   :  (c) Simon Bergot
License     :  BSD3

Maintainer  :  simon.bergot@gmail.com
Stability   :  unstable
Portability :  portable

Parameters are basic building blocks of a command line parser.
-}

module System.Console.ArgParser.Params (
  -- * Standard constructors
  -- ** Constructor
   StdArgParam (..)
  -- ** Misc types
  , ArgSrc (..)
  , FlagFormat (..)
  , ArgParser (..)
  , Optionality (..)
  , Key
  -- * Special constructors
  , FlagParam (..)
  , Descr (..)
  , MetaVar (..)
  ) where

import           Data.Char                         (toUpper)
import           Data.List
import qualified Data.Map                          as M
import           Data.Maybe
import           System.Console.ArgParser.BaseType
import           System.Console.ArgParser.Parser

-- | identifier used to specify the name of a flag
--   or a positional argument.
type Key = String

-- | Specify the format of a flag
data FlagFormat =
  -- | Possible short format ie @-f@ or @--foo@
  Short |
  -- | Only long format ie @--foo@
  Long

deleteMany :: [String] -> Flags -> Flags
deleteMany keys flags = foldl (flip M.delete) flags keys

type FlagParser = String -> Flags -> (Maybe Args, Flags)

takeFlag :: FlagParser
takeFlag key flags = (args, rest) where
  args = case mapMaybe lookupflag prefixes of
    [] -> Nothing
    grpargs -> Just $ concat grpargs
  lookupflag _key = M.lookup _key flags
  rest = deleteMany prefixes flags
  prefixes = drop 1 $ inits key

takeLongFlag :: FlagParser
takeLongFlag key flags = (args, rest) where
  args = M.lookup key flags
  rest = M.delete key flags

takeValidFlag :: FlagFormat -> FlagParser
takeValidFlag fmt = case fmt of
  Short -> takeFlag
  Long  -> takeLongFlag

-- | A simple command line flag.
--   The parsing function will be passed True
--   if the flag is present, if the flag is provided to
--   the command line, and False otherwise.
--   For a key @foo@, the flag can either be @--foo@ or @-f@
data FlagParam a =
  FlagParam FlagFormat Key (Bool -> a)

fullFlagformat :: FlagFormat -> String -> String
fullFlagformat fmt key = case fmt of
  Short -> shortfmt ++ ", " ++ longfmt
  Long  -> longfmt
 where
  shortfmt = shortflagformat key
  longfmt = longflagformat key

longflagformat :: String -> String
longflagformat = ("--" ++)

shortflagformat :: String -> String
shortflagformat key = '-' : first where
  first = take 1 key

shortestFlagFmt :: FlagFormat -> String -> String
shortestFlagFmt fmt = case fmt of
  Short -> shortflagformat
  Long  -> longflagformat

instance ParamSpec FlagParam where
  getParser (FlagParam fmt key parse) = Parser rawparse where
    rawparse (pos, flags) = case margs of
      Just []   -> (Right $ parse True,  (pos, rest))
      Just args' -> (Right $ parse True,  (pos ++ args', rest))
      Nothing   -> (Right $ parse False, (pos, rest))
     where
      (margs, rest) = takeValidFlag fmt key flags
  getParamDescr (FlagParam fmt key _) = [ParamDescr
    (const $ "[" ++ shortestFlagFmt fmt key ++ "]")
    "optional arguments"
    (const $ fullFlagformat fmt key)
    ""
    (map toUpper key)]

infixl 2 `Descr`

-- | Allows the user to provide a description for a particular parameter.
--   Can be used as an infix operator:
--
-- > myparam `Descr` "this is my description"
data Descr spec a = Descr
  { getdvalue    :: spec a
  , getuserdescr :: String
  }

instance ParamSpec spec => ParamSpec (Descr spec) where
  getParser = getParser . getdvalue
  getParamDescr (Descr inner descr) =
    map (\d -> d { argDescr = descr }) (getParamDescr inner)

infixl 2 `MetaVar`

-- | Allows the user to provide a description for a particular parameter.
--   Can be used as an infix operator:
--
-- > myparam `Descr` "this is my description"
data MetaVar spec a = MetaVar
  { getmvvalue  :: spec a
  , getusermvar :: String
  }

instance ParamSpec spec => ParamSpec (MetaVar spec) where
  getParser = getParser . getmvvalue
  getParamDescr (MetaVar inner metavar) =
    map (\d -> d { argMetaVar = metavar }) (getParamDescr inner)

-- | Defines the source of a parameter: either positional or flag.
data ArgSrc = Flag | Pos

-- | Defines whether a parameter is mandatory or optional.
--   When a parameter is marked as Optional, a default value must
--   be provided.
data Optionality a = Mandatory | Optional a

-- | Defines the number of args consumed by a standard parameter
data ArgParser a =
  -- | Uses exactly one arg
  SingleArgParser (Arg -> ParseResult a) |
  -- | Uses any number of args
  MulipleArgParser (Args -> ParseResult a)

runFlagParse
  :: ArgParser a
  -> Args
  -> ParseResult a
runFlagParse parser args = case parser of
  SingleArgParser f -> case args of
    []    -> Left "missing arg"
    [val] -> f val
    _     -> Left "too many args"
  MulipleArgParser f -> f args

runPosParse
  :: ArgParser a
  -> Args
  -> (ParseResult a, Args)
runPosParse parser args = case parser of
  SingleArgParser f -> case args of
    []       -> (Left "missing arg", [])
    val:rest -> (f val, rest)
  MulipleArgParser f -> (f args, [])

getValFormat :: ArgParser a -> String -> String
getValFormat parser metavar = case parser of
  SingleArgParser _  -> metavar
  MulipleArgParser _ -> "[" ++ metavar ++ "...]"

-- | Defines a parameter consuming arguments on the command line.
--   The source defines whether the arguments are positional:
--
-- > myprog posarg1 posarg2 ...
--
--   ... or are taken from a flag:
--
-- > myprog --myflag flagarg1 flagarg2 ...
--
--   short form:
--
-- > myprog -m flagarg1 flagarg2 ...
--
--   One can provide two signatures of parsing function using the 'ArgParser type':
--
--   * 'SingleArgParser' means that the parameter expect exactly one arg
--
--   * 'MulipleArgParser' means that the parameter expect any number of args
data StdArgParam a =
  StdArgParam (Optionality a) ArgSrc Key (ArgParser a)

instance ParamSpec StdArgParam where
  getParser (StdArgParam opt src key parse) = Parser rawparse where
    rawparse = choosesrc flagparse posparse src

    flagparse (pos, flags) = (logkey key res, (pos, rest)) where
      (margs, rest) = takeFlag key flags
      res = case margs of
        Nothing -> defaultOrError "missing flag"
        Just args -> runFlagParse parse args

    posparse (pos, flags) = case (pos, parse) of
      ([], SingleArgParser _) ->
        (logkey key $ defaultOrError "missing arg", (pos, flags))
      (args, _) -> let (res, rest) = runPosParse parse args
              in  (res, (rest, flags))

    defaultOrError = missing opt

  getParamDescr (StdArgParam opt src key parser) =
    [ParamDescr
      (wrap opt . usage) (category opt) format "" _metavar]
   where
    getflagformat flagfmt = choosesrc
      ((++ "  ") . flagfmt)
      (const "")
    getinputfmt flagfmt metavar = flag ++ value where
      flag = getflagformat flagfmt src key
      value =  getValFormat parser metavar
    usage = getinputfmt shortflagformat
    format = case src of
      Flag -> getinputfmt (fullFlagformat Short)
      Pos  -> id
    wrap Mandatory msg = msg
    wrap _         msg = "[" ++ msg ++ "]"
    _metavar = choosesrc (map toUpper key) key src


choosesrc :: a -> a -> ArgSrc -> a
choosesrc flag pos src = case src of
  Flag -> flag
  Pos  -> pos

missing :: Optionality a -> String -> ParseResult a
missing opt msg = case opt of
  Mandatory    -> Left msg
  Optional val -> Right val

category :: Optionality a -> String
category opt = case opt of
  Mandatory -> "mandatory arguments"
  _         -> "optional arguments"

logkey :: String -> ParseResult a -> ParseResult a
logkey key result = case result of
  Left err -> Left $ "fail to parse '" ++ key ++ "' : " ++ err
  val      -> val
