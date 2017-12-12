default: jicmu.svg

%.json: %.jbo zbasu.mt
	<$< jbo2json | monte eval zbasu.mt | jq . >$@

%.svg: %.json cat.jq
	<$< jq -r 'include "cat"; dot' | dot -Tsvg >$@
