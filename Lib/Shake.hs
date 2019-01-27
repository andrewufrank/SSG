
------------------------------------------------------------------------------
--
-- Module      :   the  process to convert
--              files in any input format to html
--              orginals are found in dire doughDir and go to bakeDir
--

-----------------------------------------------------------------------------
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeSynonymInstances  #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# OPTIONS -fno-warn-missing-signatures -fno-warn-orphans #-}

module Lib.Shake
     where

import Uniform.Strings (putIOwords) -- hiding ((<.>), (</>))
import Uniform.Filenames -- (toFilePath, makeAbsFile, makeRelFile, makeRelDir, stripProperPrefix')
         hiding ((<.>), (</>))
import Uniform.FileStrings () -- for instances
--import Uniform.Error
import Lib.Templating


import Lib.Foundation (SiteLayout (..))
import Lib.Bake

import Development.Shake
--import Development.Shake.Command
import Development.Shake.FilePath
--import Development.Shake.Util

shake :: SiteLayout ->    ErrIO ()
shake layout   = do
    putIOwords ["\nshake start", shownice layout]
    callIO $ shakeWrapped
                (toFilePath . doughDir $ layout)
                (toFilePath . doughDir $ layout)
                (toFilePath . doughDir $ layout)

    putIOwords ["\nshake done", "\n"]

    return ()

--bakedD, doughD, templatesD, staticD :: FilePath
--bakedD  =   toFilePath bakedPath
--doughD = toFilePath doughPath
--templatesD =  toFilePath templatesPath


shakeWrapped :: FilePath -> FilePath -> FilePath ->  IO  ()
shakeWrapped doughD templatesD bakedD = shakeArgs shakeOptions {shakeFiles=bakedD
                , shakeVerbosity=Chatty -- Loud
                , shakeLint=Just LintBasic
--                , shakeRebuild=[(RebuildNow,"allMarkdownConversion")]
--                  seems not to produce an effect
                } $
    do
        let staticD = bakedD </>"static"  -- where all the static files go

        want ["allMarkdownConversion"]

        phony "allMarkdownConversion" $
            do
                liftIO $ putIOwords ["shakeWrapped phony allMarkdonwConversion" ]

                -- get markdown files
                mdFiles1 <- getDirectoryFiles  doughD ["//*.md", "//*.markdown"]
                let htmlFiles2 = [bakedD </> md -<.> "html" | md <- mdFiles1]
                liftIO $ putIOwords ["shakeWrapped - htmlFile", showT htmlFiles2]

                -- get css
                cssFiles1 <- getDirectoryFiles templatesD ["*.css"] -- no subdirs
                liftIO $ putIOwords ["shakeWrapped - phony cssFiles1", showT cssFiles1]
                let cssFiles2 = [replaceDirectory c staticD  | c <- cssFiles1]
--                let cssFiles2 = [dropDirectory1 staticD </> c  | c <- cssFiles1]
                liftIO $ putIOwords ["shakeWrapped - phony cssFiles2", showT cssFiles2]
--                mapM_ (\fn -> copyFileChanged (templatesD </> fn) (staticD </> fn)) cssFiles1

--                liftIO $ putIOwords ["shakeWrapped - htmlFile", showT htmlFiles2]
--           shakeWrapped - htmlFile ["site/baked/index.html","site/baked/Blog/postwk.html"...
                need cssFiles2
--                need [staticD</>"page33.dtpl"]
                need htmlFiles2

        (bakedD <> "//*.html") %> \out ->
            do
                liftIO $ putIOwords ["shakeWrapped - bakedD html -  out ", showT out]
                let md =   doughD </> ( makeRelative bakedD $ out -<.> "md")
                liftIO $ putIOwords ["shakeWrapped - bakedD html - c ", showT md]
                let template = templatesD</>"page33.dtpl"
                need [md]
                need [template]
                liftIO $  bakeOneFileIO  md  template out  -- c relative to dough/

        (templatesD</>"page33.dtpl") %> \out ->     -- construct the template from pieces
            do
                liftIO $ putIOwords ["shakeWrapped - templatesD dtpl -  out ", showT out]
                let mf = templatesD</>"Master3.gtpl"
                let pf = templatesD</>"Page3.dtpl"
                need [mf, pf]
                liftIO $ makeOneMaster mf pf out
--                copyFileChanged (replaceDirectory out templatesD) out

        (staticD </> "*.css") %> \out ->            -- insert css
            do
                liftIO $ putIOwords ["shakeWrapped - staticD - *.css", showT out]
                copyFileChanged (replaceDirectory out templatesD) out


instance Exception Text

makeOneMaster :: FilePath -> FilePath -> FilePath -> IO ()
-- makes the master plus page style in template
makeOneMaster master page result = do
    putIOwords ["makeOneMaster", showT result]

    res <- runErrorVoid $ putPageInMaster
                     (makeAbsFile page) (makeAbsFile master)
                    "body" (makeAbsFile result)
    putIOwords ["makeOneMaster done", showT res ]
    return ()


bakeOneFileIO :: FilePath -> FilePath -> FilePath -> IO ()
-- bake one file absolute fp , page template and result html
bakeOneFileIO md template ht = do
            et <- runErr $ do
                    putIOwords ["bakeOneFileIO - from shake xx", s2t md] --baked/SGGdesign/Principles.md
--                    let fp1 = fp
----                            let fp1 = "/"<>fp
                    let md2 = makeAbsFile md
                    let template2 = makeAbsFile template
                    let ht2 = makeAbsFile ht
                    putIOwords ["bakeOneFileIO - files", showT md2, "\n", showT template2, "\n", showT ht2]
--                    let fp2 = makeRelFile fp1
--                    fp3 :: Path Rel File  <- stripProperPrefix' (makeRelDir doughD) fp2
--                    putIOwords ["bakeOneFileIO - next run shake", showT fp2]
--                            bakeOneFileIO - next run shake "baked/SGGdesign/Principles.md"
--                    let fp3 = fp2
                    res <- bakeOneFile True md2 template2 ht2
                    putIOwords ["bakeOneFileIO - done", showT ht2, res]
            case et of
                Left msg -> throw msg
                Right _ -> return ()
