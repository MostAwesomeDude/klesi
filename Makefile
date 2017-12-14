default: jicmu.svg

%.json: %.jbo
	<$< jbo2json | jq . >$@

jbos := $(patsubst %.jbo,%.json,$(wildcard jicmu/*.jbo))

jicmu.svg: $(jbos) cat.jq zbasu.mt
	monte eval zbasu.mt $(jbos) | jq -r 'include "cat"; dot' | dot -Tsvg >$@
