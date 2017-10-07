module {"name": "cat"};

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

def range_of($edge): . as $cat | verts | fetch($cat | source($edge));
def domain_of($edge): . as $cat | verts | fetch($cat | target($edge));

def edges_on($f; $vertex): edges | keys |
    map(. as $edge | select(($f | fetch($edge)) == $vertex));

def edges_from($vertex): edges_on(sources; $vertex);
def edges_to($vertex): edges_on(targets; $vertex);
def homs($source; $target): . as $cat | edges_from($source) |
    intersect($cat | edges_to($target));

# XXX factor!
def compose_path($path): . as $cat | $path | if length > 0
    then (first as $f | $cat | range_of($f) | map({key: ., value: .}) |
          from_entries) as $head |
        reduce (map(. as $edge | $cat | edges | fetch($edge)) | .[]) as $acc
            ($head; compose_arrows(.; $acc))
    else null end;
