#!/bin/bash
# Scoreboard mutation check: har MUT value par bringup_test chalao, nateeja jama karo.
# Pehle "make compile" chalana zaroori hai.
cd "$(dirname "$0")/out/build" || { echo "out/build nahi mila: pehle make compile chalayein"; exit 1; }
printf "%-5s %-13s %-10s\n" "MUT" "RESULT" "UVM_ERROR"
for m in 0 1 2 3 4 5 6; do
  ./simv +UVM_TESTNAME=bringup_test +UVM_VERBOSITY=UVM_LOW +UVM_NO_RELNOTES +MUT=$m -l mut_$m.log > /dev/null 2>&1
  res=$(grep -o "TEST PASSED\|TEST FAILED" mut_$m.log | head -1)
  err=$(grep -E "^UVM_ERROR :" mut_$m.log | tail -1 | awk '{print $3}')
  printf "%-5s %-13s %-10s\n" "$m" "$res" "$err"
done
