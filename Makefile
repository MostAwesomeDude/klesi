default: jicmu.svg

%.json: %.jbo
	<$< jbo2json | monte eval zbasu.mt | jq . >$@

%.svg: %.json
	<$< jq -r 'include "cat"; dot' | tee temp.dot | dot -Tsvg >$@
