NAME = trento-server

default: verify-deps clean tar

verify-deps:
	@yq -V | grep -q "yq version 3." >/dev/null 2>&1 || ( echo "yq 3.x not found; see https://github.com/marketplace/actions/yq-portable-yaml-processor" && false )
	@# For yq 3.x we need to get https://github.com/mikefarah/yq/issues/677 fixed
	@# then use
	@# yq eval-all 'select(fileIndex == 0) * select(fileIndex == 1)' $(NAME)/values.yaml ../values-overwrite.yaml
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
	    echo -e "$$(yq m -x $(NAME)/values.yaml ../values-overwrite.yaml)" > $(NAME)/values.yaml; \
	fi && \
	pushd $(NAME) && \
	helm dependency update && \
	popd && \
	rm $(NAME)/Chart.yaml && \
	tar -cf ../$(NAME).tar --xform 's,$(NAME)/,,' $(NAME)/* && \
	popd && \
	rm -rf $$tmpdir
