;; List of built in macros for LispyScript. This file is included by
;; default by the LispyScript compiler.


;;;;;;;;;;;;;;;;;;;; Conditionals ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(macro undefined? (obj)
  (= (typeof ~obj) "undefined"))

(macro null? (obj)
  (= ~obj null))

(macro true? (obj)
  (= true ~obj))

(macro false? (obj)
  (= false ~obj))

(macro boolean? (obj)
  (= (typeof ~obj) "boolean"))

(macro zero? (obj)
  (= 0 ~obj))

(macro number? (obj)
  (= (Object.prototype.toString.call ~obj) "[object Number]"))

(macro string? (obj)
  (= (Object.prototype.toString.call ~obj) "[object String]"))

(macro array? (obj)
  (= (Object.prototype.toString.call ~obj) "[object Array]"))

(macro object? (obj)
  ((function (obj)
    (= obj (Object obj))) ~obj))

(macro function? (obj)
  (= (Object.prototype.toString.call ~obj) "[object Function]"))


;;;;;;;;;;;;;;;;;;;;;;; Expressions ;;;;;;;;;;;;;;;;;;;;

(macro do (rest...)
  ((function () ~rest...)))

(macro when (cond rest...)
  (if ~cond (do ~rest...)))

(macro unless (cond rest...)
  (when (! ~cond) (do ~rest...)))

(macro cond (rest...)
  (if (#args-shift rest...) (#args-shift rest...) (#args-if rest... (cond ~rest...))))

(macro array (rest...)
  ((function ()
    (Array.prototype.slice.call arguments)) ~rest...))

(macro arrayInit (len obj)
  ((function (l o)
    (var ret [])
    (javascript "for(var i=0;i<l;i++) ret.push(o);")
    ret) ~len ~obj))

(macro arrayInit2d (i j obj)
  ((function (i j o)
    (var ret [])
    (javascript "for(var n=0;n<i;n++){var inn=[];for(var m=0;m<j;m++) inn.push(o); ret.push(inn);}")
    ret) ~i ~j ~obj))

(macro object (rest...)
  ((function ()
    (var _r {})
    (javascript "for(var i=0,l=arguments.length;i<l;i+=2){_r[arguments[i]]=arguments[i+1];}")
    _r) ~rest...))

;; method chaining macro
(macro -> (func form rest...)
  (#args-if rest... 
    (-> (((#args-shift form) ~func) ~@form) ~rest...)
    (((#args-shift form) ~func) ~@form)))

;;;;;;;;;;;;;;;;;;;;;; Iteration and Looping ;;;;;;;;;;;;;;;;;;;;

(macro each (obj fn rest...)
  ((function (o f s)
    (javascript "if(o.forEach){o.forEach(f,s);}else{for(var i=0,l=o.length;i<l;++i)f.call(s||o,o[i],i,o);}")
    undefined) ~obj ~fn ~rest...))
 
(macro eachKey (obj fn rest...)
  ((function (o f s)
    (javascript "var _k;if(Object.keys){_k=Object.keys(o);}else{_k=[];for(var i in o)_k.push(i);}")
    (each _k
      (function (elem)
        (f.call s (get elem o) elem o)))) ~obj ~fn ~rest...))

(macro each2d (arr fn)
  (each ~arr
    (function (___elem ___i ___oa)
      (each ___elem
        (function (___val ___j ___ia)
          (~fn ___val ___j ___i ___ia ___oa))))))

(macro reduce (arr fn rest...)
  ((function (arr f init)
    (var noInit (< arguments.length 3))
    (each arr
      (function (val i list)
        (if (&& (= i 0) noInit)
          (set init val)
          (set init (f init val i list)))))
    init) ~arr ~fn ~rest...))

(macro map (arr fn rest...)
  ((function (arr f scope)
    (var _r [])
    (each arr
      (function (val i list)
        (_r.push (f.call scope val i list))))
    _r) ~arr ~fn ~rest...))

(macro filter (rest...)
  (Array.prototype.filter.call ~rest...))

(macro some (rest...)
  (Array.prototype.some.call ~rest...))

(macro every (rest...)
  (Array.prototype.every.call ~rest...))

(macro loop (args vals rest...)
  ((function ()
    (var recur null)
    (var ___result !undefined)
    (var ___nextArgs null)
    (var ___f (function ~args ~rest...))
    (set recur
      (function ()
        (set ___nextArgs arguments)
        (if (= ___result undefined)
          undefined
          (do
            (set ___result undefined)
            (javascript "while(___result===undefined) ___result=___f.apply(this,___nextArgs);")
            ___result))))
    (recur ~@vals))))

(macro for (rest...)
  (doMonad arrayMonad ~rest...))


;;;;;;;;;;;;;;;;;;;; Templates ;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(macro template (name args rest...)
  (var ~name
    (function ~args
      (str ~rest...))))

(macro template-repeat (arg rest...)
  (reduce ~arg
    (function (___memo elem index)
      (+ ___memo (str ~rest...))) ""))

(macro template-repeat-key (obj rest...)
  (do
    (var ___ret "")
    (eachKey ~obj
      (function (value key)
        (set ___ret (+ ___ret (str ~rest...)))))
    ___ret))


;;;;;;;;;;;;;;;;;;;; Callback Sequence ;;;;;;;;;;;;;;;;;;;;;

(macro sequence (name args init rest...)
  (var ~name
    (function ~args
      ((function ()
        ~@init
        (var next null)
        (var ___curr 0)
        (var ___actions (new Array ~rest...))
        (set next
          (function ()
            (var ne (get ___curr++ ___actions))
            (if ne
              ne
              (throw "Call to (next) beyond sequence."))))
        ((next)))))))


;;;;;;;;;;;;;;;;;;; Unit Testing ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(macro assert (cond message)
  (if (true? ~cond)
    (+ "Passed - " ~message)
    (+ "Failed - " ~message)))

(macro testGroup (name rest...)
  (var ~name 
    (function ()
      (array ~rest...))))

(macro testRunner (groupname desc)
  ((function (groupname desc)
    (var start (new Date))
    (var tests (groupname))
    (var passed 0)
    (var failed 0)
    (each tests
      (function (elem)
        (if (elem.match /^Passed/)
          ++passed
          ++failed)))
    (str 
      (str "\n" desc "\n" start "\n\n")
      (template-repeat tests elem "\n")
      "\nTotal tests " tests.length 
      "\nPassed " passed 
      "\nFailed " failed 
      "\nDuration " (- (new Date) start) "ms\n")) ~groupname ~desc))


;;;;;;;;;;;;;;;; Monads ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(macro identityMonad ()
  (object
    "mBind" (function (mv mf) (mf mv))
    "mResult" (function (v) v)))

(macro maybeMonad ()
  (object
    "mBind" (function (mv mf) (if (null? mv) null (mf mv)))
    "mResult" (function (v) v)
    "mZero" null))

(macro arrayMonad ()
  (object
    "mBind" (function (mv mf)
              (reduce
                (map mv mf)
                (function (accum val) (accum.concat val))
                []))
    "mResult" (function (v) [v])
    "mZero" []
    "mPlus" (function ()
              (reduce
                (Array.prototype.slice.call arguments)
                (function (accum val) (accum.concat val))
                []))))

(macro stateMonad ()
  (object
    "mBind" (function (mv f)
              (function (s)
                (var l (mv s))
                (var v (get 0 l))
                (var ss (get 1 l))
                ((f v) ss)))
    "mResult" (function (v) (function (s) [v, s]))))

(macro continuationMonad ()
  (object
    "mBind" (function (mv mf)
              (function (c)
                (mv
                  (function (v)
                    ((mf v) c)))))
    "mResult" (function (v)
                (function (c)
                  (c v)))))

(macro m-bind (bindings expr)
  (mBind (#args-second bindings)
    (function ((#args-shift bindings))
      (#args-if bindings (m-bind ~bindings ~expr) ((function () ~expr))))))

(macro withMonad (monad rest...)
  ((function (___monad)
    (var mBind ___monad.mBind)
    (var mResult ___monad.mResult)
    (var mZero ___monad.mZero)
    (var mPlus ___monad.mPlus)
    ~rest...) (~monad)))

(macro doMonad (monad bindings expr)
  (withMonad ~monad
    (var ____mResult
      (function (___arg)
        (if (&& (undefined? ___arg) (! (undefined? mZero)))
          mZero
          (mResult ___arg))))
    (m-bind ~bindings (____mResult ~expr))))

(macro monad (name obj)
  (var ~name
    (function ()
      ~obj)))



