{-# LANGUAGE UndecidableInstances #-}

module Blumon.Monad.Gamma.Linear (
  GammaLinearT
, runGammaLinearT
, Time (..)
, Hour
, Minute
, (==>)
, N.NonEmpty (..) -- TODO: keep here?
) where

import Control.Monad.Base
import Control.Monad.Except
import Control.Monad.Reader
import Control.Monad.Trans.Control
import qualified Data.Finite as F
import qualified Data.List.NonEmpty as N
import qualified Data.Map as M
import Data.Maybe (fromJust)
import qualified Data.Ratio as R
import Data.Time
import GHC.Generics

import Blumon.Monad.Gamma
import Blumon.RGB

newtype GammaLinearT m a = GammaLinearT { unGammaLinearT :: ReaderT (M.Map TimeOfDay Trichromaticity) m a }
  deriving (Applicative, Functor, Monad, MonadBase b, MonadBaseControl b, MonadTrans, MonadTransControl)

instance MonadBase IO m => MonadGamma (GammaLinearT m) where
  gamma = do time <- localTimeOfDay . zonedTimeToLocalTime <$> liftBase getZonedTime
             calculateGamma time

calculateGamma :: Monad m => TimeOfDay -> GammaLinearT m Trichromaticity
calculateGamma time = do
  m <- GammaLinearT ask
  return . fromJust $ do
    (nextTime , nextGamma) <- catchError (M.lookupGT time m) $
                                \ () -> M.lookupMin m
    (prevTime , prevGamma) <- catchError (M.lookupLE time m) $
                                \ () -> M.lookupMax m
    let timeFraction = diffTimeOfDayToPicoseconds time prevTime R.% diffTimeOfDayToPicoseconds nextTime prevTime
    return $ weightedAverage' timeFraction prevGamma nextGamma

diffTimeOfDayToPicoseconds :: TimeOfDay -> TimeOfDay -> Integer
diffTimeOfDayToPicoseconds t1 t2 = diffTimeToPicoseconds $ sinceMidnight t1 - sinceMidnight t2

weightedAverage :: R.Ratio Integer -> Chromaticity -> Chromaticity -> Chromaticity
weightedAverage w c1 c2 = round c
  where c = fromIntegral c1 + w * (fromIntegral c2 - fromIntegral c1)

weightedAverage' :: R.Ratio Integer -> Trichromaticity -> Trichromaticity -> Trichromaticity
weightedAverage' w c1 c2 = Trichromaticity { red = weightedAverage w (red c1) (red c2)
                                           , green = weightedAverage w (green c1) (green c2)
                                           , blue = weightedAverage w (blue c1) (blue c2)
                                           }

instance MonadReader r m => MonadReader r (GammaLinearT m) where
  ask = lift ask
  local f tma = liftWith $ \ run ->
    local f $ run tma

runGammaLinearT' :: M.Map TimeOfDay Trichromaticity -> GammaLinearT m a -> m a
runGammaLinearT' rgbs tma = runReaderT (unGammaLinearT tma) rgbs

runGammaLinearT :: N.NonEmpty (TimeOfDay,Trichromaticity) -> GammaLinearT m a -> m a
runGammaLinearT rgbs = runGammaLinearT' $ M.fromList . N.toList $ rgbs

newtype Hour = Hour { unHour :: F.Finite 24 }
  deriving (Bounded, Enum, Eq, Generic, Num, Ord, Read, Real, Show)

newtype Minute = Minute { unMinute :: F.Finite 60 }
  deriving (Bounded, Enum, Eq, Generic, Num, Ord, Read, Real, Show)

infix 7 :.
data Time = Hour :. Minute
  deriving (Bounded, Eq, Generic, Ord, Read, Show)

infix 6 ==>
(==>) :: Time -> Trichromaticity -> (TimeOfDay,Trichromaticity)
(==>) (h :. m) c = (time,c)
  where time = TimeOfDay { todHour = fromIntegral $ unHour h
                         , todMin = fromIntegral $ unMinute m
                         , todSec = 0
                         }
