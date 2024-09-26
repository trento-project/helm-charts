NAME = trento-server

YQ := $(shell command -v yq 2> /dev/null)
HELM := $(shell command -v helm 2> /dev/null)
OSC := $(shell command -v osc 2> /dev/null)

.PHONY: verify-deps clean tar
default: verify-deps clean tar

verify-deps:
ifndef YQ
	$(error "yq not found")
endif
ifndef HELM
	$(error "helm not found")
endif
ifndef OSC
	$(error "osc not found")
endif

clean:
	rm -f *.tar
tar:
	osc service manualrun
	tmpdir=$$(mktemp -d -p .) && \
      pushd $$tmpdir && \
      tar -xf ../$(NAME).tar && \
	for patch in $$(find .. -maxdepth 1 -name '*.patch'|sort); do \
	    echo "Applying patch $$patch"; \
	    cat $$patch | patch --no-backup-if-mismatch -p1 -s -d $(NAME); \
	done && \
	if [ -f "../values-overwrite.yaml" ]; then \
	    yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' ../helm-charts/charts/$(NAME)/values.yaml ../values-overwrite.yaml > $(NAME)/values.yaml; \
	fi && \
	pushd $(NAME) && \
	helm dependency update && \
	popd && \
	rm $(NAME)/Chart.yaml && \
	tar -cf ../$(NAME).tar --xform 's,$(NAME)/,,' $(NAME)/* && \
	popd && \
	rm -rf $$tmpdir
