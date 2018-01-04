import "lib/codec/utf8" =~ [=> UTF8]
import "lib/json" =~ [=> JSON]
import "lib/streams" =~ [=> collectBytes]
exports (main)


def buildTypes(cat :Map) as DeepFrozen:
    def [=> release,
         => compatibility,
         => category] := cat
    traceln(`loaded category v$release.$compatibility`)
    def [=> graph, => paths] := category
    traceln(`${paths.size()} paths`)
    def [=> vertices, => edges,
         "source" => sources, "target" => targets] := graph
    return object cat:
        to _printOn(out):
            out.print(`${vertices.size()} types, ${edges.size()} builtins`)

        to edgesNamed(needle :Str, => source := null :NullOk[Str],
                      => target := null :NullOk[Str]):
            def accept(edge :Str) :Bool:
                return ((source == null || sources[edge] != source) &&
                        (target == null || targets[edge] != target) &&
                        (edge.contains(needle)))
            return [for edge in (edges) ? (accept(edge)) edge]

def main(_argv, => stdio) as DeepFrozen:
    def bs := collectBytes(stdio.stdin())
    return when (bs) ->
        def via (UTF8.decode) via (JSON.decode) catMap := bs
        def types := buildTypes(catMap)
        types
        0
