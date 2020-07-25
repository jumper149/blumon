module Main where

import Blumon
import Blumon.Monad.Gamma.Linear
import Blumon.Monad.Recolor.Print

main :: IO ()
main = loopRecolor def $ runGammaLinearT rgbMap . runRecolorPrintT . fmap Right
  where rgbMap = 00:.00 ==> Trichromaticity { red = 255, green = 255, blue = 255 }
            :| [ 12:.00 ==> Trichromaticity { red = 200, green = 250, blue = 150 }
               ]
