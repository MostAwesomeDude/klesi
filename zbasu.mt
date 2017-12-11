import "lib/codec/utf8" =~ [=> UTF8 :DeepFrozen]
import "lib/json" =~ [=> JSON :DeepFrozen]
import "lib/streams" =~ [=> collectBytes :DeepFrozen]
exports (main)

def i :DeepFrozen := ["CMAVO", ["I", "i"]]
def ku :DeepFrozen := ["CMAVO", ["KU", "ku"]]
def lohe :DeepFrozen := ["CMAVO", ["LE", "lo'e"]]

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
                [selbri, [head] + sumtis]
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
        def result := top(data)
        def packed := UTF8.encode(JSON.encode(result, null), null) + b`$\n`
        def stdout := stdio.stdout()
        when (stdout<-(packed), stdout<-complete()) -> { 0 }
