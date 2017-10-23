default: jicmu.svg

%-cat.json: %-base.json tax.jq
	<$< jq -f tax.jq >$@

%.svg: %-cat.json cat.jq
	<$< jq -r 'include "cat"; dot' | dot -Tsvg >$@
