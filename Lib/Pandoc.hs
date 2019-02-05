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
--  ( markdownToPandoc, pandocToContentHtml, getMeta
--  , Pandoc, flattenMeta, readMarkdown2, _String, key, (^?)
--  )
    where

import Control.Lens ((^?), (?~), (&), at)
import Data.Aeson
import Data.Aeson.Lens
import Text.Pandoc as Pandoc
import Text.Pandoc.Highlighting
import Text.Pandoc.Shared
import Text.CSL.Pandoc (processCites')
import System.Process  as System (readProcess)

import Uniform.Error hiding (Meta, at)
import Lib.FileMgt (MarkdownText(..), unMT, HTMLout(..), unHTMLout
            , unDocValue, DocValue (..) )



-- | Convert markdown text into a 'Value';
-- The 'Value'  has a "content" key containing rendered HTML
-- Metadata is assigned on the respective keys in the 'Value'
-- includes reference replacement (pandoc-citeproc)
-- runs in the pandoc monad!

markdownToPandoc :: Bool -> MarkdownText -> ErrIO Pandoc
-- process the markdown (including if necessary the BibTex treatment)
-- the bibliography must be in the metadata
-- the settings are in the markdownText (at end - to let page specific have precedence)
markdownToPandoc debug (MarkdownText t)  = do
    pandoc   <- readMarkdown2   t
    let meta2 = flattenMeta (getMeta pandoc)

    -- test if biblio is present and apply
    let bib = getMaybeStringAtKey meta2 "bibliography"
--    let bib = fmap t2s $  ( meta2) ^? key "bibliography" . _String :: Maybe FilePath

    pandoc2 <- case bib of
        Nothing ->  return pandoc
        Just _ ->   callIO $ processCites'  pandoc

    return pandoc2

pandocToContentHtml :: Bool -> Pandoc ->  ErrIO DocValue
-- convert the pandoc to html in the contentHtml key
-- the settings are initially put into the pandoc
pandocToContentHtml debug pandoc2 = do
    text2 <-  writeHtml5String2 pandoc2
    let meta2 = flattenMeta (getMeta pandoc2) :: Value
    let withContent = putStringAtKey meta2 "contentHthml" (unHTMLout text2)
--    ( meta2) & _Object . at "contentHtml" ?~ String (unHTMLout text2)
    return  . DocValue $ withContent


-- | Reasonable options for reading a markdown file
markdownOptions :: ReaderOptions
markdownOptions = def { readerExtensions = exts }
 where
  exts = mconcat
    [ extensionsFromList
      [ Ext_yaml_metadata_block
      , Ext_fenced_code_attributes
      , Ext_auto_identifiers
      ,  Ext_raw_html   -- three extension give markdown_strict
      , Ext_shortcut_reference_links
      , Ext_spaced_reference_links
      , Ext_citations           -- <-- this is the important extension for bibTex
      ]
    , githubMarkdownExtensions
    ]


-- | Reasonable options for rendering to HTML
html5Options :: WriterOptions
html5Options = def { writerHighlightStyle = Just tango
                   , writerExtensions     = writerExtensions def
                   }

-- | Handle possible pandoc failure within the Action Monad
unPandocM :: PandocIO a -> ErrIO a
unPandocM op1 = do
        res   <- callIO $ runIO (do  -- liftIO $putStrLn "unPandocM op"
                                     a <- op1 --       error "xx"
                                     -- liftIO $putStrLn "error xx"
                                     return a)
        either (\e -> do
                        putIOwords ["unPandocM error", showT e ]
                        throwError . showT $ e
                ) return res
     `catchError` (\e -> do
                        putIOwords ["unPandocM catchError", showT e ]
                        throwError . showT $  e)



getMeta :: Pandoc -> Meta
getMeta (Pandoc m _) = m

class AtKey v where
    getMaybeStringAtKey :: v -> Text -> Maybe FilePath
    putStringAtKey :: v -> Text -> Text -> v
instance AtKey Value where
    getMaybeStringAtKey meta2 k2 = fmap t2s $ meta2 ^? key k2 . _String

--instance AsValue Meta
--instance AsPrimitive Meta
--instance AsNumber Meta

    putStringAtKey meta2 k2 txt = meta2 & _Object . at k2 ?~ String txt
--        (unHTMLout text2)

instance AtKey DocValue  where
    getMaybeStringAtKey meta2 k2 = getMaybeStringAtKey (unDocValue meta2) k2

--instance AsValue Meta
--instance AsPrimitive Meta
--instance AsNumber Meta

    putStringAtKey meta2 k2 txt = DocValue $ (unDocValue meta2) & _Object . at k2 ?~ String txt



readMarkdown2 :: Text -> ErrIO Pandoc
readMarkdown2 text1 =  unPandocM $ readMarkdown markdownOptions text1

writeHtml5String2 :: Pandoc -> ErrIO HTMLout
writeHtml5String2 pandocRes = do
    p <-  unPandocM $ writeHtml5String html5Options pandocRes
    return . HTMLout $ p


-- | Flatten a Pandoc 'Meta' into a well-structured JSON object, rendering Pandoc
-- text objects into plain strings along the way.
flattenMeta :: Meta -> Value
flattenMeta (Meta meta) = toJSON $ fmap go meta
 where
  go :: MetaValue -> Value
  go (MetaMap     m) = toJSON $ fmap go m
  go (MetaList    m) = toJSONList $ fmap go m
  go (MetaBool    m) = toJSON m
  go (MetaString  m) = toJSON m
  go (MetaInlines m) = toJSON $ stringify m
  go (MetaBlocks  m) = toJSON $ stringify m
