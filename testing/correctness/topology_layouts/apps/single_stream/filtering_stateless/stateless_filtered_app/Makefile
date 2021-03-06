# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../../../../../Makefile
endif

# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

# uncomment to disable generate test related targets in this directory
TEST_TARGET := false

# uncomment to disable generate pony related targets (build/test/clean) for pony sources in this directory
#PONY_TARGET := false

# uncomment to disable generate exs related targets (build/test/clean) for elixir sources in this directory
EXS_TARGET := false

# uncomment to disable generate docker related targets (build/push) for Dockerfile in this directory
DOCKER_TARGET := false

# uncomment to disable generate recursing into Makefiles of subdirectories
# RECURSE_SUBMAKEFILES := false

SINGLE_STREAM_FILTERING_STATELESS_STATELESS_FILTERED_APP_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)


test-testing-correctness-topology_layouts-apps-single_stream-filtering_stateless-stateless_filtered_app: single_stream_filtering_stateless_stateless_filter_app_test

single_stream_filtering_stateless_stateless_filter_app_test:
	cd $(SINGLE_STREAM_FILTERING_STATELESS_STATELESS_FILTERED_APP_PATH) && \
	integration_test \
	--framed-file-sender ../../../data_gen/_test.msg \
	--validation-cmp \
	--expected-file ../../../data_gen/_expected.msg \
	--log-level error \
	--command './stateless_filtered_app' \
	--sink-expect 100

test-testing-correctness-topology_layouts-apps-single_stream-filtering_stateless-stateless_filtered_app: two_worker_single_stream_filtering_stateless_stateless_filter_app_test

two_worker_single_stream_filtering_stateless_stateless_filter_app_test:
	cd $(SINGLE_STREAM_FILTERING_STATELESS_STATELESS_FILTERED_APP_PATH) && \
	integration_test \
	--framed-file-sender ../../../data_gen/_test.msg \
	--workers 2 \
	--validation-cmp \
	--expected-file ../../../data_gen/_expected.msg \
	--log-level error \
	--command './stateless_filtered_app' \
	--sink-expect 100

test-testing-correctness-topology_layouts-apps-single_stream-filtering_stateless-stateless_filtered_app: three_worker_single_stream_filtering_stateless_stateless_filter_app_test

three_worker_single_stream_filtering_stateless_stateless_filter_app_test:
	cd $(SINGLE_STREAM_FILTERING_STATELESS_STATELESS_FILTERED_APP_PATH) && \
	integration_test \
	--framed-file-sender ../../../data_gen/_test.msg \
	--workers 3 \
	--validation-cmp \
	--expected-file ../../../data_gen/_expected.msg \
	--log-level error \
	--command './stateless_filtered_app' \
	--sink-expect 100

# end of prevent rules from being evaluated/included multiple times
endif
