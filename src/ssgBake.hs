-----------------------------------------------------------------------------
--
-- Module      :   ssgBake
-- the main for the sgg - no UI yet
-- uses shake only to convert the md files
-- copies all resources
-- must start in dir with settings2.yaml

-- experimental: only the md files are baked 
-----------------------------------------------------------------------------
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeSynonymInstances  #-}
{-# LANGUAGE OverloadedStrings     #-}

module Main     where      -- must have Main (main) or Main where

import Uniform.Convenience.StartApp
import Uniform.FileIO hiding ((<.>), (</>))
import Uniform.Shake.Path
import Uniform.Shake 
import Uniform.Error ()

import Lib.Bake
-- import Lib.Shake
--import Lib.Foundation (layoutDefaults, SiteLayout (..))
import Lib.ReadSettingFile
import Lib.Foundation (SiteLayout (..), templatesDirName, staticDirName, resourcesDirName, templatesImgDirName)

import Development.Shake
import Development.Shake.FilePath
--import Development.Shake.Path hiding (setCurrentDir, toFilePath)

import Web.Scotty
import Network.Wai.Middleware.Static (staticPolicy, addBase)
import Network.Wai.Handler.Warp  (Port) -- .Warp.Types


programName = "SSG10" :: Text
progTitle = "constructing a static site generator x6" :: Text

settingsfileName = makeRelFile "settings2" -- the yaml file
bannerImageFileName = makeRelFile "cropped-DSC05127-1024x330.jpg"
-- where should this be fixed?

main :: IO ()
main = startProg programName progTitle
             (do
                (layout2, port2)  <- readSettings settingsfileName
                bakeAll layout2
                callIO $ scotty port2 (site (bakedDir layout2))
                return ()
                )

bakeAll :: SiteLayout -> ErrIO ()
-- ^ bake all md files and copy the resources
-- sets the current dir to doughDir
bakeAll layout = do
    let  -- where the layout is used, rest in shakeWrapped
          doughP      =    doughDir  layout  -- the regular dough
          templatesP =   themeDir layout
                               `addFileName` templatesDirName
          bakedP =  bakedDir  layout
    setCurrentDir doughP
    deleteDirRecursive bakedP

    -- copy resources and banner   not easy to do with shake
    -- only the html and the pdf files (possible the jpg) are required
--    copyDirRecursive (doughP `addDir` resourcesDirName)   (bakedP `addDir` staticDirName)

    let bannerImage = templatesImgDirName `addFileName` bannerImageFileName

    copyOneFile (templatesP `addFileName` bannerImage)
        (bakedP `addDir` staticDirName `addDir` bannerImage)

    -- convert md files and copy css
    callIO $ shakeMD layout  doughP templatesP bakedP

    return ()

shakeMD :: SiteLayout -> Path Abs Dir  -> Path Abs Dir -> Path Abs Dir  -> IO ()
-- ^ process all md files (currently only the MD)
-- in IO
shakeMD layout  doughP templatesP bakedP =
--    shakeArgs2 bakedP $ do
    shakeArgs shakeOptions {shakeFiles=toFilePath bakedP -- TODO
                , shakeVerbosity=Chatty -- Loud -- Diagnostic --
                , shakeLint=Just LintBasic
--                , shakeRebuild=[(RebuildNow,"allMarkdownConversion")]
--                  seems not to produce an effect
                } $ do

        -- let doughD = toFilePath doughP
        --     templatesD = toFilePath templatesP
        --     bakedP = toFilePath bakedP
        let staticP =   bakedP `addFileName`  staticDirName  -- ok
        let resourcesDir =   doughP `addFileName`  resourcesDirName

        liftIO $ putIOwords ["\nshake dirs", "\n\tstaticP", showT staticP, "\n\tbakedP", showT bakedP
                        ,"\nresourcesDir", showT resourcesDir]

        want ["allMarkdownConversion"]
        phony "allMarkdownConversion" $ do

            mdFiles1 <- getDirectoryFilesP  doughP ["**/*.md"]   -- subfiledirectories
            let htmlFiles2 = [(toFilePath bakedP) </> (toFilePath md) -<.> "html" | md <- mdFiles1] -- , not $ isInfixOf' "index.md" md]
            liftIO $ putIOwords ["============================\nshakeWrapped - mdFile 1",  showT   mdFiles1]
            liftIO $ putIOwords ["\nshakeWrapped - htmlFile 2",  showT  htmlFiles2]
            need htmlFiles2

--             cssFiles1 <- getDirectoryFiles templatesD ["*.css"] -- no subdirs
--             let cssFiles2 = [replaceDirectory c staticP  | c <- cssFiles1]
--             liftIO $ putIOwords ["========================\nshakeWrapped - css files 1",  showT   cssFiles1]
--             liftIO $ putIOwords ["\nshakeWrapped - css files" ,  showT  cssFiles2]
--             need cssFiles2

--             pdfFiles1 <- getDirectoryFiles resourcesDir ["**/*.pdf"] -- subdirs
--             let pdfFiles2 = [ staticP </> c  | c <- pdfFiles1]
--             liftIO $ putIOwords ["===================\nshakeWrapped - pdf files1",  showT   pdfFiles1]
--             liftIO $ putIOwords ["\nshakeWrapped - pdf files 2",  showT  pdfFiles2]
--             need pdfFiles2
-- --
--             htmlFiles11<- getDirectoryFiles resourcesDir ["**/*.html"] -- subdirs
--             let htmlFiles22 = [  staticP </> c | c <- htmlFiles11]
--             liftIO $ putIOwords ["===================\nshakeWrapped - html 11 files",  showT   htmlFiles11]
--             liftIO $ putIOwords ["\nshakeWrapped - html 22 files", showT htmlFiles22]
--             need htmlFiles22

        (\x -> (((toFilePath bakedP) <> "**/*.html") ?== x) 
                            && not  (((toFilePath staticP) <> "**/*.html") ?== x)) -- with subdir
                  ?> \out -> do
            liftIO $ putIOwords ["\nshakeWrapped - bakedP html -  out ", showT out]
            let md = makeAbsFile $ (toFilePath doughP)</>  (makeRelative (toFilePath bakedP) $ out -<.> "md")
            liftIO $ putIOwords ["\nshakeWrapped - bakedP html - c ", showT bakedP, "file", showT md]
            let outP = makeAbsFile out 
            res <- runErr2action $ bakeOneFile True  md  doughP templatesP outP
            return ()
        -- (staticP <> "**/*.html" ) %> \out -> do  -- with subdir
        --     liftIO $ putIOwords ["\nshakeWrapped - staticP ok - *.html", showT staticP, "file", showT out]
        --     let fromfile = resourcesDir </> (makeRelative staticP out)
        --     liftIO $ putIOwords ["\nshakeWrapped - staticP - fromfile ", showT fromfile]
        --     copyFileChanged fromfile out

        -- (staticP </> "*.css") %> \out ->  do           -- insert css -- no subdir
        --     liftIO $ putIOwords ["\nshakeWrapped - staticP - *.css", showT out]
        --     copyFileChanged (replaceDirectory out templatesD) out

        -- (staticP <> "**/*.pdf") %> \out ->  do           -- insert pdfFIles1 -- with subdir
        --     liftIO $ putIOwords ["\nshakeWrapped - staticP - *.pdf", showT out]
        --     let fromfile = resourcesDir </> (makeRelative staticP out)
        --     liftIO $ putIOwords ["\nshakeWrapped - staticP - fromfile ", showT fromfile]
        --     copyFileChanged fromfile out


-- /home/frank/bakedHomepageSSG/SSGdesign/index.html
        return ()

site :: Path Abs Dir -> ScottyM  ()
-- for get, return the page from baked
-- for post return error
site bakedPath = do
    get "/" $ file (landingPage bakedPath)
    middleware $ staticPolicy $ addBase (toFilePath bakedPath)


landingPage bakedPath = toFilePath $ addFileName bakedPath (makeRelFile "landingPage.html")
