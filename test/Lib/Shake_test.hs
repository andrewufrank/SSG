-----------------------------------------------------------------------------
--
-- ModuKe      :   testing the new shake 
-----------------------------------------------------------------------------
{-# OPTIONS_GHC -F -pgmF htfpp #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeSynonymInstances  #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# OPTIONS -fno-warn-missing-signatures -fno-warn-orphans -fno-warn-unused-imports#-}

module Lib.Shake_test  -- (openMain, htf_thisModuelsTests)
     where


import           Test.Framework
import Uniform.Test.TestHarness


import Lib.Foundation (progName, SiteLayout (..))
import Lib.Shake2
-- import Lib.FileMgt
-- import Lib.Foundation_test (testLayout)
-- import Lib.Foundation (templatesDirName)
-- import Uniform.Json (AtKey(..), Value(..))
-- import Uniform.Pandoc -- (DocValue(..), unDocValue, docValueFileType)
--import Lib.Templating (Gtemplate(..), gtmplFileType, Dtemplate(..))
-- import Control.Lens
--import Data.Aeson
-- import Data.Aeson.Lens
-- import Data.Aeson
--import Data.Aeson.Encode.Pretty (encodePretty)
--import Data.ByteString.Lazy as BS (putStrLn)

test_shakeMD = assertEqual () $
                shakeWrapped (doughDir layoutDefaults)
                ((themeDir $ layout) `addFileName` ( templatesDirName))
                (makeAbsDir "/home/frank/.SSG/bakedTest")

