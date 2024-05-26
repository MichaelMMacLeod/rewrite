module ErrorTypes
  ( ErrorType (..),
    ErrorMessageInfo (..),
    Annotation (..),
    Span (..),
  )
where
import Data.Text (Text)

data ErrorType
  = ParsingError
  | BadEllipsesCount
  | VarsNotCapturedUnderSameEllipsisInConstructor
  | EllipsisAppliedToSymbolInConstructor
  | InvalidRuleDefinition
  | MoreThanOneEllipsisInSingleCompoundTermOfPattern
  | VariableUsedMoreThanOnceInPattern
  | OverlappingPatterns
  deriving (Eq, Show)

data ErrorMessageInfo l = ErrorMessageInfo
  { errorType :: ErrorType,
    message :: Text,
    annotations :: [Annotation l],
    help :: Maybe Text
  }
  deriving (Eq, Show)

data Annotation l = Annotation
  { span :: Span l,
    annotation :: Text
  }
  deriving (Eq, Show)

data Span l = Span
  { location :: l,
    length :: Int
  }
  deriving (Eq, Show)