def add_objs: reduce .[] as $acc ({}; . * $acc);
def enumerate: [keys, .] | transpose;

def lo: "lo " + .;
def arrow($name; $source; $target): ("\($name) : \($source) -> \($target)");

def build_arrow_graph($arrow; $source; $target):
    {
        vertices: {($source): [], ($target): []}, 
        edges: {($arrow): {}},
        source: {($arrow): $source},
        target: {($arrow): $target}
    };

def build_nenri_graph: to_entries |
    map((.key | lo) as $from | (.value | lo) as $to |
        arrow("nenri"; $from; $to) | build_arrow_graph(.; $from; $to)) |
    add_objs;
def build_nenri_paths: [];

def build_iso_graph($from; $to):
    arrow("du"; $from; $to) as $in |
    arrow("du"; $to; $from) as $out |
    {
        vertices: {($from): [], ($to): []}, 
        edges: {($in): {}, ($out): {}},
        source: {($in): $from, ($out): $to},
        target: {($in): $to, ($out): $from}
    };
def build_iso_path($from; $to):
    arrow("du"; $from; $to) as $in |
    arrow("du"; $to; $from) as $out |
    [{source: $from, target: $to, edges: [[$in, $out], []]},
     {source: $to, target: $from, edges: [[$out, $in], []]}];

def build_du_graph: to_entries |
    map(build_iso_graph(.key | lo; .value | lo)) | add_objs;
def build_du_paths: to_entries |
    map(build_iso_path(.key | lo; .value | lo)) | add;

def se($i): (["", "se ", "te ", "ve ", "xe "] | nth($i)) + .;
def fa($i): . + ([" fa", " fe", " fi", " fo", " fu"] | nth($i));

def sumti_arrow($i; $j): . as $bridi | se($i) |
    (. | lo) as $source | ($bridi | se($j) | lo) as $target |
    arrow(. | fa($j); $source; $target) |
    build_arrow_graph(.; $source; $target);

def build_sumti_graph($bridi; $links):
    $links | enumerate |
    map(. as [$i, $l] | $l |
        map(. as $j | $bridi | sumti_arrow($i; $j)) | add_objs) |
    add_objs;

def build_bridi_graph: to_entries |
    map(build_sumti_graph(.key; .value)) | add_objs;
def build_bridi_paths: to_entries |
    map(.) | [] | add;

def build_selska_graph: map(lo) | {vertices: {"lo selska": .}};
def build_selratni_graph: map(lo) | {vertices: {"lo selratni": .}};

def build_graphs: (.du | build_du_graph) as $du |
    (.selska | build_selska_graph) as $selska |
    (.selratni | build_selratni_graph) as $selratni |
    (.nenri | build_nenri_graph) as $nenri |
    (.bridi | build_bridi_graph) as $bridi |
    [$du, $selska, $selratni, $nenri, $bridi] | add_objs;
def build_paths: (.du | build_du_paths) as $du |
    (.nenri | build_nenri_paths) as $nenri |
    (.bridi | build_bridi_paths) as $bridi |
    [$du, $nenri, $bridi] | add;

build_graphs as $graph | build_paths as $paths |
    {release: 0, compatibility: 0, category: {$graph, $paths}}
