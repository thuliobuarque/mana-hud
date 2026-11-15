#!/usr/bin/env python3
"""Mana HUD: a small cross-platform window for ai-usagebar."""
import argparse
import datetime as dt
import json
import os
import shutil
import socket
import subprocess
import sys
import threading
import time

REFRESH_SECONDS = 180
PROVIDERS = {"anthropic", "openai", "antigravity"}


def remaining(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    return max(0, min(100, round(100 - value)))


def countdown(value, now=None):
    if not value:
        return "reset indisponível"
    try:
        target = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        if target.tzinfo is None:
            return "reset indisponível"
        seconds = max(0, int((target - (now or dt.datetime.now(dt.timezone.utc))).total_seconds()))
        days, seconds = divmod(seconds, 86400)
        hours, seconds = divmod(seconds, 3600)
        minutes, seconds = divmod(seconds, 60)
        return (f"{days}d " if days else "") + f"{hours:02d}:{minutes:02d}:{seconds:02d}"
    except (ValueError, TypeError, OverflowError):
        return "reset indisponível"


def fetch():
    exe = shutil.which("ai-usagebar")
    if not exe:
        raise RuntimeError("ai-usagebar não encontrado no PATH")
    result = subprocess.run([exe, "usage", "--json"], capture_output=True, text=True, timeout=45, check=False)
    if result.returncode:
        raise RuntimeError("ai-usagebar retornou erro; confira a autenticação no terminal")
    data = json.loads(result.stdout)
    if not isinstance(data.get("entries"), list):
        raise ValueError("resposta inesperada do ai-usagebar")
    return [entry for entry in data["entries"] if isinstance(entry, dict) and entry.get("id") in PROVIDERS]


def run_gui():
    import tkinter as tk
    from tkinter import ttk

    # Socket local evita janelas duplicadas sem gravar estado pessoal.
    lock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        lock.bind(("127.0.0.1", 48763))
        lock.listen(1)
    except OSError:
        lock.close()
        return
    root = tk.Tk()
    root.title("Mana HUD — Player Status")
    root.geometry("440x560")
    root.configure(bg="#0d1626")
    root.attributes("-topmost", True)
    tk.Label(root, text="MANA HUD  /  PLAYER STATUS", fg="#5be0ff", bg="#0d1626", font=("Arial", 14, "bold")).pack(pady=(14, 4))
    status = tk.Label(root, text="Conectando...", fg="#9aadc4", bg="#0d1626")
    status.pack()
    container = tk.Frame(root, bg="#0d1626")
    container.pack(fill="both", expand=True, padx=16, pady=10)
    clock_labels = []
    busy = False
    last_refresh = None

    def display(entries, error):
        nonlocal busy, last_refresh
        busy = False
        last_refresh = time.monotonic()
        if error:
            status.config(text=error, fg="#ff7180")
            return
        for child in container.winfo_children():
            child.destroy()
        clock_labels.clear()
        status.config(fg="#9aadc4")
        if not entries:
            tk.Label(container, text="Nenhum provedor configurado.", fg="white", bg="#0d1626").pack()
        for entry in entries:
            card = tk.Frame(container, bg="#162338", padx=10, pady=8)
            card.pack(fill="x", pady=4)
            tk.Label(card, text=str(entry.get("display_name") or entry.get("id")), fg="#5be0ff", bg="#162338", font=("Arial", 11, "bold")).pack(anchor="w")
            if entry.get("error"):
                tk.Label(card, text="Dados indisponíveis; verifique a conta.", fg="#ff7180", bg="#162338").pack(anchor="w")
            for index, metric in enumerate(entry.get("metrics") or []):
                if not isinstance(metric, dict):
                    continue
                value = remaining(metric.get("percent"))
                label = str(metric.get("label") or "Limite")
                tag = ("HP", "MP", "SP")[min(index, 2)]
                tk.Label(card, text=f"{tag} · {label}  —  {str(value) + '%' if value is not None else 'indisponível'} livre", fg="#e1ebfa", bg="#162338").pack(anchor="w")
                if value is not None:
                    ttk.Progressbar(card, maximum=100, value=value).pack(fill="x")
                timer = tk.Label(card, fg="#9aadc4", bg="#162338")
                timer.pack(anchor="w")
                clock_labels.append((timer, metric.get("reset_at")))

    def refresh():
        nonlocal busy
        if busy:
            return
        busy = True
        status.config(text="Atualizando...")
        def worker():
            try:
                entries, error = fetch(), None
            except (OSError, ValueError, subprocess.SubprocessError, RuntimeError):
                entries, error = None, "Não foi possível atualizar. Confira o ai-usagebar."
            try:
                root.after(0, lambda: display(entries, error))
            except RuntimeError:
                pass
        threading.Thread(target=worker, daemon=True).start()

    def tick():
        for label, reset in clock_labels:
            label.config(text="RESET  " + countdown(reset))
        if last_refresh is not None and not busy:
            left = max(0, int(REFRESH_SECONDS - (time.monotonic() - last_refresh)))
            status.config(text=f"Próxima atualização em {left // 60:02d}:{left % 60:02d}")
            if left <= 0:
                refresh()
        root.after(1000, tick)

    tk.Button(root, text="Atualizar agora", command=refresh).pack(pady=(0, 12))
    refresh()
    tick()
    root.mainloop()
    lock.close()


def launch():
    exe = sys.executable
    if os.name == "nt":
        pythonw = os.path.join(os.path.dirname(exe), "pythonw.exe")
        if os.path.exists(pythonw):
            exe = pythonw
    subprocess.Popen([exe, os.path.abspath(__file__), "--window"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--window", action="store_true", help="abre a janela no processo atual")
    args = parser.parse_args()
    run_gui() if args.window else launch()
