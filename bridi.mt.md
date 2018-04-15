Today we're going to write some Monte to do some category theory.

We'll want JSON. In Monte, JSON is defined between Unicode strings, guarded by
`Str`, but files are read as bytestrings, guarded by `Bytes`, so we'll also
need a UTF-8 decoder.

```monte
import "lib/codec/utf8" =~ [=> UTF8]
import "lib/json" =~ [=> JSON]
```

We're going to parse some things, so we'll want parser combinators.

```monte
import "lib/pen" =~ [=> pk, => makeSlicer]
```

Let's declare a module. We'll export a `main` entrypoint for running our
script.

```monte
exports (main)
```

Let's define small categories. A small category is a set of objects and a set
of arrows from objects to objects. We won't need all of the various powerful
features of categories, just some basics.

```monte
def makeCat(objects :Set, arrows :Map[Pair, Set]) as DeepFrozen:
    return object cat:
        to objects():
            return objects
        to arrows():
            return arrows
```

Let's use DOT to draw each category as a diagram.

```monte
        to dot():
            def objs := [for obj in (objects) `"$obj";`]
            def arrs := [].diverge()
            for [source, target] => names in (arrows):
                for name in (names):
                    arrs.push(`"$source" -> "$target" [label="$name"];`)
            return "\n".join(objs + arrs)
```

We'll need to be able to turn our loaded JSON into categories.

```monte
def classify(vals :List) as DeepFrozen:
    def objs := [].asSet().diverge()
    def arrows := [].asMap().diverge()
    for val in (vals):
        switch (val):
            match obj :Str:
                objs.include(obj)
            match [=> name, => source, => target]:
                def pair := [source, target]
                def arrowSet := arrows.fetch(pair, fn {
                    arrows[pair] := [].asSet().diverge()
                })
                arrowSet.include(name)
    return makeCat(objs.snapshot(), [for k => v in (arrows) k => v.snapshot()])
```

The output of the Lojban parser is a concrete parse tree. We have to reduce it
to a usable form. First, we'll define a parser to consume the parse tree. It
will be easier to consume a list of trees rather than a single tree.

```monte
def reduce(trees) as DeepFrozen:
    def head(tag, parser):
        return pk.recurse(pk.equals(tag) >> parser)
    def cmavo(selmaho, parser):
        return head("CMAVO", head(selmaho, parser))

    def setting(s):
        return pk.mapping([for x in (s) x => x])

    def da := cmavo("KOhA", setting(["da", "de", "di"].asSet()))
    def term := head("sumti5", da)

    def poi := cmavo("NOI", pk.equals("poi"))
    def kuho := cmavo("KUhO", pk.equals("ku'o"))

    def gismu := head("gismu", pk.anything)
    def brivla := head("BRIVLA", gismu)
    def se := cmavo("SE", setting(["se", "te", "ve", "xe"].asSet()))
    def tanru := head("tanruUnit2", se + brivla)
    def selbri := brivla / tanru

    def relativeClause := head("relativeClause1",
                               poi >> selbri << kuho.optional())
    def decl := head("sumti5", da + relativeClause)

    def zohu := cmavo("ZOhU", pk.equals("zo'u"))
    def terms := head("terms", decl.oneOrMore())
    def prenex := head("prenex", terms << zohu.optional())

    def sentence := term
    def statement := head("statement", prenex + sentence)
    def text := head("text", statement)
```

And now we can run the parser on the trees.

```monte
    return escape ej:
        return text(makeSlicer.fromList(trees), ej)
    catch problem:
        traceln("nope", problem)
        throw(problem)
```

And print something.

```monte
def main(argv, => makeFileResource) as DeepFrozen:
    def files := argv.slice(2, argv.size())
    def bss := [for file in (files) makeFileResource(file)<-getContents()]
    return when (promiseAllFulfilled(bss)) ->
        def trees := [for bs in (bss) {
            def via (UTF8.decode) via (JSON.decode) tree := bs
            traceln(tree)
            tree
        }]
        def reduced := reduce(trees)
        traceln(reduced)
        0
```
        def via (UTF8.encode) dot := `digraph {
            ${classed.dot()}
        }`
        def out := makeFileResource("mlatu.cat.dot")
        when (out<-setContents(dot)) ->
            traceln(42)
            0
