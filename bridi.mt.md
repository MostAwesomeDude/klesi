Today we're going to write some Monte to do some category theory. We'll be
parsing a subset of Lojban into regular logic and then interpreting that logic
in its corresponding Lojbanic allegory.

We'll want JSON to decode the output of the Lojban lexer. In Monte, JSON is
defined between Unicode strings, guarded by `Str`, but files are read as
bytestrings, guarded by `Bytes`, so we'll also need a UTF-8 decoder.

```monte
import "lib/codec/utf8" =~ [=> UTF8]
import "lib/json" =~ [=> JSON]
```

We're going to parse some things, so we'll want parser combinators. We'll be
using the brand-new "pen" toolkit for this task.

```monte
import "lib/pen" =~ [=> pk, => makeSlicer]
```

Let's declare a module. We'll export a `main` entrypoint for running our
script. We don't need to export anything else; this module is self-contained.

```monte
exports (main)
```

Every gismu has an arity, and we can't determine that morphologically, so we
have a mapping instead.

```monte
def arities :Map[Str, Int] := [
    "danlu" => 2,
    "mlatu" => 2,
    "tirxu" => 3,
]
```

The SE series of cmavo converts the slots of selbri.

```monte
def converters :List[Str] := ["se", "te", "ve", "xe"]
```

We need to do some selbri stuff.

```monte
object makeSelbri as DeepFrozen:
    to run(gismu :Str, slots :List[Int]):
        return object selbri:
            to _printOn(out):
                out.print(`<selbri $gismu $slots>`)

            to convert(which :Int):
                def ss := slots.diverge()
                def temp := ss[0]
                ss[0] := ss[which]
                ss[which] := temp
                return makeSelbri(gismu, ss.snapshot())

            to asType():
                def headSlot := slots[0]
                def se := if (headSlot == 0) { "" } else {
                    converters[headSlot - 1] + " "
                }
                return "lo " + se + gismu

    to fromGismu(gismu :Str):
        def slots := _makeList.fromIterable(0..!arities[gismu])
        return makeSelbri(gismu, slots)
```

The output of the Lojban parser is a concrete parse tree. We have to reduce it
to a usable form. First, we'll define a parser to consume the parse tree. It
will be easier to consume a list of trees rather than a single tree.

Each tree represents a single formula. A formula has a context, which
introduces the variables, and a term, which is a conjunction of terms, an
existential quantifier of some new variables over a term, an equality of
variables, or a primitive relation on variables. This is all represented as
Lojban syntax.

We'll use a basic tagged-list style to represent the formulae in context.

```monte
object exists as DeepFrozen {}
object and as DeepFrozen {}
object equals as DeepFrozen {}
object relation as DeepFrozen {}
```

Logic                 | Lojban
-----                 | ------
context               | prenex
variable of type T    | {da poi T}
existential of type T | {da poi T}
conjunction P & Q     | {ge P gi Q}
equality              | {da du de}
relation R            | {da R de di}

```monte
def reduce(trees) as DeepFrozen:
    def head(tag, parser):
        return pk.recurse(pk.equals(tag) >> parser)
    def cmavo(selmaho, parser):
        return head("CMAVO", head(selmaho, parser))

    def setting(s):
        return pk.mapping([for x in (s) x => x])

    def poi := cmavo("NOI", pk.equals("poi"))
    def kuho := cmavo("KUhO", pk.equals("ku'o"))

    def gismu := head("gismu", pk.anything) % makeSelbri.fromGismu
    def brivla := head("BRIVLA", gismu)
    def se := cmavo("SE", setting(converters.asSet()))
    def tanru := head("tanruUnit2", (se + brivla) % fn [s, b] {
        b.convert(converters.indexOf(s) + 1)
    })
    def selbri := brivla / tanru
```

Variables in regular logic are always explicitly introduced and typed. We'll
let a variable be a name and a type.

```monte
    def da := cmavo("KOhA", setting(["da", "de", "di"].asSet()))
    def relativeClause := head("relativeClause1",
                               poi >> selbri << kuho.optional())
    def decl := head("sumti5", (da + relativeClause) % fn [n, sb] {
        [n, sb.asType()]
    })

    def zohu := cmavo("ZOhU", pk.equals("zo'u"))
    def terms := head("terms", decl.oneOrMore())
    def prenex := head("prenex", terms << zohu.optional())

    def bridiTail := head("bridiTail3", brivla + da.zeroOrMore())
    def bridi := (da + bridiTail) % fn [h, [b, t]] {
        [relation, b, [h] + t]
    }
    def sentence := head("sentence", bridi)

    def statement := head("statement", prenex + sentence)
    def text := head("text", statement)
```

And now we can run the parser on the trees.

```monte
    return escape ej:
        text(makeSlicer.fromList(trees), ej)
    catch problem:
        traceln("nope", problem)
        throw(problem)
```

We'll read in our Lojban JSON, reduce it, and print what we've got.

```monte
def main(argv, => makeFileResource) as DeepFrozen:
    def files := argv.slice(2, argv.size())
    def bss := [for file in (files) makeFileResource(file)<-getContents()]
    return when (promiseAllFulfilled(bss)) ->
        def trees := [for bs in (bss) {
            def via (UTF8.decode) via (JSON.decode) tree := bs
            tree
        }]
        def reduced := reduce(trees)
        traceln(reduced)
        0
```
