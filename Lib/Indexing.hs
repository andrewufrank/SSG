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
import           Uniform.Pandoc                 (  getAtKey
        -- DocValue(..)
                        -- , unDocValue
                                                 
                                                )
import           Uniform.Time                   ( year2000 )
import           Lib.CmdLineArgs                ( PubFlags(..) )
import           Lib.CheckInput                 ( MetaRec(..), checkOneMdFile
                                                , PublicationState(..)
                                                , SortArgs (..)
                                                -- , readMeta2rec
                                                -- , checkOneMdFile
                                                )
import Lib.Foundation (SiteLayout)

makeIndex
    :: Bool
    -> SiteLayout 
    -> PubFlags
    -> MetaRec
    -> Path Abs File
    -> Path Abs Dir
    -> ErrIO MenuEntry
-- | make the index text, will be moved into the page template later
-- return zero if not index page
makeIndex debug layout flags metaRec pageFn dough2 = do
    let doindex   = fromMaybe False $  indexPage metaRec
    -- let indexSort1 = indexSort metaRec :: SortArgs
    when debug $ putIOwords ["makeIndex", "doindex", showT doindex]

    ix :: MenuEntry <- if doindex
        then do
            -- let currentDir2 = makeAbsDir $ getParentDir pageFn
            ix2 <- makeIndexForDir debug layout 
                                   flags metaRec
                                   dough2
                                   pageFn

            when debug $ putIOwords ["makeIndex", "index", showT ix2]
            return ix2
        else return zero
    return ix -- (toJSON ix :: Value)


makeIndexForDir
    :: Bool
    -> SiteLayout 
    -> PubFlags
    -> MetaRec
    -> Path Abs Dir
    -> Path Abs File
    -> ErrIO MenuEntry
-- make the index for the directory
-- place result in index.html in this directory
-- the name of the index file is passed to exclude it
-- and from it the directory above (i.e. the one to index) is derived
-- makes index only for md files in dough
-- and for subdirs, where the index must be called index.md

makeIndexForDir debug layout flags metaRec dough2 indexFn  = do
    -- values title date
    let pageFn = makeAbsDir $ getParentDir indexFn :: Path Abs Dir
    fs :: [FilePath] <- getDirContentNonHidden (toFilePath pageFn)
    when debug $ putIOwords
        [ "makeIndexForDir 2"
        , "for " , showT pageFn, "index file", showT indexFn
        -- , "\n relative root"  , showT relDirPath
        , "\n sort", showT (indexSort metaRec) , "flags", showT flags
        , "\nfiles found", unlines' . map showT $ fs 
        ]
    let fs4 = filterIndexForFiles indexFn fs :: [Path Abs File]
    fileIxs1 :: [Maybe IndexEntry] <- 
        mapM (\f -> getOneIndexEntry layout flags metaRec dough2 f ) fs4
        -- braucht lamda
    -- let fileIxs = catMaybes fileIxs1 :: [IndexEntry]
    let fileIxsSorted = sortFileEntries (indexSort metaRec)  fileIxs1
    when debug $ putIOwords
            [ "makeIndexForDir 4"
            , "index for dirs sorted "
            , showT $ map title2 fileIxsSorted
            ]

    dirs <- findDirs fs
    when debug $ putIOwords
        ["makeIndexForDir 5", "dirs ", showT dirs]

    let dirIxs = map formatOneDirIndexEntry dirs :: [IndexEntry]
    -- format the subdir entries
    let dirIxsSorted = sortWith title2 dirIxs

    let dirIxsSorted2 = if not (null dirIxsSorted)
            then dirIxsSorted ++ [zero { title2 = "------" }]
            else []
    let menu1 = MenuEntry { menu2 = dirIxsSorted2 ++ fileIxsSorted }
    when debug $ putIOwords ["makeIndexForDir 8", "menu1", showT menu1]

    return menu1


filterIndexForFiles :: Path Abs File -> [FilePath]-> [Path Abs File]
filterIndexForFiles indexFn fs = fs4
    where 
        fs2 = filter (/= toFilePath  indexFn) fs -- exclude index
        fs3 = filter (hasExtension "md") fs2
        fs4 = map makeAbsFile fs3

sortFileEntries :: SortArgs -> [Maybe IndexEntry] -> [IndexEntry]
sortFileEntries sortArg fileIxsMs = case   sortArg of
            SAtitle       -> sortWith title2 fileIxs
            SAdate        -> sortWith date2 fileIxs
            SAreverseDate -> reverse $ sortWith date2 fileIxs
            SAzero ->     fileIxs --    errorT ["makeIndexForDir fileIxsSorted", showT SAzero]
    where 
        fileIxs = catMaybes fileIxsMs 
 
formatOneDirIndexEntry :: Path Abs Dir -> IndexEntry
-- format an entry for a subdir
formatOneDirIndexEntry dn = zero { text2  = showT dn
                           , link2  = s2t $ nakedName </> ("html" :: FilePath)
                           , title2 = printable <> " (subdirectory)"
                           }
  where
    nakedName = getNakedDir $ dn :: FilePath
                -- getNakedDir . toFilePath $ dn :: FilePath
    printable = s2t nakedName

getOneIndexEntry
    :: SiteLayout -> PubFlags -> MetaRec-> Path Abs Dir -> Path Abs File -> ErrIO (Maybe IndexEntry)
-- fill one entry from one mdfile file
getOneIndexEntry layout flags metaRecBase  dough2 mdfile = do
        (_, metaRec, report) <- checkOneMdFile layout mdfile
        return $ if checkPubStateWithFlags flags (publicationState metaRec)
                    then Just $ getOneIndexEntryPure  metaRec linkName
                    else Nothing
    where 
        linkName = makeRelLink dough2 mdfile

getOneIndexEntryPure ::  MetaRec  -> Text ->  IndexEntry
-- the pure code to compute an IndexEntry
-- Text should be "/Blog/postTufteStyled.html"
getOneIndexEntryPure metaRec linkName =   IndexEntry
                { text2     = s2t . takeBaseName . t2s $ linkName 
                , link2     = linkName
                , abstract2 = fromMaybe "" $ abstract metaRec
                , title2    = fromMaybe linkName $ title metaRec
                , author2   = fromMaybe "" $ author metaRec
                , date2     = maybe (showT year2000) showT $ date metaRec
                , publish2  = shownice $ publicationState metaRec
                }

makeRelLink :: Path Abs Dir -> Path Abs File ->  Text 
-- convert a filepath to a relative link 
makeRelLink dough2 mdfile = s2t . ("/" <>) . toFilePath 
            . setExtension (makeExtensionT "html") . removeExtension $ rel2root
    where 
        rel2root = fromJustNote "makeRelLink 2321cv" $ stripProperPrefixM dough2 mdfile


checkPubStateWithFlags :: PubFlags -> Maybe PublicationState -> Bool
-- check wether the pubstate corresponds to the flag
checkPubStateWithFlags flags (Just PSpublish) = publishFlag flags
checkPubStateWithFlags flags (Just PSdraft  ) = draftFlag flags
checkPubStateWithFlags flags (Just PSold    ) = oldFlag flags
checkPubStateWithFlags _     (Just PSzero   ) = False
checkPubStateWithFlags flags     Nothing          = publishFlag flags

newtype MenuEntry = MenuEntry {menu2 :: [IndexEntry]} deriving (Generic, Eq, Ord, Show)

instance NiceStrings MenuEntry

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


