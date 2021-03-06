-----------------------------------------------------------------------------
--
-- Module      :   a test for HTF framework
-- insert {-@ HTF_TESTS @-} for each import
-----------------------------------------------------------------------------
{-# OPTIONS_GHC -F -pgmF htfpp #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables   #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE TypeSynonymInstances  #-}
{-# LANGUAGE OverloadedStrings     #-}
{-# OPTIONS -fno-warn-missing-signatures -fno-warn-orphans #-}

module Lib.Pandoc_test  -- (openMain, htf_thisModuelsTests)
     where

import           Test.Framework
import Uniform.Test.TestHarness
import Lib.Foundation (progName, SiteLayout(..), templatesDirName)
-- import Lib.FileMgt
--import Lib.YamlBlocks (readMd2meta)
import Lib.Pandoc
import Uniform.Pandoc
import Lib.Foundation_test (testLayout)
import Lib.CmdLineArgs (allFlags)

--import Text.Pandoc.Definition as PD

readMarkdownFile8 :: String  -> ErrIO MarkdownText
readMarkdownFile8 fnn =  read8   (makeAbsFile fnn) markdownFileType
---- uses files to be copied to dough
----
test_pandoc_pageFn_pageMd_1, test_pandoc_pageFn_pageMd_2 :: IO ()
test_pandoc_pageFn_pageMd_1 = test1FileIO progName  "pageFn1" "pageMd1" readMarkdownFile8
test_pandoc_pageFn_pageMd_2 = test1FileIO progName  "pageFn2" "pageMd2" readMarkdownFile8
test_pandoc_pageFn_pageMd_3 = test1FileIO progName  "pageFn3" "pageMd3" readMarkdownFile8
test_pandoc_pageFn_pageMd_4 = test1FileIO progName  "pageFn4" "pageMd4" readMarkdownFile8
test_pandoc_pageFn_pageMd_5 = test1FileIO progName  "pageFn5" "pageMd5" readMarkdownFile8
test_pandoc_pageFn_pageMd_6 = test1FileIO progName  "pageFn6" "pageMd6" readMarkdownFile8

doughP = doughDir testLayout
--markdownToPandoX :: MarkdownText -> ErrIO (Maybe Pandoc)
--markdownToPandoX = markdownToPandoc False doughP
--
--test_pandoc_11_A_D, test_pandoc_12_A_D :: IO ()
--test_pandoc_11_A_D = test1FileIO progName  "pageMd1" "resultAD1" markdownToPandoX
--test_pandoc_12_A_D = test1FileIO progName  "pageMd2" "resultAD2" markdownToPandoX
--test_pandoc_13_A_D = test1FileIO progName  "pageMd3" "resultAD3" markdownToPandoX
--            -- 13 fails
---- "/home/frank/Workspace8/ssg/site/dough/site/dough/resources/BibTexLatex.bib: openFile: does not exist (No such file or directory)"

markdownToPandoX :: String  -> ErrIO (Maybe Pandoc)
markdownToPandoX s = markdownToPandoc False allFlags doughP (makeAbsFile s)

test_pandoc_11_A_D, test_pandoc_12_A_D :: IO ()
test_pandoc_11_A_D = test1FileIO progName  "pageFn1" "resultAD1" markdownToPandoX
test_pandoc_12_A_D = test1FileIO progName  "pageFn2" "resultAD2" markdownToPandoX
test_pandoc_13_A_D = test1FileIO progName  "pageFn3" "resultAD3" markdownToPandoX
test_pandoc_14_A_D = test1FileIO progName  "pageFn4" "resultAD4" markdownToPandoX
test_pandoc_15_A_D = test1FileIO progName  "pageFn5" "resultAD5" markdownToPandoX
test_pandoc_16_A_D = test1FileIO progName  "pageFn6" "resultAD6" markdownToPandoX
            -- 13 fails
-- "/home/frank/Workspace8/ssg/site/dough/site/dough/resources/BibTexLatex.bib: openFile: does not exist (No such file or directory)"

pandocToContentHtmlX :: Maybe Pandoc -> ErrIO DocValue
pandocToContentHtmlX mp = pandocToContentHtml False (fromJustNote "fwerw" mp)
--
test_pandoc_11_A_F, test_pandoc_12_A_F :: IO ()
test_pandoc_11_A_F = test1FileIO progName  "resultAD1" "resultAF1" pandocToContentHtmlX
test_pandoc_12_A_F = test1FileIO progName  "resultAD2" "resultAF2" pandocToContentHtmlX
test_pandoc_13_A_F = test1FileIO progName  "resultAD3" "resultAF3" pandocToContentHtmlX
test_pandoc_14_A_F = test1FileIO progName  "resultAD4" "resultAF4" pandocToContentHtmlX
test_pandoc_15_A_F = test1FileIO progName  "resultAD5" "resultAF5" pandocToContentHtmlX
test_pandoc_16_A_F = test1FileIO progName  "resultAD6" "resultAF6" pandocToContentHtmlX
--
docVal2 :: DocValue -> String -> ErrIO DocValue
docVal2 docval pagefn = docValToAllVal False allFlags docval (makeAbsFile pagefn)
                (doughDir testLayout) (themeDir testLayout </> templatesDirName)

test_pandoc_11_F_G, test_pandoc_12_F_G :: IO ()
test_pandoc_11_F_G = test2FileIO progName  "resultAF1" "pageFn1" "resultAG1" docVal2
test_pandoc_12_F_G = test2FileIO progName  "resultAF2" "pageFn2" "resultAG2" docVal2
test_pandoc_13_F_G = test2FileIO progName  "resultAF3" "pageFn3" "resultAG3" docVal2
test_pandoc_14_F_G = test2FileIO progName  "resultAF4" "pageFn4" "resultAG4" docVal2
test_pandoc_15_F_G = test2FileIO progName  "resultAF5" "pageFn5" "resultAG5" docVal2
test_pandoc_16_F_G = test2FileIO progName  "resultAF6" "pageFn6" "resultAG6" docVal2

--instance Zeros Pandoc where zero = Pandoc mempty zero
----instance Zeros PD.Meta where zero = PD.Meta []
--
--markdownToHTML5xdebug ::  MarkdownText -> ErrIO DocValue
--
--markdownToHTML5xdebug intext = do
--    pandoc <- markdownToPandoc False intext
--    pandocToContentHtml False pandoc
--
--test_pandoc_11_B_E, test_pandoc_12_B_E :: IO ()
--test_pandoc_11_B_E = test1FileIO progName   "resultB1" "resultBE1"  markdownToHTML4xdebug
--test_pandoc_12_B_E = test1FileIO progName   "resultB2" "resultBE2" markdownToHTML4xdebug


instance  ShowTestHarness MarkdownText where

instance  ShowTestHarness DocValue where
instance  ShowTestHarness (Maybe Pandoc) where
