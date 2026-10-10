#!/bin/bash
# Milestone 2: RTL lint with VCS (+lint=all) on the same file list used for compile
cd "$(dirname "$0")"
rm -rf out/lint
mkdir -p out/lint
vcs -sverilog -full64 -f build.flist -timescale=1ns/1ps +lint=all \
    -Mdir=out/lint/csrc -o out/lint/simv -l out/lint/lint.log
cp out/lint/lint.log ../results/lint_vcs.log
echo "-----------------------------------------"
echo "Total lint/warning messages: $(grep -cE '^(Lint|Warning)-\[' out/lint/lint.log)"
grep -oE '^(Lint|Warning)-\[[A-Za-z-]+\]' out/lint/lint.log | sort | uniq -c | sort -rn
