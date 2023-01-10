%skeleton "lalr1.cc" /* -*- c++ -*- */
%require "3.0"
%defines
//%define parser_class_name {sysyfParser}
%define api.parser.class {sysyfParser}

%define api.token.constructor
%define api.value.type variant
%define parse.assert

%code requires
{
#include <string>
#include "SyntaxTree.h"
class sysyfDriver;
}

// The parsing context.
%param { sysyfDriver& driver }

// Location tracking
%locations
%initial-action
{
// Initialize the initial location.
@$.begin.filename = @$.end.filename = &driver.file;
};

// Enable tracing and verbose errors (which may be wrong!)
%define parse.trace
%define parse.error verbose

// Parser needs to know about the driver:
%code
{
#include "sysyfDriver.h"
#define yylex driver.lexer.yylex
}

// Tokens:
%define api.token.prefix {TOK_}

%token END
%token PLUS MINUS MULTIPLY DIVIDE MODULO ASSIGN
%token GT GTE LT LTE EQ NEQ NOT
%token LAND LOR
%token SEMICOLON COMMA
%token LPARENTHESE RPARENTHESE
%token LBRACE RBRACE
%token LBRACKET RBRACKET
%token INT VOID CONST FLOAT
%token RETURN WHILE BREAK CONTINUE IF ELSE
%token <std::string>IDENTIFIER
%token <int>INTCONST
%token <double>FLOATCONST
%token EOL COMMENT
%token BLANK


// Use variant-based semantic values: %type and %token expect genuine types
%type <SyntaxTree::Assembly*>CompUnit
%type <SyntaxTree::PtrList<SyntaxTree::GlobalDef>>GlobalDecl
%type <SyntaxTree::Type>BType  
%type <SyntaxTree::PtrList<SyntaxTree::VarDef>>VarDecl
%type <SyntaxTree::PtrList<SyntaxTree::VarDef>>VarDefList
%type <SyntaxTree::Ptr<SyntaxTree::VarDef>>VarDef
%type <SyntaxTree::Ptr<SyntaxTree::InitVal>>InitVal
%type <SyntaxTree::PtrList<SyntaxTree::InitVal>>InitValList
%type <SyntaxTree::Ptr<SyntaxTree::FuncDef>>FuncDef
%type <SyntaxTree::Ptr<SyntaxTree::BlockStmt>>Block
%type <SyntaxTree::PtrList<SyntaxTree::Stmt>>BlockItemList
%type <SyntaxTree::PtrList<SyntaxTree::Stmt>>BlockItem
%type <SyntaxTree::Ptr<SyntaxTree::Stmt>>Stmt
%type <SyntaxTree::Ptr<SyntaxTree::LVal>>LVal
%type <SyntaxTree::Ptr<SyntaxTree::Expr>>Exp
%type <SyntaxTree::Literal*>Number
%type <SyntaxTree::PtrList<SyntaxTree::VarDef>>ConstDecl
%type <SyntaxTree::PtrList<SyntaxTree::Expr>>ArrayExpList
%type <SyntaxTree::Ptr<SyntaxTree::FuncFParamList>>FuncFParams
%type <SyntaxTree::Ptr<SyntaxTree::FuncParam>>FuncFParam
%type <SyntaxTree::PtrList<SyntaxTree::FuncParam>>FuncFParamList
%type <SyntaxTree::PtrList<SyntaxTree::Expr>>ArrayParamList
%type <SyntaxTree::PtrList<SyntaxTree::Expr>>FuncRParams
%type <SyntaxTree::Ptr<SyntaxTree::Stmt>>MatchedStmt
%type <SyntaxTree::Ptr<SyntaxTree::Stmt>>UnmatchedStmt


// No %destructors are needed, since memory will be reclaimed by the
// regular destructors.

// Grammar:
%start Begin 

%%
Begin: CompUnit END {
    $1->loc = @$;
    driver.root = $1;
    return 0;
  }
  ;

CompUnit:CompUnit GlobalDecl{
		$1->global_defs.insert($1->global_defs.end(), $2.begin(), $2.end());
		$$=$1;
	} 
	| GlobalDecl{
		$$=new SyntaxTree::Assembly();
		$$->global_defs.insert($$->global_defs.end(), $1.begin(), $1.end());
  }
	;

GlobalDecl:ConstDecl{
    $$=SyntaxTree::PtrList<SyntaxTree::GlobalDef>();
    $$.insert($$.end(), $1.begin(), $1.end());
  }
	| VarDecl{
    $$=SyntaxTree::PtrList<SyntaxTree::GlobalDef>();
    $$.insert($$.end(), $1.begin(), $1.end());
  }
  | FuncDef{
    $$=SyntaxTree::PtrList<SyntaxTree::GlobalDef>();
    $$.push_back(SyntaxTree::Ptr<SyntaxTree::GlobalDef>($1));
  }
	;

BType:INT{
    $$=SyntaxTree::Type::INT;
  }
  | VOID{
    $$=SyntaxTree::Type::VOID;
  }
  | FLOAT{
    $$=SyntaxTree::Type::FLOAT;
  }
  ;

ConstDecl:CONST BType VarDefList SEMICOLON{
    $$=$3;
    for (auto &node : $$) {
      node->btype = $2;
      node->is_constant = true;
    }
  }
  ;

VarDecl:BType VarDefList SEMICOLON{
    $$=$2;
    for (auto &node : $$) {
      node->btype = $1;
      node->is_constant = false;
    }
  }
	;
VarDefList:VarDefList COMMA VarDef{
    $1.push_back(SyntaxTree::Ptr<SyntaxTree::VarDef>($3));
    $$=$1;
  }
	| VarDef{
    $$=SyntaxTree::PtrList<SyntaxTree::VarDef>();
    $$.push_back(SyntaxTree::Ptr<SyntaxTree::VarDef>($1));
  }
	;
VarDef:IDENTIFIER ArrayExpList ASSIGN InitVal{
    $$ = std::shared_ptr<SyntaxTree::VarDef>(new SyntaxTree::VarDef());
    $$->name = $1;
    $$->array_length = $2;
    $$->initializers = $4;
    $$->is_inited = true;
    $$->loc = @$;
  }
  | IDENTIFIER ArrayExpList{
    $$=std::shared_ptr<SyntaxTree::VarDef>(new SyntaxTree::VarDef());
    $$->name=$1;
    $$->array_length = $2;
    $$->is_inited = false;
    $$->loc = @$;
  }
	;

ArrayExpList:ArrayExpList LBRACKET Exp RBRACKET{
    $1.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($3));
    $$=$1;
  }
	| %empty{
    $$=SyntaxTree::PtrList<SyntaxTree::Expr>();
  }
  ;

InitVal: Exp{
    $$ = std::shared_ptr<SyntaxTree::InitVal>(new SyntaxTree::InitVal());
    $$->isExp = true;
    $$->expr = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    $$->loc = @$;
  }
  | LBRACE InitValList RBRACE{
    $$ = std::shared_ptr<SyntaxTree::InitVal>(new SyntaxTree::InitVal());
    $$->isExp = false;
    $$->elementList = $2;
    $$->loc = @$;
  }
  ;
InitValList:InitValList COMMA InitVal{
    $1.push_back(SyntaxTree::Ptr<SyntaxTree::InitVal>($3));
    $$ = $1;
  }
  | InitVal{
    $$ = SyntaxTree::PtrList<SyntaxTree::InitVal>();
    $$.push_back(SyntaxTree::Ptr<SyntaxTree::InitVal>($1));
  }
  | %empty{
    $$ = SyntaxTree::PtrList<SyntaxTree::InitVal>();
  }
	;

FuncDef:BType IDENTIFIER LPARENTHESE FuncFParams RPARENTHESE Block{
    $$ = std::shared_ptr<SyntaxTree::FuncDef>(new SyntaxTree::FuncDef());
    $$->ret_type = $1;
    $$->name = $2;
    $$->param_list = std::shared_ptr<SyntaxTree::FuncFParamList>($4);
    $$->body = SyntaxTree::Ptr<SyntaxTree::BlockStmt>($6);
    $$->loc = @$;
  }
  ;
FuncFParams:FuncFParamList{
  $$ = std::shared_ptr<SyntaxTree::FuncFParamList>(new SyntaxTree::FuncFParamList());
  $$->params = $1;
  }
  ;
FuncFParamList:FuncFParamList COMMA FuncFParam{
    $1.push_back(SyntaxTree::Ptr<SyntaxTree::FuncParam>($3));
    $$ = $1;
  }
  | FuncFParam{
    $$ = SyntaxTree::PtrList<SyntaxTree::FuncParam>();
    $$.push_back(SyntaxTree::Ptr<SyntaxTree::FuncParam>($1));
  }
  | %empty{
    $$ = SyntaxTree::PtrList<SyntaxTree::FuncParam>();
  }
	;
FuncFParam:BType IDENTIFIER{
    $$ = std::shared_ptr<SyntaxTree::FuncParam>(new SyntaxTree::FuncParam());
    $$->param_type=$1;
    $$->name = $2;
  }
  | BType IDENTIFIER ArrayParamList{
    $$ =std::shared_ptr<SyntaxTree::FuncParam>(new SyntaxTree::FuncParam());
    $$->param_type=$1;
    $$->name = $2;
    $$->array_index=$3;
  }
  ;
ArrayParamList:ArrayParamList LBRACKET Exp RBRACKET{
    $1.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($3));
    $$ = $1;
  }
  | LBRACKET RBRACKET{
    $$ = SyntaxTree::PtrList<SyntaxTree::Expr>();
    $$.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>());
  }
  | LBRACKET Exp RBRACKET{
    $$ = SyntaxTree::PtrList<SyntaxTree::Expr>();
    $$.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($2));
  }
  ;

Block:LBRACE BlockItemList RBRACE{
    $$ = std::shared_ptr<SyntaxTree::BlockStmt>(new SyntaxTree::BlockStmt());
    $$->body = $2;
    $$->loc = @$;
  }
  ;
BlockItemList:BlockItemList BlockItem{
    $1.insert($1.end(), $2.begin(), $2.end());
    $$ = $1;
  }
  | %empty{
    $$ = SyntaxTree::PtrList<SyntaxTree::Stmt>();
  }
  ;
BlockItem:VarDecl{
    $$ = SyntaxTree::PtrList<SyntaxTree::Stmt>();
    $$.insert($$.end(), $1.begin(), $1.end());
  }
  | ConstDecl{
    $$ = SyntaxTree::PtrList<SyntaxTree::Stmt>();
    $$.insert($$.end(), $1.begin(), $1.end());
  }
  | Stmt{
    $$ = SyntaxTree::PtrList<SyntaxTree::Stmt>();
    $$.push_back(SyntaxTree::Ptr<SyntaxTree::Stmt>($1));
  }
  ;


//语句
Stmt: MatchedStmt{
    $$ = $1;
  }
  | UnmatchedStmt{
    $$ = $1;
  }
  ;
//if-else匹配
MatchedStmt:IF LPARENTHESE Exp RPARENTHESE MatchedStmt ELSE MatchedStmt{
    auto temp = std::shared_ptr<SyntaxTree::IfStmt>(new SyntaxTree::IfStmt());
    temp->cond_exp = $3;
    temp->if_statement = $5;
    temp->else_statement = $7;
    $$ = std::dynamic_pointer_cast<SyntaxTree::Stmt>(temp);
    $$->loc = @$;
  }
  |
  LVal ASSIGN Exp SEMICOLON{
    auto temp = std::shared_ptr<SyntaxTree::AssignStmt>(new SyntaxTree::AssignStmt());
    temp->target = SyntaxTree::Ptr<SyntaxTree::LVal>($1);
    temp->value = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Stmt>(temp);
    $$->loc = @$;
  }
  | Exp SEMICOLON {
    auto temp = std::shared_ptr<SyntaxTree::ExprStmt>(new SyntaxTree::ExprStmt());
    temp->exp = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Stmt>(temp);
    $$->loc = @$;
  }
  | RETURN Exp SEMICOLON{
    auto temp = std::shared_ptr<SyntaxTree::ReturnStmt>(new SyntaxTree::ReturnStmt());
    temp->ret = $2;
    $$ = std::dynamic_pointer_cast<SyntaxTree::Stmt>(temp);
    $$->loc = @$;
  }
  | RETURN SEMICOLON{
    auto temp = std::shared_ptr<SyntaxTree::ReturnStmt>(new SyntaxTree::ReturnStmt());
    temp->ret = nullptr;
    $$ = std::dynamic_pointer_cast<SyntaxTree::Stmt>(temp);
    $$->loc = @$;
  }
  | BREAK SEMICOLON{
    $$ = std::shared_ptr<SyntaxTree::Stmt>(new SyntaxTree::BreakStmt());
    $$->loc = @$;
  }
  | CONTINUE SEMICOLON{
    $$ = std::shared_ptr<SyntaxTree::Stmt>(new SyntaxTree::ContinueStmt());
    $$->loc = @$;
  }
  | WHILE LPARENTHESE Exp RPARENTHESE MatchedStmt{
    auto temp = std::shared_ptr<SyntaxTree::WhileStmt>(new SyntaxTree::WhileStmt());
    temp->cond_exp = $3;
    temp->statement = $5;
    $$ = std::dynamic_pointer_cast<SyntaxTree::Stmt>(temp);
    $$->loc = @$;
  }
  | Block{
    auto temp=std::shared_ptr<SyntaxTree::BlockStmt>(new SyntaxTree::BlockStmt());
    temp = $1;
    $$ = std::dynamic_pointer_cast<SyntaxTree::Stmt>(temp);
  }
  | SEMICOLON{
    $$ = std::shared_ptr<SyntaxTree::Stmt>(new SyntaxTree::EmptyStmt());
    $$->loc = @$;
  }
  ;

UnmatchedStmt:IF LPARENTHESE Exp RPARENTHESE Stmt{
    auto temp = std::shared_ptr<SyntaxTree::IfStmt>(new SyntaxTree::IfStmt());
    temp->cond_exp = $3;
    temp->if_statement = $5;
    $$ = std::dynamic_pointer_cast<SyntaxTree::Stmt>(temp);
    $$->loc = @$;
  }
  | IF LPARENTHESE Exp RPARENTHESE MatchedStmt ELSE UnmatchedStmt{
    auto temp = std::shared_ptr<SyntaxTree::IfStmt>(new SyntaxTree::IfStmt());
    temp->cond_exp = $3;
    temp->if_statement = $5;
    temp->else_statement = $7;
    $$ = std::dynamic_pointer_cast<SyntaxTree::Stmt>(temp);
    $$->loc = @$;
  }
  ;

FuncRParams:FuncRParams COMMA Exp{
    $1.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($3));
    $$ = $1;
  }
  | Exp{
    $$ = SyntaxTree::PtrList<SyntaxTree::Expr>();
    $$.push_back(SyntaxTree::Ptr<SyntaxTree::Expr>($1));
  }
  | %empty{
    $$ = SyntaxTree::PtrList<SyntaxTree::Expr>();
  }
  ;

LVal:IDENTIFIER ArrayExpList{
    $$ = std::shared_ptr<SyntaxTree::LVal>(new SyntaxTree::LVal());
    $$->name = $1;
    $$->array_index = $2;
    $$->loc = @$;
  }
  ;

%left LOR;
%left LAND;
%left EQ NEQ;
%left GT LT LTE GTE;
%left PLUS MINUS;
%left MULTIPLY DIVIDE MODULO;
%precedence NOT;
%precedence UPLUS UMINUS;
Exp: LPARENTHESE Exp RPARENTHESE{
    $$ = $2;
  }
  | LVal{
    $$ = $1;
  }
  | Number{
    $$ = std::shared_ptr<SyntaxTree::Expr>($1);
  }
  | NOT Exp{
    auto temp = std::shared_ptr<SyntaxTree::UnaryCondExpr>(new SyntaxTree::UnaryCondExpr());
    temp->op = SyntaxTree::UnaryCondOp::NOT;
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($2);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  | PLUS Exp %prec UPLUS{
    auto temp = std::shared_ptr<SyntaxTree::UnaryExpr>(new SyntaxTree::UnaryExpr());
    temp->op = SyntaxTree::UnaryOp::PLUS;
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($2);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  | MINUS Exp %prec UMINUS{
    auto temp = std::shared_ptr<SyntaxTree::UnaryExpr>(new SyntaxTree::UnaryExpr());
    temp->op = SyntaxTree::UnaryOp::MINUS;
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($2);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  | IDENTIFIER LPARENTHESE FuncRParams RPARENTHESE{
    auto temp = std::shared_ptr<SyntaxTree::FuncCallStmt>(new SyntaxTree::FuncCallStmt());
    temp->name = $1;
    temp->params = $3;
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  | Exp PLUS Exp{
    auto temp = std::shared_ptr<SyntaxTree::BinaryExpr>(new SyntaxTree::BinaryExpr());
    temp->op = SyntaxTree::BinOp::PLUS;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  | Exp MINUS Exp{
    auto temp = std::shared_ptr<SyntaxTree::BinaryExpr>(new SyntaxTree::BinaryExpr());
    temp->op = SyntaxTree::BinOp::MINUS;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  | Exp MODULO Exp{
    auto temp = std::shared_ptr<SyntaxTree::BinaryExpr>(new SyntaxTree::BinaryExpr());
    temp->op = SyntaxTree::BinOp::MODULO;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  | Exp MULTIPLY Exp{
    auto temp = std::shared_ptr<SyntaxTree::BinaryExpr>(new SyntaxTree::BinaryExpr());
    temp->op = SyntaxTree::BinOp::MULTIPLY;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  | Exp DIVIDE Exp{
    auto temp = std::shared_ptr<SyntaxTree::BinaryExpr>(new SyntaxTree::BinaryExpr());
    temp->op = SyntaxTree::BinOp::DIVIDE;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  |  Exp LOR Exp{
    auto temp = std::shared_ptr<SyntaxTree::BinaryCondExpr>(new SyntaxTree::BinaryCondExpr());
    temp->op = SyntaxTree::BinaryCondOp::LOR;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  | Exp LAND Exp{
    auto temp = std::shared_ptr<SyntaxTree::BinaryCondExpr>(new SyntaxTree::BinaryCondExpr());
    temp->op = SyntaxTree::BinaryCondOp::LAND;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  | Exp NEQ Exp{
    auto temp = std::shared_ptr<SyntaxTree::BinaryCondExpr>(new SyntaxTree::BinaryCondExpr());
    temp->op = SyntaxTree::BinaryCondOp::NEQ;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  | Exp EQ Exp{
    auto temp = std::shared_ptr<SyntaxTree::BinaryCondExpr>(new SyntaxTree::BinaryCondExpr());
    temp->op = SyntaxTree::BinaryCondOp::EQ;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  | Exp LTE Exp{
    auto temp = std::shared_ptr<SyntaxTree::BinaryCondExpr>(new SyntaxTree::BinaryCondExpr());
    temp->op = SyntaxTree::BinaryCondOp::LTE;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  | Exp LT Exp{
    auto temp = std::shared_ptr<SyntaxTree::BinaryCondExpr>(new SyntaxTree::BinaryCondExpr());
    temp->op = SyntaxTree::BinaryCondOp::LT;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  |Exp GTE Exp{
    auto temp = std::shared_ptr<SyntaxTree::BinaryCondExpr>(new SyntaxTree::BinaryCondExpr());
    temp->op = SyntaxTree::BinaryCondOp::GTE;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  | Exp GT Exp{
    auto temp = std::shared_ptr<SyntaxTree::BinaryCondExpr>(new SyntaxTree::BinaryCondExpr());
    temp->op = SyntaxTree::BinaryCondOp::GT;
    temp->lhs = SyntaxTree::Ptr<SyntaxTree::Expr>($1);
    temp->rhs = SyntaxTree::Ptr<SyntaxTree::Expr>($3);
    $$ = std::dynamic_pointer_cast<SyntaxTree::Expr>(temp);
    $$->loc = @$;
  }
  ;

Number: INTCONST {
    $$ = new SyntaxTree::Literal();
    $$->literal_type = SyntaxTree::Type::INT;
    $$->int_const = $1;
    $$->loc = @$;
  }
  | FLOATCONST {
    $$ = new SyntaxTree::Literal();
    $$->literal_type = SyntaxTree::Type::FLOAT;
    $$->float_const = $1;
    $$->loc = @$;
  }
  ;

%%

void yy::sysyfParser::error (const location_type& l,
                          const std::string& m)
{
    driver.error(l, m);
}
