-- Module copied from Slick

-- i use it because it concentrates all funny pandoc stuff here (including the
-- writing of the json, cannot be imported, because it fixes there the Action monad
-- which i use here as a synonym to ErrIO

{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeSynonymInstances  #-}
{-# LANGUAGE OverloadedStrings     #-}

module Lib.Pandoc
  ( markdownToPandoc, pandocToContentHtml, getMeta, docValToAllVal
  , getMaybeStringAtKey
  , Pandoc, flattenMeta, readMarkdown2, _String, key, (^?)
  )
    where

import Control.Lens ((^?), (?~), (&), at)
import Data.Aeson
import Data.Aeson.Lens
import Data.Aeson(Value(Object))
import qualified Data.Yaml as Y
import  Data.Yaml.Union
import Text.Pandoc as Pandoc
import Text.Pandoc.Highlighting (tango)
--import Text.Pandoc.Shared (stringify)

import Uniform.Filenames hiding (Meta, at)
--import Uniform.Error hiding (Meta, at)
import Uniform.FileIO hiding (Meta, at)
import Lib.FileMgt -- (MarkdownText(..), unMT, HTMLout(..), unHTMLout
--            , unDocValue, DocValue (..) )
import Lib.Indexing
import Lib.BibTex
import Lib.Foundation (settingsFileName)
--import System.Time
import Uniform.Time (getDateAsText)
import Paths_SSG (version)
import Data.Version (showVersion)
import Lib.YamlBlocks (flattenMeta, getMeta, getMaybeStringAtKey
                , putStringAtKey, readMarkdown2, unPandocM)
import Lib.YamlBlocks (readMd2meta, yaml2value, mergeAll, readYaml2value)


-- | Convert markdown text into a 'Value';
-- The 'Value'  has a "content" key containing rendered HTML
-- Metadata is assigned on the respective keys in the 'Value'
-- includes reference replacement (pandoc-citeproc)
-- runs in the pandoc monad!

markdownToPandoc :: Bool -> Path Abs Dir  -> Path Abs File -> ErrIO (Maybe Pandoc)
-- process the markdown (including if necessary the BibTex treatment)
-- the bibliography must be in the metadata
-- the settings are in the markdownText (at end - to let page specific have precedence)
-- questionable if the draft/publish switch should be here
-- or in the creation of the index (where more details from md is needed
markdownToPandoc debug doughP mdfile  = do
    (pandoc, meta2) <- readMd2meta mdfile
--    pandoc   <- readMarkdown2
--    let meta2 = flattenMeta (getMeta pandoc)
    let publish = getMaybeStringAtKey meta2 "publish" :: Maybe Text
    if  isNothing publish || (fmap toLower' publish) == Just "true"
        then do
--            putIOwords ["markdownToPandoc", "publish", showT publish]

            let bib = getMaybeStringAtKey meta2 "bibliography" :: Maybe Text
            let nociteNeeded = getMaybeStringAtKey meta2 "bibliographyGroup" :: Maybe Text
            pandoc2 <- case bib of
                Nothing ->  return pandoc
                Just bibfp -> pandocProcessCites doughP (doughP </> (makeRelFile . t2s $ bibfp))
                            nociteNeeded  pandoc
                            -- here the dir is used for processing in my code

            return . Just $ pandoc2

        else do
                putIOwords ["markdownToPandoc", "NOT PUBLISH", showT publish]
                return Nothing

pandocToContentHtml :: Bool -> Pandoc ->  ErrIO DocValue
-- convert the pandoc to html in the contentHtml key
-- the settings are initially put into the pandoc
pandocToContentHtml debug pandoc2 = do
    text2 <-  writeHtml5String2 pandoc2
    let meta2 = flattenMeta (getMeta pandoc2) :: Value
    let withContent = putStringAtKey  "contentHtml" (unHTMLout text2) meta2
--    ( meta2) & _Object . at "contentHtml" ?~ String (unHTMLout text2)
    return  . DocValue $ withContent

docValToAllVal :: Bool -> DocValue -> Path Abs File -> Path Abs Dir -> Path Abs Dir -> ErrIO DocValue
-- from the docVal of the page
-- get the pageType and the settings (master) values
-- and combine them
-- the current file is only necessary if it is an index file
-- then to determine the current dir
-- and to exclude it from index
docValToAllVal debug docval pageFn dough2 templateP = do
        let mpageType = getMaybeStringAtKey docval "pageTemplate" :: Maybe Text
        when debug $ putIOwords ["docValToAllVal", "mpt", showT mpageType]
        let pageType = makeRelFile . t2s $ fromMaybe "page0default" mpageType  :: Path Rel File
        -- page0default defined in theme

        pageTypeYaml <- readYaml2value  ( templateP </> (pageType))

        settingsYaml <- readYaml2value (dough2 </> settingsFileName)
        --        svalue <- decodeThrow . t2b . unYAML $ settings

        ix <- makeIndex debug docval pageFn dough2

        -- combine all the

        --        let vx =  Y.decodeEither' (t2b . unYAML $ settingsYaml)  :: Either Y.ParseException Value
        --        let vx2 = either (error  . show) id  vx
        --        vsetting ::   Value <-   Y.decodeThrow  (t2b . unYAML $ settingsYaml)
        --
        --        vpt ::   Value <-   Y.decodeThrow  (t2b . unYAML $ pageTypeYaml)
        --        putIOwords ["pandoc settingsYaml", showT settingsYaml
        --                    , "\ndecoded settings:", showT vsetting
        --                    , "\ndecoded vx:", showT vx
        --                    , "\ndecoded pageType:", showT vpt ]

        now <- getDateAsText
        fn2 <- stripProperPrefix' dough2 pageFn
        let bottom = object ["ssgversion" .= (s2t$ showVersion version)
--                    , "today" .= zero -- (s2t "somestring to avoid failures in regression test")
                    , "filename" .= showT fn2
                    ]

        when debug $ do
            putIOwords ["pandoc filename", showT fn2]
            putIOwords ["pandoc settings2.yaml", showT settingsYaml]

        let val = mergeAll [settingsYaml, pageTypeYaml, unDocValue docval, toJSON ix, bottom]

        --        let val = DocValue . fromJustNote "decoded union 2r2e"
        --                      . decodeBytestrings
        --                    $ [ t2b $ unYAML settingsYaml
        --                        , t2b $ unYAML pageTypeYaml
        --                        , bl2b . encode $ unDocValue docval
        --                        , bl2b . encode . toJSON $ ix
        --                       ]  -- last winns!
        -- add the bottom line
        --        callIO $ toCalendarTime =<< getClockTime
--        let val3 = putStringAtKey  "ssgversion" (s2t$ showVersion version) .
--                    putStringAtKey  "today" now $ val
        return val

--unionLastWins :: _ -> _ -> _ -> _ -> Value
--
--unionLastWins o1 o2 o3 o4 =   fromJustNote "decoded union 2r2e"
--                      . decodeBytestrings
--                    $ [ t2b $   o1
--                        , t2b $ o2
--                        , bl2b $ encode o3
--                        , bl2b $ encode o4
--                       ]  -- last winns!

--        , ( "menu"
--          , Array
--              [ Object
--                  (fromList
--                     [ ( "text" , String "Blog" )
--                     , ( "link" , String "/Blog/index.html" )
--                     ])
--              , Object
--                  (fromList
--                     [ ( "text" , String "Publications" )
--                     , ( "link" , String "/PublicationList/index.html" )
--                     ])
--              ]
--          )


-- | Reasonable options for rendering to HTML
html5Options :: WriterOptions
html5Options = def { writerHighlightStyle = Just tango
                   , writerExtensions     = writerExtensions def
                   }


writeHtml5String2 :: Pandoc -> ErrIO HTMLout
writeHtml5String2 pandocRes = do
    p <-  unPandocM $ writeHtml5String html5Options pandocRes
    return . HTMLout $ p

