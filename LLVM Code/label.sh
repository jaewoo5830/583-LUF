#!/bin/bash

count=0
# Check if the directory exists
if [ -d "./training_data" ]; then
    # Loop through each .c file with numbers in their names and write their names to output.txt
    for file in ./training_data/*.c; do
        filename=$(basename "$file")
        # result=$(expr $count % 2)
        # if [ $result -eq 0 ]; then
        #     echo "$count iterations finished"
        # fi
        

    
        # clang -emit-llvm -c ./training_data/$file.c -Xclang -disable-O0-optnone -o $file.bc
        if echo "$filename" | grep -q '[0-9]'; then
            echo $filename
            times=()
            times+=($filename)
            for unroll in 1 2 4 8 16 32 64 128; do
                
                # clang -emit-llvm -c ./training_data/$file.c -Xclang -disable-O0-optnone -o exec.o
                clang -O3 -mllvm -unroll-count=$unroll $file ./training_data/header.c -o exec.o

                # clang -O3 -mllvm -unroll-count=$unroll $file -o benanddaniel.o
                # clang -emit-llvm -c ./training_data/header.c -Xclang -disable-O0-optnone -o header.bc
                # llvm-link benanddaniel.o header.bc -o test.o

                time=$(./exec.o)
                times+=($time)

                rm exec.o
            done
            # Join array elements by commas
            IFS=, # Internal Field Separator set to comma
            joinedElements="${times[*]}" # Join elements

            echo "$joinedElements" >> output.txt
        fi
        count=$((count + 1))
    done
else
    echo "Directory './training_data' not found."
fi

# clang -O3 -mllvm -unroll-factor=4 your_program.c -o your_program
