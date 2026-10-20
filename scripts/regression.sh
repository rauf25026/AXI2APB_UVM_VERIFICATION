#!/bin/bash
# Regression: har test ko kai seeds par chalao. Pehle "make compile" chalana zaroori hai.
cd "$(dirname "$0")/out/build" || { echo "out/build nahi mila: pehle make compile chalayein"; exit 1; }
TESTS="bringup_test wr_wait_test rd_wait_test b2b_wr_test b2b_rd_test mixed_rw_test pslverr_test random_wide_test"
SEEDS="1 2 3"
pass=0; fail=0
printf "%-20s %-5s %-12s %-10s %s\n" TEST SEED RESULT MATCHED FUNC_COV
for t in $TESTS; do
  for s in $SEEDS; do
    log=${t}_s${s}.log
    ./simv +vcs+lic+wait -cm line+cond+fsm+tgl+branch -cm_name ${t}_s${s} \
        +UVM_TESTNAME=$t +UVM_VERBOSITY=UVM_LOW +UVM_NO_RELNOTES +ntb_random_seed=$s \
        -l $log > /dev/null 2>&1
    res=$(grep -o "TEST PASSED\|TEST FAILED" $log | head -1)
    [ -z "$res" ] && res="NO RESULT"
    m=$(grep -o "writes matched=[0-9]* reads matched=[0-9]*" $log | head -1 | sed 's/writes matched=/W/; s/ reads matched=/ R/')
    cov=$(grep -o "axi=[0-9.]*% apb=[0-9.]*%" $log | head -1)
    printf "%-20s %-5s %-12s %-10s %s\n" "$t" "$s" "$res" "$m" "$cov"
    if [ "$res" = "TEST PASSED" ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
  done
done
echo "TOTAL: $pass passed, $fail failed"
