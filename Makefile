default: jicmu.svg

%.json: %.jbo
	<$< jbo2json | jq . >$@

jbos := $(patsubst %.jbo,%.json,$(wildcard jicmu/*.jbo))

jicmu.cat: $(jbos) zbasu.mt
	monte eval zbasu.mt $(jbos) >$@

jicmu.svg: jicmu.cat cat.jq
	<$< jq -r 'include "cat"; dot' | dot -Tsvg >$@
