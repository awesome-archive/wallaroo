# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../../../Makefile
endif

# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

# uncomment to disable generate test related targets in this directory
TEST_TARGET := false

# uncomment to disable generate pony related targets (build/test/clean) for pony sources in this directory
#PONY_TARGET := false

# uncomment to disable generate exs related targets (build/test/clean) for elixir sources in this directory
#EXS_TARGET := false

# uncomment to disable generate docker related targets (build/push) for Dockerfile in this directory
#DOCKER_TARGET := false

# uncomment to disable generate recursing into Makefiles of subdirectories
#RECURSE_SUBMAKEFILES := false

VALIDATOR_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
VALIDATOR_EXAMPLES := $(VALIDATOR_PATH)/examples

# standard rules generation makefile
include $(rules_mk_path)


test-testing-correctness-apps-sequence_window-validator: validator_test
clean-testing-correctness-apps-sequence_window-validator: validator_clean

validator_clean:
	$(QUIET)rm -f $(VALIDATOR_PATH)/validator
	$(QUIET)rm -f $(VALIDATOR_PATH)/validator.o
	$(QUIET)rm -fr $(VALIDATOR_EXAMPLES)/*.txt

validator_test:
	$(QUIET)python $(VALIDATOR_EXAMPLES)/data_gen.py
	$(VALIDATOR_PATH)/validator -i $(VALIDATOR_EXAMPLES)/pass.txt
	$(VALIDATOR_PATH)/validator -i $(VALIDATOR_EXAMPLES)/pass_with_atleastonce.txt -a
	$(VALIDATOR_PATH)/validator -i $(VALIDATOR_EXAMPLES)/fail_expect_max.txt -e 1002

# end of prevent rules from being evaluated/included multiple times
endif

