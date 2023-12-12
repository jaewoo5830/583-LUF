#!/bin/bash


# ACTION REQUIRED: Ensure that the path to the library and pass name are correct.
PATH2LIB="./build/pass/FeaturePass.so"
PASS=feature-pass

TRAINING_DIR=training_data/hi # TODO: 0 1 2 3
for file in $TRAINING_DIR/*.c; do
    filename=$(basename "$file")
    if echo "$filename" | grep -q '[0-9]'; then
        echo $filename

        # Delete outputs from previous runs. Update this if you want to retain some files across runs.
        rm -f default.profraw *_prof *_fplicm *.bc *.profdata *_output *.ll *.in *.in.Z

        # Convert source code to bitcode (IR).
        # clang -emit-llvm -c ${TRAINING_DIR}/${FILE} ${TRAINING_DIR}/header.c -Xclang -disable-O0-optnone -o file.bc

        clang -emit-llvm -c ${TRAINING_DIR}/${filename} -Xclang -disable-O0-optnone -o file.bc
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
        echo -n $filename"," >> data.csv
        opt --disable-output -load-pass-plugin="${PATH2LIB}" -passes="${PASS}" file.profdata.bc

        # Cleanup: Remove this if you want to retain the created files.
        rm -f *.in *.in.Z default.profraw *_prof *_fplicm *.bc *.profdata *_output *.ll words
    fi
done