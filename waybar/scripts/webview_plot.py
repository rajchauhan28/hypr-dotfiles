#!/usr/bin/env python3
import webview
import psutil
import json
import time
import threading
import webview.errors

font_name = 'Syne Mono'

# Corrected HTML string for webview_plot.py

html = f"""
<!DOCTYPE html>
<html>
<head>
    <title>System Stats</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {{
            background-color: transparent;
            color: #eee;
            font-family: '{font_name}', 'monospace';
            overflow: hidden;
        }}
        .chart-container {{
            position: relative;
            width: 400px;
            height: 200px;
        }}
    </style>
</head>
<body>
    <div class="chart-container">
        <canvas id="myChart"></canvas>
        <div id="stats-text" style="position: absolute; top: 10px; left: 10px; font-size: 14px;"></div>
    </div>
    <script>
        const ctx = document.getElementById('myChart').getContext('2d');
        const myChart = new Chart(ctx, {{
            type: 'line',
            data: {{
                labels: [],
                datasets: [{{
                    label: 'CPU %',
                    data: [],
                    borderColor: 'rgba(0, 255, 255, 0.8)',
                    backgroundColor: 'rgba(0, 255, 255, 0.2)',
                    pointRadius: 0,
                    fill: true,
                    tension: 0.4
                }}, {{
                    label: 'RAM %',
                    data: [],
                    borderColor: 'rgba(255, 0, 255, 0.8)',
                    backgroundColor: 'rgba(255, 0, 255, 0.2)',
                    pointRadius: 0,
                    fill: true,
                    tension: 0.4
                }}]
            }},
            options: {{
                responsive: true,
                maintainAspectRatio: false,
                plugins: {{
                    legend: {{
                        display: false
                    }}
                }},
                scales: {{
                    x: {{
                        display: false
                    }},
                    y: {{
                        display: false,
                        beginAtZero: true,
                        max: 100,
                        grid: {{
                            display: false
                        }},
                        ticks: {{
                            display: false
                        }}
                    }}
                }}
            }}
        }});

        function updateData(cpu_data, ram_data) {{
            myChart.data.labels = Array.from(Array(cpu_data.length).keys());
            myChart.data.datasets[0].data = cpu_data;
            myChart.data.datasets[1].data = ram_data;
            myChart.update('none'); // 'none' for no animation

            const latest_cpu = cpu_data[cpu_data.length - 1];
            const latest_ram = ram_data[ram_data.length - 1];
            document.getElementById('stats-text').innerText = `CPU: ${{latest_cpu.toFixed(0)}}% | RAM: ${{latest_ram.toFixed(0)}}%`;
        }}
    </script>
</body>
</html>
"""
def get_stats():
    # Non-blocking call. First call returns 0, subsequent calls return usage since last call.
    cpu_percents = psutil.cpu_percent(percpu=True)
    if not cpu_percents:
        return 0.0, psutil.virtual_memory().percent
    cpu_avg = sum(cpu_percents) / len(cpu_percents)
    mem = psutil.virtual_memory().percent
    return cpu_avg, mem

if __name__ == '__main__':
    # Initialize cpu_percent before the loop
    psutil.cpu_percent(percpu=True)
    time.sleep(0.1) # Wait a bit for the next measurement to be meaningful

    window = webview.create_window(
        'System Stats',
        html=html,
        width=420,
        height=220,
        frameless=True,
        on_top=True,
        transparent=True,
        easy_drag=True
    )

    cpu_history = []
    ram_history = []

    def update_plot_in_thread():
        while True:
            cpu, mem = get_stats()
            cpu_history.append(cpu)
            ram_history.append(mem)

            if len(cpu_history) > 50: # More data points for a smoother graph
                cpu_history.pop(0)
                ram_history.pop(0)

            js_code = f'updateData({json.dumps(cpu_history)}, {json.dumps(ram_history)})'
            
            try:
                window.evaluate_js(js_code)
            except webview.errors.WebViewException:
                # The window has been closed, so we break the loop
                break

            time.sleep(0.5) # The update interval

    update_thread = threading.Thread(target=update_plot_in_thread)
    update_thread.daemon = True
    update_thread.start()

    webview.start()
