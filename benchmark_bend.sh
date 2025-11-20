#!/bin/bash

BITONIC_ALGORITHM="bitonic_sort.bend"
NATIVE_CUDA_BINARY="bitonic_sort_cuda"
ITERATIONS=${1:-3}  
BITONIC_DEPTH=${2:-18}
RESULTS_DIR="benchmark_results"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$RESULTS_DIR"

echo "=========================================="
echo "Unified Bend Benchmark"
echo "=========================================="
echo "Algoritmo:"
echo "  $BITONIC_ALGORITHM (depth: $BITONIC_DEPTH, 2^$BITONIC_DEPTH = $((2**BITONIC_DEPTH)) elementos)"
echo "  Native CUDA: $NATIVE_CUDA_BINARY"
echo "Iterações: $ITERATIONS"
echo "Timestamp: $TIMESTAMP"
echo "=========================================="
echo ""

if [ ! -f "$BITONIC_ALGORITHM" ]; then
    echo "ERRO: $BITONIC_ALGORITHM não encontrado!"
    exit 1
fi

if [ ! -f "$NATIVE_CUDA_BINARY" ]; then
    echo "AVISO: $NATIVE_CUDA_BINARY não encontrado! Compile com: nvcc -O3 -o $NATIVE_CUDA_BINARY bitonic_sort_cuda.cu"
    echo "Continuando sem benchmark nativo CUDA..."
    NATIVE_CUDA_AVAILABLE=0
else
    NATIVE_CUDA_AVAILABLE=1
fi

extract_metrics() {
    local output="$1"
    # Extract TIME: value - look for line with TIME: and extract number before 's'
    local time=$(echo "$output" | grep -E "TIME:" | sed -n 's/.*TIME:[[:space:]]*\([0-9.]*\)s\?.*/\1/p' | head -1)
    [[ -z "$time" ]] && time="N/A"
    
    # Extract MIPS: value
    local mips=$(echo "$output" | grep -E "MIPS:" | sed -n 's/.*MIPS:[[:space:]]*\([0-9.]*\).*/\1/p' | head -1)
    [[ -z "$mips" ]] && mips="N/A"
    
    # Extract ITRS: value
    local itrs=$(echo "$output" | grep -E "ITRS:" | sed -n 's/.*ITRS:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)
    [[ -z "$itrs" ]] && itrs="N/A"
    
    echo "$time|$mips|$itrs"
}

declare -a bitonic_rust_times
declare -a bitonic_c_times
declare -a bitonic_cuda_times
declare -a bitonic_rust_mips
declare -a bitonic_c_mips
declare -a bitonic_cuda_mips

declare -a native_cuda_times

echo "=========================================="
echo "BITONIC SORT - Bend Backends"
echo "=========================================="
echo ""

echo "--- Rust Interpreter (Sequential CPU) ---"
for i in $(seq 1 $ITERATIONS); do
    echo -n "  Execução $i/$ITERATIONS: "
    start_time=$(date +%s.%N)
    output=$(bend run-rs "$BITONIC_ALGORITHM" "$BITONIC_DEPTH" -s 2>&1)
    end_time=$(date +%s.%N)
    elapsed=$(echo "$end_time - $start_time" | bc)
    
    metrics=$(extract_metrics "$output")
    time=$(echo "$metrics" | cut -d'|' -f1)
    mips=$(echo "$metrics" | cut -d'|' -f2)
    itrs=$(echo "$metrics" | cut -d'|' -f3)
    
    if [ "$time" != "N/A" ]; then
        bitonic_rust_times+=($time)
        bitonic_rust_mips+=($mips)
        echo "Tempo: ${time}s, MIPS: $mips"
    else
        echo "FALHOU"
    fi
done
echo ""

echo "--- C Interpreter (Parallel CPU) ---"
for i in $(seq 1 $ITERATIONS); do
    echo -n "  Execução $i/$ITERATIONS: "
    start_time=$(date +%s.%N)
    output=$(bend run-c "$BITONIC_ALGORITHM" "$BITONIC_DEPTH" -s 2>&1)
    end_time=$(date +%s.%N)
    elapsed=$(echo "$end_time - $start_time" | bc)
    
    metrics=$(extract_metrics "$output")
    time=$(echo "$metrics" | cut -d'|' -f1)
    mips=$(echo "$metrics" | cut -d'|' -f2)
    itrs=$(echo "$metrics" | cut -d'|' -f3)
    
    if [ "$time" != "N/A" ]; then
        bitonic_c_times+=($time)
        bitonic_c_mips+=($mips)
        echo "Tempo: ${time}s, MIPS: $mips"
    else
        echo "FALHOU"
    fi
done
echo ""

echo "--- CUDA Interpreter (GPU) ---"
for i in $(seq 1 $ITERATIONS); do
    echo -n "  Execução $i/$ITERATIONS: "
    start_time=$(date +%s.%N)
    output=$(bend run-cu "$BITONIC_ALGORITHM" "$BITONIC_DEPTH" -s 2>&1)
    end_time=$(date +%s.%N)
    elapsed=$(echo "$end_time - $start_time" | bc)
    
    metrics=$(extract_metrics "$output")
    time=$(echo "$metrics" | cut -d'|' -f1)
    mips=$(echo "$metrics" | cut -d'|' -f2)
    itrs=$(echo "$metrics" | cut -d'|' -f3)
    
    if [ "$time" != "N/A" ]; then
        bitonic_cuda_times+=($time)
        bitonic_cuda_mips+=($mips)
        echo "Tempo: ${time}s, MIPS: $mips"
    else
        echo "FALHOU"
    fi
done
echo ""

if [ "$NATIVE_CUDA_AVAILABLE" -eq 1 ]; then
    echo "=========================================="
    echo "BITONIC SORT - Native CUDA"
    echo "=========================================="
    echo ""
    
    echo "--- Native CUDA Bitonic Sort (GPU) ---"
    for i in $(seq 1 $ITERATIONS); do
        echo -n "  Execução $i/$ITERATIONS: "
        start_time=$(date +%s.%N)
        output=$(./"$NATIVE_CUDA_BINARY" "$BITONIC_DEPTH" 2>&1)
        end_time=$(date +%s.%N)
        elapsed=$(echo "$end_time - $start_time" | bc)
        
        metrics=$(extract_metrics "$output")
        time=$(echo "$metrics" | cut -d'|' -f1)
        mips=$(echo "$metrics" | cut -d'|' -f2)
        itrs=$(echo "$metrics" | cut -d'|' -f3)
        
        if [ "$time" != "N/A" ]; then
            native_cuda_times+=($time)
            echo "Tempo: ${time}s"
        else
            echo "FALHOU"
        fi
    done
    echo ""
fi

calculate_avg() {
    local arr=("$@")
    local sum=0
    local count=0
    for val in "${arr[@]}"; do
        # Only process numeric values (including decimals starting with . like .970)
        if [[ "$val" =~ ^[0-9]+\.?[0-9]*$ ]] || [[ "$val" =~ ^[0-9]*\.[0-9]+$ ]]; then
            if [[ "$val" != "N/A" ]]; then
                # Normalize values starting with . to 0.
                if [[ "$val" =~ ^\.[0-9]+$ ]]; then
                    val="0$val"
                fi
                sum=$(echo "$sum + $val" | bc -l)
                count=$((count + 1))
            fi
        fi
    done
    if [ $count -eq 0 ]; then
        echo "0"
        return
    fi
    result=$(echo "scale=3; $sum / $count" | bc -l)
    # Ensure result has leading zero if it starts with decimal point
    if [[ "$result" =~ ^\.[0-9]+$ ]]; then
        result="0$result"
    fi
    echo "$result"
}

calculate_speedup() {
    local baseline="$1"
    local current="$2"
    if [ -z "$baseline" ] || [ "$baseline" = "0" ] || [ -z "$current" ] || [ "$current" = "0" ]; then
        echo "N/A"
        return
    fi
    # Normalize values if they start with decimal point
    if [[ "$baseline" =~ ^\.[0-9]+$ ]]; then
        baseline="0$baseline"
    fi
    if [[ "$current" =~ ^\.[0-9]+$ ]]; then
        current="0$current"
    fi
    # Check if values are numeric
    if [[ "$baseline" =~ ^[0-9]+\.?[0-9]*$ ]] && [[ "$current" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        speedup=$(echo "scale=2; $baseline / $current" | bc -l 2>/dev/null)
        speedup=$(echo "$speedup" | xargs)
        # Ensure leading zero if starts with decimal
        if [[ "$speedup" =~ ^\.[0-9]+$ ]]; then
            speedup="0$speedup"
        fi
        # Verify it's a valid number
        if [[ "$speedup" =~ ^[0-9]+\.?[0-9]*$ ]] || [[ "$speedup" =~ ^[0-9]*\.[0-9]+$ ]]; then
            echo "$speedup"
        else
            echo "N/A"
        fi
    else
        echo "N/A"
    fi
}

bitonic_rust_avg=$(calculate_avg "${bitonic_rust_times[@]}")
bitonic_rust_mips_avg=$(calculate_avg "${bitonic_rust_mips[@]}")
bitonic_c_avg=$(calculate_avg "${bitonic_c_times[@]}")
bitonic_c_mips_avg=$(calculate_avg "${bitonic_c_mips[@]}")
bitonic_cuda_avg=$(calculate_avg "${bitonic_cuda_times[@]}")
bitonic_cuda_mips_avg=$(calculate_avg "${bitonic_cuda_mips[@]}")

if [ "$NATIVE_CUDA_AVAILABLE" -eq 1 ]; then
    native_cuda_avg=$(calculate_avg "${native_cuda_times[@]}")
fi

echo "=========================================="
echo "RESUMO DO BENCHMARK"
echo "=========================================="
echo ""
echo "--- Bitonic Sort (depth: $BITONIC_DEPTH) ---"
printf "%-35s %-15s %-15s %-10s\n" "Backend" "Tempo Médio (s)" "MIPS Médio" "Speedup"
echo "----------------------------------------------------------------------"

if [ ${#bitonic_rust_times[@]} -gt 0 ]; then
    printf "%-35s %-15s %-15s %-10s\n" "Rust Interpreter (Sequential)" "$bitonic_rust_avg" "$bitonic_rust_mips_avg" "1.00x"
    bitonic_baseline=$bitonic_rust_avg
fi

if [ ${#bitonic_c_times[@]} -gt 0 ]; then
    bitonic_c_speedup=$(calculate_speedup "$bitonic_baseline" "$bitonic_c_avg")
    printf "%-35s %-15s %-15s %-10s\n" "C Interpreter (Parallel CPU)" "$bitonic_c_avg" "$bitonic_c_mips_avg" "${bitonic_c_speedup}x"
fi

if [ ${#bitonic_cuda_times[@]} -gt 0 ]; then
    bitonic_cuda_speedup=$(calculate_speedup "$bitonic_baseline" "$bitonic_cuda_avg")
    printf "%-35s %-15s %-15s %-10s\n" "CUDA Interpreter (GPU)" "$bitonic_cuda_avg" "$bitonic_cuda_mips_avg" "${bitonic_cuda_speedup}x"
fi

if [ "$NATIVE_CUDA_AVAILABLE" -eq 1 ] && [ ${#native_cuda_times[@]} -gt 0 ]; then
    native_cuda_speedup=$(calculate_speedup "$bitonic_baseline" "$native_cuda_avg")
    printf "%-35s %-15s %-15s %-10s\n" "Native CUDA (GPU)" "$native_cuda_avg" "N/A" "${native_cuda_speedup}x"
fi

echo ""
echo "=========================================="
echo "ANÁLISE DE SPEEDUP"
echo "=========================================="

if [ ${#bitonic_rust_times[@]} -gt 0 ] && [ ${#bitonic_c_times[@]} -gt 0 ]; then
    speedup=$(calculate_speedup "$bitonic_rust_avg" "$bitonic_c_avg")
    if [ "$speedup" != "N/A" ]; then
        echo "Bitonic Sort - Rust → C:      ${speedup}x mais rápido"
    fi
fi
if [ ${#bitonic_rust_times[@]} -gt 0 ] && [ ${#bitonic_cuda_times[@]} -gt 0 ]; then
    speedup=$(calculate_speedup "$bitonic_rust_avg" "$bitonic_cuda_avg")
    if [ "$speedup" != "N/A" ]; then
        echo "Bitonic Sort - Rust → CUDA:   ${speedup}x mais rápido"
    fi
fi
if [ ${#bitonic_c_times[@]} -gt 0 ] && [ ${#bitonic_cuda_times[@]} -gt 0 ]; then
    speedup=$(calculate_speedup "$bitonic_c_avg" "$bitonic_cuda_avg")
    if [ "$speedup" != "N/A" ]; then
        echo "Bitonic Sort - C → CUDA:      ${speedup}x mais rápido"
    fi
fi

if [ "$NATIVE_CUDA_AVAILABLE" -eq 1 ] && [ ${#bitonic_rust_times[@]} -gt 0 ] && [ ${#native_cuda_times[@]} -gt 0 ]; then
    speedup=$(calculate_speedup "$bitonic_rust_avg" "$native_cuda_avg")
    if [ "$speedup" != "N/A" ]; then
        echo "Bitonic Sort - Rust → Native CUDA: ${speedup}x mais rápido"
    fi
fi
if [ "$NATIVE_CUDA_AVAILABLE" -eq 1 ] && [ ${#bitonic_c_times[@]} -gt 0 ] && [ ${#native_cuda_times[@]} -gt 0 ]; then
    speedup=$(calculate_speedup "$bitonic_c_avg" "$native_cuda_avg")
    if [ "$speedup" != "N/A" ]; then
        echo "Bitonic Sort - C → Native CUDA:    ${speedup}x mais rápido"
    fi
fi
if [ "$NATIVE_CUDA_AVAILABLE" -eq 1 ] && [ ${#bitonic_cuda_times[@]} -gt 0 ] && [ ${#native_cuda_times[@]} -gt 0 ]; then
    speedup=$(calculate_speedup "$bitonic_cuda_avg" "$native_cuda_avg")
    if [ "$speedup" != "N/A" ]; then
        echo "Bitonic Sort - Bend CUDA → Native CUDA: ${speedup}x mais rápido"
    fi
fi

echo ""
echo "Resultados salvos em: $RESULTS_DIR/bend_benchmark_${TIMESTAMP}.txt"

{
    echo "======================================================================"
    echo "RESULTADOS DO BENCHMARK UNIFICADO DE BEND"
    echo "======================================================================"
    echo "Data: $(date)"
    echo "Algoritmo:"
    echo "  $BITONIC_ALGORITHM (depth: $BITONIC_DEPTH, 2^$BITONIC_DEPTH = $((2**BITONIC_DEPTH)) elementos)"
    if [ "$NATIVE_CUDA_AVAILABLE" -eq 1 ]; then
        echo "  Native CUDA: $NATIVE_CUDA_BINARY"
    fi
    echo "Iterações: $ITERATIONS"
    echo "======================================================================"
    echo ""
    
    echo "RESULTADOS INDIVIDUAIS - BITONIC SORT"
    echo "----------------------------------------------------------------------"
    
    if [ ${#bitonic_rust_times[@]} -gt 0 ]; then
        echo ""
        echo "Rust Interpreter (Sequential CPU):"
        for i in $(seq 0 $((${#bitonic_rust_times[@]} - 1))); do
            echo "  Execução $((i+1))/$ITERATIONS: Tempo: ${bitonic_rust_times[$i]}s, MIPS: ${bitonic_rust_mips[$i]}"
        done
    fi
    
    if [ ${#bitonic_c_times[@]} -gt 0 ]; then
        echo ""
        echo "C Interpreter (Parallel CPU):"
        for i in $(seq 0 $((${#bitonic_c_times[@]} - 1))); do
            echo "  Execução $((i+1))/$ITERATIONS: Tempo: ${bitonic_c_times[$i]}s, MIPS: ${bitonic_c_mips[$i]}"
        done
    fi
    
    if [ ${#bitonic_cuda_times[@]} -gt 0 ]; then
        echo ""
        echo "CUDA Interpreter (GPU):"
        for i in $(seq 0 $((${#bitonic_cuda_times[@]} - 1))); do
            echo "  Execução $((i+1))/$ITERATIONS: Tempo: ${bitonic_cuda_times[$i]}s, MIPS: ${bitonic_cuda_mips[$i]}"
        done
    fi
    
    if [ "$NATIVE_CUDA_AVAILABLE" -eq 1 ] && [ ${#native_cuda_times[@]} -gt 0 ]; then
        echo ""
        echo "RESULTADOS INDIVIDUAIS - NATIVE CUDA"
        echo "----------------------------------------------------------------------"
        echo ""
        echo "Native CUDA Bitonic Sort (GPU):"
        for i in $(seq 0 $((${#native_cuda_times[@]} - 1))); do
            echo "  Execução $((i+1))/$ITERATIONS: Tempo: ${native_cuda_times[$i]}s"
        done
    fi
    
    echo ""
    echo "======================================================================"
    echo "RESUMO DO BENCHMARK"
    echo "======================================================================"
    echo ""
    echo "--- Bitonic Sort (depth: $BITONIC_DEPTH) ---"
    printf "%-35s %-15s %-15s %-10s\n" "Backend" "Tempo Médio (s)" "MIPS Médio" "Speedup"
    echo "----------------------------------------------------------------------"
    
    if [ ${#bitonic_rust_times[@]} -gt 0 ]; then
        printf "%-35s %-15s %-15s %-10s\n" "Rust Interpreter (Sequential)" "$bitonic_rust_avg" "$bitonic_rust_mips_avg" "1.00x"
    fi
    
    if [ ${#bitonic_c_times[@]} -gt 0 ]; then
        bitonic_c_speedup=$(calculate_speedup "$bitonic_rust_avg" "$bitonic_c_avg")
        printf "%-35s %-15s %-15s %-10s\n" "C Interpreter (Parallel CPU)" "$bitonic_c_avg" "$bitonic_c_mips_avg" "${bitonic_c_speedup}x"
    fi
    
    if [ ${#bitonic_cuda_times[@]} -gt 0 ]; then
        bitonic_cuda_speedup=$(calculate_speedup "$bitonic_rust_avg" "$bitonic_cuda_avg")
        printf "%-35s %-15s %-15s %-10s\n" "CUDA Interpreter (GPU)" "$bitonic_cuda_avg" "$bitonic_cuda_mips_avg" "${bitonic_cuda_speedup}x"
    fi
    
    if [ "$NATIVE_CUDA_AVAILABLE" -eq 1 ] && [ ${#native_cuda_times[@]} -gt 0 ]; then
        native_cuda_speedup=$(calculate_speedup "$bitonic_rust_avg" "$native_cuda_avg")
        printf "%-35s %-15s %-15s %-10s\n" "Native CUDA (GPU)" "$native_cuda_avg" "N/A" "${native_cuda_speedup}x"
    fi
    
    echo ""
    echo "======================================================================"
    echo "ANÁLISE DE SPEEDUP"
    echo "======================================================================"
    
    if [ ${#bitonic_rust_times[@]} -gt 0 ] && [ ${#bitonic_c_times[@]} -gt 0 ]; then
        speedup=$(calculate_speedup "$bitonic_rust_avg" "$bitonic_c_avg")
        if [ "$speedup" != "N/A" ]; then
            echo "Bitonic Sort - Rust → C:      ${speedup}x mais rápido"
        fi
    fi
    if [ ${#bitonic_rust_times[@]} -gt 0 ] && [ ${#bitonic_cuda_times[@]} -gt 0 ]; then
        speedup=$(calculate_speedup "$bitonic_rust_avg" "$bitonic_cuda_avg")
        if [ "$speedup" != "N/A" ]; then
            echo "Bitonic Sort - Rust → CUDA:   ${speedup}x mais rápido"
        fi
    fi
    if [ ${#bitonic_c_times[@]} -gt 0 ] && [ ${#bitonic_cuda_times[@]} -gt 0 ]; then
        speedup=$(calculate_speedup "$bitonic_c_avg" "$bitonic_cuda_avg")
        if [ "$speedup" != "N/A" ]; then
            echo "Bitonic Sort - C → CUDA:      ${speedup}x mais rápido"
        fi
    fi
    
    if [ "$NATIVE_CUDA_AVAILABLE" -eq 1 ] && [ ${#bitonic_rust_times[@]} -gt 0 ] && [ ${#native_cuda_times[@]} -gt 0 ]; then
        speedup=$(calculate_speedup "$bitonic_rust_avg" "$native_cuda_avg")
        if [ "$speedup" != "N/A" ]; then
            echo "Bitonic Sort - Rust → Native CUDA: ${speedup}x mais rápido"
        fi
    fi
    if [ "$NATIVE_CUDA_AVAILABLE" -eq 1 ] && [ ${#bitonic_c_times[@]} -gt 0 ] && [ ${#native_cuda_times[@]} -gt 0 ]; then
        speedup=$(calculate_speedup "$bitonic_c_avg" "$native_cuda_avg")
        if [ "$speedup" != "N/A" ]; then
            echo "Bitonic Sort - C → Native CUDA:    ${speedup}x mais rápido"
        fi
    fi
    if [ "$NATIVE_CUDA_AVAILABLE" -eq 1 ] && [ ${#bitonic_cuda_times[@]} -gt 0 ] && [ ${#native_cuda_times[@]} -gt 0 ]; then
        speedup=$(calculate_speedup "$bitonic_cuda_avg" "$native_cuda_avg")
        if [ "$speedup" != "N/A" ]; then
            echo "Bitonic Sort - Bend CUDA → Native CUDA: ${speedup}x mais rápido"
        fi
    fi
    
    echo ""
    echo "======================================================================"
    echo "DADOS BRUTOS"
    echo "======================================================================"
    echo "Bitonic Sort - Tempos Rust (s): ${bitonic_rust_times[@]}"
    echo "Bitonic Sort - MIPS Rust: ${bitonic_rust_mips[@]}"
    echo "Bitonic Sort - Tempos C (s): ${bitonic_c_times[@]}"
    echo "Bitonic Sort - MIPS C: ${bitonic_c_mips[@]}"
    echo "Bitonic Sort - Tempos CUDA (s): ${bitonic_cuda_times[@]}"
    echo "Bitonic Sort - MIPS CUDA: ${bitonic_cuda_mips[@]}"
    if [ "$NATIVE_CUDA_AVAILABLE" -eq 1 ]; then
        echo "Native CUDA - Tempos (s): ${native_cuda_times[@]}"
    fi
    echo "======================================================================"
} > "$RESULTS_DIR/bend_benchmark_${TIMESTAMP}.txt"

echo ""
echo "Benchmark concluído!"
