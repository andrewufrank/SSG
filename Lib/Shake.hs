------------------------------------------------------------------------------
--
-- Module      :   the  process to convert
--              files in any input format to html
--              orginals are found in dire doughDir and go to bakeDir
--            used from serverSSG and ssg10 
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

module Lib.Shake where

import Uniform.Shake
import Uniform.Shake (liftErrIO)

-- import           Development.Shake -- hiding ((<.>), (</>))
-- import           Development.Shake.FilePath
--                                          hiding ( (<.>)
--                                                 , (</>) -- (toFilePath, makeAbsFile
-- --                , makeRelFile, makeRelDir, stripProperPrefix')
--                                                 )
import Lib.Bake -- for instances
import Lib.Foundation (SiteLayout(..), staticDirName, templatesDirName)
import Uniform.Error
import Uniform.FileIO

import Uniform.FileStrings ()
import Uniform.Strings (putIOwords)

ashake = 34

shakeDelete :: SiteLayout -> FilePath -> ErrIO ()
-- ^ experimental - twich found delete of md
shakeDelete _ filepath = do
  putIOwords
    [ "\n\n*******************************************"
    , "experimental -- twich found  DELETED MD file "
    , s2t filepath
    ]

shake :: SiteLayout -> FilePath -> ErrIO ()
-- the second argument is the file which has changed
shake layout filepath = do
  putIOwords
    [ "\n\n=====================================shake start"
    , "caused by"
    , s2t filepath
    ]
         -- where the layout is used, rest in shakeWrapped
  let doughP = doughDir $ layout -- the regular dough
      templatesP = (themeDir $ layout) `addFileName` (templatesDirName)
      bakedP = bakedDir $ layout
  setCurrentDir (doughDir layout)
    -- delete old baked files  -- should not be needed when needs correct
  fs <- getDirectoryDirs' (toFilePath bakedP)
  putIOwords ["shakeTesting", "could be to delete", showT fs]
  callIO $ shakeWrapped doughP templatesP bakedP
  putIOwords ["\n--------------------------------------------shake done", "\n"]
  return ()

--            , shownice layout
--  mapM_ removeDirectoryRecursive fs
shakeArgs2 bakedP =
  shakeArgs
    shakeOptions
      { shakeFiles = toFilePath bakedP
      , shakeVerbosity = Chatty -- Loud
      , shakeLint = Just LintBasic
      }

--                , shakeRebuild=[(RebuildNow,"allMarkdownConversion")]
--                  seems not to produce an effect
shakeWrapped :: Path Abs Dir -> Path Abs Dir -> Path Abs Dir -> IO ()
shakeWrapped doughP templatesP bakedP =
  shakeArgs2 bakedP $
    -- let doughD = toFilePath doughP
    --     templatesD = toFilePath templatesP
    --     bakedD = toFilePath bakedP
   do
    let staticP = bakedP </> ( staticDirName) :: Path Abs Dir 
    -- where all the static files go
        resourcesP = doughP </> (makeRelDir "resources") :: Path Abs Dir 
        masterTemplateP = makeRelFile "master4.dtpl"
        settingsYamlP = makeRelFile "settings2.yaml"
--    phony "clean" $ do
--        putNormal "delete all files in "
--        removeFiles bakedP<>"*"
            -- need one for ssg and one for baked
    want ["allMarkdownConversion"]
    phony "allMarkdownConversion" $ do
      liftIO $ putIOwords ["\nshakeWrapped phony allMarkdonwConversion"]
--        yamllint  -- issue with create process, error
--        yamllint: createProcess: runInteractive
        -- get markdown files
      mdFiles1 :: [Path Rel File] <- getDirectoryFilesP doughP ["//*.md"]
            -- , "//*.markdown"]
            -- todo markdown files are not found ?
                -- found ok, but not indexed
      liftIO $ putIOwords ["\nshakeWrapped phony 1"]
      let htmlFiles2 = map ((replaceExtension' "html") 
                            . (\f -> bakedP </> f)) mdFiles1
      let htmlFiles3 = filter ( not . isInfixOf' "index.md" . toFilePath) htmlFiles2
      liftIO $ putIOwords ["\nshakeWrapped phony 2"]
      -- let htmlFiles2 =
      -- [ bakedP </> (md $-<.> (makeExtension "html") :: Path Abs File)
      -- | md <- mdFiles1
      -- , not $ isInfixOf' "index.md" md
      -- ]
      liftIO $
        putIOwords
          [ "\nshakeWrapped - htmlFile"
          , showT  htmlFiles3 -- (map (makeRelativeP doughP)
          ]
      liftIO $ putIOwords ["\nshakeWrapped phony end"]
      
-- TODO missing static resources from dough
-- what else needs to be copied ?
    -- get html files from dough (not yet done, html are in resources)
--        htmlFilesStatic <- getDirectoryFiles  doughP ["//*.html"]
--            -- todo markdown files are not found ?
--
--        let htmlFilesStatic2 = [bakedP </> f | f <- htmlFilesStatic]
--        liftIO $ putIOwords ["\nshakeWrapped - htmlFilesStatic2"
--                ,  showT (map (makeRelative  doughP) htmlFilesStatic2)]
--        need htmlFilesStatic2
--        -- get css
--        cssFiles1 <- getDirectoryFiles templatesD ["*.css"] -- no subdirs
--        let cssFiles2 = [replaceDirectory c staticD  | c <- cssFiles1]
--        liftIO $ putIOwords ["\nshakeWrapped - phony cssFiles2", showT cssFiles2]
--        need cssFiles2
      needP htmlFiles3
        -- the templates static files are copied with watch
        -- process the index files after all others are done
      indexFiles1 <- getDirectoryFilesP doughP ["//index.md"]
      let indexFiles2 = map ((replaceExtension' "html") . (\f -> bakedP </> f)) mdFiles1
      -- let indexFiles2 = [bakedP </> ix $-<.> "html" | ix <- indexFiles1]
      liftIO $ putIOwords ["\nshakeWrapped - indexFiles2", showT indexFiles2]
      needP indexFiles2

    ((toFilePath bakedP) <> "//*.html") %> \out -> do
      let outP = makeAbsFile out  :: Path Abs File
      liftIO $ putIOwords ["\nshakeWrapped - bakedP html -  out ", showT outP]
      let md = doughP </> (stripProperPrefixP bakedP . replaceExtension' "md" $ outP)
      -- let md = doughP </> (makeRelativeP bakedP $ outP $-<.> "md")
      liftIO $ putIOwords ["\nshakeWrapped - bakedP html - md ", showT md]

      let masterTemplate = templatesP </> masterTemplateP
          masterSettings_yaml = doughP </> settingsYamlP

      biblio :: [Path Rel File] <- getDirectoryFilesP resourcesP ["*.bib"] 
      let biblio2 = [resourcesP </> b | b <- biblio] :: [Path Abs File]
      putIOwords ["shake bakedP", "biblio", showT biblio2]
      yamlPageFiles <- getDirectoryFilesP templatesP ["*.yaml"]
      let yamlPageFiles2 = [templatesP </> y | y <- yamlPageFiles]
      cssFiles1 :: [Path Rel File] <- getDirectoryFilesP templatesP ["*.css"]   -- no subdirs
      liftIO $ putIOwords ["\nshakeWrapped - bakedP html - cssFiles1 ", showT cssFiles1]
      -- let cssFiles2 = [replaceDirectoryP templatesP staticP c | c <- cssFiles1]  -- flipped args
      let cssFiles2 = [ staticP </> c | c <- cssFiles1]  -- flipped args
--        when (takeBaseName md == "index")  $
--            do
----        -- for index rebake
--                let mdDir = md -<.> ""  -- should be directory
--                ixLikely <- doesDirectoryExist mdDir
--                liftIO $ putIOwords ["shake bakedP", "ixLikely ", showT ixLikely, s2t mdDir]
--                when ixLikely $
--                    do
--                        submds <- getDirectoryFiles mdDir ["*.md"]
--                        putIOwords ["shake bakedP", "submds", showT submds]
--                        need submds
--
--        liftIO $ putIOwords ["shake bakedP", "ixLikely passed", showT ixLikely, s2t mdDir]
        -- the list of needs is too large and forces
        -- baking when any biblio,css,page.yaml or .dtpl changes
      needP biblio2
      needP cssFiles2
      needP yamlPageFiles2
      needP [masterSettings_yaml]
      needP [masterTemplate]
      needP [md]


      res <- liftErrIO $ bakeOneFile False md doughP templatesP outP
      return () 
            -- c relative to dough/

    (  (toFilePath staticP) <> "/*.css") %> \out -- insert css
     -> do
     let outP = makeAbsFile out  :: Path Abs File
     liftIO $ putIOwords ["\nshakeWrapped - staticD - *.css", showT outP]
     copyFileChangedP (replaceDirectoryP staticP templatesP outP) outP
-- instance Exception Text
-- runErr2action :: ErrIO a -> Action a
-- runErr2action op = liftIO $ do
--     res <- runErr  op
--     case res of
--         Left msg -> throw msg
--         Right a -> return a
--makeOneMaster :: FilePath -> FilePath -> FilePath -> IO ()
---- makes the master plus page style in template
--makeOneMaster master page result = do
--    putIOwords ["makeOneMaster", showT result]
--
--    res <- runErrorVoid $ putPageInMaster
--                     (makeAbsFile page) (makeAbsFile master)
--                    "body" (makeAbsFile result)
--    putIOwords ["makeOneMaster done", showT res ]
--    return ()
