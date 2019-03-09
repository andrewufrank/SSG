
------------------------------------------------------------------------------
--
-- Module      :   create an index for a directory
--
-----------------------------------------------------------------------------
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeSynonymInstances  #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE DeriveGeneric, DeriveAnyClass #-}
--{-# LANGUAGE GeneralizedNewtypeDeriving #-}
--{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE RecordWildCards #-}
--{-# LANGUAGE DuplicateRecordFields #-}

module Lib.Indexing
     where

import Uniform.Strings hiding ((<.>), (</>))
import Uniform.FileIO hiding ((<.>), (</>))
import qualified Uniform.FileIO as FileIO
--import Uniform.FileStrings
--import Uniform.TypedFile

import Data.Aeson
import Data.Yaml  as Y
--import Lib.FileMgt
import Development.Shake.FilePath
import Lib.FileMgt (DocValue (..)) --  MarkdownText (..), markdownFileType)
import Lib.YamlBlocks

--insertIndex :: Path Abs File -> ErrIO ()
---- insert the index into the index md

makeIndex :: Bool -> DocValue -> Path Abs File -> ErrIO MenuEntry
-- | make the index text, will be moved into the page template later
-- return zero if not index page
makeIndex debug docval pageFn = do
        let doindex = fromMaybe False $ getMaybeStringAtKey docval "indexPage"
        when debug $ putIOwords ["makeIndex", "doindex", showT doindex]

        ix :: MenuEntry <- if doindex
            then do
                    let currentDir2 = makeAbsDir $ getParentDir pageFn
                    ix2 <- makeIndexForDir debug currentDir2 pageFn
                    when debug $ putIOwords ["makeIndex", "index", showT ix2]
                    return ix2

          else return zero
        return ix -- (toJSON ix :: Value)


makeIndexForDir :: Bool -> Path Abs Dir -> Path Abs File -> ErrIO MenuEntry
-- make the index for the directory
-- place result in index.html in this directory
-- the name of the index file is passed to exclude it
-- makes index only for md files in dough
-- needs more work for index? date ? abstract?
makeIndexForDir debug focus indexFn = do
    fs <- getDirContentNonHidden (toFilePath focus)
    let fs2 = filter (/= (toFilePath indexFn)) fs -- exclude index
    let fs3 = filter (FileIO.hasExtension ( "md")) fs2
    when debug $ putIOwords ["makeIndexForDir", "for ", showT focus, "\n", showT fs3 ]

    -- needed filename.html title abstract author data

    is :: [IndexEntry] <- mapM (\f -> getOneIndexEntry (makeAbsFile f)) fs3
    let menu1 = MenuEntry {menu2 = is}
    when debug $ putIOwords ["makeIndexForDir", "for ", showT focus, "\n", showT menu1 ]
    let yaml1 = bb2t .   Y.encode  $ menu1
    when debug $ putIOwords ["makeIndexForDir", "yaml ", yaml1  ]

    return menu1

getOneIndexEntry :: Path Abs File -> ErrIO (IndexEntry)
-- fill one entry from one md file
getOneIndexEntry md = do
        (_, meta2) <- readMd2meta md
--        mdtext :: MarkdownText <- read8 md markdownFileType
--        pandoc <- readMarkdown2 mdtext
--        let meta2 = flattenMeta (getMeta pandoc)

        let abstract1 = getMaybeStringAtKey meta2 "abstract" :: Maybe Text
        let title1 = getMaybeStringAtKey meta2 "title" :: Maybe Text
        let author1 = getMaybeStringAtKey meta2 "author" :: Maybe Text
        let date1 = getMaybeStringAtKey meta2 "date" :: Maybe Text
        let publish1 = getMaybeStringAtKey meta2 "publish" :: Maybe Text

        let paths = reverse $ splitPath (toFilePath md)
        let fn = head paths
        let dir = head . tail $ paths
        let fnn = takeBaseName fn
        let ln = s2t $ "/" <> dir </> fnn  <.> "html"

        let ix = IndexEntry {text =  s2t fnn
                        , link = ln
                        , abstract =  maybe "" id abstract1
                        , title = maybe ln id title1
                        , author = maybe "" id author1
                        , date = maybe "" id date1
                        , publicationState =  shownice $ maybe PSpublish (\t -> case t of
                                                                        "True" -> PSpublish
                                                                        "Draft" -> PSdraft
                                                                        "Old" -> PSold
                                                                        _ -> PSzero
                                                            ) publish1
                        }
        return ix


data MenuEntry = MenuEntry {menu2 :: [IndexEntry]} deriving (Generic, Eq, Ord, Show)
instance Zeros MenuEntry where zero = MenuEntry zero
instance FromJSON MenuEntry
instance ToJSON MenuEntry

data IndexEntry = IndexEntry {text :: Text  -- ^ naked filename
                              , link :: Text -- ^ the url relative to dough dir
                              , title :: Text -- ^ the title
                              , abstract :: Text
                              , author :: Text
                              , date :: Text -- ^ data in the JJJJ-MM-DD format
                              , publicationState :: Text

                              } deriving (Generic, Eq, Ord, Show)
instance Zeros IndexEntry where zero = IndexEntry zero zero zero zero zero zero zero
instance FromJSON IndexEntry
instance ToJSON IndexEntry

data PublicationState = PSpublish | PSdraft | PSold | PSzero
        deriving (Generic,  Show, Read, Ord, Eq)
-- ^ is this file ready to publish
instance Zeros PublicationState where zero = PSzero
instance NiceStrings PublicationState where shownice = drop' 2 . showT

instance ToJSON PublicationState
instance FromJSON PublicationState


--makeIndexEntry :: Path Abs File -> ErrIO IndexEntry
--makeIndexEntry fp = do
--    let paths = reverse $ splitPath (toFilePath fp)
--    let fn = head paths
--    let dir = head . tail $ paths
--    let fnn = takeBaseName fn
--
--
--
--    return $ IndexEntry {text = s2t fnn, link = s2t $ "/" <> dir </> fnn <.> "html"}


--getDirContentNonHiddenFiles :: FileOps fp => fp -> ErrIO [fp]
--getDirContentNonHiddenFiles fp = do
--    fps  <- getDirContentNonHidden fp
--    filterM doesFileExist' fps

