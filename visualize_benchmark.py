#!/usr/bin/env python3
"""
Script para visualizar resultados de benchmarks do Bend.
Gera gráficos comparativos de tempos médios e speedup.
"""

import re
import sys
import argparse
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.ticker import MaxNLocator
from pathlib import Path


def parse_benchmark_file(file_path):
    """
    Parseia o arquivo de benchmark e extrai dados relevantes.
    
    Returns:
        dict: Dicionário com backends, tempos médios e speedups
    """
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    summary_section = re.search(
        r'RESUMO DO BENCHMARK.*?--- Bitonic Sort.*?\n(.*?)\n={50,}',
        content,
        re.DOTALL
    )
    
    if not summary_section:
        raise ValueError("Não foi possível encontrar a seção RESUMO DO BENCHMARK")
    
    summary_lines = summary_section.group(1).strip().split('\n')
    
    backends = []
    avg_times = []
    avg_mips = []
    speedups = []
    
    # Pular linha de cabeçalho e separador
    for line in summary_lines[2:]:
        if not line.strip() or '---' in line:
            continue
        
        # Parsear linha: Backend name, Tempo Médio, MIPS Médio, Speedup
        # Exemplo: "Rust Interpreter (Sequential)       48.813          25.986          1.00x"
        match = re.match(
            r'(.+?)\s{2,}(\d+\.?\d*)\s{2,}([\d.]+|N/A)\s{2,}([\d.]+)x',
            line
        )
        
        if match:
            backend_name = match.group(1).strip()
            avg_time = float(match.group(2))
            mips_value = match.group(3)
            speedup = float(match.group(4))
            
            backends.append(backend_name)
            avg_times.append(avg_time)
            if mips_value == 'N/A':
                avg_mips.append(None)
            else:
                avg_mips.append(float(mips_value))
            speedups.append(speedup)
    
    return {
        'backends': backends,
        'avg_times': avg_times,
        'avg_mips': avg_mips,
        'speedups': speedups
    }


def create_time_comparison_chart(data, output_dir):
    """
    Cria gráfico de barras comparando tempos médios de execução.
    """
    backends = data['backends']
    avg_times = data['avg_times']
    
    fig, ax = plt.subplots(figsize=(12, 7))
    
    colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728']
    
    bars = ax.bar(range(len(backends)), avg_times, color=colors[:len(backends)])
    
    ax.set_ylim(bottom=0, top=60)
    
    ax.yaxis.set_major_locator(MaxNLocator(integer=False, nbins=13))
    ax.yaxis.set_major_formatter(plt.FuncFormatter(lambda x, p: f'{x:.1f}'))
    
    ax.set_xlabel('Backend', fontsize=12, fontweight='bold')
    ax.set_ylabel('Tempo Médio (segundos)', fontsize=12, fontweight='bold')
    ax.set_title('Comparação de Tempos Médios de Execução\nBitonic Sort (depth: 18, 2^18 = 262144 elementos)',
                 fontsize=14, fontweight='bold', pad=20)
    
    ax.set_xticks(range(len(backends)))
    ax.set_xticklabels(backends, rotation=15, ha='right', fontsize=10)
    
    for i, (bar, time) in enumerate(zip(bars, avg_times)):
        height = bar.get_height()
        if time >= 1:
            label = f'{time:.3f}s'
        elif time >= 0.001:
            label = f'{time:.4f}s'
        else:
            label = f'{time:.6f}s'
        
        ax.text(bar.get_x() + bar.get_width()/2., height,
                label,
                ha='center', va='bottom', fontsize=9, fontweight='bold')
    
    ax.grid(True, axis='y', alpha=0.3, linestyle='--')
    ax.set_axisbelow(True)
    
    plt.tight_layout()
    
    output_path = output_dir / 'tempos_medios.png'
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"Gráfico salvo: {output_path}")
    
    plt.close()


def create_speedup_chart(data, output_dir):
    """
    Cria gráfico de barras comparando speedup de cada backend.
    """
    backends = data['backends']
    speedups = data['speedups']
    
    fig, ax = plt.subplots(figsize=(12, 7))
    
    colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728']
    
    bars = ax.bar(range(len(backends)), speedups, color=colors[:len(backends)])
    
    ax.axhline(y=1.0, color='gray', linestyle='--', linewidth=2, 
               label='Baseline (Rust Sequential)', alpha=0.7)
    
    ax.set_yscale('log')
    
    ax.set_xlabel('Backend', fontsize=12, fontweight='bold')
    ax.set_ylabel('Speedup (escala logarítmica)', fontsize=12, fontweight='bold')
    ax.set_title('Comparação de Speedup em Relação ao Baseline\nBitonic Sort (depth: 18)',
                 fontsize=14, fontweight='bold', pad=20)
    
    ax.set_xticks(range(len(backends)))
    ax.set_xticklabels(backends, rotation=15, ha='right', fontsize=10)
    
    for i, (bar, speedup) in enumerate(zip(bars, speedups)):
        height = bar.get_height()
        if speedup >= 1000:
            label = f'{speedup:.2f}x'
        elif speedup >= 10:
            label = f'{speedup:.2f}x'
        else:
            label = f'{speedup:.2f}x'
        
        ax.text(bar.get_x() + bar.get_width()/2., height,
                label,
                ha='center', va='bottom', fontsize=9, fontweight='bold')
    
    ax.legend(loc='upper left', fontsize=10)
    
    ax.grid(True, axis='y', alpha=0.3, linestyle='--')
    ax.set_axisbelow(True)
    
    plt.tight_layout()
    
    output_path = output_dir / 'speedup_comparativo.png'
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"Gráfico salvo: {output_path}")
    
    plt.close()


def create_mips_chart(data, output_dir):
    """
    Cria gráfico de barras comparando MIPS médio de cada interpretador.
    """
    backends = data['backends']
    avg_mips = data['avg_mips']
    
    valid_backends = []
    valid_mips = []
    valid_indices = []
    
    for i, (backend, mips) in enumerate(zip(backends, avg_mips)):
        if mips is not None:
            valid_backends.append(backend)
            valid_mips.append(mips)
            valid_indices.append(i)
    
    fig, ax = plt.subplots(figsize=(12, 7))
    
    colors = ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728']
    valid_colors = [colors[i] for i in valid_indices]
    
    bars = ax.bar(range(len(valid_backends)), valid_mips, color=valid_colors)
    
    ax.set_xlabel('Backend', fontsize=12, fontweight='bold')
    ax.set_ylabel('MIPS Médio (Milhões de Instruções por Segundo)', fontsize=12, fontweight='bold')
    ax.set_title('Comparação de MIPS Médio por Interpretador\nBitonic Sort (depth: 18, 2^18 = 262144 elementos)',
                 fontsize=14, fontweight='bold', pad=20)
    
    ax.set_xticks(range(len(valid_backends)))
    ax.set_xticklabels(valid_backends, rotation=15, ha='right', fontsize=10)
    
    for i, (bar, mips) in enumerate(zip(bars, valid_mips)):
        height = bar.get_height()
        if mips >= 1000:
            label = f'{mips:.1f}'
        elif mips >= 100:
            label = f'{mips:.2f}'
        else:
            label = f'{mips:.2f}'
        
        ax.text(bar.get_x() + bar.get_width()/2., height,
                label,
                ha='center', va='bottom', fontsize=9, fontweight='bold')
    
    ax.grid(True, axis='y', alpha=0.3, linestyle='--')
    ax.set_axisbelow(True)
    
    plt.tight_layout()
    
    output_path = output_dir / 'mips_medio.png'
    plt.savefig(output_path, dpi=300, bbox_inches='tight')
    print(f"Gráfico salvo: {output_path}")
    
    plt.close()


def main():
    """Função principal."""
    parser = argparse.ArgumentParser(
        description='Visualiza resultados de benchmarks do Bend',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        'benchmark_file',
        nargs='?',
        default='benchmark_results/bend_benchmark_20251120_185555.txt',
        help='Caminho para o arquivo de benchmark (padrão: benchmark_results/bend_benchmark_20251120_185555.txt)'
    )
    parser.add_argument(
        '-o', '--output',
        default='benchmark_results',
        help='Diretório de saída para os gráficos (padrão: benchmark_results)'
    )
    
    args = parser.parse_args()
    
    benchmark_path = Path(args.benchmark_file)
    if not benchmark_path.exists():
        print(f"Erro: Arquivo não encontrado: {benchmark_path}", file=sys.stderr)
        sys.exit(1)
    
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"Parseando arquivo: {benchmark_path}")
    
    try:
        data = parse_benchmark_file(benchmark_path)
        
        print(f"Backends encontrados: {len(data['backends'])}")
        for backend, time, mips, speedup in zip(data['backends'], data['avg_times'], data['avg_mips'], data['speedups']):
            mips_str = f"{mips:.2f}" if mips is not None else "N/A"
            print(f"  - {backend}: {time:.3f}s, MIPS: {mips_str}, {speedup:.2f}x")
        
        print("\nGerando gráficos...")
        create_time_comparison_chart(data, output_dir)
        create_speedup_chart(data, output_dir)
        create_mips_chart(data, output_dir)
        
        print("\nVisualização concluída!")
        
    except Exception as e:
        print(f"Erro ao processar benchmark: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()

