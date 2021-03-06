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
{-# LANGUAGE OverloadedStrings     #-}
{-# LANGUAGE DeriveGeneric     #-}

module Lib.Indexing
    ( module Lib.Indexing
    , getAtKey
    )
where

import           Uniform.Shake
import           GHC.Exts                       ( sortWith )
import           Uniform.Json
import           Uniform.Json                   ( FromJSON(..) )
import           Uniform.Pandoc                 (  DocValue(..)
                        -- , unDocValue
                                                , getAtKey
                                                )
import           Uniform.Time                   ( year2000 )
import           Lib.CmdLineArgs                ( PubFlags(..) )
import           Lib.CheckInput                 ( MetaRec(..)
                                                , PublicationState(..)
                                                -- , readMeta2rec
                                                , checkOneMdFile
                                                )

makeIndex
    :: Bool
    -> PubFlags
    -> DocValue
    -> Path Abs File
    -> Path Abs Dir
    -> ErrIO MenuEntry
-- | make the index text, will be moved into the page template later
-- return zero if not index page
makeIndex debug flags docval pageFn dough2 = do
    let doindex   = fromMaybe False $ getAtKey docval "indexPage"
    let indexSort = getAtKey docval "indexSort" :: Maybe Text
    when debug $ putIOwords ["makeIndex", "doindex", showT doindex]

    ix :: MenuEntry <- if doindex
        then do
            let currentDir2 = makeAbsDir $ getParentDir pageFn
            ix2 <- makeIndexForDir debug
                                   flags
                                   currentDir2
                                   pageFn
                                   dough2
                                   indexSort
            when debug $ putIOwords ["makeIndex", "index", showT ix2]
            return ix2
        else return zero
    return ix -- (toJSON ix :: Value)


makeIndexForDir
    :: Bool
    -> PubFlags
    -> Path Abs Dir
    -> Path Abs File
    -> Path Abs Dir
    -> Maybe Text
    -> ErrIO MenuEntry
-- make the index for the directory
-- place result in index.html in this directory
-- the name of the index file is passed to exclude it
-- makes index only for md files in dough
-- and for subdirs, where the index must be called index.md

makeIndexForDir debug flags pageFn indexFn dough2 indexSort = do
    -- values title date

    let parentDir =
            makeAbsDir . getParentDir . toFilePath $ pageFn :: Path Abs Dir
    let relDirPath =
            fromJustNote "makeIndexForDir 1 prefix dwerwd"
                $ stripPrefix dough2 parentDir :: Path Rel Dir
    -- this is the addition for the links
    putIOwords
        [ "makeIndexForDir 2"
        , "for "
        , showT pageFn
        , "\n relative root"
        , showT relDirPath
        , "\n sort"
        , showT indexSort
        , "flags"
        , showT flags
        ]

    fs <- getDirContentNonHidden (toFilePath pageFn)
    let fs2 = filter (/= toFilePath indexFn) fs -- exclude index
    let fs3 = filter (hasExtension "md") fs2

    when debug $ putIOwords
        ["makeIndexForDir 3", "for ", showT pageFn, "\n", showT fs3]
    -- fileIxs :: [IndexEntry] <- mapM (\f -> getOneIndexEntry dough2 $ makeAbsFile f) fs3
    fileIxs1 :: [Maybe IndexEntry] <- mapM (getOneIndexEntry flags dough2 . makeAbsFile)
        fs3

    let fileIxs = catMaybes fileIxs1

    let fileIxsSorted = case fmap toLower' indexSort of
            Just "title"       -> sortWith title2 fileIxs
            Just "date"        -> sortWith date2 fileIxs
            Just "reversedate" -> reverse $ sortWith date2 fileIxs
            Just x ->
                errorT ["makeIndexForDir fileIxsSorted", "unknonw parameter", x]
            Nothing -> fileIxs
    unless (null fileIxs) $ do
        -- putIOwords
        --     [ "makeIndexForDir"
        --     , "index for dirs not sorted "
        --     , showT $ map title2 fileIxs
        --     ]
        putIOwords
            [ "makeIndexForDir 4"
            , "index for dirs soit gui &rted "
            , showT $ map title2 fileIxsSorted
            ]

    -- directories
    dirs <- findDirs fs
    when debug $ putIOwords
        ["makeIndexForDir 5", "dirs ", showT pageFn, "\ndirIxs", showT dirs]
    let dirIxs = map oneDirIndexEntry dirs :: [IndexEntry]
    -- format the subdir entries 
    -- needed filename.html title abstract author data
    when debug $ putIOwords
        [ "makeIndexForDir 6"
        , "index for dirs  "
        , showT pageFn
        , "\n"
        , showT dirIxs
        ]
    let dirIxsSorted = sortWith title2 dirIxs
    let dirIxsSorted2 = if not (null dirIxsSorted)
            then dirIxsSorted ++ [zero { title2 = "------" }]
            else []
    let menu1 = MenuEntry { menu2 = dirIxsSorted2 ++ fileIxsSorted }
    when debug $ putIOwords
        ["makeIndexForDir 7", "for ", showT pageFn, "\n", showT menu1]
    let yaml1 = encodeT menu1 -- bb2t . encode $ menu1
    when debug $ putIOwords ["makeIndexForDir 8", "yaml ", yaml1]

    return menu1

oneDirIndexEntry :: Path Abs Dir -> IndexEntry
-- format an entry for a subdir
oneDirIndexEntry dn = zero { text2  = showT dn
                           , link2  = s2t $ nakedName </> ("html" :: FilePath)
                           , title2 = printable <> " (subdirectory)"
                           }
  where
    nakedName = getNakedDir $ dn :: FilePath
                -- getNakedDir . toFilePath $ dn :: FilePath
    printable = s2t nakedName

getOneIndexEntry
    :: PubFlags -> Path Abs Dir -> Path Abs File -> ErrIO (Maybe IndexEntry)
-- fill one entry from one mdfile file
getOneIndexEntry flags dough2 mdfile = do
    (_, metaRec, report) <- checkOneMdFile  mdfile
    putIOwords ["getOneIndexEntry 1", showT flags]
    if checkPubStateWithFlags flags (publicationState metaRec)
        then do

            let parentDir =  makeAbsDir . getParentDir . toFilePath $ mdfile 
                            :: Path Abs Dir
            let relDirPath =
                    fromJustNote "makeIndexForDir prefix dwerwd"
                        $ stripPrefix dough2 parentDir :: Path Rel Dir
            let paths = reverse $ splitPath (toFilePath mdfile)
            let fn    = head paths
            let dir   = toFilePath relDirPath -- head . tail $ paths
            let fnn   = takeBaseName fn
            let ln = s2t $ "/" <> dir </> fnn <.> ("html" :: FilePath)


            let ix = IndexEntry
                    { text2     = s2t fnn
                    , link2     = ln
                    , abstract2 = fromMaybe "" $ abstract metaRec
                    , title2    = fromMaybe ln $ title metaRec
                    , author2   = fromMaybe "" $ author metaRec
                    , date2     = maybe (showT year2000) showT $ date metaRec
                    , publish2  = shownice $ publicationState metaRec
                                    -- default is publish
                    }

            when True $ putIOwords
                [ "getONeIndexEntry 2"
                , "dir"
                , showT mdfile
                , "link"
                , ln
                , "title2"
                , showT $ title2 ix
                , "title originally"
                , fromMaybe ln $ title metaRec
                ]



            return . Just $ ix
        else return Nothing

-- text2publish :: Maybe Text -> PublicationState
-- -- convert a text to a publicationstate
-- text2publish (Nothing) = PSpublish 
-- --  the default is to publish 
-- text2publish (Just tt) = case (toLower' tt) of
--     "true"  -> PSpublish
--     "publish"  -> PSpublish
--     "draft" -> PSdraft
--     "old"   -> PSold
--     _       -> PSzero

checkPubStateWithFlags :: PubFlags -> Maybe PublicationState -> Bool
-- check wether the pubstate corresponds to the flag
checkPubStateWithFlags flags (Just PSpublish) = publishFlag flags
checkPubStateWithFlags flags (Just PSdraft  ) = draftFlag flags
checkPubStateWithFlags flags (Just PSold    ) = oldFlag flags
checkPubStateWithFlags _     (Just PSzero   ) = False
checkPubStateWithFlags flags     Nothing          = publishFlag flags

newtype MenuEntry = MenuEntry {menu2 :: [IndexEntry]} deriving (Generic, Eq, Ord, Show)
instance Zeros MenuEntry where
    zero = MenuEntry zero
instance FromJSON MenuEntry
instance ToJSON MenuEntry

data IndexEntry = IndexEntry {text2 ::  Text  -- ^ naked filename -- not shown
                              , link2 :: Text -- ^ the url relative to dough dir
                              , title2 :: Text -- ^ the title as shown
                              , abstract2 :: Text
                              , author2 :: Text
                              , date2 :: Text -- UTCTime -- read the time early one to find errors
                              , publish2 :: Text

                              } deriving (Generic, Eq, Ord, Show, Read)

instance Zeros IndexEntry where
    zero = IndexEntry zero zero zero zero zero zero zero
--instance FromJSON IndexEntry
instance ToJSON IndexEntry
instance FromJSON IndexEntry where
    parseJSON = genericParseJSON defaultOptions { omitNothingFields = True }

                
-- data PublicationState = PSpublish | PSdraft | PSold | PSzero
--         deriving (Generic,  Show, Read, Ord, Eq)
-- -- ^ is this file ready to publish
-- instance Zeros PublicationState where
--     zero = PSzero
-- instance NiceStrings PublicationState where
--     shownice = drop' 2 . showT

-- instance ToJSON PublicationState
-- instance FromJSON PublicationState
