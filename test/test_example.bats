   #!/usr/bin/env bats

   @test "Verify that print_message function works" {
     run bash -c '. lib/lib.sh; print_message INFO "Test message"'
     [ "$status" -eq 0 ]
     [[ "$output" =~ "Test message" ]]
   }
