# CUDA Project - Bend Parallel Algorithms Benchmark

Este projeto faz benchmark do algoritmo Bitonic Sort usando a linguagem de programação nativamente paralela [Bend](https://github.com/HigherOrderCO/Bend) ([HVM](https://github.com/HigherOrderCO/HVM)) e compara o desempenho entre diferentes backends de execução: interpretador Rust (sequencial), interpretador C (CPU paralelo), interpretador CUDA (GPU) e implementação nativa CUDA. Trabalho realizado para a matéria de Arquitetura avançadas de Computação.

## Sobre o Projeto

Este projeto permite comparar as capacidades de paralelização do Bend com uma implementação CUDA , demonstrando o desempenho do Bitonic Sort em diferentes ambientes de execução.

## Pré-requisitos

- **Rust e Cargo** - Para instalar Bend e HVM
- **Bend** - Linguagem de programação funcional paralela
- **HVM** - Runtime paralelo (instalado automaticamente com Bend)
- **bc** - Calculadora (necessária para os scripts)
- **CUDA** (opcional) - Para benchmarks GPU e implementação nativa CUDA

## Instalação

### 1. Instalar Rust e Cargo

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
```

### 2. Instalar Bend

```bash
cargo install bend-lang
```

### 3. Instalar HVM

```bash
cargo install hvm
```

### 4. Instalar bc

```bash
sudo apt install bc
```

### 5. Instalar CUDA (Opcional - para benchmarks GPU)

**Para WSL2:**
- Siga o guia oficial de instalação do CUDA para WSL2
- Download: https://developer.nvidia.com/cuda-downloads
- Selecione "Linux" → "x86_64" → "WSL-Ubuntu" → "deb (local)"

Após instalar, verifique:
```bash
nvcc --version
nvidia-smi
```

**Nota:** CUDA é necessário apenas para benchmarks GPU. Os benchmarks de CPU (Rust e C interpreters) funcionam sem CUDA.

### 6. Compilar Programa CUDA Nativo (Opcional)

Após instalar CUDA, compile o Bitonic Sort nativo:
```bash
nvcc -O3 -o bitonic_sort_cuda bitonic_sort_cuda.cu
```

**Nota:** O script de benchmark detecta automaticamente se o binário existe. Se estiver faltando, o script continuará mas pulará a comparação com CUDA nativo.

## Como Executar

### Executar Benchmark

```bash
./benchmark_bend.sh [iterações] [profundidade]
```

Exemplos:
```bash
./benchmark_bend.sh                    # Padrão: 3 iterações, profundidade 18
./benchmark_bend.sh 3                  # 3 iterações com profundidade padrão
./benchmark_bend.sh 3 18               # 3 iterações, profundidade 18 (262,144 elementos)
./benchmark_bend.sh 5 20               # 5 iterações, profundidade 20 (1,048,576 elementos)
```

**Parâmetros:**
- Primeiro parâmetro: número de iterações (padrão: 3)
- Segundo parâmetro: profundidade da árvore para bitonic_sort (padrão: 18, significa 2^18 = 262,144 elementos)
- Profundidade maior = mais elementos = tempo de execução maior

Os resultados são salvos no diretório `benchmark_results/` com timestamp.

### Teste Manual

Teste backends individuais:
```bash
# Bitonic Sort - Interpretador Rust (sequencial)
bend run-rs bitonic_sort.bend 18 -s

# Bitonic Sort - Interpretador C (CPU paralelo)
bend run-c bitonic_sort.bend 18 -s

# Bitonic Sort - Interpretador CUDA (GPU)
bend run-cu bitonic_sort.bend 18 -s

# Bitonic Sort CUDA nativo
./bitonic_sort_cuda 18
```

## Estrutura do Projeto

```
cuda-project/
├── bitonic_sort.bend           # Algoritmo Bitonic Sort em Bend
├── bitonic_sort_cuda.cu        # Implementação CUDA nativa do Bitonic Sort
├── bitonic_sort_cuda           # Binário CUDA nativo compilado (criado após compilação)
├── benchmark_bend.sh           # Script de benchmark unificado
├── README.md                   # Este arquivo
└── benchmark_results/          # Diretório de resultados (criado ao executar)
    └── bend_benchmark_*.txt    # Resultados de benchmark com timestamp
```