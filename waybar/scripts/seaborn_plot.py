#!/usr/bin/env python3
import seaborn as sns
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np
import psutil
import os

def create_plot():
    # Get CPU and RAM usage
    cpu_usage = psutil.cpu_percent(interval=1, percpu=True)
    ram_usage = psutil.virtual_memory().percent

    # Create a futuristic plot
    plt.style.use('dark_background')
    fig, ax = plt.subplots(figsize=(4, 2))

    # Plot CPU usage
    sns.lineplot(x=np.arange(len(cpu_usage)), y=cpu_usage, ax=ax, color='cyan', marker='o', label='CPU')

    # Plot RAM usage
    ax.axhline(y=ram_usage, color='magenta', linestyle='--', label='RAM')

    # Customize the plot
    ax.set_title('System Stats')
    ax.set_xlabel('CPU Core')
    ax.set_ylabel('Usage (%)')
    ax.legend()
    ax.grid(True, which='both', linestyle='--', linewidth=0.5, color='grey')
    ax.set_ylim(0, 100)

    # Save the plot to a temporary file
    plot_path = '/tmp/sys_stats.png'
    plt.savefig(plot_path, bbox_inches='tight', pad_inches=0.1, transparent=True)
    plt.close(fig)
    return plot_path

if __name__ == "__main__":
    create_plot()
