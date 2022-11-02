NAME = trento-server

default: verify-deps clean tar

verify-deps:
	@yq -V | grep -q "version 4." >/dev/null 2>&1 || ( echo "yq 4.x not found" && false )
	@helm version | grep -q "Version" >/dev/null 2>&1 || ( echo "helm not found" && false )

clean:
	rm -f *.tar
tar:
	osc service disabledrun
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
