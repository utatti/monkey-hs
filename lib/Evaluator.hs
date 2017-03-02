module Evaluator where

import Protolude

import Data.List (last)
import Evaluator.Object
import Evaluator.Types
import Parser.AST

evalProgram :: Program -> Evaluator Object
evalProgram (Program stmts) = last <$> traverse evalStmt stmts

evalStmt :: Stmt -> Evaluator Object
evalStmt (ExprStmt expr) = evalExpr expr
evalStmt _ = undefined

evalExpr :: Expr -> Evaluator Object
evalExpr (LitExpr l) = evalLiteral l
evalExpr (PrefixExpr p e) = evalPrefix p e
evalExpr _ = undefined

evalLiteral :: Literal -> Evaluator Object
evalLiteral (IntLiteral i) = return $ OInt i
evalLiteral (BoolLiteral b) = return $ OBool b

evalPrefix :: Prefix -> Expr -> Evaluator Object
evalPrefix Not = fmap (OBool . not) . (evalExpr >=> o2b)
evalPrefix PrefixPlus = fmap OInt . (evalExpr >=> o2n)
evalPrefix PrefixMinus = fmap (OInt . negate) . (evalExpr >=> o2n)

o2b :: Object -> Evaluator Bool
o2b (OBool b) = return b
o2b o = throwError . EvalError $ show o <> " is not a bool"

o2n :: Object -> Evaluator Integer
o2n (OInt i) = return i
o2n o = throwError . EvalError $ show o <> " is not a number"

eval :: Program -> Either EvalError Object
eval = execEvaluator . evalProgram