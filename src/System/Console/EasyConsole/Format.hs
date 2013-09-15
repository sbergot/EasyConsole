module System.Console.EasyConsole.Format (
  CmdLineFormat (..),
  defaultFormat,
  showCmdLineAppUsage
  ) where

import qualified Data.Map                            as M
import           Data.Maybe

import           System.Console.EasyConsole.BaseType

data CmdLineFormat = CmdLineFormat {
  maxkeywidth    :: Int,
  keyindentwidth :: Int
  }

defaultFormat :: CmdLineFormat
defaultFormat = CmdLineFormat 60 20

showCmdLineAppUsage :: CmdLineFormat -> CmdLineApp a -> String
showCmdLineAppUsage fmt app =
  appName ++ appVersion ++ "\n" ++ appDescr ++ "\n" ++ appUsage where
    appName = appname app
    appVersion = fromMaybe "" $ appversion app
    appDescr = fromMaybe "" $ appdescr app
    paramdescrs = parserparams $ cmdargparser app
    appUsage = formatParamDescrs fmt paramdescrs
    
groupByKey :: Ord k => (a -> k) -> [a] -> [(k, [a])]
groupByKey getkey xs = M.toList $ M.fromListWith (++)
  $ map (\x -> (getkey x, [x])) xs

formatParamDescrs :: CmdLineFormat -> [ParamDescr] -> String
formatParamDescrs fmt paramdescrs = unlines $ map showCategory categories where
  categories :: [(String, [ParamDescr])]
  categories = groupByKey argCategory paramdescrs
  showCategory :: (String, [ParamDescr]) -> String
  showCategory (cat, descrs) =
    cat ++ ":\n" ++ formattedargs where
     formattedargs = unlines $ map (showargformat fmt) descrs

showargformat :: CmdLineFormat -> ParamDescr -> String
showargformat fmt descr =
  keyindent ++ formattedkey ++ sep ++ descrtext where
    keyindent = replicate (keyindentwidth fmt) ' '
    formattedkey = argFormat descr
    _maxkeywidth = maxkeywidth fmt
    padding = _maxkeywidth - length formattedkey
    sep = if padding > 0
      then replicate padding ' '
      else "\n" ++ keyindent ++ replicate _maxkeywidth ' '
    descrtext = argDescr descr