#!/bin/bash
# Fixpoint test for the Blaise self-hosting check.
#
# Steps:
#   1. Clean rebuild compiler (removes stale .ppu/.o files).
#   2. Rebuild + install RTL (cheap when nothing changed).
#   3. stage1 -> stage2 IR (FPC-built binary compiles current source).
#   4. Assemble + link stage-2 binary via QBE + gcc.
#   5. stage2 -> stage3 IR (self-compiled binary compiles same source).
#   6. diff stage-2.ssa stage-3.ssa  => empty = clean fixpoint.
#
# A 5-minute timeout is wrapped around the stage-2 invocation so a hung
# self-compiled binary doesn't lock the whole bisect loop.

set -e

# Must be run from the project root (where pasbuild.xml lives).
if [ ! -f "compiler/src/main/pascal/Blaise.pas" ]; then
  echo "Run this script from the project root: ./scripts/fixpoint.sh" >&2
  exit 1
fi

echo "[1/6] clean + rebuild compiler"
pasbuild clean > /tmp/fp_clean.log 2>&1
pasbuild compile -m blaise-compiler > /tmp/fp_compile.log 2>&1
if [ ! -x compiler/target/blaise ]; then
  echo "COMPILE_FAIL"
  tail -10 /tmp/fp_compile.log
  exit 10
fi

echo "[2/6] rebuild + install RTL"
( cd rtl && make > /tmp/fp_rtl.log 2>&1 && make install >> /tmp/fp_rtl.log 2>&1 ) || {
  echo "RTL_FAIL"; tail -5 /tmp/fp_rtl.log; exit 11;
}

echo "[3/6] stage1 -> stage2 IR"
compiler/target/blaise --source compiler/src/main/pascal/Blaise.pas \
  --unit-path compiler/src/main/pascal --unit-path rtl/src/main/pascal \
  --emit-ir > /tmp/fp_stage2.ssa 2>/tmp/fp_stage2.err
if [ ! -s /tmp/fp_stage2.ssa ] || head -1 /tmp/fp_stage2.ssa | grep -qi 'error\|exception'; then
  echo "STAGE2_IR_FAIL"
  head -3 /tmp/fp_stage2.ssa
  head -3 /tmp/fp_stage2.err
  exit 1
fi
echo "      stage2 IR: $(wc -l < /tmp/fp_stage2.ssa) lines"

echo "[4/6] assemble + link stage-2 binary"
vendor/qbe/qbe -o /tmp/fp_stage2.s /tmp/fp_stage2.ssa 2>/tmp/fp_qbe.err || {
  echo "QBE_FAIL"; cat /tmp/fp_qbe.err; exit 2;
}
gcc -o /tmp/fp_blaise2 /tmp/fp_stage2.s compiler/target/blaise_rtl.a 2>/tmp/fp_gcc.err || {
  echo "GCC_FAIL"; cat /tmp/fp_gcc.err; exit 3;
}

echo "[5/6] stage2 -> stage3 IR (5min timeout)"
timeout 300 /tmp/fp_blaise2 --source compiler/src/main/pascal/Blaise.pas \
  --unit-path compiler/src/main/pascal --unit-path rtl/src/main/pascal \
  --emit-ir > /tmp/fp_stage3.ssa 2>/tmp/fp_stage3.err
RC=$?
if [ $RC -eq 124 ]; then
  echo "STAGE3_TIMEOUT"
  exit 4
elif [ $RC -eq 139 ]; then
  echo "STAGE3_SEGFAULT"
  exit 4
elif [ $RC -ne 0 ]; then
  echo "STAGE3_FAIL rc=$RC"
  head -3 /tmp/fp_stage3.err
  exit 5
fi
echo "      stage3 IR: $(wc -l < /tmp/fp_stage3.ssa) lines"

echo "[6/6] compare"
DIFFLINES=$(diff /tmp/fp_stage2.ssa /tmp/fp_stage3.ssa | wc -l)
if [ $DIFFLINES -eq 0 ]; then
  echo "FIXPOINT_OK"
  exit 0
else
  echo "FIXPOINT_DIFF lines=$DIFFLINES"
  diff /tmp/fp_stage2.ssa /tmp/fp_stage3.ssa | head -20
  exit 6
fi
