#!/bin/bash
# Checkpoint Test Script


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="$(dirname "$(dirname "$SCRIPT_DIR")")/lib/lib.sh"

if [ -f "$LIB_PATH" ]; then
    . "$LIB_PATH"
else
    echo "Error: Cannot find lib.sh at $LIB_PATH" >&2
    exit 1
fi
set -o errtrace
set -o functrace
set_error_trap

export DRY_RUN="${DRY_RUN:-false}"

verify_checkpoint() {
    local expected="$1"
    local actual=$(cat "$CHECKPOINT_FILE")
    if [[ "$actual" != "$expected" ]]; then
        print_message ERROR "Checkpoint mismatch. Expected: $expected, Actual: $actual"
        return 1
    fi
    return 0
}

run_test() {
    local test_name="$1"
    local test_function="$2"
    print_message INFO "Running test: $test_name"
    if $test_function; then
        print_message OK "Test passed: $test_name"
    else
        print_message ERROR "Test failed: $test_name"
        exit 1
    fi
}

test_stage_checkpoint() {
    save_checkpoint "stage" "test-stage"
    verify_checkpoint "test-stage|||0"
}

test_script_checkpoint() {
    save_checkpoint "script" "test-script.sh"
    verify_checkpoint "test-stage|test-script.sh||0"
}

test_function_checkpoint() {
    save_checkpoint "function" "test_function"
    verify_checkpoint "test-stage|test-script.sh|test_function|0"
}

test_command_checkpoint() {
    save_checkpoint "command" "1"
    verify_checkpoint "test-stage|test-script.sh|test_function|1"
}

test_error_handling() {
    if ! save_checkpoint "invalid" "test" 2>/dev/null; then
        print_message OK "Error handling for invalid checkpoint type works"
        return 0
    else
        print_message ERROR "Error handling for invalid checkpoint type failed"
        return 1
    fi
}

test_resumption() {
    save_checkpoint "stage" "resume-test"
    save_checkpoint "script" "resume-script.sh"
    save_checkpoint "function" "resume_function"
    save_checkpoint "command" "3"
    
    # Mock resume_from_checkpoint function for testing
resume_from_checkpoint() {
        print_message INFO "Mocked resume_from_checkpoint called"
        verify_checkpoint "resume-test|resume-script.sh|resume_function|3"
    }
    
    resume_from_checkpoint
}

main() {
    process_init "Testing checkpoints"
    print_message INFO "Starting checkpoint tests"
    print_message INFO "DRY_RUN is set to: ${YELLOW}$DRY_RUN"

    run_test "Stage Checkpoint" test_stage_checkpoint
    run_test "Script Checkpoint" test_script_checkpoint
    run_test "Function Checkpoint" test_function_checkpoint
    run_test "Command Checkpoint" test_command_checkpoint
    run_test "Error Handling" test_error_handling
    run_test "Resumption" test_resumption

    print_message OK "All checkpoint tests completed successfully"
    process_end $?
}

main "$@"
exit $?
