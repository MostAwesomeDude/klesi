module {"name": "cat"};

# [obj] -> obj
def add_objs: reduce .[] as $acc ({}; . * $acc);

# obj -> obj[$key]
def fetch($key): to_entries | map(select(.key == $key)) |
    first // error("Missing key \($key)") | .value;

# {k: g[v] for k, v in f}
def compose_arrows($f; $g): $f |
    with_entries(.value as $v | {key, value: $g | fetch($v)});

# Set intersection, filtering a list with another list.
def intersect($r): map(select(. as $x | $r | any(. == $x)));

def verts: .category.graph.vertices;
def edges: .category.graph.edges;
def sources: .category.graph.source;
def targets: .category.graph.target;
def source($edge): sources | fetch($edge);
def target($edge): targets | fetch($edge);
def get_paths: .category | .["paths"];

def range_of($edge): . as $cat | verts | fetch($cat | source($edge));
def domain_of($edge): . as $cat | verts | fetch($cat | target($edge));

def edges_on($f; $vertex): edges | keys |
    map(. as $edge | select(($f | fetch($edge)) == $vertex));

def edges_from($vertex): edges_on(sources; $vertex);
def edges_to($vertex): edges_on(targets; $vertex);
def homs($source; $target): . as $cat | edges_from($source) |
    intersect($cat | edges_to($target));
def id_arrow($vertex): verts | fetch($vertex) | map({key: ., value: .}) |
    from_entries;

def compose_path($path): . as $cat | $path | if length > 0
    then (first as $f | $cat | source($f) as $vertex | id_arrow($vertex))
           as $head |
        reduce (map(. as $edge | $cat | edges | fetch($edge)) | .[]) as $acc
            ($head; compose_arrows(.; $acc))
    else null end;

def hash_string: reduce (explode | .[]) as $acc (0;
    (. * 1664525 + $acc) % 4294967296);

def dot_quote: "\"" + . + "\"";
def dot_verts: verts | keys | map(dot_quote + " [shape=box];");
def color_paths: get_paths |
    map("/dark28/\((.source + .target | hash_string) % 8 + 1)" as $color |
        .edges | flatten | map({key: ., value: [$color]}) | from_entries) |
    add_objs | with_entries({key: .key,
        value: .value | join(":") | dot_quote | ("color=" + .)});

def dot_edges: . as $cat | color_paths as $colors |
    edges | keys | .[] as $edge |
    ($cat | source($edge) | dot_quote) as $source |
    ($cat | target($edge) | dot_quote) as $target |
    ($edge / ":" | first | dot_quote) as $tt |
    ($colors | if has($edge) then fetch($edge) else "" end) as $color |
    $source + " -> " + $target + " [edgetooltip=\($tt) \($color)];";
def dot: ["digraph klesi {", dot_verts, dot_edges, "}"] | flatten | join("\n");

def rsort: sort_by([length, .]) | reverse;

# Apply a single rewrite rule.
def apply_rule($lhs; $rhs): index($lhs) as $start | if $start then
    ($lhs | $start + length) as $stop | .[:$start] + $rhs + .[$stop:] else .
    end;
def apply_rules($rules): . as $s |
    reduce $rules as $rule ($s; apply_rule($rule[0]; $rule[1]));
def rewrite($rules): . as $original | apply_rules($rules) |
    if . == $original then . else rewrite($rules) end;

def crits: if . == [] then [] else
    first as [$lhs, $rhs] | .[1:] |
    map(select(.[0] == $lhs) | [$rhs, .[1]]) + crits
    end;
def nontaut: select(.[0] != .[1]);
def kb($e; $rules): $e | if . == []
    then $rules | crits | if . == [] then $rules else kb(.; $rules) end
    else
        (first | map(rewrite($rules)) | rsort) as [$m, $n] |
        .[1:] | if $m == $n then kb(.; $rules) else
            $rules + [[$m, $n]] as $rs |
            map(map(rewrite($rs)) | nontaut) as $es |
            $rs | map([.[0], .[1] | rewrite($rs)] | nontaut) | kb($es; . // [])
            end
    end;
def knuth_bendix: kb(.; []);

def initial_rules: if (. | length) < 2 then [] else
    first as $x | .[1:] | map([$x, .] | rsort) + initial_rules
    end;
def solve_paths: get_paths | map(.edges | initial_rules) | flatten(1) |
    knuth_bendix;
