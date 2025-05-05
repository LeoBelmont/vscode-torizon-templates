import subprocess
import json
import re
from pathlib import Path

def run_env_setup_and_get_commands():
    bash_command = '''
    source bash/tcb-env-setup.sh -a remote
    torizoncore-builder --help
    '''
    
    result = subprocess.run(
            bash_command, capture_output=True, text=True, check=True
        )
    
    return result.stdout

def extract_commands(help_output):
    match = re.search(r"Commands:\s*(?:\{.*?\})\s*(.*?)(?=\n\S|\Z)", help_output, re.DOTALL)
    if not match:
        return []

    lines = match.group(1).splitlines()
    commands = []
    for line in lines:
        cmd = line.strip().split()[0]
        if cmd and cmd not in commands:
            commands.append(cmd)
    return commands

def load_task_labels(tasks_json_path):
    try:
        with open(tasks_json_path) as f:
            data = json.load(f)
            return [task.get("label") for task in data.get("tasks", [])]
    except Exception as e:
        print(f"❌ Failed to read {tasks_json_path}: {e}")
        return []

def main():
    tasks_path = Path("../tcb/.vscode/tasks.json")
    
    help_output = run_env_setup_and_get_commands()
    
    if not help_output:
        return

    commands = extract_commands(help_output)

    labels = load_task_labels(tasks_path)

    missing = [cmd for cmd in commands if cmd not in labels]
    
    if missing:
        print("\n❗ The following commands are missing from your task labels:")
        for cmd in missing:
            print(f"  - {cmd}")
    else:
        print("✅ All torizoncore-builder commands are represented in the task labels.")

if __name__ == "__main__":
    main()
