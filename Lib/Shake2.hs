------------------------------------------------------------------------------
--
-- Module      :  with Path  the  process to convert
--              files in any input format to html
--              orginals are found in dire doughDir and go to bakeDir
--
-----------------------------------------------------------------------------
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeSynonymInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# OPTIONS -fno-warn-missing-signatures -fno-warn-orphans #-}

module Lib.Shake2 where

import Uniform.Error (ErrIO, callIO, liftIO)
import Uniform.Shake
import Uniform.Strings (putIOwords, showT)

import Lib.Foundation
  ( SiteLayout(..)
  , resourcesDirName
  , staticDirName
  , templatesDirName
  , templatesImgDirName
  )
import Lib.CmdLineArgs (PubFlags(..))

import Lib.Bake

shakeDelete :: SiteLayout -> FilePath -> ErrIO ()
-- ^ experimental - twich found delete of md
shakeDelete _ filepath = do
  putIOwords
    [ "\n\n*******************************************"
    , "experimental -- twich found  DELETED MD file "
    , s2t filepath
    ]

shakeArgs2 :: Path b t -> Rules () -> IO ()
shakeArgs2 bakedP = do 
  -- putIOwords ["shakeArgs2", "bakedP", s2t . toFilePath $ bakedP]
  res <- shake  -- not shakeArgs, which would include the cmd line args
    shakeOptions
      { shakeFiles = toFilePath bakedP
      , shakeVerbosity = Chatty -- Loud
      , shakeLint = Just LintBasic
      }
  -- putIOwords ["shakeArgs2", "done"]
  return res 
    

shakeAll ::  SiteLayout -> PubFlags -> FilePath -> ErrIO ()
-- ^ bake all md files and copy the resources
-- sets the current dir to doughDir
-- copies banner image 
shakeAll  layout flags filepath = do
        --  where the layout is used, rest in shakeWrapped

  putIOwords
    [ "\n\n=====================================shakeAll start"
    , "\n flags", showT flags, "caused by"
    , s2t filepath
    ]
  let doughP = doughDir layout -- the regular dough
      templatesP = themeDir layout `addFileName` templatesDirName
      bakedP = bakedDir layout
      bannerImageFileName = (bannerImage layout)

  setCurrentDir doughP  -- must be done earlier to find settings file!
  deleteDirRecursive bakedP
  -- delete all the previous stuff for a new start 
  -- covers the delete issue, which shake does not handle well


    -- copy resources and banner   not easy to do with shake
    -- only the html and the pdf files (possible the jpg) are required
  let bannerImage2 = templatesImgDirName `addFileName` bannerImageFileName
  copyOneFile
    (templatesP `addFileName` bannerImage2)
    (bakedP </> staticDirName </> bannerImage2)
    -- convert md files and copy css
  callIO $ shakeMD layout flags doughP templatesP bakedP
  return ()

--    copyDirRecursive (doughP `addDir` resourcesDirName)   (bakedP `addDir` staticDirName)
shakeMD :: SiteLayout -> PubFlags -> Path Abs Dir -> Path Abs Dir -> Path Abs Dir -> IO ()
-- ^ process all md files (currently only the MD)
-- in IO
shakeMD layout flags doughP templatesP bakedP = shakeArgs2 bakedP $ do
--  =
--   shakeArgs2 bakedP 
-- --     shakeOptions
-- --       { shakeFiles = toFilePath bakedP -- TODO
-- --       , shakeVerbosity = Chatty -- Loud -- Diagnostic --
-- --       , shakeLint = Just LintBasic
-- -- --                , shakeRebuild=[(RebuildNow,"allMarkdownConversion")]
-- -- --                  seems not to produce an effect
-- --       } $ -- in Rule () 
--    do
    let staticP = bakedP </> staticDirName :: Path Abs Dir
    let resourcesP = doughP </> resourcesDirName :: Path Abs Dir
    let masterTemplate = templatesP </> masterTemplateP :: Path Abs File 
        masterTemplateP = makeRelFile "master4.dtpl" :: Path Rel File 
        settingsYamlP = makeRelFile "settings2.yaml" :: Path Rel File 
        masterSettings_yaml = doughP </> settingsYamlP :: Path Abs File


    liftIO $
      putIOwords
        [ "\nshakeMD dirs"
        , "\n\tstaticP"
        , showT staticP
        , "\n\tbakedP"
        , showT bakedP
        , "\nresourcesDir"
        , showT resourcesP
        ]
    want ["allMarkdownConversion"]
    phony "allMarkdownConversion" $ do
      mdFiles1 :: [Path Rel File] <- getDirectoryFilesP doughP ["**/*.md"] -- subfiledirectories
      let htmlFiles3 =
            map (replaceExtension' "html" . (bakedP </>)) mdFiles1
                        -- [( bakedP </>  md) -<.> "html" | md <- mdFiles1] 
             :: [Path Abs File]
                            -- , not $ isInfixOf' "index.md" md]
            -- let htmlFiles3 = map (replaceExtension "html") htmlFiles2 :: [Path Abs File]
      liftIO $
        putIOwords
          ["============================\nshakeMD - mdFile 1", showT mdFiles1]
      liftIO $ putIOwords ["\nshakeMD - htmlFile 2", showT htmlFiles3]
      needP htmlFiles3  -- includes the index files 

      cssFiles1 :: [Path Rel File] <- getDirectoryFilesP templatesP ["*.css"] -- no subdirs
      let cssFiles2 = [ staticP </> c | c <- cssFiles1] :: [Path Abs File]
      liftIO $ putIOwords ["========================\nshakeMD - css files 1",  showT   cssFiles1]
      liftIO $ putIOwords ["\nshakeMD - css files" ,  showT  cssFiles2]
      needP cssFiles2

      pdfFiles1 :: [Path Rel File] <- getDirectoryFilesP resourcesP ["**/*.pdf"] -- subdirs
      let pdfFiles2 = [ staticP </> c  | c <- pdfFiles1]
      liftIO $ putIOwords ["===================\nshakeMD - pdf files1",  showT   pdfFiles1]
      liftIO $ putIOwords ["\nshakeMD - pdf files 2",  showT  pdfFiles2]
      needP pdfFiles2
-- --
      htmlFiles11 :: [Path Rel File]  <- getDirectoryFilesP resourcesP ["**/*.html"] -- subdirs
      let htmlFiles22 = [  staticP </> c | c <- htmlFiles11]
      liftIO $ putIOwords ["===================\nshakeMD - html 11 files",  showT   htmlFiles11]
      liftIO $ putIOwords ["\nshakeMD - html 22 files", showT htmlFiles22]
      needP htmlFiles22

      biblio :: [Path Rel File] <- getDirectoryFilesP resourcesP ["*.bib"]
      let biblio2 = [resourcesP </> b | b <- biblio] :: [Path Abs File]
      putIOwords ["shake bakedP", "biblio", showT biblio2]
      needP biblio2

      yamlPageFiles <- getDirectoryFilesP templatesP ["*.yaml"]
      let yamlPageFiles2 = [templatesP </> y | y <- yamlPageFiles]
      putIOwords ["shake bakedP", "yamlPages", showT yamlPageFiles2]
      needP yamlPageFiles2
  
      cssFiles22 :: [Path Rel File] <- getDirectoryFilesP templatesP ["*.css"] -- no subdirs
      liftIO $
        putIOwords
          ["\nshakeWrapped - bakedP html - cssFiles1 ", showT cssFiles22]
      -- let cssFiles2 = [replaceDirectoryP templatesP staticP c | c <- cssFiles1]  -- flipped args
      let cssFiles3 = [staticP </> c | c <- cssFiles22] -- flipped args
      needP cssFiles3

      needP [masterSettings_yaml]
      needP [masterTemplate]


    (\x ->
       ((toFilePath bakedP <> "**/*.html") ?== x) &&
       not ((toFilePath staticP <> "**/*.html") ?== x) -- with subdir
      ) ?> \out
            -- liftIO $ putIOwords ["\nshakeMD - bakedP html -  out ", showT out]
            -- hakeMD - bakedP html -  out  "/home/frank/.SSG/bakedTest/SSGdesign/index.html"
     -> do
      let outP = makeAbsFile out :: Path Abs File
            -- --needs to know if this is abs or rel file !
            -- --liftIO $ putIOwords ["\nshakeMD - bakedP html -  out2 ", showT outP] 
      let md = replaceExtension' "md" outP :: Path Abs File --  <-    out2 -<.> "md"  
            -- liftIO $ putIOwords ["\nshakeMD - bakedP html 2 -  md ", showT md]
            -- --let md1 =  stripProperPrefixP bakedP md :: Path Rel File 
            -- l--iftIO $ putIOwords ["\nshakeMD - bakedP html 3 - md1 ", showT md1]
      let md2 = doughP </> (stripProperPrefixP bakedP md) :: Path Abs File
            -- liftIO $ putIOwords ["\nshakeMD - bakedP html 4 - md2 ", showT md2]
      res <- runErr2action $ bakeOneFile True flags md2 doughP templatesP outP
      return ()


    (toFilePath staticP <> "**/*.html") %> \out -- with subdir
     -> do
      let outP = makeAbsFile out :: Path Abs File
      liftIO $
        putIOwords
          [ "\nshakeMD - staticP ok - *.html"
          , showT staticP
          , "file"
          , showT outP
          , "out"
          , showT out
          ]
      let fromfile = resourcesP </> (makeRelativeP staticP outP)
      liftIO $ putIOwords ["\nshakeMD - staticP - fromfile ", showT fromfile]
      copyFileChangedP ( fromfile) outP

    (toFilePath staticP <> "/*.css") %> \out ->  do           -- insert css -- no subdir
      let outP = makeAbsFile out :: Path Abs File
      liftIO $ putIOwords ["\nshakeMD - staticP - *.css\n"
            , showT outP, "\nTemplatesP", showT templatesP]
      let fromfile = templatesP </> (makeRelativeP staticP outP)
      liftIO $ putIOwords ["\nshakeMD - staticP css- fromfile ", showT fromfile]
      copyFileChangedP fromfile outP

    (toFilePath staticP <> "**/*.pdf") %> \out ->  do           -- insert pdfFIles1 -- with subdir
      let outP = makeAbsFile out :: Path Abs File
      liftIO $ putIOwords ["\nshakeMD - staticP - *.pdf", showT outP]
      let fromfile = resourcesP </> (makeRelativeP staticP outP)
      liftIO $ putIOwords ["\nshakeMD - staticP  pdf - fromfile ", showT fromfile]
      copyFileChangedP fromfile outP

    return ()

-- copyFileChangedP source destDir = copyFileChanged (toFilePath source) (toFilePath destDir)
