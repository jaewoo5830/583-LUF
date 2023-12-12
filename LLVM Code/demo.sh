#!/bin/bash

echo "Input Filename:"
read filename

#-------------------------------------------------------------------------------------#
# Compile with llvm loop unrolling
echo "Compiling with LLVM loop unroll..."
clang -O0 -emit-llvm -S $filename -Xclang -disable-O0-optnone -o exec.ll
opt -passes="loop-unroll" -S exec.ll -o exec_unroll.ll
clang -O0 exec_unroll.ll -o exec.o


echo "Executing..."
start_time_base=$(date +%s%N)
./exec.o > /dev/null 2>&1
end_time_base=$(date +%s%N)
elapsed_time_base=$(( (end_time_base - start_time_base) / 1000000 ))

#-------------------------------------------------------------------------------------#
PATH2LIB="/home/azhuang/project/build/pass/FeaturePass.so"
PASS=feature-pass

# run feature extraction and put into a file
rm -f default.profraw *_prof *_fplicm *.bc *.profdata *_output *.ll *.in *.in.Z

# Convert source code to bitcode (IR).
clang -emit-llvm -c ${filename} -Xclang -disable-O0-optnone -o file.bc
# clang -emit-llvm -c ${TRAINING_DIR}/header.c -Xclang -disable-O0-optnone -o header.bc
# llvm-link main.bc header.bc -o file.bc

# Instrument profiler passes. Generates profile data.
opt -passes='pgo-instr-gen,instrprof' file.bc -o file.prof.bc

# Generate binary executable with profiler embedded
clang -fprofile-instr-generate file.prof.bc -o file_prof

# # When we run the profiler embedded executable, it generates a default.profraw file that contains the profile data.
./file_prof > /dev/null

# Converting it to LLVM form. This step can also be used to combine multiple profraw files,
# in case you want to include different profile runs together.
llvm-profdata merge -o file.profdata default.profraw

# The "Profile Guided Optimization Instrumentation-Use" pass attaches the profile data to the bc file.
opt -passes="pgo-instr-use" -o file.profdata.bc -pgo-test-profile-file="file.profdata" < file.bc

# Uncomment this and disable the cleanup if you want to "see" the instumented IR.
# llvm-dis ${1}.profdata.bc -o ${1}.prof.ll

# Runs your pass on the instrumented code.
rm -f demo_data.csv
echo "Extracting loop features..."
echo "Filename,Depth,TripCount,Total,FP,BR,Mem,Uses,Defs" >> demo_data.csv
echo -n $filename"," >> demo_data.csv
opt --disable-output -load-pass-plugin="${PATH2LIB}" -passes="${PASS}" file.profdata.bc

# Cleanup: Remove this if you want to retain the created files.
rm -f *.in *.in.Z default.profraw *_prof *_fplicm *.bc *.profdata *_output *.ll *.o words

#-------------------------------------------------------------------------------------#
# Make a prediction with the extracted features and compile using predicted unroll factor
models=("RandomForestClassifier" "XGBClassifier")
declare -A model_times

for model in "${models[@]}"; do
    unroll=$(python3 ./models/model_script.py demo_data.csv models/${model}) # TODO write script that loads model and outputs prediction
    echo "Predicted unroll factor: ${unroll}"
    echo "Executing..."
    clang -O0 -Xclang -disable-llvm-passes -unroll-count=$unroll -o exec.o $filename

    start_time_ml=$(date +%s%N)
    ./exec.o > /dev/null 2>&1
    end_time_ml=$(date +%s%N)
    elapsed_time_ml=$(( (end_time_ml - start_time_ml) / 1000000 ))

    model_times[$model]=$elapsed_time_ml
done

#-------------------------------------------------------------------------------------#
# Print results
echo "Baseline Measurement: ${elapsed_time_base} ms"
for model in "${!model_times[@]}"; do
    echo "${model%.*}: ${model_times[$model]} ms"
done