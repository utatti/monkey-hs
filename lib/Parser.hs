module Parser where

import Protolude hiding (one, many, optional)

import           Common.ParserT
import qualified Lexer.Token as Tk
import           Parser.AST
import           Parser.Types
import           Utils ((<<))

parseProgram :: Parser Program
parseProgram = Program <$> many parseStmt

parseStmt :: Parser Stmt
parseStmt = choose
  [ parseLetStmt
  , parseReturnStmt
  , parseExprStmt
  ]

parseIdent :: Parser Ident
parseIdent = next >>= go
  where
  go (Tk.Ident name) = return $ Ident name
  go _ = fail "fail to parse an identifier"

parseLetStmt :: Parser Stmt
parseLetStmt = do
  atom Tk.Let
  ident <- parseIdent
  atom Tk.Assign
  expr <- parseExpr
  atom Tk.SemiColon
  return $ LetStmt ident expr

parseReturnStmt :: Parser Stmt
parseReturnStmt = do
  atom Tk.Return
  expr <- parseExpr
  atom Tk.SemiColon
  return $ ReturnStmt expr

parseExprStmt :: Parser Stmt
parseExprStmt = ExprStmt <$> do
  expr <- parseExpr
  optional $ atom Tk.SemiColon
  return expr

infixOp :: Tk.Token -> (Precedence, Maybe Infix)
infixOp Tk.Eq = (PEquals, Just Eq)
infixOp Tk.NotEq = (PEquals, Just NotEq)
infixOp Tk.LessThan = (PLessGreater, Just LessThan)
infixOp Tk.GreaterThan = (PLessGreater, Just GreaterThan)
infixOp Tk.Plus = (PSum, Just Plus)
infixOp Tk.Minus = (PSum, Just Minus)
infixOp Tk.Multiply = (PProduct, Just Multiply)
infixOp Tk.Divide = (PProduct, Just Divide)
infixOp _ = (PLowest, Nothing)

parseAtomExpr :: Parser Expr
parseAtomExpr = choose [ parseLitExpr
                       , parseIdentExpr
                       , parseParenExpr
                       ]

parseParenExpr :: Parser Expr
parseParenExpr = do
  atom Tk.LParen
  expr <- parseExpr
  atom Tk.RParen
  return expr

parseLiteral :: Parser Literal
parseLiteral = next >>= go
  where
  go (Tk.IntLiteral i) = return $ IntLiteral i
  go (Tk.BoolLiteral b) = return $ BoolLiteral b
  go _ = fail "fail to parse a literal"

parseExpr :: Parser Expr
parseExpr = parsePrattExpr PLowest

parsePrattExpr :: Precedence -> Parser Expr
parsePrattExpr precedence = do
  left <- choose [ parsePrefixExpr, parseAtomExpr ]
  go precedence left
  where
  go :: Precedence -> Expr -> Parser Expr
  go precedence left = do
    maybePeekInfixOp <- map infixOp <$> preview
    case maybePeekInfixOp of
      Just (peekPrecedence, _) | precedence < peekPrecedence -> do
        left' <- parseInfixExpr left
        go precedence left'
      _ -> return left

parsePrefixExpr :: Parser Expr
parsePrefixExpr = do
  tkn <- choose [atom Tk.Plus, atom Tk.Minus, atom Tk.Not]
  case tkn of
    Tk.Plus -> PrefixExpr PrefixPlus <$> parseAtomExpr
    Tk.Minus -> PrefixExpr PrefixMinus <$> parseAtomExpr
    Tk.Not -> PrefixExpr Not <$> parseAtomExpr
    _ -> fail "fail to parse a prefix expr"

parseInfixExpr :: Expr -> Parser Expr
parseInfixExpr left = do
  (precedence, maybeOp) <- infixOp <$> next
  case maybeOp of
    Nothing -> fail "not infix expr"
    Just op -> do
      right <- parsePrattExpr precedence
      return $ InfixExpr op left right

parseLitExpr :: Parser Expr
parseLitExpr = LitExpr <$> parseLiteral

parseIdentExpr :: Parser Expr
parseIdentExpr = IdentExpr <$> parseIdent

finish :: Parser ()
finish = next >>= go
  where
  go Tk.EOF = return ()
  go tkn = fail $ "unexpected token: " ++ show tkn

parse :: [Tk.Token] -> Program
parse = execParser (parseProgram << finish)