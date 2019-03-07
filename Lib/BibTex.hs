-----------------------------------------------------------------------------
--
-- Module      : reading bibtex and producing the list for nocite
-----------------------------------------------------------------------------
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeSynonymInstances  #-}
{-# LANGUAGE OverloadedStrings     #-}


module Lib.BibTex  -- (openMain, htf_thisModuelsTests)
     where

import Uniform.Strings
import Uniform.Error
import Uniform.FileIO

import Text.BibTeX.Parse
import Text.BibTeX.Entry as T
import qualified Text.BibTeX.Parse as Parse
import qualified Text.BibTeX.Entry as Entry
--import qualified Text.ParserCombinators.Parsec as Parsec

--import qualified Data.Char as Char
--import System.IO (hPutStrLn, stderr, )
import Lib.FileMgt (MarkdownText(..), unMT, HTMLout(..), unHTMLout
            , unDocValue, DocValue (..) )
import Text.Pandoc (Pandoc)
import qualified Text.Pandoc   as P
import qualified Text.Pandoc.Definition   as PD
import qualified Text.Pandoc.Builder   as PB
import Text.CSL.Pandoc (processCites')
import System.Directory (setCurrentDirectory, getCurrentDirectory)
import Lib.YamlBlocks (flattenMeta, getMeta, putMeta, getMaybeStringAtKey
                , putStringAtKey, readMarkdown2, unPandocM)
import qualified Data.Map as M

{-
, MetaBlocks
                   [ Plain
                       [ Cite
                           [ Citation
                               { citationId = "frank-machbarkeit"
                               , citationPrefix = []
                               , citationSuffix = []
                               , citationMode = AuthorInText
                               , citationNoteNum = 0
                               , citationHash = 0
                               }
                           ]
                           [ Str "@frank-machbarkeit" ]
                       , Space
                       , Cite
                           [ Citation
                               { citationId = "frank09geo"
                               , citationPrefix = []
                               , citationSuffix = []
                               , citationMode = AuthorInText
                               , citationNoteNum = 0
                               , citationHash = 0
                               }
                           ]
                           [ Str "@frank09geo" ]
                       , Space
                       , Cite
                           [ Citation
                               { citationId = "Frank2010a"
                               , citationPrefix = []
                               , citationSuffix = [ Str "TUxx9999" ]
                               , citationMode = AuthorInText
                               , citationNoteNum = 0
                               , citationHash = 0
                               }
                           ]
                           [ Str "@Frank2010a" , Space , Str "[TUxx9999]" ]
                       ]
                   ]
               )
-}
fillCitation citID = PD.Citation {PD.citationId = t2s citID, PD.citationPrefix=zero, PD.citationSuffix=zero
                                    ,PD.citationMode=PD.AuthorInText
                                    , PD.citationNoteNum= zero, PD.citationHash=zero}
fillCitation :: Text -> PD.Citation

pandocProcessCites :: Path Abs Dir -> Path Abs File  -> Maybe Text->  Pandoc -> ErrIO Pandoc
-- process the citations
-- including the filling the references for publication lists
pandocProcessCites doughP biblio groupname  pandoc1 = do
    pandoc2 <- case groupname of
        Nothing -> return pandoc1
        Just gn -> do
                    bibids <- bibIdentifierFromBibTex biblio (t2s gn)
                    let cits = map (\s -> [fillCitation . s2t $ s]) bibids :: [[PD.Citation]]
                    let refs = map (\s -> [PD.Str ("@" <> s)]) bibids :: [[PD.Inline]]
                    let cites = zipWith PD.Cite cits refs  :: [PD.Inline]
                    let metablocks = PD.MetaBlocks [PD.Plain cites]
                    let map1 = M.insert "nocite" metablocks M.empty
                    let meta2 = getMeta $ pandoc1 :: P.Meta
                    let meta3 = meta2 <> P.Meta map1
                    let pandoc2 = putMeta meta3 pandoc1
                    return pandoc2
--    callIO $ do
    currDir <- currentDir
    -- the current dir is the directory in which the procCites of pando will
    -- search.

--            putIOwords ["markdownToPandoc", "currDir", showT currDir, "\ndoughP", showT doughP]
--            putIOwords ["markdownToPandoc", "bibfp", showT bib]
    setCurrentDir   doughP
    res <- callIO $ processCites'  pandoc2
    setCurrentDir currDir
--            putIOwords ["markdownToPandoc", "again currDir", showT currDir, "\nwas doughP", showT doughP]
    return res


readBibTex :: FilePath ->  IO String
-- reads the bibtex file
readBibTex fp = do
    --      bib <- getContents
    bib <- readFile fp
--    putIOwords ["readBibTex", showT bib]
    return bib

parseBibTex :: String -> IO [Entry.T]
parseBibTex bib = case  parse (skippingLeadingSpace   Parse.file) "stdin" bib of
--parseBibTex bib = case Parsec.parse (Parsec.skipMany Parsec.space >> Parse.file) "stdin" bib of
         Left errMsg -> error  (show errMsg)
         Right entries -> return entries

filterByGroup :: String -> [Entry.T] -> [Entry.T]
 -- select the entries in a group
filterByGroup groupname entries = filter (elem groupname .getGroup) entries

getGroup :: Entry.T -> [String]
getGroup e = map snd groupFields
    where
        fs = fields e  :: [(String, String)]
        groupFields = filter (("groups" ==).fst) fs

getBibIdentifier :: [Entry.T] -> [String]
-- extract the bib identifier from the entries
--getBibIdentifier es = map T.entryType es
getBibIdentifier es = map T.identifier es

bibIdentifierFromBibTex :: Path Abs File -> String -> ErrIO [String]
-- combine the process
bibIdentifierFromBibTex bibfn group = callIO $
    do
        bib <- readBibTex (toFilePath bibfn)
        entries <- parseBibTex bib
        let es = filterByGroup group entries
            ids = getBibIdentifier es
        return ids


--typeTable :: [((String, Maybe String), String)]
--typeTable =
--   (("article", Just "reviewed"), "reviewedjournal") :
--   (("article", Just "popular"), "popular") :
--   (("article", Nothing), "journal") :
--   (("inproceedings", Just "reviewed"), "reviewedconference") :
--   (("inproceedings", Nothing), "conference") :
--   (("techreport", Nothing), "techreport") :
--   (("inbook", Just "program"), "program") :
--   (("misc", Just "program"), "program") :
--   (("misc", Just "talk"), "talk") :
--   (("mastersthesis", Nothing), "thesis") :
--   (("phdthesis", Nothing), "thesis") :
--   []
--
--
--cite :: Entry.T -> String
--cite entry =
--   maybe
--      "% \\nocite"
--      ("\\nocite" ++ )
--      (lookup
--          (map Char.toLower (Entry.entryType entry),
--           lookup "subtype" (Entry.fields (Entry.lowerCaseFieldNames entry)))
--          typeTable) ++
--   "{" ++ Entry.identifier entry ++ "}"
--




