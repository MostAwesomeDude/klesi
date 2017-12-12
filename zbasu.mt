import "lib/codec/utf8" =~ [=> UTF8 :DeepFrozen]
import "lib/json" =~ [=> JSON :DeepFrozen]
import "lib/streams" =~ [=> collectBytes :DeepFrozen]
exports (main)

def i :DeepFrozen := ["CMAVO", ["I", "i"]]
def ku :DeepFrozen := ["CMAVO", ["KU", "ku"]]
def lohe :DeepFrozen := ["CMAVO", ["LE", "lo'e"]]

def combine(x, y) as DeepFrozen:
    return if (x =~ m1 :Map && y =~ m2 :Map) {
        def keys := (m1.getKeys() + m2.getKeys()).asSet()
        [for k in (keys) k => {
            if (!m1.contains(k)) { m2[k] } else if (!m2.contains(k)) {
                m1[k]
            } else { combine(m1[k], m2[k]) }
        }]
    } else if (x =~ l1 :List && y =~ l2 :List) { l1 + l2 } else { x | y }

def makeCat(objs :Map[Str, List[Str]], arrows :Map[Str, Map[Str, Str]],
            source :Map[Str, Str], target :Map[Str, Str],
            paths :List[Map], => mustCommute :Bool := true) as DeepFrozen:
    if (mustCommute):
        # Check every arrow.
        for name => arrow in (arrows):
            def s := objs[source[name]]
            def t := objs[target[name]]
            def image := [for x in (s) arrow[x]].asSet()
            if (!(image <= t.asSet())):
                throw(`Faulty arrow $name: Source $s not mapped into target $t by arrow $arrow`)
        # XXX check every path
    return object cat:
        to _printOn(out):
            out.print(`<cat: ${objs.size()} objs, ${arrows.size()} arrows>`)

        to _uncall():
            return [makeCat, "run", [objs, arrows, source, target, paths],
                    [=> mustCommute]]

        to add(other):
            def [==makeCat, =="run",
                 [oobjs, oarrows, osource, otarget, opaths],
                 _] := other._uncall()
            return makeCat(combine(objs, oobjs), combine(arrows, oarrows),
                           combine(source, osource), combine(target, otarget),
                           paths + opaths)

        to freeze():
            return [
                "release" => 0,
                "compatibility" => 0,
                "category" => [
                    "graph" => [
                        "vertices" => objs,
                        "edges" => arrows,
                        => source, => target,
                    ],
                    => paths,
                ],
            ]

object zbasu as DeepFrozen:
    to sumti(l :List, ej):
        return switch (l) {
            match [=="sumti6", ==lohe] + b ? (!b.isEmpty()) {
                def rv := if (b.last() == ku) { b.slice(0, b.size() - 1) } else { b }
                [for [=="BRIVLA", [=="gismu", gismu]] in (rv) gismu]
            }
            match _ { throw.eject(ej, `Not a sumti: $l`) }
        }

    to bridiTail(l :List, ej):
        return switch (l) {
            match [=="bridiTail3", [=="BRIVLA", [=="gismu", brivla]]] + sumtis {
                [brivla, [for s in (sumtis) zbasu.sumti(s, ej)]]
            }
            match _ { throw.eject(ej, `Not a bridi-tail: $l`) }
        }

    to bridi(l :List):
        return switch (l) {
            match [via (zbasu.sumti) head, via (zbasu.bridiTail) [selbri, sumtis]] {
                switch ([selbri, [head] + sumtis]) {
                    match [=="cmima", [x1, x2]] {
                        def source := `lo'e ${" ".join(x1)}`
                        def target := `lo'e ${" ".join(x2)}`
                        def edge := `$source ku cmima $target`
                        makeCat([source => [], target => []],
                                [edge => [].asMap()],
                                [edge => source], [edge => target], [])
                    }
                }
            }
        }

def sentence(l :List) as DeepFrozen:
    return switch (l) {
        match [=="sentence"] + b { zbasu.bridi(b) }
    }

def paragraph(l :List) as DeepFrozen:
    return switch (l) {
        match [=="paragraph"] + sentences {
            [for s in (sentences) ? (s != i) sentence(s)]
        }
    }

def top(l :List) as DeepFrozen:
    return switch (l) {
        match [=="text", [=="text1"] + paras] {
            def rv := [].diverge()
            for p in (paras) { if (p != i) { rv.extend(paragraph(p)) } }
            rv.snapshot()
        }
    }

def main(_argv, => stdio) as DeepFrozen:
    def bs := collectBytes(stdio.stdin())
    return when (bs) ->
        def data := JSON.decode(UTF8.decode(bs, null), null)
        def [var cat] + cats := top(data)
        for c in (cats):
            cat += c
        def result := cat.freeze()
        def packed := UTF8.encode(JSON.encode(result, null), null) + b`$\n`
        def stdout := stdio.stdout()
        when (stdout<-(packed), stdout<-complete()) -> { 0 }
