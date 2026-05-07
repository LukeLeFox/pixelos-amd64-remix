.PHONY: check syntax package

check: syntax

syntax:
	bash -n scripts/rpd-amd64-postinstall.sh
	bash -n scripts/rpd-amd64-diagnose.sh

package:
	cd .. && tar -czf pixelos-amd64-remix.tar.gz pixelos-amd64-remix
