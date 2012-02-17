# xl-pcl - PCL CLOS implementation for xyzzy Lisp.

## DESCRIPTION

xl-pcl は [PCL] (Portable Common Loops) を xyzzy に移植したものになる予定の何かです。

[PCL] はポータブルな CLOS の実装らしいです。

  [PCL]: http://www.cs.cmu.edu/afs/cs/project/ai-repository/ai/lang/lisp/oop/clos/pcl/0.html

現状はまったく動いていないので過度な期待はしないように。

----

## 移植状況

完了した部分は以下のとおり。

  * 他の処理系用のコードなど不要なファイルの除去
  * xyzzy で動くようにいろいろ修正
    - 構造体の print-function は defstruct の前に定義されていないとダメとか
    - (declare) があるとまずい部分の削除
    - in-package が古い書き方だったので修正
    - 0d0104db949a1478f7d34074cf77db1bc2012a02
  * 処理系依存部分で xyzzy 用の実装を追加 (後述)
    - 34cd45933890e10f0205ac922dff2d4d867abaeb
  * SBCL から循環参照を検出するコードを移植
    - 6380b443ea9183387a48c597ebc299ed2f7caed5
    - http://sbcl.git.sourceforge.net/git/gitweb.cgi?p=sbcl/sbcl.git;a=commit;h=310d5f86d736ecf9525711b087b04797c549879c

これでバイト・コンパイルまでは出来るようになったと思うが、
braid.l のロード中に循環参照があって無限再帰してしまう。

現状は SBCL から循環参照を検出するコードをもってきたのでスタックオーバーフローにはならないが
ロードできない。

あと、ロード中に xyzzy がクラッシュすることがよくあります。

```lisp
user> (require "xl-pcl/defsys")
t

user> (pcl::compile-pcl)
Loading binary of pkg...
Loading binary of walk...
Loading binary of iterate...
Loading binary of macros...
Loading binary of low...
Loading binary of xyzzy-low...
Loading binary of fin...
Loading binary of defclass...
Loading binary of defs...
Loading binary of fngen...
Loading binary of cache...
Loading binary of dlisp...
Loading binary of dlisp2...
Loading binary of boot...
Loading binary of vector...
Loading binary of slots-boot...
Loading binary of combin...
Loading binary of dfun...
Loading binary of fast-init...
Loading binary of braid...
vicious metacircle:  The computation of an effective method of #<lexical-closure: (anonymous)> for
arguments of types (#117=#S(xl-pcl::std-instance wrapper ...) uses the effective method being computed.
```

SBCL から循環参照まわりの修正をいろいろ持ってきたけど直らなくて挫折気味。

オリジナルの PCL をなんとか直すか、
他の処理系の PCL (いろいろ直っているだろうけど、処理系依存のコードがたっぷり) を直すのが速いか、
closette で妥協するか。。。

  * [SBCL](http://sbcl.git.sourceforge.net/git/gitweb.cgi?p=sbcl/sbcl.git;a=tree;f=src/pcl;h=5c89fec93dba6e30e5a54882ac996843295d173c;hb=HEAD)
  * [CMUCL](http://common-lisp.net/viewvc/cmucl/src/pcl/)
  * [clisp](http://clisp.hg.sourceforge.net/hgweb/clisp/clisp/file/dfb5a78b146e/src)
  * [cosette](http://www.cs.cmu.edu/afs/cs/project/ai-repository/ai/lang/lisp/oop/clos/closette/0.html)
  * [Common Lisp Implementations: A Survey](http://common-lisp.net/~dlw/LispSurvey.html)


----

## xyzzy での実装

xyzzy で個別に実装する必要があった部分を説明します。


## コードウォーカーでの環境マクロ

ソース: https://github.com/miyamuko/xl-pcl/blob/master/site-lisp/xl-pcl/walk.l

以下の関数・マクロを処理系毎に実装する必要があります。

  * Macro: with-augmented-environment (`NEW-ENV` `OLD-ENV` &key `FUNCTIONS` `MACROS`) &body `BODY`)
  * Function: with-augmented-environment-internal `ENV` `FUNCTIONS` `MACROS`
  * Function: environment-function `ENV` `FN`
  * Function: environment-macro `ENV` `MACRO`

### Macro: with-augmented-environment (`NEW-ENV` `OLD-ENV` &key `FUNCTIONS` `MACROS`) &body `BODY`)

`FUNCTIONS` と `MACROS` で指定した環境を用意して `BODY` を評価するマクロ。
`FUNCTIONS` と `MACROS` は flet と macrolet を指定するようなもの。

実装は with-augmented-environment-internal に丸投げするだけでよい。
ここは実装依存にはならないので他の処理系用の実装からコピペするだけ。

### Function: with-augmented-environment-internal `ENV` `FUNCTIONS` `MACROS`

指定した `FUNCTIONS` と `MACROS` を環境に追加する。

#### xyzzy の environment-object

macro の引数でわたされる「環境」は他の処理系では alist だったりするらしいが、
xyzzy では environment-object で表現される。
また、environment-object API もないため自由に環境を操作できない。

```lisp
;;; clisp の場合
[1]> (macrolet ((env (&environment env)
                  env))
       (env))
#(NIL
  #(ENV
    #<MACRO
      #<FUNCTION ENV (SYSTEM::<MACRO-FORM> ENV)
        (DECLARE (CONS SYSTEM::<MACRO-FORM>))
        (IF
         (NOT (SYSTEM::LIST-LENGTH-IN-BOUNDS-P SYSTEM::<MACRO-FORM> 1 1 NIL))
         (SYSTEM::MACRO-CALL-ERROR SYSTEM::<MACRO-FORM>)
         (LET* NIL (BLOCK ENV ENV)))>
      NIL>
    NIL))

;;; xyzzy の場合
user> (macrolet ((env (&environment env)
                   env))
        (env))
#<environment-object 83628120>
```

#### xyzzy の macroexpand

macroexpand は environment-object 以外にも alist を受け付ける。

```lisp
user> (defmacro foo (a b)
        `(+ ,a ,b))
foo

user> #'foo
(macro (a b) (block foo (list '+ a b)))

user> (macroexpand '(foo 1 2) `((foo macro (a b) (block foo (list '+ a b)))))
(+ 1 2)
```

#### 実装

environment-object API がないので完全には実装できない。
が、おそらく以下のことが出来れば良いと思うので無理やり実装する。

  * with-augmented-environment で導入した環境関数を environment-function で取得できる
  * with-augmented-environment で導入した環境マクロを environment-macro で取得できる
  * with-augmented-environment で導入した環境マクロを macroexpand で展開できる

with-augmented-environment には 3 種類の引数が渡されるので、
それぞれ以下のように実装する。

  * with-augmented-environment の引数
    - environment-function, environment-macro, macroexpand 両方で利用される
    - 引数はマクロ展開する関数(?)
    - 以下のデータを環境に追加する
        ```lisp
        '((<macroname> 'lisp:macro <function>)              ; environment-macro 用
          (<macroname> 'lisp:macro <macroargs> <macrobody>) ; macroexpand 用
          (<funcname> 'lisp:function <function>)
          )
        ```
    - macroexpand 用のマクロは引数で渡された関数を funcall するだけの
      マクロ本文を組み立てる
  * macrolet で定義したマクロ
    - macroexpand で利用される
    - 引数はマクロ本文
    - 以下のデータを環境に追加する
        ```lisp
        '((<macroname> 'lisp:macro <macroargs> <macrobody>) ; macroexpand 用
          )
        ```
  * `*key-to-walker-environment*`
    - environment-macro で利用される
    - 引数は環境
    - 以下のデータを環境に追加する
        ```lisp
        '((<macroname> 'lisp:macro <env>)                   ; environment-macro 用
          )
        ```

### Function: environment-function `ENV` `FN`

with-augmented-environment で拡張した環境から関数を取り出す。

関数名で assoc して 2 つめの値が 'lisp:function なら 3 つめの値を返す。

### Function: environment-macro `ENV` `MACRO`

with-augmented-environment で拡張した環境からマクロを取り出す。

  * 引数が `*key-to-walker-environment*` なら
    * マクロ名で assoc して 2 つめの値が 'lisp:macro なら 3 つめの値を返す。
  * 引数が `*key-to-walker-environment*` 以外なら
    * 1 つめの値がマクロ名で、かつ 2 つめの値が 'lisp:macro で、
      かつ 3 つめの値が function な物を探す
    * macroexpand 用と environment-macro 用でキーが同じ 2 つのデータを入れているので
      単純に assoc できない

### 実行例

```lisp
;;; xyzzy lisp REPL
user> (use-package :walker)
t

user> (defun expand-rpush (form env)
        `(push ,(caddr form) ,(cadr form)))
expand-rpush

user> (defmacro with-lexical-macros (macros &body body &environment old-env)
        (let ((walker:walk-form-expand-macros-p t))
          (walker::with-augmented-environment (new-env old-env :macros macros)
                                              (walker:walk-form `(progn ,@body) new-env))))
with-lexical-macros

user> (defmacro with-rpush (&body body)
        `(with-lexical-macros ((rpush ,#'expand-rpush)) ,@body))
with-rpush

user> (let ((a))
        (flet ((foo (a b)
                 (+ a b)))
          (with-rpush
           (macrolet ((bar (a b)
                        `(* ,a ,b)))
             (rpush a (bar (foo 1 2) (foo 2 3)))))
          a))
(15)
```

### 参考

  * [multiple-value-blog1: sb-walkerのrpushの例がよく分からない](http://multiple-value-blog1.blogspot.com/2011/12/sb-walkerrpush.html)
  * [multiple-value-blog1: sb-walkerのrpushの例がよく分からない (2)](http://multiple-value-blog1.blogspot.com/2011/12/sb-walkerrpush-2.html)


----

## Funcallable Instance の実装

ソース: https://github.com/miyamuko/xl-pcl/blob/master/site-lisp/xl-pcl/fin.l

Funcallable Instance (以下 FIN) とはその名の通り funcall や apply ができるインスタンスである。
インスタンスであるため任意のデータを保持することができる。

ただし、funcall や apply が出来るからと言って、シンボルではいけないみたい。
PCL では FIN に対して以下の関数の実装が求められている。

  * Function: allocate-funcallable-instance-1
  * Function: funcallable-instance-p `X`
  * Function: set-funcallable-instance-function `FIN` `NEW-VALUE`
  * Function: funcallable-instance-data-1 `FIN` `DATA-NAME`
  * Function: (setf funcallable-instance-data-1) `FIN` `DATA-NAME` `NEW-VALUE`

### Function: allocate-funcallable-instance-1

新規の FIN を作成して返す。

データを保持するための vector を作成して、それを閉じ込めたクロージャを返す。
vector のサイズは 3 固定である。

### Function: funcallable-instance-p `X`

`X` がクロージャ、かつ vector を保持しているなら t

### Function: set-funcallable-instance-function `FIN` `NEW-VALUE`

`NEW-VALUE` で指定した関数を FIN に設定する。
FIN を funcall や apply したらこの関数を呼び出す必要がある。

xyzzy では si:closure-variable でクロージャ内に閉じ込めている変数を参照できるので、
これでクロージャ内に閉じ込めた vector の最初の要素に設定する。

PCL では FIN の関数の引数とジェネリック関数(メソッドだったかも) の
引数を比較し違うと文句をいってくるので、FIN の引数も書き換える必要がある。

FIN の引数の書き換えは si:closure-body を無理やり書き換えることで行う。
なお、このようなことをして問題がないかは未調査。

```lisp
;; FIN の作成
user> (setf fin (let ((data (make-vector 3)))
                  #'(lambda (&rest args)
                      (apply (svref data 0) args))))
#<lexical-closure: (anonymous)>

;; FIN のデータの取得
user> (setf data (cdr (assoc 'data (si:closure-variable fin))))
#(nil nil nil)

;; FIN に関数を設定
user> (setf (svref data 0) #'(lambda (a b) (+ a b)))
#<lexical-closure: (anonymous)>

;; FIN を呼び出してみる
user> (funcall fin 1 2)
3

;; FIN の実態を取得
user> (si:closure-body fin)
(lambda (&rest args) (apply (svref data 0) args))

;; FIN 内の関数の実体を取得
user> (si:closure-body (svref data 0))
(lambda (a b) (+ a b))

;; FIN と FIN 内の関数で引数を無理やり合わせる
user> (setf (cdr (si:closure-body fin))
            (cdr `(lambda (a b)
                    (funcall (svref data 0) a b))))
((a b) (funcall (svref data 0) a b))

user> (si:closure-body fin)
(lambda (a b) (funcall (svref data 0) a b))

user> (funcall fin 1 2)
3
```

### Function: funcallable-instance-data-1 `FIN` `DATA-NAME`

`DATA-NAME` で指定したデータを FIN から取得する。

`DATA-NAME` には `wrapper` と `slots` が渡されると PCL の仕様で決まっている。
クロージャ内に閉じ込めた vector の第 2 および第 3 要素を取得する。

### Function: (setf funcallable-instance-data-1) `FIN` `DATA-NAME` `NEW-VALUE`

`DATA-NAME` で指定したデータを FIN に設定する。

`DATA-NAME` には `wrapper` と `slots` が渡されると PCL の仕様で決まっている。
`NEW-VALUE` はクロージャ内に閉じ込めた vector の第 2 および第 3 要素に設定する。

### 実行例

```lisp
user> (setf fin (pcl::allocate-funcallable-instance-1))

user> (pcl::set-funcallable-instance-function fin #'(lambda (a b) (+ a b)))
((a b) (funcall #<lexical-closure: (anonymous)> a b))

user> (funcall fin 1 2)
3

user> (pcl::funcallable-instance-data-1 fin 'pcl::wrapper)
nil

user> (setf (pcl::funcallable-instance-data-1 fin 'pcl::wrapper) "foobar")
"foobar"

user> (pcl::funcallable-instance-data-1 fin 'pcl::wrapper)
"foobar"

user> (pcl::set-funcallable-instance-function fin #'(lambda (a b) (* a b)))
((a b) (funcall #<lexical-closure: (anonymous)> a b))

user> (funcall fin 2 3)
6
```

### 参考

* [HCL上のPortable Common Loopsのインプリメントと高速化技法](https://ipsj.ixsq.nii.ac.jp/ej/index.php?active_action=repository_view_main_item_detail&item_id=24717&item_no=1&page_id=13&block_id=8)
